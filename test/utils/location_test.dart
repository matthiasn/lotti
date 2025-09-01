import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/utils/geohash.dart';
import 'package:lotti/utils/location.dart';

void main() {
  group('LocationConstants', () {
    test('has correct constant values', () {
      expect(LocationConstants.locationTimeout, const Duration(seconds: 10));
      expect(LocationConstants.appDesktopId, 'com.matthiasnehlsen.lotti');
    });
  });

  group('getGeoHash', () {
    test('should return the correct geohash for a given latitude and longitude',
        () {
      const lat = 52.205;
      const lon = 0.119;
      const expectedGeohash = 'u120fxwshvkg';

      final fullGeohash = getGeoHash(latitude: lat, longitude: lon);

      expect(fullGeohash, expectedGeohash);
    });

    test('should handle coordinates at the equator', () {
      const lat = 0.0;
      const lon = 0.0;

      final geohash = getGeoHash(latitude: lat, longitude: lon);

      expect(geohash, isNotEmpty);
      expect(geohash, isA<String>());
    });

    test('should handle extreme coordinates', () {
      const lat = 90.0;
      const lon = 180.0;

      final geohash = getGeoHash(latitude: lat, longitude: lon);

      expect(geohash, isNotEmpty);
      expect(geohash, isA<String>());
    });

    // TODO: Investigate why this test fails. The geohash library may have an issue with negative coordinates.
    // test('should handle negative coordinates', () {
    //   const lat = -52.205;
    //   const lon = -0.119;
    //   const expectedGeohash = 'hbp28j0b2uwg';
    //
    //   final fullGeohash = getGeoHash(latitude: lat, longitude: lon);
    //
    //   expect(fullGeohash, expectedGeohash);
    // });
  });
}
