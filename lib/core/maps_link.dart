import 'models.dart';

/// Google Maps directions URL (Maps URLs API). Opens the Maps app on Android.
Uri mapsDirectionsUri(LatLng origin, LatLng destination, {TravelMode? mode}) =>
    Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'origin': '${origin.lat},${origin.lng}',
      'destination': '${destination.lat},${destination.lng}',
      if (mode != null)
        'travelmode': switch (mode) {
          TravelMode.walk => 'walking',
          TravelMode.drive => 'driving',
          TravelMode.twoWheeler => 'two-wheeler',
          TravelMode.bicycle => 'bicycling',
        },
    });
