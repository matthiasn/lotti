import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/habits/model/habit_form_mapping.dart';
import 'package:lotti/features/habits/ui/widgets/editor/habit_signal_presentation.dart';

import '../../../../../test_data/test_data.dart';

void main() {
  final water = measurableWater.copyWith(
    id: 'water',
    displayName: 'Water',
    unitName: 'ml',
  );
  final byId = {'water': water};

  test('each kind has its own icon', () {
    expect(HabitSignalKind.measurable.icon, LottiIcons.measure);
    expect(HabitSignalKind.health.icon, LottiIcons.heartRate);
    expect(HabitSignalKind.workout.icon, LottiIcons.fitness);
  });

  test(
    'names resolve through the measurable, the health config, or the id',
    () {
      expect(
        habitSignalDisplayName(
          const HabitSignalForm(kind: HabitSignalKind.measurable, id: 'water'),
          byId,
        ),
        'Water',
      );
      expect(
        habitSignalDisplayName(
          const HabitSignalForm(kind: HabitSignalKind.measurable, id: 'gone'),
          byId,
        ),
        'gone',
      );
      expect(
        habitSignalDisplayName(
          const HabitSignalForm(
            kind: HabitSignalKind.health,
            id: 'cumulative_step_count',
          ),
          byId,
        ),
        'Steps',
      );
      expect(
        habitSignalDisplayName(
          const HabitSignalForm(kind: HabitSignalKind.workout, id: 'running'),
          byId,
        ),
        'running',
      );
      expect(
        habitSignalDisplayName(
          const HabitSignalForm(
            kind: HabitSignalKind.workout,
            id: 'running',
            title: 'Morning run',
          ),
          byId,
        ),
        'Morning run',
      );
    },
  );

  test('units come from the measurable or the workout dimension', () {
    expect(
      habitSignalUnit(
        const HabitSignalForm(kind: HabitSignalKind.measurable, id: 'water'),
        byId,
      ),
      'ml',
    );
    expect(
      habitSignalUnit(
        const HabitSignalForm(kind: HabitSignalKind.health, id: 'x'),
        byId,
      ),
      '',
    );
    for (final (type, unit) in [
      (WorkoutValueType.duration, 'min'),
      (WorkoutValueType.distance, 'km'),
      (WorkoutValueType.energy, 'kcal'),
    ]) {
      expect(
        habitSignalUnit(
          HabitSignalForm(
            kind: HabitSignalKind.workout,
            id: 'running',
            mode: HabitSignalMode.atLeast,
            workoutValueType: type,
          ),
          byId,
        ),
        unit,
      );
    }
    expect(
      habitSignalUnit(
        const HabitSignalForm(kind: HabitSignalKind.workout, id: 'running'),
        byId,
      ),
      '',
    );
  });
}
