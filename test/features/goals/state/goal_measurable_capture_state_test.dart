import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/goals/service/goal_measurable_capture_service.dart';
import 'package:lotti/features/goals/state/goal_measurable_capture_state.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  test('the newest decision for a source message wins', () async {
    final repository = MockAgentRepository();
    final older = DateTime(2026, 8, 11, 9);
    final newer = DateTime(2026, 8, 11, 10);
    AgentMessageEntity action({
      required String id,
      required String payloadId,
      required String toolName,
      required DateTime createdAt,
    }) =>
        AgentDomainEntity.agentMessage(
              id: id,
              agentId: 'goal-1',
              threadId: 'thread-1',
              kind: AgentMessageKind.action,
              createdAt: createdAt,
              vectorClock: null,
              contentEntryId: payloadId,
              metadata: AgentMessageMetadata(toolName: toolName),
            )
            as AgentMessageEntity;
    final recorded = action(
      id: 'recorded',
      payloadId: 'payload-recorded',
      toolName: GoalMeasurableCaptureToolNames.recorded,
      createdAt: older,
    );
    final dismissed = action(
      id: 'dismissed',
      payloadId: 'payload-dismissed',
      toolName: GoalMeasurableCaptureToolNames.dismissed,
      createdAt: newer,
    );
    when(
      () => repository.getEntitiesByAgentId(
        'goal-1',
        type: AgentEntityTypes.agentMessage,
      ),
    ).thenAnswer((_) async => [dismissed, recorded]);
    when(() => repository.getEntitiesByIds(any())).thenAnswer(
      (_) async => {
        for (final id in ['payload-dismissed', 'payload-recorded'])
          id: AgentDomainEntity.agentMessagePayload(
            id: id,
            agentId: 'goal-1',
            createdAt: id == 'payload-dismissed' ? newer : older,
            vectorClock: null,
            content: {
              'sourceMessageId': 'source-1',
              if (id == 'payload-recorded') 'entryIds': ['measurement-1'],
            },
          ),
      },
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

    final decisions = await container.read(
      goalMeasurableCaptureDecisionsProvider('goal-1').future,
    );

    expect(decisions['source-1']?.recorded, isFalse);
    expect(decisions['source-1']?.recordedAt, newer);
  });
}
