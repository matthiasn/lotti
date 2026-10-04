part of 'goal_progress_card.dart';

class _HabitDimensionCard extends StatelessWidget {
  const _HabitDimensionCard({
    required this.habit,
    required this.today,
    required this.onHabitOutcomeSelected,
    this.scrollGroup,
    this.verdictsByDay = const {},
  });

  final LinkedScrollGroup? scrollGroup;

  /// The user's per-day verdicts on this habit, keyed by UTC day.
  final Map<DateTime, DayVerdict> verdictsByDay;
  final GoalHabitProgressView habit;
  final DateTime today;
  final GoalHabitOutcomeSelected? onHabitOutcomeSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final successfulWeeks =
        habit.window == const GoalWindow.rollingDays(count: 7)
        ? habit.successfulWeeks
        : null;
    // The shallow foot pays for the centering slack an interactive day track
    // leaves under its squares — so it is only right on a card that actually
    // ENDS on that track. A check-off callout closes some cards, and it is a
    // bordered surface that would sit crowded against the card edge with the
    // slack stranded above it instead.
    final endsOnDayTrack =
        !(onHabitOutcomeSelected != null &&
            habit.suggestedFromDimensionName != null);
    return DesignSystemSectionCard(
      // An interactive day row is already a touch-floor-tall track around a
      // cell half its height, so the card gets ~10px of centering slack under
      // the squares for free. On the cards that end there, a full
      // card-padding foot on top of that slack left a band of dead space
      // taller than the squares themselves.
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step5,
        tokens.spacing.step5,
        tokens.spacing.step5,
        endsOnDayTrack ? tokens.spacing.step2 : tokens.spacing.step5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DimensionHeader(
            kind: GoalDimensionKind.habit,
            title: habit.name,
            source: context.messages.goalDimensionHabitSource,
            // The reading names its window CONCRETELY — "1 of 3 · calendar
            // week" — because the track below can show several windows'
            // worth of days, and "this window" read as a claim about the
            // whole visible span. Past the target the "X of Y" frame stops
            // parsing — "6 of 3" reads as a broken fraction rather than as
            // three completions to spare — so an exceeded quota states the
            // count and names the target beside it.
            reading: habit.successesInWindow > habit.targetCount
                ? context.messages.goalDimensionHabitReadingOverTargetWindowed(
                    habit.successesInWindow,
                    habit.targetCount,
                    goalWindowLabel(context, habit.window),
                  )
                : context.messages.goalDimensionHabitReadingWindowed(
                    habit.successesInWindow,
                    habit.targetCount,
                    goalWindowLabel(context, habit.window),
                  ),
            met: habit.deficit == 0,
            hasData: true,
          ),
          // step2: with the deficit note and the reliability tail both riding
          // the window line, the header sits directly above ONE caption row —
          // and that row belongs to the squares under it, not to the header.
          SizedBox(height: tokens.spacing.step2),
          _HabitProgressRow(
            habit: habit,
            today: today,
            onOutcomeSelected: onHabitOutcomeSelected,
            verdictsByDay: verdictsByDay,
            scrollGroup: scrollGroup,
            // The six-week tail rides the window line above the squares
            // rather than taking a row under them: both facts describe the
            // same window, and stacked they cost the card a row to say so.
            successfulWeeks: successfulWeeks,
          ),
        ],
      ),
    );
  }
}

typedef _BloodPressureMetrics = ({
  GoalMetricProgressView systolic,
  GoalMetricProgressView diastolic,
});
typedef _MetricSummary = ({
  num current,
  num latest,
  bool hasData,
  bool latestOnTargetToday,
  bool met,
});
_BloodPressureMetrics? _bloodPressureMetrics(
  List<GoalMetricProgressView> metrics,
) {
  GoalMetricProgressView? systolic;
  GoalMetricProgressView? diastolic;
  for (final metric in metrics) {
    if (metric.sourceId == GoalHealthDataTypes.bloodPressureSystolic) {
      systolic ??= metric;
    } else if (metric.sourceId == GoalHealthDataTypes.bloodPressureDiastolic) {
      diastolic ??= metric;
    }
  }
  if (systolic == null || diastolic == null) return null;
  final systolicUnit = systolic.unitName?.trim() ?? '';
  final diastolicUnit = diastolic.unitName?.trim() ?? '';
  final compatibleDays = listEquals(
    systolic.days.map((day) => day.day).toList(),
    diastolic.days.map((day) => day.day).toList(),
  );
  final systolicHasData = systolic.days.any((day) => day.isObserved);
  final diastolicHasData = diastolic.days.any((day) => day.isObserved);
  if (systolicHasData != diastolicHasData ||
      systolic.window != diastolic.window ||
      systolic.aggregation != diastolic.aggregation ||
      systolicUnit != diastolicUnit ||
      !compatibleDays) {
    return null;
  }
  return (systolic: systolic, diastolic: diastolic);
}

/// Whether a day counts toward a `count` criterion, by the SAME rule the
/// evaluator uses.
///
/// `GoalProgressEvaluator` passes `countPositiveValues: true` for category
/// time alone; every other kind counts each observed day whatever its value.
/// Applying the positive-value rule everywhere made a zero-to-positive metric
/// day read as progress the evaluator's own tally never saw.
bool _countsTowardTally(GoalMetricProgressView metric, GoalProgressDay day) =>
    day.isObserved &&
    (metric.kind != GoalDimensionKind.categoryTime || day.value > 0);
_MetricSummary _metricSummary(
  GoalMetricProgressView metric, {
  required DateTime today,
}) {
  final observed = metric.days.where((day) => day.isObserved).toList()
    ..sort((a, b) => a.day.compareTo(b.day));
  // The evaluator's own figure wins. Recomputing here produced a different
  // number over a different set of days, so the card's headline and the
  // agent's report could quote two values for one week.
  final current =
      metric.evaluatedActual ??
      switch (metric.aggregation) {
        GoalAggregation.dailySumThenAverage when observed.isNotEmpty =>
          observed.fold<num>(0, (sum, day) => sum + day.value) /
              observed.length,
        GoalAggregation.max when observed.isNotEmpty => observed.fold<num>(
          observed.first.value,
          (value, day) => math.max(value, day.value),
        ),
        // The same qualification rule as the improvement check above, so the
        // number shown and the sentence under it cannot disagree about a day.
        GoalAggregation.count =>
          observed.where((day) => _countsTowardTally(metric, day)).length,
        _ => observed.fold<num>(0, (sum, day) => sum + day.value),
      };
  final meetsPeriodTarget = switch (metric.direction) {
    GoalDirection.atLeast => current >= metric.target,
    GoalDirection.atMost => current <= metric.target,
  };
  final latestDay = observed.lastOrNull;
  final isSupportedHealth = GoalHealthDataTypes.supported.contains(
    metric.sourceId,
  );
  final latestOnTargetToday =
      isSupportedHealth &&
      latestDay != null &&
      DateUtils.isSameDay(latestDay.day, today) &&
      _valueMeetsTarget(latestDay.value, metric.target, metric.direction);
  return (
    current: current,
    // The most recent observation. Point-sample vitals display this instead
    // of the period aggregate. An on-target reading recorded today also gets
    // a positive daily presentation without changing the persisted rolling
    // evaluation result.
    latest: observed.isEmpty ? 0 : observed.last.value,
    hasData: observed.isNotEmpty,
    latestOnTargetToday: latestOnTargetToday,
    met:
        observed.isNotEmpty &&
        (meetsPeriodTarget ||
            (!isSupportedHealth && metric.projectedOnTrack) ||
            latestOnTargetToday),
  );
}

bool _valueMeetsTarget(num value, num target, GoalDirection direction) =>
    switch (direction) {
      GoalDirection.atLeast => value >= target,
      GoalDirection.atMost => value <= target,
    };

/// What the dimension header quotes as "current": the latest sample for
/// point-sample health vitals (blood pressure, weight), the period aggregate
/// for everything that is genuinely a sum/count/average target (steps,
/// measurables, tracked time).
num _metricDisplayValue(
  GoalMetricProgressView metric,
  _MetricSummary summary,
) => GoalHealthDataTypes.supported.contains(metric.sourceId)
    ? summary.latest
    : summary.current;

class _BloodPressureDimensionCard extends StatelessWidget {
  const _BloodPressureDimensionCard({
    required this.metrics,
    required this.today,
    this.scrollGroup,
  });

  final LinkedScrollGroup? scrollGroup;
  final _BloodPressureMetrics metrics;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final number = NumberFormat.decimalPattern(locale);
    final systolic = _metricSummary(metrics.systolic, today: today);
    final diastolic = _metricSummary(metrics.diastolic, today: today);
    final hasData = systolic.hasData && diastolic.hasData;
    final met = hasData && systolic.met && diastolic.met;
    final onTargetToday =
        systolic.latestOnTargetToday && diastolic.latestOnTargetToday;
    final systolicColor = tokens.colors.alert.error.defaultColor;
    final diastolicColor = tokens.colors.alert.info.defaultColor;
    final range = _metricDateRange([metrics.systolic, metrics.diastolic]);
    final unit = metrics.systolic.unitName?.trim() ?? '';
    final unitSuffix = unit.isEmpty ? '' : ' $unit';
    final yValues = <num>[
      metrics.systolic.target,
      metrics.diastolic.target,
      ...metrics.systolic.days
          .where((day) => day.isObserved)
          .map((day) => day.value),
      ...metrics.diastolic.days
          .where((day) => day.isObserved)
          .map((day) => day.value),
    ];
    final reading = hasData
        ? '${formatGoalAggregate(number, _metricDisplayValue(metrics.systolic, systolic))} / '
              '${formatGoalAggregate(number, _metricDisplayValue(metrics.diastolic, diastolic))}'
              '$unitSuffix'
        : '—';
    return DesignSystemSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DimensionHeader(
            kind: GoalDimensionKind.health,
            title: context.messages.dashboardHealthBloodPressure,
            source: context.messages.goalDimensionHealthSource,
            reading: reading,
            met: met,
            hasData: hasData,
            onTargetToday: onTargetToday,
          ),
          // No data, no plot: an empty frame with a date range under it and
          // nothing between them reads as a chart that failed to draw.
          if (range != null && hasData) ...[
            SizedBox(height: tokens.spacing.step4),
            SizedBox(
              height: tokens.spacing.step13,
              child: TimeSeriesMultiLineChart(
                lineBarsData: [
                  _bloodPressureLine(metrics.systolic, systolicColor),
                  _bloodPressureLine(metrics.diastolic, diastolicColor),
                ],
                rangeStart: range.start,
                rangeEnd: range.end,
                minVal: yValues.reduce(math.min),
                maxVal: yValues.reduce(math.max),
                unit: unit,
                dateOnly: true,
                seriesLabels: [
                  context.messages.dashboardHealthSystolic,
                  context.messages.dashboardHealthDiastolic,
                ],
                horizontalLines: [
                  _targetLine(metrics.systolic.target, systolicColor),
                  _targetLine(metrics.diastolic.target, diastolicColor),
                ],
              ),
            ),
            DashboardChartDateAxis(
              rangeStart: range.start,
              rangeEnd: range.end,
              dateOnly: true,
            ),
            SizedBox(height: tokens.spacing.step3),
            // Two lines, two entries. Each carries its own threshold as a
            // quiet annotation instead of claiming a second swatch of the
            // same hue. Centered: the legend annotates the card, it is not a
            // row in the leading-aligned data stack.
            SizedBox(
              width: double.infinity,
              child: DashboardChartLegend(
                alignment: WrapAlignment.center,
                entries: [
                  DashboardLegendEntry(
                    color: systolicColor,
                    label: context.messages.dashboardHealthSystolic,
                    annotation: _targetAnnotation(context, metrics.systolic),
                  ),
                  DashboardLegendEntry(
                    color: diastolicColor,
                    label: context.messages.dashboardHealthDiastolic,
                    annotation: _targetAnnotation(context, metrics.diastolic),
                  ),
                ],
              ),
            ),
          ]
          // See [_MetricDimensionCard]: only the no-data case says something
          // the header's status caption does not.
          else ...[
            SizedBox(height: tokens.spacing.step3),
            _DimensionSummaryNote(
              text: context.messages.goalDimensionNoDataNote,
            ),
          ],
        ],
      ),
    );
  }
}

/// The one-sentence reading under a signal card, centered under the legend
/// it concludes — the balanced closing line of the card rather than another
/// left-ragged data row.
class _DimensionSummaryNote extends StatelessWidget {
  const _DimensionSummaryNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return SizedBox(
      width: double.infinity,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: tokens.typography.styles.body.bodySmall.copyWith(
          color: tokens.colors.text.mediumEmphasis,
        ),
      ),
    );
  }
}

LineChartBarData _bloodPressureLine(
  GoalMetricProgressView metric,
  Color color,
) {
  final observations = goalMetricObservations(metric);
  return LineChartBarData(
    spots: observations
        .map(
          (item) => FlSpot(
            item.dateTime.millisecondsSinceEpoch.toDouble(),
            item.value.toDouble(),
          ),
        )
        .toList(),
    color: color,
    isStrokeCapRound: true,
    dotData: FlDotData(show: observations.length == 1),
  );
}

HorizontalLine _targetLine(num target, Color color) {
  // Full-strength hue: the dash already separates threshold from series,
  // and the target the user is chasing must not be the faintest mark.
  final style = chartEmphasisLine(color);
  return HorizontalLine(
    y: target.toDouble(),
    color: style.color,
    strokeWidth: style.strokeWidth,
    dashArray: style.dashArray,
  );
}

/// The threshold a series' dashed rule marks, as a quiet qualifier for that
/// series' OWN legend entry: "Target ≤ 125".
///
/// It is deliberately not a legend entry of its own. Blood pressure listed
/// "Systolic" and "Systolic · Target ≤ 125" as two equal entries in one hue,
/// so a two-line chart wore a four-entry legend in which half the entries
/// named no line at all.
String _targetAnnotation(
  BuildContext context,
  GoalMetricProgressView metric,
) =>
    '${context.messages.habitsGoalLineLabel} '
    '${_targetThreshold(context, metric)}';

/// The bare comparison — "≥ 10,000" — for a legend entry whose own label is
/// already the word "Target".
String _targetThreshold(BuildContext context, GoalMetricProgressView metric) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  // A step target is a round number in the thousands and the direction is
  // never in doubt — nobody sets a ceiling on their steps — so it reads as
  // the figure alone, compactly: "Goal 10k", not "Goal ≥ 10,000".
  if (metric.sourceId == GoalHealthDataTypes.steps) {
    return NumberFormat.compact(locale: locale).format(metric.target);
  }
  final direction = switch (metric.direction) {
    GoalDirection.atLeast => '≥',
    GoalDirection.atMost => '≤',
  };
  return '$direction ${NumberFormat.decimalPattern(locale).format(metric.target)}';
}

({DateTime start, DateTime end})? _metricDateRange(
  Iterable<GoalMetricProgressView> metrics,
) {
  final days =
      metrics.expand((metric) => metric.days).map((day) => day.day).toList()
        ..sort();
  if (days.isEmpty) return null;
  return (start: days.first, end: days.last);
}

String _metricTitle(BuildContext context, GoalMetricProgressView metric) =>
    metric.sourceId == GoalHealthDataTypes.steps
    ? context.messages.goalChartStepsPerDay
    : metric.name;

/// What ONE day's value of [metric] is called.
///
/// Distinct from the card title, which names the series: a steps criterion is
/// authored as "Average steps per day" and titled "Steps per day", but a single
/// day's figure is neither an average nor a rate — it is that day's step count,
/// and the reflection sheet printed 9,950 under the word "Average".
String goalMetricDayRowLabel(
  BuildContext context,
  GoalMetricProgressView metric,
) => metric.sourceId == GoalHealthDataTypes.steps
    ? context.messages.goalChartStepsDaily
    : metric.name;
String _metricSource(BuildContext context, GoalMetricProgressView metric) =>
    metric.sourceId == GoalHealthDataTypes.steps
    ? context.messages.goalCreateStepsTargetLabel
    : _dimensionSource(context, metric.kind);

class _MetricDimensionCard extends StatelessWidget {
  const _MetricDimensionCard({
    required this.metric,
    required this.today,
    this.scrollGroup,
  });

  final LinkedScrollGroup? scrollGroup;
  final GoalMetricProgressView metric;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final summary = _metricSummary(metric, today: today);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final number = NumberFormat.decimalPattern(locale);
    final unit = metric.unitName?.trim();
    final displayValue = _metricDisplayValue(metric, summary);
    // A card that plots a 7-day average also draws the target as a keyed
    // legend entry ("Goal ≤ 88"), so the corner states the LATEST reading
    // alone and hands the corner's second figure to the average instead —
    // repeating the target here would spend the card's most valuable line on
    // a number already named twice below.
    final averageSeries =
        summary.hasData && goalMetricShowsSevenDayAverage(metric);
    final latestAverage = averageSeries
        ? goalMetricSevenDayAverage(metric, today: today).lastOrNull
        : null;
    // The LATEST day, not the period aggregate. `_metricDisplayValue` falls
    // through to the evaluator's actual for anything outside the
    // point-sample set, and for an "average steps per day" criterion that
    // actual IS the trailing mean — so the corner printed the average as the
    // current value and the card showed one number twice (10,100 over
    // 10,100). A card that draws the mean has to quote something else.
    final latestReading = summary.hasData ? summary.latest : displayValue;
    final reading = averageSeries
        ? _valueWithUnit(
            formatGoalAggregate(number, latestReading, against: metric.target),
            unit,
          )
        : unit == null || unit.isEmpty
        ? context.messages.goalDimensionMetricReading(
            formatGoalAggregate(number, displayValue, against: metric.target),
            formatGoalAggregate(number, metric.target, against: displayValue),
          )
        : context.messages.goalDimensionMetricReadingWithUnit(
            formatGoalAggregate(number, displayValue, against: metric.target),
            formatGoalAggregate(number, metric.target, against: displayValue),
            unit,
          );
    return DesignSystemSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DimensionHeader(
            kind: metric.kind,
            title: _metricTitle(context, metric),
            source: _metricSource(context, metric),
            reading: reading,
            met: summary.met,
            hasData: summary.hasData,
            onTargetToday: summary.latestOnTargetToday,
            averageReading: latestAverage == null
                ? null
                : '$goalAverageSymbol '
                      '${formatGoalAggregate(number, latestAverage.value)}',
            // The average LINE's hue, from the same token the series reads.
            averageColor: tokens.colors.alert.info.defaultColor,
          ),
          // Nothing observed, no plot. A dimension with no readings drew a
          // full-height empty frame — a card's worth of white under a header
          // that already says "Not enough data", which reads as a chart that
          // failed rather than as a goal nobody has fed yet. The note below
          // carries the explanation on its own.
          if (summary.hasData) ...[
            SizedBox(height: tokens.spacing.step4),
            if ((metric.kind == GoalDimensionKind.categoryTime ||
                    metric.kind == GoalDimensionKind.labelTime) &&
                metric.dailyTimeRange != null)
              _CategoryBandSeries(metric: metric)
            else if (goalMetricShowsSevenDayAverage(metric))
              _MetricTrendSeries(metric: metric, today: today)
            else if (GoalHealthDataTypes.supported.contains(metric.sourceId))
              _MetricHealthSeries(metric: metric)
            else
              _MetricProgressSeries(metric: metric, scrollGroup: scrollGroup),
          ]
          // Nothing observed: the header reads "Not enough data" but says
          // nothing about why the card is empty, so the note survives for
          // exactly that case. Every other verdict it used to carry — on
          // target, on track, behind — is the header's status caption
          // restated in a sentence, under a chart that already shows it.
          else ...[
            SizedBox(height: tokens.spacing.step3),
            _DimensionSummaryNote(
              text: context.messages.goalDimensionNoDataNote,
            ),
          ],
        ],
      ),
    );
  }
}

/// The mean, as a mark rather than a phrase.
///
/// Not localized on purpose: it is a mathematical symbol, read the same in
/// every language the app ships, and it replaces a label ("7-day average")
/// that was three times wider than the figure it introduced. The chart's own
/// legend still names the series in words, which is where a reader who does
/// not know the symbol will look.
const String goalAverageSymbol = 'Ø';

/// "93.4 kg" — a bare reading and its unit, for corners that state the
/// latest value without comparing it to anything.
String _valueWithUnit(String value, String? unit) =>
    unit == null || unit.isEmpty ? value : '$value $unit';

class _DimensionHeader extends StatelessWidget {
  const _DimensionHeader({
    required this.kind,
    required this.title,
    required this.source,
    required this.reading,
    required this.met,
    required this.hasData,
    this.averageReading,
    this.averageColor,
    this.onTargetToday = false,
  });

  final GoalDimensionKind kind;
  final String title;
  final String source;
  final String reading;
  final bool met;
  final bool hasData;

  /// The rolling 7-day average, set beside the latest reading for signals
  /// that plot one.
  ///
  /// The two figures answer different questions — "where am I right now" and
  /// "where has the week put me" — and only one of them was ever in the
  /// corner. It is tinted with [averageColor], the average LINE's own hue, so
  /// the number and the mark it summarises are keyed to each other without
  /// spending a word on saying so.
  final String? averageReading;
  final Color? averageColor;
  final bool onTargetToday;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final color = switch (kind) {
      GoalDimensionKind.habit => tokens.colors.interactive.enabled,
      GoalDimensionKind.health => tokens.colors.alert.info.defaultColor,
      GoalDimensionKind.measurable => GoalAccentHues.aurora(
        Theme.of(context).brightness,
      ),
      GoalDimensionKind.categoryTime =>
        tokens.colors.alert.warning.defaultColor,
      GoalDimensionKind.labelTime => tokens.colors.alert.warning.defaultColor,
    };
    final icon = switch (kind) {
      GoalDimensionKind.habit => LottiIcons.confirmCircled,
      GoalDimensionKind.health => LottiIcons.favorite,
      GoalDimensionKind.measurable => LottiIcons.measure,
      GoalDimensionKind.categoryTime => LottiIcons.schedule,
      GoalDimensionKind.labelTime => LottiIcons.label,
    };
    final glyph = DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: SurfaceAlphas.washControl),
        borderRadius: BorderRadius.circular(tokens.radii.s),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step2),
        child: Icon(icon, size: IconSizes.s, color: color),
      ),
    );
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: tokens.typography.styles.subtitle.subtitle2),
        Text(
          source,
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.lowEmphasis,
          ),
        ),
      ],
    );
    final statusLabel = !hasData
        ? context.messages.goalCoarseHealthNotEnoughData
        : onTargetToday
        ? context.messages.goalDimensionOnTargetTodayStatus
        : met
        ? context.messages.goalDimensionOnTrackStatus
        : context.messages.goalDimensionNeedsAttentionStatus;
    // On-target-today is good news whatever the period verdict says — the
    // positive label must never wear the warning ink.
    final statusColor = !hasData
        ? tokens.colors.text.mediumEmphasis
        : onTargetToday || met
        ? tokens.colors.alert.success.ink
        : tokens.colors.alert.warning.ink;
    // One block pinned to the card's corner: the key reading on top, its
    // verdict as a supporting caption underneath. Inline on the title row the
    // pair floated mid-row and read as two unrelated facts; stacked and
    // end-aligned it reads as a single corner element.
    final readingStyle = tokens.typography.styles.subtitle.subtitle2;
    final captionStyle = tokens.typography.styles.others.caption;
    final average = averageReading;
    // The reading LINE carries both figures side by side: the latest value,
    // and one tier down in the average line's own hue, the rolling mean.
    // That is the shape every other corner on this page already uses — a
    // habit states "7 · target 5 · rolling 7 days" on one line and drops only
    // the verdict below — and a third line here made the signal card the one
    // card whose corner was a paragraph. Size and hue tell the two apart, so
    // no separator is spent on saying they are different things, and the Ø
    // stays against the figure it summarises.
    Widget readingLine({required bool alignEnd, required bool inline}) {
      final align = alignEnd ? TextAlign.end : TextAlign.start;
      final value = Text(
        reading,
        textAlign: align,
        style: readingStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
      if (average == null) return value;
      final mean = Text(
        average,
        textAlign: align,
        style: captionStyle.copyWith(color: averageColor),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
      if (!inline) {
        return Column(
          crossAxisAlignment: alignEnd
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [value, mean],
        );
      }
      // Baselines, not box bottoms. The two figures are set at different
      // sizes, so bottom-aligning them would sit the smaller one low by the
      // difference in descent. A Wrap cannot align baselines, which is why
      // the fall back to two lines is decided by the measurement below
      // rather than left to one.
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Flexible(child: value),
          SizedBox(width: tokens.spacing.step2),
          mean,
        ],
      );
    }

    final statusStyle = captionStyle.copyWith(color: statusColor);
    Widget block({
      required bool alignEnd,
      required bool inline,
      bool statusTrailing = false,
    }) {
      final status = Text(
        statusLabel,
        textAlign: alignEnd ? TextAlign.end : TextAlign.start,
        style: statusStyle,
      );
      final reading = readingLine(alignEnd: alignEnd, inline: inline);
      if (statusTrailing) {
        // Off the corner, the block has the card's whole width, and a verdict
        // stacked under a reading that fills a fraction of it read as a line
        // of its own, unattached. On the reading's own row, at the trailing
        // edge, it sits where the corner puts it — under the figure it
        // judges — just turned sideways.
        return Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            // Expanded, not Flexible beside a Spacer: two flex children split
            // the row in half and ellipsized a reading that had room.
            Expanded(child: reading),
            SizedBox(width: tokens.spacing.step4),
            status,
          ],
        );
      }
      return Column(
        crossAxisAlignment: alignEnd
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [reading, status],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // MEASURED, not guessed. The old rule dropped the corner under the
        // title below a fixed width, so a card with room to spare still broke
        // its own layout: "92.7 kg  Ø 92.9" needs a fraction of the width
        // that breakpoint reserved for it, and the block it displaced is the
        // one thing on the card a reader looks for first.
        final valueWidth = goalTextWidth(context, reading, readingStyle);
        final meanWidth = average == null
            ? 0.0
            : goalTextWidth(context, average, captionStyle);
        final inlineWidth =
            valueWidth +
            (average == null ? 0 : tokens.spacing.step2 + meanWidth);
        final leading =
            IconSizes.s + tokens.spacing.step2 * 2 + tokens.spacing.step3;
        // The identity keeps a readable measure of its own, but never demands
        // more than one: a long signal name ellipsizes beside the corner
        // rather than pushing it onto a line of its own.
        final identityDemand = math.min(
          math.max(
            goalTextWidth(context, title, readingStyle),
            goalTextWidth(context, source, captionStyle),
          ),
          tokens.spacing.step13,
        );
        final available = math.max<double>(
          constraints.maxWidth -
              leading -
              identityDemand -
              tokens.spacing.step3,
          0,
        );
        // Three layouts, tried widest-first: both figures on one corner line,
        // the mean under the value, and only then the block off the title row
        // altogether. The status caption is left out of the test on purpose —
        // it may wrap inside the corner, which is cheaper than surrendering
        // the corner.
        final inlineFits = inlineWidth <= available;
        final stackedFits = math.max(valueWidth, meanWidth) <= available;
        if (inlineFits || stackedFits) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              glyph,
              SizedBox(width: tokens.spacing.step3),
              Expanded(child: identity),
              SizedBox(width: tokens.spacing.step3),
              // Non-flex, so the Expanded identity absorbs every spare pixel
              // and the block sits flush against the card's trailing edge — a
              // loose Flexible parked its own unused allocation AFTER the
              // block, which is what left it floating mid-row.
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: available),
                child: block(alignEnd: true, inline: inlineFits),
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                glyph,
                SizedBox(width: tokens.spacing.step3),
                Expanded(child: identity),
              ],
            ),
            SizedBox(height: tokens.spacing.step3),
            // No corner left to pin to, so the block drops below and starts
            // on the card's own rail, left of the glyph-indented identity —
            // and takes the full card width back, which is usually room
            // enough to keep both figures on one line after all.
            block(
              alignEnd: false,
              inline: inlineWidth <= constraints.maxWidth,
              statusTrailing:
                  math.min(inlineWidth, math.max(valueWidth, meanWidth)) +
                      tokens.spacing.step4 +
                      goalTextWidth(context, statusLabel, statusStyle) <=
                  constraints.maxWidth,
            ),
          ],
        );
      },
    );
  }
}
