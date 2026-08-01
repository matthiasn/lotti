import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/service/agent_retention_policy.dart';

void main() {
  const policy = AgentRetentionPolicy();
  final now = DateTime(2026, 8);

  group('what is never eligible', () {
    test('no user-authored type has an age horizon', () {
      for (final type in AgentRetentionPolicy.userAuthoredTypes) {
        expect(
          policy.horizonFor(type),
          isNull,
          reason: "$type is the user's own material and never expires.",
        );
      }
    });

    test('an ancient capture and day plan survive any cutoff', () {
      for (final type in [
        AgentEntityTypes.capture,
        AgentEntityTypes.dayPlan,
        AgentEntityTypes.daySummary,
        AgentEntityTypes.dayDirective,
        AgentEntityTypes.plannerKnowledge,
      ]) {
        expect(
          policy.isBeyondHorizon(
            type: type,
            createdAt: DateTime(2015),
            now: now,
          ),
          isFalse,
          reason: '$type must never be dropped, however old.',
        );
      }
    });

    test('the deliberate keeps stay keeps', () {
      for (final type in [
        AgentEntityTypes.weekRollup,
        'wakeTokenUsage',
        AgentEntityTypes.attentionRequest,
        AgentEntityTypes.attentionClaimDisposition,
      ]) {
        expect(
          policy.horizonFor(type),
          isNull,
          reason:
              'These were decided against on the record, not overlooked — '
              'a horizon appearing here is a regression.',
        );
      }
    });
  });

  group('isBeyondHorizon', () {
    test('an old day-status event is past the horizon', () {
      expect(
        policy.isBeyondHorizon(
          type: AgentEntityTypes.dayStatusEvent,
          createdAt: now.subtract(const Duration(days: 91)),
          now: now,
        ),
        isTrue,
      );
    });

    test('one inside the window is kept', () {
      expect(
        policy.isBeyondHorizon(
          type: AgentEntityTypes.dayStatusEvent,
          createdAt: now.subtract(const Duration(days: 89)),
          now: now,
        ),
        isFalse,
      );
    });

    test('the boundary itself is kept, not dropped', () {
      expect(
        policy.isBeyondHorizon(
          type: AgentEntityTypes.dayStatusEvent,
          createdAt: now.subtract(policy.dayStatusEvents),
          now: now,
        ),
        isFalse,
        reason: 'Strictly-before, so the horizon is inclusive of its edge.',
      );
    });

    test('observations are not age-eligible — they are bounded by count', () {
      expect(
        policy.isBeyondHorizon(
          type: AgentEntityTypes.agentMessage,
          createdAt: DateTime(2015),
          now: now,
        ),
        isFalse,
        reason:
            'An age rule here would let a heavy week evict a light month, '
            'which is not the bound the store needs.',
      );
    });
  });

  test('every read window the policy protects fits inside it', () {
    // The digest reads status events from its watermark with 12h of sync-lag
    // slack; evaluation surfaces read wake runs over at most 30 days. If a
    // horizon ever drops below a read window, the read silently starts
    // returning less than it asks for.
    expect(policy.dayStatusEvents, greaterThan(const Duration(days: 3)));
    expect(policy.wakeRunLog, greaterThanOrEqualTo(const Duration(days: 30)));
    expect(policy.observationsPerAgent, greaterThan(40));
  });
}
