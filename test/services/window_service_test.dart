import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/service/embedding_service.dart';
import 'package:lotti/features/sync/backfill/backfill_request_service.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/service_disposer.dart';
import 'package:lotti/services/window_service.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';

void _noOpLog(dynamic error, StackTrace stackTrace, String service) {}

void main() {
  group('ServiceDisposer', () {
    late MockBackfillRequestService mockBackfill;
    late MockEmbeddingService mockEmbeddingService;
    late MockOutboxService mockOutbox;
    late MockMatrixService mockMatrix;
    late MockJournalDb mockJournalDb;
    late MockSyncDatabase mockSyncDb;
    late MockAgentDatabase mockAgentDb;
    late MockEditorDb mockEditorDb;
    late MockFts5Db mockFts5Db;
    late MockSettingsDb mockSettingsDb;
    late MockEmbeddingStore mockEmbeddingStore;
    late ServiceDisposer disposer;

    setUp(() async {
      await getIt.reset();

      mockBackfill = MockBackfillRequestService();
      mockEmbeddingService = MockEmbeddingService();
      mockOutbox = MockOutboxService();
      mockMatrix = MockMatrixService();
      mockJournalDb = MockJournalDb();
      mockSyncDb = MockSyncDatabase();
      mockAgentDb = MockAgentDatabase();
      mockEditorDb = MockEditorDb();
      mockFts5Db = MockFts5Db();
      mockSettingsDb = MockSettingsDb();
      mockEmbeddingStore = MockEmbeddingStore();

      when(mockBackfill.dispose).thenReturn(null);
      when(mockEmbeddingService.stop).thenAnswer((_) async {});
      when(mockOutbox.dispose).thenAnswer((_) async {});
      when(mockMatrix.dispose).thenAnswer((_) async {});
      when(mockJournalDb.close).thenAnswer((_) async {});
      when(mockSyncDb.close).thenAnswer((_) async {});
      when(mockAgentDb.close).thenAnswer((_) async {});
      when(mockEditorDb.close).thenAnswer((_) async {});
      when(mockFts5Db.close).thenAnswer((_) async {});
      when(mockSettingsDb.close).thenAnswer((_) async {});
      when(mockEmbeddingStore.close).thenReturn(null);

      getIt
        ..registerSingleton<BackfillRequestService>(mockBackfill)
        ..registerSingleton<EmbeddingService>(mockEmbeddingService)
        ..registerSingleton<OutboxService>(mockOutbox)
        ..registerSingleton<MatrixService>(mockMatrix)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<SyncDatabase>(mockSyncDb)
        ..registerSingleton<AgentDatabase>(mockAgentDb)
        ..registerSingleton<EditorDb>(mockEditorDb)
        ..registerSingleton<Fts5Db>(mockFts5Db)
        ..registerSingleton<SettingsDb>(mockSettingsDb)
        ..registerSingleton<EmbeddingStore>(mockEmbeddingStore);

      disposer = ServiceDisposer(getIt, _noOpLog);
    });

    tearDown(() async {
      await getIt.reset();
    });

    test('disposes all services and databases', () async {
      await disposer.disposeAll();

      verify(mockBackfill.dispose).called(1);
      verify(mockEmbeddingService.stop).called(1);
      verify(mockOutbox.dispose).called(1);
      verify(mockMatrix.dispose).called(1);
      verify(mockJournalDb.close).called(1);
      verify(mockSyncDb.close).called(1);
      verify(mockAgentDb.close).called(1);
      verify(mockEditorDb.close).called(1);
      verify(mockFts5Db.close).called(1);
      verify(mockSettingsDb.close).called(1);
      verify(mockEmbeddingStore.close).called(1);
    });

    test('disposes OutboxService before MatrixService', () async {
      final callOrder = <String>[];

      when(mockOutbox.dispose).thenAnswer((_) async {
        callOrder.add('OutboxService');
      });
      when(mockMatrix.dispose).thenAnswer((_) async {
        callOrder.add('MatrixService');
      });

      await disposer.disposeAll();

      final outboxIndex = callOrder.indexOf('OutboxService');
      final matrixIndex = callOrder.indexOf('MatrixService');
      expect(outboxIndex, lessThan(matrixIndex));
    });

    test('continues disposal when a service throws', () async {
      when(mockOutbox.dispose).thenThrow(Exception('outbox boom'));

      await disposer.disposeAll();

      verify(mockMatrix.dispose).called(1);
      verify(mockJournalDb.close).called(1);
      verify(mockEmbeddingStore.close).called(1);
    });

    test('continues disposal when a database close throws', () async {
      when(mockJournalDb.close).thenThrow(Exception('db boom'));

      await disposer.disposeAll();

      verify(mockSyncDb.close).called(1);
      verify(mockSettingsDb.close).called(1);
      verify(mockEmbeddingStore.close).called(1);
    });

    test('handles missing services gracefully', () async {
      await getIt.reset();
      final emptyDisposer = ServiceDisposer(getIt, _noOpLog);

      await emptyDisposer.disposeAll();
      // Should not throw
    });

    test('disposeServicesOnly skips Drift database close calls', () async {
      await disposer.disposeServicesOnly();

      verify(mockBackfill.dispose).called(1);
      verify(mockEmbeddingService.stop).called(1);
      verify(mockOutbox.dispose).called(1);
      verify(mockMatrix.dispose).called(1);
      // ObjectBox embedding store is safe to close on macOS — see service_disposer.
      verify(mockEmbeddingStore.close).called(1);

      verifyNever(mockJournalDb.close);
      verifyNever(mockSyncDb.close);
      verifyNever(mockAgentDb.close);
      verifyNever(mockEditorDb.close);
      verifyNever(mockFts5Db.close);
      verifyNever(mockSettingsDb.close);
    });

    test('logs errors via the provided callback', () async {
      final loggedErrors = <String>[];
      final loggingDisposer = ServiceDisposer(
        getIt,
        (error, stackTrace, service) => loggedErrors.add(service),
      );

      when(mockOutbox.dispose).thenThrow(Exception('boom'));
      when(mockJournalDb.close).thenThrow(Exception('db boom'));

      await loggingDisposer.disposeAll();

      expect(loggedErrors, contains('OutboxService'));
      expect(loggedErrors, contains('JournalDb'));
    });
  });

  group('WindowService shutdown sequence', () {
    setUp(() async {
      await getIt.reset();

      final mockLoggingService = MockLoggingService();
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
        ..registerSingleton<LoggingService>(mockLoggingService)
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
