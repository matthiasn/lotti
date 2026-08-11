import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  test('projects only durable user turns and reply_to_user actions while '
      'hiding legacy FACTS rows', () async {
    final repository = MockAgentRepository();
    final now = DateTime(2026, 8, 11, 9);
    AgentMessageEntity message({
      required String id,
      required AgentMessageKind kind,
      required String payloadId,
      String? toolName,
      String? runKey,
    }) =>
        AgentDomainEntity.agentMessage(
              id: id,
              agentId: 'goal-1',
              threadId: 'thread',
              kind: kind,
              createdAt: now.add(Duration(minutes: id == 'user' ? 0 : 1)),
              vectorClock: null,
              contentEntryId: payloadId,
              metadata: AgentMessageMetadata(
                toolName: toolName,
                runKey: runKey,
              ),
            )
            as AgentMessageEntity;

    final user = message(
      id: 'user',
      kind: AgentMessageKind.user,
      payloadId: 'payload-user',
    );
    final reply = message(
      id: 'reply',
      kind: AgentMessageKind.action,
      payloadId: 'payload-reply',
      toolName: AgentConversationToolNames.replyToUser,
    );
    final privateThought = message(
      id: 'thought',
      kind: AgentMessageKind.thought,
      payloadId: 'payload-thought',
    );
    final legacyFacts = message(
      id: 'legacy-facts',
      kind: AgentMessageKind.user,
      payloadId: 'payload-facts',
      runKey: 'automatic-run',
    );
    when(
      () => repository.getEntitiesByAgentId(
        'goal-1',
        type: AgentEntityTypes.agentMessage,
        limit: 50,
      ),
    ).thenAnswer((_) async => [reply, legacyFacts, privateThought, user]);
    when(() => repository.getEntity('payload-user')).thenAnswer(
      (_) async => AgentDomainEntity.agentMessagePayload(
        id: 'payload-user',
        agentId: 'goal-1',
        createdAt: now,
        vectorClock: null,
        content: const {'text': 'I checked in.'},
      ),
    );
    when(() => repository.getEntity('payload-reply')).thenAnswer(
      (_) async => AgentDomainEntity.agentMessagePayload(
        id: 'payload-reply',
        agentId: 'goal-1',
        createdAt: now,
        vectorClock: null,
        content: const {'text': 'Noted.'},
      ),
    );
    final container = ProviderContainer(
      overrides: [
        agentRepositoryProvider.overrideWithValue(repository),
        agentUpdateStreamProvider(
          'goal-1',
        ).overrideWith((ref) => const Stream.empty()),
      ],
    );
    addTearDown(container.dispose);

    final projection = await container.read(
      agentChatProjectionProvider('goal-1').future,
    );

    expect(projection.map((message) => message.text), [
      'I checked in.',
      'Noted.',
    ]);
    expect(projection.map((message) => message.role), [
      AgentChatRole.user,
      AgentChatRole.agent,
    ]);
    verifyNever(() => repository.getEntity('payload-thought'));
    verifyNever(() => repository.getEntity('payload-facts'));
  });
}
