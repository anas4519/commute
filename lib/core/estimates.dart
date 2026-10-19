import 'models.dart';

/// Derived (not API-backed) estimates.
abstract final class Estimates {
  /// E-rickshaw time: mean of car and two-wheeler durations, rounded to the
  /// nearest minute (returned in seconds). Null unless both are available and
  /// belong to [routeKey].
  static int? eRickSec(LegResult? car, LegResult? bike, String routeKey) {
    bool usable(LegResult? r) => r != null && r.ok && r.routeKey == routeKey;
    if (!usable(car) || !usable(bike)) return null;
    final avgMin = (car!.durationSec! + bike!.durationSec!) / 2 / 60;
    return avgMin.round() * 60;
  }
}
