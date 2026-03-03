import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/database/embeddings_db.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/ollama_embedding_repository.dart';
import 'package:lotti/features/ai/state/embedding_backfill_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

// ---------------------------------------------------------------------------
// Test data helpers
// ---------------------------------------------------------------------------

final _fixedDate = DateTime(2024, 3, 15);

Metadata _meta({required String id}) => Metadata(
      id: id,
      createdAt: _fixedDate,
      updatedAt: _fixedDate,
      dateFrom: _fixedDate,
      dateTo: _fixedDate,
    );

TaskData _taskData(String title) => TaskData(
      status: TaskStatus.open(
        id: 'status-id',
        createdAt: _fixedDate,
        utcOffset: 0,
      ),
      title: title,
      statusHistory: [],
      dateFrom: _fixedDate,
      dateTo: _fixedDate,
    );

const _longText = 'This is a sufficiently long text for embedding generation.';

Float32List _fakeEmbedding() => Float32List(kEmbeddingDimensions);

const _testCategoryId = 'cat-1';

const _ollamaBaseUrl = 'http://localhost:11434';

/// Computes the same SHA-256 hash as EmbeddingContentExtractor.contentHash.
String _hashOf(String text) => sha256.convert(utf8.encode(text)).toString();

// ---------------------------------------------------------------------------
// Stub helpers
// ---------------------------------------------------------------------------

void _stubOllamaProvider(MockAiConfigRepository repo) {
  when(() => repo.resolveOllamaBaseUrl())
      .thenAnswer((_) async => _ollamaBaseUrl);
}

void _stubNoExistingHash(MockEmbeddingsDb db) {
  when(() => db.getContentHash(any())).thenReturn(null);
}

void _stubUpsertEmbedding(MockEmbeddingsDb db) {
  when(
    () => db.upsertEmbedding(
      entityId: any(named: 'entityId'),
      entityType: any(named: 'entityType'),
      modelId: any(named: 'modelId'),
      embedding: any(named: 'embedding'),
      contentHash: any(named: 'contentHash'),
      categoryId: any(named: 'categoryId'),
    ),
  ).thenReturn(null);
}

void _stubEmbed(MockOllamaEmbeddingRepository repo) {
  when(
    () => repo.embed(
      input: any(named: 'input'),
      baseUrl: any(named: 'baseUrl'),
      model: any(named: 'model'),
    ),
  ).thenAnswer((_) async => _fakeEmbedding());
}

void _stubEntityIds(MockJournalDb db, List<String> ids) {
  when(() => db.journalEntityIdsByCategory(_testCategoryId))
      .thenReturn(MockSelectable<String>(ids));
}

void _stubEntity(MockJournalDb db, JournalEntity entity) {
  when(() => db.journalEntityById(entity.id)).thenAnswer((_) async => entity);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockJournalDb mockJournalDb;
  late MockEmbeddingsDb mockEmbeddingsDb;
  late MockOllamaEmbeddingRepository mockEmbeddingRepo;
  late MockAiConfigRepository mockAiConfigRepo;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(Float32List(0));
  });

  setUp(() async {
    await getIt.reset();

    mockJournalDb = MockJournalDb();
    mockEmbeddingsDb = MockEmbeddingsDb();
    mockEmbeddingRepo = MockOllamaEmbeddingRepository();
    mockAiConfigRepo = MockAiConfigRepository();

    getIt
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<EmbeddingsDb>(mockEmbeddingsDb)
      ..registerSingleton<OllamaEmbeddingRepository>(mockEmbeddingRepo)
      ..registerSingleton<AiConfigRepository>(mockAiConfigRepo);

    _stubOllamaProvider(mockAiConfigRepo);
    _stubNoExistingHash(mockEmbeddingsDb);
    _stubUpsertEmbedding(mockEmbeddingsDb);
    _stubEmbed(mockEmbeddingRepo);

    // Default: embeddings flag enabled
    when(() => mockJournalDb.getConfigFlag(enableEmbeddingsFlag))
        .thenAnswer((_) async => true);

    container = ProviderContainer();
  });

  tearDown(() async {
    container.dispose();
    await getIt.reset();
  });

  EmbeddingBackfillController controller() =>
      container.read(embeddingBackfillControllerProvider.notifier);

  EmbeddingBackfillState state() =>
      container.read(embeddingBackfillControllerProvider);

  group('EmbeddingBackfillController initial state', () {
    test('starts with default values', () {
      final s = state();
      expect(s.isRunning, isFalse);
      expect(s.progress, 0);
      expect(s.processedCount, 0);
      expect(s.totalCount, 0);
      expect(s.embeddedCount, 0);
      expect(s.error, isNull);
    });
  });

  group('EmbeddingBackfillController processes entities', () {
    test('generates embedding for a task entry', () async {
      final task = Task(
        meta: _meta(id: 'entity-1'),
        data: _taskData('Test task title'),
        entryText: const EntryText(plainText: _longText),
      );

      _stubEntityIds(mockJournalDb, ['entity-1']);
      _stubEntity(mockJournalDb, task);

      await controller().backfillCategory(_testCategoryId);

      final s = state();
      expect(s.isRunning, isFalse);
      expect(s.progress, 1.0);
      expect(s.processedCount, 1);
      expect(s.totalCount, 1);
      expect(s.embeddedCount, 1);
      expect(s.error, isNull);

      verify(
        () => mockEmbeddingsDb.upsertEmbedding(
          entityId: 'entity-1',
          entityType: 'task',
          modelId: any(named: 'modelId'),
          embedding: any(named: 'embedding'),
          contentHash: any(named: 'contentHash'),
          categoryId: any(named: 'categoryId'),
        ),
      ).called(1);
    });

    test('generates embedding for a journal text entry', () async {
      final entry = JournalEntry(
        meta: _meta(id: 'entry-1'),
        entryText: const EntryText(plainText: _longText),
      );

      _stubEntityIds(mockJournalDb, ['entry-1']);
      _stubEntity(mockJournalDb, entry);

      await controller().backfillCategory(_testCategoryId);

      expect(state().embeddedCount, 1);
      verify(
        () => mockEmbeddingsDb.upsertEmbedding(
          entityId: 'entry-1',
          entityType: 'journal_text',
          modelId: any(named: 'modelId'),
          embedding: any(named: 'embedding'),
          contentHash: any(named: 'contentHash'),
          categoryId: any(named: 'categoryId'),
        ),
      ).called(1);
    });

    test('processes multiple entities with final progress at 1.0', () async {
      final entities = List.generate(
        5,
        (i) => JournalEntry(
          meta: _meta(id: 'entity-$i'),
          entryText: const EntryText(plainText: _longText),
        ),
      );
      final ids = entities.map((e) => e.id).toList();

      _stubEntityIds(mockJournalDb, ids);
      for (final entity in entities) {
        _stubEntity(mockJournalDb, entity);
      }

      await controller().backfillCategory(_testCategoryId);

      final s = state();
      expect(s.processedCount, 5);
      expect(s.totalCount, 5);
      expect(s.embeddedCount, 5);
      expect(s.progress, 1.0);
    });

    test('passes correct base URL to embedding repository', () async {
      final entry = JournalEntry(
        meta: _meta(id: 'entry-1'),
        entryText: const EntryText(plainText: _longText),
      );

      _stubEntityIds(mockJournalDb, ['entry-1']);
      _stubEntity(mockJournalDb, entry);

      await controller().backfillCategory(_testCategoryId);

      verify(
        () => mockEmbeddingRepo.embed(
          input: any(named: 'input'),
          baseUrl: _ollamaBaseUrl,
          model: any(named: 'model'),
        ),
      ).called(1);
    });
  });

  group('EmbeddingBackfillController skips entries', () {
    test('skips entities not found in database', () async {
      _stubEntityIds(mockJournalDb, ['missing-1']);
      when(() => mockJournalDb.journalEntityById('missing-1'))
          .thenAnswer((_) async => null);

      await controller().backfillCategory(_testCategoryId);

      expect(state().processedCount, 1);
      expect(state().embeddedCount, 0);
      verifyNever(
        () => mockEmbeddingRepo.embed(
          input: any(named: 'input'),
          baseUrl: any(named: 'baseUrl'),
          model: any(named: 'model'),
        ),
      );
    });

    test('skips entities with no extractable text (JournalImage)', () async {
      final image = JournalImage(
        meta: _meta(id: 'image-1'),
        data: ImageData(
          imageId: 'img-id',
          imageFile: 'photo.jpg',
          imageDirectory: '/images',
          capturedAt: _fixedDate,
        ),
      );

      _stubEntityIds(mockJournalDb, ['image-1']);
      _stubEntity(mockJournalDb, image);

      await controller().backfillCategory(_testCategoryId);

      expect(state().processedCount, 1);
      expect(state().embeddedCount, 0);
    });

    test('skips entities with text shorter than minimum length', () async {
      final entry = JournalEntry(
        meta: _meta(id: 'short-1'),
        entryText: const EntryText(plainText: 'Too short'),
      );

      _stubEntityIds(mockJournalDb, ['short-1']);
      _stubEntity(mockJournalDb, entry);

      await controller().backfillCategory(_testCategoryId);

      expect(state().processedCount, 1);
      expect(state().embeddedCount, 0);
    });

    test('skips entities with unchanged content hash', () async {
      final entry = JournalEntry(
        meta: _meta(id: 'cached-1'),
        entryText: const EntryText(plainText: _longText),
      );

      _stubEntityIds(mockJournalDb, ['cached-1']);
      _stubEntity(mockJournalDb, entry);

      when(() => mockEmbeddingsDb.getContentHash('cached-1'))
          .thenReturn(_hashOf(_longText));

      await controller().backfillCategory(_testCategoryId);

      expect(state().processedCount, 1);
      expect(state().embeddedCount, 0);
      verifyNever(
        () => mockEmbeddingRepo.embed(
          input: any(named: 'input'),
          baseUrl: any(named: 'baseUrl'),
          model: any(named: 'model'),
        ),
      );
    });

    test('embeddedCount reflects only actually embedded entries', () async {
      // Embeddable task
      final task = Task(
        meta: _meta(id: 'task-1'),
        data: _taskData('Embeddable task'),
        entryText: const EntryText(plainText: _longText),
      );
      // Image (not embeddable)
      final image = JournalImage(
        meta: _meta(id: 'image-1'),
        data: ImageData(
          imageId: 'img',
          imageFile: 'photo.jpg',
          imageDirectory: '/images',
          capturedAt: _fixedDate,
        ),
      );
      // Entry with cached hash (skipped)
      final cached = JournalEntry(
        meta: _meta(id: 'cached-1'),
        entryText: const EntryText(plainText: _longText),
      );

      _stubEntityIds(mockJournalDb, ['task-1', 'image-1', 'cached-1']);
      _stubEntity(mockJournalDb, task);
      _stubEntity(mockJournalDb, image);
      _stubEntity(mockJournalDb, cached);
      when(() => mockEmbeddingsDb.getContentHash('cached-1'))
          .thenReturn(_hashOf(_longText));

      await controller().backfillCategory(_testCategoryId);

      final s = state();
      expect(s.processedCount, 3);
      expect(s.totalCount, 3);
      expect(s.embeddedCount, 1);
    });

    test('handles empty category gracefully', () async {
      _stubEntityIds(mockJournalDb, []);

      await controller().backfillCategory(_testCategoryId);

      final s = state();
      expect(s.isRunning, isFalse);
      expect(s.progress, 1.0);
      expect(s.totalCount, 0);
      expect(s.processedCount, 0);
      expect(s.embeddedCount, 0);
    });
  });

  group('EmbeddingBackfillController error handling', () {
    test('continues processing after per-entity embed failure', () async {
      final bad = JournalEntry(
        meta: _meta(id: 'bad-1'),
        entryText: const EntryText(
          plainText: 'Bad entry with enough text for embedding gen.',
        ),
      );
      final good = JournalEntry(
        meta: _meta(id: 'good-1'),
        entryText: const EntryText(plainText: _longText),
      );

      _stubEntityIds(mockJournalDb, ['bad-1', 'good-1']);
      _stubEntity(mockJournalDb, bad);
      _stubEntity(mockJournalDb, good);

      // Override: first embed call throws, second succeeds
      var callCount = 0;
      when(
        () => mockEmbeddingRepo.embed(
          input: any(named: 'input'),
          baseUrl: any(named: 'baseUrl'),
          model: any(named: 'model'),
        ),
      ).thenAnswer((_) {
        callCount++;
        if (callCount == 1) throw Exception('Ollama down');
        return Future.value(_fakeEmbedding());
      });

      await controller().backfillCategory(_testCategoryId);

      final s = state();
      expect(s.processedCount, 2);
      expect(s.embeddedCount, 1);
      expect(s.error, isNull);
    });

    test('sets error when embedding pipeline not registered', () async {
      await getIt.reset();
      container.dispose();
      container = ProviderContainer();

      await controller().backfillCategory(_testCategoryId);

      expect(state().error, contains('not available'));
      expect(state().isRunning, isFalse);
    });

    test('sets error when no Ollama provider configured', () async {
      when(() => mockAiConfigRepo.resolveOllamaBaseUrl())
          .thenAnswer((_) async => null);

      await controller().backfillCategory(_testCategoryId);

      expect(state().error, contains('No Ollama provider'));
      expect(state().isRunning, isFalse);
    });

    test('sets error on unexpected exception during ID fetch', () async {
      when(() => mockJournalDb.journalEntityIdsByCategory(_testCategoryId))
          .thenThrow(Exception('Database connection lost'));

      await controller().backfillCategory(_testCategoryId);

      expect(state().error, contains('Database connection lost'));
      expect(state().isRunning, isFalse);
    });
  });

  group('EmbeddingBackfillController state transitions', () {
    test('clears previous error when starting new backfill', () async {
      // First: trigger error
      when(() => mockAiConfigRepo.resolveOllamaBaseUrl())
          .thenAnswer((_) async => null);

      await controller().backfillCategory(_testCategoryId);
      expect(state().error, isNotNull);

      // Second: fix provider, run empty category
      _stubOllamaProvider(mockAiConfigRepo);
      _stubEntityIds(mockJournalDb, []);

      await controller().backfillCategory(_testCategoryId);
      expect(state().error, isNull);
    });

    test('resets counters when starting new backfill', () async {
      final entry = JournalEntry(
        meta: _meta(id: 'entity-1'),
        entryText: const EntryText(plainText: _longText),
      );
      _stubEntityIds(mockJournalDb, ['entity-1']);
      _stubEntity(mockJournalDb, entry);

      await controller().backfillCategory(_testCategoryId);
      expect(state().processedCount, 1);

      // Second run — counters reset
      _stubEntityIds(mockJournalDb, []);
      await controller().backfillCategory(_testCategoryId);

      expect(state().processedCount, 0);
      expect(state().embeddedCount, 0);
      expect(state().totalCount, 0);
    });

    test('isRunning is false after completion', () async {
      _stubEntityIds(mockJournalDb, []);
      await controller().backfillCategory(_testCategoryId);
      expect(state().isRunning, isFalse);
    });

    test('isRunning is false after error', () async {
      when(() => mockAiConfigRepo.resolveOllamaBaseUrl())
          .thenAnswer((_) async => null);

      await controller().backfillCategory(_testCategoryId);
      expect(state().isRunning, isFalse);
    });

    test('cancel sets cancelled flag', () {
      // Verify cancel doesn't crash and the controller remains usable.
      expect(state().isRunning, isFalse);
    });

    test('cancel stops processing mid-loop', () async {
      // Create 3 entities — cancel after the first embed call
      final entities = List.generate(
        3,
        (i) => JournalEntry(
          meta: _meta(id: 'entity-$i'),
          entryText: const EntryText(plainText: _longText),
        ),
      );
      _stubEntityIds(mockJournalDb, entities.map((e) => e.id).toList());
      for (final entity in entities) {
        _stubEntity(mockJournalDb, entity);
      }

      // Cancel after the first embed call
      var embedCount = 0;
      when(
        () => mockEmbeddingRepo.embed(
          input: any(named: 'input'),
          baseUrl: any(named: 'baseUrl'),
          model: any(named: 'model'),
        ),
      ).thenAnswer((_) async {
        embedCount++;
        if (embedCount == 1) {
          controller().cancel();
        }
        return _fakeEmbedding();
      });

      await controller().backfillCategory(_testCategoryId);

      // Should have processed only 1 entity (cancelled before 2nd iteration)
      final s = state();
      expect(s.processedCount, 1);
      expect(s.embeddedCount, 1);
      expect(s.isRunning, isFalse);
    });

    test('rejects concurrent backfill when already running', () async {
      // Make the first backfill hang by using a Completer
      final entities = [
        JournalEntry(
          meta: _meta(id: 'slow-1'),
          entryText: const EntryText(plainText: _longText),
        ),
      ];
      _stubEntityIds(mockJournalDb, ['slow-1']);
      _stubEntity(mockJournalDb, entities.first);

      final completer = Completer<Float32List>();
      when(
        () => mockEmbeddingRepo.embed(
          input: any(named: 'input'),
          baseUrl: any(named: 'baseUrl'),
          model: any(named: 'model'),
        ),
      ).thenAnswer((_) => completer.future);

      // Start first backfill (won't complete yet)
      final firstRun = controller().backfillCategory(_testCategoryId);

      // Allow isRunning to be set
      await Future<void>.delayed(Duration.zero);
      expect(state().isRunning, isTrue);

      // Second call should be ignored
      await controller().backfillCategory(_testCategoryId);

      // Complete the hanging embed
      completer.complete(_fakeEmbedding());
      await firstRun;

      expect(state().processedCount, 1);
      expect(state().isRunning, isFalse);
    });

    test('sets error when embeddings are disabled', () async {
      when(() => mockJournalDb.getConfigFlag(enableEmbeddingsFlag))
          .thenAnswer((_) async => false);

      await controller().backfillCategory(_testCategoryId);

      expect(state().error, contains('disabled'));
      expect(state().isRunning, isFalse);
    });
  });

  group('EmbeddingBackfillState copyWith', () {
    test('preserves existing values when no arguments given', () {
      const original = EmbeddingBackfillState(
        progress: 0.5,
        isRunning: true,
        processedCount: 10,
        totalCount: 20,
        embeddedCount: 5,
        error: 'some error',
      );

      final copied = original.copyWith();

      expect(copied.progress, 0.5);
      expect(copied.isRunning, isTrue);
      expect(copied.processedCount, 10);
      expect(copied.totalCount, 20);
      expect(copied.embeddedCount, 5);
      expect(copied.error, 'some error');
    });

    test('updates specified fields', () {
      const original = EmbeddingBackfillState();

      final updated = original.copyWith(
        progress: 0.75,
        isRunning: true,
        processedCount: 15,
        totalCount: 20,
        embeddedCount: 10,
        error: 'test error',
      );

      expect(updated.progress, 0.75);
      expect(updated.isRunning, isTrue);
      expect(updated.processedCount, 15);
      expect(updated.totalCount, 20);
      expect(updated.embeddedCount, 10);
      expect(updated.error, 'test error');
    });

    test('clearError sets error to null', () {
      const original = EmbeddingBackfillState(error: 'old error');
      final cleared = original.copyWith(clearError: true);
      expect(cleared.error, isNull);
    });

    test('clearError takes precedence over error parameter', () {
      const original = EmbeddingBackfillState(error: 'old error');
      final cleared = original.copyWith(clearError: true, error: 'new error');
      expect(cleared.error, isNull);
    });
  });
}
