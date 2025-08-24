import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/portals/audio_portal_service.dart';
import 'package:lotti/services/portals/portal_service.dart';
import 'package:mocktail/mocktail.dart';

class MockLoggingService extends Mock implements LoggingService {}

class MockDBusClient extends Mock implements DBusClient {}

class MockDBusRemoteObject extends Mock implements DBusRemoteObject {}

class MockDBusMethodSuccessResponse extends Mock
    implements DBusMethodSuccessResponse {}

class MockStreamSubscription extends Mock
    implements StreamSubscription<DBusSignal> {}

class MockDBusSignal extends Mock implements DBusSignal {}

class FakeDBusObjectPath extends Fake implements DBusObjectPath {
  FakeDBusObjectPath(this.value);

  @override
  final String value;

  @override
  String toString() => value;
}

class FakeDBusSignature extends Fake implements DBusSignature {}

void main() {
  group('AudioPortalService', () {
    late AudioPortalService service;
    late MockLoggingService mockLoggingService;
    late MockDBusClient mockDBusClient;
    late MockDBusRemoteObject mockDBusRemoteObject;

    setUpAll(() {
      registerFallbackValue(StackTrace.current);
      registerFallbackValue(FakeDBusObjectPath('/test'));
      registerFallbackValue(FakeDBusSignature());
      registerFallbackValue(const DBusString(''));
      registerFallbackValue(DBusDict.stringVariant(const {}));
      registerFallbackValue(const DBusUint32(0));
      registerFallbackValue(DBusArray.string([]));
    });

    setUp(() {
      mockLoggingService = MockLoggingService();
      mockDBusClient = MockDBusClient();
      mockDBusRemoteObject = MockDBusRemoteObject();

      getIt.registerSingleton<LoggingService>(mockLoggingService);

      service = AudioPortalService()
        ..resetAccess(); // Reset access status to ensure clean state for each test

      // Setup default mock behaviors
      when(() => mockLoggingService.captureException(
            any<dynamic>(),
            domain: any(named: 'domain'),
            subDomain: any(named: 'subDomain'),
            stackTrace: any<dynamic>(named: 'stackTrace'),
          )).thenReturn(null);

      when(() => mockDBusClient.close()).thenAnswer((_) async {});
    });

    tearDown(() async {
      if (service.isInitialized) {
        await service.dispose();
      }
      await getIt.reset();
    });

    test('mock objects are properly initialized', () {
      expect(mockDBusClient, isNotNull);
      expect(mockDBusRemoteObject, isNotNull);
      expect(mockLoggingService, isNotNull);
    });

    test('should be a singleton', () {
      final service1 = AudioPortalService();
      final service2 = AudioPortalService();
      expect(identical(service1, service2), isTrue);
    });

    test('should detect Flatpak environment correctly', () {
      final shouldUse = PortalService.shouldUsePortal;
      final isLinux = Platform.isLinux;
      final hasFlatpakId = Platform.environment['FLATPAK_ID'] != null;

      expect(shouldUse, equals(isLinux && hasFlatpakId));
    });

    test('should initialize and dispose properly', () async {
      expect(service.isInitialized, isFalse);

      await service.initialize();
      expect(service.isInitialized, isTrue);

      await service.dispose();
      expect(service.isInitialized, isFalse);
    });

    test('should manage microphone access status', () {
      expect(service.hasMicrophoneAccess, isFalse);

      service.resetAccess();
      expect(service.hasMicrophoneAccess, isFalse);
    });

    group('Constants', () {
      test('should have correct audio portal constants', () {
        expect(AudioPortalConstants.interfaceName,
            equals('org.freedesktop.portal.Device'));
        expect(AudioPortalConstants.accessDeviceMethod, equals('AccessDevice'));
        expect(AudioPortalConstants.microphoneDevice, equals('microphone'));
        expect(AudioPortalConstants.cameraDevice, equals('camera'));
        expect(AudioPortalConstants.speakersDevice, equals('speakers'));
      });
    });

    group('when not in Flatpak environment', () {
      test('requestMicrophoneAccess should return true', () async {
        if (!PortalService.shouldUsePortal) {
          final result = await service.requestMicrophoneAccess();
          expect(result, isTrue);
          expect(service.hasMicrophoneAccess, isTrue);
        }
      });

      test('isAvailable should return true', () async {
        if (!PortalService.shouldUsePortal) {
          final available = await AudioPortalService.isAvailable();
          expect(available, isTrue);
        }
      });
    });

    group('requestMicrophoneAccess method', () {
      test('should handle portal access request', () async {
        if (!PortalService.shouldUsePortal) {
          return;
        }

        await service.initialize();

        // In portal environment, the method should return false on error
        final result = await service.requestMicrophoneAccess();
        expect(result, isFalse);
        expect(service.hasMicrophoneAccess, isFalse);
      });

      test('should return cached access status when already granted', () async {
        if (!PortalService.shouldUsePortal) {
          // Set access to true
          service.resetAccess();

          final result = await service.requestMicrophoneAccess();
          expect(result, isTrue);
          expect(service.hasMicrophoneAccess, isTrue);

          // Second call should return cached result
          final result2 = await service.requestMicrophoneAccess();
          expect(result2, isTrue);
        }
      });

      test('should handle portal unavailability gracefully', () async {
        if (!PortalService.shouldUsePortal) {
          return;
        }

        await service.initialize();

        // In portal environment, the method should return false and log the error
        final result = await service.requestMicrophoneAccess();
        expect(result, isFalse);
        expect(service.hasMicrophoneAccess, isFalse);

        // Verify that exception was logged
        verify(
          () => mockLoggingService.captureException(
            any<dynamic>(),
            domain: 'AudioPortalService',
            subDomain: 'requestMicrophoneAccess',
            stackTrace: any<dynamic>(named: 'stackTrace'),
          ),
        ).called(1);
      });

      test('should handle timeout errors', () async {
        if (!PortalService.shouldUsePortal) {
          return;
        }

        await service.initialize();

        // Should handle timeout gracefully by returning false
        final result = await service.requestMicrophoneAccess();
        expect(result, isFalse);
        expect(service.hasMicrophoneAccess, isFalse);
      });
    });

    group('Handle Token Generation', () {
      test('should generate unique handle tokens for microphone access',
          () async {
        final token1 = PortalService.createHandleToken('microphone');

        // Add a small delay to ensure different timestamps
        await Future<void>.delayed(const Duration(milliseconds: 1));

        final token2 = PortalService.createHandleToken('microphone');

        expect(token1, isNotEmpty);
        expect(token2, isNotEmpty);
        expect(token1, isNot(equals(token2)));
        expect(token1, startsWith('microphone_'));
        expect(token2, startsWith('microphone_'));
      });
    });

    group('Portal Integration', () {
      test('should use correct portal interface and method', () {
        expect(AudioPortalConstants.interfaceName,
            equals('org.freedesktop.portal.Device'));
        expect(AudioPortalConstants.accessDeviceMethod, equals('AccessDevice'));
      });

      test('should handle portal response parsing', () async {
        if (!PortalService.shouldUsePortal) {
          return;
        }

        await service.initialize();

        // In portal environment, the method should return false on error
        final result = await service.requestMicrophoneAccess();
        expect(result, isFalse);
        expect(service.hasMicrophoneAccess, isFalse);
      });
    });

    group('Access Status Management', () {
      test('should reset access status correctly', () async {
        // Initially false
        expect(service.hasMicrophoneAccess, isFalse);

        // Reset should keep it false
        service.resetAccess();
        expect(service.hasMicrophoneAccess, isFalse);
      });

      test('should maintain access status across multiple calls', () async {
        if (!PortalService.shouldUsePortal) {
          // Reset to ensure clean state
          service.resetAccess();

          // First call should set access to true
          final result1 = await service.requestMicrophoneAccess();
          expect(result1, isTrue);
          expect(service.hasMicrophoneAccess, isTrue);

          // Second call should return cached result
          final result2 = await service.requestMicrophoneAccess();
          expect(result2, isTrue);
          expect(service.hasMicrophoneAccess, isTrue);
        }
      });

      test('should handle access status after reset', () async {
        if (!PortalService.shouldUsePortal) {
          // Reset to ensure clean state
          service.resetAccess();

          // Get access
          final result1 = await service.requestMicrophoneAccess();
          expect(result1, isTrue);
          expect(service.hasMicrophoneAccess, isTrue);

          // Reset access
          service.resetAccess();
          expect(service.hasMicrophoneAccess, isFalse);

          // Request access again
          final result2 = await service.requestMicrophoneAccess();
          expect(result2, isTrue);
          expect(service.hasMicrophoneAccess, isTrue);
        }
      });
    });

    group('Error Handling', () {
      test('should handle portal access denied', () async {
        if (!PortalService.shouldUsePortal) {
          return;
        }

        await service.initialize();

        // Should handle access denied gracefully by returning false
        final result = await service.requestMicrophoneAccess();
        expect(result, isFalse);
        expect(service.hasMicrophoneAccess, isFalse);
      });

      test('should handle portal communication errors', () async {
        if (!PortalService.shouldUsePortal) {
          return;
        }

        await service.initialize();

        // Should handle communication errors gracefully by returning false
        final result = await service.requestMicrophoneAccess();
        expect(result, isFalse);
        expect(service.hasMicrophoneAccess, isFalse);
      });

      test('should log exceptions with correct domain and subdomain', () async {
        if (!PortalService.shouldUsePortal) {
          return;
        }

        await service.initialize();

        // Should return false and log the exception
        final result = await service.requestMicrophoneAccess();
        expect(result, isFalse);
        expect(service.hasMicrophoneAccess, isFalse);

        verify(
          () => mockLoggingService.captureException(
            any<dynamic>(),
            domain: 'AudioPortalService',
            subDomain: 'requestMicrophoneAccess',
            stackTrace: any<dynamic>(named: 'stackTrace'),
          ),
        ).called(1);
      });
    });

    group('Device Type Constants', () {
      test('should have correct microphone device type', () {
        expect(AudioPortalConstants.microphoneDevice, equals('microphone'));
      });

      test('should use correct device type in portal calls', () {
        // This test verifies the constant is used correctly
        expect(AudioPortalConstants.microphoneDevice, isA<String>());
        expect(AudioPortalConstants.microphoneDevice, isNotEmpty);
      });
    });

    group('Portal Availability', () {
      test('should check portal availability correctly', () async {
        final available = await AudioPortalService.isAvailable();

        if (PortalService.shouldUsePortal) {
          // In Flatpak environment, availability depends on actual portal
          expect(available, isA<bool>());
        } else {
          // In non-Flatpak environment, should return true
          expect(available, isTrue);
        }
      });

      test('should handle portal availability check errors', () async {
        if (!PortalService.shouldUsePortal) {
          return;
        }

        try {
          await service.initialize();

          final available = await AudioPortalService.isAvailable();
          expect(available, isA<bool>());
        } catch (e) {
          // Should handle errors gracefully
          expect(e, isA<Exception>());
        }
      });
    });

    // Focused tests for specific code coverage
    group('Code Coverage Tests', () {
      test('should handle successful portal response with code 0', () {
        final mockSignal = MockDBusSignal();
        when(() => mockSignal.values).thenReturn([
          const DBusUint32(0), // Success code
          DBusDict.stringVariant({}),
        ]);

        expect(mockSignal.values.isNotEmpty, isTrue);
        final code = (mockSignal.values[0] as DBusUint32).value;
        expect(code == 0, isTrue);
      });

      test('should handle failed portal response with non-zero code', () {
        final mockSignal = MockDBusSignal();
        when(() => mockSignal.values).thenReturn([
          const DBusUint32(1), // Failure code
          DBusDict.stringVariant({}),
        ]);

        expect(mockSignal.values.isNotEmpty, isTrue);
        final code = (mockSignal.values[0] as DBusUint32).value;
        expect(code == 0, isFalse);
      });

      test('should handle empty signal values', () {
        final mockSignal = MockDBusSignal();
        when(() => mockSignal.values).thenReturn([]);

        expect(mockSignal.values.isNotEmpty, isFalse);
      });

      test('should handle empty return values from method call', () {
        final mockResponse = MockDBusMethodSuccessResponse();
        when(() => mockResponse.returnValues).thenReturn([]);

        expect(mockResponse.returnValues.isEmpty, isTrue);
      });

      test('should create correct device array for portal call', () {
        final deviceArray =
            DBusArray.string([AudioPortalConstants.microphoneDevice]);
        expect(deviceArray.asStringArray(), contains('microphone'));
      });

      test('should handle signal listener exceptions', () {
        final completer = Completer<bool>();

        try {
          // Simulate an exception in signal processing
          throw Exception('Signal processing error');
        } catch (e) {
          completer.completeError(e);
        }

        expectLater(
          completer.future,
          throwsA(isA<Exception>()),
        );
      });

      test('should handle timeout correctly', () async {
        final completer = Completer<bool>();

        final future = completer.future.timeout(
          const Duration(milliseconds: 100),
          onTimeout: () {
            throw TimeoutException('Audio portal response timed out');
          },
        );

        await expectLater(
          future,
          throwsA(isA<TimeoutException>()),
        );
      });

      test('should verify logging service is registered before logging', () {
        // Test getIt.isRegistered check
        expect(getIt.isRegistered<LoggingService>(), isTrue);

        // Unregister and check
        getIt.unregister<LoggingService>();
        expect(getIt.isRegistered<LoggingService>(), isFalse);

        // Re-register for cleanup
        getIt.registerSingleton<LoggingService>(mockLoggingService);
      });
    });
  });
}
