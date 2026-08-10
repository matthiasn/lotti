import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
              _CompactDayCell(hit: visible[index], today: index == 6),
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
class GoalProgressCard extends StatelessWidget {
  const GoalProgressCard({required this.progress, super.key});

  final GoalProgressView progress;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return DesignSystemSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: tokens.spacing.step3,
            runSpacing: tokens.spacing.step1,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
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
            ],
          ),
          SizedBox(height: tokens.spacing.step4),
          if (progress.habits.isNotEmpty)
            for (var index = 0; index < progress.habits.length; index++) ...[
              if (index > 0) SizedBox(height: tokens.spacing.step4),
              _HabitProgressRow(habit: progress.habits[index]),
            ]
          else if (progress.metric case final metric?)
            _MetricProgressSeries(metric: metric),
          SizedBox(height: tokens.spacing.step4),
          const _ProgressLegend(),
        ],
      ),
    );
  }
}

class _HabitProgressRow extends StatelessWidget {
  const _HabitProgressRow({required this.habit});

  final GoalHabitProgressView habit;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final activeDays = habit.days.skip(1).toList(growable: false);
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
          context.messages.goalProgressHabitTarget(habit.targetCount),
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
              if (index > 0) SizedBox(width: tokens.spacing.step2),
              SizedBox(
                width: ControlSizes.iconChipCompact,
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
        SizedBox(height: tokens.spacing.step2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < activeDays.length; index++) ...[
              if (index > 0) SizedBox(width: tokens.spacing.step2),
              _ProgressDayCell(
                hit: activeDays[index].hasValue,
                today: index == activeDays.length - 1,
                agingOut: index == 0 && habit.oldestSuccessAgesOutTonight,
              ),
            ],
          ],
        ),
      ],
    );
    final reliability = _Reliability(
      successfulWeeks: habit.successfulWeeks,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= tokens.spacing.step13 * 3;
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
              reliability,
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

class _ProgressDayCell extends StatelessWidget {
  const _ProgressDayCell({
    required this.hit,
    required this.today,
    required this.agingOut,
  });

  final bool hit;
  final bool today;
  final bool agingOut;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
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
      width: ControlSizes.iconChipCompact,
      height: ControlSizes.iconChipCompact,
      decoration: BoxDecoration(
        color: hit
            ? tokens.colors.interactive.enabled
            : tokens.colors.background.level03,
        borderRadius: BorderRadius.circular(tokens.radii.s),
        border: border,
      ),
    );
    if (!today || hit) return cell;
    return DsDashedBorder(
      color: tokens.colors.text.lowEmphasis,
      radius: tokens.radii.s,
      child: cell,
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var index = 0; index < metric.days.length; index++) ...[
                if (index > 0) SizedBox(width: tokens.spacing.step2),
                Expanded(
                  child: FractionallySizedBox(
                    heightFactor: maxValue == 0
                        ? 0
                        : (metric.days[index].value / maxValue).clamp(0, 1),
                    alignment: Alignment.bottomCenter,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: metric.days[index].value >= metric.target
                            ? tokens.colors.alert.info.defaultColor
                            : tokens.colors.background.level03,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(tokens.radii.s),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
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
