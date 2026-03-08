import 'dart:io';
import 'dart:typed_data';

import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/database/objectbox_embedding_entity.dart';
import 'package:lotti/features/ai/database/objectbox_embedding_store.dart';
import 'package:lotti/features/ai/database/objectbox_ops.dart';
import 'package:lotti/features/ai/database/real_objectbox_ops.dart'; // coverage:ignore-line
import 'package:lotti/objectbox.g.dart'; // coverage:ignore-line
import 'package:path/path.dart' as p;

/// Directory name for sharded ObjectBox embedding stores.
const kObjectBoxShardedEmbeddingsDirectoryName = 'objectbox_embeddings_sharded';

/// Marker file written after successful migration from a single store.
const _migratedMarkerFileName = '.migrated';

/// Default shard key for entities with no category.
const kDefaultShardKey = '_default';

/// Pattern matching only safe shard-key characters (alphanumeric, hyphen,
/// underscore). Everything else is replaced to prevent path traversal.
final _unsafeShardKeyChars = RegExp('[^a-zA-Z0-9_-]');

/// Sanitises a shard key so it can never escape the base path via path
/// traversal.
///
/// Replaces any character that is not alphanumeric, hyphen, or underscore with
/// an underscore. This prevents `../` and similar sequences from being used.
String sanitizeShardKey(String raw) {
  if (raw.isEmpty) return kDefaultShardKey;
  return raw.replaceAll(_unsafeShardKeyChars, '_');
}

/// Factory for creating [ObjectBoxOps] instances per shard directory.
///
/// Production code creates [RealObjectBoxOps]; tests inject mocks.
typedef ObjectBoxOpsFactory = Future<ObjectBoxOps> Function(String directory);

/// A shard: an [ObjectBoxEmbeddingStore] paired with its [ObjectBoxOps].
class _Shard {
  _Shard({required this.store, required this.ops});

  final ObjectBoxEmbeddingStore store;
  final ObjectBoxOps ops;
}

/// [EmbeddingStore] that manages per-category ObjectBox stores (shards).
///
/// Each category gets its own HNSW index, preventing large categories from
/// drowning out results from small ones. Searches fan out to the relevant
/// shards and merge results globally.
class ShardedEmbeddingStore implements EmbeddingStore {
  ShardedEmbeddingStore._({
    required String basePath,
    required ObjectBoxOpsFactory opsFactory,
    this.distanceCutoff = 0.8,
  }) : _basePath = basePath,
       _opsFactory = opsFactory;

  final String _basePath;
  final ObjectBoxOpsFactory _opsFactory;

  /// Distance above which results are discarded (simple global cutoff).
  final double distanceCutoff;

  /// Open shards keyed by shard key (typically categoryId).
  final Map<String, _Shard> _shards = {};

  /// entityId → shardKey for fast lookup.
  final Map<String, String> _primaryIndex = {};

  /// taskId → set of report entityIds for reverse lookup.
  final Map<String, Set<String>> _reverseTaskIndex = {};

  /// Opens a [ShardedEmbeddingStore] and rebuilds in-memory indexes.
  static Future<ShardedEmbeddingStore> open({
    required String basePath,
    String? macosApplicationGroup,
    double distanceCutoff = 0.8,
    ObjectBoxOpsFactory? opsFactory,
  }) async {
    final store = ShardedEmbeddingStore._(
      basePath: basePath,
      opsFactory: opsFactory ?? _defaultOpsFactory(macosApplicationGroup),
      distanceCutoff: distanceCutoff,
    );
    await store._ensureAllShardsOpen();
    store._rebuildIndexes();
    return store;
  }

  // coverage:ignore-start
  static ObjectBoxOpsFactory _defaultOpsFactory(
    String? macosApplicationGroup,
  ) {
    return (String directory) async {
      final store = await openStore(
        directory: directory,
        macosApplicationGroup: macosApplicationGroup,
      );
      return RealObjectBoxOps(store);
    };
  }
  // coverage:ignore-end

  // ---------------------------------------------------------------------------
  // EmbeddingStore interface
  // ---------------------------------------------------------------------------

  @override
  Future<List<EmbeddingSearchResult>> search({
    required Float32List queryVector,
    int k = 10,
    String? entityTypeFilter,
    Set<String>? categoryIds,
  }) async {
    if (k <= 0) return const [];

    final shardsToQuery = await _resolveShardsToQuery(categoryIds);
    if (shardsToQuery.isEmpty) return const [];

    // Over-fetch from each shard to get a good global top-K after merging.
    // With an entity-type filter, more candidates are needed because many
    // near-neighbours may be filtered out.
    const unfilteredOverfetchFactor = 2;
    const filteredOverfetchFactor = 3;
    final perShardLimit = entityTypeFilter != null
        ? k * filteredOverfetchFactor
        : k * unfilteredOverfetchFactor;

    final allResults = <EmbeddingSearchResult>[];
    for (final shard in shardsToQuery) {
      final hits = shard.store.search(
        queryVector: queryVector,
        k: perShardLimit,
        entityTypeFilter: entityTypeFilter,
      );
      allResults.addAll(hits);
    }

    // Apply distance cutoff and sort globally by distance.
    allResults
      ..removeWhere((r) => r.distance > distanceCutoff)
      ..sort((a, b) => a.distance.compareTo(b.distance));

    // Trim to requested k.
    if (allResults.length > k) {
      return allResults.sublist(0, k);
    }
    return allResults;
  }

  @override
  Future<void> replaceEntityEmbeddings({
    required String entityId,
    required String entityType,
    required String modelId,
    required String contentHash,
    required List<Float32List> embeddings,
    String categoryId = '',
    String taskId = '',
    String subtype = '',
  }) async {
    final shardKey = sanitizeShardKey(categoryId);
    final targetShard = await _getOrCreateShard(shardKey);

    // Write to the new shard first, then delete from the old one.
    // This write-then-delete order ensures that a crash between the two
    // operations leaves a duplicate (cleaned up on next startup by
    // _rebuildIndexes) rather than losing the entity's embeddings entirely.
    targetShard.store.replaceEntityEmbeddings(
      entityId: entityId,
      entityType: entityType,
      modelId: modelId,
      contentHash: contentHash,
      embeddings: embeddings,
      categoryId: categoryId,
      taskId: taskId,
      subtype: subtype,
    );

    // Now safe to delete from the old shard (data exists in the new one).
    final oldShardKey = _primaryIndex[entityId];
    if (oldShardKey != null && oldShardKey != shardKey) {
      _shards[oldShardKey]?.store.deleteEntityEmbeddings(entityId);
    }

    // Update indexes. An empty embeddings list means "delete only" — the
    // wrapped store removes existing chunks without inserting new ones.
    if (embeddings.isEmpty) {
      _primaryIndex.remove(entityId);
      _reverseTaskIndex
        ..forEach((_, entityIds) => entityIds.remove(entityId))
        ..removeWhere((_, entityIds) => entityIds.isEmpty);
    } else {
      _primaryIndex[entityId] = shardKey;
      if (taskId.isNotEmpty) {
        (_reverseTaskIndex[taskId] ??= {}).add(entityId);
      }
    }
  }

  @override
  Future<void> deleteEntityEmbeddings(String entityId) async {
    final shardKey = _primaryIndex[entityId];
    if (shardKey == null) return;

    _shards[shardKey]?.store.deleteEntityEmbeddings(entityId);
    _primaryIndex.remove(entityId);

    // Clean up reverse task index.
    _reverseTaskIndex
      ..forEach((_, entityIds) => entityIds.remove(entityId))
      ..removeWhere((_, entityIds) => entityIds.isEmpty);
  }

  @override
  Future<String?> getContentHash(String entityId) async {
    final shardKey = _primaryIndex[entityId];
    if (shardKey == null) return null;
    return _shards[shardKey]?.store.getContentHash(entityId);
  }

  @override
  Future<bool> hasEmbedding(String entityId) async {
    return _primaryIndex.containsKey(entityId);
  }

  @override
  int get count {
    var total = 0;
    for (final shard in _shards.values) {
      total += shard.store.count;
    }
    return total;
  }

  @override
  Future<void> deleteAll() async {
    for (final shard in _shards.values) {
      shard.store.deleteAll();
    }
    _primaryIndex.clear();
    _reverseTaskIndex.clear();
  }

  @override
  Future<void> close() async {
    for (final shard in _shards.values) {
      shard.store.close();
    }
    _shards.clear();
    _primaryIndex.clear();
    _reverseTaskIndex.clear();
  }

  // ---------------------------------------------------------------------------
  // Shard management
  // ---------------------------------------------------------------------------

  /// Returns or creates a shard for the given key (write path).
  Future<_Shard> _getOrCreateShard(String shardKey) async {
    final existing = _shards[shardKey];
    if (existing != null) return existing;

    final dir = p.join(_basePath, shardKey);
    await Directory(dir).create(recursive: true);
    return _openShardFromDirectory(shardKey, dir);
  }

  /// Opens an existing shard directory (read path). Returns null if the
  /// directory does not exist — never creates directories.
  Future<_Shard?> _openExistingShard(String shardKey) async {
    final existing = _shards[shardKey];
    if (existing != null) return existing;

    final dir = p.join(_basePath, shardKey);
    if (!Directory(dir).existsSync()) return null;

    return _openShardFromDirectory(shardKey, dir);
  }

  /// Opens a shard from a directory path, registers it in [_shards].
  Future<_Shard> _openShardFromDirectory(
    String shardKey,
    String directory,
  ) async {
    final ops = await _opsFactory(directory);
    final store = ObjectBoxEmbeddingStore(ops);
    final shard = _Shard(store: store, ops: ops);
    _shards[shardKey] = shard;
    return shard;
  }

  /// Resolves which shards to query for a search request.
  Future<List<_Shard>> _resolveShardsToQuery(
    Set<String>? categoryIds,
  ) async {
    if (categoryIds != null && categoryIds.isNotEmpty) {
      final shards = <_Shard>[];
      for (final catId in categoryIds) {
        final shardKey = sanitizeShardKey(catId);
        final shard = await _openExistingShard(shardKey);
        if (shard != null) shards.add(shard);
      }
      return shards;
    }

    // No category filter — query all shards.
    await _ensureAllShardsOpen();
    return _shards.values.toList();
  }

  /// Scans the base directory and opens any shard directories not yet open.
  Future<void> _ensureAllShardsOpen() async {
    final baseDir = Directory(_basePath);
    if (!baseDir.existsSync()) return;

    final entries = baseDir.listSync().whereType<Directory>().toList()
      ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));

    for (final dir in entries) {
      final shardKey = p.basename(dir.path);
      if (!_shards.containsKey(shardKey)) {
        await _openShardFromDirectory(shardKey, dir.path);
      }
    }
  }

  /// Rebuilds [_primaryIndex] and [_reverseTaskIndex] from all open shards.
  void _rebuildIndexes() {
    _primaryIndex.clear();
    _reverseTaskIndex.clear();

    for (final entry in _shards.entries) {
      final shardKey = entry.key;
      final metadata = entry.value.ops.queryAllEntityMetadata();

      for (final row in metadata) {
        final existingShardKey = _primaryIndex[row.entityId];
        if (existingShardKey != null && existingShardKey != shardKey) {
          // Duplicate entity across shards — interrupted move. Keep in the
          // later shard (alphabetically) and clean up the earlier one.
          _shards[existingShardKey]?.store.deleteEntityEmbeddings(
            row.entityId,
          );
        }
        _primaryIndex[row.entityId] = shardKey;

        if (row.taskId.isNotEmpty) {
          (_reverseTaskIndex[row.taskId] ??= {}).add(row.entityId);
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Migration
  // ---------------------------------------------------------------------------

  /// Migrates data from a single ObjectBox embedding store to sharded stores.
  ///
  /// This is a one-time migration. If the `.migrated` marker file exists in
  /// [shardedBasePath], migration is skipped.
  // coverage:ignore-start
  static Future<void> migrateFromSingleStore({
    required String documentsPath,
    required String shardedBasePath,
    required String? macosApplicationGroup,
  }) async {
    final markerFile = File(p.join(shardedBasePath, _migratedMarkerFileName));
    if (markerFile.existsSync()) return;

    // Clean up any partial state from a previously interrupted migration.
    final shardedBaseDir = Directory(shardedBasePath);
    if (shardedBaseDir.existsSync()) {
      await shardedBaseDir.delete(recursive: true);
    }

    final oldPath = p.join(documentsPath, kObjectBoxEmbeddingsDirectoryName);
    if (!Directory(oldPath).existsSync()) {
      // No old store — write marker and return.
      await shardedBaseDir.create(recursive: true);
      await markerFile.writeAsString(
        'Migrated at ${DateTime.now().toUtc().toIso8601String()}',
      );
      return;
    }

    // Open old store.
    final oldStore = await openStore(
      directory: oldPath,
      macosApplicationGroup: macosApplicationGroup,
    );
    final oldOps = RealObjectBoxOps(oldStore);

    try {
      // Load all entities in a single pass and group by categoryId.
      final allEntities = oldOps.findAllEntities();
      final groups = <String, List<EmbeddingChunkEntity>>{};
      for (final entity in allEntities) {
        final key = sanitizeShardKey(entity.categoryId);
        (groups[key] ??= []).add(entity);
      }

      // Open all shard stores first, write data, then close all in finally.
      await shardedBaseDir.create(recursive: true);
      final shardOpsMap = <String, RealObjectBoxOps>{};
      try {
        for (final shardKey in groups.keys) {
          final shardDir = p.join(shardedBasePath, shardKey);
          await Directory(shardDir).create(recursive: true);
          final shardStore = await openStore(
            directory: shardDir,
            macosApplicationGroup: macosApplicationGroup,
          );
          shardOpsMap[shardKey] = RealObjectBoxOps(shardStore);
        }

        for (final entry in groups.entries) {
          final shardOps = shardOpsMap[entry.key]!;
          // Reset IDs so ObjectBox assigns new ones in the shard store.
          for (final entity in entry.value) {
            entity.id = 0;
          }
          shardOps.putMany(entry.value);
        }
      } finally {
        for (final ops in shardOpsMap.values) {
          ops.close();
        }
      }

      // Write marker only after successful migration.
      await markerFile.writeAsString(
        'Migrated at ${DateTime.now().toUtc().toIso8601String()}',
      );
    } finally {
      oldOps.close();
    }
  }

  // coverage:ignore-end
}
