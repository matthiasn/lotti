import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/ui/pages/conflicts/conflict_detail_shared.dart';
import 'package:lotti/features/sync/ui/widgets/conflicts/conflict_merge.dart';
import 'package:lotti/features/sync/ui/widgets/conflicts/entry_field_diff.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/repositories/checklist_repository.dart';

/// The two concurrent versions of a conflicted entry. [local] is the version
/// currently in the journal; [remote] is the incoming version deserialized
/// from the conflict row's payload.
class ConflictPair {
  const ConflictPair({
    required this.local,
    required this.remote,
  });

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
/// sides, the write applies, and the conflict row auto-resolves. A resolved
/// checklist is written through [ChecklistRepository.resolveConflict], which
/// also lists a kept checklist on its task, or deletes the items of one whose
/// deletion was kept (ADR 0105).
///
/// A resolution is built on the sides the user was shown, so it applies only
/// while the stored row is still that local side: a version stored since —
/// the task agent setting a field, a checklist listed on the task — would
/// otherwise be replaced by the merged clock without anyone having seen it
/// (`specs/tla/TaskFieldWrites.tla`, ResolveOnStored). Refused, the
/// resolution answers false, and the screen reads the local side again.
class ConflictResolutionService {
  ConflictResolutionService({
    PersistenceLogic? persistenceLogic,
    ChecklistRepository? checklistRepository,
    JournalDb? journalDb,
  }) : _persistence = persistenceLogic ?? getIt<PersistenceLogic>(),
       _checklistRepositoryOverride = checklistRepository,
       _journalDb = journalDb ?? getIt<JournalDb>();

  final PersistenceLogic _persistence;
  final JournalDb _journalDb;
  final ChecklistRepository? _checklistRepositoryOverride;

  /// Built on first use: only a checklist's resolution needs it.
  late final ChecklistRepository _checklistRepository =
      _checklistRepositoryOverride ?? ChecklistRepository();

  /// "Keep this device" / "Keep other device".
  Future<bool> keepSide(ConflictPair pair, ConflictSide side) {
    final winner = resolveToSide(
      local: pair.local,
      remote: pair.remote,
      side: side,
    );
    return _write(winner, pair);
  }

  Future<bool> _write(JournalEntity resolved, ConflictPair pair) {
    // Read with its soft deletion, as the screen read it: a delete-versus-
    // edit conflict is resolved over the local tombstone.
    Future<bool> shown() async =>
        (await _journalDb.journalEntityByIdIncludingDeleted(
          pair.local.id,
        ))?.meta.vectorClock ==
        pair.local.meta.vectorClock;
    Future<bool> write() => _persistence.updateJournalEntity(
      resolved,
      resolved.meta,
      precondition: shown,
    );
    if (resolved is! Checklist) return write();
    return _checklistRepository.resolveConflict(resolved, write);
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
    return _write(merged, pair);
  }
}
