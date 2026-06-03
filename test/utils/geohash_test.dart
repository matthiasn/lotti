import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/utils/geohash.dart';

/// The complete set of characters a GeoHasher (base-32) hash can contain.
/// Derived from dart_geohash's internal `_baseSequence`.
const _base32Chars = '0123456789bcdefghjkmnpqrstuvwxyz';

extension _AnyGeoHash on glados.Any {
  /// Generates a latitude in [−90, 90). Both bounds are valid for encode().
  glados.Generator<double> get latitude =>
      glados.DoubleAnys(this).doubleInRange(-90, 90);

  /// Generates a longitude in [−180, 180). Both bounds are valid for encode().
  glados.Generator<double> get longitude =>
      glados.DoubleAnys(this).doubleInRange(-180, 180);
}

void main() {
  // ---------------------------------------------------------------------------
  // Static worked examples
  // ---------------------------------------------------------------------------
  group('getGeoHash — worked examples', () {
    test('Cambridge, UK encodes to known 12-char hash', () {
      // Derived from the existing location_test.dart value.
      expect(
        getGeoHash(latitude: 52.205, longitude: 0.119),
        'u120fxwshvkg',
      );
    });

    test('origin (0, 0) produces a 12-character hash', () {
      final result = getGeoHash(latitude: 0, longitude: 0);
      expect(result.length, 12, reason: 'default precision is 12');
    });

    test('origin (0, 0) hash contains only base-32 characters', () {
      final result = getGeoHash(latitude: 0, longitude: 0);
      for (final ch in result.split('')) {
        expect(
          _base32Chars.contains(ch),
          isTrue,
          reason: 'unexpected char "$ch" in "$result"',
        );
      }
    });

    test('encoding is deterministic — same input gives same output', () {
      const lat = 48.8566;
      const lon = 2.3522;
      final first = getGeoHash(latitude: lat, longitude: lon);
      final second = getGeoHash(latitude: lat, longitude: lon);
      expect(first, second, reason: 'encode must be deterministic');
    });

    test('sufficiently distant locations produce different hashes', () {
      // Sydney vs New York — distance > 16 000 km.
      final sydney = getGeoHash(latitude: -33.87, longitude: 151.21);
      final newYork = getGeoHash(latitude: 40.71, longitude: -74.01);
      expect(sydney, isNot(newYork));
    });
  });

  // ---------------------------------------------------------------------------
  // Glados property tests
  // ---------------------------------------------------------------------------
  group('getGeoHash — properties', () {
    glados.Glados2(
      glados.any.latitude,
      glados.any.longitude,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'output is always exactly 12 characters for any valid coordinate',
      (lat, lon) {
        final result = getGeoHash(latitude: lat, longitude: lon);
        expect(
          result.length,
          12,
          reason: 'lat=$lat, lon=$lon → "$result"',
        );
      },
      tags: 'glados',
    );

    glados.Glados2(
      glados.any.latitude,
      glados.any.longitude,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'output contains only base-32 characters',
      (lat, lon) {
        final result = getGeoHash(latitude: lat, longitude: lon);
        for (final ch in result.split('')) {
          expect(
            _base32Chars.contains(ch),
            isTrue,
            reason: 'lat=$lat, lon=$lon → "$result" has unexpected char "$ch"',
          );
        }
      },
      tags: 'glados',
    );

    glados.Glados2(
      glados.any.latitude,
      glados.any.longitude,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'encoding is deterministic — calling twice returns the same hash',
      (lat, lon) {
        final first = getGeoHash(latitude: lat, longitude: lon);
        final second = getGeoHash(latitude: lat, longitude: lon);
        expect(first, second, reason: 'lat=$lat, lon=$lon');
      },
      tags: 'glados',
    );

    // Prefix-stability: two points that share the same truncated position
    // (i.e. when rounded to 1 decimal place they are equal) must produce the
    // same 12-character geohash because the inputs are identical.
    // Conversely, we verify that a point differs from a far-away latitude
    // (offset by 45 degrees) on the same longitude.
    glados.Glados2(
      glados.any.latitude,
      glados.any.longitude,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'latitude shift by 45° produces a different hash (same longitude)',
      (lat, lon) {
        // Shift latitude by 45 degrees, clamping to the valid range so we do
        // not trigger a RangeError in GeoHasher.encode.
        final shiftedLat = (lat + 45.0).clamp(-89.999, 89.999);
        // Only assert when the shift was actually applied (i.e. the original
        // latitude is not already at the extreme end where clamping brings the
        // shifted value back to the same cell).
        if ((shiftedLat - lat).abs() < 1.0) return; // clamping collapsed gap

        final original = getGeoHash(latitude: lat, longitude: lon);
        final shifted = getGeoHash(latitude: shiftedLat, longitude: lon);
        expect(
          original,
          isNot(shifted),
          reason: 'lat=$lat shifted=$shiftedLat lon=$lon',
        );
      },
      tags: 'glados',
    );
  });
}
