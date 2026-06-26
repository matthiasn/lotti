import 'dart:core';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/dashboards/state/survey_chart_controller.dart';
import 'package:lotti/features/dashboards/state/survey_data.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/stale_async_value.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_multiline_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/utils.dart';
import 'package:lotti/features/surveys/tools/run_surveys.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Chart card for a survey series (CFQ-11, GHQ-12, or PANAS): a multi-line plot
/// of each tracked score over time, with an add button that launches the
/// matching survey.
///
/// Watches [SurveyChartDataController] for survey completions, derives one line
/// per score key via `surveyLines`, and computes the shared min/max so all
/// lines share an axis. The add action dispatches to the right survey runner by
/// `surveyType`.
class DashboardSurveyChart extends ConsumerWidget {
  const DashboardSurveyChart({
    required this.chartConfig,
    required this.rangeStart,
    required this.rangeEnd,
    super.key,
  });

  final DashboardSurveyItem chartConfig;
  final DateTime rangeStart;
  final DateTime rangeEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void onTapAdd() {
      if (chartConfig.surveyType == cfq11SurveyTaskName) {
        runCfq11(
          context: context,
          themeData: Theme.of(context),
        );
      }
      if (chartConfig.surveyType == panasSurveyTaskName) {
        runPanas(
          context: context,
          themeData: Theme.of(context),
        );
      }
      if (chartConfig.surveyType == ghq12SurveyTaskName) {
        runGhq12(
          context: context,
          themeData: Theme.of(context),
        );
      }
    }

    return StaleAsyncValue<List<JournalEntity>>(
      async: ref.watch(
        surveyChartDataControllerProvider((
          surveyType: chartConfig.surveyType,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        )),
      ),
      builder: (context, value, isInitialLoading) {
        final items = value ?? const <JournalEntity>[];
        final lineBarsData = surveyLines(
          entities: items,
          dashboardSurveyItem: chartConfig,
        );
        final allSpots = lineBarsData
            .map((data) => data.spots)
            .expand((spots) => spots)
            .toList();
        final minVal = allSpots.isEmpty
            ? 0
            : allSpots.map((spot) => spot.y).reduce(min);
        final maxVal = allSpots.isEmpty
            ? 0
            : allSpots.map((spot) => spot.y).reduce(max);

        return DashboardChart(
          chart: TimeSeriesMultiLineChart(
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            lineBarsData: lineBarsData,
            minVal: minVal,
            maxVal: maxVal,
          ),
          dateAxis: DashboardChartDateAxis(
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          ),
          chartHeader: DashboardChartHeader(
            title: chartConfig.surveyName,
            action: DashboardChartAddButton(
              tooltip: context.messages.dashboardTakeSurveyTooltip,
              onPressed: onTapAdd,
            ),
          ),
          isLoading: isInitialLoading,
          isEmpty: items.isEmpty,
          emptyMessage: context.messages.dashboardChartNoData,
          height: 180,
        );
      },
    );
  }
}
