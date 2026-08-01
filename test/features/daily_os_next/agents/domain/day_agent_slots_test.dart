import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';

void main() {
  group('dayAgentIdForDate', () {
    glados.Glados<_GeneratedDayDate>(
      glados.any.dayDate,
      glados.ExploreConfig(numRuns: 120),
    ).test('uses the shared day-plan ID for the local calendar day', (
      generated,
    ) {
      expect(
        localDay(generated.withTime),
        generated.dayOnly,
        reason: '$generated',
      );
      expect(
        dayAgentIdForDate(generated.withTime),
        dayPlanId(generated.dayOnly),
        reason: '$generated',
      );
    }, tags: 'glados');
  });

  group('dayAgentPlanEntityId', () {
    test('locks the cross-service entity-id format for a day plan', () {
      // The literal prefix is the lookup key shared with DayAgentPlanService;
      // any drift here silently breaks cross-service plan-existence checks.
      expect(
        dayAgentPlanEntityId('dayplan-2026-05-25'),
        'day_agent_plan:dayplan-2026-05-25',
      );
    });

    test('embeds the dayId verbatim, including empty input', () {
      expect(dayAgentPlanEntityId(''), 'day_agent_plan:');
    });

    glados.Glados<String>(
      glados.any.letterOrDigits,
      glados.ExploreConfig(numRuns: 120),
    ).test('always prefixes the dayId without mutating it', (dayId) {
      final entityId = dayAgentPlanEntityId(dayId);
      expect(entityId, 'day_agent_plan:$dayId', reason: 'dayId="$dayId"');
      expect(entityId.startsWith('day_agent_plan:'), isTrue);
      expect(
        entityId.substring('day_agent_plan:'.length),
        dayId,
        reason: 'dayId="$dayId"',
      );
    }, tags: 'glados');
  });

  group('dayDirectiveEntityId', () {
    test('locks the per-day directive register id format', () {
      // The literal prefix is the PK the coordinator writes and every day
      // owner reads; drift here would silently orphan issued directives.
      expect(
        dayDirectiveEntityId('dayplan-2026-05-25'),
        'day_directive:dayplan-2026-05-25',
      );
    });
  });

  group('dayStatusEventId', () {
    test('locks the append-only event id format (prefix:dayId:suffix)', () {
      expect(
        dayStatusEventId('dayplan-2026-05-25', 'abc123'),
        'day_status:dayplan-2026-05-25:abc123',
      );
      expect(
        dayStatusEventId('dayplan-2026-05-25', 'abc123'),
        startsWith(dayStatusEventIdPrefix),
      );
    });

    test('distinct suffixes yield distinct ids for the same day', () {
      expect(
        dayStatusEventId('dayplan-2026-05-25', 'a'),
        isNot(dayStatusEventId('dayplan-2026-05-25', 'b')),
      );
    });

    test('durable retries share one processing-job-scoped event id', () {
      expect(
        dayStatusEventIdForProcessingJob(
          'dayplan-2026-05-25',
          'draft_dayplan-2026-05-25',
        ),
        'day_status:dayplan-2026-05-25:job:draft_dayplan-2026-05-25',
      );
    });
  });

  group('canonicalWeekStart', () {
    test('maps every weekday of one week to the same Monday', () {
      // 2026-05-18 is a Monday.
      for (var offset = 0; offset < 7; offset++) {
        expect(
          canonicalWeekStart(DateTime(2026, 5, 18 + offset, 13, 45)),
          DateTime.utc(2026, 5, 18),
          reason: 'offset $offset must bucket to Monday 2026-05-18',
        );
      }
    });

    test('a Sunday belongs to the week begun the prior Monday, crossing '
        'month boundaries', () {
      expect(canonicalWeekStart(DateTime(2026, 6, 7)), DateTime.utc(2026, 6));
      expect(
        canonicalWeekStart(DateTime(2026, 5, 3)),
        DateTime.utc(2026, 4, 27),
      );
    });

    test('reads calendar components, so a local and a UTC-typed spelling of '
        'the same date agree', () {
      expect(
        canonicalWeekStart(DateTime(2026, 5, 20, 23, 30)),
        canonicalWeekStart(DateTime.utc(2026, 5, 20, 23, 30)),
        reason:
            'A converting read would move the UTC-typed spelling across a '
            'day — and, near a Monday, across a week.',
      );
    });
  });

  group('recordedWallClock', () {
    test("reads the timestamp's components, never a conversion", () {
      // dateFrom crosses the wire without a zone suffix, so its components are
      // the recorder's wall clock on every device. Converting would make the
      // answer depend on the reader's zone, which is the bug this replaces.
      expect(
        recordedWallClock(DateTime(2026, 5, 27, 12, 30, 15)),
        DateTime.utc(2026, 5, 27, 12, 30, 15),
      );
    });

    test('a UTC-typed timestamp keeps its own components too', () {
      expect(
        recordedWallClock(DateTime.utc(2026, 5, 31, 23, 30)),
        DateTime.utc(2026, 5, 31, 23, 30),
        reason:
            'Imported data is UTC-typed; reading components rather than '
            'converting keeps every device on one answer for it too.',
      );
    });

    test('a local and a UTC spelling of one wall clock agree', () {
      expect(
        recordedWallClock(DateTime(2026, 6, 1, 0, 30)),
        recordedWallClock(DateTime.utc(2026, 6, 1, 0, 30)),
        reason:
            'The reading is the calendar, not the instant — which is exactly '
            'what makes two devices bucket the same entry identically.',
      );
    });
  });

  group('canonicalWallClockDuration', () {
    test('reads the length off the calendar, not the instants', () {
      expect(
        canonicalWallClockDuration(
          DateTime(2026, 5, 27, 9),
          DateTime(2026, 5, 27, 10, 30),
        ),
        const Duration(minutes: 90),
      );
    });

    test('a backwards fall-back interval contributes nothing, not a '
        'negative', () {
      // Around a fall-back transition the recorder's own clock legitimately
      // runs backwards: 01:50 daylight to 01:10 standard is 20 elapsed
      // minutes but reads as −40 on the calendar. A negative contribution
      // would subtract from the category's total rather than mis-size it.
      expect(
        canonicalWallClockDuration(
          DateTime(2026, 11, 1, 1, 50),
          DateTime(2026, 11, 1, 1, 10),
        ),
        Duration.zero,
      );
    });
  });

  group('weekRollupEntityId', () {
    test('locks the per-week register id format (Monday date key)', () {
      // The literal prefix is the PK the digest recompute writes and reads;
      // drift here would silently orphan persisted rollups.
      expect(
        weekRollupEntityId(DateTime(2026, 5, 18)),
        'week_rollup_v2:2026-05-18',
      );
    });

    test('keys on calendar components, so two devices agree', () {
      // A converting read would push the UTC-typed spelling to 05-19 (or back
      // to 05-17) depending on the reader's zone — two ids for one week, which
      // is exactly the register flapping the canonical key prevents.
      expect(
        weekRollupEntityId(DateTime.utc(2026, 5, 18, 23, 59)),
        'week_rollup_v2:2026-05-18',
      );
      expect(
        weekRollupEntityId(DateTime(2026, 5, 18, 23, 59)),
        'week_rollup_v2:2026-05-18',
      );
    });

    test('pads single-digit months and days', () {
      expect(
        weekRollupEntityId(DateTime.utc(2026, 1, 5)),
        'week_rollup_v2:2026-01-05',
      );
    });
  });

  group('captureDayId', () {
    CaptureEntity capture({String dayId = '', DateTime? capturedAt}) {
      return AgentDomainEntity.capture(
            id: 'c1',
            agentId: 'a1',
            transcript: 't',
            capturedAt: capturedAt ?? DateTime(2026, 5, 25, 8, 30),
            createdAt: DateTime(2026, 5, 25, 8, 30),
            vectorClock: null,
            dayId: dayId,
          )
          as CaptureEntity;
    }

    test('returns the explicit dayId when present', () {
      expect(
        captureDayId(capture(dayId: 'dayplan-2026-05-25')),
        'dayplan-2026-05-25',
      );
    });

    test('derives the day from capturedAt for a legacy capture', () {
      expect(
        captureDayId(capture(capturedAt: DateTime(2026, 5, 25, 23, 59))),
        'dayplan-2026-05-25',
      );
    });

    test('buckets a UTC capturedAt by the local calendar day', () {
      // A UTC-typed timestamp must resolve to the user's local day, not the
      // UTC day, so a near-midnight capture is not filed under the wrong date.
      final utcAt = DateTime.utc(2026, 5, 25, 23, 59);
      expect(
        captureDayId(capture(capturedAt: utcAt)),
        'dayplan-${utcAt.toLocal().toIso8601String().substring(0, 10)}',
      );
    });
  });
}

class _GeneratedDayDate {
  const _GeneratedDayDate({
    required this.yearSlot,
    required this.monthSlot,
    required this.daySlot,
    required this.hourSlot,
    required this.minuteSlot,
    required this.secondSlot,
  });

  final int yearSlot;
  final int monthSlot;
  final int daySlot;
  final int hourSlot;
  final int minuteSlot;
  final int secondSlot;

  int get year => 2000 + yearSlot % 50;
  int get month => 1 + monthSlot % 12;
  int get day => 1 + daySlot % 28;
  int get hour => hourSlot % 24;
  int get minute => minuteSlot % 60;
  int get second => secondSlot % 60;

  DateTime get dayOnly => DateTime(year, month, day);
  DateTime get withTime => DateTime(year, month, day, hour, minute, second);

  @override
  String toString() {
    return '_GeneratedDayDate('
        'year: $year, month: $month, day: $day, '
        'hour: $hour, minute: $minute, second: $second)';
  }
}

extension _AnyDayAgentDate on glados.Any {
  glados.Generator<int> get _slot => glados.IntAnys(this).intInRange(0, 100000);

  glados.Generator<_GeneratedDayDate> get dayDate =>
      glados.CombinableAny(this).combine6(
        _slot,
        _slot,
        _slot,
        _slot,
        _slot,
        _slot,
        (
          int yearSlot,
          int monthSlot,
          int daySlot,
          int hourSlot,
          int minuteSlot,
          int secondSlot,
        ) => _GeneratedDayDate(
          yearSlot: yearSlot,
          monthSlot: monthSlot,
          daySlot: daySlot,
          hourSlot: hourSlot,
          minuteSlot: minuteSlot,
          secondSlot: secondSlot,
        ),
      );
}
