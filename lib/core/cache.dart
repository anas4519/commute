import 'dart:convert';

import 'models.dart';

/// Per (pair, mode) result cache with mode-specific TTLs.
class ResultCache {
  ResultCache({this.trafficTtl = const Duration(minutes: 3), this.walkTtl = const Duration(hours: 24)});

  final Duration trafficTtl;
  final Duration walkTtl;
  final Map<String, Map<TravelMode, LegResult>> _data = {};

  Duration ttlFor(TravelMode m) => m.trafficAware ? trafficTtl : walkTtl;

  LegResult? get(String pairId, TravelMode m) => _data[pairId]?[m];

  void put(String pairId, TravelMode m, LegResult r) => (_data[pairId] ??= {})[m] = r;

  /// Fresh = exists, matches current endpoints, succeeded, within TTL.
  /// Errors are retried on next refresh (but cheaply: only those cells).
  bool isFresh(CommutePair p, TravelMode m, DateTime now) {
    final r = get(p.id, m);
    if (r == null || r.routeKey != p.routeKey || !r.ok) return false;
    return now.difference(r.fetchedAt) < ttlFor(m);
  }

  /// Pairs that need fetching for [m]. [force] ignores TTL for traffic modes
  /// (walking stays cached: it doesn't change with traffic).
  List<CommutePair> stale(List<CommutePair> pairs, TravelMode m, DateTime now, {bool force = false}) =>
      pairs.where((p) {
        if (force && m.trafficAware) return true;
        return !isFresh(p, m, now);
      }).toList();

  void retainOnly(Iterable<String> ids) {
    final keep = ids.toSet();
    _data.removeWhere((k, _) => !keep.contains(k));
  }

  DateTime? lastUpdated(Iterable<String> ids) {
    DateTime? best;
    for (final id in ids) {
      for (final r in (_data[id] ?? const {}).values) {
        if (r.ok && (best == null || r.fetchedAt.isAfter(best))) best = r.fetchedAt;
      }
    }
    return best;
  }

  String encode() =>
      jsonEncode(_data.map((id, modes) => MapEntry(id, modes.map((m, r) => MapEntry(m.name, r.toJson())))));

  void decode(String s) {
    _data.clear();
    try {
      final j = jsonDecode(s) as Map<String, dynamic>;
      j.forEach((id, modes) {
        (modes as Map<String, dynamic>).forEach((name, r) {
          final m = TravelMode.byName(name);
          if (m != null) put(id, m, LegResult.fromJson(r as Map<String, dynamic>));
        });
      });
    } catch (_) {
      _data.clear(); // corrupt cache: just refetch
    }
  }
}
