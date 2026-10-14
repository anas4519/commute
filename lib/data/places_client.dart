import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../core/link_utils.dart';
import '../core/models.dart';
import 'config.dart';

class Suggestion {
  final String placeId;
  final String main;
  final String secondary;
  const Suggestion(this.placeId, this.main, this.secondary);
}

/// Places API (New): Autocomplete + Place Details sharing one session token.
/// A session = autocomplete requests until a selection, then one Details call.
class PlacesClient {
  PlacesClient({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;
  String? _session;

  /// Start a new billing session (call when the picker opens).
  void newSession() => _session = _uuidV4();

  Future<List<Suggestion>> autocomplete(String input) async {
    _session ??= _uuidV4();
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
        .timeout(const Duration(seconds: 8));
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
    final res = await _http
        .get(uri, headers: AppConfig.headers('id,displayName,formattedAddress,location'))
        .timeout(const Duration(seconds: 8));
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

  static const _ua =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0 Mobile Safari/537.36';

  /// Follows a short link (maps.app.goo.gl / goo.gl/maps) hop by hop and stops
  /// as soon as a URL carries coordinates. Handles consent.google.com and
  /// intent:// redirects, and falls back to scraping the final HTML page.
  Future<ResolveResult> resolveShortLink(String url) async {
    ResolveResult? last;
    for (var attempt = 0; attempt < 2; attempt++) {
      last = await _resolveOnce(url);
      if (last.location != null) return last;
      if (!last.retryable) return last;
    }
    return last!;
  }

  Future<ResolveResult> _resolveOnce(String start) async {
    var uri = Uri.parse(start);
    try {
      for (var hop = 0; hop < 8; hop++) {
        final req = http.Request('GET', uri)
          ..followRedirects = false
          ..headers.addAll({
            'User-Agent': _ua,
            'Accept-Language': 'en-IN,en;q=0.9',
            'Accept': 'text/html,*/*',
          });
        final res = await _http.send(req).timeout(const Duration(seconds: 15));
        final loc = res.headers['location'];
        if (res.isRedirect || (res.statusCode >= 300 && res.statusCode < 400 && loc != null)) {
          await res.stream.drain<void>();
          var next = LinkUtils.unwrapConsent(uri.resolve(loc!).toString());
          next = LinkUtils.fromIntent(loc.toLowerCase().startsWith('intent://') ? loc : next) ?? next;
          next = LinkUtils.unwrapConsent(next);
          final ll = LinkUtils.coordsFromUrl(next);
          if (ll != null) return ResolveResult(location: ll, finalUrl: next);
          uri = Uri.parse(next);
          continue;
        }
        if (res.statusCode != 200) {
          await res.stream.drain<void>();
          return ResolveResult(
            error: 'HTTP ${res.statusCode} from ${uri.host}',
            retryable: res.statusCode >= 500,
          );
        }
        final direct = LinkUtils.coordsFromUrl(uri.toString());
        if (direct != null) {
          await res.stream.drain<void>();
          return ResolveResult(location: direct, finalUrl: uri.toString());
        }
        // Read up to ~1.5 MB of HTML and scrape coordinates.
        final bytes = <int>[];
        await for (final chunk in res.stream.timeout(const Duration(seconds: 15))) {
          bytes.addAll(chunk);
          if (bytes.length > 1500000) break;
        }
        final ll = LinkUtils.coordsFromHtml(String.fromCharCodes(bytes));
        return ll != null
            ? ResolveResult(location: ll, finalUrl: uri.toString())
            : ResolveResult(error: 'No coordinates on ${uri.host}${uri.path}', finalUrl: uri.toString());
      }
      return ResolveResult(error: 'Too many redirects');
    } on TimeoutException {
      return ResolveResult(error: 'Timed out reaching ${uri.host}', retryable: true);
    } on SocketException catch (e) {
      return ResolveResult(error: 'Network error: ${e.message}', retryable: true);
    } on http.ClientException catch (e) {
      return ResolveResult(error: 'Network error: ${e.message}', retryable: true);
    } catch (e) {
      return ResolveResult(error: 'Unexpected: $e');
    }
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
  const ResolveResult({this.location, this.finalUrl, this.error, this.retryable = false});
}
