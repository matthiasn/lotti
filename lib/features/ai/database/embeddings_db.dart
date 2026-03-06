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
    this.chunkIndex = 0,
    this.taskId = '',
    this.subtype = '',
  });

  final String entityId;
  final double distance;
  final String entityType;

  /// The zero-based chunk index within the source entity.
  ///
  /// For short content that fits in a single chunk this is 0.
  /// For chunked content this identifies which segment matched.
  final int chunkIndex;

  /// The task ID this embedding relates to, for direct lookup.
  ///
  /// Populated for agent report embeddings to link back to the parent task.
  /// Empty string when not applicable.
  final String taskId;

  /// The subtype of the embedding, e.g. agent template name.
  ///
  /// Used to distinguish between multiple agent reports for the same task.
  /// Empty string when not applicable.
  final String subtype;
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
        "EmbeddingsDb.open(): 'path' must be set when not inMemory",
      );
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
    // or if embedding_metadata is missing required columns. Since embeddings
    // are derived data that can be regenerated, we drop and recreate both
    // tables on schema mismatch.
    if (_hasDimensionMismatch() ||
        _hasMissingColumn('category_id') ||
        _hasMissingColumn('task_id') ||
        _hasMissingColumn('subtype') ||
        _hasMissingColumn('chunk_index') ||
        _hasMissingColumn('embedding_id') ||
        _hasWrongPrimaryKey()) {
      db
        ..execute('DROP TABLE IF EXISTS vec_embeddings')
        ..execute('DROP TABLE IF EXISTS embedding_metadata');
    }

    db
      ..execute('''
        CREATE TABLE IF NOT EXISTS embedding_metadata (
          entity_id TEXT NOT NULL,
          chunk_index INTEGER NOT NULL DEFAULT 0,
          embedding_id TEXT NOT NULL,
          entity_type TEXT NOT NULL,
          model_id TEXT NOT NULL,
          content_hash TEXT NOT NULL,
          created_at TEXT NOT NULL,
          category_id TEXT NOT NULL DEFAULT '',
          task_id TEXT NOT NULL DEFAULT '',
          subtype TEXT NOT NULL DEFAULT '',
          PRIMARY KEY (entity_id, chunk_index)
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
        CREATE INDEX IF NOT EXISTS idx_task_id
          ON embedding_metadata(task_id);
      ''')
      ..execute('''
        CREATE INDEX IF NOT EXISTS idx_entity_id
          ON embedding_metadata(entity_id);
      ''')
      ..execute('''
        CREATE INDEX IF NOT EXISTS idx_embedding_id
          ON embedding_metadata(embedding_id);
      ''')
      ..execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS vec_embeddings
          USING vec0(
            embedding_id TEXT PRIMARY KEY,
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

  /// Checks whether the existing embedding_metadata table is missing a
  /// [columnName].
  ///
  /// Returns `false` if the table doesn't exist yet (nothing to migrate).
  bool _hasMissingColumn(String columnName) {
    final info = db.select('PRAGMA table_info(embedding_metadata)');
    if (info.isEmpty) return false;
    return !info.any((row) => row['name'] == columnName);
  }

  /// Checks whether the existing embedding_metadata table still uses the
  /// old single-column primary key (entity_id only) instead of the new
  /// composite (entity_id, chunk_index).
  ///
  /// Returns `false` if the table doesn't exist yet.
  bool _hasWrongPrimaryKey() {
    final info = db.select('PRAGMA table_info(embedding_metadata)');
    if (info.isEmpty) return false;

    // In PRAGMA table_info, `pk` is nonzero for PK columns.
    // The new schema has pk=1 for entity_id and pk=2 for chunk_index.
    final pkColumns = info
        .where((row) => (row['pk'] as int) > 0)
        .map((row) => row['name']);
    return !pkColumns.contains('chunk_index');
  }

  /// Builds the composite embedding ID used as the vec0 primary key.
  ///
  /// Format: `{entityId}:{chunkIndex}` (e.g. `abc-123:0`, `abc-123:3`).
  static String embeddingId(String entityId, int chunkIndex) =>
      '$entityId:$chunkIndex';

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
  /// match the vec0 table schema. The [chunkIndex] identifies the chunk
  /// within the source entity (0 for single-chunk entities).
  void upsertEmbedding({
    required String entityId,
    required String entityType,
    required String modelId,
    required Float32List embedding,
    required String contentHash,
    int chunkIndex = 0,
    String categoryId = '',
    String taskId = '',
    String subtype = '',
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
    final vecId = embeddingId(entityId, chunkIndex);

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
            (entity_id, chunk_index, embedding_id, entity_type, model_id,
             content_hash, created_at, category_id, task_id, subtype)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            entityId,
            chunkIndex,
            vecId,
            entityType,
            modelId,
            contentHash,
            now,
            categoryId,
            taskId,
            subtype,
          ],
        )
        // vec0 virtual tables don't support INSERT OR REPLACE — delete first.
        ..execute(
          'DELETE FROM vec_embeddings WHERE embedding_id = ?',
          [vecId],
        )
        ..execute(
          'INSERT INTO vec_embeddings (embedding_id, embedding) VALUES (?, ?)',
          [vecId, blob],
        )
        ..execute('COMMIT');
    } on Object {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  /// Deletes a single chunk embedding by entity ID and chunk index.
  void deleteEmbedding(String entityId, {int chunkIndex = 0}) {
    final vecId = embeddingId(entityId, chunkIndex);
    db.execute('BEGIN');
    try {
      db
        ..execute(
          'DELETE FROM vec_embeddings WHERE embedding_id = ?',
          [vecId],
        )
        ..execute(
          'DELETE FROM embedding_metadata '
          'WHERE entity_id = ? AND chunk_index = ?',
          [entityId, chunkIndex],
        )
        ..execute('COMMIT');
    } on Object {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  /// Deletes all chunk embeddings for a given entity ID.
  void deleteEntityEmbeddings(String entityId) {
    // First, find all chunk indices so we can delete from vec_embeddings
    // (which uses composite embedding_id, not entity_id).
    final rows = db.select(
      'SELECT chunk_index FROM embedding_metadata WHERE entity_id = ?',
      [entityId],
    );

    if (rows.isEmpty) return;

    db.execute('BEGIN');
    try {
      for (final row in rows) {
        final idx = row['chunk_index'] as int;
        db.execute(
          'DELETE FROM vec_embeddings WHERE embedding_id = ?',
          [embeddingId(entityId, idx)],
        );
      }
      db
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
      SELECT v.embedding_id, v.distance,
             m.entity_id, m.chunk_index, m.entity_type, m.task_id, m.subtype
      FROM vec_embeddings v
      JOIN embedding_metadata m
        ON m.embedding_id = v.embedding_id
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
        chunkIndex: row['chunk_index'] as int? ?? 0,
        taskId: row['task_id'] as String? ?? '',
        subtype: row['subtype'] as String? ?? '',
      );
    }).toList();
  }

  /// Whether any embedding exists for [entityId] (any chunk).
  bool hasEmbedding(String entityId) {
    final rows = db.select(
      'SELECT 1 FROM embedding_metadata WHERE entity_id = ? LIMIT 1',
      [entityId],
    );
    return rows.isNotEmpty;
  }

  /// Returns the stored content hash for [entityId] (from chunk 0), or null.
  ///
  /// The content hash is the same across all chunks for a given entity
  /// (it hashes the full source text, not individual chunks).
  String? getContentHash(String entityId) {
    final rows = db.select(
      'SELECT content_hash FROM embedding_metadata '
      'WHERE entity_id = ? AND chunk_index = 0 LIMIT 1',
      [entityId],
    );
    if (rows.isEmpty) return null;
    return rows.first['content_hash'] as String;
  }

  /// Returns the number of chunks stored for [entityId].
  int getChunkCount(String entityId) {
    final rows = db.select(
      'SELECT COUNT(*) AS cnt FROM embedding_metadata WHERE entity_id = ?',
      [entityId],
    );
    return rows.first['cnt'] as int;
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
