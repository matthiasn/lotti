import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/goals/service/goal_assessment_service.dart';
import 'package:lotti/widgets/day_indicators/day_mark.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  test(
    'stores a spec-bound assessment as an append-only action payload',
    () async {
      final syncService = _TransactionalSyncService();
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
          rating: DayVerdict.mixed,
          dimensionRatings: const {
            'reading': DayVerdict.met,
            'sleep': DayVerdict.missed,
          },
          note: 'Good reading, short sleep.',
          provenance: DayVerdictProvenance.suggestedAndAccepted,
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
      expect(syncService.transactionCalls, 1);
    },
  );

  test(
    'an improving verdict stays readable by clients that predate it',
    () async {
      final syncService = _TransactionalSyncService();
      final upserts = <AgentDomainEntity>[];
      when(() => syncService.upsertEntity(any())).thenAnswer((
        invocation,
      ) async {
        upserts.add(invocation.positionalArguments.first as AgentDomainEntity);
      });
      final service = GoalAssessmentService(syncService);

      await withClock(
        Clock.fixed(DateTime(2026, 8, 12, 20, 15)),
        () => service.record(
          agentId: 'goal-1',
          day: DateTime.utc(2026, 8, 11),
          specVersionId: 'goal-1:spec-v4',
          rating: DayVerdict.improving,
          dimensionRatings: const {
            'reading': DayVerdict.improving,
            'sleep': DayVerdict.met,
          },
          note: 'Short sleep but trending up.',
        ),
      );

      final content = (upserts.first as AgentMessagePayloadEntity).content;
      // A client shipped before `improving` existed decodes by searching its
      // own three-value enum and DISCARDS the whole record when nothing
      // matches — note and per-dimension verdicts included. So the legacy key
      // carries the nearest verdict it can read...
      expect(content['rating'], 'mixed');
      expect(content['dimensionRatings'], {
        'reading': 'mixed',
        'sleep': 'met',
      });
      // ...and the real one rides alongside for readers that understand it.
      expect(content['ratingV2'], 'improving');
      expect(content['dimensionRatingsV2'], {
        'reading': 'improving',
        'sleep': 'met',
      });
    },
  );

  test('a verdict every client understands carries no second copy', () async {
    final syncService = _TransactionalSyncService();
    final upserts = <AgentDomainEntity>[];
    when(() => syncService.upsertEntity(any())).thenAnswer((
      invocation,
    ) async {
      upserts.add(invocation.positionalArguments.first as AgentDomainEntity);
    });
    final service = GoalAssessmentService(syncService);

    await withClock(
      Clock.fixed(DateTime(2026, 8, 12, 20, 15)),
      () => service.record(
        agentId: 'goal-1',
        day: DateTime.utc(2026, 8, 11),
        specVersionId: 'goal-1:spec-v4',
        rating: DayVerdict.met,
        dimensionRatings: const {'reading': DayVerdict.met},
      ),
    );

    final content = (upserts.first as AgentMessagePayloadEntity).content;
    expect(content['rating'], 'met');
    expect(content.containsKey('ratingV2'), isFalse);
    expect(content.containsKey('dimensionRatingsV2'), isFalse);
  });
}

class _TransactionalSyncService extends MockAgentSyncService {
  int transactionCalls = 0;

  @override
  Future<T> runInTransaction<T>(Future<T> Function() action) {
    transactionCalls++;
    return action();
  }
}
