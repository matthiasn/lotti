import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/tools/change_effect.dart';
import 'package:lotti/logic/services/metadata_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';

void main() {
  group('ChangeEffect', () {
    test('travels through the arguments and leaves them as they were', () {
      const sent = ChangeEffect(key: 'set-1:3', base: {'title': 'Old'});
      final args = sent.addTo({'title': 'New'});

      final (:effect, args: toolArgs) = ChangeEffect.takeFrom(args);

      expect(toolArgs, {'title': 'New'});
      expect(effect!.key, 'set-1:3');
      expect(effect.base, {'title': 'Old'});
    });

    test(
      'replaces what a proposal carried under the reserved names — a model '
      'can write any key into its arguments',
      () {
        const effect = ChangeEffect(key: 'set-1:0');

        final args = effect.addTo({
          'title': 'New',
          ChangeEffect.keyArg: 'forged',
          ChangeEffect.baseArg: {'title': 'Forged'},
        });

        expect(args, {'title': 'New', ChangeEffect.keyArg: 'set-1:0'});
      },
    );

    test('carries the target base, and a forged one never survives', () {
      const sent = ChangeEffect(
        key: 'set-1:3',
        targetBase: {'isChecked': false},
      );

      final args = sent.addTo({
        'id': 'item-1',
        ChangeEffect.targetBaseArg: {'isChecked': true},
      });
      final (:effect, args: toolArgs) = ChangeEffect.takeFrom(args);

      expect(args[ChangeEffect.targetBaseArg], {'isChecked': false});
      expect(toolArgs, {'id': 'item-1'});
      expect(effect!.targetBase, {'isChecked': false});
      expect(effect.base, isNull);
      // Without one, a forged target base is dropped.
      expect(
        const ChangeEffect(key: 'k').addTo({
          ChangeEffect.targetBaseArg: {'isChecked': true},
        }),
        {ChangeEffect.keyArg: 'k'},
      );
    });

    test('strips a lone target base from the arguments', () {
      final taken = ChangeEffect.takeFrom({
        'id': 'item-1',
        ChangeEffect.targetBaseArg: {'isChecked': true},
      });

      expect(taken.effect, isNull);
      expect(taken.args, {'id': 'item-1'});
    });

    test('names no effect when the arguments carry none', () {
      final args = {'title': 'New'};

      final taken = ChangeEffect.takeFrom(args);

      expect(taken.effect, isNull);
      expect(taken.args, same(args));
    });

    test('strips a key that is no key, and names no effect', () {
      final taken = ChangeEffect.takeFrom({
        'title': 'New',
        ChangeEffect.keyArg: '',
        ChangeEffect.baseArg: 'not a map',
      });

      expect(taken.effect, isNull);
      expect(taken.args, {'title': 'New'});
    });

    test('derives the id MetadataService derives from the same input', () {
      const effect = ChangeEffect(key: 'set-1:0');

      expect(
        effect.entityId('task'),
        MetadataService.deterministicId(effect.entityInput('task')),
      );
      expect(effect.entityId('task'), isNot(effect.entityId('time-entry')));
      expect(
        effect.entityId('task'),
        isNot(const ChangeEffect(key: 'set-1:1').entityId('task')),
      );
    });

    test('finds an entity it created, deleted ones included', () async {
      const effect = ChangeEffect(key: 'set-1:0');
      final id = effect.entityId('task');
      final db = MockJournalDb();
      when(
        () => db.journalEntityMapForIdsIncludingDeleted([id]),
      ).thenAnswer((_) async => {id: testTask});

      expect(await effect.created(db, 'task'), isTrue);

      when(
        () => db.journalEntityMapForIdsIncludingDeleted([id]),
      ).thenAnswer((_) async => const <String, JournalEntity>{});
      expect(await effect.created(db, 'task'), isFalse);
    });

    test('reports the first field that moved away from its base', () {
      const effect = ChangeEffect(
        key: 'set-1:0',
        base: {'title': 'Old', 'dueDate': null},
      );

      expect(effect.changedField({'title': 'Old', 'dueDate': null}), isNull);
      expect(
        effect.changedField({'title': 'Edited', 'dueDate': null}),
        'title',
      );
      expect(
        effect.changedField({'title': 'Old', 'dueDate': '2026-10-01'}),
        'dueDate',
      );
      // Nothing recorded: nothing to compare.
      expect(
        const ChangeEffect(key: 'k').changedField({'title': 'x'}),
        isNull,
      );
    });

    test(
      'records itself on the task beside the effects recorded there, and '
      'finds only its own key (ADR 0098)',
      () {
        const effect = ChangeEffect(key: 'set-1:0');
        final other = testTask.copyWith(
          data: testTask.data.copyWith(appliedChangeEffects: {'set-0:2'}),
        );

        expect(effect.recordedOn(testTask), isFalse);
        expect(effect.recordedOn(other), isFalse);

        final recorded = effect.recordOn(other);

        expect(recorded.data.appliedChangeEffects, {'set-0:2', 'set-1:0'});
        expect(effect.recordedOn(recorded), isTrue);
        expect(
          const ChangeEffect(key: 'set-1:1').recordedOn(recorded),
          isFalse,
        );
        // Only the record changes: the tool sets the field itself.
        expect(recorded.meta, other.meta);
        expect(
          recorded.data.copyWith(appliedChangeEffects: {'set-0:2'}),
          other.data,
        );
      },
    );
  });

  group('target bases (ADR 0097)', () {
    final checkedAt = DateTime(2026, 3, 17, 16);
    final titleSetAt = DateTime(2026, 3, 17, 15);
    final item = ChecklistItemData(
      title: 'Book the venue',
      isChecked: false,
      linkedChecklists: const [],
      checkedAt: checkedAt,
      titleSetAt: titleSetAt,
    );

    test('a checklist update records the fields it sets and their stamps', () {
      final fields = checklistItemFields(item);

      expect(targetBaseFor({'id': 'i', 'isChecked': true}, fields), {
        'isChecked': false,
        'isChecked@': checkedAt.toIso8601String(),
      });
      expect(targetBaseFor({'id': 'i', 'title': 'New'}, fields), {
        'title': 'Book the venue',
        'title@': titleSetAt.toIso8601String(),
      });
      expect(targetBaseFor({'id': 'i', 'isArchived': true}, fields), {
        'isArchived': false,
        'isArchived@': null,
      });
      expect(targetBaseFor({'id': 'i'}, fields), isNull);
    });

    test('changedIn sees an edit that restores the value, by its stamp', () {
      final effect = ChangeEffect(
        key: 'k',
        targetBase: targetBaseFor({
          'isChecked': true,
        }, checklistItemFields(item)),
      );

      expect(effect.changedIn(checklistItemFields(item)), isNull);
      // Checked by the first application, then unchecked by the user.
      final restored = item.copyWith(checkedAt: DateTime(2026, 3, 18));
      expect(effect.changedIn(checklistItemFields(restored)), 'isChecked@');
      expect(
        effect.changedIn(checklistItemFields(item.copyWith(isChecked: true))),
        'isChecked',
      );
      expect(const ChangeEffect(key: 'k').changedIn({'x': 1}), isNull);
    });

    test('a time entry records its range as stored and its text', () {
      final fields = timeEntryFields(testTextEntry);

      expect(targetBaseFor({'entryId': 'e', 'summary': 'New'}, fields), {
        'summary': 'test entry text',
      });
      expect(
        targetBaseFor({
          'entryId': 'e',
          'startTime': 'x',
          'endTime': 'y',
        }, fields),
        {
          'startTime': testTextEntry.meta.dateFrom.toIso8601String(),
          'endTime': testTextEntry.meta.dateTo.toIso8601String(),
        },
      );
      expect(timeEntryFields(testTask)['summary'], isNull);
    });

    test("a project status records the status word and the entry's id", () {
      final status = ProjectStatus.onHold(
        id: 'status-1',
        createdAt: DateTime(2026, 3, 17),
        utcOffset: 0,
        reason: 'Waiting on legal',
      );

      expect(
        targetBaseFor({
          'status': 'active',
          'reason': 'x',
        }, projectFields(status)),
        {'status': 'on_hold', 'status@': 'status-1'},
      );
    });

    test('notApplied is a success that names what moved on', () {
      final result = ChangeEffect.notApplied('checklist item', 'isChecked');

      expect(result.success, isTrue);
      expect(result.output, startsWith('Nothing applied'));
      expect(result.output, contains("checklist item's isChecked"));
    });
  });

  test('taskFieldSetBy names the field of each field-setting tool', () {
    expect(taskFieldSetBy(TaskAgentToolNames.setTaskTitle), 'title');
    expect(taskFieldSetBy(TaskAgentToolNames.setTaskStatus), 'status');
    expect(taskFieldSetBy(TaskAgentToolNames.updateTaskPriority), 'priority');
    expect(
      taskFieldSetBy(TaskAgentToolNames.updateTaskEstimate),
      'estimateMinutes',
    );
    expect(taskFieldSetBy(TaskAgentToolNames.updateTaskDueDate), 'dueDate');
    expect(taskFieldSetBy(TaskAgentToolNames.setTaskLanguage), 'languageCode');
    expect(taskFieldSetBy(TaskAgentToolNames.addChecklistItem), isNull);
  });
}
