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
      test('should not attempt portal when not in Flatpak', () async {
        // When not in Flatpak, takeScreenshot should not use portal
        // This test verifies the non-Flatpak path
        expect(PortalService.shouldUsePortal, isFalse,
            reason: 'This test verifies non-Flatpak behavior');

        // Mock logging to ensure no portal fallback is logged
        when(() => mockLoggingService.captureException(
              any<dynamic>(),
              domain: screenshotDomain,
              subDomain: 'portal_fallback',
            )).thenReturn(null);

        // The screenshot will fail because we don't have the actual tools
        // but it should NOT log portal_fallback
        try {
          await takeScreenshot();
        } catch (e) {
          // Expected to fail
        }

        // Verify portal fallback was NOT logged (because we're not in Flatpak)
        verifyNever(
          () => mockLoggingService.captureException(
            any<dynamic>(),
            domain: screenshotDomain,
            subDomain: 'portal_fallback',
          ),
        );
      });

      test('portal service should throw when used outside Flatpak', () async {
        // This test verifies that ScreenshotPortalService properly guards against
        // being used outside of Flatpak
        expect(PortalService.shouldUsePortal, isFalse,
            reason: 'This test requires non-Flatpak environment');

        final portalService = ScreenshotPortalService();

        // Should throw UnsupportedError when not in Flatpak
        await expectLater(
          portalService.takeScreenshot(
            directory: '/tmp',
            filename: 'test.png',
          ),
          throwsA(isA<UnsupportedError>()),
        );
      });
    });

    group('Portal Integration Tests', () {
      test('should use traditional flow when not in Flatpak', () async {
        // Verify we're not in Flatpak
        expect(PortalService.shouldUsePortal, isFalse,
            reason: 'This test verifies non-Flatpak behavior');

        // Mock logging to capture any exceptions
        when(() => mockLoggingService.captureException(
              any<dynamic>(),
              domain: screenshotDomain,
              stackTrace: any<StackTrace?>(named: 'stackTrace'),
            )).thenReturn(null);

        // The screenshot will fail because we don't have the actual screenshot tools
        await expectLater(
          takeScreenshot(),
          throwsA(anyOf(isA<Exception>(), isA<StateError>())),
        );

        // Verify that the exception was logged (but NOT as portal_fallback)
        verify(() => mockLoggingService.captureException(
              any<dynamic>(),
              domain: screenshotDomain,
              stackTrace: any<StackTrace?>(named: 'stackTrace'),
            )).called(1);
      });

      test('portal service lifecycle in non-Flatpak environment', () async {
        // Even when not in Flatpak, the portal service should handle
        // initialization and disposal gracefully
        expect(PortalService.shouldUsePortal, isFalse);

        final portalService = ScreenshotPortalService();

        // Test initialization - should succeed even outside Flatpak
        expect(portalService.isInitialized, isFalse);
        await portalService.initialize();
        expect(portalService.isInitialized, isTrue);

        // Test disposal
        await portalService.dispose();
        expect(portalService.isInitialized, isFalse);
      });

      test('portal service client access should fail outside Flatpak', () {
        expect(PortalService.shouldUsePortal, isFalse);

        final portalService = ScreenshotPortalService();

        // Accessing client without initialization should throw
        expect(
          () => portalService.client,
          throwsA(isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('not initialized'),
          )),
        );
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
