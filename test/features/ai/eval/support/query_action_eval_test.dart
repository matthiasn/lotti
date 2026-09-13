import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_task_action_planner.dart';

import 'query_action_eval.dart';

void main() {
  QueryChatAnswer answer(
    List<ChangeItem> items, {
    String text = 'Review changes.',
  }) => QueryChatAnswer(
    questionId: 'q',
    text: text,
    coverage: const QueryCoverage(),
    proposedActions: items,
  );
  QueryActionEvalCase scenario(String id) =>
      queryActionEvalCases.singleWhere((c) => c.id == id);

  test('positive cases cover every tool exposed by production', () {
    const batch = {
      'add_checklist_item': 'add_multiple_checklist_items',
      'update_checklist_item': 'update_checklist_items',
      'assign_task_label': 'assign_task_labels',
      'migrate_checklist_item': 'migrate_checklist_items',
    };
    final covered = queryActionEvalCases
        .expand((c) => c.expected)
        .map((a) => batch[a.tool] ?? a.tool)
        .toSet();
    expect(covered, QueryTaskActionPlanner.tools.map((t) => t.name).toSet());
    expect(
      queryActionEvalCases.map((c) => c.id).toSet(),
      hasLength(queryActionEvalCases.length),
    );
  });

  test('wrong targets, unrequested effects and duplicate actions fail', () {
    const correct = ChangeItem(
      toolName: 'update_checklist_item',
      args: {
        'id': ActionEvalIds.feeder,
        'isChecked': true,
        'reason':
            'The user explicitly requests this change in the current chat.',
      },
      humanSummary: 'Checked',
    );
    final check = scenario('checklist_check');
    expect(
      check.grade(
        answer([
          correct.copyWith(args: {...correct.args}..remove('reason')),
        ]),
      ),
      isNotEmpty,
    );
    expect(
      check.grade(
        answer([
          correct.copyWith(args: {...correct.args, 'reason': 'Please'}),
        ]),
      ),
      isNotEmpty,
    );
    expect(check.grade(answer([correct])), isEmpty);
    expect(
      check.grade(
        answer([
          correct.copyWith(
            args: {...correct.args, 'id': ActionEvalIds.sensor},
          ),
        ]),
      ),
      isNotEmpty,
    );
    expect(
      check.grade(
        answer([
          correct.copyWith(args: {...correct.args, 'isArchived': true}),
        ]),
      ),
      isNotEmpty,
    );
    expect(
      check.grade(answer([correct, correct])),
      contains('unexpected_actions'),
    );
    expect(
      check.grade(
        answer([correct.copyWith(status: ChangeItemStatus.confirmed)]),
      ),
      isNotEmpty,
    );
  });

  test(
    'time grading accepts equivalent local syntax but rejects wrong ranges and content',
    () {
      const time = ChangeItem(
        toolName: 'create_time_entry',
        args: {
          'startTime': '2026-09-12T10:00',
          'endTime': '2026-09-12T10:30:00.000',
          'summary': 'Habitat maintenance.',
        },
        humanSummary: 'Time',
      );
      final check = scenario('time');
      expect(check.grade(answer([time])), isEmpty);
      expect(
        check.grade(
          answer([
            time.copyWith(
              args: {...time.args, 'endTime': '2026-09-12T11:30:00'},
            ),
          ]),
        ),
        isNotEmpty,
      );
      expect(
        check.grade(
          answer([
            time.copyWith(
              args: {...time.args, 'summary': 'Unrelated shopping'},
            ),
          ]),
        ),
        isNotEmpty,
      );
      expect(
        check.grade(
          answer([
            time.copyWith(
              args: {...time.args, 'startTime': '2026-09-12T10:00:00Z'},
            ),
          ]),
        ),
        isNotEmpty,
      );
    },
  );

  test(
    'batch grading requires both exact items and rejects silently checked additions',
    () {
      final items = ['Inspect the inlet', 'Test the pressure sensor']
          .map(
            (title) => ChangeItem(
              toolName: 'add_checklist_item',
              args: {'title': title},
              humanSummary: title,
            ),
          )
          .toList();
      final check = scenario('checklist_batch');
      expect(check.grade(answer(items.reversed.toList())), isEmpty);
      expect(check.grade(answer(items.take(1).toList())), isNotEmpty);
      expect(
        check.grade(
          answer([
            items.first.copyWith(
              args: {...items.first.args, 'isChecked': true},
            ),
            items.last,
          ]),
        ),
        isNotEmpty,
      );
    },
  );

  test(
    'a migration must reference the preceding follow-up placeholder and group',
    () {
      const create = ChangeItem(
        toolName: 'create_follow_up_task',
        args: {
          'title': 'Repair the feeder inlet',
          '_placeholderTaskId': 'generated',
        },
        humanSummary: 'Follow up',
      );
      const move = ChangeItem(
        toolName: 'migrate_checklist_item',
        args: {
          'id': ActionEvalIds.feeder,
          'title': 'Inspect the feeder seal',
          'targetTaskId': 'generated',
        },
        humanSummary: 'Move',
        groupId: 'generated',
      );
      final check = scenario('follow_up_migrate');
      expect(check.grade(answer([create, move])), isEmpty);
      expect(
        check.grade(answer([move, create])),
        contains('invalid_follow_up_dependency'),
      );
      expect(
        check.grade(answer([create, move.copyWith(groupId: null)])),
        contains('invalid_follow_up_dependency'),
      );
      expect(
        check.grade(
          answer([
            create,
            move.copyWith(
              args: {...move.args, 'targetTaskId': ActionEvalIds.target},
            ),
          ]),
        ),
        isNotEmpty,
      );
    },
  );

  test('label confidence and optional defaults cannot hide extra intent', () {
    const label = ChangeItem(
      toolName: 'assign_task_label',
      args: {'id': ActionEvalIds.label, 'confidence': 'high'},
      humanSummary: 'Assign label',
    );
    final check = scenario('label');
    expect(check.grade(answer([label])), isEmpty);
    expect(
      check.grade(
        answer([
          label.copyWith(args: {...label.args, 'confidence': 'low'}),
        ]),
      ),
      isNotEmpty,
    );
    expect(
      check.grade(
        answer([
          label.copyWith(args: {...label.args}..remove('confidence')),
        ]),
      ),
      isNotEmpty,
    );
    final followUp = scenario('follow_up_migrate').expected.first;
    const create = ChangeItem(
      toolName: 'create_follow_up_task',
      args: {
        'title': 'Repair the feeder inlet',
        '_placeholderTaskId': 'new',
        'priority': 'P2',
      },
      humanSummary: 'Create',
    );
    expect(followUp.matches(create, 'new'), isTrue);
    expect(
      followUp.matches(
        create.copyWith(args: {...create.args, 'priority': 'P0'}),
        'new',
      ),
      isFalse,
    );
    for (final placeholder in [null, '', 1]) {
      expect(
        followUp.matches(
          create.copyWith(
            args: {...create.args, '_placeholderTaskId': placeholder},
          ),
          'new',
        ),
        isFalse,
      );
    }
  });

  test('relationship direction and missing time text fail independently', () {
    const link = ChangeItem(
      toolName: 'link_task',
      args: {'targetTaskId': ActionEvalIds.target, 'relation': 'blocks'},
      humanSummary: 'Link',
    );
    expect(scenario('link').grade(answer([link])), isEmpty);
    expect(scenario('link_inverse').grade(answer([link])), isNotEmpty);
    const time = ChangeItem(
      toolName: 'create_time_entry',
      args: {
        'startTime': '2026-09-12T10:00:00',
        'endTime': '2026-09-12T10:30:00',
      },
      humanSummary: 'Record time',
    );
    expect(scenario('time').grade(answer([time])), isNotEmpty);
    expect(
      scenario('time').grade(
        answer([
          time.copyWith(args: {...time.args, 'summary': ''}),
        ]),
      ),
      isNotEmpty,
    );
  });

  test(
    'negative cases require an answer without actions or completion claims',
    () {
      final check = scenario('missing_time');
      expect(
        check.grade(answer([], text: 'What start and end time should I use?')),
        isEmpty,
      );
      expect(
        check.grade(answer([], text: 'I recorded it.')),
        contains('false_execution_claim'),
      );
      for (final claim in [
        "I've set the language.",
        'I linked the task.',
        'I archived it.',
        'I restored it.',
        'I removed it.',
        'I assigned the label.',
        'I migrated the item.',
        'I renamed the task.',
        'I started the timer.',
        'I logged the session.',
        'I have now checked the item.',
        'I’ve already moved it.',
      ]) {
        expect(
          check.grade(answer([], text: claim)),
          contains('false_execution_claim'),
          reason: claim,
        );
      }
      expect(check.grade(answer([], text: '')), contains('empty_answer'));
      expect(
        check.grade(
          answer([
            const ChangeItem(
              toolName: 'create_time_entry',
              args: {},
              humanSummary: '',
            ),
          ]),
        ),
        contains('unexpected_actions'),
      );
    },
  );
}
