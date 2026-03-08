import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/database/entity_metadata_row.dart';
import 'package:lotti/features/ai/database/objectbox_embedding_entity.dart';
import 'package:lotti/features/ai/database/objectbox_embedding_store.dart';
import 'package:lotti/features/ai/database/objectbox_ops.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  group('ObjectBoxEmbeddingStore (unit tests with mocked ops)', () {
    late MockObjectBoxOps mockOps;
    late ObjectBoxEmbeddingStore store;

    final testDate = DateTime.utc(2024, 3, 15);

    setUpAll(() {
      registerFallbackValue(Float32List(0));
      registerFallbackValue(<EmbeddingChunkEntity>[]);
      registerFallbackValue(<int>[]);
      registerFallbackValue(<String>[]);
    });

    setUp(() {
      mockOps = MockObjectBoxOps();
      store = ObjectBoxEmbeddingStore(mockOps);
    });

    Float32List validVector() => Float32List(kEmbeddingDimensions);

    Float32List invalidVector() => Float32List(4);

    EmbeddingChunkEntity makeEntity({
      String entityId = 'entity-1',
      int chunkIndex = 0,
      String entityType = 'journalEntry',
      String modelId = 'nomic-embed-text',
      String contentHash = 'hash-1',
      String categoryId = '',
      String taskId = '',
      String subtype = '',
    }) {
      return EmbeddingChunkEntity(
        embeddingKey: '$entityId:$chunkIndex',
        entityId: entityId,
        chunkIndex: chunkIndex,
        entityType: entityType,
        modelId: modelId,
        contentHash: contentHash,
        createdAt: testDate,
        categoryId: categoryId,
        taskId: taskId,
        subtype: subtype,
        embedding: validVector(),
      );
    }

    /// Stubs [mockOps.nearestNeighborSearch] to accept any arguments and
    /// return [result].
    void stubNearestNeighborSearch([
      List<EmbeddingSearchHit> result = const [],
    ]) {
      when(
        () => mockOps.nearestNeighborSearch(
          queryVector: any(named: 'queryVector'),
          maxResults: any(named: 'maxResults'),
          limit: any(named: 'limit'),
          entityTypeFilter: any(named: 'entityTypeFilter'),
          categoryIds: any(named: 'categoryIds'),
        ),
      ).thenReturn(result);
    }

    /// Stubs [mockOps.runInWriteTransaction] to immediately invoke the action.
    void stubWriteTransaction() {
      when(() => mockOps.runInWriteTransaction(any())).thenAnswer(
        (invocation) {
          final action = invocation.positionalArguments[0] as void Function();
          action();
        },
      );
    }

    group('count', () {
      test('delegates to ops.count()', () {
        when(mockOps.count).thenReturn(42);
        expect(store.count, 42);
        verify(mockOps.count).called(1);
      });
    });

    group('close', () {
      test('delegates to ops.close()', () {
        when(mockOps.close).thenReturn(null);
        store.close();
        verify(mockOps.close).called(1);
      });
    });

    group('deleteAll', () {
      test('runs removeAll inside a write transaction', () {
        stubWriteTransaction();
        when(mockOps.removeAll).thenReturn(null);

        store.deleteAll();

        verify(() => mockOps.runInWriteTransaction(any())).called(1);
        verify(mockOps.removeAll).called(1);
      });
    });

    group('deleteEntityEmbeddings', () {
      test('removes entity IDs inside a write transaction', () {
        stubWriteTransaction();
        when(() => mockOps.findIdsByEntityId('entity-1')).thenReturn([10, 20]);
        when(() => mockOps.removeMany(any())).thenReturn(null);

        store.deleteEntityEmbeddings('entity-1');

        verify(() => mockOps.findIdsByEntityId('entity-1')).called(1);
        verify(() => mockOps.removeMany([10, 20])).called(1);
      });

      test('does not call removeMany when no IDs found', () {
        stubWriteTransaction();
        when(() => mockOps.findIdsByEntityId('entity-1')).thenReturn([]);

        store.deleteEntityEmbeddings('entity-1');

        verify(() => mockOps.findIdsByEntityId('entity-1')).called(1);
        verifyNever(() => mockOps.removeMany(any()));
      });
    });

    group('getContentHash', () {
      test('returns content hash from first chunk entity', () {
        when(
          () => mockOps.findByEmbeddingKey('entity-1:0'),
        ).thenReturn(makeEntity(contentHash: 'abc123'));

        expect(store.getContentHash('entity-1'), 'abc123');
      });

      test('returns null when entity not found', () {
        when(() => mockOps.findByEmbeddingKey('entity-1:0')).thenReturn(null);

        expect(store.getContentHash('entity-1'), isNull);
      });
    });

    group('hasEmbedding', () {
      test('returns true when entity exists', () {
        when(
          () => mockOps.findFirstByEntityId('entity-1'),
        ).thenReturn(makeEntity());

        expect(store.hasEmbedding('entity-1'), isTrue);
      });

      test('returns false when entity does not exist', () {
        when(() => mockOps.findFirstByEntityId('entity-1')).thenReturn(null);

        expect(store.hasEmbedding('entity-1'), isFalse);
      });
    });

    group('replaceEntityEmbeddings', () {
      test('constructs entities with correct fields and stores them', () {
        final capturedEntities = <List<EmbeddingChunkEntity>>[];

        stubWriteTransaction();
        when(() => mockOps.findIdsByEntityId('entity-1')).thenReturn([]);
        when(() => mockOps.putMany(any())).thenAnswer((invocation) {
          capturedEntities.add(
            List<EmbeddingChunkEntity>.from(
              invocation.positionalArguments[0] as List<EmbeddingChunkEntity>,
            ),
          );
        });

        withClock(Clock.fixed(testDate), () {
          store.replaceEntityEmbeddings(
            entityId: 'entity-1',
            entityType: 'journalEntry',
            modelId: 'nomic-embed-text',
            contentHash: 'hash-1',
            embeddings: [validVector(), validVector()],
            categoryId: 'work',
            taskId: 'task-1',
            subtype: 'report',
          );
        });

        expect(capturedEntities, hasLength(1));
        final entities = capturedEntities.first;
        expect(entities, hasLength(2));

        expect(entities[0].embeddingKey, 'entity-1:0');
        expect(entities[0].entityId, 'entity-1');
        expect(entities[0].chunkIndex, 0);
        expect(entities[0].entityType, 'journalEntry');
        expect(entities[0].modelId, 'nomic-embed-text');
        expect(entities[0].contentHash, 'hash-1');
        expect(entities[0].createdAt, testDate);
        expect(entities[0].categoryId, 'work');
        expect(entities[0].taskId, 'task-1');
        expect(entities[0].subtype, 'report');

        expect(entities[1].embeddingKey, 'entity-1:1');
        expect(entities[1].chunkIndex, 1);
      });

      test('removes existing embeddings before inserting new ones', () {
        final callOrder = <String>[];

        stubWriteTransaction();
        when(() => mockOps.findIdsByEntityId('entity-1')).thenAnswer((_) {
          callOrder.add('findIds');
          return [10];
        });
        when(() => mockOps.removeMany(any())).thenAnswer((_) {
          callOrder.add('removeMany');
        });
        when(() => mockOps.putMany(any())).thenAnswer((_) {
          callOrder.add('putMany');
        });

        store.replaceEntityEmbeddings(
          entityId: 'entity-1',
          entityType: 'journalEntry',
          modelId: 'nomic-embed-text',
          contentHash: 'hash-1',
          embeddings: [validVector()],
        );

        expect(callOrder, ['findIds', 'removeMany', 'putMany']);
      });

      test('throws ArgumentError for invalid embedding dimensions', () {
        expect(
          () => store.replaceEntityEmbeddings(
            entityId: 'entity-1',
            entityType: 'journalEntry',
            modelId: 'nomic-embed-text',
            contentHash: 'hash-1',
            embeddings: [invalidVector()],
          ),
          throwsArgumentError,
        );
      });

      test('does not call putMany for empty embeddings list', () {
        stubWriteTransaction();
        when(() => mockOps.findIdsByEntityId('entity-1')).thenReturn([]);

        store.replaceEntityEmbeddings(
          entityId: 'entity-1',
          entityType: 'journalEntry',
          modelId: 'nomic-embed-text',
          contentHash: 'hash-1',
          embeddings: [],
        );

        verifyNever(() => mockOps.putMany(any()));
      });
    });

    group('search', () {
      test('returns mapped search results from ops', () {
        final queryVector = validVector();
        stubNearestNeighborSearch([
          EmbeddingSearchHit(
            object: makeEntity(
              entityId: 'hit-1',
              chunkIndex: 2,
              taskId: 'task-1',
              subtype: 'report',
            ),
            score: 0.95,
          ),
        ]);

        final results = store.search(queryVector: queryVector);

        expect(results, hasLength(1));
        expect(results.first.entityId, 'hit-1');
        expect(results.first.distance, 0.95);
        expect(results.first.entityType, 'journalEntry');
        expect(results.first.chunkIndex, 2);
        expect(results.first.taskId, 'task-1');
        expect(results.first.subtype, 'report');
      });

      test('returns empty list when k <= 0', () {
        final results = store.search(queryVector: validVector(), k: 0);
        expect(results, isEmpty);
        verifyNever(
          () => mockOps.nearestNeighborSearch(
            queryVector: any(named: 'queryVector'),
            maxResults: any(named: 'maxResults'),
            limit: any(named: 'limit'),
            entityTypeFilter: any(named: 'entityTypeFilter'),
            categoryIds: any(named: 'categoryIds'),
          ),
        );
      });

      test('returns empty list when k is negative', () {
        final results = store.search(queryVector: validVector(), k: -1);
        expect(results, isEmpty);
      });

      test('throws ArgumentError for invalid query vector dimensions', () {
        expect(
          () => store.search(queryVector: invalidVector()),
          throwsArgumentError,
        );
      });

      test('uses k*3 maxResults when entity type filter is applied', () {
        stubNearestNeighborSearch();

        final queryVector = validVector();
        store.search(
          queryVector: queryVector,
          k: 5,
          entityTypeFilter: 'journalEntry',
        );

        final captured = verify(
          () => mockOps.nearestNeighborSearch(
            queryVector: any(named: 'queryVector'),
            maxResults: captureAny(named: 'maxResults'),
            limit: captureAny(named: 'limit'),
            entityTypeFilter: captureAny(named: 'entityTypeFilter'),
            categoryIds: any(named: 'categoryIds'),
          ),
        ).captured;

        expect(captured[0], 15); // maxResults = k * 3
        expect(captured[1], 5); // limit = k
        expect(captured[2], 'journalEntry');
      });

      test('uses k*3 maxResults when category filter is applied', () {
        stubNearestNeighborSearch();

        final queryVector = validVector();
        store.search(
          queryVector: queryVector,
          categoryIds: {'work', 'home'},
        );

        final captured = verify(
          () => mockOps.nearestNeighborSearch(
            queryVector: any(named: 'queryVector'),
            maxResults: captureAny(named: 'maxResults'),
            limit: captureAny(named: 'limit'),
            entityTypeFilter: any(named: 'entityTypeFilter'),
            categoryIds: captureAny(named: 'categoryIds'),
          ),
        ).captured;

        expect(captured[0], 30); // maxResults = k * 3
        expect(captured[1], 10); // limit = k (default)
        expect(
          captured[2] as List<String>,
          containsAll(<String>['work', 'home']),
        );
      });

      test('treats empty categoryIds set as no filter', () {
        stubNearestNeighborSearch();

        final queryVector = validVector();
        store.search(
          queryVector: queryVector,
          categoryIds: {},
        );

        final captured = verify(
          () => mockOps.nearestNeighborSearch(
            queryVector: any(named: 'queryVector'),
            maxResults: captureAny(named: 'maxResults'),
            limit: any(named: 'limit'),
            entityTypeFilter: any(named: 'entityTypeFilter'),
            categoryIds: captureAny(named: 'categoryIds'),
          ),
        ).captured;

        expect(captured[0], 10); // no filter, so maxResults = k
        expect(captured[1], isNull); // categoryIds passed as null
      });

      test('returns empty list when ops returns no hits', () {
        stubNearestNeighborSearch();

        final results = store.search(queryVector: validVector());
        expect(results, isEmpty);
      });
    });

    group('embedding key generation', () {
      test('generates keys in entityId:chunkIndex format', () {
        final capturedEntities = <List<EmbeddingChunkEntity>>[];

        stubWriteTransaction();
        when(() => mockOps.findIdsByEntityId(any())).thenReturn([]);
        when(() => mockOps.putMany(any())).thenAnswer((invocation) {
          capturedEntities.add(
            List<EmbeddingChunkEntity>.from(
              invocation.positionalArguments[0] as List<EmbeddingChunkEntity>,
            ),
          );
        });

        store.replaceEntityEmbeddings(
          entityId: 'my-entity',
          entityType: 'journalEntry',
          modelId: 'model',
          contentHash: 'hash',
          embeddings: [validVector(), validVector(), validVector()],
        );

        final entities = capturedEntities.first;
        expect(entities[0].embeddingKey, 'my-entity:0');
        expect(entities[1].embeddingKey, 'my-entity:1');
        expect(entities[2].embeddingKey, 'my-entity:2');
      });
    });

    group('getCategoryId', () {
      test('returns categoryId from stored entity', () {
        when(
          () => mockOps.findFirstByEntityId('entity-1'),
        ).thenReturn(makeEntity(categoryId: 'cat-work'));

        expect(store.getCategoryId('entity-1'), 'cat-work');
      });

      test('returns null for missing entity', () {
        when(() => mockOps.findFirstByEntityId('missing')).thenReturn(null);

        expect(store.getCategoryId('missing'), isNull);
      });
    });

    group('moveEntityToShard', () {
      test('updates categoryId on all chunks', () {
        final chunks = [
          makeEntity(categoryId: 'old'),
          makeEntity(chunkIndex: 1, categoryId: 'old'),
        ];
        when(
          () => mockOps.findEntitiesByEntityId('entity-1'),
        ).thenReturn(chunks);
        stubWriteTransaction();
        when(() => mockOps.putMany(any())).thenReturn(null);

        store.moveEntityToShard('entity-1', 'new-cat');

        expect(chunks[0].categoryId, 'new-cat');
        expect(chunks[1].categoryId, 'new-cat');
        verify(() => mockOps.putMany(chunks)).called(1);
      });

      test('no-op when no chunks found', () {
        when(
          () => mockOps.findEntitiesByEntityId('missing'),
        ).thenReturn([]);

        store.moveEntityToShard('missing', 'cat');

        verifyNever(() => mockOps.putMany(any()));
      });
    });

    group('moveRelatedReportEmbeddings', () {
      test('updates categoryId on all report chunks for taskId', () {
        final reportChunks = [
          makeEntity(
            entityId: 'report-1',
            categoryId: 'old-cat',
            taskId: 'task-1',
          ),
        ];
        when(mockOps.queryAllEntityMetadata).thenReturn([
          const EntityMetadataRow(entityId: 'report-1', taskId: 'task-1'),
          const EntityMetadataRow(entityId: 'other-entry', taskId: ''),
        ]);
        when(
          () => mockOps.findEntitiesByEntityId('report-1'),
        ).thenReturn(reportChunks);
        stubWriteTransaction();
        when(() => mockOps.putMany(any())).thenReturn(null);

        store.moveRelatedReportEmbeddings('task-1', 'new-cat');

        expect(reportChunks[0].categoryId, 'new-cat');
        verify(() => mockOps.putMany(reportChunks)).called(1);
        // Should not touch 'other-entry' which has a different taskId.
        verifyNever(() => mockOps.findEntitiesByEntityId('other-entry'));
      });

      test('no-op when no reports match taskId', () {
        when(mockOps.queryAllEntityMetadata).thenReturn([
          const EntityMetadataRow(entityId: 'entry-1', taskId: ''),
        ]);

        store.moveRelatedReportEmbeddings('task-1', 'new-cat');

        verifyNever(() => mockOps.findEntitiesByEntityId(any()));
      });
    });

    group('getContentHash uses embedding key format', () {
      test('looks up entityId:0 for the content hash', () {
        when(
          () => mockOps.findByEmbeddingKey('special-id:0'),
        ).thenReturn(makeEntity(contentHash: 'found-hash'));

        expect(store.getContentHash('special-id'), 'found-hash');
        verify(() => mockOps.findByEmbeddingKey('special-id:0')).called(1);
      });
    });
  });
}
