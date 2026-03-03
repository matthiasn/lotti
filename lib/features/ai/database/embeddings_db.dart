import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:sqlite3/sqlite3.dart';

/// The fixed embedding dimension used by the vec0 virtual table.
///
/// This must match the `float[N]` declaration in the vec0 schema.
const kEmbeddingDimensions = 1024;

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
  EmbeddingsDb({this.path, this.inMemory = false})
      : assert(inMemory || path != null, 'path must be set when not inMemory');

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
    // Check if the vec_embeddings table already exists with wrong dimensions,
    // or if embedding_metadata is missing the category_id column. Since
    // embeddings are derived data that can be regenerated, we drop and
    // recreate both tables on schema mismatch.
    if (_hasDimensionMismatch() || _hasMissingCategoryColumn()) {
      db
        ..execute('DROP TABLE IF EXISTS vec_embeddings')
        ..execute('DROP TABLE IF EXISTS embedding_metadata');
    }

    db
      ..execute('''
        CREATE TABLE IF NOT EXISTS embedding_metadata (
          entity_id TEXT PRIMARY KEY,
          entity_type TEXT NOT NULL,
          model_id TEXT NOT NULL,
          content_hash TEXT NOT NULL,
          created_at TEXT NOT NULL,
          category_id TEXT NOT NULL DEFAULT ''
        );
      ''')
      ..execute('''
        CREATE INDEX IF NOT EXISTS idx_entity_type
          ON embedding_metadata(entity_type);
      ''')
      ..execute('''
        CREATE INDEX IF NOT EXISTS idx_category_id
          ON embedding_metadata(category_id);
      ''')
      ..execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS vec_embeddings
          USING vec0(
            entity_id TEXT PRIMARY KEY,
            embedding float[$kEmbeddingDimensions]
          );
      ''');
  }

  /// Checks whether the existing vec_embeddings table has a different
  /// dimension than [kEmbeddingDimensions].
  ///
  /// Returns `false` if the table doesn't exist yet (nothing to migrate).
  bool _hasDimensionMismatch() {
    // Virtual tables are stored with type='table' in sqlite_master.
    final schema = db.select(
      "SELECT sql FROM sqlite_master WHERE name='vec_embeddings'",
    );
    if (schema.isEmpty) return false;

    final sql = schema.first['sql'] as String? ?? '';
    // The CREATE VIRTUAL TABLE statement contains "float[N]".
    final match = RegExp(r'float\[(\d+)\]').firstMatch(sql);
    if (match == null) return false;

    final existingDims = int.tryParse(match.group(1)!);
    return existingDims != null && existingDims != kEmbeddingDimensions;
  }

  /// Checks whether the existing embedding_metadata table is missing the
  /// `category_id` column added for category-scoped vector search.
  ///
  /// Returns `false` if the table doesn't exist yet (nothing to migrate).
  bool _hasMissingCategoryColumn() {
    final info = db.select('PRAGMA table_info(embedding_metadata)');
    if (info.isEmpty) return false;
    return !info.any((row) => row['name'] == 'category_id');
  }

  /// Closes the database. Safe to call multiple times.
  void close() {
    final d = _db;
    if (d == null) return;
    _db = null;
    d.dispose();
  }

  /// Inserts or updates an embedding and its metadata.
  ///
  /// The [embedding] must have exactly [kEmbeddingDimensions] elements to
  /// match the vec0 table schema.
  void upsertEmbedding({
    required String entityId,
    required String entityType,
    required String modelId,
    required Float32List embedding,
    required String contentHash,
    String categoryId = '',
  }) {
    if (embedding.length != kEmbeddingDimensions) {
      throw ArgumentError(
        'EmbeddingsDb.upsertEmbedding(): embedding.length '
        '(${embedding.length}) does not match kEmbeddingDimensions '
        '($kEmbeddingDimensions) '
        'for entityId=$entityId, entityType=$entityType, modelId=$modelId',
      );
    }

    final now = clock.now().toUtc().toIso8601String();

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
            (entity_id, entity_type, model_id, content_hash, created_at,
             category_id)
          VALUES (?, ?, ?, ?, ?, ?)
          ''',
          [entityId, entityType, modelId, contentHash, now, categoryId],
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
  /// first). Optionally filter by [entityTypeFilter] and/or [categoryIds].
  ///
  /// Note: Filters are applied as post-KNN predicates via a JOIN on
  /// embedding_metadata. This means the result may contain fewer than [k]
  /// items when filtering is active, since vec0 selects the top-k candidates
  /// before the predicates are evaluated.
  List<EmbeddingSearchResult> search({
    required Float32List queryVector,
    int k = 10,
    String? entityTypeFilter,
    Set<String>? categoryIds,
  }) {
    if (queryVector.length != kEmbeddingDimensions) {
      throw ArgumentError(
        'EmbeddingsDb.search(): queryVector.length '
        '(${queryVector.length}) does not match kEmbeddingDimensions '
        '($kEmbeddingDimensions)',
      );
    }

    final blob = queryVector.buffer.asUint8List(
      queryVector.offsetInBytes,
      queryVector.lengthInBytes,
    );

    final typeClause = entityTypeFilter != null ? 'AND m.entity_type = ?' : '';
    final categoryClause = categoryIds != null && categoryIds.isNotEmpty
        ? 'AND m.category_id IN (${List.filled(categoryIds.length, '?').join(', ')})'
        : '';
    final params = [
      blob,
      k,
      if (entityTypeFilter != null) entityTypeFilter,
      if (categoryIds != null && categoryIds.isNotEmpty) ...categoryIds,
    ];

    final rows = db.select(
      '''
      SELECT v.entity_id, v.distance, m.entity_type
      FROM vec_embeddings v
      JOIN embedding_metadata m ON v.entity_id = m.entity_id
      WHERE v.embedding MATCH ?
        AND k = ?
        $typeClause
        $categoryClause
      ORDER BY v.distance
      ''',
      params,
    );

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
