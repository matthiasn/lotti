import 'package:flutter/material.dart';
import 'package:lotti/beamer/beamer_delegates.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/measurable_utils.dart';

class MeasurementSuggestions extends StatelessWidget {
  const MeasurementSuggestions({
    required this.measurableDataType,
    super.key,
  });

  final MeasurableDataType measurableDataType;

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
          spacing: 10,
          runSpacing: 10,
          children: popularValues.map((num value) {
            final regex = RegExp(r'([.]*0)(?!.*\d)');
            final label = value.toDouble().toString().replaceAll(regex, '');
            final unit = measurableDataType.unitName;

            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () async {
                  final now = DateTime.now();
                  await getIt<PersistenceLogic>().createMeasurementEntry(
                    data: MeasurementData(
                      dataTypeId: measurableDataType.id,
                      dateTo: now,
                      dateFrom: now,
                      value: value,
                    ),
                    private: measurableDataType.private ?? false,
                  );
                  dashboardsBeamerDelegate.beamBack();
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 8,
                    ),
                    color: styleConfig().primaryColor,
                    child: Text('$label $unit'),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
