import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/portals/portal_service.dart';
import 'package:mocktail/mocktail.dart';

class MockLoggingService extends Mock implements LoggingService {}

// Test implementation of PortalService for testing abstract class
class TestPortalService extends PortalService {
  @override
  Future<void> initialize() async {
    await super.initialize();
  }

  @override
  Future<void> dispose() async {
    await super.dispose();
  }
}

void main() {
  group('PortalService', () {
    late TestPortalService service;
    late MockLoggingService mockLoggingService;

    setUp(() {
      mockLoggingService = MockLoggingService();

      getIt.registerSingleton<LoggingService>(mockLoggingService);
      service = TestPortalService();
    });

    tearDown(() async {
      if (service.isInitialized) {
        await service.dispose();
      }
      await getIt.reset();
    });

    group('Environment Detection', () {
      test('shouldUsePortal matches isRunningInFlatpak on Linux', () {
        final shouldUse = PortalService.shouldUsePortal;
        final isLinux = Platform.isLinux;
        final hasFlatpakId = Platform.environment['FLATPAK_ID'] != null &&
            Platform.environment['FLATPAK_ID']!.isNotEmpty;

        expect(shouldUse, equals(isLinux && hasFlatpakId));
      });

      test('isRunningInFlatpak returns correct value based on environment', () {
        final isRunning = PortalService.isRunningInFlatpak;
        final isLinux = Platform.isLinux;
        final hasFlatpakId = Platform.environment['FLATPAK_ID'] != null &&
            Platform.environment['FLATPAK_ID']!.isNotEmpty;

        expect(isRunning, equals(isLinux && hasFlatpakId));
      });
    });

    group('Initialization', () {
      test('should handle initialization when shouldUsePortal is false',
          () async {
        // Test in non-Flatpak environment
        expect(service.isInitialized, isFalse);

        await service.initialize();

        expect(service.isInitialized, isTrue);
        // Should throw StateError when accessing client in non-Flatpak mode
        expect(() => service.client, throwsStateError);
      });

      test('should handle multiple initializations safely', () async {
        expect(service.isInitialized, isFalse);

        await service.initialize();
        expect(service.isInitialized, isTrue);

        // Second initialization should not cause issues
        await service.initialize();
        expect(service.isInitialized, isTrue);
      });
    });

    group('Disposal', () {
      test('should dispose successfully when initialized', () async {
        expect(service.isInitialized, isFalse);

        await service.initialize();
        expect(service.isInitialized, isTrue);

        await service.dispose();
        expect(service.isInitialized, isFalse);
      });

      test('should handle disposal when not initialized', () async {
        expect(service.isInitialized, isFalse);

        await expectLater(service.dispose(), completes);
        expect(service.isInitialized, isFalse);
      });

      test('should handle multiple disposals safely', () async {
        await service.initialize();
        await service.dispose();
        expect(service.isInitialized, isFalse);

        // Second disposal should not cause issues
        await service.dispose();
        expect(service.isInitialized, isFalse);
      });
    });

    group('Client Access', () {
      test('should throw StateError when accessing uninitialized client', () {
        expect(() => service.client, throwsStateError);
      });

      test('should throw StateError when accessing client outside Flatpak',
          () async {
        await service.initialize();
        expect(() => service.client, throwsStateError);
      });
    });

    group('Portal Object Creation', () {
      test(
          'should create portal object with correct parameters when in Flatpak',
          () async {
        // This test will only work in actual Flatpak environment
        // In test environment, it will throw, which is expected
        try {
          await service.initialize();
          final object = service.createPortalObject();
          expect(object, isA<DBusRemoteObject>());
        } catch (e) {
          // Expected in non-Flatpak test environment
          expect(e, isA<StateError>());
        }
      });
    });

    group('Handle Token Generation', () {
      test('should generate unique handle tokens', () async {
        final token1 = PortalService.createHandleToken('test');

        // Add a longer delay to ensure different timestamps
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final token2 = PortalService.createHandleToken('test');

        expect(token1, isNotEmpty);
        expect(token2, isNotEmpty);
        expect(token1, isNot(equals(token2)));
        expect(token1, startsWith('test_'));
        expect(token2, startsWith('test_'));
      });

      test('should include timestamp in handle tokens', () {
        final token = PortalService.createHandleToken('prefix');
        final parts = token.split('_');

        expect(parts.length, equals(2));
        expect(parts[0], equals('prefix'));
        expect(int.tryParse(parts[1]), isNotNull);
      });

      test('should generate different tokens for different prefixes', () {
        final token1 = PortalService.createHandleToken('prefix1');
        final token2 = PortalService.createHandleToken('prefix2');

        expect(token1, startsWith('prefix1_'));
        expect(token2, startsWith('prefix2_'));
        expect(token1, isNot(equals(token2)));
      });
    });

    group('Interface Availability', () {
      test(
          'should return false for ScreenshotPortalService when not in Flatpak',
          () async {
        final available = await PortalService.isInterfaceAvailable(
          'org.freedesktop.portal.Screenshot',
          service,
          'ScreenshotPortalService',
        );

        expect(available, isFalse);
      });

      test('should return true for AudioPortalService when not in Flatpak',
          () async {
        final available = await PortalService.isInterfaceAvailable(
          'org.freedesktop.portal.Device',
          service,
          'AudioPortalService',
        );

        expect(available, isTrue);
      });

      test('should handle interface availability check errors gracefully',
          () async {
        // This will fail in test environment, but we can test error handling
        final available = await PortalService.isInterfaceAvailable(
          'org.freedesktop.portal.Screenshot',
          service,
          'ScreenshotPortalService',
        );

        // Should return false on error
        expect(available, isFalse);
      });

      test('should handle interface availability check for unknown service',
          () async {
        final available = await PortalService.isInterfaceAvailable(
          'org.freedesktop.portal.Unknown',
          service,
          'UnknownService',
        );

        // Should return false for unknown service
        expect(available, isFalse);
      });
    });

    group('Constants', () {
      test('should have correct portal constants', () {
        expect(PortalConstants.portalBusName,
            equals('org.freedesktop.portal.Desktop'));
        expect(PortalConstants.portalPath,
            equals('/org/freedesktop/portal/desktop'));
        expect(PortalConstants.responseTimeout,
            equals(const Duration(seconds: 30)));
      });
    });
  });
}
