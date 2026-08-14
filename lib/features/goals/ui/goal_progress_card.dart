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
import 'package:lotti/features/goals/model/goal_assessment.dart';
import 'package:lotti/features/goals/model/goal_health_data_types.dart';
import 'package:lotti/features/goals/state/goal_progress_view.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/charts/utils.dart';

/// The handover's seven-cell picture used on each Agents-list row. It is
/// intentionally unlabeled visually, but exposes one concise semantic summary.
class GoalCompactWindowStrip extends StatelessWidget {
  const GoalCompactWindowStrip({
    required this.days,
    this.placeholder = false,
    this.cellSize = IconSizes.xs,
    this.lastDay,
    this.onDaySelected,
    this.ratingsByDay = const {},
    super.key,
  }) : assert(
         onDaySelected == null || lastDay != null,
         'A tappable strip needs lastDay to date the cell that was tapped.',
       );

  final List<GoalCompactDayState> days;

  /// True while the strip stands in for a window that has not resolved yet.
  /// Placeholder cells render as dashed outlines, never as the filled grey a
  /// genuinely-empty week wears — "no data yet" and "nothing happened" must
  /// not share an encoding, or the strip contradicts a Healthy chip beside
  /// it.
  final bool placeholder;

  /// Edge of one day's square. Defaults to the compact size the list rows
  /// need; the detail page passes the habit day square's size so the two
  /// strips on one screen read as the same instrument at the same scale.
  final double cellSize;

  /// The day the last cell stands for. Every earlier cell counts back from
  /// it, which is how a tap resolves to a date without a second parallel
  /// list that could fall out of step with [days].
  final DateTime? lastDay;

  /// Opens the day's reflection. Null leaves the strip a read-only figure —
  /// which is what the list rows want, since a tap there navigates.
  final ValueChanged<DateTime>? onDaySelected;

  /// Day verdicts the user has recorded, keyed by UTC day. Ignored without a
  /// [lastDay] to line them up against.
  ///
  /// A recorded verdict wins over the measured state for that cell. The
  /// measurement is evidence about a day; the reflection is the user's ruling
  /// on it, and a strip that kept showing grey after they filed the day as
  /// missed would be contradicting them.
  final Map<DateTime, GoalAssessmentRating> ratingsByDay;

  DateTime _dateAt(int index, int length) =>
      lastDay!.subtract(Duration(days: length - 1 - index));

  GoalAssessmentRating? _ratingAt(int index, int length) {
    if (ratingsByDay.isEmpty || lastDay == null) return null;
    final date = _dateAt(index, length);
    return ratingsByDay[DateTime.utc(date.year, date.month, date.day)];
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final visible = days.take(7).toList(growable: false);
    if (visible.isEmpty) return const SizedBox.shrink();
    final onDaySelected = this.onDaySelected;
    final locale = Localizations.localeOf(context).toLanguageTag();

    Widget cellAt(int index) {
      if (placeholder) return _PlaceholderDayCell(size: cellSize);
      final today = index == visible.length - 1;
      final rating = _ratingAt(index, visible.length);
      if (onDaySelected == null) {
        return _CompactDayCell(
          state: visible[index],
          today: today,
          size: cellSize,
          rating: rating,
        );
      }
      final date = _dateAt(index, visible.length);
      final dayName = DateFormat.MMMEd(locale).format(date);
      // Colour and an inner dot are the only thing separating these cells,
      // and neither reaches a screen reader. Each day therefore announces its
      // own state, not just its date — the strip's summary gives a count and
      // cannot say WHICH days went well, which is exactly what a reader needs
      // once every cell is individually actionable.
      final outcome = rating != null
          ? goalAssessmentRatingLabel(context, rating)
          : switch (visible[index]) {
              GoalCompactDayState.full => context.messages.goalProgressDone,
              GoalCompactDayState.partial =>
                context.messages.goalProgressPartial,
              GoalCompactDayState.none =>
                context.messages.goalProgressHabitDayNoEntry,
            };
      return _CompactDayCell(
        state: visible[index],
        today: today,
        size: cellSize,
        rating: rating,
        label: context.messages.goalProgressHabitDaySemantics(
          dayName,
          outcome,
        ),
        onTap: () => onDaySelected(date),
      );
    }

    // Read-only, the strip is a figure and hugs its content. Tappable, it
    // spans its parent instead: seven cells each demanding the 48px touch
    // floor would overflow a phone card, so the cells share the measure and
    // every one of them still clears the floor.
    final row = Row(
      mainAxisSize: onDaySelected == null ? MainAxisSize.min : MainAxisSize.max,
      children: [
        for (var index = 0; index < visible.length; index++) ...[
          if (index > 0) SizedBox(width: tokens.spacing.step1),
          if (onDaySelected == null)
            cellAt(index)
          else
            Expanded(child: cellAt(index)),
        ],
      ],
    );

    return Semantics(
      label: placeholder
          ? context.messages.goalProgressStripLoading
          : context.messages.goalProgressCompactSemantics(
              visible
                  .where((state) => state != GoalCompactDayState.none)
                  .length,
            ),
      // A tappable strip publishes each day as its own button, so the summary
      // above becomes the container's label rather than the whole story.
      child: onDaySelected == null ? ExcludeSemantics(child: row) : row,
    );
  }
}

/// A not-yet-resolved day slot: same footprint as a real cell, dashed
/// outline instead of a fill, so the silhouette holds without borrowing the
/// empty-week encoding.
class _PlaceholderDayCell extends StatelessWidget {
  const _PlaceholderDayCell({this.size = IconSizes.xs});

  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.all(tokens.spacing.step1),
      child: DsDashedBorder(
        color: tokens.colors.text.lowEmphasis,
        radius: tokens.radii.xs,
        child: SizedBox(width: size, height: size),
      ),
    );
  }
}

class _CompactDayCell extends StatelessWidget {
  const _CompactDayCell({
    required this.state,
    required this.today,
    this.size = IconSizes.xs,
    this.onTap,
    this.label,
    this.rating,
  });

  final GoalCompactDayState state;
  final bool today;
  final double size;
  final VoidCallback? onTap;

  /// The user's verdict for this day, when they have recorded one. It decides
  /// the fill; [state] is only what the app measured.
  final GoalAssessmentRating? rating;

  /// Spoken and hovered name for a tappable cell. Null on a read-only strip,
  /// whose semantics are carried by the summary above it.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final rating = this.rating;
    // The dot is the measured-partial cue; a recorded verdict wears its own
    // glyph instead. Either way the cell says something a reader who cannot
    // separate the hues can still act on.
    final showsPartialDot =
        rating == null && state == GoalCompactDayState.partial;
    final cell = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: rating == null
            ? goalDayStateFill(tokens, state)
            : goalAssessmentRatingFill(tokens, rating),
        borderRadius: BorderRadius.circular(tokens.radii.xs),
      ),
      child: showsPartialDot
          ? Center(
              child: goalPartialDayDot(
                tokens,
                // The dot has to stay legible inside the square it marks, so
                // it scales with it rather than sitting at one fixed size.
                size <= IconSizes.xs
                    ? tokens.spacing.step1
                    : tokens.spacing.step2,
              ),
            )
          // Only where the square is big enough to hold it. On the list rows'
          // 12px cells a glyph is a smudge, and those strips carry no recorded
          // verdicts anyway.
          : rating != null && size >= ControlSizes.iconChipCompact
          ? Center(
              child: Icon(
                goalAssessmentRatingGlyph(rating),
                size: size * 0.6,
                color: tokens.colors.alert.success.ink,
              ),
            )
          : null,
    );
    // Every cell shares one outer footprint; today only adds the dashed
    // ring inside it, so the strip's rhythm never bulges at the last cell.
    final padded = Padding(
      padding: EdgeInsets.all(tokens.spacing.step1),
      child: cell,
    );
    final decorated = today
        ? DsDashedBorder(
            color: tokens.colors.text.lowEmphasis,
            radius: tokens.radii.xs,
            child: padded,
          )
        : padded;
    final onTap = this.onTap;
    if (onTap == null) return decorated;
    // The square keeps its size; the hit slot around it takes the full height
    // of the touch floor and whatever width the row can spare. Growing the
    // square itself to 48px would make the strip shout over the habit rows it
    // is meant to summarise.
    return Semantics(
      label: label,
      button: true,
      excludeSemantics: true,
      child: Tooltip(
        message: label ?? '',
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(tokens.radii.s),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: TapTargets.minimum,
              ),
              child: Center(child: decorated),
            ),
          ),
        ),
      ),
    );
  }
}

/// Formats an aggregate for display, without spraying false precision.
///
/// The rolling aggregates are means, so a step average arrives as
/// 7684.428571… and `decimalPattern` renders it "7,684.429" — three decimals
/// of a quantity that only exists in whole numbers. Weight and blood pressure
/// do want a fraction, so the rule is scale rather than data type: below 100,
/// one decimal and only when it is not a whole number; at 100 and above, none,
/// where a tenth is noise beside the number it qualifies.
String formatGoalAggregate(NumberFormat number, num value) {
  final rounded = value.abs() >= 100
      ? value.roundToDouble()
      : (value * 10).roundToDouble() / 10;
  return number.format(
    rounded == rounded.roundToDouble() ? rounded.toInt() : rounded,
  );
}

/// Shared fill for a day cell: the full-strength success hue when the goal
/// requirement held as of that day, a lighter wash of the same hue for a
/// partial success (routine kept, target still building), neutral otherwise.
/// `SurfaceAlphas.muted` is the sanctioned "reduced-strength accent" alpha,
/// so no new color token is introduced. Data-that-happened wears the
/// `alert.success` family; the interactive teal stays strictly for things
/// the user can tap.
Color goalDayStateFill(DsTokens tokens, GoalCompactDayState state) =>
    switch (state) {
      GoalCompactDayState.full => tokens.colors.alert.success.defaultColor,
      GoalCompactDayState.partial =>
        tokens.colors.alert.success.defaultColor.withValues(
          alpha: SurfaceAlphas.muted,
        ),
      GoalCompactDayState.none => tokens.colors.background.level03,
    };

/// Hue for a day the user has actually judged, which outranks what the app
/// measured: a reflection is a statement about the day, and the measurement is
/// only evidence toward one.
///
/// Four distinct hues, all existing alert tokens, and the same three the
/// reflections-history pill has always used — extended with the blue a
/// restarting agent wears for [GoalAssessmentRating.improving], which is
/// progress that is not yet arrival. Sharing one scheme is the point: the
/// strip and the history are two views of the same verdict, and a day filed
/// as missed must not be grey in one place and red in another.
///
/// Notably [GoalAssessmentRating.missed] is not the neutral grey a day with no
/// data wears. Deciding a day was missed and never looking at it are different
/// facts, and the strip has to be able to say which.
Color goalAssessmentRatingFill(DsTokens tokens, GoalAssessmentRating rating) =>
    switch (rating) {
      GoalAssessmentRating.met => tokens.colors.alert.success.defaultColor,
      GoalAssessmentRating.improving => tokens.colors.alert.info.defaultColor,
      GoalAssessmentRating.mixed => tokens.colors.alert.warning.defaultColor,
      GoalAssessmentRating.missed => tokens.colors.alert.error.defaultColor,
    };

/// The glyph that names a recorded verdict without relying on its hue.
///
/// Four fills that differ only by colour are four fills a red-green colour
/// deficiency cannot tell apart, and the strip's whole job is to be read at a
/// glance. Each verdict therefore carries a shape as well: a tick for met, a
/// rising arrow for improving, a half-filled circle for mixed, a cross for
/// missed.
IconData goalAssessmentRatingGlyph(GoalAssessmentRating rating) =>
    switch (rating) {
      GoalAssessmentRating.met => Icons.check_rounded,
      GoalAssessmentRating.improving => Icons.trending_up_rounded,
      GoalAssessmentRating.mixed => Icons.contrast_rounded,
      GoalAssessmentRating.missed => Icons.close_rounded,
    };

/// The localized name of a day verdict, shared by the strip's semantics and
/// the reflection sheet's own toggle so the two can never drift apart.
String goalAssessmentRatingLabel(
  BuildContext context,
  GoalAssessmentRating rating,
) => switch (rating) {
  GoalAssessmentRating.met => context.messages.goalAssessmentMet,
  GoalAssessmentRating.improving => context.messages.goalAssessmentImproving,
  GoalAssessmentRating.mixed => context.messages.goalAssessmentMixed,
  GoalAssessmentRating.missed => context.messages.goalAssessmentMissed,
};

/// The non-color cue for a partial day: a full-strength dot inside the
/// lighter wash, so full/partial/none survive without a legend (the list
/// rows carry none) and for color-blind readers.
Widget goalPartialDayDot(DsTokens tokens, double diameter) => Container(
  width: diameter,
  height: diameter,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    color: tokens.colors.alert.success.ink,
  ),
);

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
    this.ratingsByDay = const {},
    super.key,
  });

  final GoalProgressView progress;
  final GoalHabitOutcomeSelected? onHabitOutcomeSelected;
  final ValueChanged<DateTime>? onReflectDay;

  /// Day verdicts the user has recorded, keyed by UTC day. They decide the
  /// whole-goal strip's colours, outranking what the app measured.
  final Map<DateTime, GoalAssessmentRating> ratingsByDay;

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
        // A composite goal always gets this card: the strip is the only place
        // its dimensions are summed into one week.
        //
        // A leaf goal gets it only where the days are actionable. Gating it on
        // the composite rule alone left single-habit and single-metric goals
        // unable to reflect on a past day at all and showing none of the
        // verdict colours — the feature is about goal days, and a leaf goal
        // has those too. Adding the card unconditionally would instead put a
        // second, near-identical week above the one its single dimension
        // already draws.
        if (progress.compositeRule != null ||
            (onReflectDay != null && progress.compactWindow.isNotEmpty)) ...[
          _CompositeProgressCard(
            progress: progress,
            onReflectDay: onReflectDay,
            ratingsByDay: ratingsByDay,
          ),
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
        // ONE legend for all habit cards, aligned with their content edge —
        // repeating it per card taxed every screenful with boilerplate.
        if (progress.habits.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.cardPadding,
            ),
            child: const _ProgressLegend(),
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
                // The sparkle stays exclusive to agent suggestions; this row
                // is the USER writing a reflection.
                Icon(
                  Icons.edit_note_rounded,
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
  const _CompositeProgressCard({
    required this.progress,
    this.onReflectDay,
    this.ratingsByDay = const {},
  });

  final GoalProgressView progress;

  /// Opens a day's reflection from the strip. Null while the goal cannot be
  /// reflected on — a retired agent, or a spec that has not resolved.
  final ValueChanged<DateTime>? onReflectDay;

  final Map<DateTime, GoalAssessmentRating> ratingsByDay;

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
            style: tokens.typography.styles.subtitle.subtitle2,
          ),
          SizedBox(height: tokens.spacing.step3),
          // The strip counts DAYS; the caption below counts dimensions on
          // one day. Naming the frame keeps the two from reading as one
          // contradictory statistic.
          Text(
            context.messages.goalCompositeLastSevenDays,
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.lowEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step1),
          GoalCompactWindowStrip(
            days: progress.compactWindow,
            // Matched to the habit day squares below: the two strips describe
            // the same week at the same scale, and the whole-goal one used to
            // render at 12px against their 28px.
            cellSize: ControlSizes.iconChipCompact,
            lastDay: progress.today,
            onDaySelected: onReflectDay,
            ratingsByDay: ratingsByDay,
          ),
          if (progress.compositeRule != null)
            SizedBox(height: tokens.spacing.step3),
          // "3 of 5 dimensions · 4 required" says nothing about a goal with
          // one dimension, so a leaf goal gets the strip without the tally.
          if (progress.compositeRule != null)
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
                final label = compact
                    ? Row(
                        children: [
                          Flexible(child: title),
                          SizedBox(width: tokens.spacing.step3),
                          // The streak displaces the caption rather than the
                          // title: "This rolling week" already says the window
                          // slides, while the streak is data that otherwise
                          // costs a whole row of its own.
                          if (successfulWeeks == null)
                            Expanded(child: caption)
                          else ...[
                            const Spacer(),
                            _Reliability(successfulWeeks: successfulWeeks),
                          ],
                        ],
                      )
                    : Wrap(
                        spacing: tokens.spacing.step3,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [title, caption],
                      );
                // The streak rides on the trailing edge of the label it
                // qualifies. On its own row below the day squares it was an
                // orphan: a two-word stat marooned against the right edge
                // with a card's width of nothing beside it and a gap under
                // it, which read as a layout accident rather than a figure.
                if (successfulWeeks == null) return label;
                if (compact) return label;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: label),
                    SizedBox(width: tokens.spacing.step4),
                    _Reliability(successfulWeeks: successfulWeeks),
                  ],
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
  bool improving,
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
  // Whether the most recent observation moved TOWARD the target relative to
  // the one before it. Not a trend — two points never are — but it is the
  // difference between "behind" and "behind and getting worse", and it is the
  // one thing the seven bars above cannot say on their own.
  final previousDay = observed.length < 2
      ? null
      : observed[observed.length - 2];
  final improving =
      latestDay != null &&
      previousDay != null &&
      (metric.direction == GoalDirection.atLeast
          ? latestDay.value > previousDay.value
          : latestDay.value < previousDay.value);
  return (
    current: current,
    // The most recent observation. Point-sample vitals display this instead
    // of the period aggregate. An on-target reading recorded today also gets
    // a positive daily presentation without changing the persisted rolling
    // evaluation result.
    latest: observed.isEmpty ? 0 : observed.last.value,
    hasData: observed.isNotEmpty,
    latestOnTargetToday: latestOnTargetToday,
    improving: improving,
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
    // Both halves have to be moving the right way. One improving while the
    // other slips is not a reading that improved.
    final improving = systolic.improving && diastolic.improving;
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
          if (range != null) ...[
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
                : improving
                ? context.messages.goalDimensionImprovingNote
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
            formatGoalAggregate(number, displayValue),
            formatGoalAggregate(number, metric.target),
          )
        : context.messages.goalDimensionMetricReadingWithUnit(
            formatGoalAggregate(number, displayValue),
            formatGoalAggregate(number, metric.target),
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
                : summary.improving
                // Behind, but moving the right way — worth saying, and the
                // one thing the bars above cannot.
                ? context.messages.goalDimensionImprovingNote
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
        Text(title, style: tokens.typography.styles.subtitle.subtitle2),
        Text(
          source,
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.lowEmphasis,
          ),
        ),
      ],
    );
    Column readingBlock(CrossAxisAlignment align) => Column(
      crossAxisAlignment: align,
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
              // One left rag per card on narrow widths — right alignment
              // only where the width earns it (the wide branch below).
              Align(
                alignment: Alignment.centerLeft,
                child: readingBlock(CrossAxisAlignment.start),
              ),
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
            readingBlock(CrossAxisAlignment.end),
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
    // Slots span the full pitch, so adjacent hit regions touch without
    // overlapping — each editable cell gets the widest tap area the
    // authored density allows, and labels stay centered over their cells.
    final width = pitch * children.length;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var index = 0; index < children.length; index++)
            Positioned(
              left: pitch * index,
              width: pitch,
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
    // Deterministic arithmetic, not a verdict — the header's status caption
    // owns the warning ink; the countdown stays neutral so urgency isn't
    // flattened by repetition.
    final stateColor = tokens.colors.text.mediumEmphasis;
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
      // Interactive rows own a touch-floor-high track so each cell's hit
      // slot meets TapTargets.minimum vertically; read-only rows keep the
      // compact height.
      final trackHeight = widget.onOutcomeSelected == null
          ? itemExtent
          : TapTargets.minimum;
      return _DayTrack(
        height: trackHeight,
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
    // Ages-out is a quiet outline, not the page's alarm hue: an on-track
    // habit must never wear warning orange. Today-and-done rings in the
    // success family — the cell is data, not a control.
    final border = agingOut
        ? Border.all(
            color: tokens.colors.text.lowEmphasis,
            width: BorderWidths.emphasis,
          )
        : today && hit
        ? Border.all(
            color: tokens.colors.alert.success.defaultColor,
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
          : dayState == GoalCompactDayState.partial
          ? Center(child: goalPartialDayDot(tokens, tokens.spacing.step2))
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
      // The visual stays at the compact chip size; the hit slot meets the
      // design system's touch floor vertically and fills the track pitch
      // horizontally — invisible ergonomics, unchanged rhythm.
      child: SizedBox.expand(
        key: ValueKey(
          'goal-habit-day-$habitId-'
          '${day.day.toIso8601String().substring(0, 10)}',
        ),
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
                      ? tokens.colors.alert.success.defaultColor
                      : tokens.colors.background.level03,
                  borderRadius: BorderRadius.circular(tokens.radii.xs),
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: tokens.spacing.step1),
        Text(
          context.messages.goalReliabilityWeeks(successfulWeeks),
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.mediumEmphasis,
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
          height: _chartHeight(tokens),
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
          // Even spacing across the card, but each bar keeps the same width
          // it has in the scrollable variant. Left to fill its share, a
          // seven-day week rendered ~40px slabs that dominated the card and
          // read nothing like the day squares above them.
          Expanded(
            child: Center(
              // A tight width, not a maximum. `_bar` is a FractionallySizedBox
              // with no widthFactor, so a loose constraint passes straight
              // through to a DecoratedBox with no intrinsic width and every
              // bar collapses to zero — an invisible chart.
              child: SizedBox(
                width: ControlSizes.iconChipCompact,
                child: _bar(context, metric.days[index], maxValue),
              ),
            ),
          )
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
    final minimumObservedHeight = tokens.spacing.step2 / _chartHeight(tokens);
    final heightFactor =
        day.isObserved && rawHeightFactor < minimumObservedHeight
        ? minimumObservedHeight
        : rawHeightFactor;
    final barFill = DecoratedBox(
      decoration: BoxDecoration(
        // The same fill the day cells above use, for the same meaning: this
        // day met the goal. The bars wore `alert.info` — a blue that carried
        // no threshold meaning at all, so a 12,000-step day and a 5,000-step
        // day were told apart only by height, and the day the user actually
        // beat their target looked no different from the day they missed it.
        color: goalDayStateFill(
          tokens,
          metric.meetsTarget(day)
              ? GoalCompactDayState.full
              : GoalCompactDayState.none,
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
    Widget item(
      Color color,
      String label, {
      bool outlined = false,
      bool dotted = false,
      bool dashed = false,
    }) {
      Widget swatch = Container(
        width: IconSizes.xs,
        height: IconSizes.xs,
        decoration: BoxDecoration(
          color: outlined || dashed ? Colors.transparent : color,
          border: outlined
              ? Border.all(color: color, width: BorderWidths.emphasis)
              : null,
          borderRadius: BorderRadius.circular(tokens.radii.xs),
        ),
        // The legend swatch carries the same non-color cue as the cells.
        child: dotted
            ? Center(child: goalPartialDayDot(tokens, tokens.spacing.step1))
            : null,
      );
      if (dashed) {
        swatch = DsDashedBorder(
          color: color,
          radius: tokens.radii.xs,
          child: swatch,
        );
      }
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          swatch,
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
    }

    return Wrap(
      spacing: tokens.spacing.step4,
      runSpacing: tokens.spacing.step2,
      children: [
        item(
          tokens.colors.alert.success.defaultColor,
          context.messages.goalProgressDone,
        ),
        item(
          tokens.colors.alert.success.defaultColor.withValues(
            alpha: SurfaceAlphas.muted,
          ),
          context.messages.goalProgressPartial,
          dotted: true,
        ),
        // Quiet outline, matching the ring the cells actually draw — an
        // on-track row must not wear the alarm hue in its key either.
        item(
          tokens.colors.text.lowEmphasis,
          context.messages.goalProgressAgesOut,
          outlined: true,
        ),
        // Dashed, exactly like the today cell — the key must match the map.
        item(
          tokens.colors.text.lowEmphasis,
          context.messages.goalProgressToday,
          dashed: true,
        ),
      ],
    );
  }
}
