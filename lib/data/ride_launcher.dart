import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/log.dart';
import '../core/models.dart';
import '../core/ride_links.dart';

/// Launches ride apps with sensible fallbacks. Every attempt is logged.
abstract final class RideLauncher {
  static Future<bool> _url(Uri u, String what) async {
    try {
      final ok = await launchUrl(u, mode: LaunchMode.externalApplication);
      AppLog.d('ride', '$what ${ok ? 'launched' : 'not handled'}: ${AppLog.trunc(u.toString(), 140)}');
      return ok;
    } catch (e) {
      AppLog.d('ride', '$what failed ${e.runtimeType}: $e');
      return false;
    }
  }

  static Future<bool> _store(String pkg) async =>
      await _url(RideLinks.market(pkg), 'play store (market)') ||
      await _url(RideLinks.playStore(pkg), 'play store (web)');

  static Future<bool> uber(CommutePair p) async {
    if (await _url(RideLinks.uber(p.origin, p.destination), 'uber link')) return true;
    return _store(RideLinks.uberPackage);
  }

  /// Rapido has no public deep-link API: send a geo: VIEW intent to its
  /// package (drop location), else just open the app, else the Play Store.
  static Future<bool> rapido(CommutePair p) async {
    if (!Platform.isAndroid) return _store(RideLinks.rapidoPackage);
    const pkg = RideLinks.rapidoPackage;
    final geo = RideLinks.geo(p.destination);
    try {
      final view = AndroidIntent(
        action: 'action_view',
        data: geo,
        package: pkg,
        flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      if (await view.canResolveActivity() ?? false) {
        await view.launch();
        AppLog.d('ride', 'rapido geo intent launched: $geo');
        return true;
      }
      AppLog.d('ride', 'rapido geo intent: no handler');
      final main = AndroidIntent(
        action: 'android.intent.action.MAIN',
        category: 'android.intent.category.LAUNCHER',
        package: pkg,
        flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      if (await main.canResolveActivity() ?? false) {
        await main.launch();
        AppLog.d('ride', 'rapido opened via launcher intent');
        return true;
      }
      AppLog.d('ride', 'rapido not installed');
    } catch (e) {
      AppLog.d('ride', 'rapido intent failed ${e.runtimeType}: $e');
    }
    return _store(pkg);
  }
}
