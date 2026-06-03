import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/geolocation.dart';

void main() {
  group('Geolocation JSON round-trips — static examples', () {
    Geolocation roundTrip(Geolocation g) => Geolocation.fromJson(
          jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>,
        );

    test('minimal Geolocation survives JSON round-trip', () {
      final g = Geolocation(
        createdAt: DateTime(2024, 3, 15, 10),
        latitude: 48.137154,
        longitude: 11.576124,
        geohashString: 'u281z',
      );
      final decoded = roundTrip(g);
      expect(decoded, g, reason: 'minimal Geolocation round-trip');
      expect(decoded.latitude, 48.137154);
      expect(decoded.longitude, 11.576124);
      expect(decoded.geohashString, 'u281z');
      expect(decoded.accuracy, isNull);
      expect(decoded.speed, isNull);
      expect(decoded.altitude, isNull);
      expect(decoded.timezone, isNull);
    });

    test('Geolocation with all optional fields survives JSON round-trip', () {
      final g = Geolocation(
        createdAt: DateTime(2024, 6, 1, 12, 30),
        latitude: -33.868820,
        longitude: 151.209290,
        geohashString: 'r3gx2',
        utcOffset: 600,
        timezone: 'Australia/Sydney',
        accuracy: 5,
        speed: 1.5,
        speedAccuracy: 0.3,
        heading: 180,
        headingAccuracy: 2,
        altitude: 42,
      );
      final decoded = roundTrip(g);
      expect(decoded, g, reason: 'full Geolocation round-trip');
      expect(decoded.utcOffset, 600);
      expect(decoded.timezone, 'Australia/Sydney');
      expect(decoded.accuracy, 5.0);
      expect(decoded.speed, 1.5);
      expect(decoded.speedAccuracy, 0.3);
      expect(decoded.heading, 180.0);
      expect(decoded.headingAccuracy, 2.0);
      expect(decoded.altitude, 42.0);
    });

    test('Geolocation at extreme coordinates survives JSON round-trip', () {
      final g = Geolocation(
        createdAt: DateTime(2024),
        latitude: -90,
        longitude: 180,
        geohashString: '000000',
      );
      final decoded = roundTrip(g);
      expect(decoded, g, reason: 'extreme coords round-trip');
      expect(decoded.latitude, -90.0);
      expect(decoded.longitude, 180.0);
    });

    test('Geolocation with zero speed and altitude survives JSON round-trip',
        () {
      final g = Geolocation(
        createdAt: DateTime(2024, 3, 15),
        latitude: 0,
        longitude: 0,
        geohashString: 's0000',
        speed: 0,
        altitude: 0,
      );
      final decoded = roundTrip(g);
      expect(decoded, g, reason: 'zero values round-trip');
      expect(decoded.speed, 0.0);
      expect(decoded.altitude, 0.0);
    });
  });

  group('Geolocation Glados round-trips', () {
    glados.Glados(
      glados.any.generatedGeolocation,
      glados.ExploreConfig(numRuns: 120),
    ).test('Geolocation round-trips through JSON', (scenario) {
      final geo = scenario.geolocation;
      final decoded = Geolocation.fromJson(
        jsonDecode(jsonEncode(geo.toJson())) as Map<String, dynamic>,
      );
      expect(decoded, geo, reason: '$scenario');
      expect(decoded.latitude, geo.latitude, reason: 'latitude preserved');
      expect(decoded.longitude, geo.longitude, reason: 'longitude preserved');
      expect(decoded.geohashString, geo.geohashString,
          reason: 'geohash preserved');
    }, tags: 'glados');
  });
}

// ---------------------------------------------------------------------------
// Glados generator helpers for Geolocation.
// ---------------------------------------------------------------------------

class _GeneratedGeolocation {
  const _GeneratedGeolocation({
    required this.dateSlot,
    required this.latSlot,
    required this.lonSlot,
    required this.utcOffsetSlot,
    required this.optionalsSlot,
  });

  final int dateSlot;
  final int latSlot;
  final int lonSlot;
  final int utcOffsetSlot;
  final int optionalsSlot;

  Geolocation get geolocation {
    final date =
        DateTime.utc(2024, (dateSlot % 12) + 1, (dateSlot % 28) + 1);
    final lat = (latSlot % 181) - 90.0;
    final lon = (lonSlot % 361) - 180.0;
    final geohash = 'gh${latSlot.toRadixString(36)}';
    final utcOffset = optionalsSlot % 4 == 0 ? null : (utcOffsetSlot % 1440) - 720;
    final timezone = optionalsSlot % 3 == 0 ? null : 'UTC';
    final accuracy = optionalsSlot % 5 == 0 ? null : (optionalsSlot % 100) + 1.0;
    final speed = optionalsSlot % 6 == 0 ? null : (optionalsSlot % 30) + 0.5;
    final altitude = optionalsSlot % 7 == 0 ? null : (optionalsSlot % 500) - 50.0;

    return Geolocation(
      createdAt: date,
      latitude: lat,
      longitude: lon,
      geohashString: geohash,
      utcOffset: utcOffset,
      timezone: timezone,
      accuracy: accuracy,
      speed: speed,
      altitude: altitude,
    );
  }

  @override
  String toString() =>
      '_GeneratedGeolocation(dateSlot: $dateSlot, '
      'latSlot: $latSlot, lonSlot: $lonSlot, '
      'optionalsSlot: $optionalsSlot)';
}

extension _AnyGeolocation on glados.Any {
  glados.Generator<_GeneratedGeolocation> get generatedGeolocation =>
      glados.CombinableAny(this).combine5(
        glados.IntAnys(this).intInRange(0, 50),
        glados.IntAnys(this).intInRange(0, 180),
        glados.IntAnys(this).intInRange(0, 360),
        glados.IntAnys(this).intInRange(0, 1440),
        glados.IntAnys(this).intInRange(0, 20),
        (dateSlot, latSlot, lonSlot, utcOffsetSlot, optionalsSlot) =>
            _GeneratedGeolocation(
          dateSlot: dateSlot,
          latSlot: latSlot,
          lonSlot: lonSlot,
          utcOffsetSlot: utcOffsetSlot,
          optionalsSlot: optionalsSlot,
        ),
      );
}
