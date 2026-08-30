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
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_bar_line_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_line_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_multiline_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/utils.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/callouts/design_system_inline_callout.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/components/ds_quiet_ink.dart';
import 'package:lotti/features/design_system/components/tooltips/ds_tooltip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/logic/goal_aggregate_rounding.dart';
import 'package:lotti/features/goals/logic/goal_metric_series.dart';
import 'package:lotti/features/goals/model/goal_assessment.dart';
import 'package:lotti/features/goals/model/goal_health_data_types.dart';
import 'package:lotti/features/goals/state/goal_assessment_state.dart';
import 'package:lotti/features/goals/state/goal_progress_view.dart';
import 'package:lotti/features/goals/ui/goal_day_marks.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:lotti/widgets/day_indicators/day_mark.dart';
import 'package:lotti/widgets/day_indicators/day_mark_cell.dart';
import 'package:lotti/widgets/day_indicators/day_mark_strip.dart';
import 'package:lotti/widgets/day_indicators/day_mark_styles.dart';
import 'package:lotti/widgets/day_indicators/day_track.dart';
import 'package:lotti/widgets/misc/linked_scroll_group.dart';

/// Formats an aggregate for display at a precision the number can actually
/// carry.
///
/// The rolling aggregates are means, so a step average arrives as
/// 7684.428571… and `decimalPattern` renders every digit of it. The rule is
/// scale rather than data type, because the same function formats step counts,
/// kilograms and millimetres of mercury:
///
///  * **1000 and above → nearest hundred.** A seven-day step average is an
///    estimate of a habit, not a measurement; "7,684" invites a reader to
///    believe the last two digits mean something, and they do not.
///  * **100 to 999 → whole numbers.** A blood pressure of 127.3 is 127.
///  * **Below 100 → one decimal, and only when there is one.** Weight is the
///    case that needs it: 94.5 kg is a real distinction, 94.53 is not.
///
/// Targets go through the same rule so a value can never appear to miss a
/// target it actually meets, purely because the two were rounded differently.
String formatGoalAggregate(NumberFormat number, num value, {num? against}) {
  // The quantization itself lives in goal_aggregate_rounding.dart, shared
  // with the FACTS renderer so the agent quotes the same number this card
  // prints. Whole results arrive as ints, so decimalPattern never shows a
  // spurious ".0".
  return number.format(roundGoalAggregate(value, against: against));
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
    this.habitsHeadingTrailing,
    this.scrollGroup,
    this.assessments = const [],
    this.specVersionId,
    super.key,
  });

  final GoalProgressView progress;
  final GoalHabitOutcomeSelected? onHabitOutcomeSelected;

  /// The goal's reflection history. A habit day the user judged in the
  /// reflection sheet wears that verdict on its square, outranking the
  /// measured outcome — the same rule the whole-goal strip follows.
  final List<GoalAssessmentRecord> assessments;

  /// The spec version in force, scoping [assessments]: a judgement passed
  /// under retired criteria must not colour a day under the current ones.
  final String? specVersionId;

  /// Trailing control on the FIRST evidence heading — Habits when the goal
  /// has habit rows, otherwise Signals — where the detail page rides its
  /// page-wide time-range picker. A signal-only goal still inherits the
  /// shared span, so it must still get the control that names it.
  final Widget? habitsHeadingTrailing;

  /// The page's unison day-track scroll group; every extended track joins.
  final LinkedScrollGroup? scrollGroup;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final verdictsByHabit = [
      for (final habit in progress.habits)
        latestDimensionRatingsByDay(
          assessments,
          criterionId: habit.criterionId,
          specVersionId: specVersionId,
        ),
    ];
    final patternMetrics = progress.metrics.where(
      (metric) =>
          metric.kind == GoalDimensionKind.categoryTime &&
          metric.categoryTimeSessions.isNotEmpty,
    );
    final bloodPressure = _bloodPressureMetrics(progress.metrics);
    final hasSignalCards =
        progress.metrics.isNotEmpty || patternMetrics.isNotEmpty;
    Widget sectionHeading(String title, {Widget? trailing}) => Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.step3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The whole-goal week lives in [GoalThisWeekCard], placed by the page
        // in its hero stack (design handover §4b) — this widget owns only the
        // evidence sections beneath it: Habits, then the data Signals.
        if (progress.habits.isNotEmpty)
          sectionHeading(
            context.messages.navTabTitleHabits,
            trailing: habitsHeadingTrailing,
          ),
        for (var index = 0; index < progress.habits.length; index++) ...[
          _HabitDimensionCard(
            habit: progress.habits[index],
            today: progress.today,
            onHabitOutcomeSelected: onHabitOutcomeSelected,
            scrollGroup: scrollGroup,
            verdictsByDay: verdictsByHabit[index],
          ),
          SizedBox(height: tokens.spacing.step3),
        ],
        if (hasSignalCards)
          sectionHeading(
            context.messages.goalDetailSignalsTitle,
            // A signal-only goal has no Habits heading; the range picker
            // lands on its first heading instead of vanishing.
            trailing: progress.habits.isEmpty ? habitsHeadingTrailing : null,
          ),
        for (final metric in progress.metrics)
          if (bloodPressure == null || metric != bloodPressure.diastolic) ...[
            if (bloodPressure != null && metric == bloodPressure.systolic)
              _BloodPressureDimensionCard(
                metrics: bloodPressure,
                today: progress.today,
                scrollGroup: scrollGroup,
              )
            else
              _MetricDimensionCard(
                metric: metric,
                today: progress.today,
                scrollGroup: scrollGroup,
              ),
            SizedBox(height: tokens.spacing.step3),
          ],
        for (final patternMetric in patternMetrics) ...[
          _CategoryPatternCard(metric: patternMetric),
          SizedBox(height: tokens.spacing.step3),
        ],
        if (hasSignalCards)
          // The freshness contract for the deterministic layer, stated once
          // under the signals it covers (§4b): live numbers, bounded scope.
          Text(
            context.messages.goalDetailWatchingSignals,
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.lowEmphasis,
            ),
          ),
      ],
    );
  }
}

/// The whole-goal "This week" hero card (design handover §4b): the one place
/// a goal's dimensions are summed into a single week — the large 7-day strip
/// with the user's verdict colours, the Reflect-on-today row, and (for
/// composite goals) the yesterday dimension tally.
class GoalThisWeekCard extends StatelessWidget {
  const GoalThisWeekCard({
    required this.progress,
    this.onReflectDay,
    this.ratingsByDay = const {},
    this.scrollGroup,
    super.key,
  });

  /// Joins the page's unison day-track scrolling when the goal strip spans
  /// more than a week.
  final LinkedScrollGroup? scrollGroup;

  /// Whether the card has anything to show for [progress].
  ///
  /// A composite goal always gets it: the strip is the only place its
  /// dimensions are summed into one week. A leaf goal gets it only where the
  /// days are actionable ([canReflect]) — the feature is about goal days,
  /// and a leaf goal has those too, but without reflection the card would
  /// just duplicate the week its single dimension already draws.
  static bool shouldShow(
    GoalProgressView progress, {
    required bool canReflect,
  }) =>
      progress.compositeRule != null ||
      (canReflect && progress.compactWindow.isNotEmpty);

  final GoalProgressView progress;

  /// Opens a day's reflection from the strip. Null while the goal cannot be
  /// reflected on — a retired agent, or a spec that has not resolved.
  final ValueChanged<DateTime>? onReflectDay;

  final Map<DateTime, DayVerdict> ratingsByDay;

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
              // The shared per-day policy, so this tally cannot disagree with
              // the reflection sheet the strip above it opens.
              DateUtils.isSameDay(day.day, yesterday) && metric.dayMark(day),
        ),
    ].where((met) => met).length;
    final required = progress.requiredSuccesses ?? progress.dimensionCount;
    return DesignSystemSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and the day's own action on ONE row. As a full-width row
          // under the strip the reflection cost the card a touch-target's
          // height plus two gaps to say what a corner button says in the
          // header's own line — and it left the header rail empty.
          //
          // The pairing is CONDITIONAL on the action fitting. Its label is
          // localized and user-scaled — German renders it "Über den heutigen
          // Tag nachdenken" — so at phone width and a raised text scale the
          // button alone can outgrow the card, and an inflexible trailing
          // child in a Row does not shrink, it overflows. Measured rather
          // than guessed at a breakpoint, for exactly that reason.
          _GoalDaysHeader(
            title: progress.compactWindow.length > 7
                // Over the page's shared range the card is no longer a
                // week — it is the goal's day-by-day record over the same
                // span every other track shows.
                ? context.messages.goalDetailGoalDaysTitle
                : context.messages.goalDetailThisWeekTitle,
            action: onReflectDay == null
                ? null
                : _ReflectTodayButton(
                    recorded:
                        ratingsByDay[DateTime.utc(
                          progress.today.year,
                          progress.today.month,
                          progress.today.day,
                        )],
                    onReflect: () => onReflectDay!(progress.today),
                  ),
          ),
          SizedBox(height: tokens.spacing.step1),
          // The strip counts DAYS; the caption below counts dimensions on
          // one day. Naming the frame keeps the two from reading as one
          // contradictory statistic.
          Text(
            progress.compactWindow.length > 7
                ? _periodLabel(context, [
                    for (
                      var offset = progress.compactWindow.length - 1;
                      offset >= 0;
                      offset--
                    )
                      GoalProgressDay(
                        day: progress.today.subtract(Duration(days: offset)),
                        value: 0,
                      ),
                  ])
                : context.messages.goalCompositeLastSevenDays,
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.lowEmphasis,
            ),
          ),
          // step1: the date line labels the strip directly beneath it, the
          // same pairing the habit cards use. A step3 gap made it read as
          // floating between the strip and the title row above. A tappable
          // strip brings its own air: its touch-floor slot is taller than
          // the squares it centres.
          if (onReflectDay == null) SizedBox(height: tokens.spacing.step1),
          // On the card's own rail. It used to be inset by a chart's y-axis
          // gutter so it would line up with plots on other cards — but this
          // card draws no plot, so the gutter was 52px of nothing between the
          // caption above and the first day of the week.
          DayMarkStrip(
            marks: goalDayMarks(
              states: progress.compactWindow,
              lastDay: progress.today,
              verdictsByDay: ratingsByDay,
            ),
            onDaySelected: onReflectDay,
            scrollGroup: scrollGroup,
          ),
          // "3 of 5 dimensions · 4 required" says nothing about a goal with
          // one dimension, so a leaf goal gets the strip without the tally.
          // Centered under the strip it closes, like every legend and summary
          // line on the cards below it.
          if (progress.compositeRule != null) ...[
            SizedBox(height: tokens.spacing.step2),
            SizedBox(
              width: double.infinity,
              child: Text(
                context.messages.goalCompositeProgressSummary(
                  metYesterday,
                  progress.dimensionCount,
                  required,
                ),
                textAlign: TextAlign.center,
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The Goal-days card header: the title with the day's action on its
/// trailing edge, or — when the two cannot share the width — the title with
/// the action on its own line beneath, still end-aligned.
///
/// The action is a button, so it has no ellipsis to fall back on: it either
/// fits or it overflows its row. The decision is taken against the label's
/// MEASURED width of one line of text, at the current locale and text scale.
///
/// Every responsive header on this card decides whether a line fits by
/// laying its text out rather than by consulting a breakpoint: no fixed
/// width can tell whether "Über den heutigen Tag nachdenken" clears a title
/// at 1.6x, and the same question is asked of a reflect action, a period
/// line and a signal's corner block. One measurement, three callers.
double goalTextWidth(BuildContext context, String text, TextStyle style) =>
    (TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout()).width;

/// MEASURED width at the current locale and text scale, because no fixed
/// breakpoint can tell whether "Über den heutigen Tag nachdenken" fits
/// beside a title at 1.6x.
class _GoalDaysHeader extends StatelessWidget {
  const _GoalDaysHeader({required this.title, required this.action});

  final String title;

  /// The trailing action; null while the goal cannot be reflected on.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final titleStyle = tokens.typography.styles.subtitle.subtitle2;
    final action = this.action;
    if (action == null) return Text(title, style: titleStyle);
    return LayoutBuilder(
      builder: (context, constraints) {
        // The button's own ink, from the SAME tokens its dense size spec
        // reads: the caption label, a glyph at the caption's line height,
        // and the gap plus the two horizontal insets around them. Reserving
        // a hand-picked icon constant here would drift from the button the
        // moment the spec changed, and a measurement that under-reserves
        // puts the row back in the overflow it exists to prevent.
        final actionWidth =
            goalTextWidth(
              context,
              context.messages.goalAssessmentReflectToday,
              tokens.typography.styles.others.caption,
            ) +
            tokens.typography.lineHeight.caption +
            tokens.spacing.step2 * 3;
        // The title keeps a readable measure of its own rather than being
        // squeezed to a sliver beside a long action.
        final fitsBeside =
            actionWidth +
                goalTextWidth(context, title, titleStyle) +
                tokens.spacing.step4 <=
            constraints.maxWidth;
        if (fitsBeside) {
          return Row(
            children: [
              Expanded(child: Text(title, style: titleStyle)),
              SizedBox(width: tokens.spacing.step4),
              action,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: titleStyle),
            SizedBox(height: tokens.spacing.step2),
            // Still the card's trailing rail, one line down: the action does
            // not become a leading-aligned row again just because it moved.
            Align(alignment: AlignmentDirectional.centerEnd, child: action),
          ],
        );
      },
    );
  }
}

/// The day's own reflection, as the Goal-days header's trailing action.
///
/// Carries today's state rather than only inviting the action: a control that
/// says "Reflect on today" whether or not you already did is one you have to
/// tap to find out. Once a rating exists the button wears that verdict's glyph
/// and word, so the corner reads as today's answer and stays the way back in.
class _ReflectTodayButton extends StatelessWidget {
  const _ReflectTodayButton({
    required this.recorded,
    required this.onReflect,
  });

  final DayVerdict? recorded;
  final VoidCallback onReflect;

  @override
  Widget build(BuildContext context) {
    final recorded = this.recorded;
    return DesignSystemButton(
      key: const ValueKey('goal-reflect-today'),
      label: recorded == null
          ? context.messages.goalAssessmentReflectToday
          : dayVerdictLabel(context, recorded),
      onPressed: onReflect,
      // The sparkle stays exclusive to agent suggestions; this button is the
      // USER writing a reflection.
      leadingIcon: recorded == null
          ? LottiIcons.editNote
          : dayVerdictGlyph(recorded),
      variant: DesignSystemButtonVariant.tertiary,
      size: DesignSystemButtonSize.dense,
      // The header rail is the card's trailing edge: the ink may bleed into
      // the card padding, the label may not sit inside it.
      tapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}

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

/// The weekday label track paired with the day squares. It shares the same
/// pitch and item extent — and the same horizontal scroller — as the squares
/// below it, so labels and cells can never drift out of alignment.
class _WeekdayTrack extends StatelessWidget {
  const _WeekdayTrack({
    required this.days,
    required this.trackId,
    required this.metrics,
  });

  final List<GoalProgressDay> days;

  /// Key namespace for this track's captions — a habit id, or the metric's
  /// criterion id. Not a habit id as such: a metric track wearing a habit's
  /// identity to reach this widget was the field name lying about itself.
  final String trackId;
  final DayTrackMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final locale = Localizations.localeOf(context).toLanguageTag();
    // The one-letter form only where the column cannot hold "Mon": narrow
    // labels are harder to read, so they are a fallback, not the default.
    final format = metrics.narrowLabels
        ? DateFormat.EEEEE(locale)
        : DateFormat.E(locale);
    return DayTrack(
      height: metrics.labelHeight,
      pitch: metrics.pitch,
      children: [
        for (final day in days)
          SizedBox(
            key: ValueKey(
              'goal-habit-weekday-$trackId-'
              '${day.day.toIso8601String().substring(0, 10)}',
            ),
            width: daySquareSize(context),
            child: OverflowBox(
              maxWidth: double.infinity,
              child: Text(
                format.format(day.day),
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
      GoalDimensionKind.labelTime =>
        context.messages.goalDimensionLabelTimeSource,
    };

/// Index of the authored rolling window's first day inside [activeDays] —
/// the cell the ages-out ring belongs to. Falls back to the list head for
/// non-rolling windows or short lists.
int _windowStartIndex(
  GoalHabitProgressView habit,
  List<GoalProgressDay> activeDays,
) {
  final window = habit.window;
  if (window is! GoalWindowRollingDays) return 0;
  if (activeDays.length < window.count) return 0;
  return activeDays.length - window.count;
}

class _HabitProgressRow extends StatefulWidget {
  const _HabitProgressRow({
    required this.habit,
    required this.today,
    required this.onOutcomeSelected,
    this.successfulWeeks,
    this.scrollGroup,
    this.verdictsByDay = const {},
  });

  final LinkedScrollGroup? scrollGroup;
  final Map<DateTime, DayVerdict> verdictsByDay;

  /// The rolling-week reliability tail, drawn on the trailing edge of the
  /// window line. Null for habits whose window is not a rolling week — the
  /// tail counts weeks, and nothing else here is measured in them.
  final int? successfulWeeks;
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
          SnackBar(content: Text(context.messages.saveFailedRetry)),
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
    // flattened by repetition. A habit that is AT its rate says nothing here:
    // the header already reads "On track", and the cryptic "at rate" beside
    // the reliability tail read as part of that figure.
    final note = habit.deficit == 0
        ? null
        : context.messages.goalDaysToRecover(habit.deficit);
    // NO cadence line at all: the corner block now carries count, target AND
    // the concrete window ("1 of 3 · calendar week"), so a "3× · calendar
    // week" line here would be the same facts twice on one card. The period
    // line is left with the one thing nothing else states: which dates the
    // squares below it cover.
    final cadenceStyle = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.lowEmphasis,
    );
    final noteStyle = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.mediumEmphasis,
    );
    Widget cells(DayTrackMetrics metrics) {
      // Interactive rows own a touch-floor-high track so each cell's hit
      // slot meets TapTargets.minimum vertically; read-only rows keep the
      // compact height.
      final trackHeight = widget.onOutcomeSelected == null
          ? daySquareSize(context)
          : TapTargets.minimum;
      return DayTrack(
        height: trackHeight,
        pitch: metrics.pitch,
        children: [
          for (var index = 0; index < activeDays.length; index++)
            _ProgressDayCell(
              day: activeDays[index],
              habitId: habit.habitId,
              today: DateUtils.isSameDay(
                activeDays[index].day,
                widget.today,
              ),
              verdict:
                  widget.verdictsByDay[DateTime.utc(
                    activeDays[index].day.year,
                    activeDays[index].day.month,
                    activeDays[index].day.day,
                  )],
              // The WINDOW's first day — with the page's shared span
              // rendering extra history, the list head can be a blank day
              // weeks before the window.
              agingOut:
                  index == _windowStartIndex(habit, activeDays) &&
                  habit.oldestSuccessAgesOutTonight,
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

    // The squares alone; the date axis is the tooltip on each of them.
    Widget track(DayTrackMetrics metrics) => cells(metrics);

    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = dayTrackMetrics(context);
        final contentWidth = metrics.pitch * activeDays.length;
        final periodLine = _periodLabel(context, activeDays);
        // The deficit note shares the period line whenever everything on it
        // fits side by side: facts about the same window on one caption row,
        // instead of a dedicated line whose only content is usually one short
        // sentence. Only a narrow card stacks them.
        final successfulWeeks = widget.successfulWeeks;
        // The tail measured, not guessed: its bars are token-sized and its
        // caption is localized, so the only honest width is a laid-out one.
        final reliabilityWidth = successfulWeeks == null
            ? 0.0
            : _Reliability.bars * BorderWidths.emphasis * 2 +
                  (_Reliability.bars - 1) * tokens.spacing.step1 +
                  tokens.spacing.step3 +
                  goalTextWidth(
                    context,
                    context.messages.goalReliabilityWeeks(successfulWeeks),
                    noteStyle,
                  );
        final noteSharesLine =
            note != null &&
            goalTextWidth(context, periodLine, cadenceStyle) +
                    tokens.spacing.step4 +
                    goalTextWidth(context, note, noteStyle) +
                    (reliabilityWidth == 0
                        ? 0
                        : tokens.spacing.step4 + reliabilityWidth) <=
                constraints.maxWidth;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The stacked fallback: the note flush to the trailing edge under
            // the corner block it qualifies, with the whole row to itself —
            // it wraps only when the card is narrower than the sentence, not
            // at an arbitrary fraction of a row nothing else shares.
            if (note != null && !noteSharesLine) ...[
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Text(note, textAlign: TextAlign.end, style: noteStyle),
              ),
              SizedBox(height: tokens.spacing.step2),
            ],
            // The span the squares below cover, on the same rail as the
            // squares themselves — it used to sit a chart's y-axis gutter to
            // their left, keyed to a plot this card does not draw.
            KeyedSubtree(
              key: ValueKey('goal-habit-plot-${habit.habitId}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Window line: which days these squares cover, and — for a
                  // rolling week — how many of the last six the habit
                  // actually carried. One row, because both qualify the same
                  // window; the tail on the trailing rail, so the line reads
                  // span-then-record rather than as two stacked captions.
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          periodLine,
                          style: cadenceStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (noteSharesLine) ...[
                        SizedBox(width: tokens.spacing.step4),
                        Text(note, style: noteStyle),
                      ],
                      const Spacer(),
                      if (successfulWeeks != null) ...[
                        SizedBox(width: tokens.spacing.step4),
                        _Reliability(successfulWeeks: successfulWeeks),
                      ],
                    ],
                  ),
                  // step1, not step2: the window line LABELS the squares, so
                  // it has to read as attached to them rather than floating
                  // midway between them and the header block above. A
                  // tappable track brings its own air: its touch-floor slot
                  // is taller than the square it centres.
                  if (widget.onOutcomeSelected == null)
                    SizedBox(height: tokens.spacing.step1),
                  // Labels and squares pan as one unit, and only where even
                  // the narrowest column overflows.
                  fitOrScrollDayTrack(
                    contentWidth: contentWidth,
                    availableWidth: constraints.maxWidth,
                    group: widget.scrollGroup,
                    child: track(metrics),
                  ),
                ],
              ),
            ),
            if (widget.onOutcomeSelected != null &&
                habit.suggestedFromDimensionName != null) ...[
              SizedBox(height: tokens.spacing.step4),
              // The design system's inline callout, with the action it is
              // asking for on its trailing edge: this is the one thing on the
              // card the app wants the user to do, and as a caption row
              // between two other caption rows it read as more fine print.
              DesignSystemInlineCallout(
                key: ValueKey('goal-habit-checkoff-callout-${habit.habitId}'),
                icon: LottiIcons.aiSpark,
                tone: tokens.colors.interactive.enabled,
                text: context.messages.goalHabitCheckOffSuggestion(
                  habit.suggestedFromDimensionName!,
                ),
                trailing: DesignSystemButton(
                  key: ValueKey('goal-habit-checkoff-${habit.habitId}'),
                  label: context.messages.goalHabitCheckOffAction,
                  onPressed: _savingDay != null
                      ? null
                      : () => _recordOutcome(
                          widget.today,
                          HabitCompletionType.success,
                        ),
                  size: DesignSystemButtonSize.dense,
                  leadingIcon: LottiIcons.confirm,
                ),
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

class _ProgressDayCell extends StatelessWidget {
  const _ProgressDayCell({
    required this.day,
    required this.habitId,
    required this.agingOut,
    required this.saving,
    required this.enabled,
    required this.onOutcomeSelected,
    required this.today,
    this.verdict,
  });

  final GoalProgressDay day;
  final String habitId;

  /// Whether this is the current day. Empty and unjudged, it draws as the
  /// dashed unresolved outline rather than a past day's neutral fill.
  final bool today;

  /// The user's verdict on this habit for this day, when they recorded one
  /// in the reflection sheet. It decides the fill; the measured outcome is
  /// only what the app observed.
  final DayVerdict? verdict;

  /// Whether this is the window's oldest kept day and it ages out tonight.
  /// Said in the tooltip and the semantics, not drawn on the square.
  final bool agingOut;
  final bool saving;
  final bool enabled;
  final ValueChanged<HabitCompletionType>? onOutcomeSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final completionType = day.habitCompletionType;
    final missed = completionType == HabitCompletionType.fail;
    // A completed day is a partial success (lighter wash) while the habit's
    // own window target was not yet met as of that day; a null verdict from
    // older projections keeps the established full-strength rendering.
    final dayState = goalProgressDayMarkState(day);
    // A recorded verdict outranks the measured outcome for the fill, exactly
    // as on the whole-goal strip: the measurement is evidence, the
    // reflection is the user's ruling on the day.
    final verdict = this.verdict;
    final dayKey = day.day.toIso8601String().substring(0, 10);
    final pending =
        today &&
        verdict == null &&
        dayState == DayMarkState.none &&
        (completionType == null || completionType == HabitCompletionType.open);
    final size = daySquareSize(context);
    Widget cell = pending
        ? PlaceholderDayCell(
            key: ValueKey('goal-habit-day-visual-$habitId-$dayKey'),
            day: day.day,
          )
        : Container(
            key: ValueKey('goal-habit-day-visual-$habitId-$dayKey'),
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: verdict == null
                  ? dayMarkStateFill(tokens, dayState)
                  : dayVerdictFill(tokens, verdict),
              borderRadius: BorderRadius.circular(tokens.radii.xs),
            ),
            child: dayMarkSquareContent(
              context,
              state: dayState,
              verdict: verdict,
              day: day.day,
              size: size,
            ),
          );
    if (dayState == DayMarkState.partial) {
      cell = KeyedSubtree(
        key: ValueKey('goal-day-partial-$habitId-$dayKey'),
        child: cell,
      );
    }
    if (missed) {
      cell = KeyedSubtree(
        key: ValueKey('goal-day-missed-$habitId-$dayKey'),
        child: cell,
      );
    }
    final locale = Localizations.localeOf(context).toLanguageTag();
    final date = DateFormat.yMMMd(locale).format(day.day);
    final menuDate = DateFormat.MMMEd(locale).format(day.day);
    final measured = switch (completionType) {
      HabitCompletionType.success =>
        context.messages.completeHabitSuccessButton,
      HabitCompletionType.skip => context.messages.completeHabitSkipButton,
      HabitCompletionType.fail => context.messages.completeHabitFailButton,
      HabitCompletionType.open ||
      null => context.messages.goalProgressHabitDayNoEntry,
    };
    // Spoken and hovered as the verdict where one stands, the measurement
    // otherwise — the cell must say what it shows. The ages-out fact rides
    // along: the square has no room to draw it.
    final ruling = verdict == null
        ? measured
        : dayVerdictLabel(context, verdict);
    final outcome = [
      ruling,
      if (agingOut) context.messages.goalProgressAgesOut,
    ].join(' · ');
    final semanticLabel = context.messages.goalProgressHabitDaySemantics(
      date,
      outcome,
    );
    final callback = onOutcomeSelected;
    if (callback == null) {
      return Semantics(
        label: semanticLabel,
        excludeSemantics: true,
        child: DsTooltip(
          title: menuDate,
          message: outcome,
          preferBelow: false,
          child: cell,
        ),
      );
    }
    return Semantics(
      label: semanticLabel,
      button: true,
      enabled: enabled && !saving,
      excludeSemantics: true,
      // The square stays small; the hit slot meets the design system's touch
      // floor vertically and fills the track pitch horizontally — invisible
      // ergonomics, unchanged rhythm.
      child: SizedBox.expand(
        key: ValueKey('goal-habit-day-$habitId-$dayKey'),
        child: _HabitDayOutcomeMenu(
          enabled: enabled && !saving,
          currentOutcome: completionType,
          headerKey: ValueKey('goal-habit-day-date-$habitId-$dayKey'),
          menuDate: menuDate,
          outcomeLabel: outcome,
          semanticLabel: semanticLabel,
          onSelected: callback,
          child: Center(
            child: saving
                ? SizedBox.square(
                    dimension: size,
                    child: const CircularProgressIndicator(
                      strokeWidth: BorderWidths.emphasis,
                    ),
                  )
                : cell,
          ),
        ),
      ),
    );
  }
}

/// The goal-details quick picker for one habit day.
///
/// This stays intentionally smaller than the full habit-recording dialog: a
/// date header and four immediate actions. The old Material popup left its
/// last hover band above the rounded bottom edge; the design-system menu uses
/// one clipped, edge-to-edge surface so the highlight follows both corners.
class _HabitDayOutcomeMenu extends StatefulWidget {
  const _HabitDayOutcomeMenu({
    required this.enabled,
    required this.currentOutcome,
    required this.headerKey,
    required this.menuDate,
    required this.outcomeLabel,
    required this.semanticLabel,
    required this.onSelected,
    required this.child,
  });

  final bool enabled;
  final HabitCompletionType? currentOutcome;
  final Key headerKey;
  final String menuDate;

  /// The day's recorded outcome, localized — the tooltip's body line.
  final String outcomeLabel;
  final String semanticLabel;
  final ValueChanged<HabitCompletionType> onSelected;
  final Widget child;

  @override
  State<_HabitDayOutcomeMenu> createState() => _HabitDayOutcomeMenuState();
}

class _HabitDayOutcomeMenuState extends State<_HabitDayOutcomeMenu> {
  final MenuController _controller = MenuController();

  bool _isSelected(HabitCompletionType outcome) =>
      outcome == HabitCompletionType.open
      ? widget.currentOutcome == null ||
            widget.currentOutcome == HabitCompletionType.open
      : widget.currentOutcome == outcome;

  void _select(HabitCompletionType outcome) {
    _controller.close();
    if (_isSelected(outcome)) return;
    widget.onSelected(outcome);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return MenuAnchor(
      controller: _controller,
      alignmentOffset: Offset(0, tokens.spacing.step2),
      style: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Colors.transparent),
        elevation: WidgetStatePropertyAll(0),
        padding: WidgetStatePropertyAll(EdgeInsets.zero),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder()),
        side: WidgetStatePropertyAll(BorderSide.none),
      ),
      menuChildren: [
        DesignSystemContextMenu(
          key: const ValueKey('goal-habit-day-menu'),
          header: widget.menuDate,
          headerKey: widget.headerKey,
          edgeToEdge: true,
          size: DesignSystemContextMenuSize.small,
          width: tokens.spacing.step13,
          semanticsLabel: widget.semanticLabel,
          items: [
            DesignSystemContextMenuItem(
              key: const ValueKey('goal-habit-day-success'),
              label: context.messages.completeHabitSuccessButton,
              icon: LottiIcons.confirm,
              iconColor: tokens.colors.alert.success.ink,
              isSelected: _isSelected(HabitCompletionType.success),
              onTap: () => _select(HabitCompletionType.success),
            ),
            DesignSystemContextMenuItem(
              key: const ValueKey('goal-habit-day-skipped'),
              label: context.messages.completeHabitSkipButton,
              icon: LottiIcons.remove,
              iconColor: tokens.colors.text.mediumEmphasis,
              isSelected: _isSelected(HabitCompletionType.skip),
              onTap: () => _select(HabitCompletionType.skip),
            ),
            DesignSystemContextMenuItem(
              key: const ValueKey('goal-habit-day-missed'),
              label: context.messages.completeHabitFailButton,
              icon: LottiIcons.close,
              iconColor: tokens.colors.alert.error.ink,
              isSelected: _isSelected(HabitCompletionType.fail),
              onTap: () => _select(HabitCompletionType.fail),
            ),
            DesignSystemContextMenuItem(
              key: const ValueKey('goal-habit-day-none'),
              label: context.messages.goalProgressHabitDayNoEntry,
              icon: LottiIcons.radioUnselected,
              iconColor: tokens.colors.text.lowEmphasis,
              isSelected: _isSelected(HabitCompletionType.open),
              onTap: () => _select(HabitCompletionType.open),
            ),
          ],
        ),
      ],
      // No hover fill: the pitch-wide hit slot is far larger than the square
      // it serves, so the overlay drew a phantom button around the cell.
      // Hover answers with the styled tooltip naming the day and its
      // recorded outcome instead.
      builder: (context, controller, child) => DsTooltip(
        title: widget.menuDate,
        message: widget.outcomeLabel,
        preferBelow: false,
        child: DsQuietInk(
          onTap: widget.enabled
              ? () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                }
              : null,
          borderRadius: BorderRadius.circular(tokens.radii.s),
          focusRing: true,
          builder: (context, highlighted) => widget.child,
        ),
      ),
    );
  }
}

class _Reliability extends StatelessWidget {
  const _Reliability({required this.successfulWeeks});

  /// Weeks the tail draws. Public so the window line can reserve the tail's
  /// width from the same number the tail is built from.
  static const int bars = 6;

  final int successfulWeeks;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    // Bars and their caption on ONE line, on the trailing rail of the window
    // line they qualify. Hugging, not stretching: the row that hosts it owns
    // the slack.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < bars; index++) ...[
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
        SizedBox(width: tokens.spacing.step3),
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
    final locale = Localizations.localeOf(context).toString();
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
                            DateFormat.MMMEd(locale).add_jm().format(
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

/// The measured day-mark state a habit's [GoalProgressDay] renders as: a
/// recorded miss or skip first, then whether the day was hit, then whether
/// the habit's own window target was met as of that day — a completed day
/// while the target was still building is the lighter wash; a null verdict
/// from older projections keeps the established full-strength rendering.
DayMarkState goalProgressDayMarkState(GoalProgressDay day) =>
    switch (day.habitCompletionType) {
      HabitCompletionType.fail => DayMarkState.missed,
      HabitCompletionType.skip => DayMarkState.skipped,
      _ when !day.hasValue => DayMarkState.none,
      _ when day.targetSatisfied ?? true => DayMarkState.full,
      _ => DayMarkState.partial,
    };
