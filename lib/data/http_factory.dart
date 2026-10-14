import 'dart:async';
import 'dart:io';

import 'package:cronet_http/cronet_http.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../core/log.dart';

/// HTTP clients. On Android we prefer Cronet (Android/Chromium network stack:
/// system DNS, Chromium TLS/cert store) over dart:io, which failed on a real
/// device with a TLS hostname mismatch for maps.app.goo.gl.
abstract final class HttpFactory {
  static CronetEngine? _engine;
  static bool _cronetFailed = false;

  static CronetEngine? _cronet() {
    if (!Platform.isAndroid || _cronetFailed) return null;
    try {
      return _engine ??= CronetEngine.build(
        cacheMode: CacheMode.disabled,
        enableHttp2: true,
        enableQuic: true,
      );
    } catch (e) {
      _cronetFailed = true;
      AppLog.d('http', 'Cronet unavailable (${e.runtimeType}: $e), using dart:io');
      return null;
    }
  }

  /// Native (Cronet) client if available, else null.
  static http.Client? native() {
    final e = _cronet();
    return e == null ? null : CronetClient.fromCronetEngine(e);
  }

  /// dart:io client with sane connect timeout.
  static http.Client io() => IOClient(HttpClient()..connectionTimeout = const Duration(seconds: 8));

  /// Preferred general client for API calls.
  static http.Client preferred() {
    final n = native();
    AppLog.d('http', 'API client: ${n != null ? 'cronet' : 'dart:io'}');
    return n ?? io();
  }

  /// Logs DNS answers for diagnosis (never throws, never blocks callers).
  static void logDns(String host) {
    unawaited(
      InternetAddress.lookup(host).timeout(const Duration(seconds: 3)).then((list) {
        AppLog.d(
          'dns',
          '$host → ${list.map((a) => '${a.type == InternetAddressType.IPv6 ? 'v6' : 'v4'}:${a.address}').join(', ')}',
        );
      }, onError: (Object e) => AppLog.d('dns', '$host lookup failed ${e.runtimeType}: $e')),
    );
  }
}
