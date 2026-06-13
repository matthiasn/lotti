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

class DashboardWidget extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardByIdProvider(dashboardId));

    if (dashboard == null) {
      return const SizedBox.shrink();
    }

    final items = dashboard.items.map((DashboardItem dashboardItem) {
      switch (dashboardItem) {
        case final DashboardMeasurementItem measurement:
          return MeasurablesBarChart(
            measurableDataTypeId: measurement.id,
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
              padding: EdgeInsets.only(
                top: tokens.spacing.step4,
                left: tokens.spacing.step2,
                right: tokens.spacing.step2,
              ),
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
