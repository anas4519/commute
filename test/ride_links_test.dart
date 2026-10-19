import 'package:commute/core/models.dart';
import 'package:commute/core/ride_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const home = Place(label: 'Home & Co', location: LatLng(28.5677, 77.2795), address: 'Okhla, New Delhi');
  const metro = Place(label: 'Jamia Millia Islamia', location: LatLng(28.5616, 77.2803));

  test('uber universal link', () {
    final u = RideLinks.uber(home, metro);
    expect(u.host, 'm.uber.com');
    expect(u.path, '/ul/');
    final q = u.queryParameters;
    expect(q['action'], 'setPickup');
    expect(q['pickup[latitude]'], '28.5677');
    expect(q['pickup[longitude]'], '77.2795');
    expect(q['pickup[nickname]'], 'Home & Co');
    expect(q['pickup[formatted_address]'], 'Okhla, New Delhi');
    expect(q['dropoff[latitude]'], '28.5616');
    expect(q['dropoff[longitude]'], '77.2803');
    expect(q['dropoff[nickname]'], 'Jamia Millia Islamia');
    expect(q.containsKey('dropoff[formatted_address]'), isFalse);
  });

  test('rapido geo uri and store links', () {
    expect(RideLinks.geo(metro), 'geo:28.5616,77.2803?q=28.5616,77.2803(Jamia%20Millia%20Islamia)');
    expect(
      RideLinks.playStore(RideLinks.rapidoPackage).toString(),
      'https://play.google.com/store/apps/details?id=com.rapido.passenger',
    );
    expect(RideLinks.market('x').toString(), 'market://details?id=x');
  });

  test('rapido navigate deep link carries pickup and drop', () {
    final u = RideLinks.rapidoNavigate(home, metro);
    expect(u.scheme, 'rapido');
    expect(u.host, 'navigate');
    expect(u.queryParameters, {'pickLat': '28.5677', 'pickLng': '77.2795', 'dropLat': '28.5616', 'dropLng': '77.2803'});
    expect(u.toString(), 'rapido://navigate?pickLat=28.5677&pickLng=77.2795&dropLat=28.5616&dropLng=77.2803');
  });
}
