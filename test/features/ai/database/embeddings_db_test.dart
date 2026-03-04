import 'dart:io';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/database/embeddings_db.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

import 'load_sqlite_vec.dart';

/// Creates a [Float32List] with [length] elements, all set to [value].
Float32List _makeVector(int length, {double value = 0}) {
  final v = Float32List(length);
  for (var i = 0; i < length; i++) {
    v[i] = value;
  }
  return v;
}

/// Creates a [Float32List] with [length] elements where each element is its
/// index as a float (0.0, 1.0, 2.0, …).
Float32List _makeSequentialVector(int length) {
  final v = Float32List(length);
  for (var i = 0; i < length; i++) {
    v[i] = i.toDouble();
  }
  return v;
}

void main() {
  if (!sqliteVecAvailable) {
    test('sqlite-vec not built — skipping', () {
      markTestSkipped(
        'Native library not found at $testSqliteVecLibPath. '
        'Run `make build_test_sqlite_vec` to enable these tests.',
      );
    });
    return;
  }

  setUpAll(loadSqliteVecForTests);

  late EmbeddingsDb db;

  setUp(() {
    db = EmbeddingsDb(inMemory: true)..open();
  });

  tearDown(() {
    db.close();
  });

  group('EmbeddingsDb lifecycle', () {
    test('open creates schema and allows operations', () {
      expect(db.count, 0);
    });

    test('close prevents further operations', () {
      db.close();
      expect(
        () => db.count,
        throwsA(isA<StateError>()),
      );
    });

    test('close is idempotent', () {
      db
        ..close()
        // Second close should not throw.
        ..close();
    });
  });

  group('upsertEmbedding', () {
    test('inserts a new embedding', () {
      final vec = _makeVector(kEmbeddingDimensions, value: 1);

      db.upsertEmbedding(
        entityId: 'entity-1',
        entityType: 'journal_entry',
        modelId: 'test-model',
        embedding: vec,
        contentHash: 'hash-1',
      );

      expect(db.count, 1);
      expect(db.hasEmbedding('entity-1'), isTrue);
      expect(db.getContentHash('entity-1'), 'hash-1');
    });

    test('updates an existing embedding', () {
      final vec1 = _makeVector(kEmbeddingDimensions, value: 1);
      final vec2 = _makeVector(kEmbeddingDimensions, value: 2);

      db
        ..upsertEmbedding(
          entityId: 'entity-1',
          entityType: 'journal_entry',
          modelId: 'test-model',
          embedding: vec1,
          contentHash: 'hash-1',
        )
        ..upsertEmbedding(
          entityId: 'entity-1',
          entityType: 'journal_entry',
          modelId: 'test-model',
          embedding: vec2,
          contentHash: 'hash-2',
        );

      expect(db.count, 1);
      expect(db.getContentHash('entity-1'), 'hash-2');
    });

    test('inserts multiple embeddings', () {
      for (var i = 0; i < 5; i++) {
        db.upsertEmbedding(
          entityId: 'entity-$i',
          entityType: 'journal_entry',
          modelId: 'test-model',
          embedding: _makeVector(kEmbeddingDimensions, value: i.toDouble()),
          contentHash: 'hash-$i',
        );
      }

      expect(db.count, 5);
    });

    test('stores created_at from clock', () {
      final fixedTime = DateTime.utc(2026, 1, 15, 10, 30);

      withClock(Clock.fixed(fixedTime), () {
        db.upsertEmbedding(
          entityId: 'entity-clock',
          entityType: 'journal_entry',
          modelId: 'test-model',
          embedding: _makeVector(kEmbeddingDimensions, value: 1),
          contentHash: 'hash-clock',
        );
      });

      final rows = db.db.select(
        'SELECT created_at FROM embedding_metadata '
        "WHERE entity_id = 'entity-clock'",
      );
      expect(rows.first['created_at'], fixedTime.toIso8601String());
    });

    test('stores task_id and subtype', () {
      final vec = _makeVector(kEmbeddingDimensions, value: 1);

      db.upsertEmbedding(
        entityId: 'report-1',
        entityType: 'agent_report',
        modelId: 'test-model',
        embedding: vec,
        contentHash: 'hash-r1',
        categoryId: 'cat-1',
        taskId: 'task-42',
        subtype: 'lotti',
      );

      expect(db.count, 1);

      // Verify via raw SQL that values are stored.
      final rows = db.db.select(
        'SELECT task_id, subtype FROM embedding_metadata '
        "WHERE entity_id = 'report-1'",
      );
      expect(rows.first['task_id'], 'task-42');
      expect(rows.first['subtype'], 'lotti');
    });

    test('defaults task_id and subtype to empty string', () {
      final vec = _makeVector(kEmbeddingDimensions, value: 1);

      db.upsertEmbedding(
        entityId: 'entity-1',
        entityType: 'task',
        modelId: 'test-model',
        embedding: vec,
        contentHash: 'hash-1',
      );

      final rows = db.db.select(
        'SELECT task_id, subtype FROM embedding_metadata '
        "WHERE entity_id = 'entity-1'",
      );
      expect(rows.first['task_id'], '');
      expect(rows.first['subtype'], '');
    });

    test('throws on dimension mismatch', () {
      expect(
        () => db.upsertEmbedding(
          entityId: 'entity-bad',
          entityType: 'journal_entry',
          modelId: 'test-model',
          embedding: _makeVector(512, value: 1),
          contentHash: 'hash-bad',
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('does not match kEmbeddingDimensions'),
          ),
        ),
      );
      expect(db.count, 0);
    });
  });

  group('deleteEmbedding', () {
    test('removes an existing embedding', () {
      db.upsertEmbedding(
        entityId: 'entity-1',
        entityType: 'journal_entry',
        modelId: 'test-model',
        embedding: _makeVector(kEmbeddingDimensions),
        contentHash: 'hash-1',
      );

      expect(db.count, 1);
      db.deleteEmbedding('entity-1');
      expect(db.count, 0);
      expect(db.hasEmbedding('entity-1'), isFalse);
    });

    test('is a no-op for non-existent entity', () {
      db.deleteEmbedding('nonexistent');
      expect(db.count, 0);
    });
  });

  group('hasEmbedding', () {
    test('returns false for non-existent entity', () {
      expect(db.hasEmbedding('nonexistent'), isFalse);
    });

    test('returns true for existing entity', () {
      db.upsertEmbedding(
        entityId: 'entity-1',
        entityType: 'task',
        modelId: 'test-model',
        embedding: _makeVector(kEmbeddingDimensions),
        contentHash: 'hash-1',
      );
      expect(db.hasEmbedding('entity-1'), isTrue);
    });
  });

  group('getContentHash', () {
    test('returns null for non-existent entity', () {
      expect(db.getContentHash('nonexistent'), isNull);
    });

    test('returns the stored content hash', () {
      db.upsertEmbedding(
        entityId: 'entity-1',
        entityType: 'task',
        modelId: 'test-model',
        embedding: _makeVector(kEmbeddingDimensions),
        contentHash: 'abc123',
      );
      expect(db.getContentHash('entity-1'), 'abc123');
    });
  });

  group('deleteAll', () {
    test('removes all embeddings', () {
      for (var i = 0; i < 3; i++) {
        db.upsertEmbedding(
          entityId: 'entity-$i',
          entityType: 'journal_entry',
          modelId: 'test-model',
          embedding: _makeVector(kEmbeddingDimensions, value: i.toDouble()),
          contentHash: 'hash-$i',
        );
      }

      expect(db.count, 3);
      db.deleteAll();
      expect(db.count, 0);
    });
  });

  group('search', () {
    test('returns nearest neighbors ordered by distance', () {
      db
        // Vector close to query: all 1.0
        ..upsertEmbedding(
          entityId: 'close',
          entityType: 'journal_entry',
          modelId: 'test-model',
          embedding: _makeVector(kEmbeddingDimensions, value: 1),
          contentHash: 'hash-close',
        )
        // Vector far from query: all 100.0
        ..upsertEmbedding(
          entityId: 'far',
          entityType: 'journal_entry',
          modelId: 'test-model',
          embedding: _makeVector(kEmbeddingDimensions, value: 100),
          contentHash: 'hash-far',
        );

      // Query vector: all 0.0
      final query = _makeVector(kEmbeddingDimensions);

      final results = db.search(queryVector: query, k: 2);

      expect(results, hasLength(2));
      expect(results[0].entityId, 'close');
      expect(results[1].entityId, 'far');
      expect(results[0].distance, lessThan(results[1].distance));
    });

    test('respects k limit', () {
      for (var i = 0; i < 5; i++) {
        db.upsertEmbedding(
          entityId: 'entity-$i',
          entityType: 'journal_entry',
          modelId: 'test-model',
          embedding: _makeVector(kEmbeddingDimensions, value: i.toDouble()),
          contentHash: 'hash-$i',
        );
      }

      final results =
          db.search(queryVector: _makeVector(kEmbeddingDimensions), k: 3);
      expect(results, hasLength(3));
    });

    test('filters by entity type', () {
      db
        ..upsertEmbedding(
          entityId: 'journal-1',
          entityType: 'journal_entry',
          modelId: 'test-model',
          embedding: _makeVector(kEmbeddingDimensions, value: 1),
          contentHash: 'hash-j1',
        )
        ..upsertEmbedding(
          entityId: 'task-1',
          entityType: 'task',
          modelId: 'test-model',
          embedding: _makeVector(kEmbeddingDimensions, value: 1),
          contentHash: 'hash-t1',
        );

      final query = _makeVector(kEmbeddingDimensions);

      final journalResults = db.search(
        queryVector: query,
        entityTypeFilter: 'journal_entry',
      );

      final taskResults = db.search(
        queryVector: query,
        entityTypeFilter: 'task',
      );

      expect(journalResults, hasLength(1));
      expect(journalResults[0].entityId, 'journal-1');
      expect(journalResults[0].entityType, 'journal_entry');

      expect(taskResults, hasLength(1));
      expect(taskResults[0].entityId, 'task-1');
      expect(taskResults[0].entityType, 'task');
    });

    test('returns empty list when no embeddings exist', () {
      final results = db.search(queryVector: _makeVector(kEmbeddingDimensions));
      expect(results, isEmpty);
    });

    test('throws on query vector dimension mismatch', () {
      expect(
        () => db.search(queryVector: _makeVector(512)),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('does not match kEmbeddingDimensions'),
          ),
        ),
      );
    });

    test('returns task_id and subtype in search results', () {
      db
        ..upsertEmbedding(
          entityId: 'report-1',
          entityType: 'agent_report',
          modelId: 'test-model',
          embedding: _makeVector(kEmbeddingDimensions, value: 1),
          contentHash: 'hash-r1',
          taskId: 'task-42',
          subtype: 'lotti',
        )
        ..upsertEmbedding(
          entityId: 'task-1',
          entityType: 'task',
          modelId: 'test-model',
          embedding: _makeVector(kEmbeddingDimensions, value: 2),
          contentHash: 'hash-t1',
        );

      final results = db.search(
        queryVector: _makeVector(kEmbeddingDimensions, value: 1),
        k: 2,
      );

      expect(results, hasLength(2));

      // First result (closest) should be the report with task_id/subtype.
      expect(results[0].entityId, 'report-1');
      expect(results[0].taskId, 'task-42');
      expect(results[0].subtype, 'lotti');

      // Second result should have empty defaults.
      expect(results[1].entityId, 'task-1');
      expect(results[1].taskId, '');
      expect(results[1].subtype, '');
    });

    test('returns zero distance for identical vectors', () {
      db.upsertEmbedding(
        entityId: 'entity-1',
        entityType: 'journal_entry',
        modelId: 'test-model',
        embedding: _makeVector(kEmbeddingDimensions, value: 1),
        contentHash: 'hash-1',
      );

      final results = db.search(
        queryVector: _makeVector(kEmbeddingDimensions, value: 1),
        k: 1,
      );

      expect(results, hasLength(1));
      expect(results[0].distance, closeTo(0, 1e-6));
    });
  });

  group('search with sequential vectors', () {
    test('correctly ranks vectors by similarity', () {
      final baseVector = _makeSequentialVector(kEmbeddingDimensions);

      // Insert a vector identical to base
      db.upsertEmbedding(
        entityId: 'identical',
        entityType: 'journal_entry',
        modelId: 'test-model',
        embedding: Float32List.fromList(baseVector),
        contentHash: 'hash-identical',
      );

      // Insert a vector with small perturbation
      final similar = Float32List.fromList(baseVector);
      for (var i = 0; i < 10; i++) {
        similar[i] += 5;
      }
      db.upsertEmbedding(
        entityId: 'similar',
        entityType: 'journal_entry',
        modelId: 'test-model',
        embedding: similar,
        contentHash: 'hash-similar',
      );

      // Insert a very different vector
      final different = _makeVector(kEmbeddingDimensions, value: 999);
      db.upsertEmbedding(
        entityId: 'different',
        entityType: 'journal_entry',
        modelId: 'test-model',
        embedding: different,
        contentHash: 'hash-different',
      );

      final results = db.search(queryVector: baseVector, k: 3);

      expect(results, hasLength(3));
      expect(results[0].entityId, 'identical');
      expect(results[0].distance, closeTo(0, 1e-6));
      expect(results[1].entityId, 'similar');
      expect(results[2].entityId, 'different');
    });
  });

  group('search with category filter', () {
    test('filters results by single category', () {
      db
        ..upsertEmbedding(
          entityId: 'cat-a-1',
          entityType: 'task',
          modelId: 'test-model',
          embedding: _makeVector(kEmbeddingDimensions, value: 1),
          contentHash: 'hash-ca1',
          categoryId: 'category-a',
        )
        ..upsertEmbedding(
          entityId: 'cat-b-1',
          entityType: 'task',
          modelId: 'test-model',
          embedding: _makeVector(kEmbeddingDimensions, value: 2),
          contentHash: 'hash-cb1',
          categoryId: 'category-b',
        )
        ..upsertEmbedding(
          entityId: 'cat-a-2',
          entityType: 'task',
          modelId: 'test-model',
          embedding: _makeVector(kEmbeddingDimensions, value: 3),
          contentHash: 'hash-ca2',
          categoryId: 'category-a',
        );

      final query = _makeVector(kEmbeddingDimensions);

      final results = db.search(
        queryVector: query,
        categoryIds: {'category-a'},
      );

      expect(results, hasLength(2));
      final ids = results.map((r) => r.entityId).toSet();
      expect(ids, containsAll(['cat-a-1', 'cat-a-2']));
    });

    test('filters results by multiple categories', () {
      db
        ..upsertEmbedding(
          entityId: 'cat-a',
          entityType: 'task',
          modelId: 'test-model',
          embedding: _makeVector(kEmbeddingDimensions, value: 1),
          contentHash: 'hash-a',
          categoryId: 'category-a',
        )
        ..upsertEmbedding(
          entityId: 'cat-b',
          entityType: 'task',
          modelId: 'test-model',
          embedding: _makeVector(kEmbeddingDimensions, value: 2),
          contentHash: 'hash-b',
          categoryId: 'category-b',
        )
        ..upsertEmbedding(
          entityId: 'cat-c',
          entityType: 'task',
          modelId: 'test-model',
          embedding: _makeVector(kEmbeddingDimensions, value: 3),
          contentHash: 'hash-c',
          categoryId: 'category-c',
        );

      final query = _makeVector(kEmbeddingDimensions);

      final results = db.search(
        queryVector: query,
        categoryIds: {'category-a', 'category-c'},
      );

      expect(results, hasLength(2));
      final ids = results.map((r) => r.entityId).toSet();
      expect(ids, containsAll(['cat-a', 'cat-c']));
    });

    test('returns all results when no category filter specified', () {
      db
        ..upsertEmbedding(
          entityId: 'cat-a',
          entityType: 'task',
          modelId: 'test-model',
          embedding: _makeVector(kEmbeddingDimensions, value: 1),
          contentHash: 'hash-a',
          categoryId: 'category-a',
        )
        ..upsertEmbedding(
          entityId: 'cat-b',
          entityType: 'task',
          modelId: 'test-model',
          embedding: _makeVector(kEmbeddingDimensions, value: 2),
          contentHash: 'hash-b',
          categoryId: 'category-b',
        )
        ..upsertEmbedding(
          entityId: 'no-cat',
          entityType: 'task',
          modelId: 'test-model',
          embedding: _makeVector(kEmbeddingDimensions, value: 3),
          contentHash: 'hash-nc',
        );

      final query = _makeVector(kEmbeddingDimensions);

      final results = db.search(queryVector: query);

      expect(results, hasLength(3));
    });
  });

  group('search at scale', () {
    // Insert 20,000 vectors where each has a unique constant value
    // equal to its index. This creates a linear spread in vector space.
    // Even indices are 'journal_entry', odd indices are 'task'.
    const totalEntries = 20000;

    setUp(() {
      for (var i = 0; i < totalEntries; i++) {
        db.upsertEmbedding(
          entityId: 'entity-$i',
          entityType: i.isEven ? 'journal_entry' : 'task',
          modelId: 'test-model',
          embedding: _makeVector(kEmbeddingDimensions, value: i.toDouble()),
          contentHash: 'hash-$i',
        );
      }
    });

    test('finds nearest neighbors among 20k entries', () {
      expect(db.count, totalEntries);

      // Query with a vector of all 50.0 — entity-50 should be the
      // exact match, with entity-49 and entity-51 as nearest neighbors.
      final query = _makeVector(kEmbeddingDimensions, value: 50);
      final results = db.search(queryVector: query, k: 5);

      expect(results, hasLength(5));
      expect(results[0].entityId, 'entity-50');
      expect(results[0].distance, closeTo(0, 1e-6));

      // The next results should be entity-49 and entity-51 (equidistant),
      // then entity-48 and entity-52 (equidistant).
      final nextIds = results.sublist(1).map((r) => r.entityId).toSet();
      expect(nextIds, containsAll(['entity-49', 'entity-51']));

      // All 5 results should be within the range [48..52]
      for (final result in results) {
        final id = int.parse(result.entityId.split('-').last);
        expect(id, inInclusiveRange(48, 52));
      }

      // Distances should be monotonically non-decreasing
      for (var i = 1; i < results.length; i++) {
        expect(
          results[i].distance,
          greaterThanOrEqualTo(results[i - 1].distance),
        );
      }
    });

    test('entity type filter works at scale', () {
      final query = _makeVector(kEmbeddingDimensions, value: 50);

      // Note: sqlite-vec applies KNN first, then the JOIN filter.
      // Requesting k=20 returns the 20 nearest vectors, then filters
      // to tasks only. With alternating types and query at 50, roughly
      // half of the 20 nearest will be tasks.
      final taskResults = db.search(
        queryVector: query,
        k: 20,
        entityTypeFilter: 'task',
      );

      expect(taskResults, isNotEmpty);
      for (final result in taskResults) {
        expect(result.entityType, 'task');
      }

      // Nearest tasks to value 50 are odd indices: 49, 51, 47, 53, ...
      expect(taskResults.first.entityId, isIn(['entity-49', 'entity-51']));

      // Distances should be monotonically non-decreasing
      for (var i = 1; i < taskResults.length; i++) {
        expect(
          taskResults[i].distance,
          greaterThanOrEqualTo(taskResults[i - 1].distance),
        );
      }
    });
  });

  group('dimension mismatch migration', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('embeddings_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('recreates tables when existing table has wrong dimensions', () {
      final dbPath = '${tempDir.path}/embeddings.sqlite';

      // Create a DB with 2048-dimension vec_embeddings table.
      final rawDb = raw.sqlite3.open(dbPath)
        ..execute('''
          CREATE TABLE IF NOT EXISTS embedding_metadata (
            entity_id TEXT PRIMARY KEY,
            entity_type TEXT NOT NULL,
            model_id TEXT NOT NULL,
            content_hash TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''')
        ..execute('''
          CREATE VIRTUAL TABLE IF NOT EXISTS vec_embeddings
            USING vec0(
              entity_id TEXT PRIMARY KEY,
              embedding float[2048]
            )
        ''')
        ..execute('''
          INSERT INTO embedding_metadata
            (entity_id, entity_type, model_id, content_hash, created_at)
          VALUES ('old-entity', 'task', 'model', 'hash', '2024-01-01')
        ''');
      // Insert a vector with 2048 dimensions.
      final oldVec = Float32List(2048);
      final oldBlob = oldVec.buffer.asUint8List();
      rawDb
        ..execute(
          'INSERT INTO vec_embeddings (entity_id, embedding) VALUES (?, ?)',
          ['old-entity', oldBlob],
        )
        ..dispose();

      // Now open via EmbeddingsDb — should detect mismatch and recreate.
      final embeddingsDb = EmbeddingsDb(path: dbPath)..open();

      // Old data should be gone.
      expect(embeddingsDb.count, 0);
      expect(embeddingsDb.hasEmbedding('old-entity'), isFalse);

      // Should be able to insert with correct dimensions now.
      embeddingsDb.upsertEmbedding(
        entityId: 'new-entity',
        entityType: 'task',
        modelId: 'test-model',
        embedding: _makeVector(kEmbeddingDimensions, value: 1),
        contentHash: 'hash-new',
      );

      expect(embeddingsDb.count, 1);

      // Search should work with correct dimensions.
      final results = embeddingsDb.search(
        queryVector: _makeVector(kEmbeddingDimensions, value: 1),
      );
      expect(results, hasLength(1));
      expect(results[0].entityId, 'new-entity');

      embeddingsDb.close();
    });

    test('does not recreate tables when dimensions match', () {
      final dbPath = '${tempDir.path}/embeddings_match.sqlite';

      // Seed a DB with correct dimensions and data.
      (EmbeddingsDb(path: dbPath)..open())
        ..upsertEmbedding(
          entityId: 'existing',
          entityType: 'task',
          modelId: 'test-model',
          embedding: _makeVector(kEmbeddingDimensions, value: 1),
          contentHash: 'hash',
        )
        ..close();

      // Open via EmbeddingsDb — should NOT recreate.
      final embeddingsDb = EmbeddingsDb(path: dbPath)..open();

      // Data should still be there.
      expect(embeddingsDb.hasEmbedding('existing'), isTrue);
      expect(embeddingsDb.getContentHash('existing'), 'hash');

      embeddingsDb.close();
    });

    test('recreates tables when category_id column is missing', () {
      final dbPath = '${tempDir.path}/embeddings_no_category.sqlite';

      // Create a DB with the old schema (no category_id column).
      final rawDb = raw.sqlite3.open(dbPath)
        ..execute('''
          CREATE TABLE IF NOT EXISTS embedding_metadata (
            entity_id TEXT PRIMARY KEY,
            entity_type TEXT NOT NULL,
            model_id TEXT NOT NULL,
            content_hash TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''')
        ..execute('''
          CREATE VIRTUAL TABLE IF NOT EXISTS vec_embeddings
            USING vec0(
              entity_id TEXT PRIMARY KEY,
              embedding float[$kEmbeddingDimensions]
            )
        ''')
        ..execute('''
          INSERT INTO embedding_metadata
            (entity_id, entity_type, model_id, content_hash, created_at)
          VALUES ('old-entity', 'task', 'model', 'hash', '2024-01-01')
        ''');
      final oldVec = Float32List(kEmbeddingDimensions);
      final oldBlob = oldVec.buffer.asUint8List();
      rawDb
        ..execute(
          'INSERT INTO vec_embeddings (entity_id, embedding) VALUES (?, ?)',
          ['old-entity', oldBlob],
        )
        ..dispose();

      // Now open via EmbeddingsDb — should detect missing column and recreate.
      final embeddingsDb = EmbeddingsDb(path: dbPath)..open();

      // Old data should be gone.
      expect(embeddingsDb.count, 0);
      expect(embeddingsDb.hasEmbedding('old-entity'), isFalse);

      // Should be able to insert with category_id now.
      embeddingsDb.upsertEmbedding(
        entityId: 'new-entity',
        entityType: 'task',
        modelId: 'test-model',
        embedding: _makeVector(kEmbeddingDimensions, value: 1),
        contentHash: 'hash-new',
        categoryId: 'my-category',
      );

      expect(embeddingsDb.count, 1);

      // Search with category filter should work.
      final results = embeddingsDb.search(
        queryVector: _makeVector(kEmbeddingDimensions, value: 1),
        categoryIds: {'my-category'},
      );
      expect(results, hasLength(1));
      expect(results[0].entityId, 'new-entity');

      embeddingsDb.close();
    });

    test('recreates tables when task_id column is missing', () {
      final dbPath = '${tempDir.path}/embeddings_no_task_id.sqlite';

      // Create a DB with the old schema (has category_id but no task_id).
      final rawDb = raw.sqlite3.open(dbPath)
        ..execute('''
          CREATE TABLE IF NOT EXISTS embedding_metadata (
            entity_id TEXT PRIMARY KEY,
            entity_type TEXT NOT NULL,
            model_id TEXT NOT NULL,
            content_hash TEXT NOT NULL,
            created_at TEXT NOT NULL,
            category_id TEXT NOT NULL DEFAULT ''
          )
        ''')
        ..execute('''
          CREATE VIRTUAL TABLE IF NOT EXISTS vec_embeddings
            USING vec0(
              entity_id TEXT PRIMARY KEY,
              embedding float[$kEmbeddingDimensions]
            )
        ''')
        ..execute('''
          INSERT INTO embedding_metadata
            (entity_id, entity_type, model_id, content_hash, created_at,
             category_id)
          VALUES ('old-entity', 'task', 'model', 'hash', '2024-01-01',
                  'cat-1')
        ''');
      final oldVec = Float32List(kEmbeddingDimensions);
      final oldBlob = oldVec.buffer.asUint8List();
      rawDb
        ..execute(
          'INSERT INTO vec_embeddings (entity_id, embedding) VALUES (?, ?)',
          ['old-entity', oldBlob],
        )
        ..dispose();

      // Now open via EmbeddingsDb — should detect missing column and recreate.
      final embeddingsDb = EmbeddingsDb(path: dbPath)..open();

      // Old data should be gone.
      expect(embeddingsDb.count, 0);

      // Should be able to insert with task_id and subtype now.
      embeddingsDb.upsertEmbedding(
        entityId: 'new-entity',
        entityType: 'agent_report',
        modelId: 'test-model',
        embedding: _makeVector(kEmbeddingDimensions, value: 1),
        contentHash: 'hash-new',
        categoryId: 'my-category',
        taskId: 'task-123',
        subtype: 'lotti',
      );

      expect(embeddingsDb.count, 1);

      // Search should return task_id and subtype.
      final results = embeddingsDb.search(
        queryVector: _makeVector(kEmbeddingDimensions, value: 1),
      );
      expect(results, hasLength(1));
      expect(results[0].entityId, 'new-entity');
      expect(results[0].taskId, 'task-123');
      expect(results[0].subtype, 'lotti');

      embeddingsDb.close();
    });

    test('handles brand new database without existing tables', () {
      final dbPath = '${tempDir.path}/fresh.sqlite';

      // Open a completely fresh DB — no tables exist yet.
      final embeddingsDb = EmbeddingsDb(path: dbPath)..open();

      expect(embeddingsDb.count, 0);

      // Should work normally.
      embeddingsDb.upsertEmbedding(
        entityId: 'entity-1',
        entityType: 'task',
        modelId: 'test-model',
        embedding: _makeVector(kEmbeddingDimensions, value: 1),
        contentHash: 'hash-1',
      );

      expect(embeddingsDb.count, 1);
      embeddingsDb.close();
    });
  });
}
