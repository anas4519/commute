import 'models.dart';

/// One computeRouteMatrix request (single travel mode) plus the mapping
/// from its (originIndex, destinationIndex) cells back to pair ids.
class MatrixRequest {
  final List<LatLng> origins;
  final List<LatLng> destinations;
  final Map<(int, int), List<String>> cells;
  const MatrixRequest(this.origins, this.destinations, this.cells);

  int get billedElements => origins.length * destinations.length;
}

class MatrixPlanner {
  static const maxElements = 625; // non-transit limit (100 for TRAFFIC_AWARE_OPTIMAL)

  /// Picks the cheapest plan (fewest billed elements; ties → fewest requests):
  ///  A) one request per distinct origin with its distinct destinations, or
  ///  B) a single full cross-product of all distinct origins × destinations.
  static List<MatrixRequest> plan(List<CommutePair> pairs) {
    if (pairs.isEmpty) return const [];
    final grouped = _groupByOrigin(pairs);
    final full = _fullMatrix(pairs);
    final groupedCost = grouped.fold<int>(0, (s, r) => s + r.billedElements);
    if (full.billedElements <= maxElements &&
        (full.billedElements < groupedCost || (full.billedElements == groupedCost && grouped.length > 1))) {
      return [full];
    }
    return grouped;
  }

  static List<MatrixRequest> _groupByOrigin(List<CommutePair> pairs) {
    final byOrigin = <LatLng, List<CommutePair>>{};
    for (final p in pairs) {
      byOrigin.putIfAbsent(p.origin.location, () => []).add(p);
    }
    final out = <MatrixRequest>[];
    byOrigin.forEach((origin, group) {
      final dests = <LatLng>[];
      final cells = <(int, int), List<String>>{};
      for (final p in group) {
        var di = dests.indexOf(p.destination.location);
        if (di < 0) {
          dests.add(p.destination.location);
          di = dests.length - 1;
        }
        cells.putIfAbsent((0, di), () => []).add(p.id);
      }
      // Chunk if a single origin has > maxElements destinations (unlikely).
      for (var start = 0; start < dests.length; start += maxElements) {
        final end = (start + maxElements).clamp(0, dests.length);
        final sub = <(int, int), List<String>>{};
        cells.forEach((k, v) {
          if (k.$2 >= start && k.$2 < end) sub[(0, k.$2 - start)] = v;
        });
        out.add(MatrixRequest([origin], dests.sublist(start, end), sub));
      }
    });
    return out;
  }

  static MatrixRequest _fullMatrix(List<CommutePair> pairs) {
    final origins = <LatLng>[], dests = <LatLng>[];
    final cells = <(int, int), List<String>>{};
    int idx(List<LatLng> l, LatLng v) {
      final i = l.indexOf(v);
      if (i >= 0) return i;
      l.add(v);
      return l.length - 1;
    }

    for (final p in pairs) {
      final key = (idx(origins, p.origin.location), idx(dests, p.destination.location));
      cells.putIfAbsent(key, () => []).add(p.id);
    }
    return MatrixRequest(origins, dests, cells);
  }

  /// Maps raw response elements to per-pair results. Cells the API didn't
  /// return are reported as errors so the UI can show "n/a".
  static Map<String, LegResult> mapResponse(
    MatrixRequest req,
    List<dynamic> elements,
    Map<String, String> routeKeys,
    DateTime now,
  ) {
    final out = <String, LegResult>{};
    for (final raw in elements) {
      if (raw is! Map) continue;
      final e = raw;
      final key = ((e['originIndex'] as int?) ?? 0, (e['destinationIndex'] as int?) ?? 0);
      final ids = req.cells[key];
      if (ids == null) continue; // unneeded cross-product cell
      final status = e['status'] is Map ? e['status'] as Map : null;
      final condition = e['condition'] as String?;
      String? error;
      if (status != null && status['code'] != null && status['code'] != 0) {
        error = (status['message'] as String?) ?? 'Error ${status['code']}';
      } else if (condition != null && condition != 'ROUTE_EXISTS') {
        error = condition == 'ROUTE_NOT_FOUND' ? 'No route' : condition;
      }
      final dur = parseDuration(e['duration'] as String?);
      if (error == null && dur == null) error = 'No route';
      for (final id in ids) {
        out[id] = LegResult(
          durationSec: error == null ? dur : null,
          distanceMeters: error == null ? e['distanceMeters'] as int? : null,
          error: error,
          fetchedAt: now,
          routeKey: routeKeys[id] ?? '',
        );
      }
    }
    req.cells.forEach((_, ids) {
      for (final id in ids) {
        out.putIfAbsent(
          id,
          () => LegResult(error: 'No result', fetchedAt: now, routeKey: routeKeys[id] ?? ''),
        );
      }
    });
    return out;
  }

  /// "123s" / "12.5s" → seconds.
  static int? parseDuration(String? s) {
    if (s == null || !s.endsWith('s')) return null;
    final v = double.tryParse(s.substring(0, s.length - 1));
    return v?.round();
  }
}
