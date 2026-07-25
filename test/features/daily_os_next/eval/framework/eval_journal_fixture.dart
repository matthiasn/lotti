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
  final Set<String> _created = {};

  /// Replaces the contents with [entities] — called once per cell.
  void reset(Iterable<JournalEntity> entities) {
    _byId
      ..clear()
      ..addEntries([
        for (final entity in entities) MapEntry(entity.id, entity),
      ]);
    _created.clear();
  }

  /// Records a write — a triage update, or a task the run created.
  void add(JournalEntity entity) => _byId[entity.id] = entity;

  /// Records a task the run brought into existence.
  ///
  /// Tracked here rather than inferred from the agent log, because
  /// `create_task_from_phrase` only writes a `ParsedItemEntity` when the model
  /// passes the optional `captureItemId`. Without it the task is still created
  /// and still schedulable, and reconstructing ids from parsed items alone
  /// would report that legitimate work as fabricated.
  void addCreated(JournalEntity entity) {
    add(entity);
    _created.add(entity.id);
  }

  /// Ids of tasks this run created.
  Set<String> get createdIds => Set.unmodifiable(_created);

  /// Every task currently stored, reflecting any updates the run made.
  List<Task> get tasks => _byId.values.whereType<Task>().toList();

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
