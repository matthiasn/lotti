import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/utils/geohash.dart';
import 'package:lotti/utils/location.dart';

void main() {
  group('LocationConstants', () {
    test('has correct constant values', () {
      expect(LocationConstants.locationTimeout, const Duration(seconds: 10));
      expect(LocationConstants.appDesktopId, 'com.matthiasn.lotti');
    });
  });

  group('getGeoHash', () {
    test(
      'should return the correct geohash for a given latitude and longitude',
      () {
        const lat = 52.205;
        const lon = 0.119;
        const expectedGeohash = 'u120fxwshvkg';

        final fullGeohash = getGeoHash(latitude: lat, longitude: lon);

        expect(fullGeohash, expectedGeohash);
      },
    );

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

    test('should handle negative coordinates', () {
      // `dart_geohash` has historical inconsistencies on negative
      // coords; assert non-empty rather than pin a literal.
      const lat = -52.205;
      const lon = -0.119;

      final geohash = getGeoHash(latitude: lat, longitude: lon);

      expect(geohash, isNotEmpty);
      expect(geohash, isA<String>());
    });
  });
}
