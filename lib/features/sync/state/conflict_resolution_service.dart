import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/ui/pages/conflicts/conflict_detail_shared.dart';
import 'package:lotti/features/sync/ui/widgets/conflicts/conflict_merge.dart';
import 'package:lotti/features/sync/ui/widgets/conflicts/entry_field_diff.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';

/// The two concurrent versions of a conflicted entry plus the conflict row that
/// recorded them. [local] is the version currently in the journal; [remote] is
/// the incoming version deserialized from the conflict row's payload.
class ConflictPair {
  const ConflictPair({
    required this.conflict,
    required this.local,
    required this.remote,
  });

  final Conflict conflict;
  final JournalEntity local;
  final JournalEntity remote;

  /// Field-level diff between the two versions — what the resolution UI renders.
  EntryDiff get diff => computeEntryDiff(local, remote);
}

/// Loads and resolves sync conflicts. Thin orchestration over the DB and
/// persistence layers plus the pure [computeEntryDiff] / [resolveToSide] /
/// [buildMergedEntity] logic — so it is fully unit-testable without widgets.
///
/// Resolution always writes through [PersistenceLogic.updateJournalEntity];
/// because the written entity carries the merged vector clock it dominates both
/// sides, the write applies, and the conflict row auto-resolves.
class ConflictResolutionService {
  ConflictResolutionService({
    JournalDb? db,
    PersistenceLogic? persistenceLogic,
  }) : _db = db ?? getIt<JournalDb>(),
       _persistence = persistenceLogic ?? getIt<PersistenceLogic>();

  final JournalDb _db;
  final PersistenceLogic _persistence;

  /// Loads both versions of the conflicted entry, or `null` if the conflict row
  /// or the local entry is gone (already resolved or deleted elsewhere).
  Future<ConflictPair?> loadPair(String conflictId) async {
    final conflict = await _db.conflictById(conflictId);
    if (conflict == null) return null;
    final local = await _db.journalEntityById(conflictId);
    if (local == null) return null;
    final JournalEntity remote;
    try {
      remote = fromSerialized(conflict.serialized);
    } catch (_) {
      // A corrupt payload shouldn't crash the conflict-detail path; degrade
      // to "not found" so the UI shows its not-found state instead.
      return null;
    }
    return ConflictPair(conflict: conflict, local: local, remote: remote);
  }

  /// "Keep this device" / "Keep other device".
  Future<bool> keepSide(ConflictPair pair, ConflictSide side) {
    final winner = resolveToSide(
      local: pair.local,
      remote: pair.remote,
      side: side,
    );
    return _persistence.updateJournalEntity(winner, winner.meta);
  }

  /// "Combine": write the per-field merge of the two sides.
  Future<bool> combine(
    ConflictPair pair, {
    required ConflictSide baseSide,
    required Map<EntryField, ConflictSide> choices,
  }) {
    final merged = buildMergedEntity(
      local: pair.local,
      remote: pair.remote,
      baseSide: baseSide,
      choices: choices,
    );
    return _persistence.updateJournalEntity(merged, merged.meta);
  }
}
