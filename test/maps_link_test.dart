import 'package:commute/core/maps_link.dart';
import 'package:commute/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('directions uri', () {
    final u = mapsDirectionsUri(
      const LatLng(28.6, 77.2),
      const LatLng(28.63, 77.22),
      mode: TravelMode.twoWheeler,
    );
    expect(u.host, 'www.google.com');
    expect(u.path, '/maps/dir/');
    expect(u.queryParameters['api'], '1');
    expect(u.queryParameters['origin'], '28.6,77.2');
    expect(u.queryParameters['destination'], '28.63,77.22');
    expect(u.queryParameters['travelmode'], 'two-wheeler');
    expect(
      mapsDirectionsUri(const LatLng(1, 2), const LatLng(3, 4)).queryParameters.containsKey('travelmode'),
      isFalse,
    );
  });
}
