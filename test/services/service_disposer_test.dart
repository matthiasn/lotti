import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
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
    test('disposeAll on empty container is a no-op', () async {
      await disposer.disposeAll();
      expect(loggedErrors, isEmpty);
    });

    test('disposeAll calls services and databases in expected order', () async {
      final order = <String>[];

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
      final settingsDb = MockSettingsDb();
      when(settingsDb.close).thenAnswer((_) async {
        order.add('SettingsDb');
      });

      testGetIt
        ..registerSingleton<BackfillRequestService>(backfill)
        ..registerSingleton<EmbeddingService>(embeddingService)
        ..registerSingleton<OutboxService>(outbox)
        ..registerSingleton<MatrixService>(matrix)
        ..registerSingleton<EmbeddingStore>(embeddingStore)
        ..registerSingleton<JournalDb>(journalDb)
        ..registerSingleton<SyncDatabase>(syncDb)
        ..registerSingleton<AgentDatabase>(agentDb)
        ..registerSingleton<EditorDb>(editorDb)
        ..registerSingleton<Fts5Db>(fts5Db)
        ..registerSingleton<SettingsDb>(settingsDb);

      await disposer.disposeAll();

      expect(order, [
        'BackfillRequestService',
        'EmbeddingService',
        'OutboxService',
        'MatrixService',
        'EmbeddingStore',
        'JournalDb',
        'SyncDatabase',
        'AgentDatabase',
        'EditorDb',
        'Fts5Db',
        'SettingsDb',
      ]);
      expect(loggedErrors, isEmpty);
    });

    test('disposeServicesOnly skips Drift databases', () async {
      final order = <String>[];

      final embeddingService = MockEmbeddingService();
      when(embeddingService.stop).thenAnswer((_) async {
        order.add('EmbeddingService');
      });
      final journalDb = MockJournalDb();
      when(journalDb.close).thenAnswer((_) async {
        order.add('JournalDb');
      });

      testGetIt
        ..registerSingleton<EmbeddingService>(embeddingService)
        ..registerSingleton<JournalDb>(journalDb);

      await disposer.disposeServicesOnly();

      expect(order, ['EmbeddingService']);
      expect(loggedErrors, isEmpty);
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

      await disposer.disposeServicesOnly();

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

      await disposer.disposeServicesOnly();

      expect(order, ['MatrixService']);
      expect(loggedErrors.single.service, 'OutboxService');
      expect(loggedErrors.single.error, isStateError);
    });

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

        unawaited(disposer.disposeServicesOnly());

        // Advance just past the per-operation timeout (3s).
        async
          ..elapse(const Duration(seconds: 3, milliseconds: 1))
          ..flushMicrotasks();

        expect(order, ['MatrixService']);
        expect(loggedErrors.single.service, 'OutboxService');
        expect(loggedErrors.single.error, isA<TimeoutException>());
      });
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
