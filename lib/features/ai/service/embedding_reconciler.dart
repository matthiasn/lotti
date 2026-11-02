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
/// - **Chunks without a register** — embedded before registers existed —
///   are never shared: nothing versions them, not even Add Device. They are
///   checked like any stored vectors, and [adoptUnregistered] gives the
///   ones that still match a register, which `EmbeddingShare.shareUnversioned`
///   then versions and sends.
///
/// Only a row this device holds counts. An entry or task with no row at all
/// is left alone, never taken for deleted: a journal restored from an
/// older backup lacks rows its vector store still describes, and retiring
/// those would remove the vectors from every device.
///
/// Each read is batched. The caller runs [EmbeddingProcessor.processEntity]
/// over [entriesToReprocess] — which re-embeds, or removes with a tombstone,
/// as the entry now warrants; [adoptUnregistered] and
/// [retireReportsOfDeletedTasks] write registers directly, each under its
/// entry's lock.
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

  /// The journal entities whose live vectors here — with a register or
  /// without — do not match this device's copy: the entry is deleted, its
  /// text no longer hashes as the vectors' did (labels included, whatever
  /// the privacy toggle says), or the version has no chunks.
  Future<Set<String>> entriesToReprocess() async {
    final due = <String>{};
    await _checkJournalVectors(
      [
        ...await _liveRegisters(),
        ...await _unregistered(),
      ].where((version) => version.entityType != kEntityTypeAgentReport),
      onStale: (version, _) async => due.add(version.entityId),
    );
    return due;
  }

  /// Writes a register — unshared, no clock — for every chunk set stored
  /// without one whose text still matches: a journal entry's with the
  /// entry's clock as its source, a report's as it is (a report has no
  /// source clock). Returns how many it adopted.
  ///
  /// A journal entry with no row here is left alone, and one that no longer
  /// matches is [entriesToReprocess]'s. Under each entry's lock, and only
  /// while the set is still unregistered with the same content.
  Future<int> adoptUnregistered() async {
    final unregistered = await _unregistered();
    var adopted = 0;
    for (final version in unregistered) {
      if (version.entityType == kEntityTypeAgentReport &&
          await _adopt(version)) {
        adopted++;
      }
    }
    await _checkJournalVectors(
      unregistered.where(
        (version) => version.entityType != kEntityTypeAgentReport,
      ),
      onMatch: (version, entity) async {
        if (await _adopt(
          EmbeddingRegister(
            entityId: version.entityId,
            modelId: version.modelId,
            entityType: version.entityType,
            contentHash: version.contentHash,
            sourceVectorClock: entity.meta.vectorClock,
            taskId: version.taskId,
            subtype: version.subtype,
          ),
        )) {
          adopted++;
        }
      },
    );
    return adopted;
  }

  Future<bool> _adopt(EmbeddingRegister version) =>
      EmbeddingProcessor.runExclusive(
        version.taskId.isNotEmpty ? version.taskId : version.entityId,
        () async {
          if (await _store.getRegister(version.entityId) != null ||
              await _store.getContentHash(version.entityId) !=
                  version.contentHash) {
            return false;
          }
          await _store.putRegister(version);
          return true;
        },
      );

  /// Reads [versions] of journal entries against the rows they describe, in
  /// batches, and calls [onStale] for each whose entry is deleted, whose
  /// text no longer hashes as stored, or which has no chunks, and [onMatch]
  /// for each that still matches. A version with no row here is skipped.
  Future<void> _checkJournalVectors(
    Iterable<EmbeddingRegister> versions, {
    Future<void> Function(EmbeddingRegister, JournalEntity)? onStale,
    Future<void> Function(EmbeddingRegister, JournalEntity)? onMatch,
  }) async {
    final all = versions.toList();
    if (all.isEmpty) return;

    final labels = await EmbeddingProcessor.buildLabelResolver(_journalDb);
    for (final slice in all.slices(_batchSize)) {
      final entities = await _rows({
        for (final version in slice) version.entityId,
      });
      for (final version in slice) {
        final entity = entities[version.entityId];
        if (entity == null) continue;
        final text = entity.isDeleted
            ? null
            : await EmbeddingProcessor.embeddingText(entity, labels);
        final stale =
            text == null ||
            !await _store.hasEmbedding(version.entityId) ||
            EmbeddingContentExtractor.contentHash(text) != version.contentHash;
        await (stale ? onStale : onMatch)?.call(version, entity);
      }
    }
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

  /// The chunk sets of this model stored without a register.
  Future<List<EmbeddingRegister>> _unregistered() async => [
    for (final version in await _store.unregisteredVersions())
      if (version.modelId == _modelId) version,
  ];

  Future<List<EmbeddingRegister>> _liveRegisters() async => [
    for (final register in await _store.allRegisters())
      if (!register.deleted && register.modelId == _modelId) register,
  ];
}
