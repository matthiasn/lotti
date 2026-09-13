import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/conversions.dart';

import 'penguin_query_eval.dart';
import 'query_action_eval.dart';

/// A declared action-only overlay. The canonical ManualDemoWorld and ordinary
/// five-case query baseline remain unchanged. Every scenario starts from this
/// same fixed state; only the declared language/timer variants differ.
class QueryActionEvalFixture {
  QueryActionEvalFixture(this.database);
  final PenguinQueryDatabase database;
  static final now = DateTime(2026, 9, 13, 12);
  static const otherCategory = 'query-eval-other-category';

  Task home({bool languageAlreadySet = false}) => database.corpus.task.copyWith(
    meta: database.corpus.task.meta.copyWith(private: false, labelIds: []),
    data: database.corpus.task.data.copyWith(
      status: TaskStatus.open(
        id: 'action-eval-open',
        createdAt: now,
        utcOffset: 120,
      ),
      estimate: const Duration(minutes: 30),
      due: DateTime(2026, 9, 20),
      priority: TaskPriority.p2Medium,
      languageCode: languageAlreadySet ? 'en' : null,
      languageSource: ChangeSource.user,
      checklistIds: [ActionEvalIds.checklist],
      aiSuppressedLabelIds: {},
    ),
  );

  List<JournalEntity> get entries {
    final task = home();
    Metadata meta(String id) =>
        task.meta.copyWith(id: id, createdAt: now, updatedAt: now);
    return [
      task,
      Checklist(
        meta: meta(ActionEvalIds.checklist),
        data: ChecklistData(
          title: 'Feeder maintenance',
          linkedChecklistItems: [ActionEvalIds.feeder, ActionEvalIds.sensor],
          linkedTasks: [task.id],
        ),
      ),
      ChecklistItem(
        meta: meta(ActionEvalIds.feeder),
        data: ChecklistItemData(
          title: 'Inspect the feeder seal',
          isChecked: false,
          linkedChecklists: const [ActionEvalIds.checklist],
          // ignore: avoid_redundant_argument_values
          checkedBy: ChangeSource.user,
          checkedAt: DateTime(2026, 9, 13, 10),
        ),
      ),
      ChecklistItem(
        meta: meta(ActionEvalIds.sensor),
        data: ChecklistItemData(
          title: 'Replace the pressure sensor',
          isChecked: true,
          isArchived: true,
          linkedChecklists: const [ActionEvalIds.checklist],
          // ignore: avoid_redundant_argument_values
          checkedBy: ChangeSource.user,
          checkedAt: DateTime(2026, 9, 13, 10),
        ),
      ),
      task.copyWith(
        meta: meta(ActionEvalIds.target),
        data: task.data.copyWith(
          title: 'Order replacement feeder parts',
          checklistIds: [],
        ),
      ),
      task.copyWith(
        meta: meta(
          ActionEvalIds.foreign,
        ).copyWith(categoryId: otherCategory, private: true),
        data: task.data.copyWith(
          title: 'Private medical appointment',
          checklistIds: [],
        ),
      ),
      JournalEntry(
        meta: meta(ActionEvalIds.session).copyWith(
          dateFrom: DateTime(2026, 9, 12, 10),
          dateTo: DateTime(2026, 9, 12, 11),
        ),
        entryText: const EntryText(plainText: 'Feeder calibration session.'),
      ),
      JournalEntry(
        meta: meta(ActionEvalIds.timer).copyWith(
          dateFrom: DateTime(2026, 9, 13, 11),
          dateTo: DateTime(2026, 9, 13, 11),
        ),
        entryText: const EntryText(plainText: 'Working on the feeder.'),
      ),
    ];
  }

  LabelDefinition get label => LabelDefinition(
    id: ActionEvalIds.label,
    name: 'Orbital Operations',
    color: '#008577',
    createdAt: now,
    updatedAt: now,
    vectorClock: null,
    private: false,
    applicableCategoryIds: [database.corpus.task.meta.categoryId!],
  );

  List<EntryLink> get links => [
    for (final id in [
      ActionEvalIds.target,
      ActionEvalIds.foreign,
      ActionEvalIds.session,
      ActionEvalIds.timer,
    ])
      EntryLink.basic(
        id: 'action-eval-link-$id',
        fromId: database.corpus.task.id,
        toId: id,
        createdAt: now,
        updatedAt: now,
        vectorClock: null,
      ),
  ];

  String get hash => sha256
      .convert(
        utf8.encode(
          jsonEncode({
            'version': 'penguin-action-overlay-v1',
            'now': now.toIso8601String(),
            'entries': entries.map((entry) => entry.toJson()).toList(),
            'label': label.toJson(),
            'links': links.map((link) => link.toJson()).toList(),
          }),
        ),
      )
      .toString();

  Future<void> seed() async {
    await database.journal.upsertEntityDefinition(
      database.corpus.world.categories.first.copyWith(
        id: otherCategory,
        name: 'Separate synthetic category',
      ),
    );
    await database.journal.upsertEntityDefinition(label);
    for (final entry in entries) {
      await database.journal.upsertJournalDbEntity(toDbEntity(entry));
      await database.fts.insertText(entry);
    }
    for (final link in links) {
      await database.journal.upsertEntryLink(link);
    }
  }

  Future<void> reset(QueryActionEvalCase scenario) async {
    await database.journal.upsertJournalDbEntity(
      toDbEntity(home(languageAlreadySet: scenario.languageAlreadySet)),
    );
  }
}
