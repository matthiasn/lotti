import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_answer_builder.dart';
import 'package:lotti/features/agents/query/query_chat_action_service.dart';
import 'package:lotti/features/agents/query/query_journal_crawler.dart';
import 'package:lotti/features/agents/query/query_task_action_context.dart';
import 'package:lotti/features/agents/query/query_task_action_planner.dart';
import 'package:lotti/features/agents/query/query_text_inference.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import 'query_test_utils.dart';

void main() {
  late QueryPersistenceBench bench;
  late QueryChatActionService service;
  late String chat;
  late String question;
  late List<String> calls;
  var enabled = true;
  var failTime = false;
  var hideAfterFirst = false;
  var deleteAfterFirst = false;
  Completer<void>? hold;
  const items = [
    ChangeItem(
      toolName: 'add_checklist_item',
      args: {'title': 'Inspect feeder'},
      humanSummary: 'Inspect feeder',
    ),
    ChangeItem(
      toolName: 'create_time_entry',
      args: {
        'startTime': '2026-09-13T10:00:00',
        'endTime': '2026-09-13T10:30:00',
        'summary': 'Habitat maintenance',
      },
      humanSummary: 'Habitat maintenance',
    ),
  ];
  setUpAll(registerAllFallbackValues);
  setUp(() async {
    bench = QueryPersistenceBench();
    bench.entries['task'] = testTask.copyWith(
      meta: testTask.meta.copyWith(
        id: 'task',
        categoryId: null,
        private: false,
      ),
    );
    calls = [];
    enabled = true;
    failTime = false;
    hideAfterFirst = false;
    deleteAfterFirst = false;
    hold = null;
    const scope = QueryScope(kind: QueryScopeKind.task, id: 'task');
    chat = await bench.store.create('agent', scope, 'Feeder');
    final asked = await bench.store.ask(
      'agent',
      chat,
      'Add the check and log half an hour.',
    );
    question = asked.id;
    await bench.store.publish(
      'agent',
      chat,
      QueryBuiltAnswer(
        answer: QueryChatAnswer(
          questionId: question,
          text: 'Review these changes.',
          coverage: const QueryCoverage(),
          proposedActions: items,
          dependencies: (asked.data as QueryChatQuestion).dependencies,
        ),
      ),
    );
    service = QueryChatActionService(
      store: bench.store,
      enabled: () => enabled,
      labels: MockLabelsRepository(),
      readContext: (taskId, ids) async => QueryTaskActionContext(
        taskId: taskId,
        input: const {},
        dependencies: const [],
      ),
      dispatch: (name, args, taskId) async {
        expect(taskId, 'task');
        calls.add(name);
        if (hold != null) await hold!.future;
        if (deleteAfterFirst) {
          await bench.store.delete('agent', chat, forget: true);
        }
        if (hideAfterFirst) {
          final task = bench.entries['task']!;
          bench.entries['task'] = task.copyWith(
            meta: task.meta.copyWith(private: true),
          );
        }
        if (name == 'create_time_entry' && failTime) {
          return const ToolExecutionResult(
            success: false,
            output: 'Storage unavailable',
          );
        }
        return const ToolExecutionResult(success: true, output: 'Applied');
      },
    );
  });
  tearDown(() async => bench.close());

  Future<List<ToolExecutionResult>> resolve({bool approved = true}) =>
      service.resolve(
        agentId: 'agent',
        chatId: chat,
        questionId: question,
        approved: approved,
      );

  test(
    'nothing executable exists until Accept, then each change runs once',
    () async {
      expect(calls, isEmpty);
      expect(
        await bench.repository.getEntity('query-chat:$question:actions'),
        isNull,
      );
      final result = await resolve();
      expect(result.every((r) => r.success), isTrue);
      expect(calls, ['add_checklist_item', 'create_time_entry']);
      await resolve();
      expect(calls.length, 2);
    },
  );

  test(
    'Dismiss never creates a change set and cannot later be accepted',
    () async {
      await resolve(approved: false);
      await expectLater(resolve(), throwsA(isA<QueryScopeUnavailable>()));
      expect(calls, isEmpty);
      expect(
        await bench.repository.getEntity('query-chat:$question:actions'),
        isNull,
      );
      final history = (await bench.store.load('agent')).chats.single;
      expect(
        history.events
            .map((e) => e.data)
            .whereType<QueryChatActionDecision>()
            .single
            .approved,
        isFalse,
      );
    },
  );

  test('retry applies only the previously failed item', () async {
    failTime = true;
    final first = await resolve();
    expect(first.map((r) => r.success), [true, false]);
    failTime = false;
    final second = await resolve();
    expect(second.map((r) => r.success), [true]);
    expect(calls, [
      'add_checklist_item',
      'create_time_entry',
      'create_time_entry',
    ]);
  });

  for (final invalidation in ['deleted', 'private', 'disabled', 'archived']) {
    test('refuses approval after $invalidation', () async {
      if (invalidation == 'deleted') {
        await bench.store.delete('agent', chat, forget: true);
      }
      if (invalidation == 'archived') {
        await bench.store.archive('agent', chat, archived: true);
      }
      if (invalidation == 'disabled') enabled = false;
      if (invalidation == 'private') {
        final task = bench.entries['task']!;
        bench.entries['task'] = task.copyWith(
          meta: task.meta.copyWith(private: true),
        );
      }
      await expectLater(resolve(), throwsA(isA<QueryScopeUnavailable>()));
      expect(calls, isEmpty);
      expect(
        await bench.repository.getEntity('query-chat:$question:actions'),
        isNull,
      );
    });
  }

  test(
    'deleting chat during approval never revives remaining changes',
    () async {
      deleteAfterFirst = true;
      await resolve();
      expect(calls, ['add_checklist_item']);
      expect(
        await bench.repository.getEntity('query-chat:$question:actions'),
        isNull,
      );
      expect((await bench.store.load('agent')).chats, isEmpty);
    },
  );

  test('visibility is rechecked between approved changes', () async {
    hideAfterFirst = true;
    final results = await resolve();
    expect(calls, ['add_checklist_item']);
    expect(results.map((r) => r.success), [true, false]);
  });

  for (final hideCreatedTask in [false, true]) {
    test(
      'approval resolves follow-up IDs before live validation: hidden=$hideCreatedTask',
      () async {
        final home = bench.entries['task']! as Task;
        bench.entries['task'] = home.copyWith(
          data: home.data.copyWith(checklistIds: ['list']),
        );
        bench.entries['list'] = Checklist(
          meta: home.meta.copyWith(id: 'list'),
          data: const ChecklistData(
            title: 'Preflight',
            linkedChecklistItems: ['feeder'],
            linkedTasks: ['task'],
          ),
        );
        bench.entries['feeder'] = ChecklistItem(
          meta: home.meta.copyWith(id: 'feeder'),
          data: const ChecklistItemData(
            title: 'Inspect feeder',
            isChecked: false,
            linkedChecklists: ['list'],
          ),
        );
        when(bench.db.getAllLabelDefinitions).thenAnswer((_) async => []);
        final loader = QueryTaskActionContextLoader(access: bench.store.access);
        final context = await loader.load('task');
        final planned =
            await QueryTaskActionPlanner(
              inference: QueryTextInference(
                generate: (_, _) => Stream.value(
                  jsonEncode({
                    'answer': 'Review the follow-up and migration.',
                    'actions': [
                      {
                        'name': 'create_follow_up_task',
                        'arguments': {'title': 'Feeder repair'},
                        'summary': 'Create repair',
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
                    ],
                  }),
                ),
              ),
            ).plan(
              context: context,
              question: 'Create a repair task and move the feeder check.',
              conversation: [],
              cancellation: QueryCancellation(),
            );
        final asked = await bench.store.ask(
          'agent',
          chat,
          'Create a repair task and move the feeder check.',
        );
        question = asked.id;
        await bench.store.publish(
          'agent',
          chat,
          QueryBuiltAnswer(
            answer: QueryChatAnswer(
              questionId: question,
              text: planned.text,
              coverage: const QueryCoverage(),
              proposedActions: planned.items,
              dependencies: context.dependencies,
            ),
          ),
        );
        final placeholder = planned.items.first.args['_placeholderTaskId'];
        expect(planned.items.last.args['targetTaskId'], placeholder);
        service = QueryChatActionService(
          store: bench.store,
          enabled: () => true,
          labels: MockLabelsRepository(),
          readContext: (taskId, ids) => loader.load(taskId, relatedIds: ids),
          dispatch: (name, args, taskId) async {
            calls.add(name);
            if (name == 'create_follow_up_task') {
              // Model the journal mutation/ID returned by FollowUpTaskHandler.
              bench.entries['created-task'] = home.copyWith(
                meta: home.meta.copyWith(
                  id: 'created-task',
                  private: hideCreatedTask,
                ),
              );
              bench.link('task', 'created-task');
              return const ToolExecutionResult(
                success: true,
                output: 'Created',
                mutatedEntityId: 'created-task',
              );
            }
            expect(args['targetTaskId'], 'created-task');
            expect(args['targetTaskId'], isNot(placeholder));
            expect(args['id'], 'feeder');
            return const ToolExecutionResult(success: true, output: 'Migrated');
          },
        );
        expect(calls, isEmpty);
        final results = await resolve();
        expect(results.map((r) => r.success), [true, !hideCreatedTask]);
        expect(calls, [
          'create_follow_up_task',
          if (!hideCreatedTask) 'migrate_checklist_item',
        ]);
      },
    );
  }

  test('repeated Accept while applying does not dispatch twice', () async {
    hold = Completer<void>();
    final first = resolve();
    // A second request meets the service guard before any asynchronous read.
    expect(await resolve(), isEmpty);
    hold!.complete();
    await first;
    expect(calls, ['add_checklist_item', 'create_time_entry']);
  });
}
