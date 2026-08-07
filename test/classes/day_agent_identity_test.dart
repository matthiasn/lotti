import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_agent_identity.dart';

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

  group('isDailyOsDayOwner', () {
    test('accepts the coordinator and per-day agents only', () {
      expect(isDailyOsDayOwner(dailyOsPlannerAgentId), isTrue);
      expect(isDailyOsDayOwner('day_agent:dayplan-2026-07-22'), isTrue);
      expect(isDailyOsDayOwner('dayplan-2026-07-22'), isFalse);
      expect(isDailyOsDayOwner('someone-else'), isFalse);
    });
  });

  group('ownsDailyOsDay', () {
    test("accepts the coordinator and exactly this day's agent", () {
      const dayId = 'dayplan-2026-07-22';
      expect(ownsDailyOsDay(dailyOsPlannerAgentId, dayId), isTrue);
      expect(ownsDailyOsDay('day_agent:$dayId', dayId), isTrue);
    });

    test('rejects sibling day agents, legacy ids, and foreign agents', () {
      const dayId = 'dayplan-2026-07-22';
      expect(ownsDailyOsDay('day_agent:dayplan-2026-07-21', dayId), isFalse);
      expect(ownsDailyOsDay(dayId, dayId), isFalse);
      expect(ownsDailyOsDay('task-agent-1', dayId), isFalse);
    });
  });

  group('canReadDailyOsDayArtifact', () {
    const dayId = 'dayplan-2026-07-22';
    const dayAgent = 'day_agent:$dayId';

    test('exact ownership always passes, even for foreign agents', () {
      expect(
        canReadDailyOsDayArtifact(
          readerAgentId: 'task-agent-1',
          ownerAgentId: 'task-agent-1',
          dayId: dayId,
        ),
        isTrue,
      );
    });

    test('a Daily OS reader spans the ownership cutover both ways', () {
      expect(
        canReadDailyOsDayArtifact(
          readerAgentId: dayAgent,
          ownerAgentId: dailyOsPlannerAgentId,
          dayId: dayId,
        ),
        isTrue,
      );
      expect(
        canReadDailyOsDayArtifact(
          readerAgentId: dailyOsPlannerAgentId,
          ownerAgentId: dayAgent,
          dayId: dayId,
        ),
        isTrue,
      );
    });

    test("a sibling day agent's artifact stays invisible", () {
      expect(
        canReadDailyOsDayArtifact(
          readerAgentId: dayAgent,
          ownerAgentId: 'day_agent:dayplan-2026-07-21',
          dayId: dayId,
        ),
        isFalse,
      );
    });

    test('a foreign reader never gains cross-owner reads', () {
      expect(
        canReadDailyOsDayArtifact(
          readerAgentId: 'task-agent-1',
          ownerAgentId: dailyOsPlannerAgentId,
          dayId: dayId,
        ),
        isFalse,
      );
    });

    test("a foreign owner's artifact stays invisible to Daily OS readers", () {
      expect(
        canReadDailyOsDayArtifact(
          readerAgentId: dayAgent,
          ownerAgentId: 'task-agent-1',
          dayId: dayId,
        ),
        isFalse,
      );
    });
  });
}
