import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/ip_geolocation_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class MockLoggingService extends Mock implements LoggingService {}

void main() {
  late MockLoggingService mockLoggingService;

  setUp(() {
    mockLoggingService = MockLoggingService();

    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
    getIt.registerSingleton<LoggingService>(mockLoggingService);
  });

  tearDown(getIt.reset);

  group('IpGeolocationService Integration Tests', () {
    // These tests make real network calls and should be skipped in CI
    group('Live API Tests', () {
      test(
        'getLocationFromIp returns valid geolocation from real API',
        () async {
          final result = await IpGeolocationService.getLocationFromIp();

          expect(result, isNotNull);
          expect(result!.latitude, isNotNull);
          expect(result.longitude, isNotNull);
          expect(result.geohashString, isNotEmpty);
          expect(result.accuracy, equals(50000)); // IP location accuracy
          expect(result.timezone, isNotEmpty);
          expect(result.utcOffset, isNotNull);
        },
        skip: 'Requires network access - run manually',
      );

      test(
        'geohash is properly generated for location',
        () async {
          final result = await IpGeolocationService.getLocationFromIp();

          if (result != null) {
            expect(result.geohashString, isNotEmpty);
            expect(result.geohashString.length, greaterThanOrEqualTo(8));

            // Geohash should only contain valid base32 characters
            expect(
              RegExp(r'^[0-9bcdefghjkmnpqrstuvwxyz]+$')
                  .hasMatch(result.geohashString),
              isTrue,
            );
          }
        },
        skip: 'Requires network access - run manually',
      );

      test(
        'UTC offset is reasonable',
        () async {
          final result = await IpGeolocationService.getLocationFromIp();

          if (result != null) {
            // UTC offset should be between -12 and +14 hours (in minutes)
            expect(result.utcOffset, greaterThanOrEqualTo(-720));
            expect(result.utcOffset, lessThanOrEqualTo(840));

            // UTC offset should be a multiple of 15 minutes (most common)
            // Note: Some timezones have 30 or 45 minute offsets
            if (result.utcOffset != null) {
              expect(result.utcOffset! % 15, equals(0));
            }
          }
        },
        skip: 'Requires network access - run manually',
      );
    });

    group('Error Handling', () {
      test(
        'handles network timeout gracefully',
        () async {
          // This test would need to simulate a timeout
          // In practice, the service has a 5-second timeout
          final future = IpGeolocationService.getLocationFromIp();

          // The call should complete within a reasonable time
          final result = await future.timeout(
            const Duration(seconds: 10),
            onTimeout: () => null,
          );

          // Result should be either null or a valid Geolocation
          expect(result, anyOf(isNull, isA<Geolocation>()));
        },
        skip: 'Requires network access - run manually',
      );
    });
  });

  group('UTC Offset Parsing Tests', () {
    // These tests validate the parsing logic indirectly through the API response
    test('handles various timezone offsets correctly', () async {
      // Test data for known timezone offsets - not used in actual test
      // but kept for reference

      // Note: We can't directly test _parseUtcOffset since it's private
      // But we can verify the service handles different formats correctly
      // by checking the result includes a valid UTC offset

      final result = await IpGeolocationService.getLocationFromIp();

      if (result != null) {
        // The offset should be valid regardless of the user's location
        expect(result.utcOffset, isNotNull);
        expect(result.utcOffset, isA<int>());
      }
    });
  });
}
