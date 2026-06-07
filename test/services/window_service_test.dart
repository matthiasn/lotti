import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/ai/service/embedding_service.dart';
import 'package:lotti/features/sync/backfill/backfill_request_service.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/window_service.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';

void main() {
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

    test('macOS shutdown disposes player then calls exit', () async {
      final callOrder = <String>[];
      final exitCompleter = Completer<int>();

      WindowService(
        skipWindowManagerSetup: true,
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

      expect(callOrder, equals(['playerDispose', 'exit']));
      expect(exitCode, equals(0));
    });

    test('macOS shutdown calls exit even if player disposal throws', () async {
      final exitCompleter = Completer<int>();

      WindowService(
        skipWindowManagerSetup: true,
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
        isMacOSOverride: () => true,
        exitOverride: exitCompleter.complete,
        playerDisposerOverride: () async {},
      ).onWindowClose();

      final exitCode = await exitCompleter.future;
      expect(exitCode, equals(0));
    });

    test('detached lifecycle event triggers macOS shutdown sequence', () async {
      final exitCompleter = Completer<int>();
      final playerDisposed = Completer<void>();

      WindowService(
        skipWindowManagerSetup: true,
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
}
