import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/service/embedding_service.dart';
import 'package:lotti/features/sync/backfill/backfill_request_service.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/service_disposer.dart';
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
    late MockLoggingDb mockLoggingDb;
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
      mockLoggingDb = MockLoggingDb();
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
      when(mockLoggingDb.close).thenAnswer((_) async {});
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
        ..registerSingleton<LoggingDb>(mockLoggingDb)
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
      verify(mockLoggingDb.close).called(1);
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
      // Should not throw.
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
}
