import 'package:flutter/material.dart';
import 'package:intersperse/intersperse.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/themes/theme.dart';

final testAutoComplete = AutoCompleteRule.and(
  rules: [
    AutoCompleteRule.or(
      rules: [
        AutoCompleteRule.multiple(
          successes: 5,
          rules: [
            AutoCompleteRule.measurable(
              dataTypeId: 'push-ups',
              minimum: 25,
            ),
            AutoCompleteRule.measurable(
              dataTypeId: 'pull-ups',
              minimum: 10,
            ),
            AutoCompleteRule.measurable(
              dataTypeId: 'sit-ups',
              minimum: 70,
            ),
            AutoCompleteRule.measurable(
              dataTypeId: 'lunges',
              minimum: 30,
            ),
            AutoCompleteRule.measurable(
              dataTypeId: 'plank',
              minimum: 70,
            ),
            AutoCompleteRule.measurable(
              dataTypeId: 'squats',
              minimum: 10,
            ),
          ],
        ),
        AutoCompleteRule.workout(
          dataType: 'functionalStrengthTraining.duration',
          minimum: 30,
        ),
      ],
    ),
    AutoCompleteRule.or(
      rules: [
        AutoCompleteRule.health(
          dataType: 'cumulative_step_count',
          minimum: 10000,
        ),
        AutoCompleteRule.workout(
          dataType: 'walking.duration',
          minimum: 60,
        ),
        AutoCompleteRule.workout(
          dataType: 'swimming.duration',
          minimum: 20,
        ),
        AutoCompleteRule.workout(
          dataType: 'cycling.duration',
          minimum: 120,
        ),
      ],
    ),
    AutoCompleteRule.measurable(
      dataTypeId: 'water',
      minimum: 2000,
    ),
  ],
);

class HabitAutocompleteWidget extends StatefulWidget {
  const HabitAutocompleteWidget(this.autoCompleteRule, {super.key});

  final AutoCompleteRule? autoCompleteRule;

  @override
  State<HabitAutocompleteWidget> createState() =>
      _HabitAutocompleteWidgetState();
}

class _HabitAutocompleteWidgetState extends State<HabitAutocompleteWidget> {
  @override
  Widget build(BuildContext context) {
    const spacer = SizedBox(height: 10, width: 15);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ColoredBox(
        color: Colors.grey.withOpacity(0.6),
        child: widget.autoCompleteRule?.map(
          health: (health) {
            return Container(
              color: Colors.blue.withOpacity(0.5),
              padding: const EdgeInsets.all(8),
              child: Text(
                '${health.dataType}'
                '${health.minimum != null ? ', min: ${health.minimum}' : ''}'
                '${health.maximum != null ? ', max: ${health.maximum}' : ''}',
                style: monospaceTextStyle(),
              ),
            );
          },
          workout: (workout) {
            return Container(
              color: Colors.blue.withOpacity(0.5),
              padding: const EdgeInsets.all(8),
              child: Text(
                '${workout.dataType}'
                '${workout.minimum != null ? ', min: ${workout.minimum}' : ''}'
                '${workout.maximum != null ? ', max: ${workout.maximum}' : ''}',
                style: monospaceTextStyle(),
              ),
            );
          },
          measurable: (measurable) {
            return Container(
              color: Colors.green.withOpacity(0.5),
              padding: const EdgeInsets.all(8),
              child: Text(
                '${measurable.dataTypeId}'
                '${measurable.minimum != null ? ', min: ${measurable.minimum}' : ''}'
                '${measurable.maximum != null ? ', max: ${measurable.maximum}' : ''}',
                style: monospaceTextStyle(),
              ),
            );
          },
          and: (and) {
            return Row(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    'AND',
                    style: monospaceTextStyle()
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    spacer,
                    ...intersperse(
                      spacer,
                      and.rules.map(HabitAutocompleteWidget.new),
                    ),
                    spacer,
                  ],
                ),
                spacer,
              ],
            );
          },
          or: (or) {
            return Row(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    'OR',
                    style: monospaceTextStyle()
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    spacer,
                    ...intersperse(
                      spacer,
                      or.rules.map(HabitAutocompleteWidget.new),
                    ),
                    spacer,
                  ],
                ),
                spacer,
              ],
            );
          },
          multiple: (multiple) {
            final n = multiple.rules.length;

            return Row(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    '${multiple.successes}/$n',
                    style: monospaceTextStyle()
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    spacer,
                    ...intersperse(
                      spacer,
                      multiple.rules.map(HabitAutocompleteWidget.new),
                    ),
                    spacer,
                  ],
                ),
                spacer,
              ],
            );
          },
        ),
      ),
    );
  }
}
