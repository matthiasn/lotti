import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/goals/model/goal_assessment.dart';
import 'package:lotti/features/goals/service/goal_assessment_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  test(
    'stores a spec-bound assessment as an append-only action payload',
    () async {
      final syncService = MockAgentSyncService();
      final upserts = <AgentDomainEntity>[];
      when(() => syncService.upsertEntity(any())).thenAnswer((
        invocation,
      ) async {
        upserts.add(invocation.positionalArguments.first as AgentDomainEntity);
      });
      final service = GoalAssessmentService(syncService);
      final now = DateTime(2026, 8, 12, 20, 15);

      final id = await withClock(
        Clock.fixed(now),
        () => service.record(
          agentId: 'goal-1',
          day: DateTime.utc(2026, 8, 11),
          specVersionId: 'goal-1:spec-v4',
          rating: GoalAssessmentRating.mixed,
          dimensionRatings: const {
            'reading': GoalAssessmentRating.met,
            'sleep': GoalAssessmentRating.missed,
          },
          note: 'Good reading, short sleep.',
          provenance: GoalAssessmentProvenance.suggestedAndAccepted,
          suggestedBy: 'Juno',
        ),
      );

      expect(upserts, hasLength(2));
      final payload = upserts.first as AgentMessagePayloadEntity;
      final action = upserts.last as AgentMessageEntity;
      expect(payload.content['recordId'], id);
      expect(
        payload.content['day'],
        DateTime.utc(2026, 8, 11).toIso8601String(),
      );
      expect(payload.content['specVersionId'], 'goal-1:spec-v4');
      expect(payload.content['rating'], 'mixed');
      expect(payload.content['dimensionRatings'], {
        'reading': 'met',
        'sleep': 'missed',
      });
      expect(payload.content['provenance'], 'suggestedAndAccepted');
      expect(payload.content['suggestedBy'], 'Juno');
      expect(action.id, id);
      expect(action.contentEntryId, payload.id);
      expect(action.metadata.toolName, GoalAssessmentToolNames.record);
      expect(action.createdAt, now);
    },
  );
}
