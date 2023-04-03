import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/measurable_utils.dart';

class MeasurementSuggestions extends StatelessWidget {
  const MeasurementSuggestions({
    required this.measurableDataType,
    required this.saveMeasurement,
    required this.measurementTime,
    super.key,
  });

  final MeasurableDataType measurableDataType;
  final DateTime measurementTime;

  final Future<void> Function({
    required MeasurableDataType measurableDataType,
    required DateTime measurementTime,
    num? value,
  }) saveMeasurement;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<JournalEntity>>(
      stream: getIt<JournalDb>().watchMeasurementsByType(
        type: measurableDataType.id,
        rangeStart: DateTime.now().subtract(const Duration(days: 90)),
        rangeEnd: DateTime.now().add(const Duration(days: 1)),
      ),
      builder: (
        BuildContext context,
        AsyncSnapshot<List<JournalEntity>> measurementsSnapshot,
      ) {
        final popularValues = rankedByPopularity(
          measurements: measurementsSnapshot.data,
        );

        return Wrap(
          spacing: 5,
          runSpacing: 5,
          children: popularValues.map((num value) {
            final regex = RegExp(r'([.]*0)(?!.*\d)');
            final label = value.toDouble().toString().replaceAll(regex, '');

            void onPressed() => saveMeasurement(
                  value: value,
                  measurableDataType: measurableDataType,
                  measurementTime: measurementTime,
                );

            return ActionChip(
              onPressed: onPressed,
              label: Text(label),
              disabledColor: styleConfig().primaryColor,
            );
          }).toList(),
        );
      },
    );
  }
}
