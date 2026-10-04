part of 'goal_progress_card.dart';

class _MetricTrendSeries extends StatelessWidget {
  const _MetricTrendSeries({required this.metric, required this.today});

  final GoalMetricProgressView metric;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final range = _metricDateRange([metric]);
    if (range == null) return const SizedBox.shrink();
    final actual = goalMetricObservations(metric);
    final averages = goalMetricSevenDayAverage(metric, today: today);
    final actualColor = tokens.colors.interactive.enabled;
    final averageColor = tokens.colors.alert.info.defaultColor;
    final targetColor = tokens.colors.alert.warning.defaultColor;
    final isSteps = metric.sourceId == GoalHealthDataTypes.steps;
    final actualLabel = _metricTitle(context, metric);
    final yValues = <num>[
      metric.target,
      ...actual.map((observation) => observation.value),
      ...averages.map((observation) => observation.value),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: tokens.spacing.step13,
          child: isSteps
              ? TimeSeriesBarLineChart(
                  barData: actual,
                  lineData: averages,
                  rangeStart: range.start,
                  rangeEnd: range.end,
                  maxVal: yValues.reduce(math.max),
                  barColor: actualColor,
                  lineColor: averageColor,
                  barLabel: actualLabel,
                  lineLabel: context.messages.goalChartSevenDayAverage,
                  unit: metric.unitName ?? '',
                  dateOnly: true,
                  horizontalLines: [
                    _targetLine(metric.target, targetColor),
                  ],
                )
              : TimeSeriesMultiLineChart(
                  lineBarsData: [
                    timeSeriesAreaLine(data: actual, color: actualColor),
                    if (averages.isNotEmpty)
                      _metricAverageLine(averages, averageColor),
                  ],
                  rangeStart: range.start,
                  rangeEnd: range.end,
                  minVal: yValues.reduce(math.min),
                  maxVal: yValues.reduce(math.max),
                  unit: metric.unitName ?? '',
                  dateOnly: true,
                  seriesLabels: [
                    actualLabel,
                    if (averages.isNotEmpty)
                      context.messages.goalChartSevenDayAverage,
                  ],
                  horizontalLines: [
                    _targetLine(metric.target, targetColor),
                  ],
                ),
        ),
        DashboardChartDateAxis(
          rangeStart: range.start,
          rangeEnd: range.end,
          dateOnly: true,
        ),
        SizedBox(height: tokens.spacing.step3),
        // One entry per line drawn, and nothing else. The fourth entry used to
        // be a sentence — "Current below 7-day average · toward target",
        // coloured green or red — which is a reading of the data, not a key to
        // it: a legend swatch that matched no mark on the chart, in a hue that
        // meant something different from every other hue in the card.
        SizedBox(
          width: double.infinity,
          child: DashboardChartLegend(
            alignment: WrapAlignment.center,
            entries: [
              DashboardLegendEntry(color: actualColor, label: actualLabel),
              if (averages.isNotEmpty)
                DashboardLegendEntry(
                  color: averageColor,
                  label: context.messages.goalChartSevenDayAverage,
                  // The corner quotes this same figure as "Ø …" in this same
                  // hue; colour is the only thing tying the two together, so
                  // the legend that resolves the symbol has to wear it.
                  labelWearsSeriesColor: true,
                ),
              DashboardLegendEntry(
                color: targetColor,
                label: context.messages.habitsGoalLineLabel,
                annotation: _targetThreshold(context, metric),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

LineChartBarData _metricAverageLine(
  List<Observation> observations,
  Color color,
) {
  final style = chartEmphasisLine(color);
  return LineChartBarData(
    spots: [
      for (final observation in observations)
        FlSpot(
          observation.dateTime.millisecondsSinceEpoch.toDouble(),
          observation.value.toDouble(),
        ),
    ],
    color: style.color,
    barWidth: style.strokeWidth,
    dashArray: style.dashArray,
    isStrokeCapRound: true,
    dotData: const FlDotData(show: false),
  );
}

class _MetricHealthSeries extends StatelessWidget {
  const _MetricHealthSeries({required this.metric});

  final GoalMetricProgressView metric;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final range = _metricDateRange([metric]);
    if (range == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: tokens.spacing.step13,
          child: TimeSeriesLineChart(
            data: goalMetricObservations(metric),
            rangeStart: range.start,
            rangeEnd: range.end,
            unit: metric.unitName ?? '',
            dateOnly: true,
            horizontalLines: [
              _targetLine(
                metric.target,
                tokens.colors.interactive.enabled,
              ),
            ],
          ),
        ),
        DashboardChartDateAxis(
          rangeStart: range.start,
          rangeEnd: range.end,
          dateOnly: true,
        ),
      ],
    );
  }
}

class _MetricProgressSeries extends StatelessWidget {
  const _MetricProgressSeries({required this.metric, this.scrollGroup});

  final LinkedScrollGroup? scrollGroup;

  final GoalMetricProgressView metric;

  /// Height of the plot area. Shared with the minimum-bar floor below, so a
  /// change here cannot silently leave an observed-but-tiny day invisible.
  static double _chartHeight(DsTokens tokens) => tokens.spacing.step9;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final maxValue = metric.days.fold<num>(
      metric.target,
      (current, day) => day.value > current ? day.value : current,
    );
    // A "nice" axis so the two ticks the plot labels are rounded values a
    // reader can trust, rather than the raw series maximum. The gutter is the
    // page-wide one every plot and date axis shares.
    final axis = niceAxis(0, maxValue, zeroBased: true);
    final chartHeight = _chartHeight(tokens);
    return LayoutBuilder(
      builder: (context, constraints) {
        final plotWidth = math.max<double>(
          constraints.maxWidth - kChartLeftAxisWidth,
          0,
        );
        final metrics = dayTrackMetrics(context);
        final contentWidth = metrics.pitch * metric.days.length;
        final track = _track(context, axis.max, metrics);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The span, on the plot's own rail rather than the card's — it
            // labels the bars, so it starts where they start.
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: kChartLeftAxisWidth,
              ),
              child: Text(
                _periodLabel(context, metric.days),
                style: tokens.typography.styles.others.caption.copyWith(
                  color: tokens.colors.text.lowEmphasis,
                ),
              ),
            ),
            SizedBox(height: tokens.spacing.step3),
            SizedBox(
              height: chartHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PlotValueAxis(axis: axis),
                  Expanded(
                    child: Stack(
                      children: [
                        if (axis.max > 0 && metric.targetIsPerDay)
                          _TargetRule(
                            target: metric.target,
                            axisMax: axis.max,
                            height: chartHeight,
                          ),
                        Positioned.fill(
                          child: fitOrScrollDayTrack(
                            contentWidth: contentWidth,
                            availableWidth: plotWidth,
                            group: scrollGroup,
                            child: track,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: tokens.spacing.step1),
            // The date axis: one caption per bar, on the bars' own grid.
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: kChartLeftAxisWidth,
              ),
              child: _WeekdayTrack(
                days: metric.days,
                trackId: 'metric-${metric.criterionId}',
                metrics: metrics,
              ),
            ),
            SizedBox(height: tokens.spacing.step3),
            SizedBox(
              width: double.infinity,
              child: DashboardChartLegend(
                alignment: WrapAlignment.center,
                entries: _legendEntries(context, tokens),
              ),
            ),
          ],
        );
      },
    );
  }

  /// The three fills a bar can wear, plus the threshold its rule marks.
  List<DashboardLegendEntry> _legendEntries(
    BuildContext context,
    DsTokens tokens,
  ) => [
    DashboardLegendEntry(
      color: dayMarkStateFill(tokens, DayMarkState.full),
      label: context.messages.goalMetricLegendOnTarget,
    ),
    DashboardLegendEntry(
      color: dayMarkStateFill(tokens, DayMarkState.partial),
      label: context.messages.goalMetricLegendOffTarget,
    ),
    DashboardLegendEntry(
      color: dayMarkStateFill(tokens, DayMarkState.none),
      label: context.messages.goalProgressHabitDayNoEntry,
    ),
    if (metric.targetIsPerDay)
      DashboardLegendEntry(
        color: tokens.colors.decorative.level01,
        label: context.messages.habitsGoalLineLabel,
        annotation: _targetThreshold(context, metric),
      ),
  ];

  /// The bars on the page's shared day grid.
  ///
  /// `DayTrack` with [dayTrackMetrics], exactly like the habit squares
  /// and the whole-goal strip: a plain Row with fixed gaps matched the default
  /// pitch but not the text-scale-expanded one, so at raised text scales the
  /// bars' Wednesday drifted away from the Wednesday one card above.
  Widget _track(
    BuildContext context,
    num maxValue,
    DayTrackMetrics metrics,
  ) {
    final tokens = context.designTokens;
    final height = _chartHeight(tokens);
    // Built once for the whole track rather than per bar: a ninety-day span
    // was constructing ninety date formats, ninety number formats and ninety
    // tooltip decorations on every build, for a popup at most one of them
    // will ever show.
    final locale = Localizations.localeOf(context).toString();
    final chrome = (
      dateFormat: DateFormat.MMMd(locale),
      number: NumberFormat.decimalPattern(locale),
      tooltip: chartTooltipDecoration(context),
      unit: metric.unitName?.trim() ?? '',
    );
    return DayTrack(
      height: height,
      pitch: metrics.pitch,
      children: [
        for (final day in metric.days)
          // A tight box, not a loose slot. `_bar` is a FractionallySizedBox
          // whose Stack expands against its parent, so it needs bounded
          // dimensions or every bar collapses to zero — an invisible chart.
          SizedBox(
            width: daySquareSize(context),
            height: height,
            child: _bar(context, day, maxValue, chrome),
          ),
      ],
    );
  }

  Widget _bar(
    BuildContext context,
    GoalProgressDay day,
    num maxValue,
    _BarChrome chrome,
  ) {
    final tokens = context.designTokens;
    final date = chrome.dateFormat.format(day.day);
    final number = chrome.number;
    // The shared per-day policy: a bar drawn against a per-day target rule
    // is met by the day's own value OR by the window verdict as of that
    // day, so a 12,400-step day beats a 10,000 target even when the trailing
    // week's average is still short, and a short day inside an on-target
    // week is not a failure. Only a period-total criterion keeps the window
    // verdict alone, because no single bar can be read against a
    // whole-period target.
    final met = metric.dayMark(day);
    final status = !day.isObserved
        ? 'missing'
        : met
        ? 'met'
        : 'missed';
    final rawHeightFactor = maxValue == 0
        ? 0.0
        : (day.value / maxValue).clamp(0, 1).toDouble();
    final minimumObservedHeight = tokens.spacing.step2 / _chartHeight(tokens);
    final heightFactor =
        day.isObserved && rawHeightFactor < minimumObservedHeight
        ? minimumObservedHeight
        : rawHeightFactor;
    final barFill = DecoratedBox(
      decoration: BoxDecoration(
        // Three states, three fills. `background.level03` is what the legend
        // one card above defines as ABSENCE, so a logged day that fell short
        // must not wear it — it was measured, and that is a different fact
        // from a day with no data. Met is the day-cell success fill; short is
        // the muted wash of the same family; unobserved keeps the neutral.
        color: !day.isObserved
            ? dayMarkStateFill(tokens, DayMarkState.none)
            : dayMarkStateFill(
                tokens,
                met ? DayMarkState.full : DayMarkState.partial,
              ),
        border: !day.isObserved
            ? Border.all(
                color: tokens.colors.text.lowEmphasis,
                width: BorderWidths.emphasis,
              )
            : null,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(tokens.radii.s),
        ),
      ),
    );
    final provenance = metric.agentRecordedProvenanceByDay[day.day];
    final unit = chrome.unit;
    return Semantics(
      label: context.messages.goalMetricBarSemantics(
        status,
        date,
        number.format(day.value),
        number.format(metric.target),
      ),
      // Tap to read the day off the chart. These bars are painted by hand
      // rather than by fl_chart, so they had no tooltip at all: a tracked
      // 45-minute afternoon was on screen with no way to find out it was 45.
      child: Tooltip(
        triggerMode: TooltipTriggerMode.tap,
        decoration: chrome.tooltip,
        richMessage: chartTooltipMessage(
          context,
          date: date,
          entries: [
            (
              label: metric.name,
              value: day.isObserved
                  ? [
                      formatGoalAggregate(number, day.value),
                      if (unit.isNotEmpty) unit,
                    ].join(' ')
                  : context.messages.goalProgressHabitDayNoEntry,
            ),
          ],
        ),
        child: ExcludeSemantics(
          child: Stack(
            // Expand, so the fractional bar still measures against the plot
            // height rather than shrink-wrapping to nothing.
            fit: StackFit.expand,
            children: [
              FractionallySizedBox(
                key: ValueKey(
                  'goal-metric-bar-${day.day.toIso8601String().substring(0, 10)}',
                ),
                heightFactor: heightFactor,
                alignment: Alignment.bottomCenter,
                child: barFill,
              ),
              // A full-height sibling of the bar, not a child of it. Inside the
              // fractional box a short bar — 4px against a 12px icon — hosted
              // most of the badge outside its own bounds, so the visible part
              // could not be hovered. Anchored from the bottom instead, it sits
              // at the bar's top when there is room and rests on the baseline
              // when there is not.
              if (metric.agentRecordedDays.contains(day.day))
                Positioned(
                  right: 0,
                  bottom: math.max(
                    0,
                    _chartHeight(tokens) * heightFactor - IconSizes.xs,
                  ),
                  child: Tooltip(
                    message: provenance == null
                        ? context.messages.goalDimensionRecordedByAgent
                        : context.messages.goalDimensionRecordedByAgentDetails(
                            provenance.agentName,
                            deviceTimestampLabel(
                              context,
                              provenance.recordedAt,
                            ),
                          ),
                    child: Icon(
                      LottiIcons.editNote,
                      size: IconSizes.xs,
                      color: GoalAccentHues.aurora(
                        Theme.of(context).brightness,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The value axis a hand-painted plot is read against: the scale's ceiling and
/// its floor, on the same gutter every fl_chart plot on the page reserves.
///
/// Two ticks rather than a full ladder — these bars are a compact strip inside
/// a card, and the numbers exist to give the silhouette a magnitude, not to
/// support reading a value off the grid. Tapping a bar gives the exact figure.
class _PlotValueAxis extends StatelessWidget {
  const _PlotValueAxis({required this.axis});

  final NiceAxis axis;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: kChartLeftAxisWidth,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ChartLabel(formatAxisValue(axis.max)),
        ChartLabel(formatAxisValue(axis.min)),
      ],
    ),
  );
}

/// The per-day target, drawn across the plot.
///
/// Clamped to leave the rule's own thickness inside the plot: a target at the
/// axis ceiling would otherwise land on the clipped top edge, invisible in
/// exactly the case it matters most — a goal that is still behind.
class _TargetRule extends StatelessWidget {
  const _TargetRule({
    required this.target,
    required this.axisMax,
    required this.height,
  });

  final num target;
  final double axisMax;
  final double height;

  @override
  Widget build(BuildContext context) => Positioned(
    key: const ValueKey('goal-metric-target-rule'),
    left: 0,
    right: 0,
    bottom: math.min(
      height * (target / axisMax).clamp(0, 1),
      height - BorderWidths.hairline,
    ),
    child: SizedBox(
      height: BorderWidths.hairline,
      child: ColoredBox(color: context.designTokens.colors.decorative.level01),
    ),
  );
}

/// The formatters and decoration one bar track shares across its bars.
typedef _BarChrome = ({
  DateFormat dateFormat,
  NumberFormat number,
  BoxDecoration tooltip,
  String unit,
});

class _CategoryBandSeries extends StatelessWidget {
  const _CategoryBandSeries({required this.metric});

  final GoalMetricProgressView metric;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final range = metric.dailyTimeRange!;
    final allSessions = metric.categoryTimeSessions;
    final sessions = allSessions.length <= 24
        ? allSessions
        : allSessions.sublist(allSessions.length - 24);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: tokens.spacing.step8,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final bandSegments = _bandSegments(range);
              return Stack(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: tokens.colors.background.level03,
                      borderRadius: BorderRadius.circular(tokens.radii.s),
                    ),
                    child: const SizedBox.expand(),
                  ),
                  for (final segment in bandSegments)
                    Positioned(
                      left: width * segment.$1,
                      width: width * (segment.$2 - segment.$1),
                      top: 0,
                      bottom: 0,
                      child: ColoredBox(
                        color: tokens.colors.alert.warning.defaultColor
                            .withValues(alpha: SurfaceAlphas.tint),
                      ),
                    ),
                  for (final session in sessions)
                    Positioned(
                      left: width * _minuteFraction(session.dateFrom),
                      width: math.max(
                        tokens.spacing.step1,
                        width *
                            session.duration.inMinutes.clamp(1, 1440) /
                            1440,
                      ),
                      top: tokens.spacing.step2,
                      bottom: tokens.spacing.step2,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: _startsInBand(session.dateFrom, range)
                              ? tokens.colors.alert.warning.defaultColor
                              : tokens.colors.interactive.enabled,
                          borderRadius: BorderRadius.circular(tokens.radii.xs),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        SizedBox(height: tokens.spacing.step1),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final hour in const [0, 7, 12, 22, 24])
              Text(
                hour.toString().padLeft(2, '0'),
                style: tokens.typography.styles.others.caption.copyWith(
                  color: tokens.colors.text.lowEmphasis,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

List<(double, double)> _bandSegments(GoalDailyTimeRange range) {
  final start = range.startMinute / 1440;
  final end = range.endMinute / 1440;
  return range.startMinute < range.endMinute
      ? [(start, end)]
      : [(0, end), (start, 1)];
}

double _minuteFraction(DateTime date) => (date.hour * 60 + date.minute) / 1440;
bool _startsInBand(DateTime date, GoalDailyTimeRange range) {
  final minute = date.hour * 60 + date.minute;
  return range.startMinute < range.endMinute
      ? minute >= range.startMinute && minute < range.endMinute
      : minute >= range.startMinute || minute < range.endMinute;
}

class _CategoryPatternCard extends StatelessWidget {
  const _CategoryPatternCard({required this.metric});

  final GoalMetricProgressView metric;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final bins = List<int>.filled(24, 0);
    for (final session in metric.categoryTimeSessions) {
      bins[session.dateFrom.hour]++;
    }
    final maxCount = bins.fold<int>(1, math.max);
    final busiestHour = bins.indexOf(maxCount);
    final dailyTimeRange = metric.dailyTimeRange;
    return DesignSystemSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LottiIcons.insights,
                color: tokens.colors.alert.warning.defaultColor,
              ),
              SizedBox(width: tokens.spacing.step2),
              Text(
                '${context.messages.goalPatternTitle} · ${metric.name}',
                style: tokens.typography.styles.subtitle.subtitle2,
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.step4),
          SizedBox(
            height: tokens.spacing.step8,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var hour = 0; hour < bins.length; hour++)
                  Expanded(
                    child: FractionallySizedBox(
                      heightFactor: bins[hour] / maxCount,
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: BorderWidths.hairline,
                        ),
                        child: ColoredBox(
                          color:
                              dailyTimeRange != null &&
                                  _startsInBand(
                                    DateTime(2000, 1, 1, hour),
                                    dailyTimeRange,
                                  )
                              ? tokens.colors.alert.warning.defaultColor
                              : tokens.colors.interactive.enabled,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: tokens.spacing.step3),
          _DimensionSummaryNote(
            text: context.messages.goalPatternBusiestHour(
              busiestHour.toString().padLeft(2, '0'),
            ),
          ),
        ],
      ),
    );
  }
}
