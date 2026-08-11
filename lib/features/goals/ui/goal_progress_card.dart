import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entity_definitions.dart';
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
    super.key,
  });

  final GoalProgressView progress;
  final GoalHabitOutcomeSelected? onHabitOutcomeSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final habitWindow = progress.habits.firstOrNull?.window;
    final windows = [
      for (final habit in progress.habits) habit.window,
      for (final metric in progress.metrics) metric.window,
    ];
    final usesRollingWeek =
        windows.isNotEmpty &&
        windows.every(
          (window) => window == const GoalWindow.rollingDays(count: 7),
        );
    return DesignSystemSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: tokens.spacing.step3,
            runSpacing: tokens.spacing.step1,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (usesRollingWeek) ...[
                Text(
                  context.messages.goalProgressTitle,
                  style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                    color: tokens.colors.text.highEmphasis,
                  ),
                ),
                Text(
                  context.messages.goalProgressCaption,
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: tokens.colors.text.lowEmphasis,
                  ),
                ),
              ] else if (progress.metric case final metric?)
                Text(
                  _metricPeriodLabel(context, metric),
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: tokens.colors.text.lowEmphasis,
                  ),
                )
              else if (habitWindow != null && progress.habits.isNotEmpty)
                Text(
                  _periodLabel(context, progress.habits.first.days),
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: tokens.colors.text.lowEmphasis,
                  ),
                ),
            ],
          ),
          SizedBox(height: tokens.spacing.step4),
          if (progress.habits.isNotEmpty)
            for (var index = 0; index < progress.habits.length; index++) ...[
              if (index > 0) SizedBox(height: tokens.spacing.step3),
              _HabitProgressRow(
                habit: progress.habits[index],
                today: progress.today,
                onOutcomeSelected: onHabitOutcomeSelected,
              ),
            ],
          for (var index = 0; index < progress.metrics.length; index++) ...[
            if (progress.habits.isNotEmpty || index > 0)
              SizedBox(height: tokens.spacing.step4),
            _MetricProgressSeries(metric: progress.metrics[index]),
          ],
          if (progress.habits.isNotEmpty) ...[
            SizedBox(height: tokens.spacing.step4),
            const _ProgressLegend(),
          ],
        ],
      ),
    );
  }

  String _metricPeriodLabel(
    BuildContext context,
    GoalMetricProgressView metric,
  ) {
    return _periodLabel(context, metric.days);
  }

  String _periodLabel(BuildContext context, List<GoalProgressDay> days) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final format = DateFormat.MMMd(locale);
    return '${format.format(days.first.day)} – ${format.format(days.last.day)}';
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
    final locale = Localizations.localeOf(context).toLanguageTag();
    final stateColor = habit.deficit == 0
        ? tokens.colors.alert.success.ink
        : tokens.colors.alert.warning.ink;
    final note = habit.deficit == 0
        ? context.messages.goalProgressAtRate
        : context.messages.goalProgressDaysToHealthy(habit.deficit);
    final labels = [
      for (final day in activeDays)
        DateFormat.E(locale).format(day.day).characters.first,
    ];
    final interactive = widget.onOutcomeSelected != null;
    final daySlotWidth = interactive
        ? TapTargets.minimum
        : ControlSizes.iconChipCompact;

    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          habit.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.text.highEmphasis,
          ),
        ),
        Text(
          goalHabitTargetLabel(
            context,
            targetCount: habit.targetCount,
            window: habit.window,
          ),
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.lowEmphasis,
          ),
        ),
      ],
    );
    final cells = Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < labels.length; index++) ...[
              if (!interactive && index > 0)
                SizedBox(width: tokens.spacing.step2),
              SizedBox(
                key: ValueKey(
                  'goal-habit-weekday-${habit.habitId}-'
                  '${activeDays[index].day.toIso8601String().substring(0, 10)}',
                ),
                width: daySlotWidth,
                child: Text(
                  labels[index],
                  textAlign: TextAlign.center,
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: tokens.colors.text.lowEmphasis,
                  ),
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: tokens.spacing.step1),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < activeDays.length; index++) ...[
              if (!interactive && index > 0)
                SizedBox(width: tokens.spacing.step2),
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
          ],
        ),
      ],
    );
    final successfulWeeks = habit.successfulWeeks;
    final reliability = successfulWeeks == null
        ? null
        : _Reliability(successfulWeeks: successfulWeeks);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            activeDays.length <= 7 &&
            constraints.maxWidth >= tokens.spacing.step13 * 4;
        if (wide) {
          return Row(
            children: [
              SizedBox(width: tokens.spacing.step13, child: identity),
              SizedBox(width: tokens.spacing.step4),
              cells,
              SizedBox(width: tokens.spacing.step4),
              Expanded(
                child: Text(
                  note,
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: stateColor,
                  ),
                ),
              ),
              ?reliability,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: identity),
                Text(
                  note,
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: stateColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: tokens.spacing.step3),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: cells,
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
    : '$targetCount× · ${goalWindowLabel(context, window)}';

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
    final cell = Container(
      key: missed
          ? ValueKey(
              'goal-day-missed-$habitId-'
              '${day.day.toIso8601String().substring(0, 10)}',
            )
          : null,
      width: ControlSizes.iconChip,
      height: ControlSizes.iconChip,
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
    final decoratedCell = !today || hit
        ? cell
        : DsDashedBorder(
            color: tokens.colors.text.lowEmphasis,
            radius: tokens.radii.s,
            child: cell,
          );
    final callback = onOutcomeSelected;
    if (callback == null) return decoratedCell;
    final date = DateFormat.yMMMd(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(day.day);
    return SizedBox.square(
      key: ValueKey(
        'goal-habit-day-$habitId-'
        '${day.day.toIso8601String().substring(0, 10)}',
      ),
      dimension: TapTargets.minimum,
      child: PopupMenuButton<HabitCompletionType>(
        enabled: enabled && !saving,
        initialValue: day.habitCompletionType,
        padding: EdgeInsets.zero,
        position: PopupMenuPosition.under,
        offset: Offset(0, tokens.spacing.step2),
        color: tokens.colors.background.level01,
        surfaceTintColor: Colors.transparent,
        constraints: BoxConstraints.tightFor(width: tokens.spacing.step13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radii.s),
        ),
        tooltip: date,
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
                  dimension: ControlSizes.iconChip,
                  child: Padding(
                    padding: EdgeInsets.all(tokens.spacing.step2),
                    child: const CircularProgressIndicator(),
                  ),
                )
              : decoratedCell,
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
          metric.name,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.text.highEmphasis,
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
          heightFactor: maxValue == 0
              ? 0.0
              : (day.value / maxValue).clamp(0, 1).toDouble(),
          alignment: Alignment.bottomCenter,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: metric.meetsTarget(day)
                  ? tokens.colors.alert.info.defaultColor
                  : tokens.colors.background.level03,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(tokens.radii.s),
              ),
            ),
          ),
        ),
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
