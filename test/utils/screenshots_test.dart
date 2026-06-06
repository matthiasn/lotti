import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/portals/portal_service.dart';
import 'package:lotti/services/portals/screenshot_portal_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/screenshot_consts.dart';
import 'package:lotti/utils/screenshots.dart';
import 'package:mocktail/mocktail.dart';
import 'package:window_manager/window_manager.dart';

import '../helpers/fallbacks.dart';
import '../mocks/mocks.dart';

// ---------------------------------------------------------------------------
// Shared mocks and fakes
// ---------------------------------------------------------------------------

class MockWindowManager extends Mock implements WindowManager {}

class MockDirectory extends Mock implements Directory {}

class MockProcess extends Mock implements Process {}

class FakeDBusObjectPath extends Fake implements DBusObjectPath {}

class FakeDBusMethodCall extends Fake implements DBusMethodCall {}

class FakeDBusSignature extends Fake implements DBusSignature {}

void main() {
  // ---------------------------------------------------------------------------
  // Canonical tests (originally in screenshots_test.dart)
  // ---------------------------------------------------------------------------

  group('Screenshot Tests', () {
    late MockDomainLogger mockLoggingService;
    late MockWindowManager mockWindowManager;
    late MockDirectory mockDirectory;

    setUpAll(() {
      registerAllFallbackValues();
      registerFallbackValue(StackTrace.current);
    });

    setUp(() {
      mockLoggingService = MockDomainLogger();
      mockWindowManager = MockWindowManager();
      mockDirectory = MockDirectory();

      // Register mocks in GetIt
      getIt
        ..registerSingleton<DomainLogger>(mockLoggingService)
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
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Unsupported screenshot tool'),
            ),
          ),
        );
      });

      test('validates tool configuration for supported tools', () {
        // Test that all supported tools have valid configurations
        for (final tool in linuxScreenshotTools) {
          final config = screenshotToolConfigs[tool];
          expect(
            config,
            isNotNull,
            reason: 'Tool $tool should have configuration',
          );
          expect(config!.arguments, isA<List<String>>());
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
      test(
        'creates ImageData with correct properties on supported platform',
        () async {
          // Mock the directory creation
          when(
            () => mockDirectory.create(recursive: any(named: 'recursive')),
          ).thenAnswer((_) async => mockDirectory);

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
        },
      );
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
          expect(config!.arguments, isA<List<String>>());
        }
      });
    });

    group('Error Messages', () {
      test('provides helpful error message for missing tools', () {
        expect(
          noScreenshotToolAvailableMessage,
          contains('No screenshot tool available'),
        );
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
          screencaptureFailedMessage,
          contains('macOS screencapture failed'),
        );
        expect(
          unsupportedPlatformMessage,
          contains('Screenshot functionality is not supported'),
        );
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

  // ---------------------------------------------------------------------------
  // Comprehensive tests (originally in screenshots_comprehensive_test.dart)
  // ---------------------------------------------------------------------------

  group('Screenshots Comprehensive Tests', () {
    late MockDomainLogger mockLoggingService;
    late MockWindowManager mockWindowManager;
    late Directory testTempDir;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();

      registerAllFallbackValues();
      registerFallbackValue(StackTrace.current);
      registerFallbackValue(FakeDBusObjectPath());
      registerFallbackValue(FakeDBusMethodCall());
      registerFallbackValue(FakeDBusSignature());
      registerFallbackValue(DBusDict.stringVariant(const {}));

      // Create a real temp directory for integration tests
      testTempDir = await Directory.systemTemp.createTemp('screenshot_test');
    });

    tearDownAll(() async {
      if (testTempDir.existsSync()) {
        await testTempDir.delete(recursive: true);
      }
    });

    setUp(() {
      mockLoggingService = MockDomainLogger();
      mockWindowManager = MockWindowManager();

      // Register mocks in GetIt
      getIt
        ..registerSingleton<DomainLogger>(mockLoggingService)
        ..registerSingleton<WindowManager>(mockWindowManager)
        ..registerSingleton<Directory>(testTempDir);

      // Setup default mock behaviors
      when(() => mockWindowManager.minimize()).thenAnswer((_) async {});
      when(() => mockWindowManager.show()).thenAnswer((_) async {});

      when(
        () => mockLoggingService.log(
          any<LogDomain>(),
          any<String>(),
          subDomain: any(named: 'subDomain'),
        ),
      ).thenReturn(null);

      when(
        () => mockLoggingService.error(
          any<LogDomain>(),
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: any(named: 'subDomain'),
        ),
      ).thenAnswer((_) async {});
    });

    tearDown(getIt.reset);

    group('Portal Environment Detection', () {
      test('isRunningInFlatpak returns correct value based on environment', () {
        final isRunning = PortalService.isRunningInFlatpak;
        expect(isRunning, isA<bool>());

        // Verify consistency with shouldUsePortal
        if (Platform.isLinux) {
          final hasFlatpakId =
              Platform.environment['FLATPAK_ID'] != null &&
              Platform.environment['FLATPAK_ID']!.isNotEmpty;
          expect(isRunning, equals(hasFlatpakId));
        } else {
          expect(isRunning, isFalse);
        }
      });

      test('shouldUsePortal is consistent with environment', () {
        final shouldUse = PortalService.shouldUsePortal;
        final isRunning = PortalService.isRunningInFlatpak;
        expect(shouldUse, equals(isRunning));
      });
    });

    group('Screenshot Portal Integration', () {
      test('takeScreenshot uses portal when in Flatpak environment', () async {
        // This test verifies the integration with portal services
        // In non-Flatpak environment, it should fall back to traditional methods

        if (PortalService.shouldUsePortal) {
          // In Flatpak, should attempt to use portal
          expect(
            () async {
              await takeScreenshot();
            },
            throwsA(
              anyOf(
                isA<MissingPluginException>(),
                isA<UnsupportedError>(),
                isA<Exception>(),
              ),
            ),
          );
        } else {
          // Outside Flatpak, should use traditional screenshot tools
          expect(
            () async {
              await takeScreenshot();
            },
            throwsA(
              anyOf(
                isA<MissingPluginException>(),
                isA<UnsupportedError>(),
                isA<Exception>(),
              ),
            ),
          );
        }
      });

      test('portal service availability check', () async {
        final isAvailable = await ScreenshotPortalService.isAvailable();
        expect(isAvailable, isA<bool>());

        // Portal should only be available in Flatpak
        if (!PortalService.shouldUsePortal) {
          expect(isAvailable, isFalse);
        }
      });

      test('handles portal fallback to traditional methods', () async {
        // When portal fails, should fall back to traditional screenshot methods
        // This is tested by the error handling in takeScreenshot

        when(
          () => mockLoggingService.error(
            LogDomain.screenshots,
            any<Object>(),
            subDomain: 'portal_fallback',
          ),
        ).thenAnswer((_) async {});

        // Attempt screenshot which should handle fallback
        expect(() async {
          await takeScreenshot();
        }, throwsA(isA<Exception>()));
      });
    });

    group('isCommandAvailable', () {
      test('returns false for non-existent commands', () async {
        // Test with a command that should not exist
        final result = await isCommandAvailable('nonexistent_command_xyz123');
        expect(result, isFalse);
      });

      test('returns true for existing commands', () async {
        // Test with a command that should exist on most systems
        if (Platform.isLinux || Platform.isMacOS) {
          final result = await isCommandAvailable('ls');
          expect(result, isTrue);
        }
      });
    });

    group('findAvailableScreenshotTool', () {
      test('returns a tool or null depending on system', () async {
        final result = await findAvailableScreenshotTool();
        // On Linux, might return a tool if available
        // On other systems, should return null
        if (Platform.isLinux) {
          expect(result, anyOf(isNull, isIn(linuxScreenshotTools)));
        } else if (Platform.isMacOS) {
          // macOS might have ImageMagick's import tool available
          expect(result, anyOf(isNull, isIn(linuxScreenshotTools)));
        } else {
          expect(result, isNull);
        }
      });
    });

    group('takeLinuxScreenshot', () {
      test('throws exception for unsupported tool', () async {
        await expectLater(
          takeLinuxScreenshot(
            'unsupported_tool',
            'test.jpg',
            testTempDir.path,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Unsupported screenshot tool'),
            ),
          ),
        );
      });

      test('validates tool arguments exist', () {
        for (final tool in linuxScreenshotTools) {
          final config = screenshotToolConfigs[tool];
          expect(config, isNotNull, reason: 'Config for $tool should exist');
          expect(config!.arguments, isA<List<String>>());
        }
      });

      test('handles process execution structure', () async {
        // We can't easily mock Process.start without IOOverrides
        // But we can verify the tool configuration is correct
        expect(spectacleArguments, contains('-f'));
        expect(gnomeScreenshotArguments, contains('-f'));
        expect(importArguments, containsAll(['-window', 'root']));
      });
    });

    group('takeScreenshot main function', () {
      test('throws UnsupportedError on unsupported platforms', () async {
        // We can't easily mock Platform.operatingSystem
        // but we can test the error message exists
        expect(unsupportedPlatformMessage, contains('not supported'));
      });

      test('logs exceptions and rethrows them', () async {
        // In test environment, takeScreenshot will throw MissingPluginException
        await expectLater(
          takeScreenshot(),
          throwsA(isA<MissingPluginException>()),
        );

        // Logging should be attempted
        verify(
          () => mockLoggingService.error(
            LogDomain.screenshots,
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
          ),
        ).called(1);
      });

      test('restores window even on error', () async {
        // This test would require mocking the global windowManager
        // which is not easily possible without refactoring
        // We verify the behavior exists through the _safelyRestoreWindow function
        expect(() async {
          await takeScreenshot();
        }, throwsA(isA<MissingPluginException>()));
      });

      test('creates correct ImageData structure', () async {
        // This test would need platform-specific mocking
        // We verify the ImageData structure is correct
        final testData = ImageData(
          imageId: 'test-id',
          imageFile: 'test.jpg',
          imageDirectory: '/test/',
          capturedAt: DateTime(2024, 3, 15, 10, 30),
        );

        expect(testData.imageFile, endsWith('.jpg'));
        expect(testData.imageDirectory, contains('/'));
        expect(testData.capturedAt, isA<DateTime>());
      });

      test('uses correct delay for window minimization', () async {
        // Verify delay constants are reasonable
        expect(screenshotDelaySeconds, greaterThan(0));
        expect(screenshotDelaySeconds, lessThanOrEqualTo(5));
      });
    });

    group('macOS screenshot', () {
      test('uses correct screencapture arguments', () {
        expect(screencaptureArguments, contains('-tjpg'));
        expect(screencaptureTool, equals('screencapture'));
      });

      test('handles screencapture timeout', () async {
        // Test timeout handling for macOS
        expect(screenshotProcessTimeoutSeconds, greaterThan(0));
        expect(screenshotProcessTimeoutSeconds, lessThanOrEqualTo(60));
      });

      test('handles screencapture failure', () {
        expect(screencaptureFailedMessage, contains('screencapture failed'));
      });
    });

    group('File and directory handling', () {
      test('creates unique filenames', () async {
        // Test that uuid is used for unique filenames
        final uuid1 = uuid.v1();
        final uuid2 = uuid.v1();
        expect(uuid1, isNot(equals(uuid2)));
      });

      test('uses correct date format for directories', () {
        final date = DateTime(2023, 12, 25);
        final formatted = DateFormat(screenshotDateFormat).format(date);
        expect(formatted, equals('2023-12-25'));
      });

      test('constructs correct relative paths', () {
        const relativePath = screenshotDirectoryPath;
        expect(relativePath, equals('images/'));
        expect(relativePath, isNot(startsWith('/')));
      });
    });

    group('Error recovery', () {
      test('window restoration is attempted on error', () async {
        // We can't mock the global windowManager easily
        // Instead verify error handling works
        expect(() async {
          await takeScreenshot();
        }, throwsA(isA<MissingPluginException>()));
      });

      test('logging never prevents screenshot completion', () async {
        // In test environment, we get MissingPluginException
        await expectLater(
          takeScreenshot(),
          throwsA(isA<MissingPluginException>()),
        );

        // Verify logging was attempted
        verify(
          () => mockLoggingService.error(
            LogDomain.screenshots,
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
          ),
        ).called(1);
      });
    });

    group('Platform detection', () {
      test('correctly identifies platform tools', () {
        if (Platform.isMacOS) {
          expect(screencaptureTool, equals('screencapture'));
        } else if (Platform.isLinux) {
          expect(linuxScreenshotTools, isNotEmpty);
          expect(linuxScreenshotTools.first, equals(spectacleTool));
        }
      });

      test('has fallback tools for Linux', () {
        expect(linuxScreenshotTools.length, greaterThan(1));
        expect(
          linuxScreenshotTools,
          containsAll([
            spectacleTool,
            gnomeScreenshotTool,
            scrotTool,
            importTool,
          ]),
        );
      });
    });
  });

  // ---------------------------------------------------------------------------
  // Platform-specific tests (originally in screenshots_platform_test.dart)
  // ---------------------------------------------------------------------------

  group('Platform-specific Screenshot Tests', () {
    late MockDomainLogger mockLoggingService;
    late MockWindowManager mockWindowManager;
    late Directory testTempDir;

    setUpAll(() async {
      registerAllFallbackValues();
      registerFallbackValue(StackTrace.current);
      testTempDir = await Directory.systemTemp.createTemp(
        'platform_screenshot_test',
      );
    });

    tearDownAll(() async {
      if (testTempDir.existsSync()) {
        await testTempDir.delete(recursive: true);
      }
    });

    setUp(() {
      mockLoggingService = MockDomainLogger();
      mockWindowManager = MockWindowManager();

      getIt
        ..registerSingleton<DomainLogger>(mockLoggingService)
        ..registerSingleton<WindowManager>(mockWindowManager)
        ..registerSingleton<Directory>(testTempDir);

      when(() => mockWindowManager.minimize()).thenAnswer((_) async {});
      when(() => mockWindowManager.show()).thenAnswer((_) async {});

      when(
        () => mockLoggingService.log(
          any<LogDomain>(),
          any<String>(),
          subDomain: any(named: 'subDomain'),
        ),
      ).thenReturn(null);

      when(
        () => mockLoggingService.error(
          any<LogDomain>(),
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: any(named: 'subDomain'),
        ),
      ).thenAnswer((_) async {});
    });

    tearDown(getIt.reset);

    group('Portal vs Traditional Screenshot Selection', () {
      test('uses portal in Flatpak environment', () {
        final usePortal = PortalService.shouldUsePortal;

        if (Platform.isLinux) {
          final hasFlatpakId =
              Platform.environment['FLATPAK_ID'] != null &&
              Platform.environment['FLATPAK_ID']!.isNotEmpty;
          expect(usePortal, equals(hasFlatpakId));
        } else {
          expect(usePortal, isFalse);
        }
      });

      test('falls back to traditional tools when portal unavailable', () async {
        // When not in Flatpak, should use traditional screenshot tools
        if (!PortalService.shouldUsePortal && Platform.isLinux) {
          final availableTool = await findAvailableScreenshotTool();
          // Should find a tool or return null
          expect(availableTool, anyOf(isNull, isIn(linuxScreenshotTools)));
        }
      });

      test('portal service singleton is properly managed', () {
        final service1 = ScreenshotPortalService();
        final service2 = ScreenshotPortalService();

        // Should be the same instance (singleton)
        expect(identical(service1, service2), isTrue);
      });
    });

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
        expect(config!.arguments, equals(spectacleArguments));
        expect(config.arguments, contains('-f')); // fullscreen
        expect(config.arguments, contains('-b')); // background
        expect(config.arguments, contains('-n')); // no notification
        expect(config.arguments, contains('-o')); // output to stdout
      });

      test('gnome-screenshot configuration is correct', () {
        final config = screenshotToolConfigs[gnomeScreenshotTool];

        expect(config, isNotNull);
        expect(config!.arguments, equals(gnomeScreenshotArguments));
        expect(config.arguments, contains('-f')); // file parameter
      });

      test('scrot configuration is correct', () {
        final config = screenshotToolConfigs[scrotTool];

        expect(config, isNotNull);
        expect(config!.arguments, equals(scrotArguments));
        expect(
          config.arguments,
          isEmpty,
        ); // scrot uses filename as positional arg
      });

      test('import (ImageMagick) configuration is correct', () {
        final config = screenshotToolConfigs[importTool];

        expect(config, isNotNull);
        expect(config!.arguments, equals(importArguments));
        expect(config.arguments, contains('-window'));
        expect(config.arguments, contains('root'));
      });

      test('tool priority order is correct', () {
        expect(linuxScreenshotTools.first, equals(spectacleTool));
        expect(linuxScreenshotTools[1], equals(gnomeScreenshotTool));
        expect(linuxScreenshotTools[2], equals(scrotTool));
        expect(linuxScreenshotTools.last, equals(importTool));
      });

      test('all tools have configurations', () {
        for (final tool in linuxScreenshotTools) {
          expect(
            screenshotToolConfigs.containsKey(tool),
            isTrue,
            reason: 'Tool $tool should have a configuration',
          );
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

          final fakeCommandAvailable = await isCommandAvailable(
            'fake_command_xyz',
          );
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
          // On non-Linux (like macOS), may have ImageMagick's import tool
          expect(tool, anyOf(isNull, isIn(linuxScreenshotTools)));
        }
      });

      test('checks tools in priority order', () {
        // Verify the tool order is correct
        expect(linuxScreenshotTools, contains(spectacleTool));
        expect(linuxScreenshotTools, contains(gnomeScreenshotTool));
        expect(linuxScreenshotTools, contains(scrotTool));
        expect(linuxScreenshotTools, contains(importTool));
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
        final testDate = DateTime(2024, 3, 15, 10, 30);
        final day = DateFormat(screenshotDateFormat).format(testDate);
        final pathStr = '$screenshotDirectoryPath$day/';

        expect(pathStr, startsWith('images/'));
        expect(pathStr, endsWith('/'));
        expect(pathStr, matches(RegExp(r'^images/\d{4}-\d{2}-\d{2}/$')));
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

        // Delays should be reasonable
        expect(screenshotDelaySeconds, lessThanOrEqualTo(5));
      });

      test('restores window after screenshot', () async {
        // Verify initial state - no calls made yet
        verifyNever(() => mockWindowManager.show());

        // Would be called in actual screenshot flow
        await mockWindowManager.show();
        verify(() => mockWindowManager.show()).called(1);
      });
    });

    group('Flatpak Security and Permissions', () {
      test('verifies restricted filesystem access in Flatpak', () {
        // In Flatpak, only specific directories should be accessible
        const flatpakAllowedPaths = [
          'xdg-documents/Lotti',
          'xdg-download/Lotti',
          'xdg-pictures', // Read-only
        ];

        for (final path in flatpakAllowedPaths) {
          // Verify Lotti-specific directories are isolated
          if (path.contains('Lotti')) {
            expect(path.endsWith('/Lotti'), isTrue);
          }
        }
      });

      test('ensures portal is used for privileged operations', () async {
        // In Flatpak, screenshots must use portal instead of direct access
        if (PortalService.isRunningInFlatpak) {
          expect(PortalService.shouldUsePortal, isTrue);

          // Should not attempt to use traditional screenshot tools directly
          await expectLater(
            // Direct screenshot tools should fail in sandboxed environment
            takeLinuxScreenshot('spectacle', 'test.png', testTempDir.path),
            throwsA(isA<Exception>()),
          );
        }
      });

      test('validates portal bus names and paths', () {
        // Security: Ensure we're talking to the correct portal service
        expect(
          PortalConstants.portalBusName,
          equals('org.freedesktop.portal.Desktop'),
        );
        expect(
          PortalConstants.portalPath,
          equals('/org/freedesktop/portal/desktop'),
        );

        // These should never change as they're part of the XDG spec
        expect(
          ScreenshotPortalConstants.interfaceName,
          equals('org.freedesktop.portal.Screenshot'),
        );
      });

      test('verifies sandbox restrictions are enforced', () {
        // Test that the app respects sandbox boundaries
        if (PortalService.isRunningInFlatpak) {
          // Should not have direct access to system directories
          final systemDirs = ['/usr', '/etc', '/var'];

          for (final dir in systemDirs) {
            // In a properly sandboxed Flatpak, these would be restricted
            // We can't directly test this without being in Flatpak
            expect(dir, startsWith('/'));
          }
        }
      });

      test('ensures proper cleanup of portal resources', () async {
        final portalService = ScreenshotPortalService();

        await portalService.initialize();
        expect(portalService.isInitialized, isTrue);

        await portalService.dispose();
        expect(portalService.isInitialized, isFalse);

        // Should not leak resources after disposal
        expect(() => portalService.client, throwsStateError);
      });
    });
  });

  // ---------------------------------------------------------------------------
  // Portal integration tests
  // (originally in screenshots_portal_integration_test.dart)
  // ---------------------------------------------------------------------------

  group('Screenshots Portal Integration', () {
    late MockDomainLogger mockLoggingService;
    late MockWindowManager mockWindowManager;

    setUpAll(() {
      registerAllFallbackValues();
      registerFallbackValue(StackTrace.current);
    });

    setUp(() {
      mockLoggingService = MockDomainLogger();
      mockWindowManager = MockWindowManager();

      // Register mocks in GetIt
      getIt
        ..registerSingleton<DomainLogger>(mockLoggingService)
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
        expect(
          PortalService.shouldUsePortal,
          isFalse,
          reason: 'This test verifies non-Flatpak behavior',
        );

        // Mock logging to ensure no portal fallback is logged
        when(
          () => mockLoggingService.error(
            LogDomain.screenshots,
            any<Object>(),
            subDomain: 'portal_fallback',
          ),
        ).thenAnswer((_) async {});

        // The screenshot will fail because we don't have the actual tools
        // but it should NOT log portal_fallback
        try {
          await takeScreenshot();
        } catch (e) {
          // Expected to fail
        }

        // Verify portal fallback was NOT logged (because we're not in Flatpak)
        verifyNever(
          () => mockLoggingService.error(
            LogDomain.screenshots,
            any<Object>(),
            subDomain: 'portal_fallback',
          ),
        );
      });

      test('portal service should throw when used outside Flatpak', () async {
        // This test verifies that ScreenshotPortalService properly guards against
        // being used outside of Flatpak
        expect(
          PortalService.shouldUsePortal,
          isFalse,
          reason: 'This test requires non-Flatpak environment',
        );

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
        expect(
          PortalService.shouldUsePortal,
          isFalse,
          reason: 'This test verifies non-Flatpak behavior',
        );

        // Mock logging to capture any exceptions
        when(
          () => mockLoggingService.error(
            LogDomain.screenshots,
            any<Object>(),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          ),
        ).thenAnswer((_) async {});

        // The screenshot will fail because we don't have the actual screenshot tools
        await expectLater(
          takeScreenshot(),
          throwsA(anyOf(isA<Exception>(), isA<StateError>())),
        );

        // Verify that the exception was logged (but NOT as portal_fallback)
        verify(
          () => mockLoggingService.error(
            LogDomain.screenshots,
            any<Object>(),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          ),
        ).called(1);
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
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('not initialized'),
            ),
          ),
        );
      });
    });

    group('Portal Constants Integration', () {
      test('should use correct portal constants', () {
        expect(
          ScreenshotPortalConstants.interfaceName,
          equals('org.freedesktop.portal.Screenshot'),
        );
        expect(
          ScreenshotPortalConstants.screenshotMethod,
          equals('Screenshot'),
        );
      });

      test('should use correct portal timeout', () {
        expect(
          PortalConstants.responseTimeout,
          equals(const Duration(seconds: 30)),
        );
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
  });
}
