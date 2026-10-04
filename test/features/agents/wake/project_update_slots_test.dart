import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/agents/agent_config.dart';
import 'package:lotti/features/agents/wake/project_update_slots.dart';

void main() {
  group('nextProjectUpdateSlot', () {
    test('hourly slots start on the hour, strictly after the instant', () {
      expect(
        nextProjectUpdateSlot(
          DateTime(2026, 10, 2, 10, 25),
          intervalMinutes: 60,
        ),
        DateTime(2026, 10, 2, 11),
      );
      // An instant on a boundary belongs to the slot it starts: the next one
      // is a full interval later.
      expect(
        nextProjectUpdateSlot(DateTime(2026, 10, 2, 11), intervalMinutes: 60),
        DateTime(2026, 10, 2, 12),
      );
    });

    test('anchors longer intervals at 06:00, also before the anchor', () {
      expect(
        nextProjectUpdateSlot(DateTime(2026, 10, 2, 7), intervalMinutes: 480),
        DateTime(2026, 10, 2, 14),
      );
      expect(
        nextProjectUpdateSlot(DateTime(2026, 10, 2, 23), intervalMinutes: 480),
        DateTime(2026, 10, 3, 6),
      );
      // 03:00 lies in the 22:00 slot of the day before.
      expect(
        nextProjectUpdateSlot(DateTime(2026, 10, 2, 3), intervalMinutes: 480),
        DateTime(2026, 10, 2, 6),
      );
      expect(
        nextProjectUpdateSlot(
          DateTime(2026, 10, 2, 5, 59),
          intervalMinutes: 240,
        ),
        DateTime(2026, 10, 2, 6),
      );
    });

    test('a daily interval updates at the next 06:00', () {
      expect(
        nextProjectUpdateSlot(DateTime(2026, 10, 2, 5), intervalMinutes: 1440),
        DateTime(2026, 10, 2, 6),
      );
      expect(
        nextProjectUpdateSlot(DateTime(2026, 10, 2, 6), intervalMinutes: 1440),
        DateTime(2026, 10, 3, 6),
      );
    });

    glados.Glados2(
      glados.IntAnys(glados.any).intInRange(0, 7 * 24 * 60),
      glados.IntAnys(
        glados.any,
      ).intInRange(0, ProjectUpdateSlots.choices.length),
    ).test(
      'the next slot is later, at most one interval away, and on the grid',
      (minuteOfWeek, choice) {
        final interval = ProjectUpdateSlots.choices[choice];
        // UTC keeps the arithmetic free of the test machine's clock changes.
        final after = DateTime.utc(2026, 10, 5).add(
          Duration(minutes: minuteOfWeek, seconds: 17),
        );
        final slot = nextProjectUpdateSlot(after, intervalMinutes: interval);

        expect(slot.isAfter(after), isTrue);
        expect(
          slot.difference(after) <= Duration(minutes: interval),
          isTrue,
          reason: '$after → $slot',
        );
        final minuteOfDay = slot.hour * 60 + slot.minute;
        expect(
          (minuteOfDay - ProjectUpdateSlots.anchorMinutes) % interval,
          0,
          reason: '$slot is off the grid',
        );
        expect(slot.second, 0);
      },
      tags: 'glados',
    );
  });

  group('effectiveUpdateIntervalMinutes', () {
    test('defaults to hourly and ignores values it does not offer', () {
      expect(effectiveUpdateIntervalMinutes(const AgentConfig()), 60);
      expect(
        effectiveUpdateIntervalMinutes(
          const AgentConfig(updateIntervalMinutes: 240),
        ),
        240,
      );
      expect(
        effectiveUpdateIntervalMinutes(
          const AgentConfig(updateIntervalMinutes: 7),
        ),
        60,
      );
    });
  });

  group('slot records', () {
    test('derive the same id for the same slot instant in any zone', () {
      final local = DateTime(2026, 10, 2, 11);
      expect(
        projectUpdateSlotRecordId('agent-1', local),
        projectUpdateSlotRecordId('agent-1', local.toUtc()),
      );
      expect(
        projectUpdateSlotRecordId('agent-1', local),
        isNot(projectUpdateSlotRecordId('agent-2', local)),
      );
    });

    test('are recognised by their workspace key', () {
      final key = projectUpdateWorkspaceKey(DateTime.utc(2026, 10, 2, 9));
      expect(key, 'project_update:2026-10-02T09:00:00.000Z');
      expect(isProjectUpdateWorkspace(key), isTrue);
      expect(isProjectUpdateWorkspace('goal-escalation:2026-W40'), isFalse);
      expect(isProjectUpdateWorkspace(null), isFalse);
    });
  });
}
