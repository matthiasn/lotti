import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
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
