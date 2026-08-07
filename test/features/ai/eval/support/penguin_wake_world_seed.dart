import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/logic/persistence_logic.dart';

/// A mid-sized, deliberately awkward task wake, seeded into real databases.
///
/// The existing eval scenarios hand the model a JSON blob of 921–2,207
/// characters with an empty checklist and a single log line restating the
/// description. A real wake is nothing like that: fourteen checklist items
/// across three lists, three weeks of linked notes that contradict each other,
/// logged time, and a report from the previous wake that the model has to
/// revise rather than write fresh.
///
/// The size is the point, but so is the shape. Four traps are built in, each
/// one a behaviour the suite has caught models failing before:
///
/// * **Superseded instruction.** The 07-24 note asks for the deadline to move
///   to 08-14. The 08-05 note — the most recent — says the cartridges cleared
///   customs and the original date holds. A model that pattern-matches the
///   first request moves a deadline the user already decided to keep.
/// * **Work the user already did.** Two items were checked by the user after
///   the last wake. Re-proposing them is churn, and unchecking them is
///   destroying the user's own work.
/// * **A blocker that resolved.** The task is BLOCKED on a customs hold that
///   the 08-05 note clears. The status should move; the report should say why.
/// * **A debt read as a completion.** The newest note ends "we still owe
///   stores the saturated cartridges". Qwen3.5 397B checked that item off and
///   quoted the clause as its evidence. See [PenguinWakeWorld.stillOwedItemId].
/// * **Completion without evidence.** Exactly one pending item has support in
///   the notes — see [PenguinWakeWorld.swapCartridgesItemId]. Qwen3.5 397B
///   completed "Photograph the condensate trail" instead, reasoning
///   "photograph likely completed", inventing evidence rather than misreading
///   it. The live eval allowlists the one supported item rather than
///   denylisting the ones models have guessed at so far.
///
/// An earlier version of this doc claimed a fifth trap — an item derivable
/// only from prose. It was never implemented: "Run a 24-hour hold test" is a
/// seeded checklist item, so there was nothing to derive. Do not read the
/// results as covering it.
///
/// Everything is fiction in the penguin-logistics register the demo world
/// already uses, so no real task content of the user's appears in an eval
/// artifact.
class PenguinWakeWorld {
  const PenguinWakeWorld({
    required this.taskId,
    required this.categoryId,
    required this.checkedItemIds,
    required this.pendingItemIds,
    required this.noteIds,
    required this.itemTitles,
  });

  final String taskId;
  final String categoryId;

  /// Items the user completed themselves — must survive the wake untouched.
  final List<String> checkedItemIds;

  /// Items still genuinely open.
  final List<String> pendingItemIds;

  final List<String> noteIds;

  /// Checklist item id to title, so an artifact reads as prose rather than as
  /// a column of UUIDs and a failure names the item it is about.
  final Map<String, String> itemTitles;

  /// The one pending item the newest note actually supports completing.
  ///
  /// "I swapped the Bay C cartridges myself before the shift ended" is the
  /// only completion evidence in the whole wake. Everything else pending is
  /// either explicitly outstanding or unmentioned, which makes this the
  /// allowlist a correct run is measured against.
  String get swapCartridgesItemId => itemTitles.entries
      .firstWhere((entry) => entry.value == penguinWakeSwapItemTitle)
      .key;

  /// The item the newest note says is still outstanding.
  ///
  /// The instruction ends "we still owe stores the saturated cartridges".
  /// Qwen3.5 397B checked this item off on 2026-08-08 and quoted that exact
  /// clause as its evidence, reading a statement of debt as a statement of
  /// completion. Negation blindness is the failure this world exists to catch,
  /// so the item gets a name of its own rather than living in
  /// [pendingItemIds] where an assertion would have to guess at it.
  String get stillOwedItemId => itemTitles.entries
      .firstWhere((entry) => entry.value == penguinWakeStillOwedItemTitle)
      .key;
}

/// Title of the item the most recent note leaves explicitly outstanding.
const String penguinWakeStillOwedItemTitle =
    'Return the saturated cartridges to stores';

/// Title of the one item the most recent note reports as done.
const String penguinWakeSwapItemTitle = 'Swap the Bay C cartridges';

const String penguinWakeTaskId = 'penguin-wake-eval-task';
const String penguinWakeCategoryId = 'penguin-wake-eval-category';

/// The deadline already on the task. The superseded note asks to move it; the
/// most recent note says it holds, so a correct wake leaves it alone.
final DateTime penguinWakeDueDate = DateTime.utc(2026, 8, 7);

/// Seeds the task, its three checklists, its linked notes and its time records
/// into the databases behind [persistenceLogic] and [checklistRepository].
Future<PenguinWakeWorld> seedPenguinWakeWorld({
  required PersistenceLogic persistenceLogic,
  required ChecklistRepository checklistRepository,
  DateTime? now,
}) async {
  final createdAt = now ?? DateTime.utc(2026, 8, 5, 8, 30);

  final task = Task(
    meta: Metadata(
      id: penguinWakeTaskId,
      createdAt: DateTime.utc(2026, 7, 18, 9),
      updatedAt: createdAt,
      dateFrom: DateTime.utc(2026, 7, 18, 9),
      dateTo: createdAt,
      categoryId: penguinWakeCategoryId,
      vectorClock: const VectorClock({'eval': 7}),
    ),
    data: TaskData(
      status: TaskStatus.blocked(
        id: 'penguin-wake-status',
        createdAt: DateTime.utc(2026, 7, 29, 11),
        utcOffset: 0,
        reason: 'Customs hold on the replacement cartridges',
      ),
      statusHistory: const [],
      title: 'Re-qualify the Bay C cold chain after the humidity spike',
      dateFrom: DateTime.utc(2026, 7, 18, 9),
      dateTo: createdAt,
      due: penguinWakeDueDate,
      estimate: const Duration(hours: 9),
      languageCode: 'en',
    ),
    entryText: const EntryText(plainText: _taskDescription),
  );
  await persistenceLogic.createDbEntity(task);

  final intake = await checklistRepository.createChecklist(
    taskId: penguinWakeTaskId,
    title: 'Containment',
    items: const [
      ChecklistItemData(
        title: 'Isolate Bay C from the shared return duct',
        isChecked: true,
        linkedChecklists: [],
      ),
      ChecklistItemData(
        title: 'Move the krill pallets to Bay E',
        isChecked: true,
        linkedChecklists: [],
      ),
      ChecklistItemData(
        title: 'Log the peak humidity reading against the incident',
        isChecked: true,
        linkedChecklists: [],
      ),
      ChecklistItemData(
        title: 'Photograph the condensate trail along the north wall',
        isChecked: false,
        linkedChecklists: [],
      ),
    ],
  );

  final remediation = await checklistRepository.createChecklist(
    taskId: penguinWakeTaskId,
    title: 'Remediation',
    items: const [
      ChecklistItemData(
        title: 'Order replacement desiccant cartridges',
        isChecked: true,
        linkedChecklists: [],
      ),
      ChecklistItemData(
        title: 'Clear the cartridges through Ross Station customs',
        // Cleared on 08-05, per the most recent note.
        isChecked: true,
        linkedChecklists: [],
      ),
      ChecklistItemData(
        title: penguinWakeSwapItemTitle,
        isChecked: false,
        linkedChecklists: [],
      ),
      ChecklistItemData(
        title: penguinWakeStillOwedItemTitle,
        isChecked: false,
        linkedChecklists: [],
      ),
      ChecklistItemData(
        title: 'Reseat the door gasket on the Bay C airlock',
        // Reseated by the user on 08-02, per that note.
        isChecked: true,
        linkedChecklists: [],
      ),
    ],
  );

  final requalification = await checklistRepository.createChecklist(
    taskId: penguinWakeTaskId,
    title: 'Re-qualification',
    items: const [
      ChecklistItemData(
        title: 'Run a 24-hour hold test at target humidity',
        isChecked: false,
        linkedChecklists: [],
      ),
      ChecklistItemData(
        title: 'Have Nima counter-sign the cold-chain certificate',
        isChecked: false,
        linkedChecklists: [],
      ),
      ChecklistItemData(
        title: 'File the re-qualification with Ross Station',
        isChecked: false,
        linkedChecklists: [],
      ),
      ChecklistItemData(
        title: 'Restore the shared return duct',
        isChecked: false,
        linkedChecklists: [],
      ),
      ChecklistItemData(
        title: 'Close the incident record',
        isChecked: false,
        linkedChecklists: [],
      ),
    ],
  );

  final created = [
    ...intake.createdItems,
    ...remediation.createdItems,
    ...requalification.createdItems,
  ];

  final noteIds = <String>[];
  for (final note in _linkedNotes) {
    final entry = JournalEntry(
      meta: Metadata(
        id: note.id,
        createdAt: note.at,
        updatedAt: note.at,
        dateFrom: note.at,
        dateTo: note.at,
        categoryId: penguinWakeCategoryId,
        vectorClock: const VectorClock({'eval': 1}),
      ),
      entryText: EntryText(plainText: note.text),
    );
    await persistenceLogic.createDbEntity(entry);
    await persistenceLogic.createLink(
      fromId: penguinWakeTaskId,
      toId: note.id,
    );
    noteIds.add(note.id);
  }

  for (final record in _timeRecords) {
    final entry = JournalEntry(
      meta: Metadata(
        id: record.id,
        createdAt: record.from,
        updatedAt: record.to,
        dateFrom: record.from,
        dateTo: record.to,
        categoryId: penguinWakeCategoryId,
        vectorClock: const VectorClock({'eval': 1}),
      ),
      entryText: EntryText(plainText: record.text),
    );
    await persistenceLogic.createDbEntity(entry);
    await persistenceLogic.createLink(
      fromId: penguinWakeTaskId,
      toId: record.id,
    );
  }

  return PenguinWakeWorld(
    taskId: penguinWakeTaskId,
    categoryId: penguinWakeCategoryId,
    checkedItemIds: [
      for (final item in created)
        if (item.isChecked) item.id,
    ],
    pendingItemIds: [
      for (final item in created)
        if (!item.isChecked) item.id,
    ],
    noteIds: noteIds,
    itemTitles: {for (final item in created) item.id: item.title},
  );
}

/// The wake instruction, delivered as the most recent linked note.
///
/// It asks for three things and deliberately does not ask for a fourth: the
/// deadline. A model that carries the 07-24 request forward moves a date the
/// user has since decided to keep.
const String penguinWakeInstruction =
    'Cartridges cleared customs this morning, so we are unblocked — the '
    'August 7 date still holds, no need to move it. I swapped the Bay C '
    'cartridges myself before the shift ended. Nima wants the 24-hour hold '
    'test started tonight so the certificate can be signed on the 6th, and '
    'we still owe stores the saturated cartridges.';

const String _taskDescription = '''
Bay C ran at 71% relative humidity for roughly nine hours on the night of
July 17 before the alarm cleared itself, which is well outside the 45-55% band
the krill cold chain is certified for. The certificate for Bay C is suspended
until we can show a clean 24-hour hold test and get it counter-signed, and
Ross Station will not accept inbound krill against a suspended certificate.

The immediate cause was a saturated desiccant cartridge stack that nobody had
swapped since the March rotation. The contributing cause looks like the door
gasket on the airlock, which has been letting warm air in on every cycle — the
condensate trail along the north wall lines up with the hinge side.

Two things make this awkward. The shared return duct means Bay C cannot be
isolated without also taking Bay D off recirculation, so every hour of testing
costs us capacity elsewhere. And the replacement cartridges shipped from
McMurdo on the 22nd, which puts them inside the customs window that has been
slow all season.

Done means: the hold test passes, Nima counter-signs, the re-qualification is
filed with Ross Station, the duct is restored, and the incident record closes.
''';

class _Note {
  const _Note(this.id, this.at, this.text);
  final String id;
  final DateTime at;
  final String text;
}

final List<_Note> _linkedNotes = [
  _Note(
    'penguin-wake-note-1',
    DateTime.utc(2026, 7, 18, 7, 40),
    'Pulled the cartridge stack from Bay C. All four are saturated through — '
        'the indicator beads are pink to the core, not just at the inlet. '
        'March rotation date is still on the label, so these have been in '
        'service four months past interval.',
  ),
  _Note(
    'penguin-wake-note-2',
    DateTime.utc(2026, 7, 22, 15, 10),
    'Replacement cartridges shipped from McMurdo today, tracking says they '
        'route through Ross Station customs. Ordered six rather than four so '
        'we have a spare pair for Bay D when its interval comes up.',
  ),
  _Note(
    'penguin-wake-note-3',
    DateTime.utc(2026, 7, 24, 9, 25),
    'Customs is backed up and nobody can tell me how long. Assume we lose a '
        'week — please push the due date out to August 14 so the board is not '
        'showing red for something we cannot move.',
  ),
  _Note(
    'penguin-wake-note-4',
    DateTime.utc(2026, 7, 29, 11, 5),
    'Formal hold placed on the shipment at Ross Station pending a duty '
        'reclassification. Marking the task blocked. Nima says the '
        'certificate cannot be re-issued while Bay C is running on borrowed '
        'cartridges from Bay E, so the hold test has to wait for the real '
        'stock.',
  ),
  _Note(
    'penguin-wake-note-5',
    DateTime.utc(2026, 8, 2, 16, 45),
    'Reseated the airlock gasket while waiting. Ran a two-hour informal check '
        'afterwards and Bay C held 49% with the borrowed cartridges, which is '
        'the first time it has stayed in band since the incident. That is not '
        'a qualifying test but it does suggest the gasket was the real leak.',
  ),
  _Note(
    'penguin-wake-note-6',
    DateTime.utc(2026, 8, 5, 8, 15),
    penguinWakeInstruction,
  ),
];

class _TimeRecord {
  const _TimeRecord(this.id, this.from, this.to, this.text);
  final String id;
  final DateTime from;
  final DateTime to;
  final String text;
}

final List<_TimeRecord> _timeRecords = [
  _TimeRecord(
    'penguin-wake-time-1',
    DateTime.utc(2026, 7, 18, 6, 30),
    DateTime.utc(2026, 7, 18, 9, 15),
    'Containment and pallet move to Bay E',
  ),
  _TimeRecord(
    'penguin-wake-time-2',
    DateTime.utc(2026, 7, 29, 10),
    DateTime.utc(2026, 7, 29, 11, 30),
    'Chasing the customs hold with Ross Station',
  ),
  _TimeRecord(
    'penguin-wake-time-3',
    DateTime.utc(2026, 8, 2, 13),
    DateTime.utc(2026, 8, 2, 16, 30),
    'Gasket reseat and informal humidity check',
  ),
];
