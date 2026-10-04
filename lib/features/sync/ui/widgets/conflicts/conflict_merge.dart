import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/membership_list.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/features/sync/ui/pages/conflicts/conflict_detail_shared.dart';
import 'package:lotti/features/sync/ui/widgets/conflicts/entry_field_diff.dart';

/// Assembles the resolved [JournalEntity] for a conflict. Pure: callers feed it
/// the two versions and the user's choices, and it returns the entity to write.
///
/// Every result carries the *merged* vector clock ([VectorClock.merge]) so the
/// written version causally dominates both sides and the conflict auto-resolves
/// (the persistence layer applies a write only when its clock dominates).

/// "Keep this device" / "Keep other device": returns [side]'s entity stamped
/// with the merged vector clock.
JournalEntity resolveToSide({
  required JournalEntity local,
  required JournalEntity remote,
  required ConflictSide side,
}) {
  final chosen = side == ConflictSide.local ? local : remote;
  return _resolved(chosen, local, remote);
}

/// "Combine": starts from [baseSide]'s entity — which supplies the structural
/// payload (typed `data`, geolocation, and any field not individually
/// modelled) — then overrides each field named in [choices] with the value
/// from the chosen side. Fields absent from [choices], or whose choice equals
/// [baseSide], are left as the base's.
///
/// Only independently-mergeable fields are honoured: the metadata fields
/// (category, starred, private, flag, dateFrom, dateTo), the [EntryField.body]
/// text, for entities that carry a structured title [EntryField.title], and
/// a task's status, priority, estimate and due date (ADR 0107). Other
/// differences ([EntryField.other], audio duration, …) follow [baseSide].
JournalEntity buildMergedEntity({
  required JournalEntity local,
  required JournalEntity remote,
  required ConflictSide baseSide,
  required Map<EntryField, ConflictSide> choices,
}) {
  JournalEntity entityFor(ConflictSide side) =>
      side == ConflictSide.local ? local : remote;

  final base = entityFor(baseSide);

  var meta = base.meta;
  void overrideMeta(
    EntryField field,
    Metadata Function(Metadata current, Metadata source) apply,
  ) {
    final choice = choices[field];
    if (choice == null || choice == baseSide) return;
    meta = apply(meta, entityFor(choice).meta);
  }

  overrideMeta(
    EntryField.category,
    (m, src) => m.copyWith(categoryId: src.categoryId),
  );
  overrideMeta(
    EntryField.starred,
    (m, src) => m.copyWith(starred: src.starred),
  );
  overrideMeta(
    EntryField.private,
    (m, src) => m.copyWith(private: src.private),
  );
  overrideMeta(EntryField.flag, (m, src) => m.copyWith(flag: src.flag));
  overrideMeta(
    EntryField.dateFrom,
    (m, src) => m.copyWith(dateFrom: src.dateFrom),
  );
  overrideMeta(EntryField.dateTo, (m, src) => m.copyWith(dateTo: src.dateTo));

  var result = base.copyWith(meta: meta);

  final bodyChoice = choices[EntryField.body];
  if (bodyChoice != null && bodyChoice != baseSide) {
    result = result.copyWith(entryText: entityFor(bodyChoice).entryText);
  }

  final titleChoice = choices[EntryField.title];
  if (titleChoice != null && titleChoice != baseSide) {
    result = _withTitleFrom(result, entityFor(titleChoice));
  }

  if (result is Task) {
    var data = result.data;
    void overrideTask(
      EntryField field,
      TaskData Function(TaskData current, TaskData source) apply,
    ) {
      final choice = choices[field];
      if (choice == null || choice == baseSide) return;
      if (entityFor(choice) case final Task source) {
        data = apply(data, source.data);
      }
    }

    overrideTask(
      EntryField.status,
      (d, src) => d.copyWith(status: src.status),
    );
    overrideTask(
      EntryField.priority,
      (d, src) => d.copyWith(priority: src.priority),
    );
    overrideTask(
      EntryField.estimate,
      (d, src) => d.copyWith(estimate: src.estimate),
    );
    overrideTask(EntryField.dueDate, (d, src) => d.copyWith(due: src.due));
    result = result.copyWith(data: data);
  }

  return _resolved(result, local, remote);
}

/// [entity] as the resolution of [local] and [remote]: the merged clock; for
/// a task, every applied change either side records — whichever side's
/// fields the user kept, a change that landed on either must not apply again
/// (`TaskData.appliedChangeEffects`, ADR 0098), every status either side's
/// history records (`TaskDataOnStored.withHistoryOf`), pull request tracking
/// when either side turned it on (`TaskDataOnStored.withTrackingOf`), and
/// every checklist either side lists; for a checklist, every item either
/// side lists (ADR 0105). Keeping one side's list would drop what the other device added: a
/// checklist nobody sees any more, or an item listed nowhere.
JournalEntity _resolved(
  JournalEntity entity,
  JournalEntity local,
  JournalEntity remote,
) {
  final joined = switch ((entity, local, remote)) {
    (final Task e, final Task l, final Task r) => e.copyWith(
      data: e.data
          .withEffectsOf(l.data)
          .withEffectsOf(r.data)
          .withHistoryOf(l.data)
          .withHistoryOf(r.data)
          .withTrackingOf(l.data)
          .withTrackingOf(r.data)
          .copyWith(
            checklistIds: _joined(
              e.data.checklistIds,
              l.data.checklistIds,
              r.data.checklistIds,
            ),
          ),
    ),
    (final Checklist e, final Checklist l, final Checklist r) => e.copyWith(
      data: e.data.copyWith(
        linkedChecklistItems: joinMembers(
          joinMembers(e.data.linkedChecklistItems, l.data.linkedChecklistItems),
          r.data.linkedChecklistItems,
        ),
      ),
    ),
    _ => entity,
  };
  return _withMergedClock(joined, local, remote);
}

/// [kept] with every id [local] or [remote] lists appended ([joinMembers]);
/// `null` only when all three are.
List<String>? _joined(
  List<String>? kept,
  List<String>? local,
  List<String>? remote,
) {
  if (kept == null && local == null && remote == null) return null;
  return joinMembers(
    joinMembers(kept ?? const [], local ?? const []),
    remote ?? const [],
  );
}

/// Copies the structured title from [source] onto [base]. Both are the same
/// runtime type for any real conflict (a type change is resolved as a binary,
/// never combined), so the non-matching record-pattern arms are unreachable
/// and fall through to [base] unchanged.
JournalEntity _withTitleFrom(JournalEntity base, JournalEntity source) {
  return switch ((base, source)) {
    (final Task b, final Task s) => b.copyWith(
      data: b.data.copyWith(title: s.data.title),
    ),
    (final JournalEvent b, final JournalEvent s) => b.copyWith(
      data: b.data.copyWith(title: s.data.title),
    ),
    (final ProjectEntry b, final ProjectEntry s) => b.copyWith(
      data: b.data.copyWith(title: s.data.title),
    ),
    (final Checklist b, final Checklist s) => b.copyWith(
      data: b.data.copyWith(title: s.data.title),
    ),
    (final ChecklistItem b, final ChecklistItem s) => b.copyWith(
      data: b.data.copyWith(title: s.data.title),
    ),
    _ => base,
  };
}

JournalEntity _withMergedClock(
  JournalEntity entity,
  JournalEntity local,
  JournalEntity remote,
) {
  final lvc = local.meta.vectorClock;
  final rvc = remote.meta.vectorClock;
  if (lvc == null && rvc == null) return entity;
  return entity.copyWith(
    meta: entity.meta.copyWith(vectorClock: VectorClock.merge(lvc, rvc)),
  );
}
