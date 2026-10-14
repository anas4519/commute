import 'package:commute/core/link_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('extractFirstUrl', () {
    test('share text with name + newline', () {
      expect(
        LinkUtils.extractFirstUrl('Rajiv Chowk Metro\nhttps://maps.app.goo.gl/AbC123?g_st=aw'),
        'https://maps.app.goo.gl/AbC123?g_st=aw',
      );
    });
    test('url in prose with trailing punctuation', () {
      expect(LinkUtils.extractFirstUrl('see (https://maps.app.goo.gl/x1).'), 'https://maps.app.goo.gl/x1');
    });
    test('bare url / none', () {
      expect(LinkUtils.extractFirstUrl(' https://goo.gl/maps/q '), 'https://goo.gl/maps/q');
      expect(LinkUtils.extractFirstUrl('28.6, 77.2'), isNull);
    });
  });

  group('unwrapConsent', () {
    test('returns continue param', () {
      const real = 'https://www.google.com/maps/place/X/@28.6,77.2,17z';
      final c = 'https://consent.google.com/m?continue=${Uri.encodeComponent(real)}&gl=IN&hl=en';
      expect(LinkUtils.unwrapConsent(c), real);
    });
    test('non-consent untouched', () {
      expect(LinkUtils.unwrapConsent('https://www.google.com/maps'), 'https://www.google.com/maps');
      expect(
        LinkUtils.unwrapConsent('https://consent.google.com/m?gl=IN'),
        'https://consent.google.com/m?gl=IN',
      );
    });
  });

  test('fromIntent uses browser_fallback_url', () {
    final fb = Uri.encodeComponent('https://www.google.com/maps/@28.6,77.2,15z');
    expect(
      LinkUtils.fromIntent('intent://maps/x#Intent;scheme=https;S.browser_fallback_url=$fb;end'),
      'https://www.google.com/maps/@28.6,77.2,15z',
    );
    expect(
      LinkUtils.fromIntent('intent://www.google.com/maps/@1.5,2.5,3z#Intent;scheme=https;end'),
      'https://www.google.com/maps/@1.5,2.5,3z',
    );
    expect(LinkUtils.fromIntent('https://a.b'), 'https://a.b');
  });

  test('coordsFromHtml: og:image staticmap and inline state', () {
    const og =
        '<meta content="https://maps.google.com/maps/api/staticmap?center=28.6328%2C77.2197&amp;zoom=15" property="og:image">';
    final a = LinkUtils.coordsFromHtml(og)!;
    expect(a.lat, 28.6328);
    expect(a.lng, 77.2197);
    final b = LinkUtils.coordsFromHtml('foo [null,null,12.914,77.628] bar')!;
    expect(b.lat, 12.914);
    expect(LinkUtils.coordsFromHtml('<html>nothing</html>'), isNull);
  });
}
