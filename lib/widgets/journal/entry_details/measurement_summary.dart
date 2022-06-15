import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/widgets/charts/dashboard_measurables_chart.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';
import 'package:lotti/widgets/journal/helpers.dart';
import 'package:lotti/widgets/journal/text_viewer_widget.dart';

class MeasurementSummary extends StatelessWidget {
  MeasurementSummary(
    this.measurementEntry, {
    super.key,
  });

  final JournalDb _db = getIt<JournalDb>();
  final MeasurementEntry measurementEntry;

  @override
  Widget build(BuildContext context) {
    final data = measurementEntry.data;

    return StreamBuilder<MeasurableDataType?>(
        stream: _db.watchMeasurableDataTypeById(data.dataTypeId),
        builder: (
          BuildContext context,
          AsyncSnapshot<MeasurableDataType?> typeSnapshot,
        ) {
          final dataType = typeSnapshot.data;

          if (dataType == null) {
            return const SizedBox.shrink();
          }

          return Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (measurementEntry.entryText?.plainText != null)
                  TextViewerWidget(entryText: measurementEntry.entryText),
                DashboardMeasurablesChart(
                  rangeStart: getRangeStart(context: context),
                  rangeEnd: getRangeEnd(),
                  measurableDataTypeId: measurementEntry.data.dataTypeId,
                ),
                const SizedBox(height: 8),
                EntryTextWidget(
                  entryTextForMeasurable(data, dataType),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          );
        },);
  }
}
