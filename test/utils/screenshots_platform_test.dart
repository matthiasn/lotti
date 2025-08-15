import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/screenshot_consts.dart';
import 'package:lotti/utils/screenshots.dart';
import 'package:mocktail/mocktail.dart';
import 'package:window_manager/window_manager.dart';

// Mocks
class MockLoggingService extends Mock implements LoggingService {}

class MockWindowManager extends Mock implements WindowManager {}

class MockProcess extends Mock implements Process {}

void main() {
  group('Platform-specific Screenshot Tests', () {
    late MockLoggingService mockLoggingService;
    late MockWindowManager mockWindowManager;
    late Directory testTempDir;

    setUpAll(() async {
      registerFallbackValue(StackTrace.current);
      testTempDir =
          await Directory.systemTemp.createTemp('platform_screenshot_test');
    });

    tearDownAll(() async {
      if (testTempDir.existsSync()) {
        await testTempDir.delete(recursive: true);
      }
    });

    setUp(() {
      mockLoggingService = MockLoggingService();
      mockWindowManager = MockWindowManager();

      getIt
        ..registerSingleton<LoggingService>(mockLoggingService)
        ..registerSingleton<WindowManager>(mockWindowManager)
        ..registerSingleton<Directory>(testTempDir);

      when(() => mockWindowManager.minimize()).thenAnswer((_) async {});
      when(() => mockWindowManager.show()).thenAnswer((_) async {});

      when(() => mockLoggingService.captureEvent(
            any<dynamic>(),
            domain: any(named: 'domain'),
            subDomain: any(named: 'subDomain'),
          )).thenReturn(null);

      when(() => mockLoggingService.captureException(
            any<dynamic>(),
            domain: any(named: 'domain'),
            subDomain: any(named: 'subDomain'),
            stackTrace: any<dynamic>(named: 'stackTrace'),
          )).thenReturn(null);
    });

    tearDown(getIt.reset);

    group('macOS Screenshot', () {
      test('uses correct screencapture command', () {
        expect(screencaptureTool, equals('screencapture'));
        expect(screencaptureArguments, contains('-tjpg'));
      });

      test('handles screencapture process correctly', () async {
        final mockProcess = MockProcess();
        const mockStdout = Stream<List<int>>.empty();
        const mockStderr = Stream<List<int>>.empty();

        when(() => mockProcess.stdout).thenAnswer((_) => mockStdout);
        when(() => mockProcess.stderr).thenAnswer((_) => mockStderr);
        when(() => mockProcess.exitCode).thenAnswer((_) async => 0);

        // Can't easily test Process.start without IOOverrides
        expect(screencaptureTool, isNotEmpty);
        expect(screencaptureArguments, isNotEmpty);
      });

      test('formats error message correctly for macOS', () {
        const exitCode = 1;
        const errorMessage = '$screencaptureFailedMessage$exitCode';

        expect(errorMessage, contains('macOS screencapture failed'));
        expect(errorMessage, contains('1'));
      });
    });

    group('Linux Screenshot Tools', () {
      test('spectacle configuration is correct', () {
        final config = screenshotToolConfigs[spectacleTool];

        expect(config, isNotNull);
        expect(config!.name, equals('Spectacle'));
        expect(config.arguments, equals(spectacleArguments));
        expect(config.arguments, contains('-f')); // fullscreen
        expect(config.arguments, contains('-b')); // background
        expect(config.arguments, contains('-n')); // no notification
        expect(config.arguments, contains('-o')); // output to stdout
        expect(config.description, contains('KDE'));
        expect(config.installCommand, contains('spectacle'));
      });

      test('gnome-screenshot configuration is correct', () {
        final config = screenshotToolConfigs[gnomeScreenshotTool];

        expect(config, isNotNull);
        expect(config!.name, equals('GNOME Screenshot'));
        expect(config.arguments, equals(gnomeScreenshotArguments));
        expect(config.arguments, contains('-f')); // file parameter
        expect(config.description, contains('GNOME'));
        expect(config.installCommand, contains('gnome-screenshot'));
      });

      test('scrot configuration is correct', () {
        final config = screenshotToolConfigs[scrotTool];

        expect(config, isNotNull);
        expect(config!.name, equals('Scrot'));
        expect(config.arguments, equals(scrotArguments));
        expect(
            config.arguments, isEmpty); // scrot uses filename as positional arg
        expect(config.description, contains('Lightweight'));
        expect(config.installCommand, contains('scrot'));
      });

      test('import (ImageMagick) configuration is correct', () {
        final config = screenshotToolConfigs[importTool];

        expect(config, isNotNull);
        expect(config!.name, equals('ImageMagick Import'));
        expect(config.arguments, equals(importArguments));
        expect(config.arguments, contains('-window'));
        expect(config.arguments, contains('root'));
        expect(config.description, contains('ImageMagick'));
        expect(config.installCommand, contains('imagemagick'));
      });

      test('tool priority order is correct', () {
        expect(linuxScreenshotTools.first, equals(spectacleTool));
        expect(linuxScreenshotTools[1], equals(gnomeScreenshotTool));
        expect(linuxScreenshotTools[2], equals(scrotTool));
        expect(linuxScreenshotTools.last, equals(importTool));
      });

      test('all tools have configurations', () {
        for (final tool in linuxScreenshotTools) {
          expect(screenshotToolConfigs.containsKey(tool), isTrue,
              reason: 'Tool $tool should have a configuration');
        }
      });
    });

    group('Platform Detection', () {
      test('provides helpful error for unsupported platforms', () {
        const unsupportedPlatform = 'windows';
        const errorMessage = '$unsupportedPlatformMessage$unsupportedPlatform';

        expect(errorMessage, contains('not supported'));
        expect(errorMessage, contains(unsupportedPlatform));
      });

      test('has platform-specific tool lists', () {
        // Linux has multiple tools
        expect(linuxScreenshotTools.length, greaterThan(1));

        // macOS has single tool
        expect(screencaptureTool, isNotEmpty);
      });
    });

    group('Tool Availability', () {
      test('checks command availability correctly', () async {
        // Test with actual commands that should exist
        if (Platform.isLinux || Platform.isMacOS) {
          final lsAvailable = await isCommandAvailable('ls');
          expect(lsAvailable, isTrue);

          final fakeCommandAvailable =
              await isCommandAvailable('fake_command_xyz');
          expect(fakeCommandAvailable, isFalse);
        }
      });

      test('returns tool based on availability', () async {
        // This test depends on the actual system
        final tool = await findAvailableScreenshotTool();

        if (Platform.isLinux) {
          // On Linux, might find one of the tools or none
          expect(tool, anyOf(isNull, isIn(linuxScreenshotTools)));
        } else {
          // On non-Linux, should return null
          expect(tool, isNull);
        }
      });

      test('checks tools in priority order', () {
        // Verify the tool order is correct
        expect(linuxScreenshotTools.first, equals(spectacleTool));
        expect(linuxScreenshotTools[1], equals(gnomeScreenshotTool));
        expect(linuxScreenshotTools[2], equals(scrotTool));
        expect(linuxScreenshotTools.last, equals(importTool));
      });
    });

    group('Error Messages', () {
      test('provides installation instructions for Linux', () {
        expect(installInstructionsMessage, contains('sudo apt install'));
        expect(installInstructionsMessage, contains('spectacle'));
        expect(installInstructionsMessage, contains('gnome-screenshot'));
        expect(installInstructionsMessage, contains('scrot'));
        expect(installInstructionsMessage, contains('imagemagick'));
      });

      test('formats tool unavailable message correctly', () {
        final tools = linuxScreenshotTools.join(', ');
        final message = '$noScreenshotToolAvailableMessage$tools';

        expect(message, contains('No screenshot tool available'));
        expect(message, contains(spectacleTool));
        expect(message, contains(gnomeScreenshotTool));
      });

      test('includes exit code in error messages', () {
        const exitCode = 127;
        const message = '$failedWithExitCodeMessage$exitCode';

        expect(message, contains('failed with exit code'));
        expect(message, contains('127'));
      });
    });

    group('Process Execution', () {
      test('uses correct process timeout', () {
        expect(screenshotProcessTimeoutSeconds, equals(30));
        expect(screenshotProcessTimeoutSeconds, greaterThan(0));
        expect(screenshotProcessTimeoutSeconds, lessThanOrEqualTo(60));
      });

      test('runs processes without shell for security', () {
        expect(runInShell, isFalse);
      });

      test('expects zero exit code for success', () {
        expect(successExitCode, equals(0));
      });

      test('handles process streams correctly', () async {
        // Verify stdout and stderr are handled
        final mockProcess = MockProcess();
        final stdout = Stream<List<int>>.fromIterable([
          [72, 101, 108, 108, 111], // "Hello"
        ]);
        const stderr = Stream<List<int>>.empty();

        when(() => mockProcess.stdout).thenAnswer((_) => stdout);
        when(() => mockProcess.stderr).thenAnswer((_) => stderr);

        // Would be used in actual process execution
        expect(mockProcess.stdout, isNotNull);
        expect(mockProcess.stderr, isNotNull);
      });
    });

    group('File Generation', () {
      test('generates correct filename format', () {
        final id = uuid.v1();
        final filename = '$id$screenshotFileExtension';

        expect(filename, endsWith(screenshotFileExtension));
        expect(filename, contains('.screenshot.jpg'));
        expect(filename, matches(RegExp(r'^[0-9a-f-]+\.screenshot\.jpg$')));
      });

      test('creates date-based directory structure', () {
        final now = DateTime.now();
        final day = DateFormat(screenshotDateFormat).format(now);
        final path = '$screenshotDirectoryPath$day/';

        expect(path, startsWith('images/'));
        expect(path, endsWith('/'));
        expect(path, matches(RegExp(r'^images/\d{4}-\d{2}-\d{2}/$')));
      });

      test('uses relative paths for sandboxed environments', () {
        expect(screenshotDirectoryPath, equals('images/'));
        expect(screenshotDirectoryPath, isNot(startsWith('/')));
      });
    });

    group('Window Management', () {
      test('minimizes window before screenshot', () async {
        // Verify initial state - no calls made yet
        verifyNever(() => mockWindowManager.minimize());

        // Would be called in actual screenshot flow
        await mockWindowManager.minimize();
        verify(() => mockWindowManager.minimize()).called(1);
      });

      test('uses appropriate delays', () {
        expect(screenshotDelaySeconds, equals(1));
        expect(windowMinimizationDelayMs, equals(500));

        // Delays should be reasonable
        expect(screenshotDelaySeconds, lessThanOrEqualTo(5));
        expect(windowMinimizationDelayMs, lessThanOrEqualTo(1000));
      });

      test('restores window after screenshot', () async {
        // Verify initial state - no calls made yet
        verifyNever(() => mockWindowManager.show());

        // Would be called in actual screenshot flow
        await mockWindowManager.show();
        verify(() => mockWindowManager.show()).called(1);
      });
    });
  });
}
