import 'coord_parser.dart';
import 'models.dart';

/// Helpers for turning pasted share text / redirect chains into coordinates.
abstract final class LinkUtils {
  static final _url = RegExp(r'''(https?://|intent://)[^\s<>"']+''', caseSensitive: false);

  /// First URL in arbitrary pasted text, e.g. "Rajiv Chowk\nhttps://maps.app.goo.gl/abc".
  /// Trailing punctuation from prose is trimmed.
  static String? extractFirstUrl(String text) {
    final m = _url.firstMatch(text);
    if (m == null) return null;
    return m.group(0)!.replaceFirst(RegExp(r'[).,;!?\]]+$'), '');
  }

  /// `consent.google.com/...?continue=URL` → `URL` (else unchanged).
  static String unwrapConsent(String url) {
    final u = Uri.tryParse(url);
    if (u == null || !u.host.startsWith('consent.')) return url;
    final cont = u.queryParameters['continue'];
    return (cont != null && cont.isNotEmpty) ? cont : url;
  }

  /// `intent://...#Intent;...;S.browser_fallback_url=ENC;end` → https URL.
  /// Also maps `intent://` paths back to https://.
  static String? fromIntent(String url) {
    if (!url.toLowerCase().startsWith('intent://')) return url;
    final fb = RegExp(r'S\.browser_fallback_url=([^;]+)').firstMatch(url);
    if (fb != null) return Uri.decodeComponent(fb.group(1)!);
    final hash = url.indexOf('#Intent');
    final path = url.substring('intent://'.length, hash < 0 ? url.length : hash);
    return 'https://$path';
  }

  static final _htmlPatterns = <RegExp>[
    RegExp(r'!3d(-?\d{1,3}\.\d+)!4d(-?\d{1,3}\.\d+)'),
    RegExp(r'center=(-?\d{1,3}\.\d+)(?:%2C|,)(-?\d{1,3}\.\d+)', caseSensitive: false),
    RegExp(r'markers=(-?\d{1,3}\.\d+)(?:%2C|,)(-?\d{1,3}\.\d+)', caseSensitive: false),
    RegExp(r'@(-?\d{1,3}\.\d+),(-?\d{1,3}\.\d+)'),
    RegExp(r'\[null,null,(-?\d{1,3}\.\d+),(-?\d{1,3}\.\d+)\]'),
  ];

  /// Last-resort coordinate scrape from a Maps HTML page (og:image static map,
  /// canonical/link URLs, embedded APP_INITIALIZATION_STATE).
  static LatLng? coordsFromHtml(String html) {
    final metaUrl = RegExp(
      r'''<meta[^>]+content="([^"]*(?:staticmap|maps)[^"]*)"''',
      caseSensitive: false,
    ).allMatches(html).map((m) => m.group(1)!.replaceAll('&amp;', '&'));
    for (final candidate in [...metaUrl, html]) {
      for (final re in _htmlPatterns) {
        for (final m in re.allMatches(candidate)) {
          final lat = double.tryParse(m.group(1)!), lng = double.tryParse(m.group(2)!);
          if (lat != null && lng != null && lat.abs() <= 90 && lng.abs() <= 180 && !(lat == 0 && lng == 0)) {
            return LatLng(lat, lng);
          }
        }
      }
    }
    return null;
  }

  /// Coordinates directly from a URL, if present.
  static LatLng? coordsFromUrl(String url) => CoordParser.parse(url);
}
