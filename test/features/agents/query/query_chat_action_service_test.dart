import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_answer_builder.dart';
import 'package:lotti/features/agents/query/query_chat_action_service.dart';
import 'package:lotti/features/agents/query/query_journal_crawler.dart';
import 'package:lotti/features/agents/query/query_task_action_planner.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';

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
