import 'dart:core';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/dashboards/state/health_chart_controller.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/stale_async_value.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/utils.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/charts/utils.dart';

/// Blood-pressure chart card: a dual-line chart plotting systolic (alert.error)
/// and diastolic (alert.info) over the range, with dashed reference lines at
/// 120 and 80 mmHg and a two-entry legend.
///
/// Watches both `BLOOD_PRESSURE_SYSTOLIC` and `BLOOD_PRESSURE_DIASTOLIC`
/// observation providers and keeps each series' last value via its own
/// [StaleValue] so a span change doesn't flash the card empty. Stateful (rather
/// than using [StaleAsyncValue]) precisely because it stitches together two
/// independent async streams.
class DashboardHealthBpChart extends ConsumerStatefulWidget {
  const DashboardHealthBpChart({
    required this.rangeStart,
    required this.rangeEnd,
    this.embedded = false,
    super.key,
  });

  final DateTime rangeStart;
  final DateTime rangeEnd;
  final bool embedded;

  @override
  ConsumerState<DashboardHealthBpChart> createState() =>
      _DashboardHealthBpChartState();
}

class _DashboardHealthBpChartState
    extends ConsumerState<DashboardHealthBpChart> {
  final StaleValue<List<Observation>> _systolic = StaleValue();
  final StaleValue<List<Observation>> _diastolic = StaleValue();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final systolicColor = tokens.colors.alert.error.defaultColor;
    final diastolicColor = tokens.colors.alert.info.defaultColor;

    final systolicAsync = ref.watch(
      healthObservationsControllerProvider((
        healthDataType: 'HealthDataType.BLOOD_PRESSURE_SYSTOLIC',
        rangeStart: widget.rangeStart,
        rangeEnd: widget.rangeEnd,
      )),
    );
    final diastolicAsync = ref.watch(
      healthObservationsControllerProvider((
        healthDataType: 'HealthDataType.BLOOD_PRESSURE_DIASTOLIC',
        rangeStart: widget.rangeStart,
        rangeEnd: widget.rangeEnd,
      )),
    );
    final systolicData =
        _systolic.resolve(systolicAsync) ?? const <Observation>[];
    final diastolicData =
        _diastolic.resolve(diastolicAsync) ?? const <Observation>[];
    final isLoading =
        _systolic.isInitialLoading(systolicAsync) ||
        _diastolic.isInitialLoading(diastolicAsync);

    return DashboardChart(
      chart: Padding(
        padding: EdgeInsets.only(
          top: tokens.spacing.step5,
          right: tokens.spacing.step2,
        ),
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: 20,
              getDrawingHorizontalLine: (value) {
                if (value == 80.0) {
                  return chartEmphasisLine(
                    diastolicColor.withValues(alpha: 0.5),
                  );
                }
                if (value == 120.0) {
                  return chartEmphasisLine(
                    systolicColor.withValues(alpha: 0.5),
                  );
                }

                return chartGridLine(context);
              },
            ),
            clipData: const FlClipData.horizontal(),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                tooltipMargin: isMobile ? 24 : 16,
                tooltipPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                getTooltipColor: (_) => tokens.colors.background.level03,
                tooltipBorderRadius: BorderRadius.circular(8),
                getTooltipItems: (List<LineBarSpot> spots) {
                  return spots.map((spot) {
                    return LineTooltipItem(
                      '',
                      TextStyle(
                        fontSize: fontSizeSmall,
                        fontWeight: FontWeight.w300,
                        color: tokens.colors.text.highEmphasis,
                      ),
                      children: [
                        TextSpan(
                          text: '${spot.y.toInt()} mmHg\n',
                          style: chartTooltipStyleBold,
                        ),
                        TextSpan(
                          text: chartDateFormatterFull(spot.x),
                          style: chartTooltipStyle,
                        ),
                      ],
                    );
                  }).toList();
                },
              ),
            ),
            titlesData: const FlTitlesData(
              rightTitles: AxisTitles(),
              topTitles: AxisTitles(),
              bottomTitles: AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 20,
                  getTitlesWidget: leftTitleWidgets,
                  reservedSize: kChartLeftAxisWidth,
                  minIncluded: false,
                  maxIncluded: false,
                ),
              ),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border.all(color: tokens.colors.decorative.level01),
            ),
            minX: widget.rangeStart.millisecondsSinceEpoch.toDouble(),
            maxX: widget.rangeEnd.millisecondsSinceEpoch.toDouble(),
            lineBarsData: [
              LineChartBarData(
                spots: systolicData
                    .map(
                      (item) => FlSpot(
                        item.dateTime.millisecondsSinceEpoch.toDouble(),
                        item.value.toDouble(),
                      ),
                    )
                    .toList(),
                isCurved: true,
                color: systolicColor,
                curveSmoothness: 0.1,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
              ),
              LineChartBarData(
                spots: diastolicData
                    .map(
                      (item) => FlSpot(
                        item.dateTime.millisecondsSinceEpoch.toDouble(),
                        item.value.toDouble(),
                      ),
                    )
                    .toList(),
                isCurved: true,
                curveSmoothness: 0.1,
                color: diastolicColor,
                isStrokeCapRound: true,
                dotData: const FlDotData(
                  show: false,
                ),
              ),
            ],
          ),
          duration: Duration.zero,
        ),
      ),
      dateAxis: DashboardChartDateAxis(
        rangeStart: widget.rangeStart,
        rangeEnd: widget.rangeEnd,
      ),
      chartHeader: BpChartInfoWidget(embedded: widget.embedded),
      isLoading: isLoading,
      isEmpty: systolicData.isEmpty && diastolicData.isEmpty,
      emptyMessage: context.messages.dashboardChartNoData,
      embedded: widget.embedded,
      footer: DashboardChartLegend(
        entries: [
          DashboardLegendEntry(
            color: systolicColor,
            label: context.messages.dashboardHealthSystolic,
          ),
          DashboardLegendEntry(
            color: diastolicColor,
            label: context.messages.dashboardHealthDiastolic,
          ),
        ],
      ),
      height: widget.embedded ? 140 : 220,
    );
  }
}

/// Header for the blood-pressure card: localized "Blood pressure" title with a
/// "mmHg" unit subtitle.
class BpChartInfoWidget extends StatelessWidget {
  const BpChartInfoWidget({this.embedded = false, super.key});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    // Embedded in an entry card the host names the metric, so the chart's own
    // title would duplicate it — drop the header and keep just the trend +
    // legend.
    if (embedded) return const SizedBox.shrink();

    return DashboardChartHeader(
      title: context.messages.dashboardHealthBloodPressure,
      subtitle: 'mmHg',
    );
  }
}
