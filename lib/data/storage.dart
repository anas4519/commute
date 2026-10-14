import 'package:shared_preferences/shared_preferences.dart';

import '../core/models.dart';

class Storage {
  Storage(this._p);
  final SharedPreferences _p;
  static Future<Storage> open() async => Storage(await SharedPreferences.getInstance());

  List<CommutePair> loadPairs() {
    final s = _p.getString('pairs');
    if (s == null) return [];
    try {
      return CommutePair.decodeList(s);
    } catch (_) {
      return [];
    }
  }

  Future<void> savePairs(List<CommutePair> l) => _p.setString('pairs', CommutePair.encodeList(l));
  String? loadCache() => _p.getString('cache');
  Future<void> saveCache(String s) => _p.setString('cache', s);

  Set<TravelMode> loadModes() {
    final l = _p.getStringList('modes');
    if (l == null) return {TravelMode.walk, TravelMode.drive, TravelMode.twoWheeler};
    return l.map(TravelMode.byName).whereType<TravelMode>().toSet();
  }

  Future<void> saveModes(Set<TravelMode> m) => _p.setStringList('modes', m.map((e) => e.name).toList());
}
