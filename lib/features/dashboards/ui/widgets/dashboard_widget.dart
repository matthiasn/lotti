import 'package:flutter/material.dart';
import 'package:intersperse/intersperse.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_health_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_measurables_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_survey_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_workout_chart.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/charts/habits/dashboard_habits_chart.dart';

class DashboardWidget extends StatelessWidget {
  const DashboardWidget({
    required this.rangeStart,
    required this.rangeEnd,
    required this.dashboardId,
    this.transformationController,
    super.key,
    this.showTitle = false,
  });

  final DateTime rangeStart;
  final DateTime rangeEnd;
  final String dashboardId;
  final bool showTitle;
  final TransformationController? transformationController;

  @override
  Widget build(BuildContext context) {
    final dashboard = getIt<EntitiesCacheService>().getDashboardById(
      dashboardId,
    );

    if (dashboard == null) {
      return const SizedBox.shrink();
    }

    final items = dashboard.items.map((DashboardItem dashboardItem) {
      switch (dashboardItem) {
        case final DashboardMeasurementItem measurement:
          return MeasurablesBarChart(
            measurableDataTypeId: measurement.id,
            dashboardId: dashboardId,
            aggregationType: measurement.aggregationType,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            enableCreate: true,
            transformationController: transformationController,
          );
        case final DashboardHealthItem health:
          return DashboardHealthChart(
            chartConfig: health,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            transformationController: transformationController,
          );
        case final DashboardWorkoutItem workout:
          return DashboardWorkoutChart(
            chartConfig: workout,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            transformationController: transformationController,
          );
        case final DashboardStoryTimeItem _:
          return const Text('Story Time Chart currently not implemented');
        case final WildcardStoryTimeItem _:
          return const SizedBox.shrink();
        case final DashboardSurveyItem survey:
          return DashboardSurveyChart(
            chartConfig: survey,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            transformationController: transformationController,
          );
        case final DashboardHabitItem habit:
          return DashboardHabitsChart(
            habitId: habit.habitId,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          );
      }
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
          ...intersperse(const SizedBox(height: 16), items.whereType<Widget>()),
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
