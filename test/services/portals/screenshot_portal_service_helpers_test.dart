import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/portals/screenshot_portal_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockLoggingService extends Mock implements LoggingService {}

void main() {
  group('ScreenshotPortalService helper functions', () {
    late _MockLoggingService mockLogging;

    setUpAll(() {
      registerFallbackValue(StackTrace.current);
    });

    setUp(() {
      mockLogging = _MockLoggingService();
      getIt.registerSingleton<LoggingService>(mockLogging);
      when(() => mockLogging.captureException(
            any<dynamic>(),
            domain: any(named: 'domain'),
            subDomain: any(named: 'subDomain'),
            stackTrace: any<dynamic>(named: 'stackTrace'),
          )).thenReturn(null);
    });

    tearDown(getIt.reset);

    group('parseUriFromResults', () {
      test('parses file URI from DBusVariant(DBusString)', () {
        final results = <DBusValue, DBusValue>{
          const DBusString('uri'):
              const DBusVariant(DBusString('file:///tmp/a.png')),
        };

        final path = ScreenshotPortalService.parseUriFromResults(results);
        expect(path, equals(Uri.parse('file:///tmp/a.png').toFilePath()));
      });

      test('parses file URI from DBusString', () {
        final results = <DBusValue, DBusValue>{
          const DBusString('uri'): const DBusString('file:///tmp/b.png'),
        };

        final path = ScreenshotPortalService.parseUriFromResults(results);
        expect(path, equals(Uri.parse('file:///tmp/b.png').toFilePath()));
      });

      test('returns null for missing uri', () {
        final results = <DBusValue, DBusValue>{};
        final path = ScreenshotPortalService.parseUriFromResults(results);
        expect(path, isNull);
      });

      test('returns null for non-file scheme', () {
        final results = <DBusValue, DBusValue>{
          const DBusString('uri'): const DBusString('http://example.com/x'),
        };
        final path = ScreenshotPortalService.parseUriFromResults(results);
        expect(path, isNull);
      });

      test('returns null for non-string value inside variant', () {
        final results = <DBusValue, DBusValue>{
          const DBusString('uri'): const DBusVariant(DBusUint32(123)),
        };
        final path = ScreenshotPortalService.parseUriFromResults(results);
        expect(path, isNull);
      });
    });

    group('persistScreenshot', () {
      test('moves or copies screenshot to target location', () async {
        final tempDir = await Directory.systemTemp.createTemp('lotti_portal_');
        addTearDown(() async {
          // ignore: avoid_slow_async_io
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        // Create a fake screenshot file
        final sourceFile = File('${tempDir.path}/source.png');
        await sourceFile.writeAsBytes([1, 2, 3, 4]);

        final targetPath = await ScreenshotPortalService.persistScreenshot(
          sourceFile.path,
          tempDir.path,
          'saved.png',
        );

        expect(targetPath, equals('${tempDir.path}/saved.png'));
        expect(File(targetPath).existsSync(), isTrue);
      });

      test('returns original path and logs on error', () async {
        final tempDir = await Directory.systemTemp.createTemp('lotti_portal_');
        addTearDown(() async {
          // ignore: avoid_slow_async_io
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        // Intentionally point to non-existent source file
        final bogusSource = '${tempDir.path}/does_not_exist.png';

        final result = await ScreenshotPortalService.persistScreenshot(
          bogusSource,
          tempDir.path,
          'ignored.png',
        );

        expect(result, equals(bogusSource));
        verify(() => mockLogging.captureException(
              any<dynamic>(),
              domain: 'ScreenshotPortalService',
              subDomain: 'file_copy_error',
              stackTrace: any<StackTrace?>(named: 'stackTrace'),
            )).called(1);
      });
    });
  });
}
