import 'package:commute/data/doh.dart';
import 'package:commute/data/places_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('parses Google/Cloudflare DoH JSON, A records only', () {
    const body =
        '{"Status":0,"Answer":['
        '{"name":"maps.app.goo.gl.","type":5,"data":"x.google.com."},'
        '{"name":"maps.app.goo.gl.","type":1,"TTL":300,"data":"142.251.12.101"},'
        '{"name":"maps.app.goo.gl.","type":1,"TTL":300,"data":"142.251.12.139"},'
        '{"name":"maps.app.goo.gl.","type":28,"data":"2404:6800::1"}]}';
    expect(Doh.parseJson(body), ['142.251.12.101', '142.251.12.139']);
    expect(Doh.parseJson('{"Status":3}'), isEmpty); // NXDOMAIN
    expect(Doh.parseJson('{"Status":0}'), isEmpty);
  });

  test('lookup falls through endpoints and rejects block-page IP', () async {
    final hits = <String>[];
    final ips = await Doh.lookup(
      'maps.app.goo.gl',
      clientFactory: () => MockClient((req) async {
        hits.add(req.url.host);
        expect(req.url.queryParameters['name'], 'maps.app.goo.gl');
        expect(req.headers['accept'], 'application/dns-json');
        if (req.url.host == 'dns.google') throw http.ClientException('blocked');
        if (req.url.host == 'cloudflare-dns.com') {
          return http.Response('{"Status":0,"Answer":[{"type":1,"data":"139.5.241.93"}]}', 200);
        }
        return http.Response('{"Status":0,"Answer":[{"type":1,"data":"142.251.12.101"}]}', 200);
      }),
    );
    expect(ips, ['142.251.12.101']);
    expect(hits, ['dns.google', 'cloudflare-dns.com', '8.8.8.8']);
  });

  test('default resolver order is doh → cronet → dart:io', () {
    expect(PlacesClient.defaultPaths.map((p) => p.$1).toList(), ['doh', 'cronet', 'dart:io']);
  });
}
