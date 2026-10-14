import 'package:commute/core/matrix_planner.dart';
import 'package:commute/core/models.dart';
import 'package:commute/data/routes_client.dart';
import 'package:flutter_test/flutter_test.dart';

Place pl(String n, double lat, double lng) => Place(label: n, location: LatLng(lat, lng));
final home = pl('Home', 28.60, 77.20), a = pl('A', 28.61, 77.21), b = pl('B', 28.62, 77.22);
final office = pl('Office', 28.50, 77.10);
CommutePair pr(String id, Place o, Place d) => CommutePair(id: id, name: '', origin: o, destination: d);

void main() {
  test('shared origin → one request, one element per pair', () {
    final plan = MatrixPlanner.plan([pr('1', home, a), pr('2', home, b)]);
    expect(plan, hasLength(1));
    expect(plan.single.billedElements, 2);
    expect(plan.single.cells[(0, 0)], ['1']);
    expect(plan.single.cells[(0, 1)], ['2']);
  });

  test('disjoint pairs stay grouped (avoid paying for cross product)', () {
    final plan = MatrixPlanner.plan([pr('1', home, a), pr('2', office, b)]);
    expect(plan, hasLength(2));
    expect(plan.fold<int>(0, (s, r) => s + r.billedElements), 2);
  });

  test('complete bipartite pairs → single full matrix', () {
    final plan = MatrixPlanner.plan([
      pr('1', home, a),
      pr('2', home, b),
      pr('3', office, a),
      pr('4', office, b),
    ]);
    expect(plan, hasLength(1));
    expect(plan.single.billedElements, 4);
  });

  test('duplicate pairs share a cell', () {
    final plan = MatrixPlanner.plan([pr('1', home, a), pr('2', home, a)]);
    expect(plan.single.billedElements, 1);
    expect(plan.single.cells[(0, 0)], ['1', '2']);
  });

  test('empty → no requests', () => expect(MatrixPlanner.plan([]), isEmpty));

  test('mapResponse: ok, per-cell error, missing cell, unordered', () {
    final pairs = [pr('1', home, a), pr('2', home, b), pr('3', home, office)];
    final req = MatrixPlanner.plan(pairs).single;
    final keys = {for (final p in pairs) p.id: p.routeKey};
    final now = DateTime(2026);
    final res = MatrixPlanner.mapResponse(
      req,
      [
        {'originIndex': 0, 'destinationIndex': 1, 'condition': 'ROUTE_NOT_FOUND', 'status': {}},
        {
          'originIndex': 0,
          'destinationIndex': 0,
          'duration': '754s',
          'distanceMeters': 3200,
          'condition': 'ROUTE_EXISTS',
          'status': {},
        },
      ],
      keys,
      now,
    );
    expect(res['1']!.durationSec, 754);
    expect(res['1']!.distanceMeters, 3200);
    expect(res['1']!.routeKey, pairs[0].routeKey);
    expect(res['2']!.ok, isFalse);
    expect(res['2']!.error, 'No route');
    expect(res['3']!.ok, isFalse); // not returned at all
  });

  test('mapResponse: status error and omitted originIndex (=0)', () {
    final req = MatrixPlanner.plan([pr('1', home, a)]).single;
    final res = MatrixPlanner.mapResponse(
      req,
      [
        {
          'status': {'code': 3, 'message': 'bad'},
        },
      ],
      {'1': 'k'},
      DateTime(2026),
    );
    expect(res['1']!.error, 'bad');
  });

  test('parseDuration', () {
    expect(MatrixPlanner.parseDuration('160s'), 160);
    expect(MatrixPlanner.parseDuration('12.6s'), 13);
    expect(MatrixPlanner.parseDuration(null), isNull);
    expect(MatrixPlanner.parseDuration('x'), isNull);
  });

  test('request body: traffic only for motor modes', () {
    final req = MatrixPlanner.plan([pr('1', home, a)]).single;
    expect(RoutesClient.body(req, TravelMode.drive)['routingPreference'], 'TRAFFIC_AWARE');
    expect(RoutesClient.body(req, TravelMode.twoWheeler)['travelMode'], 'TWO_WHEELER');
    expect(RoutesClient.body(req, TravelMode.walk).containsKey('routingPreference'), isFalse);
  });
}
