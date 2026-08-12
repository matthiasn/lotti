import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/components/ds_dashed_border.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/state/goal_progress_view.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// The handover's seven-cell picture used on each Agents-list row. It is
/// intentionally unlabeled visually, but exposes one concise semantic summary.
class GoalCompactWindowStrip extends StatelessWidget {
  const GoalCompactWindowStrip({required this.days, super.key});

  final List<bool> days;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final visible = days.take(7).toList(growable: false);
    if (visible.isEmpty) return const SizedBox.shrink();
    return Semantics(
      label: context.messages.goalProgressCompactSemantics(
        visible.where((hit) => hit).length,
      ),
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < visible.length; index++) ...[
              if (index > 0) SizedBox(width: tokens.spacing.step1),
              _CompactDayCell(
                hit: visible[index],
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
  const _CompactDayCell({required this.hit, required this.today});

  final bool hit;
  final bool today;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final cell = Container(
      width: IconSizes.xs,
      height: IconSizes.xs,
      decoration: BoxDecoration(
        color: hit
            ? tokens.colors.interactive.enabled
            : tokens.colors.background.level03,
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
        for (final metric in progress.metrics) ...[
          _MetricDimensionCard(metric: metric),
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
          _DimensionWeekdayHeader(
            days: habit.days,
            habitId: habit.habitId,
          ),
          SizedBox(height: tokens.spacing.step2),
          _HabitProgressRow(
            habit: habit,
            today: today,
            onOutcomeSelected: onHabitOutcomeSelected,
            hideName: true,
          ),
          if (successfulWeeks != null) ...[
            SizedBox(height: tokens.spacing.step2),
            Align(
              alignment: Alignment.centerRight,
              child: _Reliability(successfulWeeks: successfulWeeks),
            ),
          ],
          SizedBox(height: tokens.spacing.step4),
          const _ProgressLegend(),
        ],
      ),
    );
  }
}

class _MetricDimensionCard extends StatelessWidget {
  const _MetricDimensionCard({required this.metric});

  final GoalMetricProgressView metric;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final observed = metric.days.where((day) => day.isObserved).toList();
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
    final locale = Localizations.localeOf(context).toLanguageTag();
    final number = NumberFormat.decimalPattern(locale);
    final unit = metric.unitName?.trim();
    final reading = unit == null || unit.isEmpty
        ? context.messages.goalDimensionMetricReading(
            number.format(current),
            number.format(metric.target),
          )
        : context.messages.goalDimensionMetricReadingWithUnit(
            number.format(current),
            number.format(metric.target),
            unit,
          );
    final meetsPeriodTarget = switch (metric.direction) {
      GoalDirection.atLeast => current >= metric.target,
      GoalDirection.atMost => current <= metric.target,
    };
    final met =
        observed.isNotEmpty && (meetsPeriodTarget || metric.projectedOnTrack);
    return DesignSystemSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DimensionHeader(
            kind: metric.kind,
            title: metric.name,
            source: _dimensionSource(context, metric.kind),
            reading: reading,
            met: met,
            hasData: observed.isNotEmpty,
          ),
          SizedBox(height: tokens.spacing.step4),
          if (metric.kind == GoalDimensionKind.categoryTime &&
              metric.dailyTimeRange != null)
            _CategoryBandSeries(metric: metric)
          else
            _MetricProgressSeries(metric: metric),
          SizedBox(height: tokens.spacing.step3),
          Text(
            observed.isEmpty
                ? context.messages.goalDimensionNoDataNote
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

class _DimensionHeader extends StatelessWidget {
  const _DimensionHeader({
    required this.kind,
    required this.title,
    required this.source,
    required this.reading,
    required this.met,
    required this.hasData,
  });

  final GoalDimensionKind kind;
  final String title;
  final String source;
  final String reading;
  final bool met;
  final bool hasData;

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

class _DimensionWeekdayHeader extends StatelessWidget {
  const _DimensionWeekdayHeader({required this.days, required this.habitId});

  final List<GoalProgressDay> days;
  final String habitId;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final locale = Localizations.localeOf(context).toLanguageTag();
    if (days.length > 7) {
      return Text(
        _periodLabel(context, days),
        style: tokens.typography.styles.others.caption.copyWith(
          color: tokens.colors.text.lowEmphasis,
        ),
      );
    }
    final metrics = _weekdayLabelMetrics(context, days);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: _DayTrack(
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
      ),
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

double _dayTrackWidth(BuildContext context, List<GoalProgressDay> days) {
  if (days.isEmpty) return 0;
  return ControlSizes.iconChipCompact +
      _dayTrackPitch(context, days) * (days.length - 1);
}

double _habitGridWideMinimum(
  BuildContext context,
  List<GoalProgressDay> days,
) {
  final spacing = context.designTokens.spacing;
  return spacing.step13 * 2 + spacing.step3 * 2 + _dayTrackWidth(context, days);
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
    this.hideName = false,
  });

  final GoalHabitProgressView habit;
  final DateTime today;
  final GoalHabitOutcomeSelected? onOutcomeSelected;
  final bool hideName;

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
    final nameStyle = tokens.typography.styles.body.bodySmall.copyWith(
      color: tokens.colors.text.highEmphasis,
    );
    final cadenceStyle = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.lowEmphasis,
    );
    final noteStyle = tokens.typography.styles.others.caption.copyWith(
      color: stateColor,
    );

    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.hideName)
          Text(
            habit.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: nameStyle,
          ),
        Text(cadence, style: cadenceStyle),
      ],
    );
    Widget cells({required bool alignWithWeekdays}) {
      const itemExtent = ControlSizes.iconChipCompact;
      return _DayTrack(
        height: itemExtent,
        itemExtent: itemExtent,
        pitch: alignWithWeekdays
            ? _dayTrackPitch(context, activeDays)
            : itemExtent + tokens.spacing.step2,
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

    final successfulWeeks = habit.successfulWeeks;
    final reliability = successfulWeeks == null
        ? null
        : _Reliability(successfulWeeks: successfulWeeks);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            !widget.hideName &&
            activeDays.length <= 7 &&
            constraints.maxWidth >= _habitGridWideMinimum(context, activeDays);
        if (wide) {
          return Row(
            children: [
              SizedBox(width: tokens.spacing.step13, child: identity),
              SizedBox(width: tokens.spacing.step3),
              cells(alignWithWeekdays: true),
              SizedBox(width: tokens.spacing.step3),
              Expanded(
                child: Text(
                  note,
                  style: noteStyle,
                ),
              ),
              ?reliability,
            ],
          );
        }
        final inlineHeaderWidth =
            (widget.hideName ? 0 : _textWidth(context, habit.name, nameStyle)) +
            tokens.spacing.step2 +
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
                  if (!widget.hideName) ...[
                    Text(
                      habit.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: nameStyle,
                    ),
                    SizedBox(width: tokens.spacing.step2),
                  ],
                  Text(cadence, maxLines: 1, style: cadenceStyle),
                  const Spacer(),
                ] else if (!widget.hideName)
                  Expanded(
                    child: Text(
                      habit.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: nameStyle,
                    ),
                  )
                else
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
            SizedBox(height: tokens.spacing.step1),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: cells(alignWithWeekdays: widget.hideName),
            ),
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
        color: hit
            ? tokens.colors.interactive.enabled
            : missed
            ? tokens.colors.alert.error.defaultColor
            : tokens.colors.background.level03,
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
    final date = DateFormat.yMMMd(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(day.day);
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
        child: decoratedCell,
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
          tooltip: '',
          onSelected: (outcome) {
            if (outcome != day.habitCompletionType) callback(outcome);
          },
          itemBuilder: (context) => [
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
        Text(
          label,
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.lowEmphasis,
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
