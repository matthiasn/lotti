import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/logic/signals/choice_measurable_rules.dart';

void main() {
  bool isChoice(String id) => id == 'hydration';

  const boundedChoice = AutoCompleteRule.measurable(
    dataTypeId: 'hydration',
    minimum: 500,
    maximum: 2000,
    title: 'Pee check',
  );
  const boundedWater = AutoCompleteRule.measurable(
    dataTypeId: 'water',
    minimum: 1000,
  );
  const anyChoice = AutoCompleteRule.measurable(dataTypeId: 'hydration');
  const steps = AutoCompleteRule.health(
    dataType: 'cumulative_step_count',
    minimum: 6000,
  );

  group('unboundChoiceMeasurables', () {
    test('strips both bounds from a choice leaf and keeps its title', () {
      expect(
        unboundChoiceMeasurables(boundedChoice, isChoice),
        const AutoCompleteRule.measurable(
          dataTypeId: 'hydration',
          title: 'Pee check',
        ),
      );
    });

    test('returns the very same instance when nothing needs changing', () {
      for (final rule in [
        boundedWater,
        anyChoice,
        steps,
        const AutoCompleteRule.workout(dataType: 'running', minimum: 30),
        const AutoCompleteRule.habit(habitId: 'floss'),
      ]) {
        expect(
          identical(unboundChoiceMeasurables(rule, isChoice), rule),
          isTrue,
        );
      }
      // A composite of untouched leaves is untouched too.
      const composite = AutoCompleteRule.and(rules: [boundedWater, steps]);
      expect(
        identical(unboundChoiceMeasurables(composite, isChoice), composite),
        isTrue,
      );
    });

    test('an unknown measurable is left alone — its kind is not known', () {
      expect(
        identical(
          unboundChoiceMeasurables(boundedChoice, (_) => false),
          boundedChoice,
        ),
        isTrue,
      );
    });

    test('recurses through and / or / multiple, keeping their shape', () {
      const nested = AutoCompleteRule.multiple(
        rules: [
          AutoCompleteRule.or(
            rules: [boundedChoice, steps],
            title: 'either',
          ),
          AutoCompleteRule.and(rules: [boundedWater, boundedChoice]),
        ],
        successes: 2,
        title: 'two of',
      );
      expect(
        unboundChoiceMeasurables(nested, isChoice),
        const AutoCompleteRule.multiple(
          rules: [
            AutoCompleteRule.or(
              rules: [
                AutoCompleteRule.measurable(
                  dataTypeId: 'hydration',
                  title: 'Pee check',
                ),
                steps,
              ],
              title: 'either',
            ),
            AutoCompleteRule.and(
              rules: [
                boundedWater,
                AutoCompleteRule.measurable(
                  dataTypeId: 'hydration',
                  title: 'Pee check',
                ),
              ],
            ),
          ],
          successes: 2,
          title: 'two of',
        ),
      );
    });
  });
}
