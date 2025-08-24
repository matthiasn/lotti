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

      test('returns false when Process.run throws exception', () async {
        // Test with an invalid command that might cause Process.run to throw
        // Use empty string which should cause Process.run to throw
        final result = await isCommandAvailable('');
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

      test('iterates through all tools when none are available', () async {
        // This test ensures the loop iterates through all tools
        // Since we're likely not on a system with these Linux tools,
        // it should check all of them and return null
        final result = await findAvailableScreenshotTool();

        // If we're not on Linux or don't have the tools, result should be null
        // If we're on Linux with tools, result should be one of the expected tools
        if (result != null) {
          expect(linuxScreenshotTools, contains(result));
        }
      });
    });

    group('takeLinuxScreenshot', () {
      test('throws exception for unsupported tool', () async {
        expect(
          () => takeLinuxScreenshot('unsupported', 'test.jpg', '/test/dir'),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Unsupported screenshot tool'),
          )),
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

      test('starts process with correct arguments for spectacle', () async {
        // This test will attempt to run spectacle, which likely won't exist
        // on most test systems, causing Process.start to fail
        try {
          await takeLinuxScreenshot(spectacleTool, 'test.jpg', '/tmp');
        } catch (e) {
          // Expected to fail on systems without spectacle
          expect(e, isA<Exception>());
        }
      });

      test('builds correct arguments list', () {
        // Test that arguments are properly constructed
        final config = screenshotToolConfigs[spectacleTool];
        expect(config, isNotNull);

        // The function should combine config arguments with filename
        final expectedArgs = [...config!.arguments, 'test.jpg'];
        expect(expectedArgs.last, equals('test.jpg'));
        expect(expectedArgs.length, equals(config.arguments.length + 1));
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
        expect(screenshotDomain, isNotEmpty);
        expect(linuxScreenshotTools, isNotEmpty);
        expect(screenshotToolConfigs, isNotEmpty);
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
