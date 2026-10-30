import 'dart:convert';
import 'dart:typed_data';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/database/embedding_register.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/embedding_sync/embedding_vectors_payload.dart';
import 'package:lotti/features/ai/embedding_sync/held_embedding_versions.dart';
import 'package:lotti/features/ai/embedding_sync/synced_embedding_sink.dart';
import 'package:lotti/features/ai/service/embedding_content_extractor.dart';
import 'package:lotti/features/ai/service/embedding_processor.dart';
import 'package:lotti/utils/consts.dart';

/// Reads the text of agent report [reportId] from the agent database, or
/// `null` when this device does not hold it.
typedef ReportContentReader = Future<String?> Function(String reportId);

/// Reads a config flag.
typedef EmbeddingFlagReader = Future<bool> Function(String flag);

/// What this device's own copy of an entry says about a version.
typedef _LocalText = ({
  bool exists,
  String? contentHash,
  VectorClock? vectorClock,
  String categoryId,
  List<String> labelIds,
});

/// Stores the vector versions other devices share, when — and only when —
/// they describe the text this device holds (ADR 0150).
///
/// Per register, under the entry's lock (an agent report's: its task's,
/// as in `EmbeddingProcessor`):
///
/// 1. **Merge.** A version dominated by, or equal to, the one stored or
///    held is dropped. Of two concurrent ones the larger source clock wins
///    under [VectorClock.compareCanonically], then a tombstone over live
///    vectors of the same text, then the lower originating host — a rule
///    that reads only the two versions, so every device keeps the same one —
///    and the clocks are merged. A receiver never bumps a clock.
/// 2. **Tombstones** stop there: the entry's chunks are removed and the
///    tombstone kept, so a late copy of an older live version is dominated.
/// 3. **Validation.** The attachment must decode to finite vectors of
///    [kEmbeddingDimensions]; anything else is dropped.
/// 4. **The hash check.** The version is stored, with the sender's chunks,
///    only when this device's own text hashes to its `contentHash`.
///    Otherwise it is held ([HeldEmbeddingVersions]) until the entry, the
///    report or a task's label arrives — or discarded once the entry has
///    moved past the version's source clock.
///
/// An agent report is stored alone: the writer's tombstones remove a task's
/// older reports, and the receiver writes none of its own.
class EmbeddingSyncReceiver implements SyncedEmbeddingSink {
  EmbeddingSyncReceiver({
    required this._store,
    required this._modelId,
    required this._journalDb,
    required this._held,
    required this._reportContent,
    required this._readFlag,
  });

  final EmbeddingStore _store;
  final String _modelId;
  final JournalDb _journalDb;
  final HeldEmbeddingVersions _held;
  final ReportContentReader _reportContent;
  final EmbeddingFlagReader _readFlag;

  /// Whether arriving versions are stored now. When not, they are dropped
  /// with their receipts, and the catch-up recovers them later.
  Future<bool> get _accepting async =>
      await _readFlag(enableEmbeddingsFlag) &&
      await _readFlag(syncEmbeddingsFlag);

  @override
  Future<void> apply(IncomingEmbeddingVersion version) async {
    final register = version.register;
    if (register.modelId != _modelId || register.vectorClock == null) return;
    if (!await _accepting) return;
    await EmbeddingProcessor.runExclusive(
      _lockKey(register),
      () => _merge(register, version.payload),
    );
  }

  @override
  Future<void> onJournalEntityApplied(String entityId) =>
      _recheck((held) => held.register.entityId == entityId);

  @override
  Future<void> onAgentEntityApplied(String entityId) =>
      _recheck((held) => held.register.entityId == entityId);

  @override
  Future<void> onEntityDefinitionApplied(String definitionId) =>
      _recheck((held) => held.labelIds.contains(definitionId));

  @override
  Future<void> recheckAll() => _recheck((_) => true);

  static String _lockKey(EmbeddingRegister register) =>
      register.taskId.isNotEmpty ? register.taskId : register.entityId;

  /// Steps 1–4 for [incoming], under its lock.
  Future<void> _merge(EmbeddingRegister incoming, String? payload) async {
    var candidate = incoming;

    final stored = await _store.getRegister(incoming.entityId);
    final storedClock = stored?.vectorClock;
    if (stored != null && storedClock != null) {
      switch (VectorClock.compare(candidate.vectorClock!, storedClock)) {
        case VclockStatus.equal:
        case VclockStatus.b_gt_a:
          return;
        case VclockStatus.a_gt_b:
          break;
        case VclockStatus.concurrent:
          final merged = VectorClock.merge(candidate.vectorClock, storedClock);
          if (_wins(stored, over: candidate)) {
            await _store.putRegister(stored.copyWith(vectorClock: merged));
            await _dropHeldDominatedBy(merged, incoming.id);
            return;
          }
          candidate = candidate.copyWith(vectorClock: merged);
      }
    }

    final held = _held[incoming.id];
    if (held != null) {
      final heldClock = held.register.vectorClock!;
      switch (VectorClock.compare(candidate.vectorClock!, heldClock)) {
        case VclockStatus.equal:
        case VclockStatus.b_gt_a:
          return;
        case VclockStatus.a_gt_b:
          break;
        case VclockStatus.concurrent:
          final merged = VectorClock.merge(candidate.vectorClock, heldClock);
          if (_wins(held.register, over: candidate)) {
            await _held.put(
              HeldEmbeddingVersion(
                register: held.register.copyWith(vectorClock: merged),
                payload: held.payload,
                labelIds: held.labelIds,
              ),
            );
            return;
          }
          candidate = candidate.copyWith(vectorClock: merged);
      }
    }

    if (candidate.deleted) {
      await _store.writeTombstone(candidate);
      await _held.remove(candidate.id);
      return;
    }

    // Sent without its file: an exact copy went out before, or a newer
    // version replaced it. What is held for the register is older still.
    if (payload == null) {
      await _held.remove(candidate.id);
      return;
    }

    final List<Float32List> chunks;
    try {
      chunks = decodeEmbeddingVectors(utf8.encode(payload));
    } on InvalidEmbeddingVectorsException {
      return;
    }
    await _admit(candidate, payload, chunks);
  }

  /// Stores [candidate] when this device's text hashes the same, holds it
  /// when the text may still arrive, and discards it when the entry has
  /// moved past the text it describes.
  Future<void> _admit(
    EmbeddingRegister candidate,
    String payload,
    List<Float32List> chunks,
  ) async {
    final local = await _localText(candidate);
    if (local.exists && local.contentHash == candidate.contentHash) {
      await _store.replaceEntityEmbeddings(
        entityId: candidate.entityId,
        entityType: candidate.entityType,
        modelId: candidate.modelId,
        contentHash: candidate.contentHash,
        embeddings: chunks,
        categoryId: local.categoryId,
        taskId: candidate.taskId,
        subtype: candidate.subtype,
        register: candidate,
      );
      await _held.remove(candidate.id);
      return;
    }

    final source = candidate.sourceVectorClock;
    final localClock = local.vectorClock;
    if (source != null &&
        localClock != null &&
        VectorClock.compare(localClock, source) == VclockStatus.a_gt_b) {
      // The entry has moved on; this device's next embed supersedes it.
      await _held.remove(candidate.id);
      return;
    }

    await _held.put(
      HeldEmbeddingVersion(
        register: candidate,
        payload: payload,
        labelIds: local.labelIds,
      ),
    );
  }

  /// Drops what is held of [registerId] when [clock] covers it.
  Future<void> _dropHeldDominatedBy(
    VectorClock clock,
    String registerId,
  ) async {
    final held = _held[registerId];
    if (held == null) return;
    final status = VectorClock.compare(clock, held.register.vectorClock!);
    if (status == VclockStatus.a_gt_b || status == VclockStatus.equal) {
      await _held.remove(registerId);
    }
  }

  /// Re-runs the merge for every held version [matches] selects.
  Future<void> _recheck(bool Function(HeldEmbeddingVersion) matches) async {
    final due = _held.all.where(matches).toList();
    if (due.isEmpty || !await _accepting) return;
    for (final held in due) {
      final register = held.register;
      await EmbeddingProcessor.runExclusive(_lockKey(register), () async {
        // Taken out first, so the merge does not compare it with itself;
        // put back when the merge fails, so it waits for the next check.
        final current = _held[register.id];
        if (current == null) return;
        await _held.remove(register.id);
        try {
          await _merge(current.register, current.payload);
        } on Object {
          await _held.put(current);
          rethrow;
        }
      });
    }
  }

  /// What this device holds of [candidate]'s entry: its text's hash, its
  /// clock, its category and, for a task, its labels.
  Future<_LocalText> _localText(EmbeddingRegister candidate) async {
    if (candidate.entityType == kEntityTypeAgentReport) {
      final content = await _reportContent(candidate.entityId);
      if (content == null) return _missing;
      final text = content.trim();
      final task = await _journalDb.journalEntityById(candidate.taskId);
      return (
        exists: true,
        contentHash: text.length < kMinEmbeddingTextLength
            ? null
            : EmbeddingContentExtractor.contentHash(text),
        vectorClock: null,
        categoryId: task?.meta.categoryId ?? '',
        labelIds: const <String>[],
      );
    }

    final entity = await _journalDb.journalEntityById(candidate.entityId);
    if (entity == null) return _missing;
    final text = await EmbeddingProcessor.embeddingText(
      entity,
      await EmbeddingProcessor.buildLabelResolver(_journalDb),
    );
    return (
      exists: true,
      contentHash: text == null
          ? null
          : EmbeddingContentExtractor.contentHash(text),
      vectorClock: entity.meta.vectorClock,
      categoryId: entity.meta.categoryId ?? '',
      labelIds: entity is Task ? [...?entity.meta.labelIds] : const <String>[],
    );
  }

  static const _LocalText _missing = (
    exists: false,
    contentHash: null,
    vectorClock: null,
    categoryId: '',
    labelIds: <String>[],
  );

  /// Whether [a] beats [over], two concurrent versions of one register: the
  /// larger source clock in the canonical order, then a tombstone over live
  /// vectors of the same text, then the lower host.
  static bool _wins(EmbeddingRegister a, {required EmbeddingRegister over}) {
    final b = over;
    final bySource = VectorClock.compareCanonically(
      a.sourceVectorClock ?? const VectorClock({}),
      b.sourceVectorClock ?? const VectorClock({}),
    );
    if (bySource != 0) return bySource > 0;
    if (a.deleted != b.deleted) return a.deleted;
    return a.originatingHostId.compareTo(b.originatingHostId) < 0;
  }
}
