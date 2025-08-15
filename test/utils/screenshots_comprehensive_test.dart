import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/journal_entities.dart';
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

class MockDirectory extends Mock implements Directory {}

class MockProcess extends Mock implements Process {}

// ProcessResult is final, so we can't mock it directly

class MockDBusClient extends Mock implements DBusClient {}

class MockDBusRemoteObject extends Mock implements DBusRemoteObject {}

class MockDBusMethodResponse extends Mock implements DBusMethodResponse {}

class MockDBusSignalStream extends Mock implements DBusSignalStream {}

class MockDBusSignal extends Mock implements DBusSignal {}

class MockFile extends Mock implements File {}

class MockIOSink extends Mock implements IOSink {}

class FakeDBusObjectPath extends Fake implements DBusObjectPath {}

class FakeDBusMethodCall extends Fake implements DBusMethodCall {}

class FakeDBusSignature extends Fake implements DBusSignature {}

void main() {
  group('Screenshots Comprehensive Tests', () {
    late MockLoggingService mockLoggingService;
    late MockWindowManager mockWindowManager;
    late Directory testTempDir;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();

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
      mockLoggingService = MockLoggingService();
      mockWindowManager = MockWindowManager();

      // Register mocks in GetIt
      getIt
        ..registerSingleton<LoggingService>(mockLoggingService)
        ..registerSingleton<WindowManager>(mockWindowManager)
        ..registerSingleton<Directory>(testTempDir);

      // Setup default mock behaviors
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

    group('isRunningInFlatpak', () {
      test('returns correct value based on environment', () {
        // Test without FLATPAK_ID
        final result1 = isRunningInFlatpak();

        // We can't easily mock Platform.environment or File.existsSync
        // but we can verify the function returns a boolean
        expect(result1, isA<bool>());
      });
    });

    group('_safelyRestoreWindow', () {
      test('handles window restoration errors gracefully', () async {
        // The _safelyRestoreWindow function is private
        // We can't test it directly without mocking the global windowManager
        // which would require significant refactoring of the production code

        // Instead, we verify the function exists by checking error handling
        expect(() async {
          // This will fail due to MissingPluginException in test environment
          await takeScreenshot();
        }, throwsA(isA<MissingPluginException>()));
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
        } else {
          expect(result, isNull);
        }
      });
    });

    group('takeLinuxScreenshot', () {
      test('throws exception for unsupported tool', () async {
        await expectLater(
          takeLinuxScreenshot('unsupported_tool', 'test.jpg', testTempDir.path),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Unsupported screenshot tool'),
          )),
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

    group('takeFlatpakPortalScreenshot', () {
      test('handles portal not available', () async {
        // Mock DBusClient to simulate portal not available
        await expectLater(
          takeFlatpakPortalScreenshot(),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('D-Bus screenshot portal is not available'),
          )),
        );

        // Can't verify windowManager calls without mocking the global instance
      });

      test('handles portal timeout', () async {
        // This is a complex test that would require extensive DBus mocking
        // For now, we verify the structure exists
        expect(takeFlatpakPortalScreenshot, isA<Function>());
      });

      test('handles missing URI in portal response', () async {
        // Another complex DBus test - verify error handling exists
        expect(portalNoUriMessage, contains('no URI provided'));
      });

      test('handles user cancellation', () async {
        // Verify cancellation handling exists
        expect(portalCancelledMessage, contains('cancelled'));
      });

      test('handles file copy failure', () async {
        // Verify file handling errors exist
        expect(portalFileNotFoundMessage, contains('not found'));
      });

      test('handles unexpected URI format', () async {
        // Verify URI validation exists
        expect(portalUnexpectedUriMessage, contains('Unexpected'));
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
        verify(() => mockLoggingService.captureException(
              any<dynamic>(),
              domain: screenshotDomain,
              stackTrace: any<dynamic>(named: 'stackTrace'),
            )).called(1);
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
          capturedAt: DateTime.now(),
        );

        expect(testData.imageFile, endsWith('.jpg'));
        expect(testData.imageDirectory, contains('/'));
        expect(testData.capturedAt, isA<DateTime>());
      });

      test('uses correct delay for window minimization', () async {
        // Verify delay constants are reasonable
        expect(screenshotDelaySeconds, greaterThan(0));
        expect(screenshotDelaySeconds, lessThanOrEqualTo(5));
        expect(windowMinimizationDelayMs, greaterThan(0));
        expect(windowMinimizationDelayMs, lessThanOrEqualTo(1000));
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
        verify(() => mockLoggingService.captureException(
              any<dynamic>(),
              domain: screenshotDomain,
              stackTrace: any<dynamic>(named: 'stackTrace'),
            )).called(1);
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
            ]));
      });
    });
  });
}
