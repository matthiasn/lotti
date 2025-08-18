import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/portals/portal_service.dart';
import 'package:lotti/services/portals/screenshot_portal_service.dart';
import 'package:mocktail/mocktail.dart';

class MockLoggingService extends Mock implements LoggingService {}

void main() {
  group('ScreenshotPortalService', () {
    late ScreenshotPortalService service;
    late MockLoggingService mockLoggingService;

    setUp(() {
      mockLoggingService = MockLoggingService();
      getIt.registerSingleton<LoggingService>(mockLoggingService);
      service = ScreenshotPortalService();
    });

    tearDown(() async {
      if (service.isInitialized) {
        await service.dispose();
      }
      await getIt.reset();
    });

    test('should detect Flatpak environment correctly', () {
      // This is a static method test - behavior depends on environment
      final shouldUse = PortalService.shouldUsePortal;
      final isLinux = Platform.isLinux;
      final hasFlatpakId = Platform.environment['FLATPAK_ID'] != null;
      
      expect(shouldUse, equals(isLinux && hasFlatpakId));
    });

    test('should initialize and dispose properly', () async {
      expect(service.isInitialized, isFalse);
      
      // Initialize should complete without error
      await service.initialize();
      expect(service.isInitialized, isTrue);
      
      // Multiple initializations should be safe
      await service.initialize();
      expect(service.isInitialized, isTrue);
      
      // Dispose should complete without error
      await service.dispose();
      expect(service.isInitialized, isFalse);
    });

    test('should throw when using uninitialized client', () {
      expect(() => service.client, throwsStateError);
    });

    group('when not in Flatpak environment', () {
      test('takeScreenshot should throw UnsupportedError', () async {
        // Mock non-Flatpak environment by checking the actual environment
        if (!PortalService.shouldUsePortal) {
          await expectLater(
            () => service.takeScreenshot(),
            throwsA(isA<UnsupportedError>()),
          );
        }
      });
    });

    group('isAvailable', () {
      test('should return false when not in Flatpak', () async {
        if (!PortalService.shouldUsePortal) {
          final available = await ScreenshotPortalService.isAvailable();
          expect(available, isFalse);
        }
      });
    });
  });
}
