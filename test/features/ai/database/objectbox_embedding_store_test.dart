import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:path/path.dart' as p;

import 'objectbox_test_loader.dart';

void main() {
  late Directory tempDir;
  late EmbeddingStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'objectbox_embedding_store_test',
    );
    store = await openObjectBoxEmbeddingStoreForTests(
      documentsPath: tempDir.path,
    );
  });

  tearDown(() async {
    await store.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test(
    'stores embeddings and returns filtered nearest-neighbor matches',
    () async {
      await store.replaceEntityEmbeddings(
        entityId: 'entry-1',
        entityType: 'journalEntry',
        modelId: 'nomic-embed-text',
        contentHash: 'hash-1',
        categoryId: 'work',
        taskId: 'task-1',
        subtype: 'report',
        embeddings: [
          _vector(1, 0, 0),
          _vector(0, 0.95, 0.05),
        ],
      );
      await store.replaceEntityEmbeddings(
        entityId: 'entry-2',
        entityType: 'journalEntry',
        modelId: 'nomic-embed-text',
        contentHash: 'hash-2',
        categoryId: 'home',
        embeddings: [_vector(0, 1, 0)],
      );

      expect(await store.count, 3);
      expect(await store.hasEmbedding('entry-1'), isTrue);
      expect(await store.getContentHash('entry-1'), 'hash-1');

      final results = await store.search(
        queryVector: _vector(0, 1, 0),
        k: 3,
        entityTypeFilter: 'journalEntry',
        categoryIds: {'work'},
      );

      expect(results, hasLength(2));
      expect(results.first.entityId, 'entry-1');
      expect(results.first.entityType, 'journalEntry');
      expect(results.first.chunkIndex, 1);
      expect(results.first.taskId, 'task-1');
      expect(results.first.subtype, 'report');
      expect(results.every((result) => result.entityId == 'entry-1'), isTrue);
    },
  );

  test('replaces all chunks for an entity', () async {
    await store.replaceEntityEmbeddings(
      entityId: 'entry-1',
      entityType: 'journalEntry',
      modelId: 'nomic-embed-text',
      contentHash: 'hash-1',
      embeddings: [
        _vector(1, 0, 0),
        _vector(0, 1, 0),
      ],
    );

    await store.replaceEntityEmbeddings(
      entityId: 'entry-1',
      entityType: 'journalEntry',
      modelId: 'nomic-embed-text',
      contentHash: 'hash-2',
      embeddings: [_vector(0, 0, 1)],
    );

    expect(await store.count, 1);
    expect(await store.getContentHash('entry-1'), 'hash-2');

    final results = await store.search(
      queryVector: _vector(0, 0, 1),
      k: 2,
      entityTypeFilter: 'journalEntry',
    );

    expect(results, hasLength(1));
    expect(results.single.entityId, 'entry-1');
    expect(results.single.chunkIndex, 0);
  });

  test('invalid replacement does not delete existing embeddings', () async {
    await store.replaceEntityEmbeddings(
      entityId: 'entry-1',
      entityType: 'journalEntry',
      modelId: 'nomic-embed-text',
      contentHash: 'hash-1',
      embeddings: [_vector(1, 0, 0)],
    );

    expect(
      () => store.replaceEntityEmbeddings(
        entityId: 'entry-1',
        entityType: 'journalEntry',
        modelId: 'nomic-embed-text',
        contentHash: 'hash-2',
        embeddings: [Float32List(4)],
      ),
      throwsArgumentError,
    );

    expect(await store.count, 1);
    expect(await store.hasEmbedding('entry-1'), isTrue);
    expect(await store.getContentHash('entry-1'), 'hash-1');
  });

  test('deleteEntityEmbeddings removes only the requested entity', () async {
    await store.replaceEntityEmbeddings(
      entityId: 'entry-1',
      entityType: 'journalEntry',
      modelId: 'nomic-embed-text',
      contentHash: 'hash-1',
      embeddings: [_vector(1, 0, 0)],
    );
    await store.replaceEntityEmbeddings(
      entityId: 'entry-2',
      entityType: 'journalEntry',
      modelId: 'nomic-embed-text',
      contentHash: 'hash-2',
      embeddings: [_vector(0, 1, 0)],
    );

    await store.deleteEntityEmbeddings('entry-1');

    expect(await store.hasEmbedding('entry-1'), isFalse);
    expect(await store.hasEmbedding('entry-2'), isTrue);
    expect(await store.count, 1);
  });

  test('deleteAll clears the store', () async {
    await store.replaceEntityEmbeddings(
      entityId: 'entry-1',
      entityType: 'journalEntry',
      modelId: 'nomic-embed-text',
      contentHash: 'hash-1',
      embeddings: [_vector(1, 0, 0)],
    );
    await store.replaceEntityEmbeddings(
      entityId: 'entry-2',
      entityType: 'journalEntry',
      modelId: 'nomic-embed-text',
      contentHash: 'hash-2',
      embeddings: [_vector(0, 1, 0)],
    );

    await store.deleteAll();

    expect(await store.count, 0);
    expect(await store.hasEmbedding('entry-1'), isFalse);
    expect(await store.hasEmbedding('entry-2'), isFalse);
  });

  test('creates a dedicated ObjectBox sidecar directory', () {
    final storeDirectory = Directory(
      p.join(tempDir.path, 'objectbox_embeddings'),
    );

    expect(storeDirectory.existsSync(), isTrue);
  });

  test('search rejects query vectors with the wrong dimension', () {
    expect(
      () => store.search(
        queryVector: Float32List(4),
        k: 1,
      ),
      throwsArgumentError,
    );
  });
}

Float32List _vector(double first, double second, double third) {
  final values = List<double>.filled(kEmbeddingDimensions, 0);
  values[0] = first;
  values[1] = second;
  values[2] = third;
  return Float32List.fromList(values);
}
