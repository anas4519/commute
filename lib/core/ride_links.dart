import 'models.dart';

/// Deep links for ride-hailing apps.
abstract final class RideLinks {
  static const uberPackage = 'com.ubercab';
  static const rapidoPackage = 'com.rapido.passenger';

  static String _enc(String s) => Uri.encodeQueryComponent(s);

  /// Uber universal link (opens the app if installed, else m.uber.com web).
  /// Values are URL-encoded (Dart percent-encodes the [] in keys; servers decode it).
  static Uri uber(Place from, Place to) {
    final q = <String>[
      'action=setPickup',
      'pickup[latitude]=${from.location.lat}',
      'pickup[longitude]=${from.location.lng}',
      'pickup[nickname]=${_enc(from.label)}',
      if (from.address != null && from.address!.isNotEmpty) 'pickup[formatted_address]=${_enc(from.address!)}',
      'dropoff[latitude]=${to.location.lat}',
      'dropoff[longitude]=${to.location.lng}',
      'dropoff[nickname]=${_enc(to.label)}',
      if (to.address != null && to.address!.isNotEmpty) 'dropoff[formatted_address]=${_enc(to.address!)}',
    ];
    return Uri.parse('https://m.uber.com/ul/?${q.join('&')}');
  }

  /// Rapido in-app deep link handled by its exported DeepLinkReceiverActivity
  /// (NavigateToFeDeeplinkHandler → HomeNavigationPayload). Found in v8.130.0:
  /// reads dropLat/dropLng (required) and pickLat/pickLng (optional).
  static Uri rapidoNavigate(Place from, Place to) => Uri(
    scheme: 'rapido',
    host: 'navigate',
    queryParameters: {
      'pickLat': '${from.location.lat}',
      'pickLng': '${from.location.lng}',
      'dropLat': '${to.location.lat}',
      'dropLng': '${to.location.lng}',
    },
  );

  /// geo: URI for the drop location, e.g. `geo:28.6,77.2?q=28.6,77.2(Home)`.
  static String geo(Place to) {
    final ll = '${to.location.lat},${to.location.lng}';
    return 'geo:$ll?q=$ll(${Uri.encodeComponent(to.label)})';
  }

  static Uri playStore(String pkg) => Uri.parse('https://play.google.com/store/apps/details?id=$pkg');
  static Uri market(String pkg) => Uri.parse('market://details?id=$pkg');
}
