import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

/// Result of a vector similarity search.
class EmbeddingSearchResult {
  const EmbeddingSearchResult({
    required this.entityId,
    required this.distance,
    required this.entityType,
  });

  final String entityId;
  final double distance;
  final String entityType;
}

/// Standalone vector-embedding database backed by sqlite-vec.
///
/// Uses raw `package:sqlite3` (not Drift) because vec0 virtual tables
/// require binary vector parameters that Drift does not support natively.
///
/// The database is *derived data* — it can be deleted and rebuilt from
/// source journal entries without data loss. It lives in a separate
/// `embeddings.sqlite` file.
class EmbeddingsDb {
  /// Creates an [EmbeddingsDb].
  ///
  /// If [inMemory] is true an in-memory database is created (useful for
  /// tests). Otherwise the database is opened at [path].
  EmbeddingsDb({this.path, this.inMemory = false});

  /// File path for the database. Ignored when [inMemory] is true.
  final String? path;

  /// Whether to use an in-memory database.
  final bool inMemory;

  Database? _db;

  /// The underlying sqlite3 [Database]. Throws if not opened yet.
  Database get db {
    final d = _db;
    if (d == null) {
      throw StateError('EmbeddingsDb has not been opened yet. Call open().');
    }
    return d;
  }

  /// Opens the database and creates the schema if needed.
  void open() {
    if (!inMemory && path == null) {
      throw ArgumentError(
          "EmbeddingsDb.open(): 'path' must be set when not inMemory");
    }
    _db = inMemory ? sqlite3.openInMemory() : sqlite3.open(path!);

    db
      ..execute('PRAGMA journal_mode = WAL;')
      ..execute('PRAGMA busy_timeout = 5000;')
      ..execute('PRAGMA synchronous = NORMAL;');

    _createSchema();
  }

  void _createSchema() {
    db
      ..execute('''
        CREATE TABLE IF NOT EXISTS embedding_metadata (
          entity_id TEXT PRIMARY KEY,
          entity_type TEXT NOT NULL,
          model_id TEXT NOT NULL,
          dimensions INTEGER NOT NULL,
          content_hash TEXT NOT NULL,
          created_at TEXT NOT NULL
        );
      ''')
      ..execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS vec_embeddings
          USING vec0(
            entity_id TEXT PRIMARY KEY,
            embedding float[2048]
          );
      ''');
  }

  /// Closes the database.
  void close() {
    _db?.dispose();
    _db = null;
  }

  /// Inserts or updates an embedding and its metadata.
  void upsertEmbedding({
    required String entityId,
    required String entityType,
    required String modelId,
    required int dimensions,
    required Float32List embedding,
    required String contentHash,
  }) {
    if (embedding.length != dimensions) {
      throw ArgumentError(
        'EmbeddingsDb.upsertEmbedding(): embedding.length '
        '(${embedding.length}) does not match dimensions ($dimensions) '
        'for entityId=$entityId, entityType=$entityType, modelId=$modelId',
      );
    }

    final now = DateTime.now().toUtc().toIso8601String();

    // sqlite-vec expects the vector as a raw blob of float32 bytes.
    final blob = embedding.buffer.asUint8List(
      embedding.offsetInBytes,
      embedding.lengthInBytes,
    );

    // All three mutations must be atomic — metadata and vector data must stay
    // consistent even if one statement fails.
    db.execute('BEGIN');
    try {
      db
        ..execute(
          '''
          INSERT OR REPLACE INTO embedding_metadata
            (entity_id, entity_type, model_id, dimensions, content_hash, created_at)
          VALUES (?, ?, ?, ?, ?, ?)
          ''',
          [entityId, entityType, modelId, dimensions, contentHash, now],
        )
        // vec0 virtual tables don't support INSERT OR REPLACE — delete first.
        ..execute(
          'DELETE FROM vec_embeddings WHERE entity_id = ?',
          [entityId],
        )
        ..execute(
          'INSERT INTO vec_embeddings (entity_id, embedding) VALUES (?, ?)',
          [entityId, blob],
        )
        ..execute('COMMIT');
    } on Object {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  /// Deletes an embedding and its metadata by entity ID.
  void deleteEmbedding(String entityId) {
    db.execute('BEGIN');
    try {
      db
        ..execute(
          'DELETE FROM vec_embeddings WHERE entity_id = ?',
          [entityId],
        )
        ..execute(
          'DELETE FROM embedding_metadata WHERE entity_id = ?',
          [entityId],
        )
        ..execute('COMMIT');
    } on Object {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  /// Performs k-nearest-neighbor search.
  ///
  /// Returns up to [k] results ordered by ascending distance (most similar
  /// first). Optionally filter by [entityTypeFilter].
  ///
  /// Note: [entityTypeFilter] is applied as a post-KNN filter via a JOIN on
  /// embedding_metadata. This means the result may contain fewer than [k]
  /// items when filtering is active, since vec0 selects the top-k candidates
  /// before the entity_type predicate is evaluated.
  List<EmbeddingSearchResult> search({
    required Float32List queryVector,
    int k = 10,
    String? entityTypeFilter,
  }) {
    final blob = queryVector.buffer.asUint8List(
      queryVector.offsetInBytes,
      queryVector.lengthInBytes,
    );

    final ResultSet rows;
    if (entityTypeFilter != null) {
      rows = db.select(
        '''
        SELECT v.entity_id, v.distance, m.entity_type
        FROM vec_embeddings v
        JOIN embedding_metadata m ON v.entity_id = m.entity_id
        WHERE v.embedding MATCH ?
          AND k = ?
          AND m.entity_type = ?
        ORDER BY v.distance
        ''',
        [blob, k, entityTypeFilter],
      );
    } else {
      rows = db.select(
        '''
        SELECT v.entity_id, v.distance, m.entity_type
        FROM vec_embeddings v
        JOIN embedding_metadata m ON v.entity_id = m.entity_id
        WHERE v.embedding MATCH ?
          AND k = ?
        ORDER BY v.distance
        ''',
        [blob, k],
      );
    }

    return rows.map((row) {
      return EmbeddingSearchResult(
        entityId: row['entity_id'] as String,
        distance: (row['distance'] as num).toDouble(),
        entityType: row['entity_type'] as String,
      );
    }).toList();
  }

  /// Whether an embedding exists for [entityId].
  bool hasEmbedding(String entityId) {
    final rows = db.select(
      'SELECT 1 FROM embedding_metadata WHERE entity_id = ? LIMIT 1',
      [entityId],
    );
    return rows.isNotEmpty;
  }

  /// Returns the stored content hash for [entityId], or null if absent.
  String? getContentHash(String entityId) {
    final rows = db.select(
      'SELECT content_hash FROM embedding_metadata WHERE entity_id = ? LIMIT 1',
      [entityId],
    );
    if (rows.isEmpty) return null;
    return rows.first['content_hash'] as String;
  }

  /// The total number of embeddings stored.
  int get count {
    final rows = db.select('SELECT COUNT(*) AS cnt FROM embedding_metadata');
    return rows.first['cnt'] as int;
  }

  /// Deletes all embeddings and metadata.
  void deleteAll() {
    db.execute('BEGIN');
    try {
      db
        ..execute('DELETE FROM vec_embeddings')
        ..execute('DELETE FROM embedding_metadata')
        ..execute('COMMIT');
    } on Object {
      db.execute('ROLLBACK');
      rethrow;
    }
  }
}
