import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_line_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_multiline_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/utils.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/components/ds_dashed_border.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/model/goal_health_data_types.dart';
import 'package:lotti/features/goals/state/goal_progress_view.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/charts/utils.dart';

/// The handover's seven-cell picture used on each Agents-list row. It is
/// intentionally unlabeled visually, but exposes one concise semantic summary.
class GoalCompactWindowStrip extends StatelessWidget {
  const GoalCompactWindowStrip({required this.days, super.key});

  final List<GoalCompactDayState> days;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final visible = days.take(7).toList(growable: false);
    if (visible.isEmpty) return const SizedBox.shrink();
    return Semantics(
      label: context.messages.goalProgressCompactSemantics(
        visible.where((state) => state != GoalCompactDayState.none).length,
      ),
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < visible.length; index++) ...[
              if (index > 0) SizedBox(width: tokens.spacing.step1),
              _CompactDayCell(
                state: visible[index],
                today: index == visible.length - 1,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CompactDayCell extends StatelessWidget {
  const _CompactDayCell({required this.state, required this.today});

  final GoalCompactDayState state;
  final bool today;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final cell = Container(
      width: IconSizes.xs,
      height: IconSizes.xs,
      decoration: BoxDecoration(
        color: goalDayStateFill(tokens, state),
        borderRadius: BorderRadius.circular(tokens.radii.xs),
      ),
    );
    return today
        ? DsDashedBorder(
            color: tokens.colors.text.lowEmphasis,
            radius: tokens.radii.xs,
            child: Padding(
              padding: EdgeInsets.all(tokens.spacing.step1),
              child: cell,
            ),
          )
        : cell;
  }
}

/// Shared fill for a day cell: the full-strength success hue when the goal
/// requirement held as of that day, a lighter wash of the same hue for a
/// partial success (routine kept, target still building), neutral otherwise.
/// `SurfaceAlphas.muted` is the sanctioned "reduced-strength accent" alpha,
/// so no new color token is introduced.
Color goalDayStateFill(DsTokens tokens, GoalCompactDayState state) =>
    switch (state) {
      GoalCompactDayState.full => tokens.colors.interactive.enabled,
      GoalCompactDayState.partial =>
        tokens.colors.interactive.enabled.withValues(
          alpha: SurfaceAlphas.muted,
        ),
      GoalCompactDayState.none => tokens.colors.background.level03,
    };

/// Rolling-window detail visual. Habit routines render one row per watched
/// habit; metric goals render seven bars against the target frame.
typedef GoalHabitOutcomeSelected =
    Future<bool> Function({
      required String habitId,
      required DateTime day,
      required HabitCompletionType outcome,
    });

class GoalProgressCard extends StatelessWidget {
  const GoalProgressCard({
    required this.progress,
    this.onHabitOutcomeSelected,
    this.onReflectDay,
    super.key,
  });

  final GoalProgressView progress;
  final GoalHabitOutcomeSelected? onHabitOutcomeSelected;
  final ValueChanged<DateTime>? onReflectDay;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final patternMetrics = progress.metrics.where(
      (metric) =>
          metric.kind == GoalDimensionKind.categoryTime &&
          metric.categoryTimeSessions.isNotEmpty,
    );
    final bloodPressure = _bloodPressureMetrics(progress.metrics);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (progress.compositeRule != null) ...[
          _CompositeProgressCard(progress: progress),
          SizedBox(height: tokens.spacing.step3),
        ],
        for (final habit in progress.habits) ...[
          _HabitDimensionCard(
            habit: habit,
            today: progress.today,
            onHabitOutcomeSelected: onHabitOutcomeSelected,
          ),
          SizedBox(height: tokens.spacing.step3),
        ],
        for (final metric in progress.metrics)
          if (bloodPressure == null || metric != bloodPressure.diastolic) ...[
            if (bloodPressure != null && metric == bloodPressure.systolic)
              _BloodPressureDimensionCard(
                metrics: bloodPressure,
                today: progress.today,
              )
            else
              _MetricDimensionCard(metric: metric, today: progress.today),
            SizedBox(height: tokens.spacing.step3),
          ],
        for (final patternMetric in patternMetrics) ...[
          _CategoryPatternCard(metric: patternMetric),
          SizedBox(height: tokens.spacing.step3),
        ],
        if (onReflectDay != null)
          DesignSystemSectionCard(
            onTap: () => onReflectDay!(progress.today),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome_outlined,
                  color: tokens.colors.interactive.enabled,
                ),
                SizedBox(width: tokens.spacing.step3),
                Expanded(
                  child: Text(
                    context.messages.goalAssessmentReflectToday,
                    style: tokens.typography.styles.body.bodySmall,
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: tokens.colors.text.lowEmphasis,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CompositeProgressCard extends StatelessWidget {
  const _CompositeProgressCard({required this.progress});

  final GoalProgressView progress;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final yesterday = progress.today.subtract(const Duration(days: 1));
    final metYesterday = [
      for (final habit in progress.habits)
        habit.days.any(
          (day) => DateUtils.isSameDay(day.day, yesterday) && day.hasValue,
        ),
      for (final metric in progress.metrics)
        metric.days.any(
          (day) =>
              DateUtils.isSameDay(day.day, yesterday) &&
              metric.meetsTarget(day),
        ),
    ].where((met) => met).length;
    final required = progress.requiredSuccesses ?? progress.dimensionCount;
    return DesignSystemSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.messages.goalCompositeProgressTitle,
            style: tokens.typography.styles.subtitle.subtitle1,
          ),
          SizedBox(height: tokens.spacing.step3),
          GoalCompactWindowStrip(days: progress.compactWindow),
          SizedBox(height: tokens.spacing.step3),
          Text(
            context.messages.goalCompositeProgressSummary(
              metYesterday,
              progress.dimensionCount,
              required,
            ),
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ],
      ),
    );
  }
}

class _HabitDimensionCard extends StatelessWidget {
  const _HabitDimensionCard({
    required this.habit,
    required this.today,
    required this.onHabitOutcomeSelected,
  });

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
    return DesignSystemSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DimensionHeader(
            kind: GoalDimensionKind.habit,
            title: habit.name,
            source: context.messages.goalDimensionHabitSource,
            reading: context.messages.goalDimensionHabitReading(
              habit.successesInWindow,
              habit.targetCount,
            ),
            met: habit.deficit == 0,
            hasData: true,
          ),
          SizedBox(height: tokens.spacing.step4),
          if (habit.window == const GoalWindow.rollingDays(count: 7)) ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final compact =
                    constraints.maxWidth <
                    tokens.spacing.step13 * 2 + tokens.spacing.step5;
                final title = Text(
                  context.messages.goalProgressTitle,
                  style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                    color: tokens.colors.text.highEmphasis,
                  ),
                );
                final caption = Text(
                  compact
                      ? context.messages.goalProgressCompactCaption
                      : context.messages.goalProgressCaption,
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: tokens.colors.text.lowEmphasis,
                  ),
                );
                return compact
                    ? Row(
                        children: [
                          Flexible(child: title),
                          SizedBox(width: tokens.spacing.step3),
                          Expanded(child: caption),
                        ],
                      )
                    : Wrap(
                        spacing: tokens.spacing.step3,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [title, caption],
                      );
              },
            ),
            SizedBox(height: tokens.spacing.step2),
          ],
          _HabitProgressRow(
            habit: habit,
            today: today,
            onOutcomeSelected: onHabitOutcomeSelected,
          ),
          SizedBox(height: tokens.spacing.step4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Expanded(child: _ProgressLegend()),
              if (successfulWeeks != null) ...[
                SizedBox(width: tokens.spacing.step3),
                _Reliability(successfulWeeks: successfulWeeks),
              ],
            ],
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

_MetricSummary _metricSummary(
  GoalMetricProgressView metric, {
  required DateTime today,
}) {
  final observed = metric.days.where((day) => day.isObserved).toList()
    ..sort((a, b) => a.day.compareTo(b.day));
  final current = switch (metric.aggregation) {
    GoalAggregation.dailySumThenAverage when observed.isNotEmpty =>
      observed.fold<num>(0, (sum, day) => sum + day.value) / observed.length,
    GoalAggregation.max when observed.isNotEmpty => observed.fold<num>(
      observed.first.value,
      (value, day) => math.max(value, day.value),
    ),
    GoalAggregation.count => observed.length,
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
  });

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
        ? '${number.format(_metricDisplayValue(metrics.systolic, systolic))} / '
              '${number.format(_metricDisplayValue(metrics.diastolic, diastolic))}'
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
          if (range != null) ...[
            SizedBox(height: tokens.spacing.step4),
            Text(
              _periodLabel(context, metrics.systolic.days),
              style: tokens.typography.styles.others.caption.copyWith(
                color: tokens.colors.text.lowEmphasis,
              ),
            ),
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
            DashboardChartLegend(
              entries: [
                DashboardLegendEntry(
                  color: systolicColor,
                  label: _targetLegendLabel(
                    context,
                    context.messages.dashboardHealthSystolic,
                    metrics.systolic,
                  ),
                ),
                DashboardLegendEntry(
                  color: diastolicColor,
                  label: _targetLegendLabel(
                    context,
                    context.messages.dashboardHealthDiastolic,
                    metrics.diastolic,
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: tokens.spacing.step3),
          Text(
            !hasData
                ? context.messages.goalDimensionNoDataNote
                : onTargetToday
                ? context.messages.goalDimensionOnTargetTodayNote
                : met
                ? context.messages.goalDimensionOnTrackNote
                : context.messages.goalDimensionNeedsAttentionNote,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ],
      ),
    );
  }
}

LineChartBarData _bloodPressureLine(
  GoalMetricProgressView metric,
  Color color,
) {
  final observations = _metricObservations(metric);
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
  final style = chartEmphasisLine(
    color.withValues(alpha: SurfaceAlphas.muted),
  );
  return HorizontalLine(
    y: target.toDouble(),
    color: style.color,
    strokeWidth: style.strokeWidth,
    dashArray: style.dashArray,
  );
}

String _targetLegendLabel(
  BuildContext context,
  String name,
  GoalMetricProgressView metric,
) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final direction = switch (metric.direction) {
    GoalDirection.atLeast => '≥',
    GoalDirection.atMost => '≤',
  };
  return '$name $direction ${NumberFormat.decimalPattern(locale).format(metric.target)}';
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

List<Observation> _metricObservations(GoalMetricProgressView metric) {
  final observations =
      metric.days
          .where((day) => day.isObserved)
          .map((day) => Observation(day.day, day.value))
          .toList()
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  return observations;
}

class _MetricDimensionCard extends StatelessWidget {
  const _MetricDimensionCard({required this.metric, required this.today});

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
    final reading = unit == null || unit.isEmpty
        ? context.messages.goalDimensionMetricReading(
            number.format(displayValue),
            number.format(metric.target),
          )
        : context.messages.goalDimensionMetricReadingWithUnit(
            number.format(displayValue),
            number.format(metric.target),
            unit,
          );
    return DesignSystemSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DimensionHeader(
            kind: metric.kind,
            title: metric.name,
            source: _dimensionSource(context, metric.kind),
            reading: reading,
            met: summary.met,
            hasData: summary.hasData,
            onTargetToday: summary.latestOnTargetToday,
          ),
          SizedBox(height: tokens.spacing.step4),
          if (metric.kind == GoalDimensionKind.categoryTime &&
              metric.dailyTimeRange != null)
            _CategoryBandSeries(metric: metric)
          else if (GoalHealthDataTypes.supported.contains(metric.sourceId))
            _MetricTrendSeries(metric: metric)
          else
            _MetricProgressSeries(metric: metric),
          SizedBox(height: tokens.spacing.step3),
          Text(
            !summary.hasData
                ? context.messages.goalDimensionNoDataNote
                : summary.latestOnTargetToday
                ? context.messages.goalDimensionOnTargetTodayNote
                : summary.met
                ? context.messages.goalDimensionOnTrackNote
                : context.messages.goalDimensionNeedsAttentionNote,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ],
      ),
    );
  }
}

class _DimensionHeader extends StatelessWidget {
  const _DimensionHeader({
    required this.kind,
    required this.title,
    required this.source,
    required this.reading,
    required this.met,
    required this.hasData,
    this.onTargetToday = false,
  });

  final GoalDimensionKind kind;
  final String title;
  final String source;
  final String reading;
  final bool met;
  final bool hasData;
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
    };
    final icon = switch (kind) {
      GoalDimensionKind.habit => Icons.check_circle_outline_rounded,
      GoalDimensionKind.health => Icons.favorite_outline_rounded,
      GoalDimensionKind.measurable => Icons.straighten_rounded,
      GoalDimensionKind.categoryTime => Icons.schedule_rounded,
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
        Text(title, style: tokens.typography.styles.subtitle.subtitle1),
        Text(
          source,
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.lowEmphasis,
          ),
        ),
      ],
    );
    final readingBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(reading, style: tokens.typography.styles.subtitle.subtitle2),
        Text(
          !hasData
              ? context.messages.goalCoarseHealthNotEnoughData
              : onTargetToday
              ? context.messages.goalDimensionOnTargetTodayStatus
              : met
              ? context.messages.goalDimensionOnTrackStatus
              : context.messages.goalDimensionNeedsAttentionStatus,
          style: tokens.typography.styles.others.caption.copyWith(
            color: !hasData
                ? tokens.colors.text.mediumEmphasis
                : met
                ? tokens.colors.alert.success.ink
                : tokens.colors.alert.warning.ink,
          ),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth <
            tokens.spacing.step13 * 2 + tokens.spacing.step5;
        if (compact) {
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
              SizedBox(height: tokens.spacing.step2),
              Align(alignment: Alignment.centerRight, child: readingBlock),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            glyph,
            SizedBox(width: tokens.spacing.step3),
            Expanded(child: identity),
            SizedBox(width: tokens.spacing.step3),
            readingBlock,
          ],
        );
      },
    );
  }
}

/// The weekday label track paired with the day squares. It shares the same
/// pitch and item extent — and the same horizontal scroller — as the squares
/// below it, so labels and cells can never drift out of alignment.
class _WeekdayTrack extends StatelessWidget {
  const _WeekdayTrack({required this.days, required this.habitId});

  final List<GoalProgressDay> days;
  final String habitId;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final metrics = _weekdayLabelMetrics(context, days);
    return _DayTrack(
      height: math.max(IconSizes.s, metrics.height),
      itemExtent: ControlSizes.iconChipCompact,
      pitch: _dayTrackPitch(context, days),
      children: [
        for (final day in days)
          SizedBox(
            key: ValueKey(
              'goal-habit-weekday-$habitId-'
              '${day.day.toIso8601String().substring(0, 10)}',
            ),
            width: ControlSizes.iconChipCompact,
            child: OverflowBox(
              maxWidth: double.infinity,
              child: Text(
                DateFormat.E(locale).format(day.day),
                maxLines: 1,
                softWrap: false,
                textAlign: TextAlign.center,
                style: tokens.typography.styles.others.caption.copyWith(
                  color: tokens.colors.text.lowEmphasis,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

String _periodLabel(BuildContext context, List<GoalProgressDay> days) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final format = DateFormat.MMMd(locale);
  return '${format.format(days.first.day)} – ${format.format(days.last.day)}';
}

String _dimensionSource(BuildContext context, GoalDimensionKind kind) =>
    switch (kind) {
      GoalDimensionKind.habit => context.messages.goalDimensionHabitSource,
      GoalDimensionKind.health => context.messages.goalDimensionHealthSource,
      GoalDimensionKind.measurable =>
        context.messages.goalDimensionMeasurableSource,
      GoalDimensionKind.categoryTime =>
        context.messages.goalDimensionCategoryTimeSource,
    };

({double width, double height}) _weekdayLabelMetrics(
  BuildContext context,
  List<GoalProgressDay> days,
) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final style = context.designTokens.typography.styles.others.caption;
  final scaler = MediaQuery.textScalerOf(context);
  var width = 0.0;
  var height = 0.0;
  for (final day in days) {
    final painter = TextPainter(
      text: TextSpan(text: DateFormat.E(locale).format(day.day), style: style),
      textDirection: Directionality.of(context),
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    width = math.max(width, painter.width);
    height = math.max(height, painter.height);
  }
  return (width: width, height: height);
}

double _dayTrackPitch(BuildContext context, List<GoalProgressDay> days) {
  final tokens = context.designTokens;
  final defaultPitch = ControlSizes.iconChipCompact + tokens.spacing.step2;
  final labelWidth = _weekdayLabelMetrics(context, days).width;
  final expandedPitch = labelWidth + tokens.spacing.step1;
  final textScaledUp = MediaQuery.textScalerOf(context).scale(1) > 1;
  return textScaledUp && expandedPitch > defaultPitch
      ? expandedPitch
      : defaultPitch;
}

double _textWidth(BuildContext context, String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  return painter.width;
}

/// Keeps weekday labels and day cells on the compact handoff grid.
class _DayTrack extends StatelessWidget {
  const _DayTrack({
    required this.height,
    required this.itemExtent,
    required this.pitch,
    required this.children,
  });

  final double height;
  final double itemExtent;
  final double pitch;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final width = itemExtent + pitch * (children.length - 1);
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var index = 0; index < children.length; index++)
            Positioned(
              left: pitch * index,
              width: itemExtent,
              height: height,
              child: Center(child: children[index]),
            ),
        ],
      ),
    );
  }
}

class _HabitProgressRow extends StatefulWidget {
  const _HabitProgressRow({
    required this.habit,
    required this.today,
    required this.onOutcomeSelected,
  });

  final GoalHabitProgressView habit;
  final DateTime today;
  final GoalHabitOutcomeSelected? onOutcomeSelected;

  @override
  State<_HabitProgressRow> createState() => _HabitProgressRowState();
}

class _HabitProgressRowState extends State<_HabitProgressRow> {
  DateTime? _savingDay;

  Future<void> _recordOutcome(
    DateTime day,
    HabitCompletionType outcome,
  ) async {
    final callback = widget.onOutcomeSelected;
    if (callback == null || _savingDay != null) return;
    setState(() => _savingDay = day);
    var saved = false;
    try {
      saved = await callback(
        habitId: widget.habit.habitId,
        day: day,
        outcome: outcome,
      );
    } on Object {
      saved = false;
    } finally {
      if (mounted) setState(() => _savingDay = null);
    }
    if (!mounted) return;
    if (!saved) {
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(context.messages.goalBannerActionFailed)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final habit = widget.habit;
    final activeDays = habit.days;
    final stateColor = habit.deficit == 0
        ? tokens.colors.alert.success.ink
        : tokens.colors.alert.warning.ink;
    final note = habit.deficit == 0
        ? context.messages.goalProgressAtRate
        : context.messages.goalProgressDaysToHealthy(habit.deficit);
    final cadence = goalHabitTargetLabel(
      context,
      targetCount: habit.targetCount,
      window: habit.window,
    );
    final cadenceStyle = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.lowEmphasis,
    );
    final noteStyle = tokens.typography.styles.others.caption.copyWith(
      color: stateColor,
    );

    Widget cells() {
      const itemExtent = ControlSizes.iconChipCompact;
      return _DayTrack(
        height: itemExtent,
        itemExtent: itemExtent,
        pitch: _dayTrackPitch(context, activeDays),
        children: [
          for (var index = 0; index < activeDays.length; index++)
            _ProgressDayCell(
              day: activeDays[index],
              habitId: habit.habitId,
              today: DateUtils.isSameDay(
                activeDays[index].day,
                widget.today,
              ),
              agingOut: index == 0 && habit.oldestSuccessAgesOutTonight,
              saving: _savingDay == activeDays[index].day,
              enabled: !activeDays[index].day.isAfter(widget.today),
              onOutcomeSelected: widget.onOutcomeSelected == null
                  ? null
                  : (outcome) => _recordOutcome(
                      activeDays[index].day,
                      outcome,
                    ),
            ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final inlineHeaderWidth =
            _textWidth(context, cadence, cadenceStyle) +
            tokens.spacing.step3 +
            _textWidth(context, note, noteStyle);
        final cadenceFitsInline = inlineHeaderWidth <= constraints.maxWidth;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (cadenceFitsInline) ...[
                  Text(cadence, maxLines: 1, style: cadenceStyle),
                  const Spacer(),
                ] else
                  const Spacer(),
                SizedBox(width: tokens.spacing.step3),
                Text(
                  note,
                  style: noteStyle,
                ),
              ],
            ),
            if (!cadenceFitsInline) ...[
              SizedBox(height: tokens.spacing.step1),
              Text(cadence, style: cadenceStyle),
            ],
            SizedBox(height: tokens.spacing.step2),
            if (activeDays.length > 7) ...[
              Text(
                _periodLabel(context, activeDays),
                style: cadenceStyle,
              ),
              SizedBox(height: tokens.spacing.step1),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: cells(),
              ),
            ] else
              // Labels and squares scroll as one unit, keeping each weekday
              // caption glued to its cell.
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _WeekdayTrack(
                      days: activeDays,
                      habitId: habit.habitId,
                    ),
                    SizedBox(height: tokens.spacing.step1),
                    cells(),
                  ],
                ),
              ),
            if (widget.onOutcomeSelected != null &&
                habit.suggestedFromDimensionName != null) ...[
              SizedBox(height: tokens.spacing.step3),
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome_outlined,
                    size: IconSizes.s,
                    color: tokens.colors.interactive.enabled,
                  ),
                  SizedBox(width: tokens.spacing.step2),
                  Expanded(
                    child: Text(
                      context.messages.goalHabitCheckOffSuggestion(
                        habit.suggestedFromDimensionName!,
                      ),
                      style: tokens.typography.styles.others.caption.copyWith(
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                    ),
                  ),
                  SizedBox(width: tokens.spacing.step2),
                  DesignSystemButton(
                    key: ValueKey('goal-habit-checkoff-${habit.habitId}'),
                    label: context.messages.goalHabitCheckOffAction,
                    onPressed: _savingDay != null
                        ? null
                        : () => _recordOutcome(
                            widget.today,
                            HabitCompletionType.success,
                          ),
                    variant: DesignSystemButtonVariant.tertiary,
                    size: DesignSystemButtonSize.dense,
                    leadingIcon: Icons.check_rounded,
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Localized authored cadence used by progress and Watching surfaces.
String goalWindowLabel(BuildContext context, GoalWindow window) =>
    switch (window) {
      GoalWindowDay() => context.messages.goalWindowSingleDay,
      GoalWindowRollingDays(:final count) =>
        context.messages.goalWindowRollingDays(count),
      GoalWindowCalendarWeek() => context.messages.goalWindowCalendarWeek,
      GoalWindowCalendarMonth() => context.messages.goalWindowCalendarMonth,
    };

/// Formats one habit's target without reinterpreting non-weekly criteria as a
/// rolling seven-day goal.
String goalHabitTargetLabel(
  BuildContext context, {
  required int targetCount,
  required GoalWindow window,
}) => window == const GoalWindow.rollingDays(count: 7)
    ? context.messages.goalProgressHabitTarget(targetCount)
    : context.messages.goalProgressHabitTargetWindow(
        targetCount,
        goalWindowLabel(context, window),
      );

class _ProgressDayCell extends StatelessWidget {
  const _ProgressDayCell({
    required this.day,
    required this.habitId,
    required this.today,
    required this.agingOut,
    required this.saving,
    required this.enabled,
    required this.onOutcomeSelected,
  });

  final GoalProgressDay day;
  final String habitId;
  final bool today;
  final bool agingOut;
  final bool saving;
  final bool enabled;
  final ValueChanged<HabitCompletionType>? onOutcomeSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final hit = day.hasValue;
    final missed = day.habitCompletionType == HabitCompletionType.fail;
    // A completed day is a partial success (lighter wash) while the habit's
    // own window target was not yet met as of that day; a null verdict from
    // older projections keeps the established full-strength rendering.
    final dayState = !hit
        ? GoalCompactDayState.none
        : (day.targetSatisfied ?? true)
        ? GoalCompactDayState.full
        : GoalCompactDayState.partial;
    const visualDimension = ControlSizes.iconChipCompact;
    final border = agingOut
        ? Border.all(
            color: tokens.colors.alert.warning.defaultColor,
            width: BorderWidths.emphasis,
          )
        : today && hit
        ? Border.all(
            color: tokens.colors.interactive.enabled,
            width: BorderWidths.emphasis,
          )
        : null;
    Widget cell = Container(
      key: ValueKey(
        'goal-habit-day-visual-$habitId-'
        '${day.day.toIso8601String().substring(0, 10)}',
      ),
      width: visualDimension,
      height: visualDimension,
      decoration: BoxDecoration(
        color: missed
            ? tokens.colors.alert.error.defaultColor
            : goalDayStateFill(tokens, dayState),
        borderRadius: BorderRadius.circular(tokens.radii.s),
        border: border,
      ),
      child: missed
          ? Icon(
              Icons.close_rounded,
              size: IconSizes.xs,
              color: tokens.colors.alert.error.ink,
            )
          : null,
    );
    if (dayState == GoalCompactDayState.partial) {
      cell = KeyedSubtree(
        key: ValueKey(
          'goal-day-partial-$habitId-'
          '${day.day.toIso8601String().substring(0, 10)}',
        ),
        child: cell,
      );
    }
    if (missed) {
      cell = KeyedSubtree(
        key: ValueKey(
          'goal-day-missed-$habitId-'
          '${day.day.toIso8601String().substring(0, 10)}',
        ),
        child: cell,
      );
    }
    final decoratedCell = !today || hit
        ? cell
        : DsDashedBorder(
            color: tokens.colors.text.lowEmphasis,
            radius: tokens.radii.s,
            child: cell,
          );
    final locale = Localizations.localeOf(context).toLanguageTag();
    final date = DateFormat.yMMMd(locale).format(day.day);
    final menuDate = DateFormat.MMMEd(locale).format(day.day);
    final outcome = hit
        ? context.messages.completeHabitSuccessButton
        : missed
        ? context.messages.completeHabitFailButton
        : context.messages.goalProgressHabitDayNoEntry;
    final semanticLabel = context.messages.goalProgressHabitDaySemantics(
      date,
      outcome,
    );
    final callback = onOutcomeSelected;
    if (callback == null) {
      return Semantics(
        label: semanticLabel,
        excludeSemantics: true,
        child: Tooltip(
          message: semanticLabel,
          child: decoratedCell,
        ),
      );
    }
    return Semantics(
      label: semanticLabel,
      button: true,
      enabled: enabled && !saving,
      child: SizedBox.square(
        key: ValueKey(
          'goal-habit-day-$habitId-'
          '${day.day.toIso8601String().substring(0, 10)}',
        ),
        dimension: ControlSizes.iconChipCompact,
        child: PopupMenuButton<HabitCompletionType>(
          enabled: enabled && !saving,
          initialValue: day.habitCompletionType,
          padding: EdgeInsets.zero,
          menuPadding: EdgeInsets.zero,
          position: PopupMenuPosition.under,
          offset: Offset(0, tokens.spacing.step2),
          color: tokens.colors.background.level01,
          surfaceTintColor: Colors.transparent,
          constraints: BoxConstraints.tightFor(width: tokens.spacing.step13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radii.s),
          ),
          // The hover/long-press affordance carries the concrete date, so a
          // square never has to be resolved back to a calendar day mentally.
          tooltip: semanticLabel,
          onSelected: (outcome) {
            if (outcome != day.habitCompletionType) callback(outcome);
          },
          itemBuilder: (context) => [
            PopupMenuItem<HabitCompletionType>(
              key: ValueKey(
                'goal-habit-day-date-$habitId-'
                '${day.day.toIso8601String().substring(0, 10)}',
              ),
              enabled: false,
              height: ControlSizes.iconChipCompact,
              child: Text(
                menuDate,
                style: tokens.typography.styles.others.caption.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              key: const ValueKey('goal-habit-day-success'),
              value: HabitCompletionType.success,
              child: Row(
                children: [
                  Icon(
                    Icons.check_rounded,
                    size: IconSizes.s,
                    color: tokens.colors.alert.success.ink,
                  ),
                  SizedBox(width: tokens.spacing.step3),
                  Text(
                    context.messages.completeHabitSuccessButton,
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: tokens.colors.text.highEmphasis,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              key: const ValueKey('goal-habit-day-missed'),
              value: HabitCompletionType.fail,
              child: Row(
                children: [
                  Icon(
                    Icons.close_rounded,
                    size: IconSizes.s,
                    color: tokens.colors.alert.error.ink,
                  ),
                  SizedBox(width: tokens.spacing.step3),
                  Text(
                    context.messages.completeHabitFailButton,
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: tokens.colors.text.highEmphasis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          child: Center(
            child: saving
                ? SizedBox.square(
                    dimension: visualDimension,
                    child: Padding(
                      padding: EdgeInsets.all(tokens.spacing.step2),
                      child: const CircularProgressIndicator(),
                    ),
                  )
                : decoratedCell,
          ),
        ),
      ),
    );
  }
}

class _Reliability extends StatelessWidget {
  const _Reliability({required this.successfulWeeks});

  final int successfulWeeks;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var index = 0; index < 6; index++) ...[
              if (index > 0) SizedBox(width: tokens.spacing.step1),
              Container(
                width: BorderWidths.emphasis * 2,
                height: index < successfulWeeks
                    ? IconSizes.s
                    : tokens.spacing.step3,
                decoration: BoxDecoration(
                  color: index < successfulWeeks
                      ? tokens.colors.interactive.enabled
                      : tokens.colors.background.level03,
                  borderRadius: BorderRadius.circular(tokens.radii.xs),
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: tokens.spacing.step1),
        Text(
          '$successfulWeeks / 6',
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.lowEmphasis,
          ),
        ),
      ],
    );
  }
}

class _MetricTrendSeries extends StatelessWidget {
  const _MetricTrendSeries({required this.metric});

  final GoalMetricProgressView metric;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final range = _metricDateRange([metric]);
    if (range == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _periodLabel(context, metric.days),
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.lowEmphasis,
          ),
        ),
        SizedBox(
          height: tokens.spacing.step13,
          child: TimeSeriesLineChart(
            data: _metricObservations(metric),
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
  const _MetricProgressSeries({required this.metric});

  final GoalMetricProgressView metric;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final maxValue = metric.days.fold<num>(
      metric.target,
      (current, day) => day.value > current ? day.value : current,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _periodLabel(context, metric.days),
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.lowEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step3),
        SizedBox(
          height: tokens.spacing.step10,
          child: metric.days.length <= 7
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: _bars(context, maxValue, expanded: true),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: _bars(context, maxValue, expanded: false),
                  ),
                ),
        ),
      ],
    );
  }

  List<Widget> _bars(
    BuildContext context,
    num maxValue, {
    required bool expanded,
  }) {
    final tokens = context.designTokens;
    return [
      for (var index = 0; index < metric.days.length; index++) ...[
        if (index > 0) SizedBox(width: tokens.spacing.step2),
        if (expanded)
          Expanded(child: _bar(context, metric.days[index], maxValue))
        else
          SizedBox(
            width: ControlSizes.iconChipCompact,
            child: _bar(context, metric.days[index], maxValue),
          ),
      ],
    ];
  }

  Widget _bar(BuildContext context, GoalProgressDay day, num maxValue) {
    final tokens = context.designTokens;
    final locale = Localizations.localeOf(context).toString();
    final date = DateFormat.MMMd(locale).format(day.day);
    final number = NumberFormat.decimalPattern(locale);
    final status = !day.isObserved
        ? 'missing'
        : metric.meetsTarget(day)
        ? 'met'
        : 'missed';
    final rawHeightFactor = maxValue == 0
        ? 0.0
        : (day.value / maxValue).clamp(0, 1).toDouble();
    final minimumObservedHeight = tokens.spacing.step2 / tokens.spacing.step10;
    final heightFactor =
        day.isObserved && rawHeightFactor < minimumObservedHeight
        ? minimumObservedHeight
        : rawHeightFactor;
    final barFill = DecoratedBox(
      decoration: BoxDecoration(
        color: metric.meetsTarget(day)
            ? tokens.colors.alert.info.defaultColor
            : tokens.colors.background.level03,
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
    return Semantics(
      label: context.messages.goalMetricBarSemantics(
        status,
        date,
        number.format(day.value),
        number.format(metric.target),
      ),
      child: ExcludeSemantics(
        child: FractionallySizedBox(
          key: ValueKey(
            'goal-metric-bar-${day.day.toIso8601String().substring(0, 10)}',
          ),
          heightFactor: heightFactor,
          alignment: Alignment.bottomCenter,
          child: metric.agentRecordedDays.contains(day.day)
              ? Stack(
                  fit: StackFit.expand,
                  clipBehavior: Clip.none,
                  children: [
                    barFill,
                    Positioned(
                      top: -tokens.spacing.step3,
                      right: 0,
                      child: Tooltip(
                        message: provenance == null
                            ? context.messages.goalDimensionRecordedByAgent
                            : context.messages
                                  .goalDimensionRecordedByAgentDetails(
                                    provenance.agentName,
                                    DateFormat.MMMEd(locale).add_jm().format(
                                      provenance.recordedAt,
                                    ),
                                  ),
                        child: Icon(
                          Icons.edit_note_rounded,
                          size: IconSizes.xs,
                          color: GoalAccentHues.aurora(
                            Theme.of(context).brightness,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : barFill,
        ),
      ),
    );
  }
}

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
                Icons.insights_rounded,
                color: tokens.colors.alert.warning.defaultColor,
              ),
              SizedBox(width: tokens.spacing.step2),
              Text(
                '${context.messages.goalPatternTitle} · ${metric.name}',
                style: tokens.typography.styles.subtitle.subtitle1,
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
          Text(
            context.messages.goalPatternBusiestHour(
              busiestHour.toString().padLeft(2, '0'),
            ),
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressLegend extends StatelessWidget {
  const _ProgressLegend();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    Widget item(Color color, String label, {bool outlined = false}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: IconSizes.xs,
          height: IconSizes.xs,
          decoration: BoxDecoration(
            color: outlined ? Colors.transparent : color,
            border: outlined
                ? Border.all(color: color, width: BorderWidths.emphasis)
                : null,
            borderRadius: BorderRadius.circular(tokens.radii.xs),
          ),
        ),
        SizedBox(width: tokens.spacing.step2),
        // Flexible so the longer done/partial labels line-break on narrow
        // cards instead of overflowing the legend row.
        Flexible(
          child: Text(
            label,
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.lowEmphasis,
            ),
          ),
        ),
      ],
    );
    return Wrap(
      spacing: tokens.spacing.step4,
      runSpacing: tokens.spacing.step2,
      children: [
        item(
          tokens.colors.interactive.enabled,
          context.messages.goalProgressDone,
        ),
        item(
          tokens.colors.interactive.enabled.withValues(
            alpha: SurfaceAlphas.muted,
          ),
          context.messages.goalProgressPartial,
        ),
        item(
          tokens.colors.alert.warning.defaultColor,
          context.messages.goalProgressAgesOut,
          outlined: true,
        ),
        item(
          tokens.colors.text.lowEmphasis,
          context.messages.goalProgressToday,
          outlined: true,
        ),
      ],
    );
  }
}
