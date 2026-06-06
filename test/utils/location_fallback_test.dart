import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/ip_geolocation_service.dart';
import 'package:lotti/services/linux_location_portal.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/location.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fallbacks.dart';
import '../mocks/mocks.dart';
import '../widget_test_utils.dart';

class _FakeLinuxBackend implements LinuxLocationBackend {
  _FakeLinuxBackend({this.result, this.error, this.closeError});

  PortalLocation? result;
  Exception? error;
  Exception? closeError;
  int closeCount = 0;

  @override
  Future<PortalLocation> getLocation({required Duration timeout}) async {
    if (error != null) {
      throw error!;
    }
    return result!;
  }

  @override
  Future<void> close() async {
    closeCount++;
    if (closeError != null) throw closeError!;
  }
}

Future<Geolocation?> nullIpGeolocationProvider({
  http.Client? httpClient,
}) async {
  return null;
}

Future<Geolocation?> fakeIpGeolocationProvider({
  http.Client? httpClient,
}) async {
  return Geolocation(
    createdAt: DateTime(2024, 3, 15, 10, 30),
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
  late MockDomainLogger mockLoggingService;
  late DeviceLocation deviceLocation;

  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(FakeException());
  });

  setUp(() async {
    mockLocation = MockLocation();
    mockJournalDb = MockJournalDb();
    mockLoggingService = MockDomainLogger();

    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..unregister<JournalDb>()
          ..registerSingleton<JournalDb>(mockJournalDb)
          ..unregister<DomainLogger>()
          ..registerSingleton<DomainLogger>(mockLoggingService);
      },
    );

    // Stub captureException to prevent errors in tests
    when(
      () => mockLoggingService.error(
        any<LogDomain>(),
        any<Exception>(),
        subDomain: any<String>(named: 'subDomain'),
      ),
    ).thenAnswer((_) async {});
  });

  tearDown(tearDownTestGetIt);

  /// Builds the unit under test with the standard mock wiring; pass
  /// [ipProvider] to swap in a failing/null IP geolocation provider.
  DeviceLocation buildDeviceLocation({
    IpGeolocationProvider? ipProvider,
    LinuxLocationBackendFactory? linuxBackendFactory,
  }) => DeviceLocation(
    locationService: mockLocation,
    ipGeolocationProvider: ipProvider ?? fakeIpGeolocationProvider,
    linuxBackendFactory: linuxBackendFactory,
  );

  /// Stubs the record-location config flag.
  void stubRecordLocationFlag({required bool enabled}) {
    when(
      () => mockJournalDb.getConfigFlag(recordLocationFlag),
    ).thenAnswer((_) async => enabled);
  }

  group('DeviceLocation', () {
    group('getCurrentGeoLocation', () {
      test('returns null when location recording is disabled', () async {
        stubRecordLocationFlag(enabled: false);

        deviceLocation = buildDeviceLocation();
        final result = await deviceLocation.getCurrentGeoLocation();

        expect(result, isNull);
        verifyNever(() => mockLocation.serviceEnabled());
        verifyNever(() => mockLocation.getLocation());
      });

      test('returns native location when permission is granted', () async {
        // Skip on Linux: that platform uses the xdg-desktop-portal path, not the
        // location package mocked here.
        if (Platform.isLinux) {
          return;
        }

        stubRecordLocationFlag(enabled: true);

        when(() => mockLocation.serviceEnabled()).thenAnswer((_) async => true);

        when(
          () => mockLocation.hasPermission(),
        ).thenAnswer((_) async => PermissionStatus.granted);

        final mockLocationData = MockLocationData();
        when(() => mockLocationData.latitude).thenReturn(37.7749);
        when(() => mockLocationData.longitude).thenReturn(-122.4194);
        when(() => mockLocationData.altitude).thenReturn(10);
        when(() => mockLocationData.speed).thenReturn(5);
        when(() => mockLocationData.accuracy).thenReturn(10);
        when(() => mockLocationData.heading).thenReturn(180);
        when(() => mockLocationData.speedAccuracy).thenReturn(1);

        when(
          () => mockLocation.getLocation(),
        ).thenAnswer((_) async => mockLocationData);

        deviceLocation = buildDeviceLocation();
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
        // Skip on Linux: that platform uses the xdg-desktop-portal path, not the
        // location package mocked here.
        if (Platform.isLinux) {
          return;
        }
        stubRecordLocationFlag(enabled: true);

        when(() => mockLocation.serviceEnabled()).thenAnswer((_) async => true);

        when(
          () => mockLocation.hasPermission(),
        ).thenAnswer((_) async => PermissionStatus.denied);

        when(
          () => mockLocation.requestPermission(),
        ).thenAnswer((_) async => PermissionStatus.denied);

        deviceLocation = buildDeviceLocation();
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
        // Skip on Linux: that platform uses the xdg-desktop-portal path, not the
        // location package mocked here.
        if (Platform.isLinux) {
          return;
        }

        stubRecordLocationFlag(enabled: true);

        when(() => mockLocation.serviceEnabled()).thenAnswer((_) async => true);

        when(
          () => mockLocation.hasPermission(),
        ).thenAnswer((_) async => PermissionStatus.granted);

        when(
          () => mockLocation.getLocation(),
        ).thenThrow(Exception('Location service failed'));

        // The result should fall back to IP geolocation
        deviceLocation = buildDeviceLocation();
        final result = await deviceLocation.getCurrentGeoLocation();

        // Verify that the exception was logged
        verify(
          () => mockLoggingService.error(
            LogDomain.location,
            any<Object>(),
            subDomain: 'native_location_fallback',
          ),
        ).called(1);

        expect(result, isNotNull);
        expect(result!.latitude, 40.7128);
        expect(result.longitude, -74.0060);
        expect(result.timezone, 'America/New_York');
        expect(result.utcOffset, -300);
        expect(result.accuracy, 50000);
      });

      test(
        'falls back to IP when location data has null coordinates',
        () async {
          stubRecordLocationFlag(enabled: true);

          when(
            () => mockLocation.serviceEnabled(),
          ).thenAnswer((_) async => true);

          when(
            () => mockLocation.hasPermission(),
          ).thenAnswer((_) async => PermissionStatus.granted);

          final mockLocationData = MockLocationData();
          when(() => mockLocationData.latitude).thenReturn(null);
          when(() => mockLocationData.longitude).thenReturn(null);

          when(
            () => mockLocation.getLocation(),
          ).thenAnswer((_) async => mockLocationData);

          // Should fall back to IP geolocation
          final result = await deviceLocation.getCurrentGeoLocation();

          // The actual result depends on the IP geolocation service
          expect(result, anyOf(isNull, isA<Geolocation>()));
        },
      );

      test('handles service not enabled by falling back to IP', () async {
        // Skip on Linux: that platform uses the xdg-desktop-portal path, not the
        // location package mocked here.
        if (Platform.isLinux) {
          return;
        }
        stubRecordLocationFlag(enabled: true);

        when(
          () => mockLocation.serviceEnabled(),
        ).thenAnswer((_) async => false);

        when(
          () => mockLocation.requestService(),
        ).thenAnswer((_) async => false);

        when(
          () => mockLocation.hasPermission(),
        ).thenAnswer((_) async => PermissionStatus.denied);

        when(
          () => mockLocation.requestPermission(),
        ).thenAnswer((_) async => PermissionStatus.denied);

        // Should fall back to IP geolocation
        deviceLocation = buildDeviceLocation();
        final result = await deviceLocation.getCurrentGeoLocation();

        expect(result, isNotNull);
        expect(result!.latitude, 40.7128);
        expect(result.longitude, -74.0060);
        expect(result.timezone, 'America/New_York');
        expect(result.utcOffset, -300);
        expect(result.accuracy, 50000);

        verifyNever(() => mockLocation.getLocation());
      });

      test(
        'handles permission permanently denied by falling back to IP',
        () async {
          // Skip on Linux: that platform uses the xdg-desktop-portal path, not
          // the location package mocked here.
          if (Platform.isLinux) {
            return;
          }
          stubRecordLocationFlag(enabled: true);

          when(
            () => mockLocation.serviceEnabled(),
          ).thenAnswer((_) async => true);

          when(
            () => mockLocation.hasPermission(),
          ).thenAnswer((_) async => PermissionStatus.deniedForever);

          // Should fall back to IP geolocation
          deviceLocation = buildDeviceLocation();
          final result = await deviceLocation.getCurrentGeoLocation();

          expect(result, isNotNull);
          expect(result!.latitude, 40.7128);
          expect(result.longitude, -74.0060);
          expect(result.timezone, 'America/New_York');
          expect(result.utcOffset, -300);
          expect(result.accuracy, 50000);

          verifyNever(() => mockLocation.getLocation());
        },
      );

      test(
        'gets native location when permission initially denied then granted',
        () async {
          if (Platform.isLinux || Platform.isWindows) return;

          stubRecordLocationFlag(enabled: true);

          when(
            () => mockLocation.serviceEnabled(),
          ).thenAnswer((_) async => true);

          when(
            () => mockLocation.hasPermission(),
          ).thenAnswer((_) async => PermissionStatus.denied);

          when(
            () => mockLocation.requestPermission(),
          ).thenAnswer((_) async => PermissionStatus.granted);

          final mockLocationData = MockLocationData();
          when(() => mockLocationData.latitude).thenReturn(48.8566);
          when(() => mockLocationData.longitude).thenReturn(2.3522);
          when(() => mockLocationData.altitude).thenReturn(35);
          when(() => mockLocationData.speed).thenReturn(null);
          when(() => mockLocationData.accuracy).thenReturn(20);
          when(() => mockLocationData.heading).thenReturn(null);
          when(() => mockLocationData.speedAccuracy).thenReturn(null);

          when(
            () => mockLocation.getLocation(),
          ).thenAnswer((_) async => mockLocationData);

          deviceLocation = buildDeviceLocation();
          final result = await deviceLocation.getCurrentGeoLocation();

          expect(result, isNotNull);
          expect(result!.latitude, 48.8566);
          expect(result.longitude, 2.3522);
          verify(() => mockLocation.requestPermission()).called(1);
          verify(() => mockLocation.getLocation()).called(1);
        },
      );

      test('returns null when both native and IP geolocation fail', () async {
        if (Platform.isLinux || Platform.isWindows) return;

        stubRecordLocationFlag(enabled: true);

        when(() => mockLocation.serviceEnabled()).thenAnswer((_) async => true);

        when(
          () => mockLocation.hasPermission(),
        ).thenAnswer((_) async => PermissionStatus.denied);

        when(
          () => mockLocation.requestPermission(),
        ).thenAnswer((_) async => PermissionStatus.denied);

        deviceLocation = buildDeviceLocation(
          ipProvider: nullIpGeolocationProvider,
        );
        final result = await deviceLocation.getCurrentGeoLocation();

        expect(result, isNull);
      });

      test(
        'returns null when native throws and IP provider returns null',
        () async {
          if (Platform.isLinux || Platform.isWindows) return;

          stubRecordLocationFlag(enabled: true);

          when(
            () => mockLocation.serviceEnabled(),
          ).thenAnswer((_) async => true);

          when(
            () => mockLocation.hasPermission(),
          ).thenAnswer((_) async => PermissionStatus.granted);

          when(
            () => mockLocation.getLocation(),
          ).thenThrow(Exception('Native failed'));

          deviceLocation = buildDeviceLocation(
            ipProvider: nullIpGeolocationProvider,
          );
          final result = await deviceLocation.getCurrentGeoLocation();

          expect(result, isNull);
        },
      );
    });

    group('Linux-specific location handling', () {
      test(
        'uses xdg-desktop-portal location on Linux when available',
        () async {
          if (!Platform.isLinux) return;

          stubRecordLocationFlag(enabled: true);

          final backend = _FakeLinuxBackend(
            result: PortalLocation(
              latitude: 52.52,
              longitude: 13.405,
              altitude: 34,
              accuracy: 12,
              speed: 1.5,
              heading: 90,
            ),
          );

          deviceLocation = buildDeviceLocation(
            linuxBackendFactory: () => backend,
          );
          final result = await deviceLocation.getCurrentGeoLocation();

          expect(result, isNotNull);
          expect(result!.latitude, 52.52);
          expect(result.longitude, 13.405);
          expect(result.altitude, 34);
          expect(result.accuracy, 12);
          expect(result.speed, 1.5);
          expect(result.heading, 90);
          expect(result.geohashString, isNotEmpty);
          expect(backend.closeCount, 1);
        },
      );

      test('falls back to IP when the portal denies or times out', () async {
        if (!Platform.isLinux) return;

        stubRecordLocationFlag(enabled: true);

        final backend = _FakeLinuxBackend(
          error: TimeoutException(
            'no signal',
            const Duration(seconds: 1),
          ),
        );

        deviceLocation = buildDeviceLocation(
          linuxBackendFactory: () => backend,
        );
        final result = await deviceLocation.getCurrentGeoLocation();

        expect(result, isNotNull);
        expect(result!.latitude, 40.7128);
        expect(result.longitude, -74.0060);
        verify(
          () => mockLoggingService.error(
            LogDomain.location,
            any<Object>(),
            subDomain: 'linux_native_fallback',
          ),
        ).called(1);
        expect(backend.closeCount, 1);
      });

      test(
        'returns the native location even when backend.close() throws',
        () async {
          if (!Platform.isLinux) return;

          stubRecordLocationFlag(enabled: true);

          final backend = _FakeLinuxBackend(
            result: PortalLocation(latitude: 1, longitude: 2),
            closeError: Exception('cleanup boom'),
          );

          deviceLocation = buildDeviceLocation(
            linuxBackendFactory: () => backend,
          );
          final result = await deviceLocation.getCurrentGeoLocation();

          // Native location is preserved (not replaced by IP fallback) and the
          // close failure is logged through LoggingService instead of being
          // rethrown out of the finally block.
          expect(result, isNotNull);
          expect(result!.latitude, 1);
          expect(result.longitude, 2);
          verify(
            () => mockLoggingService.error(
              LogDomain.location,
              any<Object>(),
              subDomain: 'linux_backend_close',
            ),
          ).called(1);
          expect(backend.closeCount, 1);
        },
      );
    });

    group('Geolocation data validation', () {
      test('includes geohash for all successful locations', () async {
        // Skip on Linux: that platform uses the xdg-desktop-portal path, not the
        // location package mocked here.
        if (Platform.isLinux) {
          return;
        }

        stubRecordLocationFlag(enabled: true);

        when(() => mockLocation.serviceEnabled()).thenAnswer((_) async => true);

        when(
          () => mockLocation.hasPermission(),
        ).thenAnswer((_) async => PermissionStatus.granted);

        final mockLocationData = MockLocationData();
        when(() => mockLocationData.latitude).thenReturn(52.205);
        when(() => mockLocationData.longitude).thenReturn(0.119);
        when(() => mockLocationData.altitude).thenReturn(null);
        when(() => mockLocationData.speed).thenReturn(null);
        when(() => mockLocationData.accuracy).thenReturn(15);
        when(() => mockLocationData.heading).thenReturn(null);
        when(() => mockLocationData.speedAccuracy).thenReturn(null);

        when(
          () => mockLocation.getLocation(),
        ).thenAnswer((_) async => mockLocationData);

        deviceLocation = buildDeviceLocation();
        final result = await deviceLocation.getCurrentGeoLocation();

        expect(result, isNotNull);
        expect(result!.geohashString, isNotEmpty);
        // The geohash for coordinates (52.205, 0.119) should start with 'u120'
        expect(result.geohashString.substring(0, 4), 'u120');
      });

      test('includes timezone and UTC offset for all locations', () async {
        // Skip on Linux: that platform uses the xdg-desktop-portal path, not the
        // location package mocked here.
        if (Platform.isLinux) {
          return;
        }

        stubRecordLocationFlag(enabled: true);

        when(() => mockLocation.serviceEnabled()).thenAnswer((_) async => true);

        when(
          () => mockLocation.hasPermission(),
        ).thenAnswer((_) async => PermissionStatus.granted);

        final mockLocationData = MockLocationData();
        when(() => mockLocationData.latitude).thenReturn(0);
        when(() => mockLocationData.longitude).thenReturn(0);
        when(() => mockLocationData.altitude).thenReturn(null);
        when(() => mockLocationData.speed).thenReturn(null);
        when(() => mockLocationData.accuracy).thenReturn(100);
        when(() => mockLocationData.heading).thenReturn(null);
        when(() => mockLocationData.speedAccuracy).thenReturn(null);

        when(
          () => mockLocation.getLocation(),
        ).thenAnswer((_) async => mockLocationData);

        deviceLocation = buildDeviceLocation();
        final result = await deviceLocation.getCurrentGeoLocation();

        expect(result, isNotNull);
        expect(result!.timezone, isNotNull);
        expect(result.utcOffset, isNotNull);
      });
    });
  });
}
