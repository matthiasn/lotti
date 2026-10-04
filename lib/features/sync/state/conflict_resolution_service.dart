import 'package:lotti/classes/journal_entities.dart';
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
class ConflictResolutionService {
  ConflictResolutionService({
    PersistenceLogic? persistenceLogic,
    ChecklistRepository? checklistRepository,
  }) : _persistence = persistenceLogic ?? getIt<PersistenceLogic>(),
       _checklistRepositoryOverride = checklistRepository;

  final PersistenceLogic _persistence;
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
    return _write(winner);
  }

  Future<bool> _write(JournalEntity resolved) {
    Future<bool> write() =>
        _persistence.updateJournalEntity(resolved, resolved.meta);
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
    return _write(merged);
  }
}
