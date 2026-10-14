import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../core/log.dart';

/// DNS-over-HTTPS lookup + an HTTP client pinned to the resolved IP.
///
/// Why: some Indian ISPs (Excitel) answer `maps.app.goo.gl` with a block-page
/// IP, so the system resolver sends us to the wrong server (TLS hostname
/// mismatch). DoH bypasses ISP DNS; we then connect to the real IP while
/// still doing TLS with SNI + certificate verification for the real host.
abstract final class Doh {
  /// Endpoints in order. IP-literal ones work even if the DoH hostnames are
  /// themselves blocked/poisoned (their certificates include the IP).
  static const endpoints = <(String, String)>[
    ('dns.google', 'https://dns.google/resolve'),
    ('cloudflare', 'https://cloudflare-dns.com/dns-query'),
    ('8.8.8.8', 'https://8.8.8.8/resolve'),
    ('1.1.1.1', 'https://1.1.1.1/dns-query'),
  ];

  /// IPv4 A records from a DoH JSON answer (Google / Cloudflare format).
  static List<String> parseJson(String body) {
    final j = jsonDecode(body);
    if (j is! Map || j['Status'] != 0) return const [];
    final answers = j['Answer'];
    if (answers is! List) return const [];
    final ip = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$');
    return [
      for (final a in answers)
        if (a is Map && a['type'] == 1 && a['data'] is String && ip.hasMatch(a['data'] as String))
          a['data'] as String,
    ];
  }

  /// Known block-page IPs to reject even if a DoH answer contained them.
  static const _blocked = {'139.5.241.93'};

  static Future<List<String>> lookup(
    String host, {
    http.Client Function()? clientFactory,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    for (final (name, base) in endpoints) {
      final client = (clientFactory ?? () => IOClient(HttpClient()..connectionTimeout = timeout))();
      final sw = Stopwatch()..start();
      try {
        final uri = Uri.parse(base).replace(queryParameters: {'name': host, 'type': 'A'});
        final res = await client.get(uri, headers: {'accept': 'application/dns-json'}).timeout(timeout);
        final ips = res.statusCode == 200
            ? parseJson(res.body).where((ip) => !_blocked.contains(ip)).toList()
            : <String>[];
        AppLog.d(
          'doh',
          '$name $host → ${res.statusCode} ${ips.isEmpty ? 'no A' : ips.join(', ')} '
              'in ${sw.elapsedMilliseconds}ms',
        );
        if (ips.isNotEmpty) return ips;
      } catch (e) {
        AppLog.d('doh', '$name failed ${e.runtimeType}: ${AppLog.trunc('$e', 120)}');
      } finally {
        client.close();
      }
    }
    return const [];
  }

  /// HTTP client that connects to [ip] for requests to [host] (TLS SNI and
  /// certificate verification still use [host]); other hosts connect normally.
  static http.Client pinned(String host, String ip) {
    final hc = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    hc.connectionFactory = (Uri uri, String? proxyHost, int? proxyPort) async {
      final target = uri.host == host ? ip : uri.host;
      final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
      final task = await Socket.startConnect(target, port);
      if (uri.scheme != 'https') return task;
      final secured = task.socket.then((s) => SecureSocket.secure(s, host: uri.host));
      return ConnectionTask.fromSocket(secured, task.cancel);
    };
    return IOClient(hc);
  }
}
