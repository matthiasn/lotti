part of 'sharded_embedding_store.dart';

/// Marker file written after successful migration from a single store.
const _migratedMarkerFileName = '.migrated';

/// Migrates data from a single ObjectBox embedding store to sharded stores.
///
/// This is a one-time migration. If the `.migrated` marker file exists in
/// [shardedBasePath], migration is skipped.
// coverage:ignore-start
Future<void> migrateFromSingleEmbeddingStore({
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
