import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/portals/audio_portal_service.dart';
import 'package:lotti/services/portals/portal_service.dart';
import 'package:mocktail/mocktail.dart';

class MockLoggingService extends Mock implements LoggingService {}

void main() {
  group('AudioPortalService', () {
    late AudioPortalService service;
    late MockLoggingService mockLoggingService;

    setUp(() {
      mockLoggingService = MockLoggingService();
      getIt.registerSingleton<LoggingService>(mockLoggingService);
      service = AudioPortalService();
    });

    tearDown(() async {
      if (service.isInitialized) {
        await service.dispose();
      }
      await getIt.reset();
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
      
      // Multiple initializations should be safe
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

    group('when not in Flatpak environment', () {
      test('requestMicrophoneAccess should return true (assume available)', () async {
        if (!PortalService.shouldUsePortal) {
          final hasAccess = await service.requestMicrophoneAccess();
          expect(hasAccess, isTrue);
          expect(service.hasMicrophoneAccess, isTrue);
        }
      });
    });

    group('isAvailable', () {
      test('should return true when not in Flatpak', () async {
        if (!PortalService.shouldUsePortal) {
          final available = await AudioPortalService.isAvailable();
          expect(available, isTrue);
        }
      });
    });
  });
}
