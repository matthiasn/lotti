import 'package:flutter/material.dart';
import 'package:intersperse/intersperse.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/charts/dashboard_health_chart.dart';
import 'package:lotti/widgets/charts/dashboard_measurables_chart.dart';
import 'package:lotti/widgets/charts/dashboard_survey_chart.dart';
import 'package:lotti/widgets/charts/dashboard_workout_chart.dart';
import 'package:lotti/widgets/charts/habits/dashboard_habits_chart.dart';
import 'package:lotti/widgets/charts/stories/dashboard_story_chart.dart';
import 'package:lotti/widgets/charts/stories/wildcard_story_chart.dart';

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
    return StreamBuilder<List<DashboardDefinition>>(
      stream: getIt<JournalDb>().watchDashboardById(dashboardId),
      builder: (context, snapshot) {
        DashboardDefinition? dashboard;

        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data ?? [];
        if (data.isNotEmpty) {
          dashboard = data.first;
        }

        final items = dashboard!.items.map((DashboardItem dashboardItem) {
          return dashboardItem.map(
            measurement: (DashboardMeasurementItem measurement) {
              return DashboardMeasurablesChart(
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
              return DashboardStoryChart(
                chartConfig: storyChart,
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
              );
            },
            wildcardStoryTimeChart: (WildcardStoryTimeItem storyChart) {
              return Column(
                children: [
                  WildcardStoryChart(
                    chartConfig: storyChart,
                    rangeStart: rangeStart,
                    rangeEnd: rangeEnd,
                  ),
                  const SizedBox(height: 10),
                  WildcardStoryWeeklyChart(
                    chartConfig: storyChart,
                    rangeStart: rangeStart,
                    rangeEnd: rangeEnd,
                  ),
                ],
              );
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
                  style: taskTitleStyle(),
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
                        style: chartTitleStyle(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.dashboard_customize_outlined),
                    color: styleConfig().primaryTextColor,
                    onPressed: () =>
                        beamToNamed('/settings/dashboards/$dashboardId'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
