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

  test(
    'a rating a newer build wrote degrades to mixed instead of deleting the '
    'whole reflection',
    () async {
      final repository = MockAgentRepository();
      when(
        () => repository.getEntitiesByAgentId(
          'goal-1',
          type: AgentEntityTypes.agentMessage,
        ),
      ).thenAnswer(
        (_) async => [
          AgentDomainEntity.agentMessage(
                id: 'action-future',
                agentId: 'goal-1',
                threadId: 'future',
                kind: AgentMessageKind.action,
                createdAt: DateTime(2026, 8, 12, 9),
                vectorClock: null,
                contentEntryId: 'payload-future',
                metadata: const AgentMessageMetadata(
                  toolName: GoalAssessmentToolNames.record,
                ),
              )
              as AgentMessageEntity,
        ],
      );
      when(() => repository.getEntitiesByIds(any())).thenAnswer(
        (_) async => {
          'payload-future': AgentDomainEntity.agentMessagePayload(
            id: 'payload-future',
            agentId: 'goal-1',
            createdAt: DateTime(2026, 8, 12, 9),
            vectorClock: null,
            content: {
              'recordId': 'future',
              'day': DateTime.utc(2026, 8, 12).toIso8601String(),
              'specVersionId': 'spec-1',
              // A verdict this build has never heard of, synced from a device
              // running a newer one.
              'rating': 'thriving',
              'note': 'Felt strong today',
              'dimensionRatings': {
                'habit-gym': 'met',
                'health-weight': 'thriving',
                'health-steps': 7,
              },
              'provenance': 'ratedByUser',
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

      // Dropping the record would take the note and the day with it, so an
      // older device would show the day as never reflected on at all. Reading
      // it as the honest middle keeps the reflection and its note.
      expect(records, hasLength(1));
      expect(records.single.rating, GoalAssessmentRating.mixed);
      expect(records.single.note, 'Felt strong today');
      // Per-dimension verdicts degrade the same way, and a non-string value
      // is dropped as corruption rather than guessed at.
      expect(records.single.dimensionRatings, {
        'habit-gym': GoalAssessmentRating.met,
        'health-weight': GoalAssessmentRating.mixed,
      });
    },
  );

  group('latestRatingsByDay', () {
    GoalAssessmentRecord record({
      required String id,
      required DateTime day,
      required GoalAssessmentRating rating,
      required DateTime createdAt,
    }) => GoalAssessmentRecord(
      id: id,
      day: day,
      specVersionId: 'spec-1',
      rating: rating,
      createdAt: createdAt,
      provenance: GoalAssessmentProvenance.ratedByUser,
    );

    test('the most recent record decides the day', () {
      final day = DateTime.utc(2026, 8, 10);
      final ratings = latestRatingsByDay([
        record(
          id: 'first',
          day: day,
          rating: GoalAssessmentRating.missed,
          createdAt: DateTime.utc(2026, 8, 10, 9),
        ),
        // The user reflected, then thought better of it. The revision stands.
        record(
          id: 'revised',
          day: day,
          rating: GoalAssessmentRating.improving,
          createdAt: DateTime.utc(2026, 8, 10, 21),
        ),
      ]);

      expect(ratings, {day: GoalAssessmentRating.improving});
    });

    test('records written in the same instant resolve the same way twice', () {
      final day = DateTime.utc(2026, 8, 10);
      final at = DateTime.utc(2026, 8, 10, 21);
      final a = record(
        id: 'aaa',
        day: day,
        rating: GoalAssessmentRating.met,
        createdAt: at,
      );
      final b = record(
        id: 'bbb',
        day: day,
        rating: GoalAssessmentRating.missed,
        createdAt: at,
      );

      // The query orders by timestamp alone, so tied rows arrive in no
      // defined order. Without a stable tie-break two devices colour the same
      // day differently from identical data.
      expect(latestRatingsByDay([a, b]), {day: GoalAssessmentRating.missed});
      expect(latestRatingsByDay([b, a]), {day: GoalAssessmentRating.missed});
    });

    test('a local timestamp still keys by its UTC calendar day', () {
      final ratings = latestRatingsByDay([
        record(
          id: 'a',
          day: DateTime.utc(2026, 8, 10, 23, 30),
          rating: GoalAssessmentRating.met,
          createdAt: DateTime.utc(2026, 8, 11),
        ),
      ]);

      // The strip looks days up by their bare UTC date, so a record carrying
      // a time of day has to normalise to the same key or it never matches.
      expect(ratings.keys.single, DateTime.utc(2026, 8, 10));
    });

    test('days are independent of one another', () {
      final ratings = latestRatingsByDay([
        record(
          id: 'a',
          day: DateTime.utc(2026, 8, 9),
          rating: GoalAssessmentRating.met,
          createdAt: DateTime.utc(2026, 8, 9),
        ),
        record(
          id: 'b',
          day: DateTime.utc(2026, 8, 10),
          rating: GoalAssessmentRating.mixed,
          createdAt: DateTime.utc(2026, 8, 10),
        ),
      ]);

      expect(ratings, {
        DateTime.utc(2026, 8, 9): GoalAssessmentRating.met,
        DateTime.utc(2026, 8, 10): GoalAssessmentRating.mixed,
      });
    });

    test('no records means no colours to override the measurement', () {
      expect(latestRatingsByDay(const []), isEmpty);
    });

    test('a verdict from another spec version never colours the new goal', () {
      final day = DateTime.utc(2026, 8, 10);
      final records = [
        record(
          id: 'old-spec',
          day: day,
          rating: GoalAssessmentRating.met,
          createdAt: DateTime.utc(2026, 8, 10, 21),
        ),
        GoalAssessmentRecord(
          id: 'current-spec',
          day: day,
          specVersionId: 'spec-2',
          rating: GoalAssessmentRating.missed,
          createdAt: DateTime.utc(2026, 8, 10, 9),
          provenance: GoalAssessmentProvenance.ratedByUser,
        ),
      ];

      // Spec versions are immutable and the history keeps them all. Unscoped,
      // the NEWER old-spec verdict would win and paint the day Met under
      // criteria it never judged.
      expect(
        latestRatingsByDay(records, specVersionId: 'spec-2'),
        {day: GoalAssessmentRating.missed},
      );
      expect(
        latestRatingsByDay(records, specVersionId: 'spec-1'),
        {day: GoalAssessmentRating.met},
      );
      // Unscoped still means "whatever was written last".
      expect(latestRatingsByDay(records), {day: GoalAssessmentRating.met});
    });

    test('the standing record is available whole, not just its rating', () {
      // Reopening a judged day has to restore the note and the per-dimension
      // verdicts, not only the colour.
      final day = DateTime.utc(2026, 8, 10);
      final standing = latestAssessmentsByDay([
        record(
          id: 'r',
          day: day,
          rating: GoalAssessmentRating.improving,
          createdAt: DateTime.utc(2026, 8, 10),
        ),
      ])[day];

      expect(standing?.id, 'r');
      expect(standing?.rating, GoalAssessmentRating.improving);
    });
  });
}
