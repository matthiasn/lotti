import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/ai/service/embedding_service.dart';
import 'package:lotti/features/sync/backfill/backfill_request_service.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/app_prefs_service.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/window_service.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';

/// Stands in for the real frame wait, which needs a rendering binding.
Future<void> noClosingFrame() async {}

void main() {
  setUpAll(() {
    registerFallbackValue(<String>{});
  });

  group('WindowService shutdown sequence', () {
    setUp(() async {
      await getIt.reset();

      final mockDomainLogger = MockDomainLogger();
      final mockSettingsDb = MockSettingsDb();
      final mockBackfill = MockBackfillRequestService();
      final mockEmbeddingService = MockEmbeddingService();
      final mockOutbox = MockOutboxService();
      final mockMatrix = MockMatrixService();

      when(mockBackfill.dispose).thenReturn(null);
      when(mockEmbeddingService.stop).thenAnswer((_) async {});
      when(mockOutbox.dispose).thenAnswer((_) async {});
      when(mockMatrix.dispose).thenAnswer((_) async {});
      when(mockSettingsDb.close).thenAnswer((_) async {});

      getIt
        ..registerSingleton<DomainLogger>(mockDomainLogger)
        ..registerSingleton<SettingsDb>(mockSettingsDb)
        ..registerSingleton<BackfillRequestService>(mockBackfill)
        ..registerSingleton<EmbeddingService>(mockEmbeddingService)
        ..registerSingleton<OutboxService>(mockOutbox)
        ..registerSingleton<MatrixService>(mockMatrix);
    });

    tearDown(() async {
      await getIt.reset();
    });

    test('macOS shutdown closes databases before player and exit', () async {
      final callOrder = <String>[];
      final exitCompleter = Completer<int>();
      when(() => getIt<SettingsDb>().close()).thenAnswer((_) async {
        callOrder.add('databaseClose');
      });

      WindowService(
        skipWindowManagerSetup: true,
        closingFrameOverride: noClosingFrame,
        isMacOSOverride: () => true,
        exitOverride: (code) {
          callOrder.add('exit');
          exitCompleter.complete(code);
        },
        playerDisposerOverride: () async {
          callOrder.add('playerDispose');
        },
      ).onWindowClose();

      // Deterministically wait for exit to be called
      final exitCode = await exitCompleter.future;

      expect(callOrder, equals(['databaseClose', 'playerDispose', 'exit']));
      expect(exitCode, equals(0));
    });

    test('macOS shutdown calls exit even if player disposal throws', () async {
      final exitCompleter = Completer<int>();

      WindowService(
        skipWindowManagerSetup: true,
        closingFrameOverride: noClosingFrame,
        isMacOSOverride: () => true,
        exitOverride: exitCompleter.complete,
        playerDisposerOverride: () async {
          throw Exception('player disposal failed');
        },
      ).onWindowClose();

      final exitCode = await exitCompleter.future;
      expect(exitCode, equals(0));
    });

    test('macOS shutdown calls exit even if service disposal throws', () async {
      // Make service disposal throw
      when(() => getIt<OutboxService>().dispose()).thenThrow(Exception('boom'));

      final exitCompleter = Completer<int>();

      WindowService(
        skipWindowManagerSetup: true,
        closingFrameOverride: noClosingFrame,
        isMacOSOverride: () => true,
        exitOverride: exitCompleter.complete,
        playerDisposerOverride: () async {},
      ).onWindowClose();

      final exitCode = await exitCompleter.future;
      expect(exitCode, equals(0));
    });

    test('shutdown continues when the final log flush fails', () async {
      final loggingService = MockLoggingService();
      when(loggingService.flush).thenThrow(StateError('flush failed'));
      getIt.registerSingleton<LoggingService>(loggingService);

      await WindowService(
        skipWindowManagerSetup: true,
        closingFrameOverride: noClosingFrame,
        isMacOSOverride: () => true,
        exitOverride: (_) {},
        playerDisposerOverride: () async {},
      ).shutdown();

      verify(loggingService.flush).called(1);
      verify(() => getIt<SettingsDb>().close()).called(1);
    });

    test('shutdown drains framework summaries before log flush', () async {
      final callOrder = <String>[];
      final loggingService = MockLoggingService();
      when(() => getIt<SettingsDb>().close()).thenAnswer((_) async {
        callOrder.add('databaseClose');
      });
      when(loggingService.flush).thenAnswer((_) async {
        callOrder.add('logFlush');
      });
      getIt.registerSingleton<LoggingService>(loggingService);

      await WindowService(
        skipWindowManagerSetup: true,
        closingFrameOverride: noClosingFrame,
        isMacOSOverride: () => true,
        exitOverride: (_) {},
        playerDisposerOverride: () async {
          callOrder.add('playerDispose');
        },
        beforeLogFlush: () async {
          callOrder.add('frameworkSummaryDrain');
        },
      ).shutdown();

      expect(callOrder, [
        'databaseClose',
        'playerDispose',
        'frameworkSummaryDrain',
        'logFlush',
      ]);
    });

    test('detached lifecycle event triggers macOS shutdown sequence', () async {
      final exitCompleter = Completer<int>();
      final playerDisposed = Completer<void>();

      WindowService(
        skipWindowManagerSetup: true,
        closingFrameOverride: noClosingFrame,
        isMacOSOverride: () => true,
        exitOverride: exitCompleter.complete,
        playerDisposerOverride: () async {
          playerDisposed.complete();
        },
      ).didChangeAppLifecycleState(AppLifecycleState.detached);

      await playerDisposed.future;
      final exitCode = await exitCompleter.future;
      expect(exitCode, equals(0));
    });

    test('non-detached lifecycle events do not trigger shutdown', () async {
      var exitCalls = 0;

      final service = WindowService(
        skipWindowManagerSetup: true,
        closingFrameOverride: noClosingFrame,
        isMacOSOverride: () => true,
        exitOverride: (_) => exitCalls++,
        playerDisposerOverride: () async {},
      );

      const [
        AppLifecycleState.inactive,
        AppLifecycleState.paused,
        AppLifecycleState.resumed,
        AppLifecycleState.hidden,
      ].forEach(service.didChangeAppLifecycleState);

      // Yield once so any unawaited futures from a (mistaken) trigger
      // would have a chance to run.
      await Future<void>.delayed(Duration.zero);

      expect(exitCalls, equals(0));
    });

    test(
      'second shutdown trigger is ignored (window-close + detached)',
      () async {
        var exitCalls = 0;
        var playerDisposeCalls = 0;
        final firstExit = Completer<void>();

        final service = WindowService(
          skipWindowManagerSetup: true,
          closingFrameOverride: noClosingFrame,
          isMacOSOverride: () => true,
          exitOverride: (_) {
            exitCalls++;
            if (!firstExit.isCompleted) firstExit.complete();
          },
          playerDisposerOverride: () async {
            playerDisposeCalls++;
          },
        )..onWindowClose();

        await firstExit.future;
        // Now fire the lifecycle event that races with onWindowClose.
        service.didChangeAppLifecycleState(AppLifecycleState.detached);
        await Future<void>.delayed(Duration.zero);

        expect(exitCalls, equals(1));
        expect(playerDisposeCalls, equals(1));
      },
    );

    test('concurrent shutdown callers share one database teardown', () async {
      final outboxStarted = Completer<void>();
      final allowOutboxToStop = Completer<void>();
      when(() => getIt<OutboxService>().dispose()).thenAnswer((_) async {
        outboxStarted.complete();
        await allowOutboxToStop.future;
      });

      final service = WindowService(
        skipWindowManagerSetup: true,
        closingFrameOverride: noClosingFrame,
        isMacOSOverride: () => true,
        exitOverride: (_) {},
        playerDisposerOverride: () async {},
      );

      final first = service.shutdown();
      await outboxStarted.future;
      final second = service.shutdown();
      expect(identical(first, second), isTrue);

      allowOutboxToStop.complete();
      await Future.wait([first, second]);

      verify(() => getIt<SettingsDb>().close()).called(1);
      verify(() => getIt<OutboxService>().dispose()).called(1);
    });

    group('closing notice', () {
      test('closing is false until a quit starts', () {
        final service = WindowService(
          skipWindowManagerSetup: true,
          closingFrameOverride: noClosingFrame,
          isMacOSOverride: () => true,
          exitOverride: (_) {},
          playerDisposerOverride: () async {},
        );

        expect(service.closing.value, isFalse);
      });

      test(
        'raises closing and waits for its frame before closing databases',
        () async {
          final callOrder = <String>[];
          final frameShown = Completer<void>();
          late final WindowService service;
          when(() => getIt<SettingsDb>().close()).thenAnswer((_) async {
            callOrder.add('databaseClose');
          });

          service = WindowService(
            skipWindowManagerSetup: true,
            closingFrameOverride: () async {
              callOrder.add('frame(closing=${service.closing.value})');
              await frameShown.future;
            },
            isMacOSOverride: () => true,
            exitOverride: (_) => callOrder.add('exit'),
            playerDisposerOverride: () async {},
          );

          final close = service.closeWindow();
          await Future<void>.value();
          // Teardown is held until the notice has been painted.
          expect(callOrder, ['frame(closing=true)']);

          frameShown.complete();
          await close;

          expect(callOrder, ['frame(closing=true)', 'databaseClose', 'exit']);
          expect(service.closing.value, isTrue);
        },
      );

      test('a failing frame wait is logged and teardown still runs', () async {
        final exitCodes = <int>[];

        await WindowService(
          skipWindowManagerSetup: true,
          closingFrameOverride: () async => throw StateError('no binding'),
          isMacOSOverride: () => true,
          exitOverride: exitCodes.add,
          playerDisposerOverride: () async {},
        ).closeWindow();

        expect(exitCodes, [0]);
        verify(() => getIt<SettingsDb>().close()).called(1);
        verify(
          () => getIt<DomainLogger>().error(
            LogDomain.general,
            any<Object>(that: isA<StateError>()),
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'dispose_closingNotice',
          ),
        ).called(1);
      });

      test('the frame is awaited once even when quit fires twice', () async {
        var frames = 0;
        final service = WindowService(
          skipWindowManagerSetup: true,
          closingFrameOverride: () async => frames++,
          isMacOSOverride: () => true,
          exitOverride: (_) {},
          playerDisposerOverride: () async {},
        );

        await Future.wait([service.closeWindow(), service.closeWindow()]);

        expect(frames, 1);
      });
    });

    group('didRequestAppExit', () {
      test('answers exit at once when no quit is in progress', () async {
        final service = WindowService(
          skipWindowManagerSetup: true,
          closingFrameOverride: noClosingFrame,
          isMacOSOverride: () => true,
          exitOverride: (_) {},
          playerDisposerOverride: () async {},
        );

        expect(await service.didRequestAppExit(), AppExitResponse.exit);
        verifyNever(() => getIt<SettingsDb>().close());
      });

      test('holds a repeated quit until the running teardown ends', () async {
        final allowOutboxToStop = Completer<void>();
        final outboxStarted = Completer<void>();
        when(() => getIt<OutboxService>().dispose()).thenAnswer((_) async {
          outboxStarted.complete();
          await allowOutboxToStop.future;
        });
        final exitCodes = <int>[];
        final service = WindowService(
          skipWindowManagerSetup: true,
          closingFrameOverride: noClosingFrame,
          isMacOSOverride: () => true,
          exitOverride: exitCodes.add,
          playerDisposerOverride: () async {},
        );

        final close = service.closeWindow();
        await outboxStarted.future;

        AppExitResponse? secondResponse;
        unawaited(
          service.didRequestAppExit().then((r) => secondResponse = r),
        );
        await Future<void>.value();
        expect(secondResponse, isNull);
        expect(exitCodes, isEmpty);

        allowOutboxToStop.complete();
        await close;
        await Future<void>.value();

        expect(exitCodes, [0]);
        expect(secondResponse, AppExitResponse.exit);
      });
    });

    group('window geometry persistence', () {
      AppPrefs recordingPrefs(
        Map<String, String> store,
        List<({String key, String value})> writes,
      ) => AppPrefs(
        getBool: (_) async => null,
        setBool: ({required key, required value}) async => true,
        getString: (key) async => store[key],
        setString: ({required key, required value}) async {
          writes.add((key: key, value: value));
          store[key] = value;
          return true;
        },
      );

      WindowService buildService(AppPrefs prefs) => WindowService(
        skipWindowManagerSetup: true,
        closingFrameOverride: noClosingFrame,
        isMacOSOverride: () => false,
        exitOverride: (_) {},
        playerDisposerOverride: () async {},
        prefsOverride: prefs,
      );

      test(
        'resolveGeometry prefers prefs and never touches SettingsDb',
        () async {
          final writes = <({String key, String value})>[];
          final prefs = recordingPrefs({
            'WINDOW_SIZE': '800.0,600.0',
            'WINDOW_OFFSET': '10.0,20.0',
          }, writes);

          final (size, offset) = await buildService(prefs).resolveGeometry();

          expect(size, '800.0,600.0');
          expect(offset, '10.0,20.0');
          expect(writes, isEmpty);
          verifyNever(
            () => getIt<SettingsDb>().itemsByKeys(any()),
          );
        },
      );

      test(
        'resolveGeometry migrates legacy SettingsDb rows into prefs',
        () async {
          when(
            () => getIt<SettingsDb>().itemsByKeys(any()),
          ).thenAnswer(
            (_) async => {
              'WINDOW_SIZE': '1024.0,768.0',
              'WINDOW_OFFSET': '5.0,6.0',
            },
          );
          final writes = <({String key, String value})>[];
          final prefs = recordingPrefs({}, writes);

          final (size, offset) = await buildService(prefs).resolveGeometry();

          expect(size, '1024.0,768.0');
          expect(offset, '5.0,6.0');
          expect(writes, [
            (key: 'WINDOW_SIZE', value: '1024.0,768.0'),
            (key: 'WINDOW_OFFSET', value: '5.0,6.0'),
          ]);
        },
      );

      test('resolveGeometry returns nulls when nothing is persisted', () async {
        when(
          () => getIt<SettingsDb>().itemsByKeys(any()),
        ).thenAnswer((_) async => {});
        final prefs = recordingPrefs({}, []);

        final (size, offset) = await buildService(prefs).resolveGeometry();

        expect(size, isNull);
        expect(offset, isNull);
      });
    });

    test('non-macOS shutdown calls disposeAll', () async {
      // Track when the last service disposal completes so we can
      // deterministically await the async chain.
      final matrixDisposed = Completer<void>();
      when(
        () => (getIt<MatrixService>() as MockMatrixService).dispose(),
      ).thenAnswer((_) async {
        matrixDisposed.complete();
      });

      WindowService(
        skipWindowManagerSetup: true,
        closingFrameOverride: noClosingFrame,
        isMacOSOverride: () => false,
      ).onWindowClose();

      // MatrixService.dispose() is the last service in disposeAll's chain
      // (databases aren't registered here so _disposeAsyncSafely skips them).
      await matrixDisposed.future;

      verify(() => getIt<BackfillRequestService>().dispose()).called(1);
      verify(() => getIt<EmbeddingService>().stop()).called(1);
      verify(() => getIt<OutboxService>().dispose()).called(1);
      verify(() => getIt<MatrixService>().dispose()).called(1);
    });
  });

  group('awaitClosingNoticeFrame', () {
    testWidgets('resolves once the next frame is rendered', (tester) async {
      var resolved = false;
      unawaited(awaitClosingNoticeFrame().then((_) => resolved = true));

      await tester.pump();

      expect(resolved, isTrue);
    });

    testWidgets('resolves at once when frames are disabled', (tester) async {
      // A detached engine (SIGTERM, logout) or hidden window renders nothing.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
      try {
        expect(tester.binding.framesEnabled, isFalse);
        var resolved = false;
        unawaited(awaitClosingNoticeFrame().then((_) => resolved = true));

        // Microtasks only: a pump would render a frame and hide the wait.
        await Future<void>.value();
        await Future<void>.value();

        expect(resolved, isTrue);
      } finally {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      }
    });

    test('gives up after the frame budget when no frame comes', () {
      TestWidgetsFlutterBinding.ensureInitialized();
      fakeAsync((async) {
        var resolved = false;
        // An idle test binding never renders the frame endOfFrame waits for.
        awaitClosingNoticeFrame().then((_) => resolved = true);

        async.elapse(
          closingNoticeFrameBudget - const Duration(milliseconds: 1),
        );
        expect(resolved, isFalse);

        async.elapse(const Duration(milliseconds: 1));
        expect(resolved, isTrue);
      });
    });
  });
}
