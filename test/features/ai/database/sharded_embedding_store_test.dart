import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/database/entity_metadata_row.dart';
import 'package:lotti/features/ai/database/objectbox_embedding_entity.dart';
import 'package:lotti/features/ai/database/objectbox_ops.dart';
import 'package:lotti/features/ai/database/sharded_embedding_store.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  group('ShardedEmbeddingStore', () {
    late Directory tempDir;
    late Map<String, MockObjectBoxOps> mockOpsMap;
    late ShardedEmbeddingStore store;

    final testDate = DateTime.utc(2024, 3, 15);

    setUpAll(registerAllFallbackValues);

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('sharded_test_');
      mockOpsMap = {};
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    Float32List validVector() => Float32List(kEmbeddingDimensions);

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

    MockObjectBoxOps createMockOps(String directory) {
      final mock = MockObjectBoxOps();

      // Default stubs for a fresh shard.
      when(mock.count).thenReturn(0);
      when(mock.close).thenReturn(null);
      when(mock.removeAll).thenReturn(null);
      when(mock.queryAllEntityMetadata).thenReturn([]);
      when(() => mock.findIdsByEntityId(any())).thenReturn([]);
      when(() => mock.findByEmbeddingKey(any())).thenReturn(null);
      when(() => mock.findFirstByEntityId(any())).thenReturn(null);
      when(() => mock.findEntitiesByEntityId(any())).thenReturn([]);
      when(() => mock.putMany(any())).thenReturn(null);
      when(() => mock.removeMany(any())).thenReturn(null);
      when(() => mock.runInWriteTransaction(any())).thenAnswer((invocation) {
        final action = invocation.positionalArguments[0] as void Function();
        action();
      });
      when(
        () => mock.nearestNeighborSearch(
          queryVector: any(named: 'queryVector'),
          maxResults: any(named: 'maxResults'),
          limit: any(named: 'limit'),
          entityTypeFilter: any(named: 'entityTypeFilter'),
          categoryIds: any(named: 'categoryIds'),
        ),
      ).thenReturn([]);

      mockOpsMap[directory] = mock;
      return mock;
    }

    Future<ShardedEmbeddingStore> openStore({
      double distanceCutoff = 0.7,
    }) async => store = await ShardedEmbeddingStore.open(
      basePath: tempDir.path,
      distanceCutoff: distanceCutoff,
      opsFactory: (directory) async => createMockOps(directory),
    );

    /// Opens a store with pre-existing shard directories so that
    /// _ensureAllShardsOpen discovers them.
    Future<ShardedEmbeddingStore> openStoreWithShards(
      List<String> shardKeys, {
      double distanceCutoff = 0.7,
      Map<String, List<EntityMetadataRow>>? metadata,
    }) async {
      // Create shard directories before opening.
      for (final key in shardKeys) {
        await Directory(p.join(tempDir.path, key)).create(recursive: true);
      }

      return store = await ShardedEmbeddingStore.open(
        basePath: tempDir.path,
        distanceCutoff: distanceCutoff,
        opsFactory: (directory) async {
          final mock = createMockOps(directory);
          final key = p.basename(directory);
          if (metadata != null && metadata.containsKey(key)) {
            when(mock.queryAllEntityMetadata).thenReturn(metadata[key]!);
          }
          return mock;
        },
      );
    }

    MockObjectBoxOps getShardOps(String shardKey) {
      final key = p.join(tempDir.path, shardKey);
      return mockOpsMap[key]!;
    }

    group('search', () {
      test(
        'fans out to multiple shards and merges results by distance',
        () async {
          await openStoreWithShards(['cat-a', 'cat-b']);

          final shardA = getShardOps('cat-a');
          final shardB = getShardOps('cat-b');

          when(
            () => shardA.nearestNeighborSearch(
              queryVector: any(named: 'queryVector'),
              maxResults: any(named: 'maxResults'),
              limit: any(named: 'limit'),
              entityTypeFilter: any(named: 'entityTypeFilter'),
              categoryIds: any(named: 'categoryIds'),
            ),
          ).thenReturn([
            EmbeddingSearchHit(
              object: makeEntity(entityId: 'a-1'),
              score: 0.3,
            ),
            EmbeddingSearchHit(
              object: makeEntity(entityId: 'a-2'),
              score: 0.5,
            ),
          ]);

          when(
            () => shardB.nearestNeighborSearch(
              queryVector: any(named: 'queryVector'),
              maxResults: any(named: 'maxResults'),
              limit: any(named: 'limit'),
              entityTypeFilter: any(named: 'entityTypeFilter'),
              categoryIds: any(named: 'categoryIds'),
            ),
          ).thenReturn([
            EmbeddingSearchHit(
              object: makeEntity(entityId: 'b-1'),
              score: 0.2,
            ),
            EmbeddingSearchHit(
              object: makeEntity(entityId: 'b-2'),
              score: 0.4,
            ),
          ]);

          final results = await store.search(
            queryVector: validVector(),
            k: 3,
          );

          expect(results, hasLength(3));
          // Sorted by distance ascending.
          expect(results[0].entityId, 'b-1');
          expect(results[0].distance, 0.2);
          expect(results[1].entityId, 'a-1');
          expect(results[1].distance, 0.3);
          expect(results[2].entityId, 'b-2');
          expect(results[2].distance, 0.4);
        },
      );

      test('applies distance cutoff', () async {
        await openStoreWithShards(['cat-a']);

        final shardA = getShardOps('cat-a');
        when(
          () => shardA.nearestNeighborSearch(
            queryVector: any(named: 'queryVector'),
            maxResults: any(named: 'maxResults'),
            limit: any(named: 'limit'),
            entityTypeFilter: any(named: 'entityTypeFilter'),
            categoryIds: any(named: 'categoryIds'),
          ),
        ).thenReturn([
          EmbeddingSearchHit(
            object: makeEntity(entityId: 'close'),
            score: 0.3,
          ),
          EmbeddingSearchHit(
            object: makeEntity(entityId: 'far'),
            score: 0.9,
          ),
        ]);

        final results = await store.search(queryVector: validVector());

        expect(results, hasLength(1));
        expect(results.first.entityId, 'close');
      });

      test('returns empty when k <= 0', () async {
        await openStore();

        final results = await store.search(
          queryVector: validVector(),
          k: 0,
        );

        expect(results, isEmpty);
      });

      test('returns empty when no shards exist', () async {
        await openStore();

        final results = await store.search(queryVector: validVector());

        expect(results, isEmpty);
      });

      test(
        'queries only specified category shards when categoryIds provided',
        () async {
          await openStoreWithShards(['cat-a', 'cat-b', 'cat-c']);

          final shardA = getShardOps('cat-a');
          final shardB = getShardOps('cat-b');
          final shardC = getShardOps('cat-c');

          when(
            () => shardA.nearestNeighborSearch(
              queryVector: any(named: 'queryVector'),
              maxResults: any(named: 'maxResults'),
              limit: any(named: 'limit'),
              entityTypeFilter: any(named: 'entityTypeFilter'),
              categoryIds: any(named: 'categoryIds'),
            ),
          ).thenReturn([
            EmbeddingSearchHit(
              object: makeEntity(entityId: 'a-1'),
              score: 0.1,
            ),
          ]);

          final results = await store.search(
            queryVector: validVector(),
            categoryIds: {'cat-a'},
          );

          expect(results, hasLength(1));
          expect(results.first.entityId, 'a-1');

          // shardB and shardC should not be queried.
          verifyNever(
            () => shardB.nearestNeighborSearch(
              queryVector: any(named: 'queryVector'),
              maxResults: any(named: 'maxResults'),
              limit: any(named: 'limit'),
              entityTypeFilter: any(named: 'entityTypeFilter'),
              categoryIds: any(named: 'categoryIds'),
            ),
          );
          verifyNever(
            () => shardC.nearestNeighborSearch(
              queryVector: any(named: 'queryVector'),
              maxResults: any(named: 'maxResults'),
              limit: any(named: 'limit'),
              entityTypeFilter: any(named: 'entityTypeFilter'),
              categoryIds: any(named: 'categoryIds'),
            ),
          );
        },
      );

      test('uses k*3 perShardLimit with entityTypeFilter', () async {
        await openStoreWithShards(['cat-a']);

        final shardA = getShardOps('cat-a');

        await store.search(
          queryVector: validVector(),
          k: 5,
          entityTypeFilter: 'journalEntry',
        );

        final captured = verify(
          () => shardA.nearestNeighborSearch(
            queryVector: any(named: 'queryVector'),
            maxResults: captureAny(named: 'maxResults'),
            limit: captureAny(named: 'limit'),
            entityTypeFilter: captureAny(named: 'entityTypeFilter'),
            categoryIds: any(named: 'categoryIds'),
          ),
        ).captured;

        // perShardLimit = k * 3 = 15 when entityTypeFilter is set.
        // ObjectBoxEmbeddingStore.search applies k*3 maxResults internally.
        expect(captured[0], 15 * 3); // maxResults = perShardLimit * 3
        expect(captured[1], 15); // limit = perShardLimit
      });

      test('uses k*2 perShardLimit without entityTypeFilter', () async {
        await openStoreWithShards(['cat-a']);

        final shardA = getShardOps('cat-a');

        await store.search(
          queryVector: validVector(),
          k: 5,
        );

        final captured = verify(
          () => shardA.nearestNeighborSearch(
            queryVector: any(named: 'queryVector'),
            maxResults: captureAny(named: 'maxResults'),
            limit: captureAny(named: 'limit'),
            entityTypeFilter: any(named: 'entityTypeFilter'),
            categoryIds: any(named: 'categoryIds'),
          ),
        ).captured;

        // perShardLimit = k * 2 = 10 without entityTypeFilter.
        expect(captured[0], 10); // maxResults = perShardLimit (no filter)
        expect(captured[1], 10); // limit = perShardLimit
      });

      test(
        'skips non-existent shard directories for category queries',
        () async {
          await openStoreWithShards(['cat-a']);

          final results = await store.search(
            queryVector: validVector(),
            categoryIds: {'cat-a', 'nonexistent'},
          );

          expect(results, isEmpty);
        },
      );

      test('custom distance cutoff filters results', () async {
        await openStoreWithShards(['cat-a'], distanceCutoff: 0.4);

        final shardA = getShardOps('cat-a');
        when(
          () => shardA.nearestNeighborSearch(
            queryVector: any(named: 'queryVector'),
            maxResults: any(named: 'maxResults'),
            limit: any(named: 'limit'),
            entityTypeFilter: any(named: 'entityTypeFilter'),
            categoryIds: any(named: 'categoryIds'),
          ),
        ).thenReturn([
          EmbeddingSearchHit(
            object: makeEntity(entityId: 'close'),
            score: 0.3,
          ),
          EmbeddingSearchHit(
            object: makeEntity(entityId: 'far'),
            score: 0.5,
          ),
        ]);

        final results = await store.search(queryVector: validVector());

        expect(results, hasLength(1));
        expect(results.first.entityId, 'close');
      });
    });

    group('replaceEntityEmbeddings', () {
      test('routes to correct shard based on categoryId', () async {
        await openStore();

        await store.replaceEntityEmbeddings(
          entityId: 'entity-1',
          entityType: 'journalEntry',
          modelId: 'nomic-embed-text',
          contentHash: 'hash-1',
          embeddings: [validVector()],
          categoryId: 'cat-a',
        );

        final shardOps = getShardOps('cat-a');
        verify(() => shardOps.putMany(any())).called(1);
      });

      test('uses default shard for empty categoryId', () async {
        await openStore();

        await store.replaceEntityEmbeddings(
          entityId: 'entity-1',
          entityType: 'journalEntry',
          modelId: 'nomic-embed-text',
          contentHash: 'hash-1',
          embeddings: [validVector()],
        );

        final shardOps = getShardOps(kDefaultShardKey);
        verify(() => shardOps.putMany(any())).called(1);
      });

      test('performs cross-shard move on re-categorization', () async {
        await openStoreWithShards(
          ['cat-a'],
          metadata: {
            'cat-a': [
              const EntityMetadataRow(entityId: 'entity-1', taskId: ''),
            ],
          },
        );

        final oldShardOps = getShardOps('cat-a');

        // Move entity to cat-b.
        await store.replaceEntityEmbeddings(
          entityId: 'entity-1',
          entityType: 'journalEntry',
          modelId: 'nomic-embed-text',
          contentHash: 'hash-2',
          embeddings: [validVector()],
          categoryId: 'cat-b',
        );

        // Old shard should have delete called (inside write transaction).
        verify(() => oldShardOps.findIdsByEntityId('entity-1')).called(1);

        // New shard should have putMany called.
        final newShardOps = getShardOps('cat-b');
        verify(() => newShardOps.putMany(any())).called(1);
      });

      test('updates primaryIndex after insert', () async {
        await openStore();

        await store.replaceEntityEmbeddings(
          entityId: 'entity-1',
          entityType: 'journalEntry',
          modelId: 'nomic-embed-text',
          contentHash: 'hash-1',
          embeddings: [validVector()],
          categoryId: 'cat-a',
        );

        expect(await store.hasEmbedding('entity-1'), isTrue);
      });

      test('empty embeddings list removes entity from index', () async {
        await openStoreWithShards(
          ['cat-a'],
          metadata: {
            'cat-a': [
              const EntityMetadataRow(entityId: 'entity-1', taskId: 'task-1'),
            ],
          },
        );

        expect(await store.hasEmbedding('entity-1'), isTrue);

        // Calling with empty embeddings means "delete only" in the wrapped
        // store. The sharded wrapper must remove the entity from its index.
        await store.replaceEntityEmbeddings(
          entityId: 'entity-1',
          entityType: 'journalEntry',
          modelId: 'nomic-embed-text',
          contentHash: 'hash-2',
          embeddings: [],
          categoryId: 'cat-a',
        );

        expect(await store.hasEmbedding('entity-1'), isFalse);
      });

      test('updates reverseTaskIndex for taskId', () async {
        await openStoreWithShards(
          ['cat-a'],
          metadata: {
            'cat-a': [
              const EntityMetadataRow(
                entityId: 'report-1',
                taskId: 'task-1',
              ),
            ],
          },
        );

        // The reverse task index should have the mapping.
        // We verify by deleting and checking the index is cleaned up.
        await store.deleteEntityEmbeddings('report-1');
        expect(await store.hasEmbedding('report-1'), isFalse);
      });
    });

    group('deleteEntityEmbeddings', () {
      test('removes from correct shard and clears index', () async {
        await openStoreWithShards(
          ['cat-a'],
          metadata: {
            'cat-a': [
              const EntityMetadataRow(entityId: 'entity-1', taskId: ''),
            ],
          },
        );

        expect(await store.hasEmbedding('entity-1'), isTrue);

        await store.deleteEntityEmbeddings('entity-1');

        expect(await store.hasEmbedding('entity-1'), isFalse);
        final shardOps = getShardOps('cat-a');
        verify(() => shardOps.findIdsByEntityId('entity-1')).called(1);
      });

      test('no-op when entity not in index', () async {
        await openStore();

        // Should not throw.
        await store.deleteEntityEmbeddings('nonexistent');
      });
    });

    group('getContentHash', () {
      test('delegates to correct shard', () async {
        await openStoreWithShards(
          ['cat-a'],
          metadata: {
            'cat-a': [
              const EntityMetadataRow(entityId: 'entity-1', taskId: ''),
            ],
          },
        );

        final shardOps = getShardOps('cat-a');
        when(
          () => shardOps.findByEmbeddingKey('entity-1:0'),
        ).thenReturn(makeEntity(contentHash: 'abc123'));

        final hash = await store.getContentHash('entity-1');
        expect(hash, 'abc123');
      });

      test('returns null when entity not in index', () async {
        await openStore();

        final hash = await store.getContentHash('nonexistent');
        expect(hash, isNull);
      });
    });

    group('hasEmbedding', () {
      test('returns true for indexed entity', () async {
        await openStoreWithShards(
          ['cat-a'],
          metadata: {
            'cat-a': [
              const EntityMetadataRow(entityId: 'entity-1', taskId: ''),
            ],
          },
        );

        expect(await store.hasEmbedding('entity-1'), isTrue);
      });

      test('returns false for unknown entity', () async {
        await openStore();

        expect(await store.hasEmbedding('unknown'), isFalse);
      });
    });

    group('count', () {
      test('sums counts across all shards', () async {
        await openStoreWithShards(['cat-a', 'cat-b']);

        when(getShardOps('cat-a').count).thenReturn(10);
        when(getShardOps('cat-b').count).thenReturn(25);

        expect(store.count, 35);
      });

      test('returns 0 with no shards', () async {
        await openStore();

        expect(store.count, 0);
      });
    });

    group('deleteAll', () {
      test('calls deleteAll on all shards and clears indexes', () async {
        await openStoreWithShards(
          ['cat-a', 'cat-b'],
          metadata: {
            'cat-a': [
              const EntityMetadataRow(entityId: 'entity-1', taskId: ''),
            ],
            'cat-b': [
              const EntityMetadataRow(entityId: 'entity-2', taskId: 'task-1'),
            ],
          },
        );

        expect(await store.hasEmbedding('entity-1'), isTrue);
        expect(await store.hasEmbedding('entity-2'), isTrue);

        await store.deleteAll();

        expect(await store.hasEmbedding('entity-1'), isFalse);
        expect(await store.hasEmbedding('entity-2'), isFalse);

        verify(getShardOps('cat-a').removeAll).called(1);
        verify(getShardOps('cat-b').removeAll).called(1);
      });
    });

    group('close', () {
      test('closes all shards and clears state', () async {
        await openStoreWithShards(['cat-a', 'cat-b']);

        await store.close();

        verify(getShardOps('cat-a').close).called(1);
        verify(getShardOps('cat-b').close).called(1);
      });
    });

    group('index rebuild', () {
      test('rebuilds primaryIndex from queryAllEntityMetadata', () async {
        await openStoreWithShards(
          ['cat-a', 'cat-b'],
          metadata: {
            'cat-a': [
              const EntityMetadataRow(entityId: 'entity-1', taskId: ''),
              const EntityMetadataRow(entityId: 'entity-2', taskId: ''),
            ],
            'cat-b': [
              const EntityMetadataRow(entityId: 'entity-3', taskId: 'task-1'),
            ],
          },
        );

        expect(await store.hasEmbedding('entity-1'), isTrue);
        expect(await store.hasEmbedding('entity-2'), isTrue);
        expect(await store.hasEmbedding('entity-3'), isTrue);
        expect(await store.hasEmbedding('entity-4'), isFalse);
      });

      test('cleans up duplicate entities across shards', () async {
        // entity-1 exists in both cat-a and cat-b (interrupted move).
        await openStoreWithShards(
          ['cat-a', 'cat-b'],
          metadata: {
            'cat-a': [
              const EntityMetadataRow(entityId: 'entity-1', taskId: ''),
            ],
            'cat-b': [
              const EntityMetadataRow(entityId: 'entity-1', taskId: ''),
            ],
          },
        );

        // entity-1 should be in cat-b (later shard alphabetically).
        // cat-a should have deleteEntityEmbeddings called for entity-1.
        final shardA = getShardOps('cat-a');
        verify(() => shardA.findIdsByEntityId('entity-1')).called(1);

        // Entity should still be accessible.
        expect(await store.hasEmbedding('entity-1'), isTrue);
      });

      test('builds reverseTaskIndex from metadata', () async {
        await openStoreWithShards(
          ['cat-a'],
          metadata: {
            'cat-a': [
              const EntityMetadataRow(
                entityId: 'report-1',
                taskId: 'task-1',
              ),
              const EntityMetadataRow(
                entityId: 'report-2',
                taskId: 'task-1',
              ),
              const EntityMetadataRow(
                entityId: 'entry-1',
                taskId: '',
              ),
            ],
          },
        );

        expect(await store.hasEmbedding('report-1'), isTrue);
        expect(await store.hasEmbedding('report-2'), isTrue);
        expect(await store.hasEmbedding('entry-1'), isTrue);
      });
    });

    group('getCategoryId', () {
      test('returns shard key mapped back from default', () async {
        await openStoreWithShards(
          [kDefaultShardKey],
          metadata: {
            kDefaultShardKey: [
              const EntityMetadataRow(entityId: 'entity-1', taskId: ''),
            ],
          },
        );

        final categoryId = await store.getCategoryId('entity-1');
        expect(categoryId, '');
      });

      test('returns category ID for non-default shard', () async {
        await openStoreWithShards(
          ['cat-a'],
          metadata: {
            'cat-a': [
              const EntityMetadataRow(entityId: 'entity-1', taskId: ''),
            ],
          },
        );

        final categoryId = await store.getCategoryId('entity-1');
        expect(categoryId, 'cat-a');
      });

      test('returns null for unknown entity', () async {
        await openStore();

        final categoryId = await store.getCategoryId('unknown');
        expect(categoryId, isNull);
      });
    });

    group('moveEntityToShard', () {
      test('moves chunks between shards', () async {
        final chunks = [
          makeEntity(
            categoryId: 'cat-a',
          ),
          makeEntity(
            chunkIndex: 1,
            categoryId: 'cat-a',
          ),
        ];

        await openStoreWithShards(
          ['cat-a'],
          metadata: {
            'cat-a': [
              const EntityMetadataRow(entityId: 'entity-1', taskId: ''),
            ],
          },
        );

        final oldOps = getShardOps('cat-a');
        when(
          () => oldOps.findEntitiesByEntityId('entity-1'),
        ).thenReturn(chunks);

        await store.moveEntityToShard('entity-1', 'cat-b');

        // Chunks should have updated categoryId and reset id.
        expect(chunks[0].categoryId, 'cat-b');
        expect(chunks[0].id, 0);
        expect(chunks[1].categoryId, 'cat-b');
        expect(chunks[1].id, 0);

        // New shard should have putMany called.
        final newOps = getShardOps('cat-b');
        verify(() => newOps.putMany(chunks)).called(1);

        // Old shard should have delete called.
        verify(() => oldOps.findIdsByEntityId('entity-1')).called(1);
      });

      test('is no-op when already in correct shard', () async {
        await openStoreWithShards(
          ['cat-a'],
          metadata: {
            'cat-a': [
              const EntityMetadataRow(entityId: 'entity-1', taskId: ''),
            ],
          },
        );

        await store.moveEntityToShard('entity-1', 'cat-a');

        // No findEntitiesByEntityId should be called.
        final ops = getShardOps('cat-a');
        verifyNever(() => ops.findEntitiesByEntityId(any()));
      });

      test('is no-op for unknown entity', () async {
        await openStore();

        // Should not throw.
        await store.moveEntityToShard('unknown', 'cat-a');
      });

      test('updates primary index after move', () async {
        await openStoreWithShards(
          ['cat-a'],
          metadata: {
            'cat-a': [
              const EntityMetadataRow(entityId: 'entity-1', taskId: ''),
            ],
          },
        );

        final oldOps = getShardOps('cat-a');
        when(
          () => oldOps.findEntitiesByEntityId('entity-1'),
        ).thenReturn([makeEntity(categoryId: 'cat-a')]);

        await store.moveEntityToShard('entity-1', 'cat-b');

        // After move, getCategoryId should return new category.
        final categoryId = await store.getCategoryId('entity-1');
        expect(categoryId, 'cat-b');
      });

      test('moves entity to default shard when categoryId is empty', () async {
        await openStoreWithShards(
          ['cat-a'],
          metadata: {
            'cat-a': [
              const EntityMetadataRow(entityId: 'entity-1', taskId: ''),
            ],
          },
        );

        final oldOps = getShardOps('cat-a');
        when(
          () => oldOps.findEntitiesByEntityId('entity-1'),
        ).thenReturn([makeEntity(categoryId: 'cat-a')]);

        await store.moveEntityToShard('entity-1', '');

        // Should be in the default shard now.
        final categoryId = await store.getCategoryId('entity-1');
        expect(categoryId, '');

        // New shard should be the default shard.
        final defaultOps = getShardOps(kDefaultShardKey);
        verify(() => defaultOps.putMany(any())).called(1);
      });

      test('moves entity from default shard to named shard', () async {
        await openStoreWithShards(
          [kDefaultShardKey],
          metadata: {
            kDefaultShardKey: [
              const EntityMetadataRow(entityId: 'entity-1', taskId: ''),
            ],
          },
        );

        final defaultOps = getShardOps(kDefaultShardKey);
        when(
          () => defaultOps.findEntitiesByEntityId('entity-1'),
        ).thenReturn([makeEntity()]);

        await store.moveEntityToShard('entity-1', 'cat-b');

        final categoryId = await store.getCategoryId('entity-1');
        expect(categoryId, 'cat-b');

        final newOps = getShardOps('cat-b');
        verify(() => newOps.putMany(any())).called(1);
      });

      test('preserves reverse task index after moving a report', () async {
        await openStoreWithShards(
          ['cat-a'],
          metadata: {
            'cat-a': [
              const EntityMetadataRow(
                entityId: 'report-1',
                taskId: 'task-1',
              ),
            ],
          },
        );

        final oldOps = getShardOps('cat-a');
        when(
          () => oldOps.findEntitiesByEntityId('report-1'),
        ).thenReturn([
          makeEntity(
            entityId: 'report-1',
            categoryId: 'cat-a',
            taskId: 'task-1',
          ),
        ]);

        // Move the report to a new shard.
        await store.moveEntityToShard('report-1', 'cat-b');

        // The reverse task index should still work: calling
        // moveRelatedReportEmbeddings for task-1 should find report-1.
        final catBOps = getShardOps('cat-b');
        when(
          () => catBOps.findEntitiesByEntityId('report-1'),
        ).thenReturn([
          makeEntity(
            entityId: 'report-1',
            categoryId: 'cat-b',
            taskId: 'task-1',
          ),
        ]);

        await store.moveRelatedReportEmbeddings('task-1', 'cat-c');

        // report-1 should now be in cat-c.
        final categoryId = await store.getCategoryId('report-1');
        expect(categoryId, 'cat-c');
      });
    });

    group('moveRelatedReportEmbeddings', () {
      test('cascades to all reports for a task', () async {
        await openStoreWithShards(
          ['cat-a'],
          metadata: {
            'cat-a': [
              const EntityMetadataRow(
                entityId: 'report-1',
                taskId: 'task-1',
              ),
              const EntityMetadataRow(
                entityId: 'report-2',
                taskId: 'task-1',
              ),
            ],
          },
        );

        final oldOps = getShardOps('cat-a');
        when(
          () => oldOps.findEntitiesByEntityId('report-1'),
        ).thenReturn([
          makeEntity(
            entityId: 'report-1',
            categoryId: 'cat-a',
            taskId: 'task-1',
          ),
        ]);
        when(
          () => oldOps.findEntitiesByEntityId('report-2'),
        ).thenReturn([
          makeEntity(
            entityId: 'report-2',
            categoryId: 'cat-a',
            taskId: 'task-1',
          ),
        ]);

        await store.moveRelatedReportEmbeddings('task-1', 'cat-b');

        // Both reports should be moved to cat-b.
        final newOps = getShardOps('cat-b');
        verify(() => newOps.putMany(any())).called(2);

        // Both should be deleted from old shard.
        verify(() => oldOps.findIdsByEntityId('report-1')).called(1);
        verify(() => oldOps.findIdsByEntityId('report-2')).called(1);
      });

      test('is no-op when no reports exist for task', () async {
        await openStore();

        // Should not throw.
        await store.moveRelatedReportEmbeddings('unknown-task', 'cat-b');
      });
    });

    group('shard resolution', () {
      test('empty categoryId maps to default shard key', () async {
        await openStore();

        await store.replaceEntityEmbeddings(
          entityId: 'entity-1',
          entityType: 'journalEntry',
          modelId: 'model',
          contentHash: 'hash',
          embeddings: [validVector()],
        );

        expect(
          mockOpsMap.keys.any((k) => k.endsWith(kDefaultShardKey)),
          isTrue,
        );
      });

      test('search with empty categoryIds set queries all shards', () async {
        await openStoreWithShards(['cat-a', 'cat-b']);

        await store.search(
          queryVector: validVector(),
          categoryIds: {},
        );

        // Both shards should be queried.
        verify(
          () => getShardOps('cat-a').nearestNeighborSearch(
            queryVector: any(named: 'queryVector'),
            maxResults: any(named: 'maxResults'),
            limit: any(named: 'limit'),
            entityTypeFilter: any(named: 'entityTypeFilter'),
            categoryIds: any(named: 'categoryIds'),
          ),
        ).called(1);
        verify(
          () => getShardOps('cat-b').nearestNeighborSearch(
            queryVector: any(named: 'queryVector'),
            maxResults: any(named: 'maxResults'),
            limit: any(named: 'limit'),
            entityTypeFilter: any(named: 'entityTypeFilter'),
            categoryIds: any(named: 'categoryIds'),
          ),
        ).called(1);
      });

      test('search with null categoryIds queries all shards', () async {
        await openStoreWithShards(['cat-a']);

        await store.search(queryVector: validVector());

        verify(
          () => getShardOps('cat-a').nearestNeighborSearch(
            queryVector: any(named: 'queryVector'),
            maxResults: any(named: 'maxResults'),
            limit: any(named: 'limit'),
            entityTypeFilter: any(named: 'entityTypeFilter'),
            categoryIds: any(named: 'categoryIds'),
          ),
        ).called(1);
      });
    });
  });
}
