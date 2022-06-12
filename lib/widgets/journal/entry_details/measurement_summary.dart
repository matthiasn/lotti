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
  final JournalDb _db = getIt<JournalDb>();

  MeasurementSummary(
    this.measurementEntry, {
    Key? key,
  }) : super(key: key);

  final MeasurementEntry measurementEntry;

  @override
  Widget build(BuildContext context) {
    MeasurementData data = measurementEntry.data;

    return StreamBuilder<MeasurableDataType?>(
        stream: _db.watchMeasurableDataTypeById(data.dataTypeId),
        builder: (
          BuildContext context,
          AsyncSnapshot<MeasurableDataType?> typeSnapshot,
        ) {
          MeasurableDataType? dataType = typeSnapshot.data;

          if (dataType == null) {
            return const SizedBox.shrink();
          }

          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (measurementEntry.entryText?.plainText != null)
                  TextViewerWidget(entryText: measurementEntry.entryText),
                EntryTextWidget(
                  entryTextForMeasurable(data, dataType),
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(height: 16),
                DashboardMeasurablesChart(
                  rangeStart: getRangeStart(context: context),
                  rangeEnd: getRangeEnd(),
                  measurableDataTypeId: measurementEntry.data.dataTypeId,
                ),
              ],
            ),
          );
        });
  }
}
