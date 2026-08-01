import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/service/agent_retention_policy.dart';

import '../test_data/entity_factories.dart';

void main() {
  const policy = AgentRetentionPolicy();
  final now = DateTime(2026, 8);

  group('what is never eligible', () {
    test("the user's own material has no horizon, however old", () {
      final authored = <AgentDomainEntity>[
        makeTestCapture(createdAt: DateTime(2015)),
        makeTestDayPlan(createdAt: DateTime(2015)),
        makeTestDaySummary(createdAt: DateTime(2015)),
        makeTestDayDirective(createdAt: DateTime(2015)),
        makeTestReport(createdAt: DateTime(2015)),
      ];

      for (final entity in authored) {
        expect(
          policy.classify(entity),
          AgentRetentionClass.userAuthored,
          reason: "${entity.runtimeType} is the user's own material.",
        );
        expect(
          policy.isBeyondHorizon(
            entity: entity,
            createdAt: DateTime(2015),
            now: now,
          ),
          isFalse,
        );
      }
    });

    test('the deliberate keeps stay keeps', () {
      // These were decided against on the record, not overlooked. A horizon
      // appearing on any of them is a regression, not a new feature.
      final kept = <AgentDomainEntity>[
        makeTestWeekRollup(),
        makeTestIdentity(),
        makeTestState(),
        makeTestMessagePayload(),
      ];

      for (final entity in kept) {
        expect(policy.classify(entity), AgentRetentionClass.keptDerived);
        expect(policy.horizonFor(entity), isNull);
      }
    });

    test('a non-observation message is durable memory, not residue', () {
      final summary = makeTestMessage(
        kind: AgentMessageKind.summary,
        createdAt: DateTime(2015),
      );

      expect(policy.classify(summary), AgentRetentionClass.keptDerived);
      expect(
        policy.isBeyondHorizon(
          entity: summary,
          createdAt: DateTime(2015),
          now: now,
        ),
        isFalse,
        reason:
            'Compaction summaries are what the agent remembers after its raw '
            'log is folded away; ageing them out would erase that memory.',
      );
    });
  });

  group('what is bounded', () {
    test('an observation is bounded by both a count and an age', () {
      final observation = makeTestMessage(kind: AgentMessageKind.observation);

      expect(policy.classify(observation), AgentRetentionClass.observation);
      expect(policy.horizonFor(observation), policy.observations);
      expect(
        policy.observationsPerAgent,
        greaterThan(40),
        reason: 'A wake reads at most 40; the cap must clear every read.',
      );
    });

    test('a day-status event past the horizon is dropped', () {
      final event = makeTestDayStatusEvent();

      expect(
        policy.isBeyondHorizon(
          entity: event,
          createdAt: now.subtract(const Duration(days: 91)),
          now: now,
        ),
        isTrue,
      );
      expect(
        policy.isBeyondHorizon(
          entity: event,
          createdAt: now.subtract(const Duration(days: 89)),
          now: now,
        ),
        isFalse,
      );
    });

    test('the boundary itself is kept, not dropped', () {
      expect(
        policy.isBeyondHorizon(
          entity: makeTestDayStatusEvent(),
          createdAt: now.subtract(policy.dayStatusEvents),
          now: now,
        ),
        isFalse,
        reason: 'Strictly-before, so the horizon is inclusive of its edge.',
      );
    });
  });

  test('every read window a horizon protects fits inside it', () {
    // The digest reads status events from its watermark with 12h of sync-lag
    // slack. If a horizon ever drops below the read window it protects, the
    // read silently starts returning less than it asks for.
    expect(policy.dayStatusEvents, greaterThan(const Duration(days: 3)));
    expect(policy.observations, greaterThan(policy.dayStatusEvents));
  });
}
