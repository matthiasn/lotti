import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/database/sqlite_embedding_store.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

Float32List _embedding(double value) =>
    Float32List.fromList(List<double>.filled(1024, value));

void main() {
  late MockEmbeddingsDb mockEmbeddingsDb;
  late SqliteEmbeddingStore store;

  setUpAll(() {
    registerFallbackValue(Float32List(0));
  });

  setUp(() {
    mockEmbeddingsDb = MockEmbeddingsDb();
    store = SqliteEmbeddingStore(mockEmbeddingsDb);
  });

  test('count delegates to sqlite db', () {
    when(() => mockEmbeddingsDb.count).thenReturn(7);

    expect(store.count, 7);
  });

  test('close delegates to sqlite db', () {
    when(() => mockEmbeddingsDb.close()).thenReturn(null);

    store.close();

    verify(() => mockEmbeddingsDb.close()).called(1);
    verifyNoMoreInteractions(mockEmbeddingsDb);
  });

  test('deleteAll delegates to sqlite db', () {
    when(() => mockEmbeddingsDb.deleteAll()).thenReturn(null);

    store.deleteAll();

    verify(() => mockEmbeddingsDb.deleteAll()).called(1);
    verifyNoMoreInteractions(mockEmbeddingsDb);
  });

  test('deleteEntityEmbeddings delegates to sqlite db', () {
    when(() => mockEmbeddingsDb.deleteEntityEmbeddings(any())).thenReturn(null);

    store.deleteEntityEmbeddings('entity-1');

    verify(() => mockEmbeddingsDb.deleteEntityEmbeddings('entity-1')).called(1);
    verifyNoMoreInteractions(mockEmbeddingsDb);
  });

  test('getContentHash delegates to sqlite db', () {
    when(
      () => mockEmbeddingsDb.getContentHash('entity-1'),
    ).thenReturn('hash-1');

    expect(store.getContentHash('entity-1'), 'hash-1');
    verify(() => mockEmbeddingsDb.getContentHash('entity-1')).called(1);
    verifyNoMoreInteractions(mockEmbeddingsDb);
  });

  test('hasEmbedding delegates to sqlite db', () {
    when(() => mockEmbeddingsDb.hasEmbedding('entity-1')).thenReturn(true);

    expect(store.hasEmbedding('entity-1'), isTrue);
    verify(() => mockEmbeddingsDb.hasEmbedding('entity-1')).called(1);
    verifyNoMoreInteractions(mockEmbeddingsDb);
  });

  test('replaceEntityEmbeddings delegates atomic replacement to sqlite db', () {
    when(
      () => mockEmbeddingsDb.replaceEntityEmbeddings(
        entityId: any(named: 'entityId'),
        entityType: any(named: 'entityType'),
        modelId: any(named: 'modelId'),
        embeddings: any(named: 'embeddings'),
        contentHash: any(named: 'contentHash'),
        categoryId: any(named: 'categoryId'),
        taskId: any(named: 'taskId'),
        subtype: any(named: 'subtype'),
      ),
    ).thenReturn(null);

    store.replaceEntityEmbeddings(
      entityId: 'entity-1',
      entityType: 'JournalText',
      modelId: 'mxbai-embed-large',
      contentHash: 'hash-1',
      embeddings: [_embedding(1), _embedding(2)],
      categoryId: 'cat-1',
      taskId: 'task-1',
      subtype: 'report',
    );

    verify(
      () => mockEmbeddingsDb.replaceEntityEmbeddings(
        entityId: 'entity-1',
        entityType: 'JournalText',
        modelId: 'mxbai-embed-large',
        embeddings: any(
          named: 'embeddings',
          that: hasLength(2),
        ),
        contentHash: 'hash-1',
        categoryId: 'cat-1',
        taskId: 'task-1',
        subtype: 'report',
      ),
    ).called(1);
    verifyNoMoreInteractions(mockEmbeddingsDb);
  });

  test('replaceEntityEmbeddings delegates empty replacement to sqlite db', () {
    when(
      () => mockEmbeddingsDb.replaceEntityEmbeddings(
        entityId: any(named: 'entityId'),
        entityType: any(named: 'entityType'),
        modelId: any(named: 'modelId'),
        embeddings: any(named: 'embeddings'),
        contentHash: any(named: 'contentHash'),
        categoryId: any(named: 'categoryId'),
        taskId: any(named: 'taskId'),
        subtype: any(named: 'subtype'),
      ),
    ).thenReturn(null);

    store.replaceEntityEmbeddings(
      entityId: 'entity-1',
      entityType: 'JournalText',
      modelId: 'mxbai-embed-large',
      contentHash: 'hash-1',
      embeddings: const [],
    );

    verify(
      () => mockEmbeddingsDb.replaceEntityEmbeddings(
        entityId: 'entity-1',
        entityType: 'JournalText',
        modelId: 'mxbai-embed-large',
        embeddings: const [],
        contentHash: 'hash-1',
      ),
    ).called(1);
    verifyNoMoreInteractions(mockEmbeddingsDb);
  });

  test('search delegates to sqlite db with all filters', () {
    final expected = [
      const EmbeddingSearchResult(
        entityId: 'entity-1',
        distance: 0.12,
        entityType: 'JournalText',
        chunkIndex: 1,
        taskId: 'task-1',
        subtype: 'report',
      ),
    ];
    final queryVector = _embedding(3);

    when(
      () => mockEmbeddingsDb.search(
        queryVector: queryVector,
        k: 5,
        entityTypeFilter: 'JournalText',
        categoryIds: {'cat-1'},
      ),
    ).thenReturn(expected);

    final result = store.search(
      queryVector: queryVector,
      k: 5,
      entityTypeFilter: 'JournalText',
      categoryIds: {'cat-1'},
    );

    expect(result, same(expected));
    verify(
      () => mockEmbeddingsDb.search(
        queryVector: queryVector,
        k: 5,
        entityTypeFilter: 'JournalText',
        categoryIds: {'cat-1'},
      ),
    ).called(1);
    verifyNoMoreInteractions(mockEmbeddingsDb);
  });
}
