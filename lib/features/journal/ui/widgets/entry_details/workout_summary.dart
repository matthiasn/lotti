import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/ui/widgets/helpers.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/widgets/charts/dashboard_workout_chart.dart';
import 'package:lotti/widgets/charts/dashboard_workout_config.dart';
import 'package:lotti/widgets/charts/utils.dart';

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

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showChart)
            ...items.map(
              (DashboardWorkoutItem item) => DashboardWorkoutChart(
                chartConfig: item,
                rangeStart: getRangeStart(context: context),
                rangeEnd: getRangeEnd(),
              ),
            ),
          const SizedBox(height: 8),
          EntryTextWidget(entryTextForWorkout(data)),
        ],
      ),
    );
  }
}
