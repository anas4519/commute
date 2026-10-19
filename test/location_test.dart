import 'package:commute/core/models.dart';
import 'package:commute/data/location_service.dart';
import 'package:commute/data/places_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fallback label shows coordinates', () {
    expect(LocationService.fallbackLabel(const LatLng(28.567712, 77.2795)), 'Current location (28.56771, 77.27950)');
  });

  test('parse nearby response', () {
    final n = PlacesClient.parseNearby(
      '{"places":[{"displayName":{"text":" Jamia Nagar ","languageCode":"en"},"formattedAddress":"Okhla, New Delhi"}]}',
    );
    expect(n?.name, 'Jamia Nagar');
    expect(n?.address, 'Okhla, New Delhi');
    expect(PlacesClient.parseNearby('{}'), isNull);
    expect(PlacesClient.parseNearby('{"places":[]}'), isNull);
    expect(PlacesClient.parseNearby('{"places":[{"displayName":{"text":""}}]}'), isNull);
  });
}
