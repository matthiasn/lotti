import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/database/embeddings_db.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

/// Returns the platform-specific filename for the test sqlite3+vec library.
///
/// Built via `make build_test_sqlite_vec` before running tests.
String get _testLibPath {
  final root = Directory.current.path;
  final String ext;
  if (Platform.isMacOS) {
    ext = 'dylib';
  } else if (Platform.isWindows) {
    ext = 'dll';
  } else {
    ext = 'so';
  }
  return '$root/packages/sqlite_vec/test_sqlite3_with_vec.$ext';
}

/// Overrides the sqlite3 library to use a custom build that includes
/// sqlite-vec statically linked. Must be called once before any sqlite3 usage.
void _loadSqliteVecForTests() {
  final path = _testLibPath;
  if (!File(path).existsSync()) {
    throw StateError(
      'Test library not found at $path.\n'
      'Run `make build_test_sqlite_vec` first.',
    );
  }

  final OperatingSystem os;
  if (Platform.isMacOS) {
    os = OperatingSystem.macOS;
  } else if (Platform.isWindows) {
    os = OperatingSystem.windows;
  } else {
    os = OperatingSystem.linux;
  }
  open.overrideFor(os, () => DynamicLibrary.open(path));

  // Use inLibrary instead of staticallyLinked so the init symbol is looked up
  // in our custom library. In CI (very_good test), all tests share one process
  // and sqlite3 may already be initialised with the system library — looking
  // up the symbol there would fail.
  final customLib = DynamicLibrary.open(path);
  sqlite3.ensureExtensionLoaded(
    SqliteExtension.inLibrary(customLib, 'sqlite3_vec_init'),
  );
}

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
  setUpAll(_loadSqliteVecForTests);

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
      final vec = _makeVector(2048, value: 1);

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
      final vec1 = _makeVector(2048, value: 1);
      final vec2 = _makeVector(2048, value: 2);

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
          embedding: _makeVector(2048, value: i.toDouble()),
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
          embedding: _makeVector(2048, value: 1),
          contentHash: 'hash-clock',
        );
      });

      final rows = db.db.select(
        'SELECT created_at FROM embedding_metadata '
        "WHERE entity_id = 'entity-clock'",
      );
      expect(rows.first['created_at'], fixedTime.toIso8601String());
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
        embedding: _makeVector(2048),
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
        embedding: _makeVector(2048),
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
        embedding: _makeVector(2048),
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
          embedding: _makeVector(2048, value: i.toDouble()),
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
          embedding: _makeVector(2048, value: 1),
          contentHash: 'hash-close',
        )
        // Vector far from query: all 100.0
        ..upsertEmbedding(
          entityId: 'far',
          entityType: 'journal_entry',
          modelId: 'test-model',
          embedding: _makeVector(2048, value: 100),
          contentHash: 'hash-far',
        );

      // Query vector: all 0.0
      final query = _makeVector(2048);

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
          embedding: _makeVector(2048, value: i.toDouble()),
          contentHash: 'hash-$i',
        );
      }

      final results = db.search(queryVector: _makeVector(2048), k: 3);
      expect(results, hasLength(3));
    });

    test('filters by entity type', () {
      db
        ..upsertEmbedding(
          entityId: 'journal-1',
          entityType: 'journal_entry',
          modelId: 'test-model',
          embedding: _makeVector(2048, value: 1),
          contentHash: 'hash-j1',
        )
        ..upsertEmbedding(
          entityId: 'task-1',
          entityType: 'task',
          modelId: 'test-model',
          embedding: _makeVector(2048, value: 1),
          contentHash: 'hash-t1',
        );

      final query = _makeVector(2048);

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
      final results = db.search(queryVector: _makeVector(2048));
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

    test('returns zero distance for identical vectors', () {
      db.upsertEmbedding(
        entityId: 'entity-1',
        entityType: 'journal_entry',
        modelId: 'test-model',
        embedding: _makeVector(2048, value: 1),
        contentHash: 'hash-1',
      );

      final results = db.search(
        queryVector: _makeVector(2048, value: 1),
        k: 1,
      );

      expect(results, hasLength(1));
      expect(results[0].distance, closeTo(0, 1e-6));
    });
  });

  group('search with sequential vectors', () {
    test('correctly ranks vectors by similarity', () {
      final baseVector = _makeSequentialVector(2048);

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
      final different = _makeVector(2048, value: 999);
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
          embedding: _makeVector(2048, value: i.toDouble()),
          contentHash: 'hash-$i',
        );
      }
    });

    test('finds nearest neighbors among 20k entries', () {
      expect(db.count, totalEntries);

      // Query with a vector of all 50.0 — entity-50 should be the
      // exact match, with entity-49 and entity-51 as nearest neighbors.
      final query = _makeVector(2048, value: 50);
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
      final query = _makeVector(2048, value: 50);

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
}
