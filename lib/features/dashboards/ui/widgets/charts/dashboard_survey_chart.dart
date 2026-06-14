import 'dart:core';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/dashboards/state/survey_chart_controller.dart';
import 'package:lotti/features/dashboards/state/survey_data.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_multiline_chart.dart';
import 'package:lotti/features/surveys/tools/run_surveys.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

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
    final provider = surveyChartDataControllerProvider(
      surveyType: chartConfig.surveyType,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );

    final itemsAsync = ref.watch(provider);
    final items = itemsAsync.value ?? const [];

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
      chartHeader: DashboardChartHeader(
        title: chartConfig.surveyName,
        action: DashboardChartAddButton(
          tooltip: context.messages.dashboardTakeSurveyTooltip,
          onPressed: onTapAdd,
        ),
      ),
      isLoading: itemsAsync.isLoading && !itemsAsync.hasValue,
      isEmpty: items.isEmpty,
      emptyMessage: context.messages.dashboardChartNoData,
      height: 180,
    );
  }
}
