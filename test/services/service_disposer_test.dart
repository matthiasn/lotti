import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/notifications_db.dart';
import 'package:lotti/database/onboarding_metrics_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/service/embedding_service.dart';
import 'package:lotti/features/ai_consumption/database/consumption_database.dart';
import 'package:lotti/features/daily_os_next/database/day_processing_db.dart';
import 'package:lotti/features/habits/service/habit_auto_completion_notifier.dart';
import 'package:lotti/features/habits/service/habit_auto_completion_service.dart';
import 'package:lotti/features/sync/backfill/backfill_request_service.dart';
import 'package:lotti/features/sync/backfill/sync_recovery_service.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/services/service_disposer.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';

void main() {
  late GetIt testGetIt;
  late List<({Object error, StackTrace stackTrace, String service})>
  loggedErrors;
  late ServiceDisposer disposer;

  void logError(dynamic error, StackTrace stackTrace, String service) {
    loggedErrors.add(
      (error: error as Object, stackTrace: stackTrace, service: service),
    );
  }

  setUp(() {
    testGetIt = GetIt.asNewInstance();
    loggedErrors = [];
    disposer = ServiceDisposer(testGetIt, logError);
  });

  group('ServiceDisposer', () {
    test('drains automatic backfill before closing its stores', () {
      fakeAsync((async) {
        final pending = Completer<void>();
        final backfill = MockBackfillRequestService();
        when(backfill.stopAndDrain).thenAnswer((_) => pending.future);
        var databaseClosed = false;
        final database = MockSyncDatabase();
        when(database.close).thenAnswer((_) async => databaseClosed = true);
        testGetIt
          ..registerSingleton<BackfillRequestService>(backfill)
          ..registerSingleton<SyncDatabase>(database);
        var disposed = false;
        unawaited(disposer.disposeAll().then((_) => disposed = true));
        async.elapse(const Duration(seconds: 4));
        expect(databaseClosed, isFalse);
        expect(disposed, isFalse);
        pending.complete();
        async.flushMicrotasks();
        expect(databaseClosed, isTrue);
        expect(disposed, isTrue);
        expect(loggedErrors, isEmpty);
      });
    });

    for (final recoveryFails in [false, true]) {
      test(
        'drains slow recovery before closing stores (failure=$recoveryFails)',
        () {
          fakeAsync((async) {
            final pending = Completer<void>();
            final order = <String>[];
            final recovery = SyncRecoveryService(
              logging: MockDomainLogger(),
              recover: () {
                order.add('recover');
                return pending.future;
              },
            );
            final outbox = MockOutboxService();
            when(outbox.dispose).thenAnswer((_) async => order.add('outbox'));
            final syncDb = MockSyncDatabase();
            when(syncDb.close).thenAnswer((_) async => order.add('database'));
            testGetIt
              ..registerSingleton<SyncRecoveryService>(
                recovery,
                dispose: (service) => service.dispose(),
              )
              ..registerSingleton<OutboxService>(outbox)
              ..registerSingleton<SyncDatabase>(syncDb);
            unawaited(recovery.start());
            List<ServiceDisposalFailure>? failures;
            unawaited(disposer.disposeAll().then((value) => failures = value));
            async.flushMicrotasks();
            expect(order, ['recover']);
            expect(failures, isNull);

            // Future.timeout does not cancel the work it stops awaiting. Stores
            // must remain open even after the ordinary disposal deadline passes.
            async
              ..elapse(const Duration(seconds: 4))
              ..flushMicrotasks();
            expect(order, ['recover']);
            expect(failures, isNull);
            expect(loggedErrors, isEmpty);

            if (recoveryFails) {
              pending.completeError(StateError('recovery store unavailable'));
            } else {
              pending.complete();
            }
            async.flushMicrotasks();
            expect(order, ['recover', 'outbox', 'database']);
            expect(failures, isEmpty);

            var resetFinished = false;
            unawaited(testGetIt.reset().then((_) => resetFinished = true));
            async.flushMicrotasks();
            expect(resetFinished, isTrue);
            async.elapse(const Duration(minutes: 10));
            expect(order, ['recover', 'outbox', 'database']);
          });
        },
      );
    }

    test('disposeAll on empty container is a no-op', () async {
      await disposer.disposeAll();
      expect(loggedErrors, isEmpty);
    });

    test('disposeAll calls services and databases in expected order', () async {
      final order = <String>[];

      final autoCompletionNotifier = MockHabitAutoCompletionNotifier();
      when(autoCompletionNotifier.dispose).thenAnswer((_) {
        order.add('HabitAutoCompletionNotifier');
      });
      final autoCompletion = MockHabitAutoCompletionService();
      when(autoCompletion.dispose).thenAnswer((_) {
        order.add('HabitAutoCompletionService');
      });
      final backfill = MockBackfillRequestService();
      when(backfill.dispose).thenAnswer((_) {
        order.add('BackfillRequestService');
      });
      final embeddingService = MockEmbeddingService();
      when(embeddingService.stop).thenAnswer((_) async {
        order.add('EmbeddingService');
      });
      final outbox = MockOutboxService();
      when(outbox.dispose).thenAnswer((_) async {
        order.add('OutboxService');
      });
      final matrix = MockMatrixService();
      when(matrix.dispose).thenAnswer((_) async {
        order.add('MatrixService');
      });
      final embeddingStore = MockEmbeddingStore();
      when(embeddingStore.close).thenAnswer((_) {
        order.add('EmbeddingStore');
      });
      final aiConfigRepository = MockAiConfigRepository();
      when(aiConfigRepository.close).thenAnswer((_) async {
        order.add('AiConfigRepository');
      });

      final journalDb = MockJournalDb();
      when(journalDb.close).thenAnswer((_) async {
        order.add('JournalDb');
      });
      final syncDb = MockSyncDatabase();
      when(syncDb.close).thenAnswer((_) async {
        order.add('SyncDatabase');
      });
      final agentDb = MockAgentDatabase();
      when(agentDb.close).thenAnswer((_) async {
        order.add('AgentDatabase');
      });
      final editorDb = MockEditorDb();
      when(editorDb.close).thenAnswer((_) async {
        order.add('EditorDb');
      });
      final fts5Db = MockFts5Db();
      when(fts5Db.close).thenAnswer((_) async {
        order.add('Fts5Db');
      });
      final consumptionDb = MockConsumptionDatabase();
      when(consumptionDb.close).thenAnswer((_) async {
        order.add('ConsumptionDatabase');
      });
      final notificationsDb = MockNotificationsDb();
      when(notificationsDb.close).thenAnswer((_) async {
        order.add('NotificationsDb');
      });
      final onboardingMetricsDb = MockOnboardingMetricsDb();
      when(onboardingMetricsDb.close).thenAnswer((_) async {
        order.add('OnboardingMetricsDb');
      });
      final dayProcessingDb = MockDayProcessingDb();
      when(dayProcessingDb.close).thenAnswer((_) async {
        order.add('DayProcessingDb');
      });
      final settingsDb = MockSettingsDb();
      when(settingsDb.close).thenAnswer((_) async {
        order.add('SettingsDb');
      });

      testGetIt
        ..registerSingleton<HabitAutoCompletionNotifier>(
          autoCompletionNotifier,
        )
        ..registerSingleton<HabitAutoCompletionService>(autoCompletion)
        ..registerSingleton<BackfillRequestService>(backfill)
        ..registerSingleton<EmbeddingService>(embeddingService)
        ..registerSingleton<OutboxService>(outbox)
        ..registerSingleton<MatrixService>(matrix)
        ..registerSingleton<EmbeddingStore>(embeddingStore)
        ..registerSingleton<AiConfigRepository>(aiConfigRepository)
        ..registerSingleton<JournalDb>(journalDb)
        ..registerSingleton<SyncDatabase>(syncDb)
        ..registerSingleton<AgentDatabase>(agentDb)
        ..registerSingleton<EditorDb>(editorDb)
        ..registerSingleton<Fts5Db>(fts5Db)
        ..registerSingleton<ConsumptionDatabase>(consumptionDb)
        ..registerSingleton<NotificationsDb>(notificationsDb)
        ..registerSingleton<OnboardingMetricsDb>(onboardingMetricsDb)
        ..registerSingleton<DayProcessingDb>(dayProcessingDb)
        ..registerSingleton<SettingsDb>(settingsDb);

      await disposer.disposeAll();

      expect(order, [
        'HabitAutoCompletionNotifier',
        'HabitAutoCompletionService',
        'BackfillRequestService',
        'EmbeddingService',
        'OutboxService',
        'MatrixService',
        'EmbeddingStore',
        'AiConfigRepository',
        'JournalDb',
        'SyncDatabase',
        'AgentDatabase',
        'EditorDb',
        'Fts5Db',
        'ConsumptionDatabase',
        'NotificationsDb',
        'OnboardingMetricsDb',
        'DayProcessingDb',
        'SettingsDb',
      ]);
      expect(loggedErrors, isEmpty);
    });

    test('refreshes planner statistics before closing each database', () async {
      final steps = <String>[];
      final journalDb = MockJournalDb();
      when(() => journalDb.customStatement(any())).thenAnswer((
        invocation,
      ) async {
        steps.add('optimize:${invocation.positionalArguments.first}');
      });
      when(journalDb.close).thenAnswer((_) async {
        steps.add('close');
      });
      testGetIt.registerSingleton<JournalDb>(journalDb);

      await disposer.disposeAll();

      // Shutdown is the one moment PRAGMA optimize costs nothing, and it
      // only counts if it lands while the connection is still open.
      expect(steps, ['optimize:PRAGMA optimize', 'close']);
      expect(loggedErrors, isEmpty);
    });

    test('closes a database whose optimize fails', () async {
      final journalDb = MockJournalDb();
      when(() => journalDb.customStatement(any())).thenThrow(
        StateError('optimize boom'),
      );
      var closed = false;
      when(journalDb.close).thenAnswer((_) async {
        closed = true;
      });
      testGetIt.registerSingleton<JournalDb>(journalDb);

      await disposer.disposeAll();

      expect(closed, isTrue);
      expect(loggedErrors, isEmpty, reason: 'optimize failure is not fatal');
    });

    test('continues disposing even if a service throws', () async {
      final order = <String>[];

      final backfill = MockBackfillRequestService();
      when(backfill.dispose).thenThrow(StateError('backfill boom'));

      final embeddingService = MockEmbeddingService();
      when(embeddingService.stop).thenAnswer((_) async {
        order.add('EmbeddingService');
      });

      testGetIt
        ..registerSingleton<BackfillRequestService>(backfill)
        ..registerSingleton<EmbeddingService>(embeddingService);

      await disposer.disposeAll();

      expect(order, ['EmbeddingService']);
      expect(loggedErrors.single.service, 'BackfillRequestService');
      expect(loggedErrors.single.error, isStateError);
    });

    test('continues if an async service throws', () async {
      final order = <String>[];

      final outbox = MockOutboxService();
      when(outbox.dispose).thenThrow(StateError('outbox boom'));

      final matrix = MockMatrixService();
      when(matrix.dispose).thenAnswer((_) async {
        order.add('MatrixService');
      });

      testGetIt
        ..registerSingleton<OutboxService>(outbox)
        ..registerSingleton<MatrixService>(matrix);

      await disposer.disposeAll();

      expect(order, ['MatrixService']);
      expect(loggedErrors.single.service, 'OutboxService');
      expect(loggedErrors.single.error, isStateError);
    });

    test(
      'continues closing later databases when an earlier close throws',
      () async {
        final order = <String>[];

        final journalDb = MockJournalDb();
        when(journalDb.close).thenThrow(StateError('db boom'));
        final syncDb = MockSyncDatabase();
        when(syncDb.close).thenAnswer((_) async {
          order.add('SyncDatabase');
        });
        final settingsDb = MockSettingsDb();
        when(settingsDb.close).thenAnswer((_) async {
          order.add('SettingsDb');
        });

        testGetIt
          ..registerSingleton<JournalDb>(journalDb)
          ..registerSingleton<SyncDatabase>(syncDb)
          ..registerSingleton<SettingsDb>(settingsDb);

        await disposer.disposeAll();

        expect(order, ['SyncDatabase', 'SettingsDb']);
        expect(loggedErrors.single.service, 'JournalDb');
        expect(loggedErrors.single.error, isStateError);
      },
    );

    test('times out a hung disposal and proceeds to the next service', () {
      fakeAsync((async) {
        final order = <String>[];

        final outbox = MockOutboxService();
        // Outbox.dispose() will never complete.
        when(outbox.dispose).thenAnswer((_) => Completer<void>().future);

        final matrix = MockMatrixService();
        when(matrix.dispose).thenAnswer((_) async {
          order.add('MatrixService');
        });

        testGetIt
          ..registerSingleton<OutboxService>(outbox)
          ..registerSingleton<MatrixService>(matrix);

        unawaited(disposer.disposeAll());

        // Advance just past the per-operation timeout (3s).
        async
          ..elapse(const Duration(seconds: 3, milliseconds: 1))
          ..flushMicrotasks();

        expect(order, ['MatrixService']);
        expect(loggedErrors.single.service, 'OutboxService');
        expect(loggedErrors.single.error, isA<TimeoutException>());
      });
    });

    test('returns every failure it logged, a timeout included', () {
      fakeAsync((async) {
        final backfill = MockBackfillRequestService();
        when(backfill.dispose).thenThrow(StateError('backfill boom'));
        final outbox = MockOutboxService();
        when(outbox.dispose).thenAnswer((_) => Completer<void>().future);
        final journalDb = MockJournalDb();
        when(() => journalDb.customStatement(any())).thenAnswer((_) async {});
        when(journalDb.close).thenAnswer((_) async {});
        testGetIt
          ..registerSingleton<BackfillRequestService>(backfill)
          ..registerSingleton<OutboxService>(outbox)
          ..registerSingleton<JournalDb>(journalDb);

        List<ServiceDisposalFailure>? failures;
        unawaited(disposer.disposeAll().then((value) => failures = value));
        async
          ..elapse(const Duration(seconds: 3, milliseconds: 1))
          ..flushMicrotasks();

        // A caller that must know the generation is closed sees exactly what
        // the log saw, in order; the clean JournalDb close is not reported.
        expect(failures!.map((f) => f.service), [
          'BackfillRequestService',
          'OutboxService',
        ]);
        expect(failures!.first.error, isStateError);
        expect(failures!.last.error, isA<TimeoutException>());
        expect(failures!.first.toString(), contains('backfill boom'));
        expect(loggedErrors.map((e) => e.service), [
          'BackfillRequestService',
          'OutboxService',
        ]);
      });
    });

    test('a later disposeAll does not repeat earlier failures', () async {
      final backfill = MockBackfillRequestService();
      when(backfill.dispose).thenThrow(StateError('backfill boom'));
      testGetIt.registerSingleton<BackfillRequestService>(backfill);

      expect(await disposer.disposeAll(), hasLength(1));
      testGetIt.unregister<BackfillRequestService>();

      expect(await disposer.disposeAll(), isEmpty);
    });

    test('a clean disposal returns no failures', () async {
      final journalDb = MockJournalDb();
      when(() => journalDb.customStatement(any())).thenAnswer((_) async {});
      when(journalDb.close).thenAnswer((_) async {});
      testGetIt.registerSingleton<JournalDb>(journalDb);

      expect(await disposer.disposeAll(), isEmpty);
      verify(journalDb.close).called(1);
    });

    test(
      'disposeAll on partial registrations only runs registered services',
      () async {
        final order = <String>[];

        final journalDb = MockJournalDb();
        when(journalDb.close).thenAnswer((_) async {
          order.add('JournalDb');
        });
        final embeddingStore = MockEmbeddingStore();
        when(embeddingStore.close).thenAnswer((_) {
          order.add('EmbeddingStore');
        });

        testGetIt
          ..registerSingleton<EmbeddingStore>(embeddingStore)
          ..registerSingleton<JournalDb>(journalDb);

        await disposer.disposeAll();

        // Only the two registered services should fire, in the documented order
        // (EmbeddingStore is step 4, JournalDb is step 5).
        expect(order, ['EmbeddingStore', 'JournalDb']);
        expect(loggedErrors, isEmpty);
      },
    );
  });
}
