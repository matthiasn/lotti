import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/habits/model/habit_form_mapping.dart';
import 'package:lotti/features/habits/ui/widgets/editor/habit_signal_presentation.dart';
import 'package:lotti/l10n/app_localizations_en.dart';

import '../../../../../test_data/test_data.dart';

void main() {
  final water = measurableWater.copyWith(
    id: 'water',
    displayName: 'Water',
    unitName: 'ml',
  );
  final hydration = measurableHydration.copyWith(
    id: 'hydration',
    // A leftover unit from before the switch to choices must not label a
    // threshold that no longer exists.
    unitName: 'ml',
  );
  final byId = {'water': water, 'hydration': hydration};
  final messages = AppLocalizationsEn();

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
          messages,
          const HabitSignalForm(kind: HabitSignalKind.measurable, id: 'water'),
          byId,
        ),
        'Water',
      );
      expect(
        habitSignalDisplayName(
          messages,
          const HabitSignalForm(kind: HabitSignalKind.measurable, id: 'gone'),
          byId,
        ),
        'gone',
      );
      expect(
        habitSignalDisplayName(
          messages,
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
          messages,
          const HabitSignalForm(kind: HabitSignalKind.workout, id: 'running'),
          byId,
        ),
        'running',
      );
      expect(
        habitSignalDisplayName(
          messages,
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
        messages,
        const HabitSignalForm(kind: HabitSignalKind.measurable, id: 'water'),
        byId,
      ),
      'ml',
    );
    expect(
      habitSignalUnit(
        messages,
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
          messages,
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
        messages,
        const HabitSignalForm(kind: HabitSignalKind.workout, id: 'running'),
        byId,
      ),
      '',
    );
  });

  test('a choice measurable has no threshold unit, whatever it stores', () {
    expect(
      habitSignalUnit(
        messages,
        const HabitSignalForm(
          kind: HabitSignalKind.measurable,
          id: 'hydration',
        ),
        byId,
      ),
      '',
    );
    expect(
      habitSignalUnit(
        messages,
        const HabitSignalForm(kind: HabitSignalKind.measurable, id: 'gone'),
        byId,
      ),
      '',
    );
  });

  test('the picker subtitle is the unit, or the active choices', () {
    expect(habitMeasurableSubtitle(water), 'ml');
    expect(habitMeasurableSubtitle(water.copyWith(unitName: '')), isNull);
    expect(habitMeasurableSubtitle(hydration), 'Clear · Pale · Dark');
    expect(
      habitMeasurableSubtitle(
        hydration.copyWith(choices: const [hydrationBrown]),
      ),
      isNull,
    );
  });

  test(
    'only real journal series are evaluable; synthetic chart keys are not',
    () {
      final keys = evaluableHealthDataTypes.toSet();
      expect(keys, contains('HealthDataType.WEIGHT'));
      expect(keys, contains('cumulative_step_count'));
      expect(keys, isNot(contains('BLOOD_PRESSURE')));
      expect(keys, isNot(contains('BODY_MASS_INDEX')));
    },
  );

  test('health names come from the catalog, with a config fallback', () {
    for (final key in evaluableHealthDataTypes) {
      // Every evaluable key has a translated name (not the raw id).
      expect(habitHealthTypeName(messages, key), isNot(key));
    }
    expect(habitHealthTypeName(messages, 'HealthDataType.WEIGHT'), 'Weight');
    expect(habitHealthTypeName(messages, 'unknown_type'), 'unknown_type');
  });

  test('health thresholds carry the config unit', () {
    expect(
      habitSignalUnit(
        messages,
        const HabitSignalForm(
          kind: HabitSignalKind.health,
          id: 'HealthDataType.WEIGHT',
        ),
        byId,
      ),
      'kg',
    );
  });
}
