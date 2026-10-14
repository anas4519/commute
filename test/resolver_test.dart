import 'dart:async';

import 'package:commute/data/places_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// Fake client: responds per-URL with a status/location and a body stream that
/// may never finish.
class FakeClient extends http.BaseClient {
  FakeClient(this.handler);
  final http.StreamedResponse Function(http.BaseRequest) handler;
  bool closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async => handler(request);
  @override
  void close() => closed = true;
}

Stream<List<int>> neverEnding([List<int>? first]) {
  final c = StreamController<List<int>>();
  if (first != null) c.add(first);
  return c.stream; // never closed
}

void main() {
  PlacesClient mk(FakeClient f, {Duration deadline = const Duration(seconds: 3)}) => PlacesClient(
    resolverClient: () => f,
    hopTimeout: const Duration(milliseconds: 500),
    bodyTimeout: const Duration(milliseconds: 500),
    deadline: deadline,
  );

  test('302 with coords returns even if the 302 body never ends', () async {
    final f = FakeClient(
      (r) => http.StreamedResponse(
        neverEnding(),
        302,
        headers: {'location': 'https://www.google.com/maps/place/X/@28.6,77.2,17z/data=!3d28.63!4d77.22'},
      ),
    );
    final r = await mk(f).resolveShortLink('https://maps.app.goo.gl/abc');
    expect(r.location?.lat, 28.63);
    expect(f.closed, isTrue);
  });

  test('200 with never-ending body and no coords → error within deadline', () async {
    final f = FakeClient(
      (r) => r.url.host == 'maps.app.goo.gl'
          ? http.StreamedResponse(
              const Stream.empty(),
              302,
              headers: {'location': 'https://www.google.com/maps/place/X'},
            )
          : http.StreamedResponse(neverEnding('<html>'.codeUnits), 200),
    );
    final sw = Stopwatch()..start();
    final r = await mk(f).resolveShortLink('https://maps.app.goo.gl/abc');
    expect(r.location, isNull);
    expect(r.error, isNotNull);
    expect(sw.elapsed, lessThan(const Duration(seconds: 3)));
  });

  test('200 never-ending body but coords in streamed html are found after body timeout', () async {
    final f = FakeClient(
      (r) => r.url.host == 'maps.app.goo.gl'
          ? http.StreamedResponse(
              const Stream.empty(),
              302,
              headers: {'location': 'https://www.google.com/maps/place/X'},
            )
          : http.StreamedResponse(neverEnding('x [null,null,28.61,77.21] y'.codeUnits), 200),
    );
    final r = await mk(f).resolveShortLink('https://maps.app.goo.gl/abc');
    expect(r.location?.lng, 77.21);
  });

  test('send that never completes → overall deadline / hop timeout', () async {
    final f = FakeClient((r) => throw UnimplementedError());
    final hang = _HangClient();
    final sw = Stopwatch()..start();
    final r = await PlacesClient(
      resolverClient: () => hang,
      hopTimeout: const Duration(seconds: 10),
      deadline: const Duration(milliseconds: 700),
    ).resolveShortLink('https://maps.app.goo.gl/abc');
    expect(r.error, 'Timed out');
    expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
    expect(hang.closed, isTrue);
    expect(f.closed, isFalse);
  });

  test('redirect loop detected', () async {
    final f = FakeClient(
      (r) => http.StreamedResponse(
        const Stream.empty(),
        302,
        headers: {'location': r.url.path == '/a' ? 'https://x.example/b' : 'https://x.example/a'},
      ),
    );
    final r = await mk(f).resolveShortLink('https://x.example/a');
    expect(r.error, 'Redirect loop');
  });
}

class _HangClient extends http.BaseClient {
  bool closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => Completer<http.StreamedResponse>().future;
  @override
  void close() => closed = true;
}
