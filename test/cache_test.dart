import 'package:commute/core/cache.dart';
import 'package:commute/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final p = CommutePair(
    id: '1',
    name: '',
    origin: const Place(label: 'H', location: LatLng(28.6, 77.2)),
    destination: const Place(label: 'A', location: LatLng(28.7, 77.3)),
  );
  final t0 = DateTime(2026, 10, 14, 9);
  LegResult ok(DateTime t, {String? key}) =>
      LegResult(durationSec: 600, distanceMeters: 1000, fetchedAt: t, routeKey: key ?? p.routeKey);

  test('traffic TTL 3 min, walk TTL 24 h', () {
    final c = ResultCache()
      ..put('1', TravelMode.drive, ok(t0))
      ..put('1', TravelMode.walk, ok(t0));
    expect(c.isFresh(p, TravelMode.drive, t0.add(const Duration(minutes: 2))), isTrue);
    expect(c.isFresh(p, TravelMode.drive, t0.add(const Duration(minutes: 3))), isFalse);
    expect(c.isFresh(p, TravelMode.walk, t0.add(const Duration(hours: 23))), isTrue);
  });

  test('force refetches traffic modes but not walk', () {
    final c = ResultCache()
      ..put('1', TravelMode.drive, ok(t0))
      ..put('1', TravelMode.walk, ok(t0));
    final now = t0.add(const Duration(seconds: 10));
    expect(c.stale([p], TravelMode.drive, now, force: true), hasLength(1));
    expect(c.stale([p], TravelMode.walk, now, force: true), isEmpty);
    expect(c.stale([p], TravelMode.drive, now), isEmpty);
  });

  test('edited endpoints and errors invalidate', () {
    final c = ResultCache()
      ..put('1', TravelMode.drive, ok(t0, key: 'old'))
      ..put('1', TravelMode.walk, LegResult(error: 'x', fetchedAt: t0, routeKey: p.routeKey));
    expect(c.isFresh(p, TravelMode.drive, t0), isFalse);
    expect(c.isFresh(p, TravelMode.walk, t0), isFalse);
  });

  test('round-trip encode/decode, retainOnly, lastUpdated, corrupt input', () {
    final c = ResultCache()
      ..put('1', TravelMode.twoWheeler, ok(t0))
      ..put('2', TravelMode.drive, ok(t0.add(const Duration(minutes: 1))));
    final d = ResultCache()..decode(c.encode());
    expect(d.get('1', TravelMode.twoWheeler)!.durationSec, 600);
    expect(d.lastUpdated(['1', '2']), t0.add(const Duration(minutes: 1)));
    d.retainOnly(['1']);
    expect(d.get('2', TravelMode.drive), isNull);
    d.decode('not json');
    expect(d.get('1', TravelMode.twoWheeler), isNull);
  });
}
