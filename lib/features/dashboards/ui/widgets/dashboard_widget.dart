import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intersperse/intersperse.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/dashboards/state/dashboards_page_controller.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_health_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_measurables_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_survey_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_workout_chart.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/charts/habits/dashboard_habits_chart.dart';

/// Renders a dashboard's ordered list of items as a vertical stack of chart
/// cards over the shared `[rangeStart, rangeEnd]` window.
///
/// Acts as the dispatcher from each `DashboardItem` variant to its chart widget
/// (measurement, health, workout, survey, habit). Each chart is keyed by item
/// *identity* (not list position or range) so a chart's
/// stale-while-revalidate state stays attached to its item across edits and
/// span changes — preventing a new item from briefly showing a sibling's cached
/// data. Optionally shows the dashboard name as a title and its description as a
/// caption.
class DashboardWidget extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardByIdProvider(dashboardId));

    if (dashboard == null) {
      return const SizedBox.shrink();
    }

    // Key each chart by its item identity (NOT the range): the charts retain
    // their last data across range changes (stale-while-revalidate), so the
    // State must follow the item, not its position. Without identity keys, an
    // edit that replaces an item with another of the same widget type at the
    // same index would reuse the old State — and briefly show the previous
    // item's cached data under the new item's header.
    final items = dashboard.items.map((DashboardItem dashboardItem) {
      switch (dashboardItem) {
        case final DashboardMeasurementItem measurement:
          return MeasurablesBarChart(
            key: ValueKey(
              'measurement:${measurement.id}:'
              '${measurement.aggregationType}',
            ),
            measurableDataTypeId: measurement.id,
            aggregationType: measurement.aggregationType,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            enableCreate: true,
          );
        case final DashboardHealthItem health:
          return DashboardHealthChart(
            key: ValueKey('health:${health.healthType}'),
            chartConfig: health,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          );
        case final DashboardWorkoutItem workout:
          return DashboardWorkoutChart(
            key: ValueKey(
              'workout:${workout.workoutType}:${workout.valueType}',
            ),
            chartConfig: workout,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          );

        case final DashboardSurveyItem survey:
          return DashboardSurveyChart(
            key: ValueKey('survey:${survey.surveyType}'),
            chartConfig: survey,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          );
        case final DashboardHabitItem habit:
          return DashboardHabitsChart(
            key: ValueKey('habit:${habit.habitId}'),
            habitId: habit.habitId,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          );
      }
    });

    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.only(top: tokens.spacing.step5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showTitle)
            Padding(
              padding: EdgeInsets.only(bottom: tokens.spacing.step3),
              child: Text(
                dashboard.name,
                style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                  color: tokens.colors.text.highEmphasis,
                ),
              ),
            ),
          ...intersperse(
            SizedBox(height: tokens.spacing.cardItemSpacing),
            items.whereType<Widget>(),
          ),
          if (dashboard.description.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: tokens.spacing.step4),
              child: Text(
                dashboard.description,
                style: tokens.typography.styles.others.caption.copyWith(
                  color: tokens.colors.text.lowEmphasis,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
