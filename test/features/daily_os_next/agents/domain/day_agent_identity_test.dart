import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_identity.dart';

void main() {
  group('perDayAgentId', () {
    test('prefixes the day id with the per-day marker', () {
      expect(
        perDayAgentId('dayplan-2026-07-22'),
        'day_agent:dayplan-2026-07-22',
      );
    });

    test('perDayAgentIdForDate normalizes to the local calendar day', () {
      // Time-of-day must not leak into the identity: any instant on the same
      // local day maps to the same agent id.
      expect(
        perDayAgentIdForDate(DateTime(2026, 7, 22, 23, 59)),
        'day_agent:dayplan-2026-07-22',
      );
      expect(
        perDayAgentIdForDate(DateTime(2026, 7, 22)),
        perDayAgentIdForDate(DateTime(2026, 7, 22, 8, 30)),
      );
    });
  });

  group('isPerDayAgentId', () {
    test('accepts per-day ids and rejects everything else', () {
      expect(isPerDayAgentId('day_agent:dayplan-2026-07-22'), isTrue);
      // The coordinator is not a per-day agent.
      expect(isPerDayAgentId(dailyOsPlannerAgentId), isFalse);
      // Bare legacy pre-ADR-0022 ids share the day-id shape but not the
      // prefix — the legacy migration relies on this distinction.
      expect(isPerDayAgentId('dayplan-2026-07-22'), isFalse);
      expect(isPerDayAgentId('task-agent-1'), isFalse);
    });
  });

  group('dayIdFromPerDayAgentId', () {
    test('round-trips through perDayAgentId', () {
      const dayId = 'dayplan-2026-07-22';
      expect(dayIdFromPerDayAgentId(perDayAgentId(dayId)), dayId);
    });

    test('returns null for foreign ids and a bare prefix', () {
      expect(dayIdFromPerDayAgentId(dailyOsPlannerAgentId), isNull);
      expect(dayIdFromPerDayAgentId('dayplan-2026-07-22'), isNull);
      expect(dayIdFromPerDayAgentId(perDayAgentIdPrefix), isNull);
    });
  });

  group('isDailyOsDayOwner', () {
    test('accepts the coordinator and per-day agents only', () {
      expect(isDailyOsDayOwner(dailyOsPlannerAgentId), isTrue);
      expect(isDailyOsDayOwner('day_agent:dayplan-2026-07-22'), isTrue);
      expect(isDailyOsDayOwner('dayplan-2026-07-22'), isFalse);
      expect(isDailyOsDayOwner('someone-else'), isFalse);
    });
  });
}
