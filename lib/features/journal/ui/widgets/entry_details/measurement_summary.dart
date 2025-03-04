import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/ui/widgets/helpers.dart';
import 'package:lotti/features/journal/ui/widgets/text_viewer_widget.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';

class MeasurementSummary extends StatelessWidget {
  const MeasurementSummary(
    this.measurementEntry, {
    super.key,
  });

  final MeasurementEntry measurementEntry;

  @override
  Widget build(BuildContext context) {
    final data = measurementEntry.data;

    final dataType =
        getIt<EntitiesCacheService>().getDataTypeById(data.dataTypeId);

    if (dataType == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (measurementEntry.entryText?.plainText != null)
            TextViewerWidget(
              entryText: measurementEntry.entryText,
              maxHeight: 120,
            ),
          Padding(
            padding: const EdgeInsets.only(left: 5),
            child: EntryTextWidget(
              entryTextForMeasurable(data, dataType),
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
