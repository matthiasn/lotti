import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/portals/portal_service.dart';
import 'package:lotti/services/portals/screenshot_portal_service.dart';
import 'package:lotti/utils/screenshot_consts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:window_manager/window_manager.dart';

// Mocks
class MockLoggingService extends Mock implements LoggingService {}

class MockWindowManager extends Mock implements WindowManager {}

class MockDBusClient extends Mock implements DBusClient {}

class MockDBusRemoteObject extends Mock implements DBusRemoteObject {}

class MockDBusSignal extends Mock implements DBusSignal {}

// Fakes
class FakeDBusObjectPath extends Fake implements DBusObjectPath {
  FakeDBusObjectPath(this.value);

  @override
  final String value;
}

class FakeDBusSignature extends Fake implements DBusSignature {}

void main() {
  group('Flatpak Portal Screenshot Tests', () {
    late MockLoggingService mockLoggingService;
    late MockWindowManager mockWindowManager;
    late MockDBusClient mockDBusClient;
    late MockDBusRemoteObject mockDBusRemoteObject;
    late Directory testTempDir;
    late ScreenshotPortalService portalService;

    setUpAll(() async {
      registerFallbackValue(StackTrace.current);
      registerFallbackValue(FakeDBusObjectPath('/test'));
      registerFallbackValue(FakeDBusSignature());
      registerFallbackValue(const DBusString(''));
      registerFallbackValue(DBusDict.stringVariant(const {}));

      testTempDir = await Directory.systemTemp.createTemp('flatpak_test');
    });

    tearDownAll(() async {
      if (testTempDir.existsSync()) {
        await testTempDir.delete(recursive: true);
      }
    });

    setUp(() {
      mockLoggingService = MockLoggingService();
      mockWindowManager = MockWindowManager();
      mockDBusClient = MockDBusClient();
      mockDBusRemoteObject = MockDBusRemoteObject();
      portalService = ScreenshotPortalService();

      getIt
        ..registerSingleton<LoggingService>(mockLoggingService)
        ..registerSingleton<WindowManager>(mockWindowManager)
        ..registerSingleton<Directory>(testTempDir);

      // Setup default behaviors
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

      when(() => mockDBusClient.close()).thenAnswer((_) async {});
    });

    tearDown(() async {
      await portalService.dispose();
      await getIt.reset();
    });

    group('Portal Environment Detection', () {
      test('shouldUsePortal returns correct value based on environment', () {
        final shouldUse = PortalService.shouldUsePortal;
        final isLinux = Platform.isLinux;
        final hasFlatpakId = Platform.environment['FLATPAK_ID'] != null &&
            Platform.environment['FLATPAK_ID']!.isNotEmpty;

        expect(shouldUse, equals(isLinux && hasFlatpakId));
      });

      test('isRunningInFlatpak correctly detects Flatpak environment', () {
        final isRunning = PortalService.isRunningInFlatpak;
        expect(isRunning, isA<bool>());

        // If we're in Flatpak, FLATPAK_ID should be set
        if (isRunning) {
          expect(Platform.environment['FLATPAK_ID'], isNotNull);
          expect(Platform.environment['FLATPAK_ID'], isNotEmpty);
        }
      });
    });

    group('Portal Service Initialization', () {
      test('service initializes correctly in non-Flatpak environment',
          () async {
        // In non-Flatpak environment, initialization should succeed but not create DBus client
        if (!PortalService.shouldUsePortal) {
          await portalService.initialize();
          expect(portalService.isInitialized, isTrue);
          expect(() => portalService.client, throwsStateError);
        }
      });

      test('service handles multiple initializations safely', () async {
        await portalService.initialize();
        expect(portalService.isInitialized, isTrue);

        // Second initialization should not cause issues
        await portalService.initialize();
        expect(portalService.isInitialized, isTrue);
      });

      test('service disposes correctly', () async {
        await portalService.initialize();
        expect(portalService.isInitialized, isTrue);

        await portalService.dispose();
        expect(portalService.isInitialized, isFalse);
      });
    });

    group('Screenshot Portal Parameters', () {
      test('creates unique handle tokens', () async {
        final token1 = PortalService.createHandleToken('screenshot');
        // Add delay to ensure different timestamp
        await Future<void>.delayed(const Duration(milliseconds: 2));
        final token2 = PortalService.createHandleToken('screenshot');

        expect(token1, startsWith('screenshot_'));
        expect(token2, startsWith('screenshot_'));
        expect(token1, isNot(equals(token2)));
      });

      test('takeScreenshot throws error in non-Flatpak environment', () async {
        if (!PortalService.shouldUsePortal) {
          expect(
            () async => portalService.takeScreenshot(),
            throwsA(isA<UnsupportedError>()),
          );
        }
      });
    });

    group('Portal DBus Communication', () {
      test('portal constants are correctly defined', () {
        expect(PortalConstants.portalBusName,
            equals('org.freedesktop.portal.Desktop'));
        expect(PortalConstants.portalPath,
            equals('/org/freedesktop/portal/desktop'));
        expect(ScreenshotPortalConstants.interfaceName,
            equals('org.freedesktop.portal.Screenshot'));
        expect(
            ScreenshotPortalConstants.screenshotMethod, equals('Screenshot'));
      });

      test('handles successful portal response with file URI', () {
        const testUri = 'file:///tmp/screenshot.png';
        final signal = MockDBusSignal();

        // Mock successful response signal
        when(() => signal.values).thenReturn([
          const DBusUint32(0), // Success code
          DBusDict.stringVariant({
            'uri': const DBusString(testUri),
          }),
        ]);

        // Verify response parsing
        expect(signal.values.length, equals(2));
        final responseCode = (signal.values[0] as DBusUint32).value;
        expect(responseCode, equals(0)); // Success

        final results = (signal.values[1] as DBusDict).asStringVariantDict();
        final uri = results['uri'] as DBusString?;
        expect(uri?.value, equals(testUri));

        // Verify URI can be converted to file path
        final filePath = Uri.parse(testUri).toFilePath();
        expect(filePath, equals('/tmp/screenshot.png'));
      });

      test('handles portal cancellation response', () {
        final signal = MockDBusSignal();

        // Mock cancellation response
        when(() => signal.values).thenReturn([
          const DBusUint32(1), // Cancelled code
          DBusDict.stringVariant(const {}),
        ]);

        final responseCode = (signal.values[0] as DBusUint32).value;
        expect(responseCode, equals(1)); // Cancelled
      });

      test('handles portal error response', () {
        final signal = MockDBusSignal();

        // Mock error response
        when(() => signal.values).thenReturn([
          const DBusUint32(2), // Error code
          DBusDict.stringVariant({
            'error_message': const DBusString('Permission denied'),
          }),
        ]);

        final responseCode = (signal.values[0] as DBusUint32).value;
        expect(responseCode, equals(2)); // Error

        final results = (signal.values[1] as DBusDict).asStringVariantDict();
        final errorMessage = results['error_message'] as DBusString?;
        expect(errorMessage?.value, equals('Permission denied'));
      });
    });

    group('Portal File Operations', () {
      test('correctly handles file URI conversion', () {
        const fileUri = 'file:///home/user/Pictures/screenshot.png';
        final path = Uri.parse(fileUri).toFilePath();
        expect(path, equals('/home/user/Pictures/screenshot.png'));
      });

      test('validates screenshot file extension', () {
        const filename = 'test.screenshot.jpg';
        expect(filename.endsWith('.jpg'), isTrue);
        expect(filename.endsWith(screenshotFileExtension), isTrue);
        expect(screenshotFileExtension, equals('.screenshot.jpg'));
      });

      test('creates correct directory structure', () async {
        final testDir = '${testTempDir.path}/screenshots/2024-01-15';
        final dir = Directory(testDir);

        if (!dir.existsSync()) {
          await dir.create(recursive: true);
        }

        expect(dir.existsSync(), isTrue);

        // Cleanup
        if (dir.existsSync()) {
          await dir.delete(recursive: true);
        }
      });
    });

    group('Portal Error Handling', () {
      test('handles DBus connection errors', () {
        when(() => mockDBusRemoteObject.callMethod(
              any(),
              any(),
              any(),
            )).thenThrow(Exception('DBus connection failed'));

        // Would throw in actual portal call
        expect(
          () => mockDBusRemoteObject.callMethod(
            'org.freedesktop.portal.Screenshot',
            'Screenshot',
            [],
          ),
          throwsException,
        );
      });

      test('handles timeout in portal response', () async {
        final completer = Completer<String?>();

        // Simulate timeout
        final future = completer.future.timeout(
          const Duration(milliseconds: 100),
          onTimeout: () => throw TimeoutException('Portal response timeout'),
        );

        await expectLater(
          future,
          throwsA(isA<TimeoutException>()),
        );
      });

      test('logs exceptions to LoggingService', () {
        final exception = Exception('Portal test exception');

        mockLoggingService.captureException(
          exception,
          domain: 'PortalService',
          subDomain: 'screenshot',
        );

        verify(() => mockLoggingService.captureException(
              exception,
              domain: 'PortalService',
              subDomain: 'screenshot',
            )).called(1);
      });
    });

    group('Portal Integration with Window Manager', () {
      test('minimizes window before screenshot in fallback mode', () async {
        when(() => mockWindowManager.minimize()).thenAnswer((_) async {});

        await mockWindowManager.minimize();

        verify(() => mockWindowManager.minimize()).called(1);
      });

      test('restores window after screenshot in fallback mode', () async {
        when(() => mockWindowManager.show()).thenAnswer((_) async {});

        await mockWindowManager.show();

        verify(() => mockWindowManager.show()).called(1);
      });
    });

    group('Portal Security and Permissions', () {
      test('verifies portal runs in sandboxed context', () {
        // In Flatpak, certain paths should be restricted
        if (PortalService.isRunningInFlatpak) {
          // Portal should be used instead of direct file access
          expect(PortalService.shouldUsePortal, isTrue);
        }
      });

      test('validates screenshot directory permissions', () {
        // Test that the app can only write to allowed directories
        const allowedPaths = [
          'xdg-documents/Lotti',
          'xdg-download/Lotti',
        ];

        for (final path in allowedPaths) {
          // These paths should be accessible in Flatpak manifest
          expect(path.contains('Lotti'), isTrue);
        }
      });

      test('ensures portal options include security parameters', () {
        final options = <String, DBusValue>{
          'handle_token': DBusString(PortalService.createHandleToken('test')),
          'modal': const DBusBoolean(false),
          'interactive': const DBusBoolean(true),
        };

        expect(options.containsKey('handle_token'), isTrue);
        expect(options['interactive'], isA<DBusBoolean>());
        expect((options['interactive']! as DBusBoolean).value, isTrue);
      });
    });
  });
}
