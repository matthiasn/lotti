import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';

void main() {
  group('CaptureId equality', () {
    test('identical instances and matching values are equal', () {
      const a = CaptureId('cap_1');
      const b = CaptureId('cap_1');
      const c = CaptureId('cap_2');

      // Identity (same instance) and structural equality both pass.
      expect(a, equals(a));
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
      // ignore: unrelated_type_equality_checks
      expect(a == 'cap_1', isFalse);
    });

    test('toString carries the inner value', () {
      const id = CaptureId('cap_show');
      expect(id.toString(), 'CaptureId(cap_show)');
    });
  });

  group('DayAgentCategory equality', () {
    test('matching id/name/colorHex compare equal', () {
      const a = DayAgentCategory(
        id: 'c1',
        name: 'Work',
        colorHex: 'AABBCC',
      );
      const b = DayAgentCategory(
        id: 'c1',
        name: 'Work',
        colorHex: 'AABBCC',
      );
      const differentColour = DayAgentCategory(
        id: 'c1',
        name: 'Work',
        colorHex: 'DDEEFF',
      );

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a == differentColour, isFalse);
      // operator == fast-rejects non-matching runtime types.
      // ignore: unrelated_type_equality_checks
      expect(a == 'c1', isFalse);
    });
  });

  group('DraftPlan.copyWith', () {
    DraftPlan basePlan() => DraftPlan(
      dayDate: DateTime(2026, 5, 25),
      blocks: const [],
      bands: const [],
      capacityMinutes: 480,
      scheduledMinutes: 0,
    );

    test('returns an identical plan when called with no overrides', () {
      final original = basePlan();
      final copy = original.copyWith();

      expect(copy.dayDate, original.dayDate);
      expect(copy.blocks, original.blocks);
      expect(copy.bands, original.bands);
      expect(copy.capacityMinutes, original.capacityMinutes);
      expect(copy.scheduledMinutes, original.scheduledMinutes);
      expect(copy.actualBlocks, original.actualBlocks);
      expect(copy.agendaItems, original.agendaItems);
      expect(copy.state, original.state);
    });

    test('replaces only the supplied fields and keeps the rest', () {
      final original = basePlan();
      final newDate = DateTime(2026, 6, 2);
      final newBlock = TimeBlock(
        id: 'b1',
        title: 'Focus',
        start: newDate,
        end: newDate.add(const Duration(hours: 1)),
        type: TimeBlockType.ai,
        state: TimeBlockState.drafted,
        category: const DayAgentCategory(
          id: 'c1',
          name: 'Work',
          colorHex: 'AABBCC',
        ),
      );
      final newBand = EnergyBand(
        start: newDate,
        end: newDate.add(const Duration(hours: 1)),
        level: EnergyLevel.high,
        label: 'HIGH',
      );
      const newAgenda = AgendaItem(
        id: 'agenda_1',
        title: 'Focus',
        category: DayAgentCategory(
          id: 'c1',
          name: 'Work',
          colorHex: 'AABBCC',
        ),
        linkedBlockIds: ['b1'],
      );

      final updated = original.copyWith(
        dayDate: newDate,
        blocks: [newBlock],
        bands: [newBand],
        capacityMinutes: 360,
        scheduledMinutes: 60,
        actualBlocks: [newBlock],
        agendaItems: const [newAgenda],
        state: DayState.committed,
      );

      expect(updated.dayDate, newDate);
      expect(updated.blocks, hasLength(1));
      expect(updated.bands, hasLength(1));
      expect(updated.capacityMinutes, 360);
      expect(updated.scheduledMinutes, 60);
      expect(updated.actualBlocks, hasLength(1));
      expect(updated.agendaItems, hasLength(1));
      expect(updated.state, DayState.committed);

      // The original is untouched (DraftPlan is immutable).
      expect(original.dayDate, DateTime(2026, 5, 25));
      expect(original.blocks, isEmpty);
      expect(original.state, DayState.drafted);
    });
  });

  test('TimeBlock.duration reflects end - start', () {
    final start = DateTime(2026, 5, 25, 9);
    final end = start.add(const Duration(minutes: 45));
    final block = TimeBlock(
      id: 'b1',
      title: 'Focus',
      start: start,
      end: end,
      type: TimeBlockType.ai,
      state: TimeBlockState.drafted,
      category: const DayAgentCategory(
        id: 'c1',
        name: 'Work',
        colorHex: 'AABBCC',
      ),
    );

    expect(block.duration, const Duration(minutes: 45));
  });
}
