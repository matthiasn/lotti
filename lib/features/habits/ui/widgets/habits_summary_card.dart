import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/features/habits/state/habits_state.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// The summary KPI card at the top of the Habits tab — the analogue of the
/// Time Analysis "TOTAL" card. It answers "how am I doing today?" at a glance:
/// the day's completion as a fraction plus a progress bar (numeric *and*
/// visual, so it reads for low-vision users), and the longest active streak.
///
/// The streak counts were computed by [HabitsController] but never rendered
/// before this card; surfacing "don't break the chain" makes the habit loop's
/// reward visible, which is the whole point of a habits surface.
class HabitsSummaryCard extends ConsumerStatefulWidget {
  const HabitsSummaryCard({super.key});

  @override
  ConsumerState<HabitsSummaryCard> createState() => _HabitsSummaryCardState();
}

class _HabitsSummaryCardState extends ConsumerState<HabitsSummaryCard>
    with SingleTickerProviderStateMixin {
  /// A grander one-shot glow when the *last* habit of the day is logged — the
  /// peak reward. Rests at 1 (glow opacity `1 - value` is 0) and flashes
  /// bright→gone when the day flips to fully complete.
  late final AnimationController _allDoneFlash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    value: 1,
  );

  static bool _isAllDone(HabitsState state) =>
      state.habitDefinitions.isNotEmpty &&
      state.completedToday.length >= state.habitDefinitions.length;

  @override
  void dispose() {
    _allDoneFlash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;

    // Fire the all-done flourish only on the transition into a fully-complete
    // day, never on a card that opens already complete.
    ref.listen(habitsControllerProvider, (previous, next) {
      if ((previous == null || !_isAllDone(previous)) && _isAllDone(next)) {
        _allDoneFlash.forward(from: 0);
      }
    });

    final state = ref.watch(habitsControllerProvider);
    final total = state.habitDefinitions.length;
    final done = state.completedToday.length;
    final fraction = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);

    final card = DecoratedBox(
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
                SizedBox(width: tokens.spacing.step4),
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

    return Stack(
      children: [
        card,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _allDoneFlash,
              builder: (context, _) {
                final opacity = (1 - _allDoneFlash.value).clamp(0.0, 1.0);
                if (opacity == 0) {
                  return const SizedBox.shrink();
                }
                return Opacity(
                  key: const ValueKey('habit-all-done-flash'),
                  opacity: opacity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(tokens.radii.m),
                      border: Border.all(
                        color: tokens.colors.interactive.enabled,
                        width: 2,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// The day's headline: the *completed* count carries the accent ink (the win
/// the eye should land on) shown as a fraction "{done} / {total}" so the big
/// numeral can't be misread, with a gain-framed caption beneath — "{n} to go",
/// or "All done today" when finished — so an unfinished morning reads as
/// momentum, not failure. Caption on its own line so it never collides with the
/// headline number's baseline.
class _DoneFraction extends StatelessWidget {
  const _DoneFraction({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final remaining = (total - done).clamp(0, total);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            // Count up to the new total when a habit is completed, so the win
            // is felt at the moment of the tap rather than snapping silently.
            TweenAnimationBuilder<double>(
              tween: Tween<double>(end: done.toDouble()),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => Text(
                '${value.round()}',
                style: calmDisplayStyle(
                  tokens,
                  color: tokens.colors.interactive.enabled,
                ),
              ),
            ),
            SizedBox(width: tokens.spacing.step2),
            Text(
              '/ $total',
              style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                color: tokens.colors.text.lowEmphasis,
              ),
            ),
          ],
        ),
        Text(
          remaining == 0
              ? messages.habitsAllDoneToday
              : messages.habitsToGoCount(remaining),
          style: tokens.typography.styles.body.bodySmall.copyWith(
            // The all-done caption carries the accent ink so finishing the day
            // reads as a distinct reward state, not just another count.
            color: remaining == 0
                ? tokens.colors.interactive.enabled
                : tokens.colors.text.mediumEmphasis,
            fontWeight: remaining == 0
                ? tokens.typography.weight.semiBold
                : null,
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

    // A quiet pill anchors the streak as a deliberate badge rather than text
    // floating in the card's corner. It sizes to its content (one line) and the
    // done-fraction takes the remaining width, so the label never wraps.
    return Container(
      decoration: BoxDecoration(
        color: tokens.colors.decorative.level01,
        borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step3,
        vertical: tokens.spacing.step2,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            size: tokens.spacing.step5,
            color: accent,
          ),
          SizedBox(width: tokens.spacing.step2),
          Text(
            label,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Token-styled day-progress bar: a quiet track with an accent fill at the
/// completion fraction. The fill eases to its new width when a habit is logged,
/// so progress is *felt* advancing rather than jumping. Pure design-system
/// colours and radii — no new tokens.
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
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: fraction),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) => FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              child: child,
            ),
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
