import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/portals/portal_service.dart';
import 'package:lotti/services/portals/screenshot_portal_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fallbacks.dart';
import '../../mocks/mocks.dart';
import '../../widget_test_utils.dart';
import 'portal_test_doubles.dart';

class _ControlledScreenshotPortal extends ScreenshotPortalService {
  _ControlledScreenshotPortal(this.object) : super.forConnection();

  final DBusRemoteObject object;
  late final responses = StreamController<DBusSignal>(onCancel: () async {});
  bool enabled = true;
  int initialized = 0;
  int disposed = 0;
  DBusObjectPath? requestedHandle;

  @override
  bool get portalEnabled => enabled;

  @override
  Future<void> initialize() async {
    initialized++;
  }

  @override
  Future<void> dispose() async {
    disposed++;
  }

  @override
  DBusRemoteObject createPortalObject() => object;

  @override
  Stream<DBusSignal> screenshotResponses(DBusObjectPath handle) {
    requestedHandle = handle;
    return responses.stream;
  }

  void respond(List<DBusValue> values) => responses.add(
    DBusSignal(
      sender: 'org.freedesktop.portal.Desktop',
      path: DBusObjectPath('/request/screenshot'),
      interface: 'org.freedesktop.portal.Request',
      name: 'Response',
      values: values,
    ),
  );
}

void main() {
  group('ScreenshotPortalService', () {
    late _ControlledScreenshotPortal service;
    late MockDomainLogger mockDomainLogger;
    late MockDBusRemoteObject object;

    setUpAll(registerAllFallbackValues);
    setUp(() async {
      await setUpTestGetIt();
      mockDomainLogger = MockDomainLogger();
      await getIt.unregister<DomainLogger>();
      getIt.registerSingleton<DomainLogger>(mockDomainLogger);
      object = MockDBusRemoteObject();
      service = _ControlledScreenshotPortal(object);
      when(() => object.callMethod(any(), any(), any())).thenAnswer(
        (_) async => DBusMethodSuccessResponse([
          DBusObjectPath('/request/screenshot'),
        ]),
      );
    });
    tearDown(() async {
      if (service.requestedHandle == null) {
        service.responses.stream.listen((_) {});
      }
      await service.responses.close();
      await tearDownTestGetIt();
    });

    test(
      'rejects unsupported environments before opening a connection',
      () async {
        service.enabled = false;
        await expectLater(service.takeScreenshot(), throwsUnsupportedError);
        expect(service.initialized, 0);
        verifyNever(() => object.callMethod(any(), any(), any()));
      },
    );

    test(
      'requests interactive screenshot and returns the response file path',
      () {
        fakeAsync((async) {
          String? result;
          unawaited(
            service.takeScreenshot(interactive: true).then((path) {
              result = path;
            }),
          );
          async.flushMicrotasks();
          expect(
            service.requestedHandle,
            DBusObjectPath('/request/screenshot'),
          );
          expect(service.responses.hasListener, isTrue);
          final values =
              verify(
                    () => object.callMethod(
                      ScreenshotPortalConstants.interfaceName,
                      ScreenshotPortalConstants.screenshotMethod,
                      captureAny(),
                    ),
                  ).captured.single
                  as List<DBusValue>;
          expect(values.first, const DBusString(''));
          final options = values[1].asStringVariantDict();
          expect(options['interactive'], const DBusBoolean(true));
          expect(options['handle_token']!.asString(), startsWith('screenshot'));
          service.respond([
            const DBusUint32(0),
            DBusDict.stringVariant({
              'uri': const DBusString('file:///tmp/captured.png'),
            }),
          ]);
          async.flushMicrotasks();
          expect(result, '/tmp/captured.png');
          expect(service.disposed, 1);
          expect(service.responses.hasListener, isFalse);
          expect(async.pendingTimers, isEmpty);
        });
      },
    );

    for (final code in [1, 2]) {
      test(
        'response code $code completes with cancellation/error and cleans up',
        () {
          fakeAsync((async) {
            var completed = false;
            String? result = 'not completed';
            unawaited(
              service.takeScreenshot().then((path) {
                result = path;
                completed = true;
              }),
            );
            async.flushMicrotasks();
            service.respond([DBusUint32(code), DBusDict.stringVariant({})]);
            async.flushMicrotasks();
            expect(completed, isTrue);
            expect(result, isNull);
            expect(service.disposed, 1);
            expect(service.responses.hasListener, isFalse);
            verify(
              () => mockDomainLogger.error(
                LogDomain.screenshots,
                any<Object>(),
                subDomain: 'portal_error',
              ),
            ).called(1);
          });
        },
      );
    }

    test('response timeout completes with error and cancels subscription', () {
      fakeAsync((async) {
        Object? failure;
        unawaited(
          service.takeScreenshot().then<void>(
            (_) {
              fail('Expected timeout');
            },
            onError: (Object error) {
              failure = error;
            },
          ),
        );
        async.flushMicrotasks();
        async.elapse(
          PortalConstants.responseTimeout - const Duration(milliseconds: 1),
        );
        expect(failure, isNull);
        expect(service.disposed, 0);
        async.elapse(const Duration(milliseconds: 1));
        expect(
          failure,
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('request timed out'),
          ),
        );
        expect(service.disposed, 1);
        expect(service.responses.hasListener, isFalse);
        expect(async.pendingTimers, isEmpty);
      });
    });

    test('method timeout closes the connection without subscribing', () {
      when(() => object.callMethod(any(), any(), any())).thenAnswer(
        (_) => Completer<DBusMethodSuccessResponse>().future,
      );
      fakeAsync((async) {
        Object? failure;
        unawaited(
          service.takeScreenshot().then<void>(
            (_) {
              fail('Expected timeout');
            },
            onError: (Object error) {
              failure = error;
            },
          ),
        );
        async.flushMicrotasks();
        async.elapse(PortalConstants.responseTimeout);
        expect(failure, isA<TimeoutException>());
        expect(service.disposed, 1);
        expect(service.responses.hasListener, isFalse);
      });
    });

    test(
      'empty method response is an error and closes the connection',
      () async {
        when(() => object.callMethod(any(), any(), any())).thenAnswer(
          (_) async => DBusMethodSuccessResponse([]),
        );
        await expectLater(
          service.takeScreenshot(),
          throwsA(
            isA<Exception>().having(
              (error) => error.toString(),
              'message',
              contains('no response'),
            ),
          ),
        );
        expect(service.disposed, 1);
        expect(service.responses.hasListener, isFalse);
      },
    );

    test(
      'malformed signal propagates the parse error and cancels subscription',
      () {
        fakeAsync((async) {
          Object? failure;
          unawaited(
            service.takeScreenshot().then<void>(
              (_) {
                fail('Expected parse error');
              },
              onError: (Object error) {
                failure = error;
              },
            ),
          );
          async.flushMicrotasks();
          service.respond([
            const DBusString('wrong type'),
            DBusDict.stringVariant({}),
          ]);
          async.flushMicrotasks();
          expect(failure, isA<TypeError>());
          expect(service.disposed, 1);
          expect(service.responses.hasListener, isFalse);
        });
      },
    );

    test(
      'successful response persists exact bytes at the requested destination',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'portal_response_',
        );
        addTearDown(() => directory.delete(recursive: true));
        final source = File('${directory.path}/source.png');
        await source.writeAsBytes([9, 8, 7]);
        service.responses.onListen = () => service.respond([
          const DBusUint32(0),
          DBusDict.stringVariant({'uri': DBusString(source.uri.toString())}),
        ]);
        final result = await service.takeScreenshot(
          directory: directory.path,
          filename: 'saved.png',
        );
        expect(result, '${directory.path}/saved.png');
        expect(await File(result!).readAsBytes(), [9, 8, 7]);
        expect(service.disposed, 1);
        expect(service.responses.hasListener, isFalse);
      },
    );

    group('helper functions', () {
      group('parseUriFromResults', () {
        test('parses file URI from DBusVariant(DBusString)', () {
          final results = <DBusValue, DBusValue>{
            const DBusString('uri'): const DBusVariant(
              DBusString('file:///tmp/a.png'),
            ),
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
          final tempDir = await Directory.systemTemp.createTemp(
            'lotti_portal_',
          );
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
          expect(await File(targetPath).readAsBytes(), [1, 2, 3, 4]);
        });

        test('returns original path and logs on error', () async {
          final tempDir = await Directory.systemTemp.createTemp(
            'lotti_portal_',
          );
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
          verify(
            () => mockDomainLogger.error(
              LogDomain.screenshots,
              any<Object>(),
              stackTrace: any<StackTrace?>(named: 'stackTrace'),
              subDomain: 'file_copy_error',
            ),
          ).called(1);
        });
      });
    });
  });
}
