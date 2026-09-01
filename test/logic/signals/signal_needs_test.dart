import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/logic/signals/signal_needs.dart';

void main() {
  test('collects each series once across a nested tree', () {
    const rule = AutoCompleteRule.or(
      rules: [
        AutoCompleteRule.and(
          rules: [
            AutoCompleteRule.measurable(dataTypeId: 'water'),
            AutoCompleteRule.health(dataType: 'cumulative_step_count'),
            AutoCompleteRule.workout(dataType: 'running'),
          ],
        ),
        AutoCompleteRule.multiple(
          rules: [
            AutoCompleteRule.measurable(dataTypeId: 'water'),
            AutoCompleteRule.habit(habitId: 'habit-a'),
          ],
          successes: 1,
        ),
      ],
    );
    final needs = SignalNeeds.of(rule);
    expect(needs.measurableIds, {'water'});
    expect(needs.quantitativeTypes, {'cumulative_step_count'});
    expect(needs.workoutTypes, {'running'});
    expect(needs.habitIds, {'habit-a'});
    expect(needs.isEmpty, isFalse);
  });

  group('notificationTokens', () {
    test('expands a workout type to every spelling, the rest verbatim', () {
      const rule = AutoCompleteRule.and(
        rules: [
          AutoCompleteRule.measurable(dataTypeId: 'water'),
          AutoCompleteRule.health(dataType: 'cumulative_step_count'),
          AutoCompleteRule.workout(dataType: 'RUNNING'),
          AutoCompleteRule.habit(habitId: 'habit-a'),
        ],
      );
      expect(SignalNeeds.of(rule).notificationTokens, {
        'water',
        'cumulative_step_count',
        'running',
        'RUNNING',
        'habit-a',
      });
    });

    // A rule persisted in either era must be told about a workout stored in
    // the other: the row notifies under its stored type only.
    test('a plugin-era rule hears a canonical write and vice versa', () {
      const pluginEra = AutoCompleteRule.workout(dataType: 'RUNNING');
      const canonical = AutoCompleteRule.workout(dataType: 'running');
      expect(
        SignalNeeds.of(pluginEra).notificationTokens,
        contains('running'),
      );
      expect(
        SignalNeeds.of(canonical).notificationTokens,
        contains('RUNNING'),
      );
    });

    test('covers the alias family', () {
      expect(
        SignalNeeds.of(
          const AutoCompleteRule.workout(dataType: 'cycling'),
        ).notificationTokens,
        {'cycling', 'CYCLING', 'biking', 'BIKING'},
      );
    });

    test('is empty for an empty tree', () {
      expect(
        SignalNeeds.of(
          const AutoCompleteRule.and(rules: []),
        ).notificationTokens,
        isEmpty,
      );
    });
  });

  test('an empty composite needs nothing', () {
    expect(
      SignalNeeds.of(const AutoCompleteRule.and(rules: [])).isEmpty,
      isTrue,
    );
  });
}
