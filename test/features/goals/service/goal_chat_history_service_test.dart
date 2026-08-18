import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/ai/service/text_chunker.dart';
import 'package:lotti/features/goals/service/goal_chat_history_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  late MockAgentRepository repository;
  late GoalChatHistoryService service;
  late Map<String, AgentDomainEntity> entities;

  AgentMessageEntity message({
    required String id,
    required AgentMessageKind kind,
    required int minute,
    String? operationId,
  }) =>
      AgentDomainEntity.agentMessage(
            id: id,
            agentId: 'goal-1',
            threadId: id,
            kind: kind,
            createdAt: DateTime.utc(2026, 8, 18, 12, minute),
            vectorClock: null,
            contentEntryId: '$id:payload',
            metadata: AgentMessageMetadata(
              toolName: kind == AgentMessageKind.action
                  ? AgentConversationToolNames.replyToUser
                  : null,
              operationId: operationId,
            ),
          )
          as AgentMessageEntity;

  void stubHistory({
    required List<AgentMessageEntity> users,
    required List<AgentMessageEntity> replies,
    Map<String, String> texts = const {},
  }) {
    when(
      () => repository.getMessagesByKind(
        'goal-1',
        AgentMessageKind.user,
        limit: 50,
      ),
    ).thenAnswer((_) async => users);
    when(
      () => repository.getMessagesByKind(
        'goal-1',
        AgentMessageKind.action,
        limit: 50,
      ),
    ).thenAnswer((_) async => replies);
    entities = {
      for (final entry in texts.entries)
        '${entry.key}:payload': AgentDomainEntity.agentMessagePayload(
          id: '${entry.key}:payload',
          agentId: 'goal-1',
          createdAt: DateTime.utc(2026, 8, 18),
          vectorClock: null,
          content: {'text': entry.value},
        ),
    };
    when(() => repository.getEntity(any())).thenAnswer(
      (invocation) async =>
          entities[invocation.positionalArguments.first as String],
    );
  }

  setUp(() {
    repository = MockAgentRepository();
    service = GoalChatHistoryService(repository);
  });

  test(
    'finds only the durable turn lacking a linked or legacy reply',
    () async {
      final first = message(
        id: 'user-1',
        kind: AgentMessageKind.user,
        minute: 1,
      );
      final legacyReply = message(
        id: 'reply-1',
        kind: AgentMessageKind.action,
        minute: 2,
      );
      final second = message(
        id: 'user-2',
        kind: AgentMessageKind.user,
        minute: 3,
      );
      final linkedReply = message(
        id: 'reply-2',
        kind: AgentMessageKind.action,
        minute: 4,
        operationId: second.id,
      );
      final orphan = message(
        id: 'user-3',
        kind: AgentMessageKind.user,
        minute: 5,
      );
      stubHistory(
        users: [orphan, second, first],
        replies: [linkedReply, legacyReply],
      );

      expect(await service.oldestPendingMessageId('goal-1'), orphan.id);
    },
  );

  test('renders a role-correct bounded tail before the pending turn', () async {
    final first = message(
      id: 'user-1',
      kind: AgentMessageKind.user,
      minute: 1,
    );
    final reply = message(
      id: 'reply-1',
      kind: AgentMessageKind.action,
      minute: 2,
      operationId: first.id,
    );
    final pending = message(
      id: 'user-2',
      kind: AgentMessageKind.user,
      minute: 3,
    );
    stubHistory(
      users: [pending, first],
      replies: [reply],
      texts: {
        first.id: 'Should I move the walk?',
        reply.id: 'Which day works better?',
        pending.id: 'Friday.',
      },
    );

    final history = await service.recentDialogue(
      agentId: 'goal-1',
      before: pending,
    );

    expect(
      history.map((entry) => (entry.role, entry.text)),
      [
        (GoalChatHistoryRole.user, 'Should I move the walk?'),
        (GoalChatHistoryRole.assistant, 'Which day works better?'),
      ],
    );
    expect(
      history.map(GoalChatHistoryService.toJson),
      everyElement(containsPair('createdAt', isA<String>())),
    );
  });

  test('token pressure keeps the newest exchange context', () async {
    final old = message(
      id: 'user-old',
      kind: AgentMessageKind.user,
      minute: 1,
    );
    final recent = message(
      id: 'reply-recent',
      kind: AgentMessageKind.action,
      minute: 2,
      operationId: old.id,
    );
    final pending = message(
      id: 'user-pending',
      kind: AgentMessageKind.user,
      minute: 3,
    );
    stubHistory(
      users: [pending, old],
      replies: [recent],
      texts: {
        old.id: List.filled(80, 'older').join(' '),
        recent.id: 'What did you mean?',
      },
    );

    final history = await service.recentDialogue(
      agentId: 'goal-1',
      before: pending,
      tokenBudget: 40,
    );

    expect(history.map((entry) => entry.id), [recent.id]);
  });

  test(
    'one oversized newest reply is clipped inside the total budget',
    () async {
      final reply = message(
        id: 'reply-huge',
        kind: AgentMessageKind.action,
        minute: 1,
      );
      final pending = message(
        id: 'user-pending',
        kind: AgentMessageKind.user,
        minute: 2,
      );
      stubHistory(
        users: [pending],
        replies: [reply],
        texts: {reply.id: List.filled(2000, '界').join()},
      );

      final history = await service.recentDialogue(
        agentId: 'goal-1',
        before: pending,
        tokenBudget: 100,
      );
      final encoded = jsonEncode(
        history.map(GoalChatHistoryService.toJson).toList(),
      );
      final estimated = TextChunker.estimateTokens(encoded);
      final byteEstimate = (utf8.encode(encoded).length / 4).ceil();

      expect(history, hasLength(1));
      expect(history.single.text, endsWith('…'));
      expect(
        estimated > byteEstimate ? estimated : byteEstimate,
        lessThanOrEqualTo(100),
      );
    },
  );
}
