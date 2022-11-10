import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';

final sleepAutoComplete = HabitAutoCompleteOr(
  a: HabitAutoComplete.and(
    a: HabitAutoCompleteHealth(
      dataType: 'HealthDataType.SLEEP_ASLEEP_CORE',
      minimum: 360,
    ),
    b: HabitAutoComplete.measurable(
      dataTypeId: 'dataTypeId',
      minimum: 2000,
    ),
  ),
  b: HabitAutoCompleteHealth(
    dataType: 'HealthDataType.SLEEP_ASLEEP_REM',
    minimum: 60,
  ),
);

class HabitAutocompleteWidget extends StatefulWidget {
  const HabitAutocompleteWidget(this.habitAutoComplete, {super.key});

  final HabitAutoComplete? habitAutoComplete;

  @override
  State<HabitAutocompleteWidget> createState() =>
      _HabitAutocompleteWidgetState();
}

class _HabitAutocompleteWidgetState extends State<HabitAutocompleteWidget> {
  @override
  Widget build(BuildContext context) {
    const spacer = SizedBox(height: 8, width: 8);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ColoredBox(
        color: Colors.grey.withOpacity(0.6),
        child: widget.habitAutoComplete?.map(
          health: (health) {
            return Container(
              color: Colors.blue.withOpacity(0.5),
              padding: const EdgeInsets.all(8),
              child: Text(
                '${health.dataType.substring(15)} '
                ' ${health.minimum != null ? 'min: ${health.minimum}' : ''}'
                ' ${health.maximum != null ? 'max: ${health.maximum}' : ''}',
              ),
            );
          },
          measurable: (measurable) {
            return Container(
              color: Colors.green.withOpacity(0.5),
              padding: const EdgeInsets.all(8),
              child: Text('Measurable $measurable'),
            );
          },
          and: (and) {
            return Row(
              children: [
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('AND'),
                ),
                Column(
                  children: [
                    spacer,
                    HabitAutocompleteWidget(and.a),
                    spacer,
                    HabitAutocompleteWidget(and.b),
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
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('OR'),
                ),
                Column(
                  children: [
                    spacer,
                    HabitAutocompleteWidget(or.a),
                    spacer,
                    HabitAutocompleteWidget(or.b),
                    spacer,
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
