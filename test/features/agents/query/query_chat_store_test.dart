import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_answer_builder.dart';
import 'package:lotti/features/agents/query/query_chat_store.dart';
import 'package:lotti/features/agents/query/query_journal_crawler.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import 'query_test_utils.dart';

void main() {
  late AgentRepository repository;
  late QueryPersistenceBench bench;
  late QueryChatStore store;
  late MockOutboxService outbox;
  const scope = QueryScope(kind: QueryScopeKind.task, id: 'task');
  final now = DateTime(2026, 9, 10, 12);

  setUpAll(registerAllFallbackValues);
  setUp(() {
    bench = QueryPersistenceBench()..add('task');
    repository = bench.repository;
    outbox = bench.outbox;
    store = bench.store;
  });
  tearDown(() async {
    await bench.close();
  });

  QueryBuiltAnswer result(AgentQueryChatEventEntity question) =>
      QueryBuiltAnswer(
        answer: QueryChatAnswer(
          questionId: question.id,
          text: 'Use the feeder.',
          coverage: const QueryCoverage(checked: 1),
          dependencies: (question.data as QueryChatQuestion).dependencies,
        ),
        memory: QueryChatMemory(
          questionId: question.id,
          text: 'Feeder selected.',
          dependencies: (question.data as QueryChatQuestion).dependencies,
        ),
      );

  for (final change in ['moved', 'deleted', 'memory']) {
    test(
      'summary publication rejects changed owners or memory: $change',
      () async {
        await withClock(Clock.fixed(now), () async {
          final owner = testTask.copyWith(
            meta: testTask.meta.copyWith(
              id: 'other',
              categoryId: null,
              private: false,
            ),
          );
          bench.entries['other'] = owner;
          final chat = await store.create('agent', scope, 'Feeder');
          final question = await store.ask(
            'agent',
            chat,
            'What did calibration find?',
          );
          final current = await bench.crawler.access.load(['other']);
          final built = result(question);
          final summary = QueryBuiltAnswer(
            answer: built.answer.copyWith(
              summaryBased: true,
              dependencies: [
                ...built.answer.dependencies,
                current.reference(owner),
              ],
            ),
            memory: change == 'memory' ? built.memory : null,
          );
          if (change != 'memory') {
            bench.entries['other'] = owner.copyWith(
              meta: change == 'moved'
                  ? owner.meta.copyWith(categoryId: bench.categories.first.id)
                  : owner.meta.copyWith(deletedAt: now),
            );
          }
          await expectLater(
            store.publish('agent', chat, summary),
            change == 'memory'
                ? throwsFormatException
                : throwsA(isA<QueryScopeUnavailable>()),
          );
          expect(
            (await store.load('agent')).chats.single.answerFor(question.id),
            isNull,
          );
        });
      },
    );
  }

  test(
    'separate synced conversations survive rename, archive and reopening',
    () => withClock(Clock.fixed(now), () async {
      final first = await store.create('agent', scope, 'Feeder');
      final second = await store.create('agent', scope, 'Release');
      final question = await store.ask('agent', first, 'Which feeder?');
      expect(await store.publish('agent', first, result(question)), isTrue);
      expect(await store.publish('agent', first, result(question)), isFalse);
      await store.rename('agent', first, 'Chosen feeder');
      await store.archive('agent', first, archived: true);
      final reloaded = QueryChatStore(sync: store.sync, access: store.access);
      final chats = (await reloaded.load('agent')).chats;
      expect(chats.singleWhere((c) => c.id == first).title, 'Chosen feeder');
      expect(chats.singleWhere((c) => c.id == first).archived, isTrue);
      expect(chats.singleWhere((c) => c.id == second).questions, isEmpty);
      await store.archive('agent', first, archived: false);
      await store.markRead('agent', first, '${question.id}:answer');
      expect(
        (await store.load(
          'agent',
        )).chats.singleWhere((c) => c.id == first).unread,
        isFalse,
      );
      final writes = verify(() => outbox.enqueueMessage(captureAny())).captured;
      expect(writes.length, greaterThanOrEqualTo(8));
      expect(
        await repository.getEntitiesByAgentId(
          'agent',
          type: AgentEntityTypes.agentMessage,
        ),
        isEmpty,
      );
    }),
  );

  for (final forget in [false, true]) {
    test(
      'deletion forget=$forget blocks late replies and preserves only chosen memory',
      () => withClock(Clock.fixed(now), () async {
        final chat = await store.create('agent', scope, 'Feeder');
        final first = await store.ask('agent', chat, 'First?');
        await store.publish('agent', chat, result(first));
        final pending = await store.ask('agent', chat, 'Next?');
        await store.delete('agent', chat, forget: forget);
        expect(await store.publish('agent', chat, result(pending)), isFalse);
        await store.fail('agent', chat, pending.id);
        final projection = await store.load('agent');
        expect(projection.chats, isEmpty);
        expect(
          projection.memories.map((e) => e.id),
          forget ? isEmpty : ['${first.id}:memory'],
        );
        expect(bench.entries.keys, ['task']);
        expect(
          () => store.rename('agent', chat, 'Restored'),
          throwsA(isA<QueryScopeUnavailable>()),
        );
      }),
    );
  }

  test(
    'last publication gate rejects a source that became private',
    () => withClock(Clock.fixed(now), () async {
      final chat = await store.create('agent', scope, 'Feeder');
      final question = await store.ask('agent', chat, 'Which feeder?');
      bench.add('task', private: true);
      await expectLater(
        store.publish('agent', chat, result(question)),
        throwsA(isA<QueryScopeUnavailable>()),
      );
      expect((await store.load('agent')).memories, isEmpty);
      expect(
        (await store.load('agent')).chats.single.answerFor(question.id),
        isNull,
      );
    }),
  );

  test(
    'publication rejects an answer that drops question provenance',
    () => withClock(Clock.fixed(now), () async {
      bench.add('meeting');
      final chat = await store.create('agent', scope, 'Feeder');
      final first = await store.ask('agent', chat, 'What did we decide?');
      final firstResult = result(first);
      final access = await bench.crawler.access.load(['task', 'meeting']);
      await store.publish(
        'agent',
        chat,
        QueryBuiltAnswer(
          answer: firstResult.answer.copyWith(
            dependencies: [
              ...firstResult.answer.dependencies,
              access.reference(bench.entries['meeting']!),
            ],
          ),
        ),
      );
      final next = await store.ask('agent', chat, 'Why?');
      final full = result(next);
      expect(full.answer.dependencies.map((source) => source.id), [
        'task',
        'meeting',
      ]);
      final incomplete = QueryBuiltAnswer(
        answer: full.answer.copyWith(
          dependencies: [full.answer.dependencies.first],
        ),
      );
      await expectLater(
        store.publish('agent', chat, incomplete),
        throwsA(isA<QueryScopeUnavailable>()),
      );
      expect(
        (await store.load('agent')).chats.single.answerFor(next.id),
        isNull,
      );
      expect(await store.publish('agent', chat, full), isTrue);
      expect(
        (await store.load('agent')).chats.single.answerFor(next.id),
        isNotNull,
      );
    }),
  );

  test(
    'private-authored titles and questions cannot become public after a visibility toggle',
    () => withClock(Clock.fixed(now), () async {
      final chat = await store.create('agent', scope, 'Public chat');
      // The composer/modal captured private provenance before its asynchronous
      // write. The latest visibility read now has private entries hidden.
      await expectLater(
        store.create('agent', scope, 'Private title', private: true),
        throwsA(isA<QueryScopeUnavailable>()),
      );
      await expectLater(
        store.rename('agent', chat, 'Private rename', private: true),
        throwsA(isA<QueryScopeUnavailable>()),
      );
      await expectLater(
        store.ask('agent', chat, 'Private question', private: true),
        throwsA(isA<QueryScopeUnavailable>()),
      );
      final projection = await store.load('agent');
      expect(projection.chats.single.title, 'Public chat');
      expect(projection.chats.single.questions, isEmpty);
    }),
  );

  test(
    'failed and cancelled attempts remain retryable until an answer arrives',
    () => withClock(Clock.fixed(now), () async {
      final chat = await store.create('agent', scope, 'Feeder');
      final question = await store.ask('agent', chat, 'Which feeder?');
      expect(
        (await store.load('agent')).chats.single.failed(question.id),
        isFalse,
      );
      await store.fail('agent', chat, question.id);
      expect(
        (await store.load('agent')).chats.single.failed(question.id),
        isTrue,
      );
      await store.fail('agent', chat, question.id, cancelled: true);
      final cancelled = (await store.load('agent')).chats.single;
      expect(
        cancelled.events.last.data,
        QueryChatEventData.cancelled(questionId: question.id),
      );
      await store.publish('agent', chat, result(question));
      final answered = (await store.load('agent')).chats.single;
      expect(answered.failed(question.id), isFalse);
      await store.fail('agent', chat, question.id);
      expect((await store.load('agent')).chats.single.events, answered.events);
    }),
  );

  test(
    'invalid titles and archived or blank questions cannot create events',
    () => withClock(Clock.fixed(now), () async {
      for (final title in ['', ' ' * 5, 'x' * 121]) {
        await expectLater(
          store.create('agent', scope, title),
          throwsArgumentError,
        );
      }
      expect((await store.load('agent')).chats, isEmpty);
      final chat = await store.create('agent', scope, 'Feeder');
      await expectLater(store.ask('agent', chat, '  '), throwsArgumentError);
      await store.archive('agent', chat, archived: true);
      await expectLater(
        store.ask('agent', chat, 'Question?'),
        throwsArgumentError,
      );
      expect((await store.load('agent')).chats.single.questions, isEmpty);
      final category = bench.categories.single;
      final categoryChat = await store.create(
        'category-agent',
        QueryScope(kind: QueryScopeKind.category, id: category.id),
        'Category question',
      );
      expect(
        (await store.load('category-agent')).chats.single.id,
        categoryChat,
      );
      bench.categories[0] = category.copyWith(private: true);
      await expectLater(
        store.ask('category-agent', categoryChat, 'Hidden?'),
        throwsA(isA<QueryScopeUnavailable>()),
      );
    }),
  );
}
