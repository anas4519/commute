import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/matrix_planner.dart';
import '../core/models.dart';
import 'config.dart';

class RoutesClient {
  RoutesClient({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;
  static final _url = Uri.parse('https://routes.googleapis.com/distanceMatrix/v2:computeRouteMatrix');
  static const _mask = 'originIndex,destinationIndex,duration,distanceMeters,status,condition';

  static Map<String, dynamic> body(MatrixRequest r, TravelMode mode) => {
    'origins': r.origins.map((o) => o.toWaypoint()).toList(),
    'destinations': r.destinations.map((d) => d.toWaypoint()).toList(),
    'travelMode': mode.api,
    if (mode.trafficAware) 'routingPreference': 'TRAFFIC_AWARE',
    'regionCode': 'IN',
    'units': 'METRIC',
  };

  Future<List<dynamic>> matrix(MatrixRequest r, TravelMode mode) => _send(r, mode, retry: true);

  Future<List<dynamic>> _send(MatrixRequest r, TravelMode mode, {required bool retry}) async {
    final res = await _http
        .post(_url, headers: AppConfig.headers(_mask), body: jsonEncode(body(r, mode)))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode == 429 && retry) {
      await Future<void>.delayed(const Duration(seconds: 2));
      return _send(r, mode, retry: false);
    }
    if (res.statusCode != 200) throw ApiException.fromResponse(res.statusCode, res.body);
    final decoded = jsonDecode(res.body);
    return decoded is List ? decoded : const [];
  }
}
