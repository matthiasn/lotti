import 'package:lotti/classes/journal_entities.dart';

/// The journal a single eval cell reads and writes.
///
/// Exists because a drafting wake can *create* work, not only schedule what it
/// was shown. `create_task_from_phrase` materialises a task, and the model may
/// then reference it in `draft_day_plan` or `apply_triage`. Production resolves
/// those references through the journal — `DayAgentPlanWriter` builds its
/// allowed-existing-task set from `journalEntityMapForIds`, and the capture
/// service resolves triage targets through `journalEntityById` — so a task the
/// model just created must be *findable there*, or the pipeline rejects a
/// reference that would have worked in the app.
///
/// A stub that returns a `Task` from `createTaskEntry` without storing it is
/// therefore not a stub of the app's behaviour: it hands the model an id and
/// then denies the id exists.
///
/// One instance is shared per cell through [currentEvalJournal] rather than
/// threaded through every stub, because the two halves are registered in
/// different places — the journal reads on the per-cell harness, the
/// persistence writes in the process-wide `getIt`. The runner is explicitly
/// sequential, so a single current-cell pointer is safe; it is reset at the
/// start of each cell's seeding so no run can see another's tasks.
class EvalJournalFixture {
  final Map<String, JournalEntity> _byId = {};

  /// Replaces the contents with [entities] — called once per cell.
  void reset(Iterable<JournalEntity> entities) {
    _byId
      ..clear()
      ..addEntries([
        for (final entity in entities) MapEntry(entity.id, entity),
      ]);
  }

  /// Records something the run itself created.
  void add(JournalEntity entity) => _byId[entity.id] = entity;

  JournalEntity? byId(String id) => _byId[id];

  Map<String, JournalEntity> mapForIds(Iterable<String> ids) => {
    for (final id in ids) id: ?_byId[id],
  };

  /// Everything currently stored, for assertions.
  Iterable<JournalEntity> get entities => _byId.values;
}

/// The journal of the cell currently running.
///
/// Mutable module state, deliberately: see [EvalJournalFixture] for why the
/// two stub sites cannot share an instance any other way, and why the
/// sequential runner makes it safe.
final EvalJournalFixture currentEvalJournal = EvalJournalFixture();
