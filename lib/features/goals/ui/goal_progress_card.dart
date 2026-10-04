import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_health_data_types.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/classes/observation.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_bar_line_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_line_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_multiline_chart.dart';
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
import 'package:lotti/features/goals/state/goal_assessment_state.dart';
import 'package:lotti/features/goals/state/goal_progress_view.dart';
import 'package:lotti/features/goals/ui/goal_day_marks.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/device_datetime.dart';
import 'package:lotti/widgets/charts/time_series_utils.dart';
import 'package:lotti/widgets/day_indicators/day_mark.dart';
import 'package:lotti/widgets/day_indicators/day_mark_cell.dart';
import 'package:lotti/widgets/day_indicators/day_mark_strip.dart';
import 'package:lotti/widgets/day_indicators/day_mark_styles.dart';
import 'package:lotti/widgets/day_indicators/day_track.dart';
import 'package:lotti/widgets/misc/linked_scroll_group.dart';
import 'package:material_ui/material_ui.dart';

part 'goal_progress_card_days_part.dart';
part 'goal_progress_card_dimensions_part.dart';
part 'goal_progress_card_series_part.dart';

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
