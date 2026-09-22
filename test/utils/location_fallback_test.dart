import 'dart:async';

import 'package:flutter_test/flutter_test.dart'
    hide isLinux, isMacOS, isWindows;
import 'package:http/http.dart' as http;
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/ip_geolocation_service.dart';
import 'package:lotti/services/linux_location_portal.dart';
import 'package:lotti/services/native_location.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/location.dart';
import 'package:lotti/utils/platform.dart';
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

/// The platforms [DeviceLocation] distinguishes, pinned so every branch runs
/// on whatever host executes the suite.
enum _Host { android, iOS, macOS, linux, windows, other }

void _pinHost(_Host host) {
  final (wasAndroid, wasIOS, wasMacOS, wasLinux, wasWindows) = (
    isAndroid,
    isIOS,
    isMacOS,
    isLinux,
    isWindows,
  );
  isAndroid = host == _Host.android;
  isIOS = host == _Host.iOS;
  isMacOS = host == _Host.macOS;
  isLinux = host == _Host.linux;
  isWindows = host == _Host.windows;
  addTearDown(() {
    isAndroid = wasAndroid;
    isIOS = wasIOS;
    isMacOS = wasMacOS;
    isLinux = wasLinux;
    isWindows = wasWindows;
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockNativeLocationSource nativeSource;
  late MockJournalDb mockJournalDb;
  late MockDomainLogger mockLoggingService;

  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(FakeException());
  });

  setUp(() async {
    nativeSource = MockNativeLocationSource();
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

    when(
      () => mockLoggingService.error(
        any<LogDomain>(),
        any<Exception>(),
        subDomain: any<String>(named: 'subDomain'),
      ),
    ).thenAnswer((_) async {});
  });

  tearDown(tearDownTestGetIt);

  /// Builds the unit under test with the standard fake wiring; pass
  /// [ipProvider] to swap in a failing/null IP geolocation provider.
  DeviceLocation buildDeviceLocation({
    IpGeolocationProvider? ipProvider,
    LinuxLocationBackendFactory? linuxBackendFactory,
  }) => DeviceLocation(
    nativeLocationSource: nativeSource,
    ipGeolocationProvider: ipProvider ?? fakeIpGeolocationProvider,
    linuxBackendFactory: linuxBackendFactory,
  );

  void stubRecordLocationFlag({required bool enabled}) {
    when(
      () => mockJournalDb.getConfigFlag(recordLocationFlag),
    ).thenAnswer((_) async => enabled);
  }

  void stubNativeFix(Future<NativeLocationFix?> Function() answer) {
    when(
      () => nativeSource.currentLocation(timeout: any(named: 'timeout')),
    ).thenAnswer((_) => answer());
  }

  void expectIpFallback(Geolocation? result) {
    expect(result, isNotNull);
    expect(result!.latitude, 40.7128);
    expect(result.longitude, -74.0060);
    expect(result.timezone, 'America/New_York');
    expect(result.utcOffset, -300);
    expect(result.accuracy, 50000);
  }

  group('defaultNativeLocationSource', () {
    test('uses the app channel on Android', () {
      _pinHost(_Host.android);
      expect(defaultNativeLocationSource(), isA<AndroidLocationSource>());
    });

    for (final host in [_Host.iOS, _Host.macOS]) {
      test('uses CoreLocation on ${host.name}', () {
        _pinHost(host);
        expect(defaultNativeLocationSource(), isA<AppleLocationSource>());
      });
    }

    for (final host in [_Host.linux, _Host.windows, _Host.other]) {
      test('has none on ${host.name}', () {
        _pinHost(host);
        expect(defaultNativeLocationSource(), isNull);
      });
    }
  });

  group('DeviceLocation.getCurrentGeoLocation', () {
    test('returns null and reads nothing when recording is off', () async {
      _pinHost(_Host.android);
      stubRecordLocationFlag(enabled: false);

      final result = await buildDeviceLocation().getCurrentGeoLocation();

      expect(result, isNull);
      verifyZeroInteractions(nativeSource);
    });

    test('returns null on Windows, which records no location', () async {
      _pinHost(_Host.windows);
      stubRecordLocationFlag(enabled: true);

      final result = await buildDeviceLocation().getCurrentGeoLocation();

      expect(result, isNull);
      verifyZeroInteractions(nativeSource);
    });

    for (final host in [_Host.android, _Host.iOS, _Host.macOS]) {
      test(
        'maps a native fix into the entry geolocation on ${host.name}',
        () async {
          _pinHost(host);
          stubRecordLocationFlag(enabled: true);
          stubNativeFix(
            () async => const NativeLocationFix(
              latitude: 52.205,
              longitude: 0.119,
              altitude: 10,
              accuracy: 12,
              heading: 180,
              speed: 5,
              speedAccuracy: 1,
            ),
          );

          final result = await buildDeviceLocation().getCurrentGeoLocation();

          expect(result, isNotNull);
          expect(result!.latitude, 52.205);
          expect(result.longitude, 0.119);
          expect(result.altitude, 10);
          expect(result.accuracy, 12);
          expect(result.heading, 180);
          expect(result.speed, 5);
          expect(result.speedAccuracy, 1);
          // Cambridge, UK: the geohash is derived from the fix itself.
          expect(result.geohashString.substring(0, 4), 'u120');
          final now = DateTime.now();
          expect(result.timezone, now.timeZoneName);
          expect(result.utcOffset, now.timeZoneOffset.inMinutes);
          verify(
            () => nativeSource.currentLocation(
              timeout: LocationConstants.locationTimeout,
            ),
          ).called(1);
        },
      );
    }

    test('keeps missing optional readings missing', () async {
      _pinHost(_Host.android);
      stubRecordLocationFlag(enabled: true);
      stubNativeFix(
        () async =>
            const NativeLocationFix(latitude: 48.8566, longitude: 2.3522),
      );

      final result = await buildDeviceLocation().getCurrentGeoLocation();

      expect(result!.latitude, 48.8566);
      expect(result.altitude, isNull);
      expect(result.accuracy, isNull);
      expect(result.heading, isNull);
      expect(result.speed, isNull);
      expect(result.speedAccuracy, isNull);
    });

    test(
      'falls back to IP without logging when there is no fix to take',
      () async {
        // Refused permission and switched-off location both answer null: an
        // expected outcome, not an error worth a log line.
        _pinHost(_Host.android);
        stubRecordLocationFlag(enabled: true);
        stubNativeFix(() async => null);

        final result = await buildDeviceLocation().getCurrentGeoLocation();

        expectIpFallback(result);
        verifyNever(
          () => mockLoggingService.error(
            any<LogDomain>(),
            any<Object>(),
            subDomain: any<String>(named: 'subDomain'),
          ),
        );
      },
    );

    test('falls back to IP and logs when the native read fails', () async {
      _pinHost(_Host.iOS);
      stubRecordLocationFlag(enabled: true);
      stubNativeFix(
        () async =>
            throw TimeoutException('no fix', const Duration(seconds: 10)),
      );

      final result = await buildDeviceLocation().getCurrentGeoLocation();

      expectIpFallback(result);
      verify(
        () => mockLoggingService.error(
          LogDomain.location,
          any<Object>(),
          subDomain: 'native_location_fallback',
        ),
      ).called(1);
    });

    test('returns null when the native read and IP both fail', () async {
      _pinHost(_Host.android);
      stubRecordLocationFlag(enabled: true);
      stubNativeFix(() async => throw Exception('Native failed'));

      final result = await buildDeviceLocation(
        ipProvider: nullIpGeolocationProvider,
      ).getCurrentGeoLocation();

      expect(result, isNull);
    });

    test('uses IP alone on a platform without a native source', () async {
      _pinHost(_Host.other);
      stubRecordLocationFlag(enabled: true);

      final result = await DeviceLocation(
        ipGeolocationProvider: fakeIpGeolocationProvider,
      ).getCurrentGeoLocation();

      expectIpFallback(result);
    });
  });

  group('Linux location handling', () {
    test('uses the portal or GeoClue backend, not the native source', () async {
      _pinHost(_Host.linux);
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

      final result = await buildDeviceLocation(
        linuxBackendFactory: () => backend,
      ).getCurrentGeoLocation();

      expect(result, isNotNull);
      expect(result!.latitude, 52.52);
      expect(result.longitude, 13.405);
      expect(result.altitude, 34);
      expect(result.accuracy, 12);
      expect(result.speed, 1.5);
      expect(result.heading, 90);
      expect(result.geohashString, isNotEmpty);
      expect(backend.closeCount, 1);
      verifyZeroInteractions(nativeSource);
    });

    test('falls back to IP when the portal denies or times out', () async {
      _pinHost(_Host.linux);
      stubRecordLocationFlag(enabled: true);

      final backend = _FakeLinuxBackend(
        error: TimeoutException('no signal', const Duration(seconds: 1)),
      );

      final result = await buildDeviceLocation(
        linuxBackendFactory: () => backend,
      ).getCurrentGeoLocation();

      expectIpFallback(result);
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
        _pinHost(_Host.linux);
        stubRecordLocationFlag(enabled: true);

        final backend = _FakeLinuxBackend(
          result: PortalLocation(latitude: 1, longitude: 2),
          closeError: Exception('cleanup boom'),
        );

        final result = await buildDeviceLocation(
          linuxBackendFactory: () => backend,
        ).getCurrentGeoLocation();

        // Native location is preserved (not replaced by IP fallback) and the
        // close failure is logged instead of being rethrown out of the finally
        // block.
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

    test('getCurrentGeoLocationLinux is inert off Linux', () async {
      _pinHost(_Host.macOS);
      var backendRequested = false;

      final result = await buildDeviceLocation(
        linuxBackendFactory: () {
          backendRequested = true;
          return _FakeLinuxBackend();
        },
      ).getCurrentGeoLocationLinux();

      expect(result, isNull);
      expect(backendRequested, isFalse);
    });
  });
}
