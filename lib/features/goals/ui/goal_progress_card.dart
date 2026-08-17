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
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/components/ds_dashed_border.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/logic/goal_aggregate_rounding.dart';
import 'package:lotti/features/goals/logic/goal_metric_series.dart';
import 'package:lotti/features/goals/model/goal_assessment.dart';
import 'package:lotti/features/goals/model/goal_health_data_types.dart';
import 'package:lotti/features/goals/state/goal_progress_view.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:lotti/widgets/misc/linked_scroll_group.dart';

/// The handover's seven-cell picture used on each Agents-list row. It is
/// intentionally unlabeled visually, but exposes one concise semantic summary.
class GoalCompactWindowStrip extends StatelessWidget {
  const GoalCompactWindowStrip({
    required this.days,
    this.placeholder = false,
    this.cellSize = ControlSizes.iconChipCompact,
    this.lastDay,
    this.onDaySelected,
    this.ratingsByDay = const {},
    this.scrollGroup,
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

  /// Edge of one day's square. Defaults to the habit day square's size —
  /// list rows and the detail page draw the same instrument at the same
  /// scale. The 12px default the list once used rendered as illegible dots.
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

  /// Joins the page's unison day-track scrolling when the strip renders a
  /// span longer than a week.
  final LinkedScrollGroup? scrollGroup;

  DateTime _dateAt(int index, int length) =>
      lastDay!.subtract(Duration(days: length - 1 - index));

  GoalAssessmentRating? _ratingAt(int index, int length) {
    if (ratingsByDay.isEmpty || lastDay == null) return null;
    final date = _dateAt(index, length);
    return ratingsByDay[DateTime.utc(date.year, date.month, date.day)];
  }

  @override
  Widget build(BuildContext context) {
    // The full span, not a seven-day cap: on the detail page the strip
    // follows the page's shared range like every other day track (the list
    // rows keep passing seven-day windows).
    if (days.isEmpty) return const SizedBox.shrink();
    // Only the extended span needs to know the width it has to fit into; the
    // seven-cell list rows keep their authored pitch and their scale-down fit.
    if (days.length <= 7) return _build(context, availableWidth: null);
    return LayoutBuilder(
      builder: (context, constraints) => _build(
        context,
        availableWidth: constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : null,
      ),
    );
  }

  Widget _build(BuildContext context, {required double? availableWidth}) {
    final tokens = context.designTokens;
    final visible = days;
    final onDaySelected = this.onDaySelected;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final trackDayList = [
      for (var index = 0; index < visible.length; index++)
        GoalProgressDay(
          day: lastDay == null
              ? DateTime.utc(2000, 1, index + 1)
              : _dateAt(index, visible.length),
          value: 0,
        ),
    ];
    final metrics = goalDayTrackMetrics(
      context,
      trackDayList,
      availableWidth: availableWidth,
    );
    // A caller-chosen cell size still wins where the columns are not being
    // squeezed — the list rows deliberately draw at the habit square's scale.
    final resolvedCellSize = math.min(cellSize, metrics.cellSize);

    Widget cellAt(int index) {
      if (placeholder) return _PlaceholderDayCell(size: resolvedCellSize);
      final today = index == visible.length - 1;
      final rating = _ratingAt(index, visible.length);
      if (onDaySelected == null) {
        return _CompactDayCell(
          state: visible[index],
          today: today,
          size: resolvedCellSize,
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
        size: resolvedCellSize,
        rating: rating,
        label: context.messages.goalProgressHabitDaySemantics(
          dayName,
          outcome,
        ),
        onTap: () => onDaySelected(date),
      );
    }

    // On the page's shared seven-column track when it carries dates, so the
    // whole-goal week lines up column-for-column with the habit squares and
    // the metric bars below it. Three grids for one week meant a reader
    // could not follow a Wednesday down the page.
    //
    // The pitch is narrower than the 48px touch floor — seven of those do not
    // fit a phone card — so, exactly as the habit cells already do, the slot
    // takes the full pitch horizontally and clears the floor vertically.
    final trackDays = lastDay == null ? null : trackDayList;
    final row = trackDays == null
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < visible.length; index++) ...[
                if (index > 0) SizedBox(width: tokens.spacing.step1),
                cellAt(index),
              ],
            ],
          )
        : _DayTrack(
            height: onDaySelected == null
                ? resolvedCellSize + tokens.spacing.step2
                : TapTargets.minimum,
            pitch: metrics.pitch,
            children: [
              for (var index = 0; index < visible.length; index++)
                cellAt(index),
            ],
          );

    // A read-only strip publishes one summary rather than seven nodes, so any
    // recorded verdicts have to reach it there — otherwise the list announces
    // a measured day count while showing four verdict hues.
    final verdictSummary = ratingsByDay.isEmpty || lastDay == null
        ? ''
        : [
            for (var index = 0; index < visible.length; index++)
              if (_ratingAt(index, visible.length) case final rating?)
                context.messages.goalProgressHabitDaySemantics(
                  DateFormat.MMMEd(locale).format(
                    _dateAt(index, visible.length),
                  ),
                  goalAssessmentRatingLabel(context, rating),
                ),
          ].join(', ');

    final labelled = trackDays == null
        ? row
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Same track as the cells, so a label always sits over its own
              // column. This strip used to be seven bare squares that each
              // opened a specific date's sheet, with no way to tell which.
              _DayTrack(
                height: math.max(
                  IconSizes.s,
                  _weekdayLabelMetrics(context, trackDays).height,
                ),
                pitch: metrics.pitch,
                children: [
                  for (final day in trackDays)
                    Text(
                      (metrics.narrowLabels
                              ? DateFormat.EEEEE(locale)
                              : DateFormat.E(locale))
                          .format(day.day),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: tokens.typography.styles.others.caption.copyWith(
                        color: tokens.colors.text.lowEmphasis,
                      ),
                    ),
                ],
              ),
              row,
            ],
          );

    return Semantics(
      label: placeholder
          ? context.messages.goalProgressStripLoading
          : [
              // Counted with the verdicts applied. Taken from the measured
              // states alone, the strip could announce "1 successful day"
              // and name that same date as Missed in the next breath, while
              // the cell itself correctly showed the verdict.
              context.messages.goalProgressCompactSemantics(
                [
                  for (var index = 0; index < visible.length; index++)
                    if (_ratingAt(index, visible.length) case final rating?)
                      rating == GoalAssessmentRating.met
                    else
                      visible[index] != GoalCompactDayState.none,
                ].where((successful) => successful).length,
              ),
              if (verdictSummary.isNotEmpty) verdictSummary,
            ].join('. '),
      // A tappable strip publishes each day as its own button, so the summary
      // above becomes the container's label rather than the whole story.
      // The scale-down FittedBox is the overflow bound: the track (and the
      // dateless placeholder Row) size themselves to `pitch * days`, and on
      // a 320px phone a list row's column is a few pixels narrower than
      // seven full-size cells. Everywhere with room, the fit is identity.
      // A span wider than a week scrolls (in unison with the other tracks)
      // instead of scale-down-fitting: thirty cells squeezed into a card
      // width would be unreadable dots.
      child: visible.length > 7
          ? _LinkedDayTrackScroller(group: scrollGroup, child: labelled)
          : onDaySelected == null
          ? ExcludeSemantics(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: labelled,
              ),
            )
          : Align(
              alignment: AlignmentDirectional.centerStart,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: labelled,
              ),
            ),
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
        radius: goalDayCellRadius(tokens),
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
        borderRadius: BorderRadius.circular(goalDayCellRadius(tokens)),
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
          : rating != null
          // The verdict's own shape at every size. Collapsing the three
          // non-met verdicts into one dot on the list's 12px cells left
          // Improving, Mixed and Missed distinguishable by hue alone —
          // which is the one thing the shapes exist to avoid.
          ? Center(
              child: Icon(
                goalAssessmentRatingGlyph(rating),
                size: size * 0.75,
                // The ink of the fill's OWN family. Painting every glyph in
                // the success ink put a green tick's colour on a red missed
                // cell and an orange mixed one.
                color: goalAssessmentRatingInk(tokens, rating),
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
            radius: goalDayCellRadius(tokens),
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

/// The corner radius every day cell on this page shares.
///
/// The whole-goal strip drew its squares at `radii.xs` while the habit
/// squares — the identical footprint, one card below — drew theirs at
/// `radii.s`. Same instrument, same week, two shapes.
double goalDayCellRadius(DsTokens tokens) => tokens.radii.s;

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

/// The ink a verdict glyph is drawn in, on top of that verdict's own fill.
///
/// One high-contrast ink for every verdict rather than each family's own:
/// the families' inks are tuned to sit on a NEUTRAL surface, so a success ink
/// on a success fill is green on green and the glyph all but disappears —
/// which defeats the point of having a shape at all, since the shape exists
/// for readers who cannot separate the hues. `onInteractiveAlert` is the
/// design system's ink for exactly this: text over a saturated alert fill.
Color goalAssessmentRatingInk(DsTokens tokens, GoalAssessmentRating rating) =>
    tokens.colors.text.onInteractiveAlert;

/// The verdict's ink for a glyph drawn on an ordinary card surface.
///
/// Distinct from [goalAssessmentRatingInk], which is for a glyph sitting on
/// that verdict's own saturated fill. Using the on-alert ink here paints
/// near-background on background; using this one on a fill would be its own
/// hue on itself.
Color goalAssessmentRatingSurfaceInk(
  DsTokens tokens,
  GoalAssessmentRating rating,
) => switch (rating) {
  GoalAssessmentRating.met => tokens.colors.alert.success.ink,
  GoalAssessmentRating.improving => tokens.colors.alert.info.ink,
  GoalAssessmentRating.mixed => tokens.colors.alert.warning.ink,
  GoalAssessmentRating.missed => tokens.colors.alert.error.ink,
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
    this.alsoInGoalTitlesByHabitId = const {},
    this.habitsHeadingTrailing,
    this.scrollGroup,
    super.key,
  });

  final GoalProgressView progress;
  final GoalHabitOutcomeSelected? onHabitOutcomeSelected;

  /// Trailing control on the FIRST evidence heading — Habits when the goal
  /// has habit rows, otherwise Signals — where the detail page rides its
  /// page-wide time-range picker. A signal-only goal still inherits the
  /// shared span, so it must still get the control that names it.
  final Widget? habitsHeadingTrailing;

  /// The page's unison day-track scroll group; every extended track joins.
  final LinkedScrollGroup? scrollGroup;

  /// For each habit id, the OTHER goals sharing it, pre-joined for display
  /// ("Heart Health"). A habit is recorded once and reflected everywhere
  /// (design handover §5) — the suffix says where else that one recording
  /// lands. Empty means: render no suffix.
  final Map<String, String> alsoInGoalTitlesByHabitId;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
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
            showLegend: index == 0,
            alsoInGoals:
                alsoInGoalTitlesByHabitId[progress.habits[index].habitId],
            scrollGroup: scrollGroup,
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
          Text(
            // Over the page's shared range the card is no longer a week —
            // it is the goal's day-by-day record over the same span every
            // other track shows.
            progress.compactWindow.length > 7
                ? context.messages.goalDetailGoalDaysTitle
                : context.messages.goalDetailThisWeekTitle,
            style: tokens.typography.styles.subtitle.subtitle2,
          ),
          SizedBox(height: tokens.spacing.step3),
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
          SizedBox(height: tokens.spacing.step2),
          // On the card's own rail. It used to be inset by a chart's y-axis
          // gutter so it would line up with plots on other cards — but this
          // card draws no plot, so the gutter was 52px of nothing between the
          // caption above and the first day of the week.
          GoalCompactWindowStrip(
            days: progress.compactWindow,
            lastDay: progress.today,
            onDaySelected: onReflectDay,
            ratingsByDay: ratingsByDay,
            scrollGroup: scrollGroup,
          ),
          // Directly under the week it closes off, and inside the same card.
          // Stranded at the very bottom of the page — after every habit card,
          // the legend and every chart — the one thing the user is meant to do
          // daily was the quietest row on the surface, and nothing connected
          // it to the strip whose cells open the very same sheet.
          if (onReflectDay != null) ...[
            SizedBox(height: tokens.spacing.step3),
            _ReflectTodayRow(
              today: progress.today,
              recorded:
                  ratingsByDay[DateTime.utc(
                    progress.today.year,
                    progress.today.month,
                    progress.today.day,
                  )],
              onReflect: () => onReflectDay!(progress.today),
            ),
          ],
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

/// The day's own reflection, docked under the week it closes off.
///
/// Carries today's state rather than only inviting the action: a row that
/// says "Reflect on today" whether or not you already did is a row you have
/// to tap to find out.
class _ReflectTodayRow extends StatelessWidget {
  const _ReflectTodayRow({
    required this.today,
    required this.recorded,
    required this.onReflect,
  });

  final DateTime today;
  final GoalAssessmentRating? recorded;
  final VoidCallback onReflect;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final recorded = this.recorded;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onReflect,
        borderRadius: BorderRadius.circular(tokens.radii.s),
        child: ConstrainedBox(
          // Moving this out of a tappable section card into an inner InkWell
          // left the row's own height as the target: two icons plus `step2`
          // padding is about 32px, under the floor — on the ONE action the
          // user is meant to take daily.
          constraints: const BoxConstraints(minHeight: TapTargets.minimum),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: tokens.spacing.step2),
            child: Row(
              children: [
                // The sparkle stays exclusive to agent suggestions; this row is
                // the USER writing a reflection.
                Icon(
                  recorded == null
                      ? Icons.edit_note_rounded
                      : goalAssessmentRatingGlyph(recorded),
                  // The verdict's own family ink, NOT the on-alert ink: this
                  // glyph sits on the card surface, where the on-alert ink is
                  // near-invisible by design — it is tuned for glyphs drawn on
                  // a saturated fill, which is where the strip uses it.
                  color: recorded == null
                      ? tokens.colors.interactive.enabled
                      : goalAssessmentRatingSurfaceInk(tokens, recorded),
                ),
                SizedBox(width: tokens.spacing.step3),
                Expanded(
                  child: Text(
                    recorded == null
                        ? context.messages.goalAssessmentReflectToday
                        : goalAssessmentRatingLabel(context, recorded),
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: tokens.colors.text.highEmphasis,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: tokens.colors.text.lowEmphasis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HabitDimensionCard extends StatelessWidget {
  const _HabitDimensionCard({
    required this.habit,
    required this.today,
    required this.onHabitOutcomeSelected,
    required this.showLegend,
    this.alsoInGoals,
    this.scrollGroup,
  });

  final LinkedScrollGroup? scrollGroup;
  final GoalHabitProgressView habit;
  final DateTime today;
  final GoalHabitOutcomeSelected? onHabitOutcomeSelected;

  /// The other goals sharing this habit, pre-joined; null renders nothing.
  final String? alsoInGoals;

  /// Whether this card carries the shared day-cell key. Set on the FIRST habit
  /// card only — one legend per goal, and placed where a reader meets the
  /// squares it explains rather than four cards below them.
  final bool showLegend;

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
            // Past the target the "X of Y" frame stops parsing — "6 of 3 this
            // window" reads as a broken fraction rather than as three
            // completions to spare — so an exceeded quota states the count and
            // names the target beside it.
            reading: habit.successesInWindow > habit.targetCount
                ? context.messages.goalDimensionHabitReadingOverTarget(
                    habit.successesInWindow,
                    habit.targetCount,
                  )
                : context.messages.goalDimensionHabitReading(
                    habit.successesInWindow,
                    habit.targetCount,
                  ),
            met: habit.deficit == 0,
            hasData: true,
          ),
          if (alsoInGoals case final alsoIn?) ...[
            SizedBox(height: tokens.spacing.step1),
            Text(
              context.messages.goalDetailAlsoInGoal(alsoIn),
              key: ValueKey('goal-habit-also-in-${habit.habitId}'),
              style: tokens.typography.styles.others.caption.copyWith(
                color: tokens.colors.text.lowEmphasis,
              ),
            ),
          ],
          SizedBox(height: tokens.spacing.step4),
          _HabitProgressRow(
            habit: habit,
            today: today,
            onOutcomeSelected: onHabitOutcomeSelected,
            scrollGroup: scrollGroup,
          ),
          // The six-week tail closes the card, on its own row under the days
          // it summarises. Riding the trailing edge of a heading three rows
          // up, it was one of six figures competing for the same band of the
          // card with nothing saying which qualified which.
          if (successfulWeeks != null) ...[
            SizedBox(height: tokens.spacing.step4),
            _Reliability(successfulWeeks: successfulWeeks),
          ],
          // Inside the card, under the squares it keys. On the page background
          // between two cards it was equidistant from both and read as
          // annotating the chart below — which it does not explain at all.
          // Once per goal, not once per habit: it is the same key.
          if (showLegend) ...[
            SizedBox(height: tokens.spacing.step4),
            Divider(
              height: tokens.spacing.step4,
              color: tokens.colors.decorative.level01,
            ),
            SizedBox(height: tokens.spacing.step3),
            const _ProgressLegend(),
          ],
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
  // Whether the most recent observation moved TOWARD the target relative to
  // the one before it. Not a trend — two points never are — but it is the
  // difference between "behind" and "behind and getting worse", and it is the
  // one thing the seven bars above cannot say on their own.
  final previousDay = observed.length < 2
      ? null
      : observed[observed.length - 2];
  // For a `count` criterion a day either qualifies or it does not — its
  // magnitude carries no progress at all — so comparing raw values called a
  // bigger qualifying day an improvement over a smaller one that moved the
  // count by exactly as much.
  final improving =
      latestDay != null &&
      previousDay != null &&
      (metric.aggregation == GoalAggregation.count
          ? _countsTowardTally(metric, latestDay) &&
                !_countsTowardTally(metric, previousDay)
          : metric.direction == GoalDirection.atLeast
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
              leftAxisWidth: chartLeftAxisWidth(
                context,
                niceAxis(yValues.reduce(math.min), yValues.reduce(math.max)),
              ),
            ),
            SizedBox(height: tokens.spacing.step3),
            // Two lines, two entries. Each carries its own threshold as a
            // quiet annotation instead of claiming a second swatch of the
            // same hue.
            DashboardChartLegend(
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
    final reading = unit == null || unit.isEmpty
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
          ],
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
      GoalDimensionKind.labelTime => tokens.colors.alert.warning.defaultColor,
    };
    final icon = switch (kind) {
      GoalDimensionKind.habit => Icons.check_circle_outline_rounded,
      GoalDimensionKind.health => Icons.favorite_outline_rounded,
      GoalDimensionKind.measurable => Icons.straighten_rounded,
      GoalDimensionKind.categoryTime => Icons.schedule_rounded,
      GoalDimensionKind.labelTime => Icons.label_outline_rounded,
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
    final statusColor = !hasData
        ? tokens.colors.text.mediumEmphasis
        : met
        ? tokens.colors.alert.success.ink
        : tokens.colors.alert.warning.ink;
    // The value and its verdict belong on ONE line: "124 / 74 mmHg" with
    // "On target today" stacked underneath read as two unrelated facts, and
    // left the status floating with nothing beside it.
    Widget readingBlock({required bool alignEnd}) => Row(
      mainAxisSize: alignEnd ? MainAxisSize.min : MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          child: Text(
            reading,
            style: tokens.typography.styles.subtitle.subtitle2,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: tokens.spacing.step3),
        Flexible(
          child: Text(
            statusLabel,
            textAlign: TextAlign.end,
            style: tokens.typography.styles.others.caption.copyWith(
              color: statusColor,
            ),
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
              SizedBox(height: tokens.spacing.step3),
              // The value takes the leading edge and its verdict the trailing
              // one, so the pair spans the card instead of hanging off one
              // side of it.
              readingBlock(alignEnd: false),
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
            Flexible(child: readingBlock(alignEnd: true)),
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
    required this.habitId,
    required this.metrics,
  });

  final List<GoalProgressDay> days;
  final String habitId;
  final GoalDayTrackMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final labelMetrics = _weekdayLabelMetrics(context, days);
    // The one-letter form only where the column cannot hold "Mon": narrow
    // labels are harder to read, so they are a fallback, not the default.
    final format = metrics.narrowLabels
        ? DateFormat.EEEEE(locale)
        : DateFormat.E(locale);
    return _DayTrack(
      height: math.max(IconSizes.s, labelMetrics.height),
      pitch: metrics.pitch,
      children: [
        for (final day in days)
          SizedBox(
            key: ValueKey(
              'goal-habit-weekday-$habitId-'
              '${day.day.toIso8601String().substring(0, 10)}',
            ),
            width: metrics.cellSize,
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

/// The geometry one day track draws on: the column pitch, the square inside
/// each column, and whether the weekday captions still fit at full length.
typedef GoalDayTrackMetrics = ({
  double pitch,
  double cellSize,
  bool narrowLabels,
});

/// The narrowest column a day is still legible in — a 12px square with a
/// hairline of air either side. Below this a track scrolls instead of
/// shrinking further.
double _minimumDayPitch(DsTokens tokens) => IconSizes.xs + tokens.spacing.step2;

/// The column pitch every day row on this page shares.
///
/// One pitch, one origin, one width: the whole-goal verdict strip, the habit
/// squares and the metric bars all draw the SAME week, and drawn on three
/// different grids the same Wednesday landed in three different places on one
/// scroll. A reader cannot follow a day across the page unless the columns
/// line up.
///
/// Wide enough for the weekday label at raised text scales, which is what
/// makes the axis readable rather than merely aligned — and, when
/// [availableWidth] is known, narrow enough that a span longer than a week
/// still FITS. A fourteen-day track at the authored pitch is wider than a
/// phone card, and the trailing-edge scroller that resulted opened with the
/// first days of the span cut in half off the left edge.
GoalDayTrackMetrics goalDayTrackMetrics(
  BuildContext context,
  List<GoalProgressDay> days, {
  double? availableWidth,
}) {
  final tokens = context.designTokens;
  final defaultPitch = ControlSizes.iconChipCompact + tokens.spacing.step2;
  final labelWidth = _weekdayLabelMetrics(context, days).width;
  final expandedPitch = labelWidth + tokens.spacing.step1;
  final textScaledUp = MediaQuery.textScalerOf(context).scale(1) > 1;
  var pitch = textScaledUp && expandedPitch > defaultPitch
      ? expandedPitch
      : defaultPitch;
  if (availableWidth != null && availableWidth > 0 && days.isNotEmpty) {
    // Floored, so `pitch * days` can never round up past the width it was
    // derived from and reintroduce a one-pixel scroller.
    final fitted = (availableWidth / days.length).floorToDouble();
    if (fitted < pitch) {
      pitch = math.max(fitted, _minimumDayPitch(tokens));
    }
  }
  return (
    pitch: pitch,
    // The square shrinks with its column, or neighbouring cells would touch
    // and the track would read as one bar.
    cellSize: math.min(
      ControlSizes.iconChipCompact,
      math.max(IconSizes.xs, pitch - tokens.spacing.step2),
    ),
    // "Mon" needs its own width; a SQUEEZED column takes the one-letter form
    // rather than letting neighbouring captions overlap into mush. Only a
    // squeezed one: at the authored pitch the captions are centered and
    // overhang their cell into the gap by design, which is the established
    // rendering and stays untouched.
    narrowLabels: pitch < defaultPitch && pitch < labelWidth,
  );
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
/// One horizontal scroller per extended day track, all linked through the
/// page's [LinkedScrollGroup] and anchored at the TRAILING edge
/// (`reverse: true`): a span longer than the viewport opens with TODAY on
/// screen, dragging any track moves every track, and because reversed
/// offsets measure from the trailing edge, the same date stays vertically
/// aligned across cards even where extents differ.
class _LinkedDayTrackScroller extends StatefulWidget {
  const _LinkedDayTrackScroller({required this.child, this.group});

  final LinkedScrollGroup? group;
  final Widget child;

  @override
  State<_LinkedDayTrackScroller> createState() =>
      _LinkedDayTrackScrollerState();
}

class _LinkedDayTrackScrollerState extends State<_LinkedDayTrackScroller> {
  ScrollController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.group?.attach();
  }

  @override
  void didUpdateWidget(covariant _LinkedDayTrackScroller oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.group, widget.group)) {
      final old = _controller;
      if (old != null) oldWidget.group?.detach(old);
      _controller = widget.group?.attach();
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) widget.group?.detach(controller);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    reverse: true,
    controller: _controller,
    child: widget.child,
  );
}

class _DayTrack extends StatelessWidget {
  const _DayTrack({
    required this.height,
    required this.pitch,
    required this.children,
  });

  final double height;
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
    this.scrollGroup,
  });

  final LinkedScrollGroup? scrollGroup;
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
    // flattened by repetition. A habit that is AT its rate says nothing here:
    // the header already reads "On track", and the cryptic "at rate" beside
    // the reliability tail read as part of that figure.
    final note = habit.deficit == 0
        ? null
        : context.messages.goalProgressDaysToHealthy(habit.deficit);
    // What the habit asks for, and how its window moves — one caption
    // instead of a title, a caption and a cadence line all restating the
    // same seven days.
    final cadence = [
      goalHabitTargetLabel(
        context,
        targetCount: habit.targetCount,
        window: habit.window,
      ),
      if (habit.window == const GoalWindow.rollingDays(count: 7))
        context.messages.goalProgressCompactCaption,
    ].join(' · ');
    final cadenceStyle = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.lowEmphasis,
    );
    final noteStyle = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.mediumEmphasis,
    );

    Widget cells(GoalDayTrackMetrics metrics) {
      // Interactive rows own a touch-floor-high track so each cell's hit
      // slot meets TapTargets.minimum vertically; read-only rows keep the
      // compact height.
      final trackHeight = widget.onOutcomeSelected == null
          ? metrics.cellSize
          : TapTargets.minimum;
      return _DayTrack(
        height: trackHeight,
        pitch: metrics.pitch,
        children: [
          for (var index = 0; index < activeDays.length; index++)
            _ProgressDayCell(
              day: activeDays[index],
              habitId: habit.habitId,
              size: metrics.cellSize,
              today: DateUtils.isSameDay(
                activeDays[index].day,
                widget.today,
              ),
              // The ring marks the WINDOW's first day — with the page's
              // shared span rendering extra history, the list head can be a
              // blank day weeks before the window.
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

    Widget track(GoalDayTrackMetrics metrics) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WeekdayTrack(
          days: activeDays,
          habitId: habit.habitId,
          metrics: metrics,
        ),
        SizedBox(height: tokens.spacing.step1),
        cells(metrics),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final inlineHeaderWidth =
            _textWidth(context, cadence, cadenceStyle) +
            tokens.spacing.step3 +
            (note == null ? 0 : _textWidth(context, note, noteStyle));
        final cadenceFitsInline = inlineHeaderWidth <= constraints.maxWidth;
        // The track is sized to the width it actually has, so a fortnight of
        // days fits the card instead of opening scrolled past its own first
        // day.
        final metrics = goalDayTrackMetrics(
          context,
          activeDays,
          availableWidth: constraints.maxWidth,
        );
        final contentWidth = metrics.pitch * activeDays.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // What this habit asks for | how far off it is. One meaning per
            // side, so neither has to be read as a qualifier of the other.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (cadenceFitsInline)
                  Flexible(
                    child: Text(cadence, maxLines: 1, style: cadenceStyle),
                  )
                else
                  const Spacer(),
                if (note != null) ...[
                  SizedBox(width: tokens.spacing.step3),
                  Text(note, style: noteStyle),
                ],
              ],
            ),
            if (!cadenceFitsInline) ...[
              SizedBox(height: tokens.spacing.step1),
              Text(cadence, style: cadenceStyle),
            ],
            SizedBox(height: tokens.spacing.step3),
            // The span the squares below cover, on the same rail as the
            // squares themselves — it used to sit a chart's y-axis gutter to
            // their left, keyed to a plot this card does not draw.
            KeyedSubtree(
              key: ValueKey('goal-habit-plot-${habit.habitId}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_periodLabel(context, activeDays), style: cadenceStyle),
                  SizedBox(height: tokens.spacing.step2),
                  if (contentWidth > constraints.maxWidth)
                    // Only where even the narrowest column overflows: the
                    // labels and squares then pan as one unit, in unison with
                    // every other track on the page.
                    _LinkedDayTrackScroller(
                      group: widget.scrollGroup,
                      child: track(metrics),
                    )
                  else
                    track(metrics),
                ],
              ),
            ),
            if (widget.onOutcomeSelected != null &&
                habit.suggestedFromDimensionName != null) ...[
              SizedBox(height: tokens.spacing.step4),
              _HabitCheckOffCallout(
                habitId: habit.habitId,
                dimensionName: habit.suggestedFromDimensionName!,
                onCheckOff: _savingDay != null
                    ? null
                    : () => _recordOutcome(
                        widget.today,
                        HabitCompletionType.success,
                      ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// The "you already recorded the evidence — shall I tick the box?" prompt.
///
/// A tinted, bordered callout rather than the caption-and-tertiary-button row
/// it used to be: this is the one thing on the card the app is ASKING the user
/// to do, and at caption weight between two other caption rows it read as more
/// fine print. The sparkle stays the agent-suggestion mark it is everywhere
/// else in the app.
class _HabitCheckOffCallout extends StatelessWidget {
  const _HabitCheckOffCallout({
    required this.habitId,
    required this.dimensionName,
    required this.onCheckOff,
  });

  final String habitId;
  final String dimensionName;
  final VoidCallback? onCheckOff;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final accent = tokens.colors.interactive.enabled;
    return DecoratedBox(
      key: ValueKey('goal-habit-checkoff-callout-$habitId'),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: SurfaceAlphas.washControl),
        borderRadius: BorderRadius.circular(tokens.radii.m),
        border: Border.all(
          color: accent.withValues(alpha: SurfaceAlphas.muted),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step3),
        child: Row(
          children: [
            Icon(Icons.auto_awesome_rounded, size: IconSizes.l, color: accent),
            SizedBox(width: tokens.spacing.step3),
            Expanded(
              child: Text(
                context.messages.goalHabitCheckOffSuggestion(dimensionName),
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: tokens.colors.text.highEmphasis,
                ),
              ),
            ),
            SizedBox(width: tokens.spacing.step3),
            DesignSystemButton(
              key: ValueKey('goal-habit-checkoff-$habitId'),
              label: context.messages.goalHabitCheckOffAction,
              onPressed: onCheckOff,
              // Primary: it is the callout's whole point, and a tertiary
              // button inside a tinted box disappeared into it.
              size: DesignSystemButtonSize.dense,
              leadingIcon: Icons.check_rounded,
            ),
          ],
        ),
      ),
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
    this.size = ControlSizes.iconChipCompact,
  });

  final GoalProgressDay day;
  final String habitId;

  /// Edge of the square. Shrinks with the track's column pitch so a long span
  /// fits the card instead of scrolling past its own first day.
  final double size;
  final bool today;
  final bool agingOut;
  final bool saving;
  final bool enabled;
  final ValueChanged<HabitCompletionType>? onOutcomeSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final hit = day.hasValue;
    final completionType = day.habitCompletionType;
    final skipped = completionType == HabitCompletionType.skip;
    final missed = completionType == HabitCompletionType.fail;
    // A completed day is a partial success (lighter wash) while the habit's
    // own window target was not yet met as of that day; a null verdict from
    // older projections keeps the established full-strength rendering.
    final dayState = !hit
        ? GoalCompactDayState.none
        : (day.targetSatisfied ?? true)
        ? GoalCompactDayState.full
        : GoalCompactDayState.partial;
    final visualDimension = size;
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
            : skipped
            ? tokens.colors.background.level03
            : goalDayStateFill(tokens, dayState),
        borderRadius: BorderRadius.circular(tokens.radii.s),
        border: border,
      ),
      // The glyph scales with the square it sits in, so a squeezed column
      // does not paint a 12px cross onto a 14px cell.
      child: missed
          ? Icon(
              Icons.close_rounded,
              size: math.min(IconSizes.xs, visualDimension * 0.6),
              color: tokens.colors.alert.error.ink,
            )
          : skipped
          ? Icon(
              Icons.remove_rounded,
              size: math.min(IconSizes.xs, visualDimension * 0.6),
              color: tokens.colors.text.mediumEmphasis,
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
    final outcome = switch (completionType) {
      HabitCompletionType.success =>
        context.messages.completeHabitSuccessButton,
      HabitCompletionType.skip => context.messages.completeHabitSkipButton,
      HabitCompletionType.fail => context.messages.completeHabitFailButton,
      HabitCompletionType.open ||
      null => context.messages.goalProgressHabitDayNoEntry,
    };
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
      excludeSemantics: true,
      // The visual stays at the compact chip size; the hit slot meets the
      // design system's touch floor vertically and fills the track pitch
      // horizontally — invisible ergonomics, unchanged rhythm.
      child: SizedBox.expand(
        key: ValueKey(
          'goal-habit-day-$habitId-'
          '${day.day.toIso8601String().substring(0, 10)}',
        ),
        child: _HabitDayOutcomeMenu(
          enabled: enabled && !saving,
          currentOutcome: completionType,
          headerKey: ValueKey(
            'goal-habit-day-date-$habitId-'
            '${day.day.toIso8601String().substring(0, 10)}',
          ),
          menuDate: menuDate,
          semanticLabel: semanticLabel,
          onSelected: callback,
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
    required this.semanticLabel,
    required this.onSelected,
    required this.child,
  });

  final bool enabled;
  final HabitCompletionType? currentOutcome;
  final Key headerKey;
  final String menuDate;
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
              icon: Icons.check_rounded,
              iconColor: tokens.colors.alert.success.ink,
              isSelected: _isSelected(HabitCompletionType.success),
              onTap: () => _select(HabitCompletionType.success),
            ),
            DesignSystemContextMenuItem(
              key: const ValueKey('goal-habit-day-skipped'),
              label: context.messages.completeHabitSkipButton,
              icon: Icons.remove_rounded,
              iconColor: tokens.colors.text.mediumEmphasis,
              isSelected: _isSelected(HabitCompletionType.skip),
              onTap: () => _select(HabitCompletionType.skip),
            ),
            DesignSystemContextMenuItem(
              key: const ValueKey('goal-habit-day-missed'),
              label: context.messages.completeHabitFailButton,
              icon: Icons.close_rounded,
              iconColor: tokens.colors.alert.error.ink,
              isSelected: _isSelected(HabitCompletionType.fail),
              onTap: () => _select(HabitCompletionType.fail),
            ),
            DesignSystemContextMenuItem(
              key: const ValueKey('goal-habit-day-none'),
              label: context.messages.goalProgressHabitDayNoEntry,
              icon: Icons.radio_button_unchecked_rounded,
              iconColor: tokens.colors.text.lowEmphasis,
              isSelected: _isSelected(HabitCompletionType.open),
              onTap: () => _select(HabitCompletionType.open),
            ),
          ],
        ),
      ],
      builder: (context, controller, child) => Tooltip(
        message: widget.semanticLabel,
        child: InkWell(
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
          child: widget.child,
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
    // Bars and their caption on ONE line, reading left to right like every
    // other row on the card. Stacked and right-ragged, the tail and its label
    // formed a third column that belonged to nothing above it.
    return Row(
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
        SizedBox(width: tokens.spacing.step3),
        Flexible(
          child: Text(
            context.messages.goalReliabilityWeeks(successfulWeeks),
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
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
          leftAxisWidth: chartLeftAxisWidth(
            context,
            isSteps
                ? niceAxis(0, yValues.reduce(math.max), zeroBased: true)
                : niceAxis(yValues.reduce(math.min), yValues.reduce(math.max)),
          ),
        ),
        SizedBox(height: tokens.spacing.step3),
        // One entry per line drawn, and nothing else. The fourth entry used to
        // be a sentence — "Current below 7-day average · toward target",
        // coloured green or red — which is a reading of the data, not a key to
        // it: a legend swatch that matched no mark on the chart, in a hue that
        // meant something different from every other hue in the card.
        DashboardChartLegend(
          entries: [
            DashboardLegendEntry(color: actualColor, label: actualLabel),
            if (averages.isNotEmpty)
              DashboardLegendEntry(
                color: averageColor,
                label: context.messages.goalChartSevenDayAverage,
              ),
            DashboardLegendEntry(
              color: targetColor,
              label: context.messages.habitsGoalLineLabel,
              annotation: _targetThreshold(context, metric),
            ),
          ],
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
    // reader can trust, rather than the raw series maximum.
    final axis = niceAxis(0, maxValue, zeroBased: true);
    final axisWidth = chartLeftAxisWidth(context, axis);
    return LayoutBuilder(
      builder: (context, constraints) {
        final plotWidth = math.max<double>(constraints.maxWidth - axisWidth, 0);
        final metrics = goalDayTrackMetrics(
          context,
          metric.days,
          availableWidth: plotWidth,
        );
        final contentWidth = metrics.pitch * metric.days.length;
        final track = _track(context, axis.max, metrics);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The span, on the plot's own rail rather than the card's — it
            // labels the bars, so it starts where they start.
            Padding(
              padding: EdgeInsetsDirectional.only(start: axisWidth),
              child: Text(
                _periodLabel(context, metric.days),
                style: tokens.typography.styles.others.caption.copyWith(
                  color: tokens.colors.text.lowEmphasis,
                ),
              ),
            ),
            SizedBox(height: tokens.spacing.step3),
            SizedBox(
              height: _chartHeight(tokens),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The value axis these bars are drawn against. Without it
                  // the card showed a wall of bars and no way to read a
                  // magnitude off any of them.
                  SizedBox(
                    width: axisWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ChartLabel(formatAxisValue(axis.max)),
                        ChartLabel(formatAxisValue(axis.min)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        // The target, drawn — but only where it is a PER-DAY
                        // quantity. For a `sum` or `count` criterion the
                        // target is a period-level total while these bars are
                        // single days, so a line at the target would put two
                        // already-sufficient days under a threshold they
                        // jointly cleared.
                        if (axis.max > 0 && metric.targetIsPerDay)
                          Positioned(
                            key: const ValueKey('goal-metric-target-rule'),
                            left: 0,
                            right: 0,
                            // Clamped to leave the rule's own thickness inside
                            // the plot: a target at the axis ceiling would
                            // otherwise land on the clipped top edge, invisible
                            // in exactly the case it matters most.
                            bottom: math.min(
                              _chartHeight(tokens) *
                                  (metric.target / axis.max).clamp(0, 1),
                              _chartHeight(tokens) - BorderWidths.hairline,
                            ),
                            child: SizedBox(
                              height: BorderWidths.hairline,
                              child: ColoredBox(
                                color: tokens.colors.decorative.level01,
                              ),
                            ),
                          ),
                        Positioned.fill(
                          child: contentWidth > plotWidth
                              ? _LinkedDayTrackScroller(
                                  group: scrollGroup,
                                  child: track,
                                )
                              : track,
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
              padding: EdgeInsetsDirectional.only(start: axisWidth),
              child: _WeekdayTrack(
                days: metric.days,
                habitId: 'metric-${metric.criterionId}',
                metrics: metrics,
              ),
            ),
            SizedBox(height: tokens.spacing.step3),
            DashboardChartLegend(
              entries: [
                DashboardLegendEntry(
                  color: goalDayStateFill(tokens, GoalCompactDayState.full),
                  label: context.messages.goalMetricLegendOnTarget,
                ),
                DashboardLegendEntry(
                  color: goalDayStateFill(tokens, GoalCompactDayState.partial),
                  label: context.messages.goalMetricLegendOffTarget,
                ),
                DashboardLegendEntry(
                  color: goalDayStateFill(tokens, GoalCompactDayState.none),
                  label: context.messages.goalProgressHabitDayNoEntry,
                ),
                if (metric.targetIsPerDay)
                  DashboardLegendEntry(
                    color: tokens.colors.decorative.level01,
                    label: context.messages.habitsGoalLineLabel,
                    annotation: _targetThreshold(context, metric),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// The bars on the page's shared day grid.
  ///
  /// `_DayTrack` with [goalDayTrackMetrics], exactly like the habit squares
  /// and the whole-goal strip: a plain Row with fixed gaps matched the default
  /// pitch but not the text-scale-expanded one, so at raised text scales the
  /// bars' Wednesday drifted away from the Wednesday one card above.
  Widget _track(
    BuildContext context,
    num maxValue,
    GoalDayTrackMetrics metrics,
  ) {
    final tokens = context.designTokens;
    final height = _chartHeight(tokens);
    return _DayTrack(
      height: height,
      pitch: metrics.pitch,
      children: [
        for (final day in metric.days)
          // A tight box, not a loose slot. `_bar` is a FractionallySizedBox
          // whose Stack expands against its parent, so it needs bounded
          // dimensions or every bar collapses to zero — an invisible chart.
          SizedBox(
            width: metrics.cellSize,
            height: height,
            child: _bar(context, day, maxValue),
          ),
      ],
    );
  }

  Widget _bar(BuildContext context, GoalProgressDay day, num maxValue) {
    final tokens = context.designTokens;
    final locale = Localizations.localeOf(context).toString();
    final date = DateFormat.MMMd(locale).format(day.day);
    final number = NumberFormat.decimalPattern(locale);
    // The shared per-day policy: a bar drawn against a per-day target rule
    // is judged by the day's own value, so a 12,400-step day beats a 10,000
    // target even when the trailing week's average is still short. Only a
    // period-total criterion keeps the evaluator's window verdict, because
    // no single bar can be read against a whole-period target.
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
            ? goalDayStateFill(tokens, GoalCompactDayState.none)
            : goalDayStateFill(
                tokens,
                met ? GoalCompactDayState.full : GoalCompactDayState.partial,
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
    final unit = metric.unitName?.trim() ?? '';
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
        decoration: chartTooltipDecoration(context),
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
                      Icons.edit_note_rounded,
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
                          borderRadius: BorderRadius.circular(
                            goalDayCellRadius(tokens),
                          ),
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
          borderRadius: BorderRadius.circular(goalDayCellRadius(tokens)),
        ),
        // The legend swatch carries the same shape and non-color cue as the
        // cells it keys — at `radii.xs` it was a different shape from both.
        child: dotted
            ? Center(child: goalPartialDayDot(tokens, tokens.spacing.step1))
            : null,
      );
      if (dashed) {
        swatch = DsDashedBorder(
          color: color,
          radius: goalDayCellRadius(tokens),
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
        // The state most cells are actually IN. The key explained the two
        // green ones and both edge cases while staying silent about the
        // majority fill, which is the one a reader most needs named.
        item(
          tokens.colors.background.level03,
          context.messages.goalProgressHabitDayNoEntry,
        ),
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
