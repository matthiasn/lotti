import 'dart:async';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_chat_providers.dart';
import 'package:lotti/features/agents/query/query_journal_crawler.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../test_data/entity_factories.dart';
import 'query_test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);
  test(
    'task query resolves the existing summary agent and live scope',
    () async {
      final bench = QueryTestBench();
      final task = testTask.copyWith(
        meta: testTask.meta.copyWith(categoryId: categoryMindfulness.id),
      );
      bench.entries[task.meta.id] = task;
      final identity = makeTestIdentity();
      final container = ProviderContainer(
        overrides: [
          querySourceAccessProvider.overrideWithValue(bench.crawler.access),
          taskAgentProvider(task.meta.id).overrideWith((ref) async => identity),
        ],
      );
      addTearDown(container.dispose);
      final target = await container.read(
        queryChatTargetProvider(
          QueryScope(kind: QueryScopeKind.task, id: task.meta.id),
        ).future,
      );
      expect(target.agent, same(identity));
      expect(target.label, task.data.title);
      expect(target.categoryId, categoryMindfulness.id);
    },
  );

  test(
    'category query reuses its deterministic identity without creating another agent',
    () async {
      final bench = QueryTestBench();
      final id = '${AgentKinds.categoryAgent}:${categoryMindfulness.id}';
      final identity = makeTestIdentity(
        id: id,
        agentId: id,
        kind: AgentKinds.categoryAgent,
      );
      final service = MockAgentService();
      when(() => service.getAgent(id)).thenAnswer((_) async => identity);
      final container = ProviderContainer(
        overrides: [
          querySourceAccessProvider.overrideWithValue(bench.crawler.access),
          agentServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
      final target = await container.read(
        queryChatTargetProvider(
          QueryScope(kind: QueryScopeKind.category, id: categoryMindfulness.id),
        ).future,
      );
      expect(target.agent?.id, id);
      expect(target.label, categoryMindfulness.name);
      verify(() => service.getAgent(id)).called(1);
      verifyNoMoreInteractions(service);
    },
  );

  test(
    'hidden home is rejected before resolving or provisioning an identity',
    () async {
      final bench = QueryTestBench()..add('task', private: true);
      final container = ProviderContainer(
        overrides: [
          querySourceAccessProvider.overrideWithValue(bench.crawler.access),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        queryChatTargetProvider(
          const QueryScope(kind: QueryScopeKind.task, id: 'task'),
        ),
        (_, _) {},
      );
      addTearDown(subscription.close);
      await expectLater(
        container.read(
          queryChatTargetProvider(
            const QueryScope(kind: QueryScopeKind.task, id: 'task'),
          ).future,
        ),
        throwsA(isA<QueryScopeUnavailable>()),
      );
    },
  );

  test(
    'history observes synced events and live journal visibility changes',
    () => withClock(Clock.fixed(DateTime(2026, 9, 11)), () async {
      final bench = QueryPersistenceBench()..add('home');
      final journal = JournalDb(inMemoryDatabase: true, background: false);
      addTearDown(bench.close);
      addTearDown(journal.close);
      const scope = QueryScope(kind: QueryScopeKind.task, id: 'home');
      const key = (agentId: 'agent', scope: scope);
      final id = await bench.store.create('agent', scope, 'Feeder');
      final container = ProviderContainer(
        overrides: [
          queryChatStoreProvider.overrideWithValue(bench.store),
          agentDatabaseProvider.overrideWithValue(bench.agentDb),
          journalDbProvider.overrideWithValue(journal),
        ],
      );
      addTearDown(container.dispose);
      final provider = queryChatDataProvider(key);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      final initial = await container.read(provider.future);
      expect(initial.projection.chats.single.title, 'Feeder');
      Future<QueryChatData> nextWhere(bool Function(QueryChatData) predicate) {
        final result = Completer<QueryChatData>();
        final sub = container.listen(provider, (_, next) {
          if (!result.isCompleted &&
              next.value != null &&
              predicate(next.value!)) {
            result.complete(next.value);
          }
        });
        return result.future.whenComplete(sub.close);
      }

      final questionArrives = nextWhere(
        (value) => value.projection.chats.single.questions.isNotEmpty,
      );
      await bench.store.ask('agent', id, 'Which feeder?');
      final withQuestion = await questionArrives;
      final question = withQuestion.projection.chats.single.questions.single;
      expect(withQuestion.access.allowsEvent(question.data), isTrue);
      final privateArrives = nextWhere(
        (value) => value.access.entries['home']!.meta.private == true,
      );
      bench.add('home', private: true);
      journal.notifyUpdates({TableUpdate(journal.journal.actualTableName)});
      final withPrivate = await privateArrives;
      expect(withPrivate.access.allowsEvent(question.data), isFalse);
      final deletionArrives = nextWhere(
        (value) => value.projection.chats.isEmpty,
      );
      await bench.store.delete('agent', id, forget: true);
      expect((await deletionArrives).projection.chats, isEmpty);
    }),
  );
}
