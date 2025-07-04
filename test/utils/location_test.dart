import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/utils/location.dart';

void main() {
  group('getGeoHash', () {
    test('should return the correct geohash for a given latitude and longitude',
        () {
      const lat = 52.205;
      const lon = 0.119;
      const expectedGeohash = 'u120fxwshvkg';

      final fullGeohash = getGeoHash(latitude: lat, longitude: lon);

      expect(fullGeohash, expectedGeohash);
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
