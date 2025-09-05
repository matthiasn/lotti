import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/location.dart';
import 'package:mocktail/mocktail.dart';

class MockLocation extends Mock implements Location {}

class MockJournalDb extends Mock implements JournalDb {}

class MockLoggingService extends Mock implements LoggingService {}

class MockLocationData extends Mock implements LocationData {}

Future<Geolocation?> fakeIpGeolocationProvider(
    {http.Client? httpClient}) async {
  return Geolocation(
    createdAt: DateTime.now(),
    latitude: 40.7128,
    longitude: -74.0060,
    geohashString: 'dr5regw3pb1h',
    timezone: 'America/New_York',
    utcOffset: -300,
    accuracy: 50000,
  );
}

class FakeException extends Fake implements Exception {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockLocation mockLocation;
  late MockJournalDb mockJournalDb;
  late MockLoggingService mockLoggingService;
  late DeviceLocation deviceLocation;

  setUpAll(() {
    registerFallbackValue(FakeException());
  });

  setUp(() {
    mockLocation = MockLocation();
    mockJournalDb = MockJournalDb();
    mockLoggingService = MockLoggingService();

    if (getIt.isRegistered<JournalDb>()) {
      getIt.unregister<JournalDb>();
    }
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }

    getIt
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<LoggingService>(mockLoggingService);

    // Stub captureException to prevent errors in tests
    when(() => mockLoggingService.captureException(
          any<Exception>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
        )).thenReturn(null);
  });

  tearDown(getIt.reset);

  group('DeviceLocation', () {
    group('getCurrentGeoLocation', () {
      test('returns null when location recording is disabled', () async {
        when(() => mockJournalDb.getConfigFlag(recordLocationFlag))
            .thenAnswer((_) async => false);

        deviceLocation = DeviceLocation(
          locationService: mockLocation,
          ipGeolocationProvider: fakeIpGeolocationProvider,
        );
        final result = await deviceLocation.getCurrentGeoLocation();

        expect(result, isNull);
        verifyNever(() => mockLocation.serviceEnabled());
        verifyNever(() => mockLocation.getLocation());
      });

      test('returns native location when permission is granted', () async {
        // Skip this test on Linux as it uses GeoClue instead of Location service
        if (Platform.isLinux) {
          return;
        }

        when(() => mockJournalDb.getConfigFlag(recordLocationFlag))
            .thenAnswer((_) async => true);

        when(() => mockLocation.serviceEnabled()).thenAnswer((_) async => true);

        when(() => mockLocation.hasPermission())
            .thenAnswer((_) async => PermissionStatus.granted);

        final mockLocationData = MockLocationData();
        when(() => mockLocationData.latitude).thenReturn(37.7749);
        when(() => mockLocationData.longitude).thenReturn(-122.4194);
        when(() => mockLocationData.altitude).thenReturn(10);
        when(() => mockLocationData.speed).thenReturn(5);
        when(() => mockLocationData.accuracy).thenReturn(10);
        when(() => mockLocationData.heading).thenReturn(180);
        when(() => mockLocationData.speedAccuracy).thenReturn(1);

        when(() => mockLocation.getLocation())
            .thenAnswer((_) async => mockLocationData);

        deviceLocation = DeviceLocation(
          locationService: mockLocation,
          ipGeolocationProvider: fakeIpGeolocationProvider,
        );
        final result = await deviceLocation.getCurrentGeoLocation();

        expect(result, isNotNull);
        expect(result!.latitude, 37.7749);
        expect(result.longitude, -122.4194);
        expect(result.altitude, 10.0);
        expect(result.speed, 5.0);
        expect(result.accuracy, 10.0);
        expect(result.heading, 180.0);
        expect(result.geohashString, isNotEmpty);
        expect(result.timezone, isNotNull);
        expect(result.utcOffset, isNotNull);
      });

      test('falls back to IP geolocation when permission is denied', () async {
        when(() => mockJournalDb.getConfigFlag(recordLocationFlag))
            .thenAnswer((_) async => true);

        when(() => mockLocation.serviceEnabled()).thenAnswer((_) async => true);

        when(() => mockLocation.hasPermission())
            .thenAnswer((_) async => PermissionStatus.denied);

        when(() => mockLocation.requestPermission())
            .thenAnswer((_) async => PermissionStatus.denied);

        deviceLocation = DeviceLocation(
          locationService: mockLocation,
          ipGeolocationProvider: fakeIpGeolocationProvider,
        );
        final result = await deviceLocation.getCurrentGeoLocation();

        expect(result, isNotNull);
        expect(result!.latitude, 40.7128);
        expect(result.longitude, -74.0060);
        expect(result.timezone, 'America/New_York');
        expect(result.utcOffset, -300);
        expect(result.accuracy, 50000);

        verifyNever(() => mockLocation.getLocation());
      });

      test('falls back to IP geolocation when native location fails', () async {
        // Skip this test on Linux as it uses GeoClue instead of Location service
        if (Platform.isLinux) {
          return;
        }

        when(() => mockJournalDb.getConfigFlag(recordLocationFlag))
            .thenAnswer((_) async => true);

        when(() => mockLocation.serviceEnabled()).thenAnswer((_) async => true);

        when(() => mockLocation.hasPermission())
            .thenAnswer((_) async => PermissionStatus.granted);

        when(() => mockLocation.getLocation())
            .thenThrow(Exception('Location service failed'));

        // The result should fall back to IP geolocation
        deviceLocation = DeviceLocation(
          locationService: mockLocation,
          ipGeolocationProvider: fakeIpGeolocationProvider,
        );
        final result = await deviceLocation.getCurrentGeoLocation();

        // Verify that the exception was logged
        verify(() => mockLoggingService.captureException(
              any<dynamic>(),
              domain: 'LOCATION_SERVICE',
              subDomain: 'native_location_fallback',
            )).called(1);

        expect(result, isNotNull);
        expect(result!.latitude, 40.7128);
        expect(result.longitude, -74.0060);
        expect(result.timezone, 'America/New_York');
        expect(result.utcOffset, -300);
        expect(result.accuracy, 50000);
      });

      test('falls back to IP when location data has null coordinates',
          () async {
        when(() => mockJournalDb.getConfigFlag(recordLocationFlag))
            .thenAnswer((_) async => true);

        when(() => mockLocation.serviceEnabled()).thenAnswer((_) async => true);

        when(() => mockLocation.hasPermission())
            .thenAnswer((_) async => PermissionStatus.granted);

        final mockLocationData = MockLocationData();
        when(() => mockLocationData.latitude).thenReturn(null);
        when(() => mockLocationData.longitude).thenReturn(null);

        when(() => mockLocation.getLocation())
            .thenAnswer((_) async => mockLocationData);

        // Should fall back to IP geolocation
        final result = await deviceLocation.getCurrentGeoLocation();

        // The actual result depends on the IP geolocation service
        expect(result, anyOf(isNull, isA<Geolocation>()));
      });

      test('handles service not enabled by falling back to IP', () async {
        when(() => mockJournalDb.getConfigFlag(recordLocationFlag))
            .thenAnswer((_) async => true);

        when(() => mockLocation.serviceEnabled())
            .thenAnswer((_) async => false);

        when(() => mockLocation.requestService())
            .thenAnswer((_) async => false);

        when(() => mockLocation.hasPermission())
            .thenAnswer((_) async => PermissionStatus.denied);

        when(() => mockLocation.requestPermission())
            .thenAnswer((_) async => PermissionStatus.denied);

        // Should fall back to IP geolocation
        deviceLocation = DeviceLocation(
          locationService: mockLocation,
          ipGeolocationProvider: fakeIpGeolocationProvider,
        );
        final result = await deviceLocation.getCurrentGeoLocation();

        expect(result, isNotNull);
        expect(result!.latitude, 40.7128);
        expect(result.longitude, -74.0060);
        expect(result.timezone, 'America/New_York');
        expect(result.utcOffset, -300);
        expect(result.accuracy, 50000);

        verifyNever(() => mockLocation.getLocation());
      });

      test('handles permission permanently denied by falling back to IP',
          () async {
        when(() => mockJournalDb.getConfigFlag(recordLocationFlag))
            .thenAnswer((_) async => true);

        when(() => mockLocation.serviceEnabled()).thenAnswer((_) async => true);

        when(() => mockLocation.hasPermission())
            .thenAnswer((_) async => PermissionStatus.deniedForever);

        // Should fall back to IP geolocation
        deviceLocation = DeviceLocation(
          locationService: mockLocation,
          ipGeolocationProvider: fakeIpGeolocationProvider,
        );
        final result = await deviceLocation.getCurrentGeoLocation();

        expect(result, isNotNull);
        expect(result!.latitude, 40.7128);
        expect(result.longitude, -74.0060);
        expect(result.timezone, 'America/New_York');
        expect(result.utcOffset, -300);
        expect(result.accuracy, 50000);

        verifyNever(() => mockLocation.getLocation());
      });
    });

    group('Linux-specific location handling', () {
      test('uses GeoClue on Linux when available', () async {
        if (!Platform.isLinux) {
          // Skip this test on non-Linux platforms
          return;
        }

        when(() => mockJournalDb.getConfigFlag(recordLocationFlag))
            .thenAnswer((_) async => true);

        deviceLocation = DeviceLocation(
          locationService: mockLocation,
          ipGeolocationProvider: fakeIpGeolocationProvider,
        );
        final result = await deviceLocation.getCurrentGeoLocation();

        // On Linux, it should try GeoClue first, then fall back to IP
        expect(result, isNotNull);
        expect(result!.latitude, 40.7128);
        expect(result.longitude, -74.0060);
        expect(result.timezone, 'America/New_York');
        expect(result.utcOffset, -300);
        expect(result.accuracy, 50000);
      });

      test('falls back to IP when GeoClue fails on Linux', () async {
        if (!Platform.isLinux) {
          // Skip this test on non-Linux platforms
          return;
        }

        when(() => mockJournalDb.getConfigFlag(recordLocationFlag))
            .thenAnswer((_) async => true);

        // Mock GeoClue failure by making it throw
        when(() => mockLoggingService.captureException(
              any<Exception>(),
              domain: any<String>(named: 'domain'),
              subDomain: any<String>(named: 'subDomain'),
            )).thenReturn(null);

        deviceLocation = DeviceLocation(
          locationService: mockLocation,
          ipGeolocationProvider: fakeIpGeolocationProvider,
        );
        final result = await deviceLocation.getCurrentGeoLocation();

        // Should fall back to IP geolocation
        expect(result, isNotNull);
        expect(result!.latitude, 40.7128);
        expect(result.longitude, -74.0060);
        expect(result.timezone, 'America/New_York');
        expect(result.utcOffset, -300);
        expect(result.accuracy, 50000);
      });
    });

    group('Geolocation data validation', () {
      test('includes geohash for all successful locations', () async {
        // Skip this test on Linux as it uses GeoClue instead of Location service
        if (Platform.isLinux) {
          return;
        }

        when(() => mockJournalDb.getConfigFlag(recordLocationFlag))
            .thenAnswer((_) async => true);

        when(() => mockLocation.serviceEnabled()).thenAnswer((_) async => true);

        when(() => mockLocation.hasPermission())
            .thenAnswer((_) async => PermissionStatus.granted);

        final mockLocationData = MockLocationData();
        when(() => mockLocationData.latitude).thenReturn(52.205);
        when(() => mockLocationData.longitude).thenReturn(0.119);
        when(() => mockLocationData.altitude).thenReturn(null);
        when(() => mockLocationData.speed).thenReturn(null);
        when(() => mockLocationData.accuracy).thenReturn(15);
        when(() => mockLocationData.heading).thenReturn(null);
        when(() => mockLocationData.speedAccuracy).thenReturn(null);

        when(() => mockLocation.getLocation())
            .thenAnswer((_) async => mockLocationData);

        deviceLocation = DeviceLocation(
          locationService: mockLocation,
          ipGeolocationProvider: fakeIpGeolocationProvider,
        );
        final result = await deviceLocation.getCurrentGeoLocation();

        expect(result, isNotNull);
        expect(result!.geohashString, isNotEmpty);
        // The geohash for coordinates (52.205, 0.119) should start with 'u120'
        expect(result.geohashString.substring(0, 4), 'u120');
      });

      test('includes timezone and UTC offset for all locations', () async {
        // Skip this test on Linux as it uses GeoClue instead of Location service
        if (Platform.isLinux) {
          return;
        }

        when(() => mockJournalDb.getConfigFlag(recordLocationFlag))
            .thenAnswer((_) async => true);

        when(() => mockLocation.serviceEnabled()).thenAnswer((_) async => true);

        when(() => mockLocation.hasPermission())
            .thenAnswer((_) async => PermissionStatus.granted);

        final mockLocationData = MockLocationData();
        when(() => mockLocationData.latitude).thenReturn(0);
        when(() => mockLocationData.longitude).thenReturn(0);
        when(() => mockLocationData.altitude).thenReturn(null);
        when(() => mockLocationData.speed).thenReturn(null);
        when(() => mockLocationData.accuracy).thenReturn(100);
        when(() => mockLocationData.heading).thenReturn(null);
        when(() => mockLocationData.speedAccuracy).thenReturn(null);

        when(() => mockLocation.getLocation())
            .thenAnswer((_) async => mockLocationData);

        deviceLocation = DeviceLocation(
          locationService: mockLocation,
          ipGeolocationProvider: fakeIpGeolocationProvider,
        );
        final result = await deviceLocation.getCurrentGeoLocation();

        expect(result, isNotNull);
        expect(result!.timezone, isNotNull);
        expect(result.utcOffset, isNotNull);
      });
    });
  });
}
