import 'dart:async';

import 'package:webview_flutter/webview_flutter.dart';

import '../core/link_utils.dart';
import '../core/log.dart';
import '../core/models.dart';

/// Last-resort short-link resolver: loads the link in a (tiny, invisible)
/// WebView, which uses Android's WebView/Chromium stack, and watches URL
/// changes until one carries coordinates.
class WebLinkResolver {
  WebLinkResolver() : controller = WebViewController();
  final WebViewController controller;
  Completer<LatLng?>? _done;

  void _check(String? url, String via) {
    if (url == null || _done == null || _done!.isCompleted) return;
    var u = url;
    if (u.toLowerCase().startsWith('intent://')) u = LinkUtils.fromIntent(u) ?? u;
    u = LinkUtils.unwrapConsent(u);
    final ll = LinkUtils.coordsFromUrl(u);
    AppLog.d('web', '$via ${AppLog.trunc(u, 140)}${ll != null ? ' → $ll' : ''}');
    if (ll != null) _done!.complete(ll);
  }

  Future<LatLng?> resolve(String url, {Duration limit = const Duration(seconds: 20)}) async {
    final done = _done = Completer<LatLng?>();
    final sw = Stopwatch()..start();
    AppLog.d('web', 'start ${AppLog.trunc(url)}');
    try {
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (req) {
            _check(req.url, 'nav');
            final lower = req.url.toLowerCase();
            if (done.isCompleted || !(lower.startsWith('http://') || lower.startsWith('https://'))) {
              return NavigationDecision.prevent; // app links / intent:// handled above
            }
            return NavigationDecision.navigate;
          },
          onPageStarted: (u) => _check(u, 'started'),
          onUrlChange: (c) => _check(c.url, 'urlchange'),
          onPageFinished: (u) async {
            _check(u, 'finished');
            if (done.isCompleted) return;
            // Maps updates the URL via JS; also scrape the DOM once.
            await Future<void>.delayed(const Duration(milliseconds: 1500));
            if (done.isCompleted) return;
            try {
              final href = await controller.runJavaScriptReturningResult('location.href');
              _check('$href'.replaceAll('"', ''), 'href');
              if (done.isCompleted) return;
              final html = await controller.runJavaScriptReturningResult(
                'document.documentElement.outerHTML.slice(0, 600000)',
              );
              final ll = LinkUtils.coordsFromHtml('$html'.replaceAll(r'\u003C', '<').replaceAll(r'\"', '"'));
              AppLog.d('web', 'dom scrape ${ll ?? 'no coords'}');
              if (ll != null && !done.isCompleted) done.complete(ll);
            } catch (e) {
              AppLog.d('web', 'js failed ${e.runtimeType}: $e');
            }
          },
          onWebResourceError: (e) => AppLog.d(
            'web',
            'error ${e.errorCode} ${e.errorType} ${e.description} main=${e.isForMainFrame}',
          ),
        ),
      );
      await controller.loadRequest(Uri.parse(url));
      final r = await done.future.timeout(
        limit,
        onTimeout: () {
          AppLog.d('web', 'timeout after ${limit.inSeconds}s');
          return null;
        },
      );
      AppLog.d('web', r != null ? 'OK $r in ${sw.elapsedMilliseconds}ms' : 'failed');
      return r;
    } catch (e) {
      AppLog.d('web', 'exception ${e.runtimeType}: $e');
      return null;
    } finally {
      if (!done.isCompleted) done.complete(null);
      unawaited(controller.loadRequest(Uri.parse('about:blank')).catchError((_) {}));
    }
  }
}
