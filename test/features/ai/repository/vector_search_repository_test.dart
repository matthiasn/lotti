import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/features/ai/database/embeddings_db.dart';
import 'package:lotti/features/ai/repository/vector_search_repository.dart';
import 'package:lotti/features/ai/service/embedding_content_extractor.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';

void main() {
  late MockEmbeddingsDb mockEmbeddingsDb;
  late MockOllamaEmbeddingRepository mockEmbeddingRepo;
  late MockJournalDb mockJournalDb;
  late MockAiConfigRepository mockAiConfigRepo;
  late VectorSearchRepository sut;

  final fakeVector = Float32List(1024);

  setUpAll(() {
    registerFallbackValue(Float32List(1024));
    registerFallbackValue(<String>{});
  });

  setUp(() {
    mockEmbeddingsDb = MockEmbeddingsDb();
    mockEmbeddingRepo = MockOllamaEmbeddingRepository();
    mockJournalDb = MockJournalDb();
    mockAiConfigRepo = MockAiConfigRepository();

    sut = VectorSearchRepository(
      embeddingsDb: mockEmbeddingsDb,
      embeddingRepository: mockEmbeddingRepo,
      journalDb: mockJournalDb,
      aiConfigRepository: mockAiConfigRepo,
    );

    when(() => mockAiConfigRepo.resolveOllamaBaseUrl())
        .thenAnswer((_) async => 'http://localhost:11434');
  });

  group('VectorSearchRepository', () {
    test('returns tasks directly when search results are tasks', () async {
      when(
        () => mockEmbeddingRepo.embed(
          input: any(named: 'input'),
          baseUrl: any(named: 'baseUrl'),
        ),
      ).thenAnswer((_) async => fakeVector);

      when(
        () => mockEmbeddingsDb.search(
          queryVector: any(named: 'queryVector'),
          k: any(named: 'k'),
        ),
      ).thenReturn([
        const EmbeddingSearchResult(
          entityId: '79ef5021-12df-4651-ac6e-c9a5b58a859c',
          distance: 0.5,
          entityType: kEntityTypeTask,
        ),
      ]);

      when(() => mockJournalDb.getJournalEntitiesForIds(any()))
          .thenAnswer((_) async => [testTask]);

      final result = await sut.searchRelatedTasks(query: 'test query');

      expect(result.tasks, hasLength(1));
      expect(result.tasks.first, isA<Task>());
      expect(result.elapsed, isNotNull);
    });

    test('resolves non-task results to parent tasks via linked entries',
        () async {
      when(
        () => mockEmbeddingRepo.embed(
          input: any(named: 'input'),
          baseUrl: any(named: 'baseUrl'),
        ),
      ).thenAnswer((_) async => fakeVector);

      when(
        () => mockEmbeddingsDb.search(
          queryVector: any(named: 'queryVector'),
          k: any(named: 'k'),
        ),
      ).thenReturn([
        const EmbeddingSearchResult(
          entityId: 'text-entry-1',
          distance: 0.3,
          entityType: 'TextEntry',
        ),
      ]);

      // The text entry links to a parent task
      when(() => mockJournalDb.linkedToJournalEntities('text-entry-1'))
          .thenReturn(MockSelectable([toDbEntity(testTask)]));

      final result = await sut.searchRelatedTasks(query: 'semantic query');

      expect(result.tasks, hasLength(1));
      expect(result.tasks.first, isA<Task>());
    });

    test('deduplicates when multiple results map to the same task', () async {
      when(
        () => mockEmbeddingRepo.embed(
          input: any(named: 'input'),
          baseUrl: any(named: 'baseUrl'),
        ),
      ).thenAnswer((_) async => fakeVector);

      final taskId = testTask.meta.id;
      when(
        () => mockEmbeddingsDb.search(
          queryVector: any(named: 'queryVector'),
          k: any(named: 'k'),
        ),
      ).thenReturn([
        EmbeddingSearchResult(
          entityId: taskId,
          distance: 0.2,
          entityType: kEntityTypeTask,
        ),
        const EmbeddingSearchResult(
          entityId: 'chunk-2',
          distance: 0.4,
          entityType: 'TextEntry',
        ),
      ]);

      when(() => mockJournalDb.getJournalEntitiesForIds(any()))
          .thenAnswer((_) async => [testTask]);
      when(() => mockJournalDb.linkedToJournalEntities('chunk-2'))
          .thenReturn(MockSelectable([toDbEntity(testTask)]));

      final result = await sut.searchRelatedTasks(query: 'dup query');

      expect(result.tasks, hasLength(1));
    });

    test('returns empty results when no Ollama provider configured', () async {
      when(() => mockAiConfigRepo.resolveOllamaBaseUrl())
          .thenAnswer((_) async => null);

      final result = await sut.searchRelatedTasks(query: 'query');

      expect(result.tasks, isEmpty);
      verifyNever(
        () => mockEmbeddingRepo.embed(
          input: any(named: 'input'),
          baseUrl: any(named: 'baseUrl'),
        ),
      );
    });

    test('returns empty results when embedding fails', () async {
      when(
        () => mockEmbeddingRepo.embed(
          input: any(named: 'input'),
          baseUrl: any(named: 'baseUrl'),
        ),
      ).thenThrow(Exception('Ollama unavailable'));

      final result = await sut.searchRelatedTasks(query: 'query');

      expect(result.tasks, isEmpty);
      verifyNever(
        () => mockEmbeddingsDb.search(
          queryVector: any(named: 'queryVector'),
          k: any(named: 'k'),
        ),
      );
    });

    test('returns empty results when search returns no matches', () async {
      when(
        () => mockEmbeddingRepo.embed(
          input: any(named: 'input'),
          baseUrl: any(named: 'baseUrl'),
        ),
      ).thenAnswer((_) async => fakeVector);

      when(
        () => mockEmbeddingsDb.search(
          queryVector: any(named: 'queryVector'),
          k: any(named: 'k'),
        ),
      ).thenReturn([]);

      final result = await sut.searchRelatedTasks(query: 'no matches');

      expect(result.tasks, isEmpty);
    });

    test('skips non-task linked entries when resolving parents', () async {
      when(
        () => mockEmbeddingRepo.embed(
          input: any(named: 'input'),
          baseUrl: any(named: 'baseUrl'),
        ),
      ).thenAnswer((_) async => fakeVector);

      when(
        () => mockEmbeddingsDb.search(
          queryVector: any(named: 'queryVector'),
          k: any(named: 'k'),
        ),
      ).thenReturn([
        const EmbeddingSearchResult(
          entityId: 'text-entry-1',
          distance: 0.3,
          entityType: 'TextEntry',
        ),
      ]);

      // The text entry links to another text entry, not a task
      when(() => mockJournalDb.linkedToJournalEntities('text-entry-1'))
          .thenReturn(
        MockSelectable([toDbEntity(testTextEntry)]),
      );

      final result = await sut.searchRelatedTasks(query: 'orphan');

      expect(result.tasks, isEmpty);
    });

    test('passes custom k parameter to search', () async {
      when(
        () => mockEmbeddingRepo.embed(
          input: any(named: 'input'),
          baseUrl: any(named: 'baseUrl'),
        ),
      ).thenAnswer((_) async => fakeVector);

      when(
        () => mockEmbeddingsDb.search(
          queryVector: any(named: 'queryVector'),
          k: 5,
        ),
      ).thenReturn([]);

      await sut.searchRelatedTasks(query: 'test', k: 5);

      verify(
        () => mockEmbeddingsDb.search(
          queryVector: any(named: 'queryVector'),
          k: 5,
        ),
      ).called(1);
    });
  });
}
