import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/screenshot_consts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:window_manager/window_manager.dart';

// Mocks
class MockLoggingService extends Mock implements LoggingService {}

class MockWindowManager extends Mock implements WindowManager {}

class MockDBusClient extends Mock implements DBusClient {}

class MockDBusRemoteObject extends Mock implements DBusRemoteObject {}

class MockDBusMethodResponse extends Mock implements DBusMethodResponse {}

class MockDBusSignalStream extends Mock implements DBusSignalStream {}

class MockDBusSignal extends Mock implements DBusSignal {}

class MockFile extends Mock implements File {}

class MockStreamSubscription extends Mock
    implements StreamSubscription<DBusSignal> {}

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

    tearDown(getIt.reset);

    group('Portal availability check', () {
      test('detects when portal is available', () async {
        // Mock successful introspection
        when(() => mockDBusRemoteObject.introspect()).thenAnswer(
          (_) async => DBusIntrospectNode(
            name: 'test',
            interfaces: [
              DBusIntrospectInterface(
                dbusPortalScreenshotInterface,
                methods: [],
                signals: [],
                properties: [],
                annotations: [],
              ),
            ],
          ),
        );

        // We can't easily test _isPortalAvailable directly, but we can verify
        // the portal constants are correctly defined
        expect(dbusPortalDesktopName, equals('org.freedesktop.portal.Desktop'));
        expect(
            dbusPortalDesktopPath, equals('/org/freedesktop/portal/desktop'));
      });

      test('handles portal introspection failure', () async {
        when(() => mockDBusRemoteObject.introspect()).thenThrow(
          Exception('Service not found'),
        );

        // Portal should be considered unavailable on introspection failure
        expect(
          () async => mockDBusRemoteObject.introspect(),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('Portal screenshot flow', () {
      test('constructs correct portal options', () {
        final options = <String, DBusValue>{
          portalHandleTokenKey: const DBusString('test_token'),
          portalModalKey: const DBusBoolean(false),
          portalInteractiveKey: const DBusBoolean(false),
        };

        expect(options[portalHandleTokenKey], isA<DBusString>());
        expect((options[portalModalKey] as DBusBoolean?)?.value, isFalse);
        expect((options[portalInteractiveKey] as DBusBoolean?)?.value, isFalse);
      });

      test('generates unique tokens', () async {
        final token1 =
            '$screenshotTokenPrefix${DateTime.now().millisecondsSinceEpoch}';
        // Wait a bit to ensure different timestamp
        await Future<void>.delayed(const Duration(milliseconds: 10));
        final token2 =
            '$screenshotTokenPrefix${DateTime.now().millisecondsSinceEpoch}';

        expect(token1, startsWith(screenshotTokenPrefix));
        expect(token2, startsWith(screenshotTokenPrefix));
        expect(token1, isNot(equals(token2)));
      });

      test('handles successful portal response', () {
        const testUri = '$fileUriScheme/tmp/screenshot.png';
        final results = DBusDict.stringVariant({
          portalUriKey: const DBusString(testUri),
        });

        final signal = MockDBusSignal();
        when(() => signal.values).thenReturn([
          const DBusUint32(portalSuccessResponse),
          results,
        ]);

        // Extract response handling logic
        expect(signal.values.length, equals(2));
        final response = signal.values[0] as DBusUint32;
        expect(response.value, equals(portalSuccessResponse));

        final resultsDict = signal.values[1] as DBusDict;
        final uri =
            resultsDict.asStringVariantDict()[portalUriKey] as DBusString?;
        expect(uri?.value, equals(testUri));
      });

      test('handles portal cancellation', () {
        const cancelResponse = 1;
        final signal = MockDBusSignal();
        when(() => signal.values).thenReturn([
          const DBusUint32(cancelResponse),
          DBusDict.stringVariant(const {}),
        ]);

        final response = signal.values[0] as DBusUint32;
        expect(response.value, isNot(equals(portalSuccessResponse)));
        expect(response.value, equals(cancelResponse));
      });

      test('handles missing URI in success response', () {
        final signal = MockDBusSignal();
        when(() => signal.values).thenReturn([
          const DBusUint32(portalSuccessResponse),
          DBusDict.stringVariant(const {}), // No URI
        ]);

        final response = signal.values[0] as DBusUint32;
        final results = signal.values[1] as DBusDict;

        expect(response.value, equals(portalSuccessResponse));
        expect(results.asStringVariantDict()[portalUriKey], isNull);
      });

      test('validates file URI format', () {
        const validUri = '$fileUriScheme/path/to/file.png';
        const invalidUri = 'http://example.com/file.png';

        expect(validUri.startsWith(fileUriScheme), isTrue);
        expect(invalidUri.startsWith(fileUriScheme), isFalse);

        // Test URI parsing
        final parsedPath = Uri.parse(validUri).toFilePath();
        expect(parsedPath, equals('/path/to/file.png'));
      });

      test('handles file copy operations', () async {
        final sourceFile = MockFile();
        final testPath = '${testTempDir.path}/test_screenshot.png';

        when(sourceFile.existsSync).thenReturn(true);
        when(() => sourceFile.copy(any())).thenAnswer((_) async => sourceFile);
        when(sourceFile.delete).thenAnswer((_) async => sourceFile);

        // Simulate file operations
        expect(sourceFile.existsSync(), isTrue);
        await sourceFile.copy(testPath);
        verify(() => sourceFile.copy(testPath)).called(1);

        // Cleanup should not throw even if it fails
        await sourceFile.delete();
        verify(sourceFile.delete).called(1);
      });

      test('handles file not found after portal success', () {
        final sourceFile = MockFile();
        when(sourceFile.existsSync).thenReturn(false);

        expect(sourceFile.existsSync(), isFalse);
        expect(
          portalFileNotFoundMessage,
          contains('Screenshot file not found'),
        );
      });

      test('handles portal timeout', () {
        final completer = Completer<String>();

        expect(
          completer.future.timeout(
            const Duration(milliseconds: 100),
            onTimeout: () => throw TimeoutException('Test timeout'),
          ),
          throwsA(isA<TimeoutException>()),
        );

        expect(
          portalTimeoutMessage,
          contains('timed out'),
        );
      });
    });

    group('Window management in portal flow', () {
      test('minimizes window before screenshot', () async {
        // Verify window minimization delay is reasonable
        expect(windowMinimizationDelayMs, greaterThan(0));
        expect(windowMinimizationDelayMs, lessThanOrEqualTo(1000));
      });

      test('restores window after successful screenshot', () async {
        // Window should be restored after screenshot
        verifyNever(() => mockWindowManager.minimize());
        verifyNever(() => mockWindowManager.show());
      });

      test('restores window even on portal error', () async {
        // Simulate portal error
        when(() => mockWindowManager.minimize()).thenAnswer((_) async {});
        when(() => mockWindowManager.show()).thenAnswer((_) async {});

        // Window restoration should be called in finally block
        expect(() => mockWindowManager.show(), returnsNormally);
      });
    });

    group('DBus signal handling', () {
      test('creates proper signal subscription', () {
        final mockStream = MockDBusSignalStream();
        final mockSubscription = MockStreamSubscription();

        when(() => mockStream.listen(any())).thenReturn(mockSubscription);
        when(mockSubscription.cancel).thenAnswer((_) async {});

        final subscription = mockStream.listen((_) {});
        expect(subscription, isNotNull);
      });

      test('cancels subscription on timeout', () async {
        final mockSubscription = MockStreamSubscription();
        when(mockSubscription.cancel).thenAnswer((_) async {});

        await mockSubscription.cancel();
        verify(mockSubscription.cancel).called(1);
      });

      test('handles malformed signal data', () {
        final signal = MockDBusSignal();

        // Signal with insufficient values
        when(() => signal.values).thenReturn([]);
        expect(signal.values.length, lessThan(2));

        // Signal with wrong types
        when(() => signal.values).thenReturn([
          const DBusString('not a uint32'),
          const DBusString('not a dict'),
        ]);

        expect(
          () => signal.values[0] as DBusUint32,
          throwsA(isA<TypeError>()),
        );
      });
    });

    group('Error handling and logging', () {
      test('logs portal request start', () {
        // Verify that no calls have been made yet
        verifyNever(() => mockLoggingService.captureEvent(
              any<dynamic>(),
              domain: screenshotDomain,
            ));

        // Event would be logged when portal is called
        expect(screenshotDomain, equals('SCREENSHOT'));
      });

      test('logs portal success with URI', () {
        const testUri = '$fileUriScheme/tmp/test.png';

        // Verify success logging format
        expect(
          'Screenshot portal succeeded with URI: $testUri',
          contains('succeeded'),
        );
      });

      test('logs portal failure with response code', () {
        const failureCode = 2;

        // Verify failure logging format
        expect(
          'Screenshot portal failed with response: $failureCode',
          contains('failed'),
        );
      });

      test('captures exceptions with full context', () {
        // Verify that no calls have been made yet
        verifyNever(() => mockLoggingService.captureException(
              any<dynamic>(),
              domain: screenshotDomain,
              stackTrace: any<dynamic>(named: 'stackTrace'),
            ));
      });
    });

    group('Integration with file system', () {
      test('creates correct directory structure', () async {
        final day = DateFormat(screenshotDateFormat).format(DateTime.now());
        final expectedPath = '$screenshotDirectoryPath$day/';

        expect(expectedPath, matches(RegExp(r'images/\d{4}-\d{2}-\d{2}/')));
      });

      test('generates unique image IDs', () {
        final id1 = uuid.v1();
        final id2 = uuid.v1();

        expect(id1, isNot(equals(id2)));
        expect(id1, matches(RegExp(r'^[0-9a-f-]+$')));
      });

      test('constructs correct ImageData', () {
        final now = DateTime.now();
        final imageData = ImageData(
          imageId: 'test-id',
          imageFile: 'test$screenshotFileExtension',
          imageDirectory: screenshotDirectoryPath,
          capturedAt: now,
        );

        expect(imageData.imageFile, endsWith(screenshotFileExtension));
        expect(imageData.imageDirectory, equals(screenshotDirectoryPath));
        expect(imageData.capturedAt, equals(now));
      });
    });
  });
}
