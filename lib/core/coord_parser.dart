import 'models.dart';

/// Parses pasted coordinates or Google Maps URLs into a [LatLng].
/// Returns null when nothing valid is found.
///
/// Supported:
///  - "28.6139, 77.2090", "28.6139 77.2090", "28.6139,77.2090"
///  - URLs with `!3dLAT!4dLNG` (place pin, preferred), `@LAT,LNG,zoom`,
///    `q=`/`query=`/`ll=`/`destination=`/`center=` `LAT,LNG`
///  - Short links (maps.app.goo.gl) must be resolved first; see [isShortMapsLink].
class CoordParser {
  static final _num = r'(-?\d{1,3}(?:\.\d+)?)';
  static final _plain = RegExp('^\\s*\\(?$_num\\s*[, ]\\s*$_num\\)?\\s*\$');
  static final _pin = RegExp('!3d$_num!4d$_num');
  static final _at = RegExp('@$_num,$_num');
  static final _query = RegExp(
    '[?&](?:q|query|ll|destination|center|daddr|saddr)=(?:loc:)?$_num(?:,|%2C|\\+|%20)+$_num',
    caseSensitive: false,
  );

  static LatLng? parse(String input) {
    final s = input.trim();
    if (s.isEmpty) return null;

    final plain = _plain.firstMatch(s);
    if (plain != null) return _valid(plain.group(1)!, plain.group(2)!);

    if (!s.contains('google') && !s.contains('goo.gl') && !s.contains('maps')) return null;
    // Order matters: the pin marker is the actual place; @ is the viewport centre.
    for (final re in [_pin, _query, _at]) {
      final m = re.firstMatch(s);
      if (m != null) {
        final r = _valid(m.group(1)!, m.group(2)!);
        if (r != null) return r;
      }
    }
    return null;
  }

  static bool isShortMapsLink(String s) => RegExp(
    r'^https?://(maps\.app\.goo\.gl|goo\.gl/maps|g\.co/kgs)/',
    caseSensitive: false,
  ).hasMatch(s.trim());

  static LatLng? _valid(String a, String b) {
    final lat = double.tryParse(a), lng = double.tryParse(b);
    if (lat == null || lng == null) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    return LatLng(lat, lng);
  }
}
