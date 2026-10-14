import 'package:commute/core/coord_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  void expectLL(String s, double lat, double lng) {
    final r = CoordParser.parse(s);
    expect(r, isNotNull, reason: s);
    expect(r!.lat, closeTo(lat, 1e-6));
    expect(r.lng, closeTo(lng, 1e-6));
  }

  test('plain forms', () {
    expectLL('28.6139, 77.2090', 28.6139, 77.2090);
    expectLL('28.6139,77.2090', 28.6139, 77.2090);
    expectLL('  28.6139 77.2090 ', 28.6139, 77.2090);
    expectLL('(28.6139, 77.2090)', 28.6139, 77.2090);
    expectLL('-33.8688, 151.2093', -33.8688, 151.2093);
  });

  test('maps URLs', () {
    expectLL('https://www.google.com/maps/@28.6315,77.2167,15z', 28.6315, 77.2167);
    expectLL('https://maps.google.com/?q=28.6315,77.2167', 28.6315, 77.2167);
    expectLL('https://www.google.com/maps/search/?api=1&query=28.6315%2C77.2167', 28.6315, 77.2167);
    expectLL('https://www.google.com/maps?ll=28.5,77.1&z=10', 28.5, 77.1);
    // Pin (!3d!4d) wins over viewport (@).
    expectLL(
      'https://www.google.com/maps/place/Rajiv+Chowk/@28.6300,77.2100,17z/data=!3m1!4b1!4m6!3m5!1s0x0:0x0!8m2!3d28.6328!4d77.2197',
      28.6328,
      77.2197,
    );
  });

  test('rejects invalid', () {
    expect(CoordParser.parse(''), isNull);
    expect(CoordParser.parse('hello'), isNull);
    expect(CoordParser.parse('95.0, 77.0'), isNull);
    expect(CoordParser.parse('28.6, 190'), isNull);
    expect(CoordParser.parse('https://example.com/@28.6,77.2'), isNull);
  });

  test('short link detection', () {
    expect(CoordParser.isShortMapsLink('https://maps.app.goo.gl/abc123'), isTrue);
    expect(CoordParser.isShortMapsLink('https://www.google.com/maps/@1,2'), isFalse);
  });
}
