import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/link_utils.dart';
import '../core/log.dart';
import '../core/models.dart';
import 'config.dart';
import 'doh.dart';
import 'http_factory.dart';

class Suggestion {
  final String placeId;
  final String main;
  final String secondary;
  const Suggestion(this.placeId, this.main, this.secondary);
}

/// Places API (New): Autocomplete + Place Details sharing one session token.
/// A session = autocomplete requests until a selection, then one Details call.
class PlacesClient {
  PlacesClient({
    http.Client? client,
    http.Client Function()? resolverClient,
    List<(String, FutureOr<http.Client?> Function(String host))>? resolverPaths,
    this.hopTimeout = const Duration(seconds: 10),
    this.bodyTimeout = const Duration(seconds: 8),
    this.deadline = const Duration(seconds: 10),
  }) : _http = client ?? http.Client(),
       _paths = resolverPaths ?? (resolverClient != null ? [('test', (_) => resolverClient())] : defaultPaths);
  final http.Client _http;
  final List<(String, FutureOr<http.Client?> Function(String host))> _paths;

  static bool _isGoogleShortHost(String h) => h == 'maps.app.goo.gl' || h == 'goo.gl' || h == 'g.co';

  /// Order: DoH-pinned (bypasses ISP DNS poisoning) → Cronet → dart:io.
  /// (WebView is the UI-level last resort.)
  static final defaultPaths = <(String, FutureOr<http.Client?> Function(String host))>[
    (
      'doh',
      (host) async {
        if (!_isGoogleShortHost(host)) return null;
        final ips = await Doh.lookup(host);
        if (ips.isEmpty) return null;
        AppLog.d('link', 'doh pin $host → ${ips.first}');
        return Doh.pinned(host, ips.first);
      },
    ),
    ('cronet', (_) => HttpFactory.native()),
    ('dart:io', (_) => HttpFactory.io()),
  ];
  final Duration hopTimeout, bodyTimeout, deadline;
  String? _session;

  /// Start a new billing session (call when the picker opens).
  void newSession() => _session = _uuidV4();

  Future<List<Suggestion>> autocomplete(String input) async {
    _session ??= _uuidV4();
    final sw = Stopwatch()..start();
    final res = await _http
        .post(
          Uri.parse('https://places.googleapis.com/v1/places:autocomplete'),
          headers: AppConfig.headers(
            'suggestions.placePrediction.placeId,suggestions.placePrediction.structuredFormat',
          ),
          body: jsonEncode({
            'input': input,
            'sessionToken': _session,
            'includedRegionCodes': ['in'],
            'regionCode': 'in',
            'languageCode': 'en',
            'locationBias': {
              'circle': {
                'center': {'latitude': 28.6139, 'longitude': 77.2090},
                'radius': 50000.0,
              },
            },
          }),
        )
        .timeout(const Duration(seconds: 8))
        .catchError((Object e) {
          AppLog.d('places', 'autocomplete "${AppLog.trunc(input, 40)}" failed ${e.runtimeType}: $e');
          throw e;
        });
    AppLog.d(
      'places',
      'autocomplete "${AppLog.trunc(input, 40)}" → ${res.statusCode} in ${sw.elapsedMilliseconds}ms'
          '${res.statusCode == 200 ? '' : ' body=${AppLog.trunc(res.body)}'}',
    );
    if (res.statusCode != 200) throw ApiException.fromResponse(res.statusCode, res.body);
    final list = (jsonDecode(res.body)['suggestions'] as List?) ?? const [];
    return [
      for (final s in list)
        if (s['placePrediction'] != null)
          Suggestion(
            s['placePrediction']['placeId'] as String,
            (s['placePrediction']['structuredFormat']?['mainText']?['text'] as String?) ?? '',
            (s['placePrediction']['structuredFormat']?['secondaryText']?['text'] as String?) ?? '',
          ),
    ];
  }

  /// Ends the session. Field mask kept to cheap fields only.
  Future<Place> details(String placeId) async {
    final uri = Uri.parse('https://places.googleapis.com/v1/places/$placeId')
        .replace(queryParameters: {'sessionToken': ?_session});
    _session = null;
    final sw = Stopwatch()..start();
    final res = await _http
        .get(uri, headers: AppConfig.headers('id,displayName,formattedAddress,location'))
        .timeout(const Duration(seconds: 8))
        .catchError((Object e) {
          AppLog.d('places', 'details $placeId failed ${e.runtimeType}: $e');
          throw e;
        });
    AppLog.d(
      'places',
      'details $placeId → ${res.statusCode} in ${sw.elapsedMilliseconds}ms'
          '${res.statusCode == 200 ? '' : ' body=${AppLog.trunc(res.body)}'}',
    );
    if (res.statusCode != 200) throw ApiException.fromResponse(res.statusCode, res.body);
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final loc = j['location'] as Map<String, dynamic>;
    return Place(
      label: (j['displayName']?['text'] as String?) ?? 'Place',
      address: j['formattedAddress'] as String?,
      placeId: j['id'] as String?,
      location: LatLng((loc['latitude'] as num).toDouble(), (loc['longitude'] as num).toDouble()),
    );
  }

  /// Nearest named place (Places Nearby Search, ranked by distance) used to
  /// label a GPS fix. Returns null when nothing usable comes back.
  Future<({String name, String? address})?> nearbyName(LatLng ll) async {
    final sw = Stopwatch()..start();
    final res = await _http
        .post(
          Uri.parse('https://places.googleapis.com/v1/places:searchNearby'),
          headers: AppConfig.headers('places.displayName,places.formattedAddress'),
          body: jsonEncode({
            'maxResultCount': 1,
            'rankPreference': 'DISTANCE',
            'languageCode': 'en',
            'locationRestriction': {
              'circle': {
                'center': {'latitude': ll.lat, 'longitude': ll.lng},
                'radius': 150.0,
              },
            },
          }),
        )
        .timeout(const Duration(seconds: 6));
    AppLog.d(
      'location',
      'nearby lookup → ${res.statusCode} in ${sw.elapsedMilliseconds}ms'
          '${res.statusCode == 200 ? '' : ' body=${AppLog.trunc(res.body)}'}',
    );
    if (res.statusCode != 200) return null;
    return parseNearby(res.body);
  }

  static ({String name, String? address})? parseNearby(String body) {
    final j = jsonDecode(body);
    if (j is! Map) return null;
    final places = j['places'];
    if (places is! List || places.isEmpty || places.first is! Map) return null;
    final p = places.first as Map;
    final dn = p['displayName'];
    final name = dn is Map ? dn['text'] as String? : null;
    if (name == null || name.trim().isEmpty) return null;
    return (name: name.trim(), address: p['formattedAddress'] as String?);
  }

  static const _ua =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0 Mobile Safari/537.36';
  static const _maxHtmlBytes = 600000;

  /// Resolves a short link to coordinates. Never hangs: every hop, every body
  /// read, and the whole flow (incl. one retry) have hard timeouts, and the
  /// per-resolve HTTP client is closed at the end to abort open sockets.
  Future<ResolveResult> resolveShortLink(String url) async {
    AppLog.d('link', 'resolve start ${AppLog.trunc(url)}');
    final host = Uri.tryParse(url)?.host;
    if (host != null && host.isNotEmpty) HttpFactory.logDns(host);
    ResolveResult last = const ResolveResult(error: 'No HTTP stack available');
    for (final (name, make) in _paths) {
      http.Client? client;
      try {
        client = await Future.value(make(host ?? '')).timeout(const Duration(seconds: 8));
      } catch (e) {
        AppLog.d('link', 'path $name setup failed ${e.runtimeType}: $e');
      }
      if (client == null) {
        AppLog.d('link', 'path $name unavailable');
        continue;
      }
      final sw = Stopwatch()..start();
      try {
        last = await _resolveWithRetry(client, url).timeout(
          deadline,
          onTimeout: () {
            AppLog.d('link', 'path $name deadline ${deadline.inSeconds}s hit');
            return const ResolveResult(error: 'Timed out');
          },
        );
      } finally {
        client.close(); // aborts any in-flight request/body
      }
      AppLog.d(
        'link',
        'path $name ${last.location != null ? 'OK' : 'failed (${last.error})'} in ${sw.elapsedMilliseconds}ms',
      );
      if (last.location != null) return last.withPath(name);
    }
    return last;
  }

  Future<ResolveResult> _resolveWithRetry(http.Client client, String url) async {
    var r = await _resolveOnce(client, url);
    if (r.location == null && r.retryable) {
      AppLog.d('link', 'retrying after: ${r.error}');
      r = await _resolveOnce(client, url);
    }
    AppLog.d('link', r.location != null ? 'result ${r.location}' : 'failed: ${r.error}');
    return r;
  }

  Future<ResolveResult> _resolveOnce(http.Client client, String start) async {
    var uri = Uri.parse(start);
    final seen = <String>{};
    try {
      for (var hop = 0; hop < 8; hop++) {
        if (!seen.add(uri.toString())) {
          AppLog.d('link', 'redirect loop at ${AppLog.trunc(uri.toString())}');
          return const ResolveResult(error: 'Redirect loop');
        }
        final sw = Stopwatch()..start();
        final req = http.Request('GET', uri)
          ..followRedirects = false
          ..headers.addAll({'User-Agent': _ua, 'Accept-Language': 'en-IN,en;q=0.9', 'Accept': 'text/html,*/*'});
        final res = await client.send(req).timeout(hopTimeout);
        final loc = res.headers['location'];
        AppLog.d(
          'link',
          'hop $hop ${uri.host}${AppLog.trunc(uri.path, 60)} → ${res.statusCode} in ${sw.elapsedMilliseconds}ms'
              ' len=${res.contentLength ?? '?'} loc=${AppLog.trunc(loc, 120)}',
        );
        if (res.statusCode >= 300 && res.statusCode < 400 && loc != null) {
          _discard(res); // do NOT await drain: a never-ending body would hang here
          var next = uri.resolve(loc).toString();
          if (loc.toLowerCase().startsWith('intent://')) {
            next = LinkUtils.fromIntent(loc) ?? next;
            AppLog.d('link', 'branch intent → ${AppLog.trunc(next)}');
          }
          final unwrapped = LinkUtils.unwrapConsent(next);
          if (unwrapped != next) AppLog.d('link', 'branch consent → ${AppLog.trunc(unwrapped)}');
          next = unwrapped;
          final ll = LinkUtils.coordsFromUrl(next);
          if (ll != null) {
            AppLog.d('link', 'branch redirect-coords $ll');
            return ResolveResult(location: ll, finalUrl: next);
          }
          uri = Uri.parse(next);
          continue;
        }
        if (res.statusCode != 200) {
          _discard(res);
          return ResolveResult(error: 'HTTP ${res.statusCode} from ${uri.host}', retryable: res.statusCode >= 500);
        }
        final direct = LinkUtils.coordsFromUrl(uri.toString());
        if (direct != null) {
          _discard(res);
          AppLog.d('link', 'branch url-coords $direct');
          return ResolveResult(location: direct, finalUrl: uri.toString());
        }
        final html = await _readCapped(res.stream);
        AppLog.d('link', 'branch html-scrape read ${html.length} chars');
        final ll = LinkUtils.coordsFromHtml(html);
        return ll != null
            ? ResolveResult(location: ll, finalUrl: uri.toString())
            : ResolveResult(error: 'No coordinates on ${uri.host}${uri.path}', finalUrl: uri.toString());
      }
      return const ResolveResult(error: 'Too many redirects');
    } on TimeoutException {
      AppLog.d('link', 'TimeoutException on ${uri.host}');
      return ResolveResult(error: 'Timed out reaching ${uri.host}', retryable: true);
    } on HandshakeException catch (e) {
      AppLog.d('link', 'TLS HandshakeException: ${e.message} ${e.osError?.message ?? ''}');
      return ResolveResult(error: 'TLS error: ${e.message}', retryable: true);
    } on SocketException catch (e) {
      AppLog.d('link', 'SocketException: ${e.message} ${e.osError?.message ?? ''}');
      return ResolveResult(error: 'Network error: ${e.message}', retryable: true);
    } on http.ClientException catch (e) {
      AppLog.d('link', 'ClientException: ${e.message}');
      return ResolveResult(error: 'Network error: ${e.message}', retryable: true);
    } catch (e) {
      AppLog.d('link', 'Unexpected ${e.runtimeType}: $e');
      return ResolveResult(error: 'Unexpected: $e');
    }
  }

  static void _discard(http.StreamedResponse res) {
    // Listen and cancel immediately so the socket is released without waiting.
    res.stream.listen((_) {}, onError: (_) {}, cancelOnError: true).cancel();
  }

  /// Reads up to [_maxHtmlBytes] with a hard [bodyTimeout] for the whole body,
  /// then cancels the subscription. Returns whatever arrived (maybe partial).
  Future<String> _readCapped(Stream<List<int>> stream) {
    final bytes = BytesBuilder(copy: false);
    final done = Completer<String>();
    late final StreamSubscription<List<int>> sub;
    Timer? timer;
    void finish([String why = 'eof']) {
      if (done.isCompleted) return;
      timer?.cancel();
      sub.cancel();
      AppLog.d('link', 'body stop ($why) at ${bytes.length} bytes');
      done.complete(latin1.decode(bytes.takeBytes(), allowInvalid: true));
    }

    sub = stream.listen(
      (chunk) {
        bytes.add(chunk);
        if (bytes.length >= _maxHtmlBytes) finish('cap');
      },
      onError: (Object e) => finish('error ${e.runtimeType}'),
      onDone: finish,
      cancelOnError: true,
    );
    timer = Timer(bodyTimeout, () => finish('timeout'));
    return done.future;
  }

  static String _uuidV4() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }
}

class ResolveResult {
  final LatLng? location;
  final String? finalUrl;
  final String? error;
  final bool retryable;
  final String? path;
  const ResolveResult({this.location, this.finalUrl, this.error, this.retryable = false, this.path});
  ResolveResult withPath(String p) =>
      ResolveResult(location: location, finalUrl: finalUrl, error: error, retryable: retryable, path: p);
}
