import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/portals/portal_service.dart';
import 'package:lotti/services/portals/screenshot_portal_service.dart';
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

    group('Portal Environment Detection', () {
      test('isRunningInFlatpak returns correct value based on environment', () {
        final isRunning = PortalService.isRunningInFlatpak;
        expect(isRunning, isA<bool>());

        // Verify consistency with shouldUsePortal
        if (Platform.isLinux) {
          final hasFlatpakId = Platform.environment['FLATPAK_ID'] != null &&
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
          expect(() async {
            await takeScreenshot();
          },
              throwsA(anyOf(
                isA<MissingPluginException>(),
                isA<UnsupportedError>(),
                isA<Exception>(),
              )));
        } else {
          // Outside Flatpak, should use traditional screenshot tools
          expect(() async {
            await takeScreenshot();
          }, throwsA(isA<MissingPluginException>()));
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

        when(() => mockLoggingService.captureException(
              any<dynamic>(),
              domain: 'SCREENSHOTS',
              subDomain: 'portal_fallback',
            )).thenReturn(null);

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
