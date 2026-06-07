import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';

void main() {
  group('DayAgentSlots', () {
    test('hasActiveDay reflects non-empty activeDayId', () {
      expect(const AgentSlots().hasActiveDay, isFalse);
      expect(const AgentSlots(activeDayId: '').hasActiveDay, isFalse);
      expect(
        const AgentSlots(activeDayId: 'dayplan-2026-05-25').hasActiveDay,
        isTrue,
      );
    });
  });

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
