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

  test('an empty composite needs nothing', () {
    expect(
      SignalNeeds.of(const AutoCompleteRule.and(rules: [])).isEmpty,
      isTrue,
    );
  });
}
