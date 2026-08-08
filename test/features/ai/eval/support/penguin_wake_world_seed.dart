import 'dart:ui' show Locale;

import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/demo/seed/demo_seed_text.dart';
import 'package:lotti/features/demo/seed/demo_world.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/logic/persistence_logic.dart';

/// A wake seeded from the shipped penguin demo world.
///
/// Nothing about the task is authored here. The categories, labels, tasks,
/// checklists, notes, time records and links all come from
/// `ManualDemoWorld.penguinLogistics` — the fixture `DemoSeeder` writes on a
/// user's first run — persisted through `PersistenceLogic`, the API the app
/// writes with. Only the demo-mode plumbing around it (world handles, the R2
/// image catalog, the seed manifest) is skipped, and none of that reaches the
/// model.
///
/// The previous version invented its own task, and that is precisely where an
/// eval stops measuring the app: it had no category definitions and no labels,
/// so `LinkedTaskContextBuilder`'s label resolution never ran and the model
/// never saw a label at all.
///
/// The wake is **"Trace the humidity spike in Bay C"** — `TaskBlocked`, two
/// labels (`manual-habitat-critical`, `manual-label-blocked`), a four-item
/// checklist with one already done, and sibling links to the air-scrubber and
/// water-recycler tasks.
///
/// The one authored addition is the closing note, which is how an instruction
/// actually reaches an agent: someone writes a note on the task and the wake
/// fires. It carries the scenario's traps, all of them grounded in the demo
/// task's own checklist:
///
/// * **A blocker that resolved.** The task is blocked waiting on the sensor
///   swap; the note reports it done. The status should move.
/// * **Work already done.** "Chart the humidity readings by day" was complete
///   before the wake. Re-proposing it is churn; unchecking it destroys work.
/// * **Completion without evidence.** The note supports exactly two
///   completions — see [PenguinWakeWorld.supportedCompletionIds]. Anything else
///   is invented.
/// * **A debt read as a completion.** The note ends by saying the report still
///   has to be filed. A model that marks
///   [penguinWakeReportItemTitle] done has read the negation backwards.
class PenguinWakeWorld {
  const PenguinWakeWorld({
    required this.taskId,
    required this.categoryId,
    required this.checkedItemIds,
    required this.pendingItemIds,
    required this.noteIds,
    required this.itemTitles,
    required this.labelIds,
    required this.dueDate,
  });

  final String taskId;
  final String categoryId;

  /// Items already complete when the wake starts — must survive it untouched.
  final List<String> checkedItemIds;

  /// Items still genuinely open.
  final List<String> pendingItemIds;

  final List<String> noteIds;

  /// Checklist item id to title, so an artifact reads as prose rather than a
  /// column of UUIDs and a failure names the item it is about.
  final Map<String, String> itemTitles;

  /// The demo labels this task carries, so a test can prove they reached the
  /// model rather than being silently dropped by a mocked cache.
  final List<String> labelIds;

  /// The task's due date as seeded. Nothing in the wake asks to move it, so a
  /// proposal that changes it is invented work.
  final DateTime? dueDate;

  String _idOf(String title) =>
      itemTitles.entries.firstWhere((entry) => entry.value == title).key;

  /// The only completions the closing note supports.
  ///
  /// An allowlist rather than a denylist: a denylist has to anticipate each
  /// item a model will invent, and Qwen3.5 397B has already demonstrated it
  /// will pick one nobody predicted.
  List<String> get supportedCompletionIds => [
    _idOf(penguinWakeSensorSwapItemTitle),
    _idOf(penguinWakeSeamWalkItemTitle),
  ];

  /// The item the note explicitly leaves outstanding.
  String get stillOutstandingItemId => _idOf(penguinWakeReportItemTitle);
}

/// The demo task this wake runs on: blocked, labelled, with sibling links.
final String penguinWakeTaskId = demoHumiditySpikeTaskId;

/// Demo checklist item titles the scenario reasons about.
const String penguinWakeChartedItemTitle = 'Chart the humidity readings by day';
const String penguinWakeSensorSwapItemTitle = 'Wait for the Bay C sensor swap';
const String penguinWakeSeamWalkItemTitle =
    'Walk the seam line with the thermal camera';
const String penguinWakeReportItemTitle = 'Report the leak or clear the bay';

/// The unblocking instruction, appended as the newest linked note.
///
/// Reports two completions, resolves the blocker, and leaves the third item
/// explicitly outstanding — "still has to be filed" is a debt, not a
/// completion.
const String penguinWakeInstruction =
    'Sensor swap is done and Bay C is reporting again. I walked the seam line '
    'with the thermal camera this morning and found it — a hairline gap on the '
    'nursery-side seam, right where the condensate trail pointed. So we are '
    'unblocked. The write-up still has to be filed before we can clear the bay.';

/// A note that reports nothing new, for the no-op scenario.
const String penguinWakeNoOpNote =
    'Chased the sensor swap again. Still no date from the parts store, so Bay C '
    'is still on the old wall sensor and still reading high. Nothing else to '
    'report.';

/// Seeds the demo world, then appends the scenario's closing note.
Future<PenguinWakeWorld> seedPenguinWakeWorld({
  required PersistenceLogic persistenceLogic,
  DateTime? now,
  String? finalNote,
}) async {
  final seededAt = now ?? DateTime.utc(2026, 8, 5, 8, 30);
  final world = ManualDemoWorld.penguinLogistics(
    translate: demoSeedTextForLocale(const Locale('en')),
    now: seededAt,
  );

  // DemoSeeder's order: definitions before the entities referencing them,
  // journal entities in dependency order, links once both endpoints exist.
  for (final category in world.categories) {
    await persistenceLogic.upsertEntityDefinition(category);
  }
  for (final label in world.labels) {
    await persistenceLogic.upsertEntityDefinition(label);
  }
  for (final entity in world.journalEntities) {
    await persistenceLogic.createDbEntity(entity);
  }
  for (final link in world.links) {
    await persistenceLogic.createLink(fromId: link.fromId, toId: link.toId);
  }

  final task = world.tasks.firstWhere(
    (candidate) => candidate.meta.id == penguinWakeTaskId,
  );

  final listIds = (task.data.checklistIds ?? const <String>[]).toSet();
  final itemIds = <String>{
    for (final checklist in world.checklists)
      if (listIds.contains(checklist.meta.id))
        ...checklist.data.linkedChecklistItems,
  };
  final items = world.checklistItems
      .where((item) => itemIds.contains(item.meta.id))
      .toList();

  const noteId = 'penguin-wake-closing-note';
  final note = JournalEntry(
    meta: Metadata(
      id: noteId,
      createdAt: seededAt,
      updatedAt: seededAt,
      dateFrom: seededAt,
      dateTo: seededAt,
      categoryId: task.meta.categoryId,
      vectorClock: const VectorClock({'eval': 1}),
    ),
    entryText: EntryText(plainText: finalNote ?? penguinWakeInstruction),
  );
  await persistenceLogic.createDbEntity(note);
  await persistenceLogic.createLink(fromId: penguinWakeTaskId, toId: noteId);

  return PenguinWakeWorld(
    taskId: penguinWakeTaskId,
    categoryId: task.meta.categoryId!,
    checkedItemIds: [
      for (final item in items)
        if (item.data.isChecked) item.meta.id,
    ],
    pendingItemIds: [
      for (final item in items)
        if (!item.data.isChecked) item.meta.id,
    ],
    noteIds: [noteId],
    itemTitles: {for (final item in items) item.meta.id: item.data.title},
    labelIds: task.meta.labelIds ?? const <String>[],
    dueDate: task.data.due,
  );
}
