import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// The summary KPI card at the top of the Habits tab — the analogue of the
/// Time Analysis "TOTAL" card. It answers "how am I doing today?" at a glance:
/// the day's completion as a fraction plus a progress bar (numeric *and*
/// visual, so it reads for low-vision users), and the longest active streak.
///
/// The streak counts were computed by [HabitsController] but never rendered
/// before this card; surfacing "don't break the chain" makes the habit loop's
/// reward visible, which is the whole point of a habits surface.
class HabitsSummaryCard extends ConsumerWidget {
  const HabitsSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final state = ref.watch(habitsControllerProvider);

    final total = state.habitDefinitions.length;
    final done = state.completedToday.length;
    final fraction = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: dsCardSurface(context),
        borderRadius: BorderRadius.circular(tokens.radii.m),
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        messages.habitsDoneTodayLabel,
                        style: calmEyebrowStyle(tokens),
                      ),
                      SizedBox(height: tokens.spacing.step2),
                      _DoneFraction(done: done, total: total),
                    ],
                  ),
                ),
                _StreakBadge(
                  shortStreakCount: state.shortStreakCount,
                  longStreakCount: state.longStreakCount,
                ),
              ],
            ),
            SizedBox(height: tokens.spacing.step4),
            _ProgressBar(fraction: fraction),
          ],
        ),
      ),
    );
  }
}

/// The day's headline: the *completed* count carries the accent ink (the win
/// the eye should land on), with the total kept quiet. A gain-framed caption —
/// "{n} to go", or "All done today" when finished — replaces the old deficit
/// "{done} / {total}" so an unfinished morning reads as momentum, not failure.
class _DoneFraction extends StatelessWidget {
  const _DoneFraction({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final remaining = (total - done).clamp(0, total);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '$done',
          style: calmDisplayStyle(
            tokens,
            color: tokens.colors.interactive.enabled,
          ),
        ),
        SizedBox(width: tokens.spacing.step3),
        Padding(
          padding: EdgeInsets.only(bottom: tokens.spacing.step1),
          child: Text(
            remaining == 0
                ? messages.habitsAllDoneToday
                : messages.habitsToGoCount(remaining),
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ),
      ],
    );
  }
}

/// Longest active streak as a flame chip, or an encouraging nudge when no
/// streak is running yet. Prefers the 7-day streak (the bigger win) and falls
/// back to the 3-day one.
class _StreakBadge extends StatelessWidget {
  const _StreakBadge({
    required this.shortStreakCount,
    required this.longStreakCount,
  });

  final int shortStreakCount;
  final int longStreakCount;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;

    final hasStreak = longStreakCount > 0 || shortStreakCount > 0;
    final label = longStreakCount > 0
        ? messages.habitsStreakLongCount(longStreakCount)
        : shortStreakCount > 0
        ? messages.habitsStreakShortCount(shortStreakCount)
        : messages.habitsStartStreakToday;

    final accent = hasStreak
        ? tokens.colors.interactive.enabled
        : tokens.colors.text.lowEmphasis;

    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            size: tokens.spacing.step5,
            color: accent,
          ),
          SizedBox(width: tokens.spacing.step2),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Token-styled day-progress bar: a quiet track with an accent fill at the
/// completion fraction. Pure design-system colours and radii — no new tokens.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return ClipRRect(
      borderRadius: BorderRadius.circular(tokens.radii.xs),
      child: Stack(
        children: [
          Container(
            height: tokens.spacing.step3,
            color: tokens.colors.decorative.level01,
          ),
          FractionallySizedBox(
            widthFactor: fraction,
            child: Container(
              height: tokens.spacing.step3,
              decoration: BoxDecoration(
                color: tokens.colors.interactive.enabled,
                borderRadius: BorderRadius.circular(tokens.radii.xs),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
