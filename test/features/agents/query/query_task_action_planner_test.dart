import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/query/query_task_action_planner.dart';
import 'package:lotti/features/agents/query/query_text_inference.dart';

void main() {
  const context = QueryTaskActionContext(
    taskId: 'habitat',
    input: {
      'title': 'Inspect orbital penguin habitat',
      'checklistItems': [
        {'id': 'feeder', 'title': 'Inspect feeder', 'isChecked': false},
      ],
      'timeEntries': [
        {
          'id': 'session',
          'startTime': '2026-09-13T10:00:00',
          'endTime': '2026-09-13T11:00:00',
        },
      ],
      'labels': [
        {'id': 'ops', 'name': 'Operations'},
      ],
      'tasks': [
        {'id': 'supplies', 'title': 'Order supplies'},
      ],
    },
    dependencies: [],
    checklistIds: {'feeder'},
    taskIds: {'supplies'},
    labelIds: {'ops'},
    timeEntryIds: {'session'},
    runningTimerId: 'timer',
  );
  Future<({String text, List<ChangeItem> items})> plan(
    List<Map<String, Object?>> actions,
  ) =>
      QueryTaskActionPlanner(
        inference: QueryTextInference(
          generate: (_, _) => Stream.value(
            jsonEncode({'answer': 'Review these changes.', 'actions': actions}),
          ),
        ),
      ).plan(
        context: context,
        question: 'Add a feeder check.',
        conversation: [],
        cancellation: QueryCancellation(),
      );

  test(
    'prepares checklist and time entries without a mutation dependency',
    () async {
      final result = await plan([
        {
          'name': 'add_multiple_checklist_items',
          'arguments': {
            'items': [
              {'title': 'Inspect the feeder'},
              {'title': 'Inspect the feeder'},
            ],
          },
          'summary': 'Inspect the feeder',
        },
        {
          'name': 'create_time_entry',
          'arguments': {
            'startTime': '2026-09-13T10:00:00',
            'endTime': '2026-09-13T10:30:00',
            'summary': 'Habitat maintenance',
          },
          'summary': 'Habitat maintenance',
        },
      ]);
      expect(result.items.map((item) => item.toolName), [
        'add_checklist_item',
        'create_time_entry',
      ]);
      expect(result.items.last.args['endTime'], '2026-09-13T10:30:00');
      expect(
        result.items.every((item) => item.status.name == 'pending'),
        isTrue,
      );
    },
  );

  for (final payload in <Map<String, Object?>>[
    {'actions': <Object?>[]},
    {'answer': ' ', 'actions': <Object?>[]},
    {'answer': 'Review.', 'actions': 'not a list'},
    {
      'answer': 'Review.',
      'actions': [null],
    },
    {
      'answer': 'Review.',
      'actions': [
        {
          'name': 'set_task_title',
          'arguments': {'title': 'Feeder'},
          'summary': '',
        },
      ],
    },
    {
      'answer': 'Review.',
      'actions': List.filled(9, {
        'name': 'set_task_title',
        'arguments': {'title': 'Feeder'},
        'summary': 'Feeder',
      }),
    },
  ]) {
    test(
      'malformed or excessive response cannot become a proposal: ${jsonEncode(payload)}',
      () async {
        final planner = QueryTaskActionPlanner(
          inference: QueryTextInference(
            generate: (_, _) => Stream.value(jsonEncode(payload)),
          ),
        );
        await expectLater(
          planner.plan(
            context: context,
            question: 'Rename this task.',
            conversation: [],
            cancellation: QueryCancellation(),
          ),
          throwsA(isA<FormatException>()),
        );
      },
    );
  }

  test(
    'oversized context is rejected before contacting the provider',
    () async {
      var requested = false;
      final planner = QueryTaskActionPlanner(
        inference: QueryTextInference(
          generate: (_, _) {
            requested = true;
            return const Stream.empty();
          },
        ),
      );
      await expectLater(
        planner.plan(
          context: context,
          question: 'Rename.',
          conversation: [],
          cancellation: QueryCancellation(),
          maxInputBytes: 1,
        ),
        throwsA(isA<FormatException>()),
      );
      expect(requested, isFalse);
    },
  );

  test('exploded batches respect the twelve-change cap', () async {
    await expectLater(
      plan([
        {
          'name': 'add_multiple_checklist_items',
          'arguments': {
            'items': List.generate(13, (i) => {'title': 'Feeder check $i'}),
          },
          'summary': 'Checks',
        },
      ]),
      throwsA(isA<FormatException>()),
    );
  });

  test('end time must follow start time before approval', () async {
    await expectLater(
      plan([
        {
          'name': 'create_time_entry',
          'arguments': {
            'startTime': '2026-09-13T11:00:00',
            'endTime': '2026-09-13T10:00:00',
            'summary': 'Maintenance',
          },
          'summary': 'Maintenance',
        },
      ]),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'live IDs support links, timer updates and completed-entry corrections',
    () async {
      final result = await plan([
        {
          'name': 'link_task',
          'arguments': {'targetTaskId': 'supplies', 'relation': 'blocks'},
          'summary': 'Invented target',
        },
        {
          'name': 'update_running_timer',
          'arguments': {'timerId': 'timer', 'summary': 'Current maintenance'},
          'summary': 'Current maintenance',
        },
        {
          'name': 'update_time_entry',
          'arguments': {
            'entryId': 'session',
            'summary': 'Corrected maintenance',
          },
          'summary': 'Corrected maintenance',
        },
      ]);
      expect(result.items.map((i) => i.toolName), [
        'link_task',
        'update_running_timer',
        'update_time_entry',
      ]);
      expect(result.items.first.humanSummary, contains('Order supplies'));
      expect(
        result.items.first.humanSummary,
        isNot(contains('Invented target')),
      );
      for (final item in result.items) {
        await QueryTaskActionPlanner.validateItem(item, context);
      }
      await QueryTaskActionPlanner.validateItem(
        const ChangeItem(
          toolName: 'migrate_checklist_item',
          args: {
            'id': 'feeder',
            'title': 'Inspect feeder',
            'targetTaskId': 'supplies',
          },
          humanSummary: 'Move feeder check',
        ),
        context,
      );
    },
  );

  for (final invalidTime in ['2026-02-30T10:00:00', '2026-09-13T10:00:00Z']) {
    test('rejects invalid local time $invalidTime before review', () async {
      await expectLater(
        plan([
          {
            'name': 'create_time_entry',
            'arguments': {'startTime': invalidTime, 'summary': 'Maintenance'},
            'summary': 'Maintenance',
          },
        ]),
        throwsA(isA<FormatException>()),
      );
    });
  }

  test(
    'ID-only updates and labels name the real target rather than model prose',
    () async {
      final result = await plan([
        {
          'name': 'update_checklist_items',
          'arguments': {
            'items': [
              {'id': 'feeder', 'isChecked': true},
            ],
          },
          'summary': 'Invented name',
        },
        {
          'name': 'assign_task_labels',
          'arguments': {
            'labels': [
              {'id': 'ops', 'confidence': 'very_high'},
            ],
          },
          'summary': 'Invented label',
        },
      ]);
      expect(result.items.first.humanSummary, contains('Inspect feeder'));
      expect(result.items.last.humanSummary, contains('Operations'));
      for (final item in result.items) {
        await QueryTaskActionPlanner.validateItem(item, context);
      }
    },
  );

  for (final action in [
    {'name': 'update_report', 'arguments': <String, Object?>{}},
    {
      'name': 'create_time_entry',
      'arguments': {'summary': 'Missing start'},
    },
    {
      'name': 'set_task_title',
      'arguments': {'title': 'X', 'taskId': 'foreign'},
    },
    {
      'name': 'update_checklist_items',
      'arguments': {
        'items': [
          {'id': 'foreign', 'isChecked': true},
        ],
      },
    },
    {
      'name': 'update_time_entry',
      'arguments': {'entryId': 'foreign', 'summary': 'X'},
    },
    {
      'name': 'update_running_timer',
      'arguments': {'timerId': 'foreign', 'summary': 'X'},
    },
    {
      'name': 'link_task',
      'arguments': {'targetTaskId': 'foreign', 'relation': 'blocks'},
    },
    {
      'name': 'assign_task_labels',
      'arguments': {
        'labels': [
          {'id': 'foreign'},
        ],
      },
    },
  ]) {
    test('rejects unsafe or malformed ${action['name']}', () async {
      await expectLater(
        plan([
          {...action, 'summary': 'Untrusted proposal'},
        ]),
        throwsFormatException,
      );
    });
  }

  test(
    'partial time edits fail closed when the stored range is unavailable',
    () async {
      await expectLater(
        QueryTaskActionPlanner.validate(
          'update_time_entry',
          {'entryId': 'session', 'startTime': '2026-09-13T10:30:00'},
          const QueryTaskActionContext(
            taskId: 'habitat',
            input: {},
            dependencies: [],
            timeEntryIds: {'session'},
          ),
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'partial time edits validate against the unchanged stored endpoint',
    () async {
      for (final edit in [
        {'startTime': '2026-09-13T12:00:00'},
        {'endTime': '2026-09-13T09:00:00'},
        {'startTime': '2026-09-13T11:00:00'},
      ]) {
        await expectLater(
          plan([
            {
              'name': 'update_time_entry',
              'arguments': {'entryId': 'session', ...edit},
              'summary': 'Correct session time',
            },
          ]),
          throwsFormatException,
        );
      }
      for (final edit in [
        {'startTime': '2026-09-13T09:30:00'},
        {'endTime': '2026-09-13T11:30:00'},
        {'summary': 'Corrected session description'},
      ]) {
        final result = await plan([
          {
            'name': 'update_time_entry',
            'arguments': {'entryId': 'session', ...edit},
            'summary': 'Correct session',
          },
        ]);
        expect(result.items.single.args, {'entryId': 'session', ...edit});
      }
    },
  );

  test(
    'rejects language proposals when a task language is already set',
    () async {
      for (final language in ['en', 'de']) {
        await expectLater(
          QueryTaskActionPlanner.validate(
            'set_task_language',
            {'languageCode': 'de', 'confidence': 'high'},
            QueryTaskActionContext(
              taskId: 'habitat',
              input: {
                'task': {'languageCode': language},
              },
              dependencies: const [],
            ),
          ),
          throwsFormatException,
        );
      }
      await QueryTaskActionPlanner.validate(
        'set_task_language',
        {'languageCode': 'de', 'confidence': 'high'},
        const QueryTaskActionContext(
          taskId: 'habitat',
          input: {
            'task': {'languageCode': null},
          },
          dependencies: [],
        ),
      );
    },
  );

  test(
    'keeps advice or missing-details clarification free of proposals',
    () async {
      final result = await plan([]);
      expect(result.items, isEmpty);
      expect(result.text, 'Review these changes.');
    },
  );

  test(
    'splits a follow-up and migrates only supplied checklist items',
    () async {
      final result = await plan([
        {
          'name': 'create_follow_up_task',
          'arguments': {'title': 'Feeder repair'},
          'summary': 'Feeder repair',
        },
        {
          'name': 'migrate_checklist_items',
          'arguments': {
            'targetTaskId': 'new-task',
            'items': [
              {'id': 'feeder', 'title': 'Inspect feeder'},
            ],
          },
          'summary': 'Move feeder check',
        },
      ]);
      expect(result.items.last.toolName, 'migrate_checklist_item');
      expect(
        result.items.last.args['targetTaskId'],
        result.items.first.args['_placeholderTaskId'],
      );
    },
  );

  test(
    'migration to an existing task stays independent of a new follow-up',
    () async {
      final result = await plan([
        {
          'name': 'create_follow_up_task',
          'arguments': {'title': 'Separate repair'},
          'summary': 'New repair',
        },
        {
          'name': 'migrate_checklist_items',
          'arguments': {
            'targetTaskId': 'supplies',
            'items': [
              {'id': 'feeder', 'title': 'Inspect feeder'},
            ],
          },
          'summary': 'Move to existing supplies task',
        },
      ]);
      expect(result.items.last.args['targetTaskId'], 'supplies');
      expect(result.items.first.groupId, isNotNull);
      expect(result.items.last.groupId, isNull);
    },
  );

  for (final malformedJson in [true, false]) {
    test(
      'repairs once and discards the invalid attempt: JSON=$malformedJson',
      () async {
        var calls = 0;
        final planner = QueryTaskActionPlanner(
          inference: QueryTextInference(
            generate: (_, prompt) {
              calls++;
              final input = jsonDecode(prompt) as Map;
              if (calls == 1) {
                return Stream.value(
                  malformedJson
                      ? 'provider-sensitive-invalid-output'
                      : jsonEncode({
                          'answer': 'Review.',
                          'actions': [
                            {
                              'name': 'set_task_title',
                              'arguments': {'title': 'Discard me'},
                              'summary': 'Discard',
                            },
                            {
                              'name': 'link_task',
                              'arguments': {
                                'targetTaskId': 'foreign',
                                'relation': 'blocks',
                              },
                              'summary': 'Invalid',
                            },
                          ],
                        }),
                );
              }
              expect(input['repair'], isA<String>());
              expect(
                prompt,
                isNot(contains('provider-sensitive-invalid-output')),
              );
              expect(prompt, isNot(contains('Discard me')));
              return Stream.value(
                jsonEncode({
                  'answer': 'Review the corrected proposal.',
                  'actions': [
                    {
                      'name': 'set_task_title',
                      'arguments': {'title': 'Corrected'},
                      'summary': 'Corrected',
                    },
                  ],
                }),
              );
            },
          ),
        );
        final result = await planner.plan(
          context: context,
          question: 'Rename.',
          conversation: [],
          cancellation: QueryCancellation(),
        );
        expect(calls, 2);
        expect(result.items.single.args, {'title': 'Corrected'});
      },
    );
  }

  test(
    'stops after one failed repair and never retries transport errors',
    () async {
      for (final formatError in [true, false]) {
        var calls = 0;
        final planner = QueryTaskActionPlanner(
          inference: QueryTextInference(
            generate: (_, _) {
              calls++;
              return formatError
                  ? Stream.value('invalid')
                  : Stream.error(StateError('transport'));
            },
          ),
        );
        await expectLater(
          planner.plan(
            context: context,
            question: 'Rename.',
            conversation: [],
            cancellation: QueryCancellation(),
          ),
          formatError ? throwsFormatException : throwsStateError,
        );
        expect(calls, formatError ? 2 : 1);
      }
    },
  );

  test('cancellation prevents action repair', () async {
    var calls = 0;
    final cancellation = QueryCancellation();
    final planner = QueryTaskActionPlanner(
      inference: QueryTextInference(
        generate: (_, _) {
          calls++;
          cancellation.cancel();
          return Stream.value('invalid');
        },
      ),
    );
    await expectLater(
      planner.plan(
        context: context,
        question: 'Rename.',
        conversation: [],
        cancellation: cancellation,
      ),
      throwsA(isA<QueryCancelled>()),
    );
    expect(calls, 1);
  });

  test(
    'receives fresh local clock and replaces wake-only tool guidance',
    () async {
      final planner = QueryTaskActionPlanner(
        inference: QueryTextInference(
          generate: (system, prompt) {
            final input = jsonDecode(prompt) as Map<String, dynamic>;
            expect(
              (input['currentTime'] as Map<String, dynamic>)['localDate'],
              '2026-09-13',
            );
            expect(system, contains('Only the current explicit user request'));
            final tools = input['tools'] as List;
            final time = tools.cast<Map<String, dynamic>>().singleWhere(
              (t) => t['name'] == 'create_time_entry',
            );
            expect(time['description'], contains('requested in this chat'));
            expect(
              tools.cast<Map<String, dynamic>>().any(
                (t) => t['name'] == 'update_report',
              ),
              isFalse,
            );
            return Stream.value('{"answer":"Which start time?","actions":[]}');
          },
        ),
      );
      final result = await withClock(
        Clock.fixed(DateTime.utc(2026, 9, 13)),
        () => planner.plan(
          context: context,
          question: 'Record some time',
          conversation: [],
          cancellation: QueryCancellation(),
        ),
      );
      expect(result.text, 'Which start time?');
      expect(result.items, isEmpty);
    },
  );
}
