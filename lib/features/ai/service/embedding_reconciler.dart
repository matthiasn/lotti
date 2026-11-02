import 'package:collection/collection.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/database/embedding_register.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/service/embedding_content_extractor.dart';
import 'package:lotti/features/ai/service/embedding_processor.dart';

/// Finds the vectors this device stores that no longer describe its own copy
/// of their entry, so that its stored vectors — and through vector sync,
/// every device's — converge on what the entries say now.
///
/// Stored vectors drift from their entry in ways no local edit announces:
///
/// - **The entry is deleted.** A deletion made where vectors were not
///   shared, or synced in (a receiver never processes a synced deletion),
///   leaves live vectors here, counted in Sync health and pushed to peers
///   by deep backfill — where they wait for an entry that never comes back.
/// - **The text moved without the entry.** A task's text names its labels;
///   a rename changes it without touching the task's clock, so the vectors
///   no longer hash as the task does, and a peer that receives them later
///   holds them for good.
/// - **A report's task is deleted.** Its report vectors outlived it until a
///   deleted task took them along.
/// - **A live version without chunks** cannot be served: a peer asking for
///   it is told it was deleted.
///
/// Only a row this device holds counts. An entry or task with no row at all
/// is left alone, never taken for deleted: a journal restored from an
/// older backup lacks rows its vector store still describes, and retiring
/// those would remove the vectors from every device.
///
/// Each read is batched; nothing is written here. The caller runs
/// [EmbeddingProcessor.processEntity] over [entriesToReprocess] — which
/// re-embeds, or removes with a tombstone, as the entry now warrants — and
/// [retireReportsOfDeletedTasks] tombstones report vectors directly.
class EmbeddingReconciler {
  EmbeddingReconciler({
    required this._store,
    required this._journalDb,
    required this._modelId,
    this._batchSize = 500,
  });

  final EmbeddingStore _store;
  final JournalDb _journalDb;
  final String _modelId;
  final int _batchSize;

  /// The journal entities whose live vectors here do not match this
  /// device's copy: the entry is deleted, its text no longer hashes as the
  /// vectors' did (labels included, whatever the privacy toggle says), or
  /// the version has no chunks.
  Future<Set<String>> entriesToReprocess() async {
    final live = [
      for (final register in await _liveRegisters())
        if (register.entityType != kEntityTypeAgentReport) register,
    ];
    if (live.isEmpty) return const {};

    final labels = await EmbeddingProcessor.buildLabelResolver(_journalDb);
    final due = <String>{};
    for (final slice in live.slices(_batchSize)) {
      final entities = await _rows({
        for (final register in slice) register.entityId,
      });
      for (final register in slice) {
        final entity = entities[register.entityId];
        if (entity == null) continue;
        if (entity.isDeleted || !await _store.hasEmbedding(register.entityId)) {
          due.add(register.entityId);
          continue;
        }
        final text = await EmbeddingProcessor.embeddingText(entity, labels);
        if (text == null ||
            EmbeddingContentExtractor.contentHash(text) !=
                register.contentHash) {
          due.add(register.entityId);
        }
      }
    }
    return due;
  }

  /// Tombstones the live vectors of every agent report whose task is
  /// deleted here, and returns how many it retired.
  Future<int> retireReportsOfDeletedTasks() async {
    final live = [
      for (final register in await _liveRegisters())
        if (register.entityType == kEntityTypeAgentReport &&
            register.taskId.isNotEmpty)
          register,
    ];

    var retired = 0;
    for (final slice in live.slices(_batchSize)) {
      final tasks = await _rows({
        for (final register in slice) register.taskId,
      });
      for (final register in slice) {
        if (!(tasks[register.taskId]?.isDeleted ?? false)) continue;
        await EmbeddingProcessor.retireAgentReport(
          reportId: register.entityId,
          taskId: register.taskId,
          modelId: _modelId,
          embeddingStore: _store,
        );
        retired++;
      }
    }
    return retired;
  }

  /// The rows of [ids] this device holds, deleted ones included, whatever
  /// the privacy toggle says.
  Future<Map<String, JournalEntity>> _rows(Set<String> ids) async => {
    for (final entity
        in await _journalDb.getJournalEntitiesForIdsIncludingDeleted(ids))
      entity.meta.id: entity,
  };

  Future<List<EmbeddingRegister>> _liveRegisters() async => [
    for (final register in await _store.allRegisters())
      if (!register.deleted && register.modelId == _modelId) register,
  ];
}
