import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/habits/model/habit_form_mapping.dart';
import '../../../test_data/test_data.dart';

void main() {
  const water = HabitSignalForm(
    kind: HabitSignalKind.measurable,
    id: 'water',
    mode: HabitSignalMode.atLeast,
    threshold: 1000,
  );
  const coffee = HabitSignalForm(
    kind: HabitSignalKind.measurable,
    id: 'coffee',
    mode: HabitSignalMode.atMost,
    threshold: 2,
  );
  const steps = HabitSignalForm(
    kind: HabitSignalKind.health,
    id: 'cumulative_step_count',
    mode: HabitSignalMode.atLeast,
    threshold: 6000,
  );
  const anyRun = HabitSignalForm(kind: HabitSignalKind.workout, id: 'running');
  const longRun = HabitSignalForm(
    kind: HabitSignalKind.workout,
    id: 'running',
    mode: HabitSignalMode.atLeast,
    threshold: 5,
    workoutValueType: WorkoutValueType.distance,
  );

  group('toRule', () {
    test('no signals means no rule', () {
      expect(HabitFormMapping.toRule(const HabitSignalsForm()), isNull);
    });

    test('one signal is a bare leaf whatever the composite says', () {
      expect(
        HabitFormMapping.toRule(
          const HabitSignalsForm(
            signals: [water],
            composite: HabitCompositeRule.all,
          ),
        ),
        const AutoCompleteRule.measurable(dataTypeId: 'water', minimum: 1000),
      );
    });

    test('modes map to minimum, maximum, or neither', () {
      expect(
        HabitFormMapping.toRule(const HabitSignalsForm(signals: [coffee])),
        const AutoCompleteRule.measurable(dataTypeId: 'coffee', maximum: 2),
      );
      expect(
        HabitFormMapping.toRule(const HabitSignalsForm(signals: [anyRun])),
        const AutoCompleteRule.workout(dataType: 'running'),
      );
      expect(
        HabitFormMapping.toRule(const HabitSignalsForm(signals: [longRun])),
        const AutoCompleteRule.workout(
          dataType: 'running',
          minimum: 5,
          valueType: WorkoutValueType.distance,
        ),
      );
    });

    test('the selected value basis survives form and rule mapping', () {
      const form = HabitSignalsForm(
        signals: [
          HabitSignalForm(
            kind: HabitSignalKind.health,
            id: 'cumulative_step_count',
            mode: HabitSignalMode.atLeast,
            threshold: 6000,
            valueBasis: HabitSignalValueBasis.todayOrSevenDayAverage,
          ),
        ],
      );
      final rule = HabitFormMapping.toRule(form)! as AutoCompleteRuleHealth;
      expect(
        rule.valueBasis,
        HabitSignalValueBasis.todayOrSevenDayAverage,
      );
      expect(HabitFormMapping.fromRule(rule), form);
    });

    test('composites become or / and / multiple with a clamped count', () {
      const two = [water, steps];
      expect(
        HabitFormMapping.toRule(const HabitSignalsForm(signals: two)),
        isA<AutoCompleteRuleOr>(),
      );
      expect(
        HabitFormMapping.toRule(
          const HabitSignalsForm(
            signals: two,
            composite: HabitCompositeRule.all,
          ),
        ),
        isA<AutoCompleteRuleAnd>(),
      );
      final atLeast =
          HabitFormMapping.toRule(
                const HabitSignalsForm(
                  signals: two,
                  composite: HabitCompositeRule.atLeast,
                  requiredCount: 5,
                ),
              )!
              as AutoCompleteRuleMultiple;
      expect(atLeast.successes, 2);
    });
  });

  group('fromRule', () {
    test('null is an empty card', () {
      expect(HabitFormMapping.fromRule(null), const HabitSignalsForm());
    });

    test('a multiple reads back its count', () {
      final form = HabitFormMapping.fromRule(
        const AutoCompleteRule.multiple(
          rules: [
            AutoCompleteRule.measurable(dataTypeId: 'water', minimum: 1000),
            AutoCompleteRule.health(
              dataType: 'cumulative_step_count',
              minimum: 6000,
            ),
            AutoCompleteRule.workout(dataType: 'running'),
          ],
          successes: 2,
        ),
      );
      expect(form.signals, [water, steps, anyRun]);
      expect(form.composite, HabitCompositeRule.atLeast);
      expect(form.requiredCount, 2);
    });

    test('nested composites flatten under the root; habit leaves drop', () {
      final form = HabitFormMapping.fromRule(
        const AutoCompleteRule.and(
          rules: [
            AutoCompleteRule.or(
              rules: [
                AutoCompleteRule.measurable(dataTypeId: 'water', minimum: 1000),
                AutoCompleteRule.habit(habitId: 'other'),
              ],
            ),
            AutoCompleteRule.measurable(dataTypeId: 'coffee', maximum: 2),
          ],
        ),
      );
      expect(form.signals, [water, coffee]);
      expect(form.composite, HabitCompositeRule.all);
    });

    test('a two-bounded leaf keeps its minimum', () {
      final form = HabitFormMapping.fromRule(
        const AutoCompleteRule.measurable(
          dataTypeId: 'water',
          minimum: 500,
          maximum: 3000,
        ),
      );
      expect(form.signals.single.mode, HabitSignalMode.atLeast);
      expect(form.signals.single.threshold, 500);
    });

    test('a workout threshold without a dimension reads as any workout', () {
      final form = HabitFormMapping.fromRule(
        const AutoCompleteRule.workout(dataType: 'running', minimum: 30),
      );
      expect(form.signals.single, anyRun);
    });
  });

  group('round trips', () {
    const kinds = HabitSignalKind.values;
    const modes = HabitSignalMode.values;

    HabitSignalForm signal(int kindSlot, int modeSlot, int idSlot) {
      final kind = kinds[kindSlot % kinds.length];
      final mode = modes[modeSlot % modes.length];
      return HabitSignalForm(
        kind: kind,
        id: '${kind.name}-$idSlot',
        mode: mode,
        threshold: mode == HabitSignalMode.any ? null : 10 + idSlot,
        valueBasis: HabitSignalValueBasis
            .values[idSlot % HabitSignalValueBasis.values.length],
        workoutValueType:
            kind == HabitSignalKind.workout && mode != HabitSignalMode.any
            ? WorkoutValueType.values[idSlot % WorkoutValueType.values.length]
            : null,
      );
    }

    glados.Glados3(
      glados.any.listWithLengthInRange(0, 5, glados.any.intInRange(0, 1000)),
      glados.any.intInRange(0, 3),
      glados.any.intInRange(1, 7),
    ).test('form → rule → form is the normalized form', (slots, comp, req) {
      final form = HabitSignalsForm(
        signals: [
          for (final (i, slot) in slots.indexed) signal(slot, slot ~/ 7, i),
        ],
        composite: HabitCompositeRule.values[comp],
        requiredCount: req,
      );
      final rule = HabitFormMapping.toRule(form);
      expect(HabitFormMapping.fromRule(rule), form.normalized());
    });
  });

  group('HabitSignalsForm', () {
    test('value semantics, emptiness and completeness', () {
      const a = HabitSignalsForm(signals: [water, steps]);
      const b = HabitSignalsForm(signals: [water, steps]);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const HabitSignalsForm(signals: [water])));
      expect(a.toString(), contains('water'));
      expect(const HabitSignalsForm().isEmpty, isTrue);
      expect(a.isEmpty, isFalse);
      expect(a.isComplete, isTrue);
      expect(
        const HabitSignalsForm(
          signals: [
            HabitSignalForm(
              kind: HabitSignalKind.measurable,
              id: 'water',
              mode: HabitSignalMode.atLeast,
            ),
          ],
        ).isComplete,
        isFalse,
      );
      expect(const HabitSignalsForm(signals: [anyRun]).isComplete, isTrue);
      // A bounded workout needs both a number and a dimension.
      expect(
        HabitSignalsForm(
          signals: [
            anyRun.copyWith(mode: HabitSignalMode.atLeast, threshold: 5),
          ],
        ).isComplete,
        isFalse,
      );
      expect(const HabitSignalsForm(signals: [longRun]).isComplete, isTrue);
    });

    test('an or root reads back as "any"', () {
      final form = HabitFormMapping.fromRule(
        const AutoCompleteRule.or(
          rules: [
            AutoCompleteRule.measurable(dataTypeId: 'water', minimum: 1000),
            AutoCompleteRule.measurable(dataTypeId: 'coffee', maximum: 2),
          ],
        ),
      );
      expect(form.composite, HabitCompositeRule.any);
      expect(form.signals, [water, coffee]);
    });

    test('normalized clamps and drops an irrelevant composite', () {
      const single = HabitSignalsForm(
        signals: [water],
        composite: HabitCompositeRule.atLeast,
        requiredCount: 3,
      );
      expect(single.normalized(), const HabitSignalsForm(signals: [water]));
      const many = HabitSignalsForm(
        signals: [water, steps],
        composite: HabitCompositeRule.atLeast,
        requiredCount: 9,
      );
      expect(many.normalized().requiredCount, 2);
      expect(
        const HabitSignalsForm(
          signals: [water, steps],
          composite: HabitCompositeRule.all,
          requiredCount: 2,
        ).normalized().requiredCount,
        1,
      );
    });

    test('copyWith can clear a threshold and a dimension', () {
      final cleared = longRun.copyWith(
        mode: HabitSignalMode.any,
        clearThreshold: true,
        clearWorkoutValueType: true,
      );
      expect(cleared, anyRun);
      expect(cleared.toString(), contains('running'));
      expect(cleared.hashCode, anyRun.hashCode);
    });
  });
  group('unboundedForChoices', () {
    final hydration = measurableHydration.copyWith(id: 'hydration');
    final byId = {'hydration': hydration, 'water': measurableWater};
    const boundedChoice = HabitSignalForm(
      kind: HabitSignalKind.measurable,
      id: 'hydration',
      mode: HabitSignalMode.atLeast,
      threshold: 500,
    );
    const boundedWater = HabitSignalForm(
      kind: HabitSignalKind.measurable,
      id: 'water',
      mode: HabitSignalMode.atMost,
      threshold: 2,
    );

    test('drops a bound on a choice measurable and keeps every other', () {
      const form = HabitSignalsForm(
        signals: [boundedChoice, boundedWater],
        composite: HabitCompositeRule.all,
      );
      final result = form.unboundedForChoices(byId);
      expect(result.signals, const [
        HabitSignalForm(kind: HabitSignalKind.measurable, id: 'hydration'),
        boundedWater,
      ]);
      expect(result.composite, HabitCompositeRule.all);
    });

    test('returns the same instance when nothing needs changing', () {
      const form = HabitSignalsForm(
        signals: [
          HabitSignalForm(kind: HabitSignalKind.measurable, id: 'hydration'),
          boundedWater,
        ],
      );
      expect(identical(form.unboundedForChoices(byId), form), isTrue);
      // An unknown measurable is left alone: its kind is not known either.
      const unknown = HabitSignalsForm(signals: [boundedChoice]);
      expect(identical(unknown.unboundedForChoices(const {}), unknown), isTrue);
    });
  });
}
