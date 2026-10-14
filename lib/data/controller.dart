import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/cache.dart';
import '../core/matrix_planner.dart';
import '../core/models.dart';
import 'config.dart';
import 'routes_client.dart';
import 'storage.dart';

class CommuteController extends ChangeNotifier {
  CommuteController(this._storage, this._routes) {
    pairs = _storage.loadPairs();
    modes = _storage.loadModes();
    final c = _storage.loadCache();
    if (c != null) cache.decode(c);
  }

  final Storage _storage;
  final RoutesClient _routes;
  final cache = ResultCache();
  late List<CommutePair> pairs;
  late Set<TravelMode> modes;
  bool loading = false;
  String? banner; // whole-request problem (offline, key, etc.)
  DateTime? _lastForced;

  List<TravelMode> get orderedModes => TravelMode.values.where(modes.contains).toList();
  DateTime? get lastUpdated => cache.lastUpdated(pairs.map((p) => p.id));

  /// Fastest successful mode for a pair, if any.
  TravelMode? bestFor(CommutePair p) {
    TravelMode? best;
    int? bestSec;
    for (final m in orderedModes) {
      final r = cache.get(p.id, m);
      if (r == null || !r.ok || r.routeKey != p.routeKey) continue;
      if (bestSec == null || r.durationSec! < bestSec) {
        best = m;
        bestSec = r.durationSec;
      }
    }
    return best;
  }

  Future<void> refresh({bool force = false}) async {
    if (loading || pairs.isEmpty) return;
    final now = DateTime.now();
    if (force && _lastForced != null && now.difference(_lastForced!) < const Duration(seconds: 30)) {
      force = false; // debounce manual refresh; still fetches anything stale
    }
    if (force) _lastForced = now;
    if (!AppConfig.hasKey) {
      banner = 'No API key. Run with --dart-define-from-file=env/keys.json';
      notifyListeners();
      return;
    }
    loading = true;
    banner = null;
    notifyListeners();

    final routeKeys = {for (final p in pairs) p.id: p.routeKey};
    final errors = <String>{};
    await Future.wait(
      orderedModes.map((mode) async {
        final stale = cache.stale(pairs, mode, now, force: force);
        for (final req in MatrixPlanner.plan(stale)) {
          try {
            final els = await _routes.matrix(req, mode);
            MatrixPlanner.mapResponse(
              req,
              els,
              routeKeys,
              DateTime.now(),
            ).forEach((id, r) => cache.put(id, mode, r));
          } on SocketException {
            errors.add('Offline, showing last results');
          } on TimeoutException {
            errors.add('Request timed out');
          } on ApiException catch (e) {
            errors.add(e.message);
            // Mark cells failed only if we have nothing to show.
            for (final ids in req.cells.values) {
              for (final id in ids) {
                if (cache.get(id, mode) == null) {
                  cache.put(id, mode, LegResult(error: 'Failed', fetchedAt: now, routeKey: routeKeys[id]!));
                }
              }
            }
          } catch (e) {
            errors.add('Error: $e');
          }
        }
      }),
    );

    banner = errors.isEmpty ? null : errors.join('\n');
    loading = false;
    await _storage.saveCache(cache.encode());
    notifyListeners();
  }

  Future<void> upsert({String? id, required String name, required Place origin, required Place dest}) async {
    final i = pairs.indexWhere((p) => p.id == id);
    if (i >= 0) {
      pairs[i] = pairs[i].copyWith(name: name, origin: origin, destination: dest);
    } else {
      pairs.add(CommutePair(id: const Uuid().v4(), name: name, origin: origin, destination: dest));
    }
    await _persist();
    unawaited(refresh());
  }

  Future<void> remove(String id) async {
    pairs.removeWhere((p) => p.id == id);
    cache.retainOnly(pairs.map((p) => p.id));
    await _persist();
  }

  Future<void> insertAt(int index, CommutePair p) async {
    pairs.insert(index.clamp(0, pairs.length), p);
    await _persist();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    pairs.insert(newIndex, pairs.removeAt(oldIndex));
    await _persist();
  }

  Future<void> toggleMode(TravelMode m, bool on) async {
    on ? modes.add(m) : modes.remove(m);
    if (modes.isEmpty) modes.add(TravelMode.drive);
    await _storage.saveModes(modes);
    notifyListeners();
    unawaited(refresh());
  }

  Future<void> _persist() async {
    await _storage.savePairs(pairs);
    notifyListeners();
  }
}
