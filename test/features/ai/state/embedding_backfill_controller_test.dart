import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/ollama_embedding_repository.dart';
import 'package:lotti/features/ai/state/embedding_backfill_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

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
  status: TaskStatus.open(id: 'status-id', createdAt: _fixedDate, utcOffset: 0),
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
  when(
    () => repo.resolveOllamaBaseUrl(),
  ).thenAnswer((_) async => _ollamaBaseUrl);
}

void _stubNoExistingHash(MockEmbeddingStore db) {
  when(() => db.getContentHash(any())).thenReturn(null);
}

void _stubReplaceEntityEmbeddings(MockEmbeddingStore db) {
  when(
    () => db.replaceEntityEmbeddings(
      entityId: any(named: 'entityId'),
      entityType: any(named: 'entityType'),
      modelId: any(named: 'modelId'),
      contentHash: any(named: 'contentHash'),
      embeddings: any(named: 'embeddings'),
      categoryId: any(named: 'categoryId'),
      taskId: any(named: 'taskId'),
      subtype: any(named: 'subtype'),
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
  when(
    () => db.journalEntityIdsByCategory(_testCategoryId),
  ).thenReturn(MockSelectable<String>(ids));
}

void _stubEntity(MockJournalDb db, JournalEntity entity) {
  when(() => db.journalEntityById(entity.id)).thenAnswer((_) async => entity);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockJournalDb mockJournalDb;
  late MockEmbeddingStore mockEmbeddingStore;
  late MockOllamaEmbeddingRepository mockEmbeddingRepo;
  late MockAiConfigRepository mockAiConfigRepo;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(Float32List(0));
  });

  setUp(() async {
    mockJournalDb = MockJournalDb();
    mockEmbeddingStore = MockEmbeddingStore();
    mockEmbeddingRepo = MockOllamaEmbeddingRepository();
    mockAiConfigRepo = MockAiConfigRepository();

    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..unregister<JournalDb>()
          ..registerSingleton<JournalDb>(mockJournalDb)
          ..unregister<EmbeddingStore>()
          ..registerSingleton<EmbeddingStore>(mockEmbeddingStore)
          ..unregister<OllamaEmbeddingRepository>()
          ..registerSingleton<OllamaEmbeddingRepository>(mockEmbeddingRepo)
          ..registerSingleton<AiConfigRepository>(mockAiConfigRepo);
      },
    );

    _stubOllamaProvider(mockAiConfigRepo);
    _stubNoExistingHash(mockEmbeddingStore);
    _stubReplaceEntityEmbeddings(mockEmbeddingStore);
    _stubEmbed(mockEmbeddingRepo);

    // Default: embeddings flag enabled
    when(
      () => mockJournalDb.getConfigFlag(enableEmbeddingsFlag),
    ).thenAnswer((_) async => true);

    // Default: no labels (needed for label resolver)
    when(
      () => mockJournalDb.getAllLabelDefinitions(),
    ).thenAnswer((_) async => []);

    container = ProviderContainer();
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestGetIt();
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

      await controller().backfillCategories({_testCategoryId});

      final s = state();
      expect(s.isRunning, isFalse);
      expect(s.progress, 1.0);
      expect(s.processedCount, 1);
      expect(s.totalCount, 1);
      expect(s.embeddedCount, 1);
      expect(s.error, isNull);

      verify(
        () => mockEmbeddingStore.replaceEntityEmbeddings(
          entityId: 'entity-1',
          entityType: 'task',
          modelId: any(named: 'modelId'),
          contentHash: any(named: 'contentHash'),
          embeddings: any(named: 'embeddings'),
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

      await controller().backfillCategories({_testCategoryId});

      expect(state().embeddedCount, 1);
      verify(
        () => mockEmbeddingStore.replaceEntityEmbeddings(
          entityId: 'entry-1',
          entityType: 'journal_text',
          modelId: any(named: 'modelId'),
          contentHash: any(named: 'contentHash'),
          embeddings: any(named: 'embeddings'),
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

      await controller().backfillCategories({_testCategoryId});

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

      await controller().backfillCategories({_testCategoryId});

      verify(
        () => mockEmbeddingRepo.embed(
          input: any(named: 'input'),
          baseUrl: _ollamaBaseUrl,
          model: any(named: 'model'),
        ),
      ).called(1);
    });

    test('processes entities across multiple categories', () async {
      const catA = 'cat-a';
      const catB = 'cat-b';

      final entryA = JournalEntry(
        meta: _meta(id: 'entry-a'),
        entryText: const EntryText(plainText: _longText),
      );
      final entryB1 = JournalEntry(
        meta: _meta(id: 'entry-b1'),
        entryText: const EntryText(plainText: _longText),
      );
      final entryB2 = JournalEntry(
        meta: _meta(id: 'entry-b2'),
        entryText: const EntryText(plainText: _longText),
      );

      when(
        () => mockJournalDb.journalEntityIdsByCategory(catA),
      ).thenReturn(MockSelectable<String>(['entry-a']));
      when(
        () => mockJournalDb.journalEntityIdsByCategory(catB),
      ).thenReturn(MockSelectable<String>(['entry-b1', 'entry-b2']));

      _stubEntity(mockJournalDb, entryA);
      _stubEntity(mockJournalDb, entryB1);
      _stubEntity(mockJournalDb, entryB2);

      await controller().backfillCategories({catA, catB});

      final s = state();
      expect(s.processedCount, 3);
      expect(s.totalCount, 3);
      expect(s.embeddedCount, 3);
      expect(s.progress, 1.0);
      expect(s.error, isNull);
    });

    test('handles empty categories in multi-category set', () async {
      const catEmpty = 'cat-empty';
      const catFull = 'cat-full';

      final entry = JournalEntry(
        meta: _meta(id: 'entry-1'),
        entryText: const EntryText(plainText: _longText),
      );

      when(
        () => mockJournalDb.journalEntityIdsByCategory(catEmpty),
      ).thenReturn(MockSelectable<String>([]));
      when(
        () => mockJournalDb.journalEntityIdsByCategory(catFull),
      ).thenReturn(MockSelectable<String>(['entry-1']));

      _stubEntity(mockJournalDb, entry);

      await controller().backfillCategories({catEmpty, catFull});

      final s = state();
      expect(s.processedCount, 1);
      expect(s.totalCount, 1);
      expect(s.embeddedCount, 1);
      expect(s.progress, 1.0);
    });

    test('completes with progress 1.0 when all categories are empty', () async {
      when(
        () => mockJournalDb.journalEntityIdsByCategory('cat-x'),
      ).thenReturn(MockSelectable<String>([]));
      when(
        () => mockJournalDb.journalEntityIdsByCategory('cat-y'),
      ).thenReturn(MockSelectable<String>([]));

      await controller().backfillCategories({'cat-x', 'cat-y'});

      final s = state();
      expect(s.progress, 1.0);
      expect(s.totalCount, 0);
      expect(s.processedCount, 0);
    });
  });

  group('EmbeddingBackfillController skips entries', () {
    test('skips entities not found in database', () async {
      _stubEntityIds(mockJournalDb, ['missing-1']);
      when(
        () => mockJournalDb.journalEntityById('missing-1'),
      ).thenAnswer((_) async => null);

      await controller().backfillCategories({_testCategoryId});

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

      await controller().backfillCategories({_testCategoryId});

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

      await controller().backfillCategories({_testCategoryId});

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

      when(
        () => mockEmbeddingStore.getContentHash('cached-1'),
      ).thenReturn(_hashOf(_longText));

      await controller().backfillCategories({_testCategoryId});

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
      when(
        () => mockEmbeddingStore.getContentHash('cached-1'),
      ).thenReturn(_hashOf(_longText));

      await controller().backfillCategories({_testCategoryId});

      final s = state();
      expect(s.processedCount, 3);
      expect(s.totalCount, 3);
      expect(s.embeddedCount, 1);
    });

    test('handles empty category gracefully', () async {
      _stubEntityIds(mockJournalDb, []);

      await controller().backfillCategories({_testCategoryId});

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

      await controller().backfillCategories({_testCategoryId});

      final s = state();
      expect(s.processedCount, 2);
      expect(s.embeddedCount, 1);
      expect(s.error, isNull);
    });

    test('stops category backfill when Ollama is cooling down', () async {
      final entries = [
        JournalEntry(
          meta: _meta(id: 'first-1'),
          entryText: const EntryText(plainText: _longText),
        ),
        JournalEntry(
          meta: _meta(id: 'second-1'),
          entryText: const EntryText(
            plainText: 'Another long enough entry for embedding.',
          ),
        ),
      ];
      _stubEntityIds(mockJournalDb, entries.map((entry) => entry.id).toList());
      for (final entry in entries) {
        _stubEntity(mockJournalDb, entry);
      }
      when(
        () => mockEmbeddingRepo.embed(
          input: any(named: 'input'),
          baseUrl: any(named: 'baseUrl'),
          model: any(named: 'model'),
        ),
      ).thenThrow(
        OllamaEmbeddingCooldownException(
          retryAt: DateTime.utc(2026, 8, 1, 12, 5),
          suppressedRequestCount: 1,
        ),
      );

      await controller().backfillCategories({_testCategoryId});

      final s = state();
      expect(s.processedCount, 1);
      expect(s.progress, 0.5);
      expect(s.error, isNull);
      expect(
        s.errorCode,
        EmbeddingBackfillErrorCode.ollamaUnavailable,
      );
      verify(
        () => mockEmbeddingRepo.embed(
          input: any(named: 'input'),
          baseUrl: any(named: 'baseUrl'),
          model: any(named: 'model'),
        ),
      ).called(1);
      verifyNever(() => mockJournalDb.journalEntityById('second-1'));
    });

    test('surfaces the initial exhausted Ollama outage', () async {
      final entry = JournalEntry(
        meta: _meta(id: 'offline-1'),
        entryText: const EntryText(plainText: _longText),
      );
      _stubEntityIds(mockJournalDb, [entry.id]);
      _stubEntity(mockJournalDb, entry);

      var requestCount = 0;
      final unavailableRepository = OllamaEmbeddingRepository(
        httpClient: MockClient((request) async {
          requestCount++;
          throw http.ClientException('Ollama is offline', request.url);
        }),
      );
      getIt
        ..unregister<OllamaEmbeddingRepository>()
        ..registerSingleton<OllamaEmbeddingRepository>(
          unavailableRepository,
        );
      OllamaEmbeddingRepository.retryBaseDelay = Duration.zero;

      try {
        await controller().backfillCategories({_testCategoryId});

        final s = state();
        expect(requestCount, 3);
        expect(s.processedCount, 1);
        expect(s.totalCount, 1);
        expect(s.embeddedCount, 0);
        expect(s.progress, 1);
        expect(s.error, isNull);
        expect(
          s.errorCode,
          EmbeddingBackfillErrorCode.ollamaUnavailable,
        );
      } finally {
        OllamaEmbeddingRepository.retryBaseDelay = const Duration(seconds: 2);
        unavailableRepository.close();
      }
    });

    test('sets error when embedding pipeline not registered', () async {
      // The controller gates on `getIt.isRegistered<EmbeddingStore>()`, so
      // unregister only that one dependency rather than nuking the whole
      // registry with `getIt.reset()` (which would contaminate the batched
      // `very_good test` run if this test failed before tearDown).
      getIt.unregister<EmbeddingStore>();
      container.dispose();
      container = ProviderContainer();

      await controller().backfillCategories({_testCategoryId});

      expect(state().error, contains('not available'));
      expect(state().isRunning, isFalse);
    });

    test('sets error when no Ollama provider configured', () async {
      when(
        () => mockAiConfigRepo.resolveOllamaBaseUrl(),
      ).thenAnswer((_) async => null);

      await controller().backfillCategories({_testCategoryId});

      expect(state().error, contains('No Ollama provider'));
      expect(state().isRunning, isFalse);
    });

    test('sets error on unexpected exception during ID fetch', () async {
      when(
        () => mockJournalDb.journalEntityIdsByCategory(_testCategoryId),
      ).thenThrow(Exception('Database connection lost'));

      await controller().backfillCategories({_testCategoryId});

      expect(state().error, contains('Database connection lost'));
      expect(state().isRunning, isFalse);
    });
  });

  group('EmbeddingBackfillController state transitions', () {
    test('clears previous error when starting new backfill', () async {
      // First: trigger error
      when(
        () => mockAiConfigRepo.resolveOllamaBaseUrl(),
      ).thenAnswer((_) async => null);

      await controller().backfillCategories({_testCategoryId});
      expect(state().error, isNotNull);

      // Second: fix provider, run empty category
      _stubOllamaProvider(mockAiConfigRepo);
      _stubEntityIds(mockJournalDb, []);

      await controller().backfillCategories({_testCategoryId});
      expect(state().error, isNull);
    });

    test('resets counters when starting new backfill', () async {
      final entry = JournalEntry(
        meta: _meta(id: 'entity-1'),
        entryText: const EntryText(plainText: _longText),
      );
      _stubEntityIds(mockJournalDb, ['entity-1']);
      _stubEntity(mockJournalDb, entry);

      await controller().backfillCategories({_testCategoryId});
      expect(state().processedCount, 1);

      // Second run — counters reset
      _stubEntityIds(mockJournalDb, []);
      await controller().backfillCategories({_testCategoryId});

      expect(state().processedCount, 0);
      expect(state().embeddedCount, 0);
      expect(state().totalCount, 0);
    });

    test('isRunning is false after completion', () async {
      _stubEntityIds(mockJournalDb, []);
      await controller().backfillCategories({_testCategoryId});
      expect(state().isRunning, isFalse);
    });

    test('isRunning is false after error', () async {
      when(
        () => mockAiConfigRepo.resolveOllamaBaseUrl(),
      ).thenAnswer((_) async => null);

      await controller().backfillCategories({_testCategoryId});
      expect(state().isRunning, isFalse);
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
      final firstRun = controller().backfillCategories({_testCategoryId});

      // Drain the event queue deterministically until isRunning is set —
      // no zero-duration Timers (fake-time policy).
      await pumpEventQueue();
      expect(state().isRunning, isTrue);

      // Second call should be ignored
      await controller().backfillCategories({_testCategoryId});

      // Complete the hanging embed
      completer.complete(_fakeEmbedding());
      await firstRun;

      expect(state().processedCount, 1);
      expect(state().isRunning, isFalse);
    });

    test('sets error when embeddings are disabled', () async {
      when(
        () => mockJournalDb.getConfigFlag(enableEmbeddingsFlag),
      ).thenAnswer((_) async => false);

      await controller().backfillCategories({_testCategoryId});

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
        errorCode: EmbeddingBackfillErrorCode.ollamaUnavailable,
      );

      final copied = original.copyWith();

      expect(copied.progress, 0.5);
      expect(copied.isRunning, isTrue);
      expect(copied.processedCount, 10);
      expect(copied.totalCount, 20);
      expect(copied.embeddedCount, 5);
      expect(copied.error, isNull);
      expect(
        copied.errorCode,
        EmbeddingBackfillErrorCode.ollamaUnavailable,
      );
    });

    test('updates specified fields', () {
      const original = EmbeddingBackfillState();

      final updated = original.copyWith(
        progress: 0.75,
        isRunning: true,
        processedCount: 15,
        totalCount: 20,
        embeddedCount: 10,
        errorCode: EmbeddingBackfillErrorCode.ollamaUnavailable,
      );

      expect(updated.progress, 0.75);
      expect(updated.isRunning, isTrue);
      expect(updated.processedCount, 15);
      expect(updated.totalCount, 20);
      expect(updated.embeddedCount, 10);
      expect(updated.error, isNull);
      expect(
        updated.errorCode,
        EmbeddingBackfillErrorCode.ollamaUnavailable,
      );
    });

    test('clearError sets error to null', () {
      const original = EmbeddingBackfillState(
        errorCode: EmbeddingBackfillErrorCode.ollamaUnavailable,
      );
      final cleared = original.copyWith(clearError: true);
      expect(cleared.error, isNull);
      expect(cleared.errorCode, isNull);
    });

    test('setting a raw error clears an existing typed error code', () {
      const original = EmbeddingBackfillState(
        errorCode: EmbeddingBackfillErrorCode.ollamaUnavailable,
      );

      final updated = original.copyWith(error: 'new error');

      expect(updated.error, 'new error');
      expect(updated.errorCode, isNull);
    });

    test('setting a typed error code clears an existing raw error', () {
      const original = EmbeddingBackfillState(error: 'old error');

      final updated = original.copyWith(
        errorCode: EmbeddingBackfillErrorCode.ollamaUnavailable,
      );

      expect(updated.error, isNull);
      expect(
        updated.errorCode,
        EmbeddingBackfillErrorCode.ollamaUnavailable,
      );
    });

    test('clearError takes precedence over error parameter', () {
      const original = EmbeddingBackfillState(error: 'old error');
      final cleared = original.copyWith(clearError: true, error: 'new error');
      expect(cleared.error, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // Label resolver in backfillCategories tests
  // -------------------------------------------------------------------------

  group('EmbeddingBackfillController label resolver', () {
    test('enriches task embeddings with resolved label names', () async {
      final task = Task(
        meta: Metadata(
          id: 'task-1',
          createdAt: _fixedDate,
          updatedAt: _fixedDate,
          dateFrom: _fixedDate,
          dateTo: _fixedDate,
          labelIds: ['label-1', 'label-2'],
        ),
        data: _taskData('Fix auth bug'),
        entryText: const EntryText(plainText: _longText),
      );

      _stubEntityIds(mockJournalDb, ['task-1']);
      _stubEntity(mockJournalDb, task);

      // Stub label definitions
      when(() => mockJournalDb.getAllLabelDefinitions()).thenAnswer(
        (_) async => [
          LabelDefinition(
            id: 'label-1',
            name: 'security',
            color: '#FF0000',
            createdAt: _fixedDate,
            updatedAt: _fixedDate,
            vectorClock: null,
          ),
          LabelDefinition(
            id: 'label-2',
            name: 'backend',
            color: '#00FF00',
            createdAt: _fixedDate,
            updatedAt: _fixedDate,
            vectorClock: null,
          ),
        ],
      );

      await controller().backfillCategories({_testCategoryId});

      const expectedText =
          'Fix auth bug\nLabels: security, backend\n$_longText';
      verify(
        () => mockEmbeddingRepo.embed(
          input: expectedText,
          baseUrl: _ollamaBaseUrl,
          model: any(named: 'model'),
        ),
      ).called(1);
    });

    test('filters out deleted labels from resolver', () async {
      final task = Task(
        meta: Metadata(
          id: 'task-1',
          createdAt: _fixedDate,
          updatedAt: _fixedDate,
          dateFrom: _fixedDate,
          dateTo: _fixedDate,
          labelIds: ['label-1', 'label-deleted'],
        ),
        data: _taskData('Some task with enough title for testing'),
      );

      _stubEntityIds(mockJournalDb, ['task-1']);
      _stubEntity(mockJournalDb, task);

      when(() => mockJournalDb.getAllLabelDefinitions()).thenAnswer(
        (_) async => [
          LabelDefinition(
            id: 'label-1',
            name: 'active',
            color: '#FF0000',
            createdAt: _fixedDate,
            updatedAt: _fixedDate,
            vectorClock: null,
          ),
          LabelDefinition(
            id: 'label-deleted',
            name: 'deleted',
            color: '#999999',
            createdAt: _fixedDate,
            updatedAt: _fixedDate,
            vectorClock: null,
            deletedAt: _fixedDate,
          ),
        ],
      );

      await controller().backfillCategories({_testCategoryId});

      // Capture the input text that was embedded.
      final captured = verify(
        () => mockEmbeddingRepo.embed(
          input: captureAny(named: 'input'),
          baseUrl: _ollamaBaseUrl,
          model: any(named: 'model'),
        ),
      ).captured;

      final embeddedText = captured.first as String;
      // Only 'active' label should appear, not 'deleted'
      expect(embeddedText, contains('Labels: active'));
      expect(embeddedText, isNot(contains('deleted')));
    });
  });

  // ---------------------------------------------------------------------------
  // Glados property for the _processEntities counter arithmetic: for any
  // generated per-entity outcome sequence (embed / skip / throw), the final
  // counters and progress must satisfy the documented invariants.
  // ---------------------------------------------------------------------------
  group('backfillCategories — counter properties', () {
    glados.Glados(
      glados.any.list(glados.IntAnys(glados.any).intInRange(0, 3)),
      glados.ExploreConfig(numRuns: 60),
    ).test('counters always reconcile for any outcome sequence', (
      outcomes,
    ) async {
      // outcome per entity: 0 = embeds, 1 = skipped (entity missing),
      // 2 = fails (lookup throws).
      final ids = [for (var i = 0; i < outcomes.length; i++) 'prop-$i'];
      _stubEntityIds(mockJournalDb, ids);
      for (final (i, outcome) in outcomes.indexed) {
        switch (outcome) {
          case 0:
            _stubEntity(
              mockJournalDb,
              Task(
                meta: _meta(id: ids[i]),
                data: _taskData('Prop task $i'),
                entryText: const EntryText(plainText: _longText),
              ),
            );
          case 1:
            when(
              () => mockJournalDb.journalEntityById(ids[i]),
            ).thenAnswer((_) async => null);
          default:
            when(
              () => mockJournalDb.journalEntityById(ids[i]),
            ).thenThrow(StateError('lookup boom $i'));
        }
      }

      await controller().backfillCategories({_testCategoryId});

      final s = state();
      final expectedEmbedded = outcomes.where((o) => o == 0).length;
      expect(s.processedCount, outcomes.length, reason: '$outcomes');
      expect(s.embeddedCount, expectedEmbedded, reason: '$outcomes');
      expect(s.embeddedCount, lessThanOrEqualTo(s.processedCount));
      expect(s.progress, 1.0, reason: 'always completes: $outcomes');
      expect(s.isRunning, isFalse);
    }, tags: 'glados');
  });
}
