import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/dashboards/state/measurables_controller.dart';

class MeasurementSuggestions extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final popularValues = ref
        .watch(
          measurableSuggestionsControllerProvider(
            measurableDataTypeId: measurableDataType.id,
          ),
        )
        .valueOrNull;

    if (popularValues == null) {
      return const SizedBox.shrink();
    }

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
          disabledColor: Theme.of(context).primaryColor,
        );
      }).toList(),
    );
  }
}
