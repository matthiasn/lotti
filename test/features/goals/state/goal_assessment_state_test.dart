import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/goals/model/goal_assessment.dart';
import 'package:lotti/features/goals/service/goal_assessment_service.dart';
import 'package:lotti/features/goals/state/goal_assessment_state.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  test(
    'loads assessment payloads in one batch and orders newest day first',
    () async {
      final repository = MockAgentRepository();
      final createdAt = DateTime(2026, 8, 12, 9);
      AgentMessageEntity action(String id) =>
          AgentDomainEntity.agentMessage(
                id: 'action-$id',
                agentId: 'goal-1',
                threadId: id,
                kind: AgentMessageKind.action,
                createdAt: createdAt,
                vectorClock: null,
                contentEntryId: 'payload-$id',
                metadata: const AgentMessageMetadata(
                  toolName: GoalAssessmentToolNames.record,
                ),
              )
              as AgentMessageEntity;
      when(
        () => repository.getEntitiesByAgentId(
          'goal-1',
          type: AgentEntityTypes.agentMessage,
        ),
      ).thenAnswer((_) async => [action('older'), action('newer')]);
      when(() => repository.getEntitiesByIds(any())).thenAnswer(
        (_) async => {
          'payload-older': AgentDomainEntity.agentMessagePayload(
            id: 'payload-older',
            agentId: 'goal-1',
            createdAt: createdAt,
            vectorClock: null,
            content: const {
              'recordId': 'older',
              'day': '2026-08-10T00:00:00.000Z',
              'specVersionId': 'spec-v1',
              'rating': 'mixed',
            },
          ),
          'payload-newer': AgentDomainEntity.agentMessagePayload(
            id: 'payload-newer',
            agentId: 'goal-1',
            createdAt: createdAt,
            vectorClock: null,
            content: const {
              'recordId': 'newer',
              'day': '2026-08-11T00:00:00.000Z',
              'specVersionId': 'spec-v1',
              'rating': 'met',
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

      final records = await container.read(
        goalAssessmentHistoryProvider('goal-1').future,
      );

      expect(records.map((record) => record.id), ['newer', 'older']);
      expect(records.first.rating, GoalAssessmentRating.met);
      verify(() => repository.getEntitiesByIds(any())).called(1);
      verifyNever(() => repository.getEntity(any()));
    },
  );
}
