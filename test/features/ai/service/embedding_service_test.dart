import 'dart:async';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai/database/embeddings_db.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/service/embedding_content_extractor.dart';
import 'package:lotti/features/ai/service/embedding_service.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

/// A minimal [Metadata] for test entities.
Metadata _meta({String id = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'}) =>
    Metadata(
      id: id,
      createdAt: DateTime(2024, 3, 15),
      updatedAt: DateTime(2024, 3, 15),
      dateFrom: DateTime(2024, 3, 15),
      dateTo: DateTime(2024, 3, 15),
    );

const _entityId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
const _longText = 'This is a sufficiently long text for embedding generation.';

/// Creates a fake Float32List matching the expected dimensions.
Float32List _fakeEmbedding() => Float32List(kEmbeddingDimensions);

void main() {
  late MockEmbeddingsDb mockEmbeddingsDb;
  late MockOllamaEmbeddingRepository mockEmbeddingRepo;
  late MockJournalDb mockJournalDb;
  late MockAiConfigRepository mockAiConfigRepo;
  late UpdateNotifications updateNotifications;
  late EmbeddingService service;

  setUpAll(() {
    registerFallbackValue(Float32List(0));
  });

  setUp(() {
    mockEmbeddingsDb = MockEmbeddingsDb();
    mockEmbeddingRepo = MockOllamaEmbeddingRepository();
    mockJournalDb = MockJournalDb();
    mockAiConfigRepo = MockAiConfigRepository();
    updateNotifications = UpdateNotifications();

    service = EmbeddingService(
      embeddingsDb: mockEmbeddingsDb,
      embeddingRepository: mockEmbeddingRepo,
      journalDb: mockJournalDb,
      updateNotifications: updateNotifications,
      aiConfigRepository: mockAiConfigRepo,
    );

    // Default: flag enabled
    when(() => mockJournalDb.getConfigFlag(enableEmbeddingsFlag))
        .thenAnswer((_) async => true);

    // Default: Ollama provider configured
    when(() =>
            mockAiConfigRepo.getConfigsByType(AiConfigType.inferenceProvider))
        .thenAnswer(
      (_) async => [
        AiConfigInferenceProvider(
          id: 'ollama-1',
          name: 'Ollama',
          baseUrl: 'http://localhost:11434',
          apiKey: '',
          createdAt: DateTime(2024, 3, 15),
          inferenceProviderType: InferenceProviderType.ollama,
        ),
      ],
    );

    // Default: no existing content hash
    when(() => mockEmbeddingsDb.getContentHash(any())).thenReturn(null);

    // Default: upsert succeeds
    when(
      () => mockEmbeddingsDb.upsertEmbedding(
        entityId: any(named: 'entityId'),
        entityType: any(named: 'entityType'),
        modelId: any(named: 'modelId'),
        embedding: any(named: 'embedding'),
        contentHash: any(named: 'contentHash'),
      ),
    ).thenReturn(null);
  });

  tearDown(() async {
    await service.stop();
    await updateNotifications.dispose();
  });

  /// Helper: stubs journalEntityById to return [entity].
  void stubEntity(JournalEntity entity) {
    when(() => mockJournalDb.journalEntityById(entity.id))
        .thenAnswer((_) async => entity);
  }

  /// Helper: stubs the embedding repo to return a fake vector.
  void stubEmbedding() {
    when(
      () => mockEmbeddingRepo.embed(
        input: any(named: 'input'),
        baseUrl: any(named: 'baseUrl'),
        model: any(named: 'model'),
      ),
    ).thenAnswer((_) async => _fakeEmbedding());
  }

  /// Sends a notification batch and advances fake time past the debounce
  /// timer (100ms), then flushes microtasks so async processing completes.
  void sendAndProcess(FakeAsync async, Set<String> tokens) {
    updateNotifications.notify(tokens);
    async
      ..elapse(const Duration(milliseconds: 150))
      ..flushMicrotasks();
  }

  /// Stops the service inside the fake-async zone so in-flight futures
  /// created within that zone can complete before tearDown runs.
  void stopInZone(FakeAsync async) {
    unawaited(service.stop());
    async.flushMicrotasks();
  }

  group('EmbeddingService', () {
    test('generates embedding for a journal entry on notification', () {
      fakeAsync((async) {
        final entry = JournalEntry(
          meta: _meta(),
          entryText: const EntryText(plainText: _longText),
        );
        stubEntity(entry);
        stubEmbedding();
        service.start();

        sendAndProcess(async, {_entityId, textEntryNotification});

        verify(
          () => mockEmbeddingRepo.embed(
            input: _longText,
            baseUrl: 'http://localhost:11434',
          ),
        ).called(1);

        verify(
          () => mockEmbeddingsDb.upsertEmbedding(
            entityId: _entityId,
            entityType: kEntityTypeJournalText,
            modelId: ollamaEmbedDefaultModel,
            embedding: any(named: 'embedding'),
            contentHash: EmbeddingContentExtractor.contentHash(_longText),
          ),
        ).called(1);

        stopInZone(async);
      });
    });

    test('skips when content hash matches (unchanged content)', () {
      fakeAsync((async) {
        final entry = JournalEntry(
          meta: _meta(),
          entryText: const EntryText(plainText: _longText),
        );
        stubEntity(entry);

        // Simulate existing hash that matches current content.
        when(() => mockEmbeddingsDb.getContentHash(_entityId))
            .thenReturn(EmbeddingContentExtractor.contentHash(_longText));

        service.start();
        sendAndProcess(async, {_entityId, textEntryNotification});

        verifyNever(
          () => mockEmbeddingRepo.embed(
            input: any(named: 'input'),
            baseUrl: any(named: 'baseUrl'),
            model: any(named: 'model'),
          ),
        );

        stopInZone(async);
      });
    });

    test('skips when entity not found in DB', () {
      fakeAsync((async) {
        when(() => mockJournalDb.journalEntityById(_entityId))
            .thenAnswer((_) async => null);

        service.start();
        sendAndProcess(async, {_entityId, textEntryNotification});

        verifyNever(
          () => mockEmbeddingRepo.embed(
            input: any(named: 'input'),
            baseUrl: any(named: 'baseUrl'),
            model: any(named: 'model'),
          ),
        );

        stopInZone(async);
      });
    });

    test('skips when entity has no embeddable text', () {
      fakeAsync((async) {
        // JournalEntry with short text below threshold
        final entry = JournalEntry(
          meta: _meta(),
          entryText: const EntryText(plainText: 'short'),
        );
        stubEntity(entry);

        service.start();
        sendAndProcess(async, {_entityId, textEntryNotification});

        verifyNever(
          () => mockEmbeddingRepo.embed(
            input: any(named: 'input'),
            baseUrl: any(named: 'baseUrl'),
            model: any(named: 'model'),
          ),
        );

        stopInZone(async);
      });
    });

    test('skips when config flag is disabled', () {
      fakeAsync((async) {
        when(() => mockJournalDb.getConfigFlag(enableEmbeddingsFlag))
            .thenAnswer((_) async => false);

        final entry = JournalEntry(
          meta: _meta(),
          entryText: const EntryText(plainText: _longText),
        );
        stubEntity(entry);
        stubEmbedding();

        service.start();
        sendAndProcess(async, {_entityId, textEntryNotification});

        verifyNever(
          () => mockEmbeddingRepo.embed(
            input: any(named: 'input'),
            baseUrl: any(named: 'baseUrl'),
            model: any(named: 'model'),
          ),
        );

        stopInZone(async);
      });
    });

    test('skips when no Ollama provider is configured', () {
      fakeAsync((async) {
        when(() => mockAiConfigRepo
                .getConfigsByType(AiConfigType.inferenceProvider))
            .thenAnswer((_) async => <AiConfig>[]);

        final entry = JournalEntry(
          meta: _meta(),
          entryText: const EntryText(plainText: _longText),
        );
        stubEntity(entry);

        service.start();
        sendAndProcess(async, {_entityId, textEntryNotification});

        verifyNever(
          () => mockEmbeddingRepo.embed(
            input: any(named: 'input'),
            baseUrl: any(named: 'baseUrl'),
            model: any(named: 'model'),
          ),
        );

        stopInZone(async);
      });
    });

    test('ignores notification batches without relevant type tokens', () {
      fakeAsync((async) {
        final entry = JournalEntry(
          meta: _meta(),
          entryText: const EntryText(plainText: _longText),
        );
        stubEntity(entry);
        stubEmbedding();

        service.start();
        // Send only entity ID with an irrelevant type token
        sendAndProcess(async, {_entityId, imageNotification});

        verifyNever(
          () => mockEmbeddingRepo.embed(
            input: any(named: 'input'),
            baseUrl: any(named: 'baseUrl'),
            model: any(named: 'model'),
          ),
        );

        stopInZone(async);
      });
    });

    test('continues processing after Ollama error', () {
      fakeAsync((async) {
        const entityId2 = 'ffffffff-bbbb-cccc-dddd-eeeeeeeeeeee';

        final entry1 = JournalEntry(
          meta: _meta(),
          entryText: const EntryText(plainText: _longText),
        );
        final entry2 = JournalEntry(
          meta: _meta(id: entityId2),
          entryText: const EntryText(
            plainText: 'Another long enough text for embedding generation.',
          ),
        );

        stubEntity(entry1);
        when(() => mockJournalDb.journalEntityById(entityId2))
            .thenAnswer((_) async => entry2);

        // First call throws, second succeeds
        var callCount = 0;
        when(
          () => mockEmbeddingRepo.embed(
            input: any(named: 'input'),
            baseUrl: any(named: 'baseUrl'),
            model: any(named: 'model'),
          ),
        ).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) throw Exception('Ollama is down');
          return _fakeEmbedding();
        });

        service.start();
        sendAndProcess(
          async,
          {_entityId, entityId2, textEntryNotification},
        );

        // Both entities were attempted despite first failing
        verify(
          () => mockEmbeddingRepo.embed(
            input: any(named: 'input'),
            baseUrl: any(named: 'baseUrl'),
            model: any(named: 'model'),
          ),
        ).called(2);

        // Only second entity was stored (first failed)
        verify(
          () => mockEmbeddingsDb.upsertEmbedding(
            entityId: entityId2,
            entityType: any(named: 'entityType'),
            modelId: any(named: 'modelId'),
            embedding: any(named: 'embedding'),
            contentHash: any(named: 'contentHash'),
          ),
        ).called(1);

        stopInZone(async);
      });
    });

    test('generates embedding for a task', () {
      fakeAsync((async) {
        final task = Task(
          meta: _meta(),
          data: TaskData(
            status: TaskStatus.open(
              id: 'status-id',
              createdAt: DateTime(2024, 3, 15),
              utcOffset: 0,
            ),
            title: 'Implement the embedding pipeline feature',
            statusHistory: [],
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
          ),
          entryText: const EntryText(plainText: _longText),
        );
        stubEntity(task);
        stubEmbedding();

        service.start();
        sendAndProcess(async, {_entityId, taskNotification});

        verify(
          () => mockEmbeddingsDb.upsertEmbedding(
            entityId: _entityId,
            entityType: kEntityTypeTask,
            modelId: any(named: 'modelId'),
            embedding: any(named: 'embedding'),
            contentHash: any(named: 'contentHash'),
          ),
        ).called(1);

        stopInZone(async);
      });
    });

    test('stop cancels subscription and clears pending', () {
      fakeAsync((async) {
        final entry = JournalEntry(
          meta: _meta(),
          entryText: const EntryText(plainText: _longText),
        );
        stubEntity(entry);
        stubEmbedding();

        service.start();
        stopInZone(async);

        // Notification after stop should not trigger processing
        updateNotifications.notify({_entityId, textEntryNotification});
        async
          ..elapse(const Duration(milliseconds: 150))
          ..flushMicrotasks();

        verifyNever(
          () => mockEmbeddingRepo.embed(
            input: any(named: 'input'),
            baseUrl: any(named: 'baseUrl'),
            model: any(named: 'model'),
          ),
        );
      });
    });
  });

  group('EmbeddingService._isEntityId', () {
    // Testing the static method indirectly via notification handling

    test('filters out UPPER_SNAKE_CASE notification tokens', () {
      fakeAsync((async) {
        // Only type tokens, no entity IDs → nothing to process
        service.start();
        sendAndProcess(
          async,
          {textEntryNotification, taskNotification},
        );

        verifyNever(
          () => mockJournalDb.journalEntityById(any()),
        );

        stopInZone(async);
      });
    });
  });
}
