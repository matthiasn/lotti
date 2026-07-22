import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_plan_models.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_directive_models.dart';

void main() {
  group('DayDirectiveCommitment', () {
    final full = DayDirectiveCommitment(
      id: 'award-001',
      source: DayCommitmentSource.attentionAward,
      title: 'Ship the release notes',
      windowStart: DateTime(2026, 5, 25, 9),
      windowEnd: DateTime(2026, 5, 25, 11),
      minutes: 90,
      evidenceRefs: const ['attention-award-001', 'task-042'],
    );

    test('JSON round-trips every field', () {
      final decoded = DayDirectiveCommitment.fromJson(full.toJson());

      expect(decoded, full);
      expect(decoded.windowStart, DateTime(2026, 5, 25, 9));
      expect(decoded.evidenceRefs, ['attention-award-001', 'task-042']);
    });

    test('omits absent optionals from JSON and defaults them on read', () {
      const minimal = DayDirectiveCommitment(
        id: 'user-1',
        source: DayCommitmentSource.userCommitment,
        title: 'Call the school',
      );

      final json = minimal.toJson();
      expect(json.containsKey('windowStart'), isFalse);
      expect(json.containsKey('windowEnd'), isFalse);
      expect(json.containsKey('minutes'), isFalse);

      final decoded = DayDirectiveCommitment.fromJson(json);
      expect(decoded, minimal);
      expect(decoded.evidenceRefs, isEmpty);
    });

    test('equality covers list content, not identity', () {
      final same = DayDirectiveCommitment(
        id: 'award-001',
        source: DayCommitmentSource.attentionAward,
        title: 'Ship the release notes',
        windowStart: DateTime(2026, 5, 25, 9),
        windowEnd: DateTime(2026, 5, 25, 11),
        minutes: 90,
        // A fresh, equal-content list must still compare equal.
        evidenceRefs: List.of(['attention-award-001', 'task-042']),
      );

      expect(same, full);
      expect(same.hashCode, full.hashCode);
      expect(full.copyWithDifferentTitle(), isNot(full));
    });
  });

  group('DayCapacityBudget', () {
    final budget = DayCapacityBudget(
      availableMinutes: 420,
      alreadyScheduledMinutes: 60,
      energyBands: [
        DayAgentEnergyBand(
          start: DateTime(2026, 5, 25, 9),
          end: DateTime(2026, 5, 25, 12),
          level: DayAgentEnergyLevel.high,
          label: 'HIGH ENERGY',
        ),
      ],
    );

    test('JSON round-trips nested energy bands', () {
      final decoded = DayCapacityBudget.fromJson(budget.toJson());

      expect(decoded, budget);
      expect(decoded.energyBands.single.level, DayAgentEnergyLevel.high);
    });

    test('defaults scheduled minutes and bands when absent from JSON', () {
      final decoded = DayCapacityBudget.fromJson(const {
        'availableMinutes': 300,
      });

      expect(decoded.availableMinutes, 300);
      expect(decoded.alreadyScheduledMinutes, 0);
      expect(decoded.energyBands, isEmpty);
    });
  });

  group('DayCarryOverItem', () {
    test('JSON round-trips with either backing id', () {
      const taskBacked = DayCarryOverItem(
        title: 'Expense report',
        reason: 'Dropped for a client emergency.',
        taskId: 'task-042',
      );
      const itemBacked = DayCarryOverItem(
        title: 'Book dentist',
        reason: 'Never became a task.',
        itemId: 'parsed-007',
      );

      expect(DayCarryOverItem.fromJson(taskBacked.toJson()), taskBacked);
      expect(DayCarryOverItem.fromJson(itemBacked.toJson()), itemBacked);
      expect(taskBacked.toJson().containsKey('itemId'), isFalse);
      expect(itemBacked.toJson().containsKey('taskId'), isFalse);
    });

    test('equality distinguishes differing reasons', () {
      const a = DayCarryOverItem(title: 'X', reason: 'ran out of time');
      const b = DayCarryOverItem(title: 'X', reason: 'user dropped it');

      expect(a, isNot(b));
    });
  });
}

extension on DayDirectiveCommitment {
  DayDirectiveCommitment copyWithDifferentTitle() => DayDirectiveCommitment(
    id: id,
    source: source,
    title: '$title (changed)',
    windowStart: windowStart,
    windowEnd: windowEnd,
    minutes: minutes,
    evidenceRefs: evidenceRefs,
  );
}
