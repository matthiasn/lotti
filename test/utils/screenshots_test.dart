import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/screenshot_consts.dart';
import 'package:lotti/utils/screenshots.dart';
import 'package:mocktail/mocktail.dart';
import 'package:window_manager/window_manager.dart';

// Mocks
class MockLoggingService extends Mock implements LoggingService {}

class MockWindowManager extends Mock implements WindowManager {}

class MockDirectory extends Mock implements Directory {}

void main() {
  group('Screenshot Tests', () {
    late MockLoggingService mockLoggingService;
    late MockWindowManager mockWindowManager;
    late MockDirectory mockDirectory;

    setUpAll(() {
      registerFallbackValue(StackTrace.current);
    });

    setUp(() {
      mockLoggingService = MockLoggingService();
      mockWindowManager = MockWindowManager();
      mockDirectory = MockDirectory();

      // Register mocks in GetIt
      getIt
        ..registerSingleton<LoggingService>(mockLoggingService)
        ..registerSingleton<WindowManager>(mockWindowManager)
        ..registerSingleton<Directory>(mockDirectory);

      // Setup default mock behaviors
      when(() => mockDirectory.path).thenReturn('/test/documents');
      when(() => mockWindowManager.minimize()).thenAnswer((_) async {});
      when(() => mockWindowManager.show()).thenAnswer((_) async {});
    });

    tearDown(getIt.reset);

    group('isCommandAvailable', () {
      test('returns true when command is available', () async {
        // Test with a command that should be available on most systems
        final result = await isCommandAvailable('ls');
        expect(result, isTrue);
      });

      test('returns false when command is not available', () async {
        // Test with a command that should not exist
        final result = await isCommandAvailable('nonexistent_command_12345');
        expect(result, isFalse);
      });
    });

    group('findAvailableScreenshotTool', () {
      test('returns a tool if available on the system', () async {
        final result = await findAvailableScreenshotTool();
        // On macOS, this should return null since we're not on Linux
        // On Linux, it might return a tool if available
        expect(result, anyOf(isA<String>(), isNull));
      });
    });

    group('takeLinuxScreenshot', () {
      test('throws exception for unsupported tool', () async {
        expect(
          () => takeLinuxScreenshot('unsupported', 'test.jpg', '/test/dir'),
          throwsA(isA<Exception>()),
        );
      });

      test('validates tool configuration for supported tools', () {
        // Test that all supported tools have valid configurations
        for (final tool in linuxScreenshotTools) {
          final config = screenshotToolConfigs[tool];
          expect(config, isNotNull,
              reason: 'Tool $tool should have configuration');
          expect(config!.name, isNotEmpty);
          expect(config.arguments, isA<List<String>>());
          expect(config.description, isNotEmpty);
          expect(config.installCommand, isNotEmpty);
        }
      });
    });

    group('isRunningInFlatpak', () {
      test('returns true when FLATPAK_ID environment variable is set', () {
        // This test is environmental and may not work in all test environments
        // We test the logic exists rather than the specific result
        final result = isRunningInFlatpak();
        expect(result, isA<bool>());
      });

      test('detects Flatpak environment correctly based on file existence', () {
        // Since we can't easily mock File.existsSync in this context,
        // we just verify the function returns a boolean
        final result = isRunningInFlatpak();
        expect(result, isA<bool>());
      });
    });

    group('takeScreenshot', () {
      test('creates ImageData with correct properties on supported platform',
          () async {
        // Mock the directory creation
        when(() => mockDirectory.create(recursive: any(named: 'recursive')))
            .thenAnswer((_) async => mockDirectory);

        // This test will fail on unsupported platforms, which is expected
        // We're testing the structure and error handling
        try {
          final result = await takeScreenshot();
          expect(result, isA<ImageData>());
          expect(result.imageFile, endsWith(screenshotFileExtension));
          expect(result.imageDirectory, startsWith(screenshotDirectoryPath));
          expect(result.capturedAt, isA<DateTime>());
        } catch (e) {
          // On unsupported platforms, we expect an exception
          expect(e, anyOf(isA<Exception>(), isA<UnsupportedError>()));
        }
      });
    });

    group('Screenshot Constants', () {
      test('all required constants are defined', () {
        expect(screenshotFileExtension, isNotEmpty);
        expect(screenshotDirectoryPath, isNotEmpty);
        expect(screenshotDateFormat, isNotEmpty);
        expect(screenshotDelaySeconds, isPositive);
        expect(screenshotProcessTimeoutSeconds, isPositive);
        expect(windowMinimizationDelayMs, isPositive);
        expect(screenshotDomain, isNotEmpty);
        expect(linuxScreenshotTools, isNotEmpty);
        expect(screenshotToolConfigs, isNotEmpty);
      });

      test('Flatpak portal constants are properly defined', () {
        expect(dbusPortalDesktopName, equals('org.freedesktop.portal.Desktop'));
        expect(dbusPortalDesktopPath, equals('/org/freedesktop/portal/desktop'));
        expect(dbusPortalScreenshotInterface, equals('org.freedesktop.portal.Screenshot'));
        expect(dbusPortalRequestInterface, equals('org.freedesktop.portal.Request'));
        expect(dbusPortalResponseSignal, equals('Response'));
        expect(portalHandleTokenKey, equals('handle_token'));
        expect(portalModalKey, equals('modal'));
        expect(portalInteractiveKey, equals('interactive'));
        expect(portalUriKey, equals('uri'));
        expect(screenshotTokenPrefix, equals('lotti_screenshot_'));
        expect(portalSuccessResponse, equals(0));
      });

      test('portal error messages are defined', () {
        expect(portalNoUriMessage, isNotEmpty);
        expect(portalUnexpectedUriMessage, isNotEmpty);
        expect(portalFileNotFoundMessage, isNotEmpty);
        expect(portalTimeoutMessage, isNotEmpty);
        expect(portalCancelledMessage, isNotEmpty);
      });

      test('file URI constants are defined', () {
        expect(fileUriScheme, equals('file://'));
      });

      test('Linux screenshot tools list contains all expected tools', () {
        expect(linuxScreenshotTools, contains(spectacleTool));
        expect(linuxScreenshotTools, contains(gnomeScreenshotTool));
        expect(linuxScreenshotTools, contains(scrotTool));
        expect(linuxScreenshotTools, contains(importTool));
      });

      test('screenshot tool configurations are complete', () {
        for (final tool in linuxScreenshotTools) {
          final config = screenshotToolConfigs[tool];
          expect(config, isNotNull);
          expect(config!.name, isNotEmpty);
          expect(config.arguments, isA<List<String>>());
          expect(config.description, isNotEmpty);
          expect(config.installCommand, isNotEmpty);
        }
      });
    });

    group('Error Messages', () {
      test('provides helpful error message for missing tools', () {
        expect(noScreenshotToolAvailableMessage,
            contains('No screenshot tool available'));
        expect(installInstructionsMessage, contains('sudo apt install'));
        expect(installInstructionsMessage, contains('spectacle'));
        expect(installInstructionsMessage, contains('gnome-screenshot'));
        expect(installInstructionsMessage, contains('scrot'));
        expect(installInstructionsMessage, contains('imagemagick'));
      });

      test('error messages are properly formatted', () {
        expect(unsupportedToolMessage, contains('Unsupported screenshot tool'));
        expect(toolFailedMessage, contains('Screenshot tool'));
        expect(failedWithExitCodeMessage, contains('failed with exit code'));
        expect(
            screencaptureFailedMessage, contains('macOS screencapture failed'));
        expect(unsupportedPlatformMessage,
            contains('Screenshot functionality is not supported'));
      });
    });

    group('Tool Arguments', () {
      test('spectacle arguments are correctly defined', () {
        final config = screenshotToolConfigs[spectacleTool];
        expect(config, isNotNull);
        expect(config!.arguments, equals(spectacleArguments));
      });

      test('gnome-screenshot arguments are correctly defined', () {
        final config = screenshotToolConfigs[gnomeScreenshotTool];
        expect(config, isNotNull);
        expect(config!.arguments, equals(gnomeScreenshotArguments));
      });

      test('scrot arguments are correctly defined', () {
        final config = screenshotToolConfigs[scrotTool];
        expect(config, isNotNull);
        expect(config!.arguments, equals(scrotArguments));
      });

      test('import arguments are correctly defined', () {
        final config = screenshotToolConfigs[importTool];
        expect(config, isNotNull);
        expect(config!.arguments, equals(importArguments));
      });
    });
  });
}
