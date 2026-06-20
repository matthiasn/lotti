import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/dashboards/config/dashboard_workout_config.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_workout_chart.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/ui/widgets/helpers.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/widgets/charts/utils.dart';

/// Detail-view summary for a workout entry: optional per-metric charts for the
/// workout type plus the formatted energy/duration text. Pass `showChart:
/// false` for the compact list-card variant.
class WorkoutSummary extends StatelessWidget {
  const WorkoutSummary(
    this.workoutEntry, {
    this.showChart = true,
    super.key,
  });

  final WorkoutEntry workoutEntry;
  final bool showChart;

  @override
  Widget build(BuildContext context) {
    final data = workoutEntry.data;
    final items = <DashboardWorkoutItem>[];
    final workoutType = workoutEntry.data.workoutType;

    workoutTypes.forEach((key, value) {
      if (key.contains(workoutType)) {
        items.add(value);
      }
    });

    final tokens = context.designTokens;
    // Lead with the Energy/Duration value lines (the facts users scan for);
    // the per-metric trend charts are secondary context below them. When the
    // charts are shown they already title the workout type, so drop the
    // redundant heading line. No outer bottom padding — the card shell owns
    // the symmetric inset.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EntryTextWidget(
          entryTextForWorkout(data, includeTitle: !showChart),
          padding: EdgeInsets.zero,
        ),
        // A real section break so the value lines are not crowded against the
        // chart frame(s) below them.
        if (showChart) SizedBox(height: tokens.spacing.sectionGap),
        if (showChart)
          ...items.map(
            (DashboardWorkoutItem item) => DashboardWorkoutChart(
              chartConfig: item,
              rangeStart: getRangeStart(context: context),
              rangeEnd: getRangeEnd(),
            ),
          ),
      ],
    );
  }
}
