import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

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

  /// Follows a maps.app.goo.gl short link and returns the final URL.
  Future<String?> resolveShortLink(String url) async {
    try {
      var uri = Uri.parse(url.trim());
      for (var i = 0; i < 5; i++) {
        final r = await _http
            .send(http.Request('GET', uri)..followRedirects = false)
            .timeout(const Duration(seconds: 8));
        final loc = r.headers['location'];
        if (loc == null) return uri.toString();
        uri = uri.resolve(loc);
      }
      return uri.toString();
    } catch (_) {
      return null;
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
