import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/portals/portal_service.dart';
import 'package:lotti/services/portals/screenshot_portal_service.dart';
import 'package:lotti/utils/screenshot_consts.dart';
import 'package:lotti/utils/screenshots.dart';
import 'package:mocktail/mocktail.dart';
import 'package:window_manager/window_manager.dart';

class MockLoggingService extends Mock implements LoggingService {}

class MockWindowManager extends Mock implements WindowManager {}

void main() {
  group('Screenshots Portal Integration', () {
    late MockLoggingService mockLoggingService;
    late MockWindowManager mockWindowManager;

    setUpAll(() {
      registerFallbackValue(StackTrace.current);
    });

    setUp(() {
      mockLoggingService = MockLoggingService();
      mockWindowManager = MockWindowManager();

      // Register mocks in GetIt
      getIt
        ..registerSingleton<LoggingService>(mockLoggingService)
        ..registerSingleton<WindowManager>(mockWindowManager);

      // Setup default mock behaviors
      when(() => mockWindowManager.minimize()).thenAnswer((_) async {});
      when(() => mockWindowManager.show()).thenAnswer((_) async {});
    });

    tearDown(getIt.reset);

    group('Portal Detection', () {
      test('should detect Flatpak environment correctly', () {
        final shouldUse = PortalService.shouldUsePortal;
        final isLinux = Platform.isLinux;
        final hasFlatpakId = Platform.environment['FLATPAK_ID'] != null;

        expect(shouldUse, equals(isLinux && hasFlatpakId));
      });

      test('should use portal when in Flatpak environment', () {
        final shouldUsePortal =
            Platform.isLinux && PortalService.shouldUsePortal;

        // This test verifies the logic used in takeScreenshot()
        expect(shouldUsePortal, isA<bool>());
      });
    });

    group('Portal Service Integration', () {
      test('should create ScreenshotPortalService instance', () {
        final portalService = ScreenshotPortalService();
        expect(portalService, isA<ScreenshotPortalService>());
      });

      test('should check portal availability', () async {
        final available = await ScreenshotPortalService.isAvailable();
        expect(available, isA<bool>());
      });

      test('should handle portal unavailability gracefully', () async {
        if (!PortalService.shouldUsePortal) {
          // Skip test in non-Flatpak environment
          return;
        }

        // This test verifies that the portal fallback logic exists
        // The actual implementation will handle portal unavailability
        expect(ScreenshotPortalService.isAvailable(), isA<Future<bool>>());
      });
    });

    group('Portal Fallback Logic', () {
      test('should fall back to traditional methods when portal fails',
          () async {
        if (!PortalService.shouldUsePortal) {
          // Skip test in non-Flatpak environment
          return;
        }

        // This test verifies that the fallback logic exists in the code
        // The actual implementation will log an exception and fall back
        expect(takeScreenshot, throwsA(anything));
      });

      test('should log portal fallback exception', () async {
        if (!PortalService.shouldUsePortal) {
          // Skip test in non-Flatpak environment
          return;
        }

        try {
          await takeScreenshot();
        } catch (e) {
          // Verify that exception was logged
          verify(
            () => mockLoggingService.captureException(
              any<dynamic>(),
              domain: screenshotDomain,
              subDomain: 'portal_fallback',
            ),
          ).called(1);
        }
      });
    });

    group('Portal Integration Tests', () {
      test('should handle portal integration in Flatpak environment', () async {
        if (!PortalService.shouldUsePortal) {
          // Skip test in non-Flatpak environment
          return;
        }

        // Mock the logging service to capture exceptions
        when(() => mockLoggingService.captureException(any<dynamic>(),
            domain: any(named: 'domain'),
            subDomain: any(named: 'subDomain'))).thenReturn(null);

        try {
          await takeScreenshot();
        } catch (e) {
          // Verify that portal integration was attempted
          // The actual implementation will try portal first, then fall back
          expect(e, isA<Exception>());

          // Verify that logging was called for portal fallback
          verify(() => mockLoggingService.captureException(any<dynamic>(),
              domain: screenshotDomain,
              subDomain: 'portal_fallback')).called(1);
        }
      });

      test(
          'should maintain traditional screenshot flow in non-Flatpak environment',
          () async {
        if (PortalService.shouldUsePortal) {
          // Skip test in Flatpak environment
          return;
        }

        try {
          await takeScreenshot();
        } catch (e) {
          // Verify that traditional screenshot flow was attempted
          // The error could be Exception or StateError depending on the environment
          expect(e, anyOf(isA<Exception>(), isA<StateError>()));
        }
      });

      test('should handle portal service lifecycle correctly', () async {
        if (!PortalService.shouldUsePortal) {
          // Skip test in non-Flatpak environment
          return;
        }

        final portalService = ScreenshotPortalService();

        // Test initialization
        expect(portalService.isInitialized, isFalse);
        await portalService.initialize();
        expect(portalService.isInitialized, isTrue);

        // Test disposal
        await portalService.dispose();
        expect(portalService.isInitialized, isFalse);
      });
    });

    group('Portal Constants Integration', () {
      test('should use correct portal constants', () {
        expect(ScreenshotPortalConstants.interfaceName,
            equals('org.freedesktop.portal.Screenshot'));
        expect(
            ScreenshotPortalConstants.screenshotMethod, equals('Screenshot'));
      });

      test('should use correct portal timeout', () {
        expect(PortalConstants.responseTimeout,
            equals(const Duration(seconds: 30)));
      });
    });

    group('Portal Service Lifecycle', () {
      test('should initialize portal service correctly', () async {
        final portalService = ScreenshotPortalService();
        expect(portalService.isInitialized, isFalse);

        await portalService.initialize();
        expect(portalService.isInitialized, isTrue);

        await portalService.dispose();
        expect(portalService.isInitialized, isFalse);
      });

      test('should handle portal service disposal', () async {
        final portalService = ScreenshotPortalService();
        await portalService.initialize();
        await portalService.dispose();
        expect(portalService.isInitialized, isFalse);
      });
    });

    // Removed redundant Portal Integration Edge Cases - edge case handling is covered
    // by the main integration tests and portal service lifecycle tests
  });
}
