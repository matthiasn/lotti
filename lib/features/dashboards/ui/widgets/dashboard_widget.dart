import 'package:flutter/material.dart';
import 'package:intersperse/intersperse.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_measurables_chart.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/charts/dashboard_health_chart.dart';
import 'package:lotti/widgets/charts/dashboard_survey_chart.dart';
import 'package:lotti/widgets/charts/dashboard_workout_chart.dart';
import 'package:lotti/widgets/charts/habits/dashboard_habits_chart.dart';

class DashboardWidget extends StatelessWidget {
  const DashboardWidget({
    required this.rangeStart,
    required this.rangeEnd,
    required this.dashboardId,
    super.key,
    this.showTitle = false,
  });

  final DateTime rangeStart;
  final DateTime rangeEnd;
  final String dashboardId;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final dashboard = getIt<EntitiesCacheService>().getDashboardById(
      dashboardId,
    );

    if (dashboard == null) {
      return const SizedBox.shrink();
    }

    final items = dashboard.items.map((DashboardItem dashboardItem) {
      return dashboardItem.map(
        measurement: (DashboardMeasurementItem measurement) {
          return MeasurablesBarChart(
            measurableDataTypeId: measurement.id,
            dashboardId: dashboardId,
            aggregationType: measurement.aggregationType,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            enableCreate: true,
          );
        },
        healthChart: (DashboardHealthItem healthChart) {
          return DashboardHealthChart(
            chartConfig: healthChart,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          );
        },
        workoutChart: (DashboardWorkoutItem workoutChart) {
          return DashboardWorkoutChart(
            chartConfig: workoutChart,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          );
        },
        storyTimeChart: (DashboardStoryTimeItem storyChart) {
          return const Text('Story Time Chart currently not implemented');
        },
        wildcardStoryTimeChart: (WildcardStoryTimeItem storyChart) {
          return const SizedBox.shrink();
        },
        surveyChart: (DashboardSurveyItem surveyChart) {
          return DashboardSurveyChart(
            chartConfig: surveyChart,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          );
        },
        habitChart: (DashboardHabitItem habitItem) {
          return DashboardHabitsChart(
            habitId: habitItem.habitId,
            dashboardId: dashboardId,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          );
        },
      );
    });

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          if (showTitle)
            Text(
              dashboard.name,
              style: taskTitleStyle,
            ),
          ...intersperse(const SizedBox(height: 16), items),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Text(
                    dashboard.description,
                    style: chartTitleStyle,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
