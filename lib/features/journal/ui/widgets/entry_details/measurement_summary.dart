import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/ui/widgets/helpers.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';

/// Detail-view summary for a measurement entry: the entry's note text (if any)
/// plus the formatted `name: value unit` line. Renders nothing when the
/// measurement's data type is no longer in the cache.
class MeasurementSummary extends StatelessWidget {
  const MeasurementSummary(
    this.measurementEntry, {
    super.key,
  });

  final MeasurementEntry measurementEntry;

  @override
  Widget build(BuildContext context) {
    final data = measurementEntry.data;

    final dataType = getIt<EntitiesCacheService>().getDataTypeById(
      data.dataTypeId,
    );

    if (dataType == null) {
      return const SizedBox.shrink();
    }

    // The entry's note is rendered once by the card's editor above this
    // summary, so the summary shows only the value line (no duplicate note).
    return EntryTextWidget(
      entryTextForMeasurable(data, dataType),
      padding: EdgeInsets.zero,
    );
  }
}
