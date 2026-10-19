import 'package:commute/core/estimates.dart';
import 'package:commute/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t = DateTime(2026);
  LegResult r(int? sec, {String key = 'k', String? err}) =>
      LegResult(durationSec: sec, error: err, fetchedAt: t, routeKey: key);

  test('average of car and bike, rounded to nearest minute', () {
    expect(Estimates.eRickSec(r(600), r(420), 'k'), 540); // 10 & 7 min → 8.5 → 9
    expect(Estimates.eRickSec(r(610), r(400), 'k'), 480); // 8.42 min → 8
    expect(Estimates.eRickSec(r(300), r(300), 'k'), 300);
  });

  test('null unless both available for this route', () {
    expect(Estimates.eRickSec(null, r(300), 'k'), isNull);
    expect(Estimates.eRickSec(r(300), null, 'k'), isNull);
    expect(Estimates.eRickSec(r(300), r(null, err: 'x'), 'k'), isNull);
    expect(Estimates.eRickSec(r(300), r(300, key: 'old'), 'k'), isNull);
  });
}
