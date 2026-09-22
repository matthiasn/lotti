import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:lotti/services/native_location.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';

class _FakeLocationSettings extends Fake implements LocationSettings {}

Position _position({
  double altitude = 408,
  double altitudeAccuracy = 3,
  double accuracy = 8,
  double heading = 270,
  double speed = 3,
  double speedAccuracy = 0.5,
}) => Position(
  latitude: 47.3769,
  longitude: 8.5417,
  timestamp: DateTime.utc(2026, 9, 22, 12),
  accuracy: accuracy,
  altitude: altitude,
  altitudeAccuracy: altitudeAccuracy,
  heading: heading,
  headingAccuracy: 5,
  speed: speed,
  speedAccuracy: speedAccuracy,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const timeout = Duration(seconds: 10);

  setUpAll(() => registerFallbackValue(_FakeLocationSettings()));

  group('AppleLocationSource', () {
    late MockGeolocatorPlatform platform;
    late AppleLocationSource source;

    setUp(() {
      platform = MockGeolocatorPlatform();
      source = AppleLocationSource(platform: platform);
      when(() => platform.isLocationServiceEnabled()).thenAnswer(
        (_) async => true,
      );
      when(
        () => platform.getCurrentPosition(
          locationSettings: any(named: 'locationSettings'),
        ),
      ).thenAnswer((_) async => _position());
    });

    test(
      'reads a fix with an existing permission, bounded by the timeout',
      () async {
        when(() => platform.checkPermission()).thenAnswer(
          (_) async => LocationPermission.whileInUse,
        );

        final fix = await source.currentLocation(timeout: timeout);

        expect(fix!.latitude, 47.3769);
        expect(fix.longitude, 8.5417);
        expect(fix.altitude, 408);
        expect(fix.accuracy, 8);
        expect(fix.heading, 270);
        expect(fix.speed, 3);
        expect(fix.speedAccuracy, 0.5);
        verifyNever(() => platform.requestPermission());
        final settings =
            verify(
                  () => platform.getCurrentPosition(
                    locationSettings: captureAny(named: 'locationSettings'),
                  ),
                ).captured.single
                as LocationSettings;
        expect(settings.timeLimit, timeout);
      },
    );

    test(
      'asks once when the permission is undecided and reads on consent',
      () async {
        when(() => platform.checkPermission()).thenAnswer(
          (_) async => LocationPermission.denied,
        );
        when(() => platform.requestPermission()).thenAnswer(
          (_) async => LocationPermission.always,
        );

        final fix = await source.currentLocation(timeout: timeout);

        expect(fix, isNotNull);
        verify(() => platform.requestPermission()).called(1);
      },
    );

    for (final refused in [
      LocationPermission.denied,
      LocationPermission.deniedForever,
      LocationPermission.unableToDetermine,
    ]) {
      test(
        'answers null without reading when the user leaves it ${refused.name}',
        () async {
          when(() => platform.checkPermission()).thenAnswer(
            (_) async => LocationPermission.denied,
          );
          when(() => platform.requestPermission()).thenAnswer(
            (_) async => refused,
          );

          expect(await source.currentLocation(timeout: timeout), isNull);
          verifyNever(
            () => platform.getCurrentPosition(
              locationSettings: any(named: 'locationSettings'),
            ),
          );
        },
      );
    }

    test('does not re-ask after a permanent refusal', () async {
      when(() => platform.checkPermission()).thenAnswer(
        (_) async => LocationPermission.deniedForever,
      );

      expect(await source.currentLocation(timeout: timeout), isNull);
      verifyNever(() => platform.requestPermission());
    });

    test(
      'answers null without asking when location services are off',
      () async {
        when(() => platform.isLocationServiceEnabled()).thenAnswer(
          (_) async => false,
        );

        expect(await source.currentLocation(timeout: timeout), isNull);
        verifyNever(() => platform.checkPermission());
        verifyNever(() => platform.requestPermission());
      },
    );

    void stubPosition(Position position) {
      when(() => platform.checkPermission()).thenAnswer(
        (_) async => LocationPermission.whileInUse,
      );
      when(
        () => platform.getCurrentPosition(
          locationSettings: any(named: 'locationSettings'),
        ),
      ).thenAnswer((_) async => position);
    }

    test("drops CoreLocation's negative 'unknown' motion readings", () async {
      stubPosition(_position(heading: -1, speed: -1, speedAccuracy: -1));

      final fix = await source.currentLocation(timeout: timeout);

      expect(fix!.latitude, 47.3769);
      expect(fix.accuracy, 8);
      expect(fix.heading, isNull);
      expect(fix.speed, isNull);
      expect(fix.speedAccuracy, isNull);
    });

    test('treats a negative horizontal accuracy as no fix at all', () async {
      // CoreLocation's signal that the coordinates themselves are invalid;
      // recording them would pin the entry to a meaningless place.
      stubPosition(_position(accuracy: -1));

      expect(await source.currentLocation(timeout: timeout), isNull);
    });

    for (final unmeasured in [0.0, -1.0]) {
      test(
        'drops an altitude whose vertical accuracy is $unmeasured',
        () async {
          stubPosition(_position(altitude: 0, altitudeAccuracy: unmeasured));

          final fix = await source.currentLocation(timeout: timeout);

          expect(fix!.latitude, 47.3769);
          expect(fix.altitude, isNull);
        },
      );
    }

    test('keeps a measured altitude below sea level', () async {
      // The Dead Sea shore: negative, but a real reading.
      stubPosition(_position(altitude: -28));

      final fix = await source.currentLocation(timeout: timeout);

      expect(fix!.altitude, -28);
    });

    test('lets a timed-out read fail for the caller to fall back', () async {
      when(() => platform.checkPermission()).thenAnswer(
        (_) async => LocationPermission.whileInUse,
      );
      when(
        () => platform.getCurrentPosition(
          locationSettings: any(named: 'locationSettings'),
        ),
      ).thenAnswer(
        (_) async => throw TimeoutException('no fix', timeout),
      );

      await expectLater(
        source.currentLocation(timeout: timeout),
        throwsA(isA<TimeoutException>()),
      );
    });
  });

  group('AndroidLocationSource', () {
    const channel = MethodChannel(AndroidLocationSource.channelName);
    final calls = <MethodCall>[];
    late Object? Function(MethodCall call) answer;

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return answer(call);
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('asks the app channel for one fix within the timeout', () async {
      answer = (_) => <String, Object?>{
        'latitude': 59.3293,
        'longitude': 18.0686,
        'altitude': 28.5,
        'accuracy': 15,
        'heading': 90.5,
        'speed': 1.25,
        'speedAccuracy': 0.75,
      };

      final fix = await AndroidLocationSource().currentLocation(
        timeout: timeout,
      );

      expect(calls.single.method, 'getCurrentLocation');
      expect(calls.single.arguments, {'timeoutMs': 10000});
      expect(fix!.latitude, 59.3293);
      expect(fix.longitude, 18.0686);
      expect(fix.altitude, 28.5);
      // Integral values arrive as ints over the channel.
      expect(fix.accuracy, 15.0);
      expect(fix.heading, 90.5);
      expect(fix.speed, 1.25);
      expect(fix.speedAccuracy, 0.75);
    });

    test('keeps readings the provider did not report as null', () async {
      answer = (_) => <String, Object?>{
        'latitude': 1,
        'longitude': 2,
        'altitude': null,
        'accuracy': null,
        'heading': null,
        'speed': null,
        'speedAccuracy': null,
      };

      final fix = await AndroidLocationSource().currentLocation(
        timeout: timeout,
      );

      expect(fix!.latitude, 1.0);
      expect(fix.longitude, 2.0);
      expect(fix.altitude, isNull);
      expect(fix.accuracy, isNull);
      expect(fix.heading, isNull);
      expect(fix.speed, isNull);
      expect(fix.speedAccuracy, isNull);
    });

    test('answers null when the plugin has no fix to give', () async {
      answer = (_) => null;

      expect(
        await AndroidLocationSource().currentLocation(timeout: timeout),
        isNull,
      );
    });

    test('rejects a fix without coordinates', () async {
      answer = (_) => <String, Object?>{'latitude': 1};

      await expectLater(
        AndroidLocationSource().currentLocation(timeout: timeout),
        throwsA(isA<FormatException>()),
      );
    });

    test('surfaces a platform error for the caller to fall back', () async {
      answer = (_) => throw PlatformException(code: 'location_permission');

      await expectLater(
        AndroidLocationSource().currentLocation(timeout: timeout),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'location_permission',
          ),
        ),
      );
    });
  });
}
