import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../core/log.dart';
import '../core/models.dart';

enum LocationFix { none, locationSettings, appSettings }

class LocationFailure implements Exception {
  final String message;
  final LocationFix fix;
  const LocationFailure(this.message, {this.fix = LocationFix.none});
  @override
  String toString() => message;
}

/// Current device position with permission / GPS-off handling.
abstract final class LocationService {
  static String fallbackLabel(LatLng ll) =>
      'Current location (${ll.lat.toStringAsFixed(5)}, ${ll.lng.toStringAsFixed(5)})';

  static Future<LatLng> current() async {
    final sw = Stopwatch()..start();
    if (!await Geolocator.isLocationServiceEnabled()) {
      AppLog.d('location', 'services disabled');
      throw const LocationFailure(
        'Location is turned off. Turn it on and try again.',
        fix: LocationFix.locationSettings,
      );
    }
    var perm = await Geolocator.checkPermission();
    AppLog.d('location', 'permission $perm');
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      AppLog.d('location', 'requested → $perm');
    }
    if (perm == LocationPermission.deniedForever) {
      throw const LocationFailure(
        'Location permission is blocked. Allow it in app settings.',
        fix: LocationFix.appSettings,
      );
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.unableToDetermine) {
      throw const LocationFailure('Location permission denied.');
    }
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
      );
      AppLog.d('location', 'fix ±${p.accuracy.round()} m in ${sw.elapsedMilliseconds}ms');
      return LatLng(p.latitude, p.longitude);
    } on TimeoutException {
      final last = await Geolocator.getLastKnownPosition();
      AppLog.d('location', 'fix timed out; last known ${last == null ? 'none' : 'used'}');
      if (last != null) return LatLng(last.latitude, last.longitude);
      throw const LocationFailure("Couldn't get a GPS fix. Try again near a window or outdoors.");
    } on LocationServiceDisabledException {
      throw const LocationFailure(
        'Location is turned off. Turn it on and try again.',
        fix: LocationFix.locationSettings,
      );
    } on PermissionDeniedException {
      throw const LocationFailure('Location permission denied.');
    } catch (e) {
      AppLog.d('location', 'failed ${e.runtimeType}: $e');
      throw LocationFailure("Couldn't get your location ($e).");
    }
  }

  static Future<void> openFix(LocationFix f) async {
    switch (f) {
      case LocationFix.locationSettings:
        await Geolocator.openLocationSettings();
      case LocationFix.appSettings:
        await Geolocator.openAppSettings();
      case LocationFix.none:
        break;
    }
  }
}
