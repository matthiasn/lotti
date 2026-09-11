import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_chat_projection.dart';

void main() {
  const scope = QueryScope(kind: QueryScopeKind.task, id: 'penguin-task');
  AgentQueryChatEventEntity event(
    int n,
    QueryChatEventData data, {
    String chat = 'chat',
  }) => AgentQueryChatEventEntity(
    id: '$n',
    agentId: 'habitat-watcher',
    chatId: chat,
    data: data,
    createdAt: DateTime(2026, 7, 17, 10, n),
    vectorClock: null,
  );

  final created = event(
    0,
    const QueryChatEventData.created(scope: scope, title: 'Feeder'),
  );
  final question = event(1, const QueryChatEventData.question(text: 'Why?'));
  final answer = event(
    2,
    const QueryChatEventData.answer(
      questionId: '1',
      text: 'Keep the feeder.',
      coverage: QueryCoverage(checked: 1),
    ),
  );
  final memory = event(
    3,
    const QueryChatEventData.memory(
      questionId: '1',
      text: 'Keep the feeder.',
    ),
  );

  test('arrival order does not change history, rename or read state', () {
    final rows = [
      created,
      question,
      answer,
      event(4, const QueryChatEventData.renamed(title: 'Launch decision')),
      event(5, const QueryChatEventData.read(throughEventId: '2')),
    ];
    for (final order in [
      rows,
      rows.reversed,
      [rows[4], ...rows.take(4)],
    ]) {
      final chat = QueryChatProjection(order).chats.single;
      expect(chat.title, 'Launch decision');
      expect(chat.questions.single.id, '1');
      expect(chat.answerFor('1'), answer);
      expect(chat.lastActivity, answer.createdAt);
      expect(chat.unread, isFalse);
    }
  });

  test('delete wins over a late answer and only forget retracts learning', () {
    for (final forget in [false, true]) {
      final projection = QueryChatProjection([
        created,
        question,
        event(2, QueryChatEventData.deleted(forget: forget)),
        answer.copyWith(createdAt: DateTime(2026, 7, 17, 11)),
        memory,
        event(5, const QueryChatEventData.archived(archived: false)),
      ]);
      expect(projection.chats, isEmpty);
      expect(projection.memories, forget ? isEmpty : [memory]);
    }
  });

  test('archive restores without losing history or learning', () {
    final rows = [
      created,
      question,
      answer,
      memory,
      event(4, const QueryChatEventData.archived(archived: true)),
    ];
    expect(QueryChatProjection(rows).chats.single.archived, isTrue);
    rows.add(event(5, const QueryChatEventData.archived(archived: false)));
    final restored = QueryChatProjection(rows);
    expect(restored.chats.single.archived, isFalse);
    expect(restored.chats.single.answerFor('1'), answer);
    expect(restored.memories, [memory]);
  });

  test(
    'forgetting a conclusion removes learning derived from it in other chats',
    () {
      final derived = event(
        4,
        QueryChatEventData.memory(
          questionId: 'other-question',
          text: 'Use that feeder for release.',
          recalledMemoryIds: [memory.id],
        ),
        chat: 'other',
      );
      final rows = [created, question, answer, memory, derived];
      expect(QueryChatProjection(rows).memories.length, 2);
      expect(
        QueryChatProjection([
          ...rows,
          event(5, const QueryChatEventData.deleted(forget: true)),
        ]).memories,
        isEmpty,
      );
    },
  );

  test('a title written with private entries visible remains private', () {
    final projection = QueryChatProjection([
      created,
      event(
        2,
        const QueryChatEventData.renamed(
          title: 'Private decision',
          private: true,
        ),
      ),
    ]);
    expect(projection.chats.single.private, isTrue);
    expect(projection.chats.single.title, 'Private decision');
  });

  test('concurrent chats keep their turns and unread state separate', () {
    final projection = QueryChatProjection([
      created,
      question,
      answer,
      created.copyWith(id: 'other-created', chatId: 'other'),
      event(
        4,
        const QueryChatEventData.question(text: 'Roll call?'),
        chat: 'other',
      ),
    ]);
    final first = projection.chats.singleWhere((c) => c.id == 'chat');
    final other = projection.chats.singleWhere((c) => c.id == 'other');
    expect(first.unread, isTrue);
    expect(other.unread, isFalse);
    expect(other.answerFor('1'), isNull);
    expect(
      (other.questions.single.data as QueryChatQuestion).text,
      'Roll call?',
    );
  });

  test('a later stale read marker cannot make a read reply unread again', () {
    final rows = [
      created,
      question,
      answer,
      event(3, const QueryChatEventData.read(throughEventId: '2')),
      event(4, const QueryChatEventData.read(throughEventId: '1')),
    ];
    expect(QueryChatProjection(rows).chats.single.unread, isFalse);
    expect(QueryChatProjection(rows.reversed).chats.single.unread, isFalse);
  });

  test('failure status belongs to its unanswered question', () {
    final history = QueryChatProjection([
      created,
      question,
      event(2, const QueryChatEventData.cancelled(questionId: 'other')),
      event(3, const QueryChatEventData.failed(questionId: '1')),
    ]).chats.single;
    expect(history.failed('1'), isTrue);
    expect(history.failed('other'), isTrue);
    expect(history.failed('unrelated'), isFalse);
    expect(
      QueryChatProjection([...history.events, answer]).chats.single.failed('1'),
      isFalse,
    );
  });
}
