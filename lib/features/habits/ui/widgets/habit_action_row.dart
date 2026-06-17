import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_compact.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/create/complete_habit_dialog.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/widgets/charts/habits/dashboard_habits_data.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// The shared habit action row used by the habits tab and the dashboard habit
/// chart: a swipe-to-record row (right = success, left = missed) whose body
/// opens the completion dialog on tap, with a category icon, an optional
/// priority star, the habit name, an optional [history] slot and a trailing
/// one-tap complete button.
///
/// Whether to show per-day history is the caller's concern: the habits tab
/// passes none (history lives in the consistency heatmap), while the dashboard
/// card injects its strip. [completedToday] is supplied by the caller too — the
/// tab derives it from the controller's `successfulToday` bucket, the dashboard
/// card from its latest in-range result — so the row stays presentational.
class HabitActionRow extends StatefulWidget {
  const HabitActionRow({
    required this.habitId,
    required this.completedToday,
    this.currentStreak = 0,
    this.history,
    this.showLinkedDashboard = true,
    super.key,
  });

  final String habitId;

  /// Whether the habit counts as done today — drives the done-border and the
  /// trailing button's two modes.
  final bool completedToday;

  /// This habit's current consecutive-day streak. A small flame chip is shown
  /// next to the name once it reaches 2 (below that it's noise) — restoring the
  /// per-habit "don't break the chain" signal the combined heatmap can't give.
  final int currentStreak;

  /// Optional per-day history shown under the name (the dashboard card's strip).
  final Widget? history;

  /// Whether the completion dialog embeds the habit's linked dashboard. Set to
  /// false when this row is itself rendered inside that dashboard, so tapping it
  /// doesn't re-open the dashboard the user is already viewing.
  final bool showLinkedDashboard;

  @override
  State<HabitActionRow> createState() => _HabitActionRowState();
}

class _HabitActionRowState extends State<HabitActionRow> {
  void onTapAdd({String? dateString}) {
    final height = MediaQuery.of(context).size.height;
    final maxHeight = height * 0.9;
    final habitDefinition = getIt<EntitiesCacheService>().getHabitById(
      widget.habitId,
    );

    if (habitDefinition == null) {
      return;
    }

    // Mirror the dialog's gate: the linked dashboard only fills the sheet when
    // it will actually be shown, otherwise the form floats on a transparent
    // background.
    final showLinkedDashboard =
        widget.showLinkedDashboard && habitDefinition.dashboardId != null;

    ModalUtils.showBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(maxHeight: maxHeight),
      backgroundColor: showLinkedDashboard
          ? Theme.of(context).bottomSheetTheme.backgroundColor
          : Colors.transparent,
      builder: (BuildContext context) {
        return HabitDialog(
          habitId: habitDefinition.id,
          themeData: Theme.of(context),
          dateString: dateString,
          showLinkedDashboard: widget.showLinkedDashboard,
        );
      },
    );
  }

  /// Records a one-tap completion for *today* with [completionType] and no
  /// comment — the fast path shared by the trailing check button (success) and
  /// the horizontal swipe gestures (success / fail). The detailed dialog (date,
  /// comment, linked dashboard) stays one tap away on the row body.
  ///
  /// Confirms with a brief outcome SnackBar so the action is acknowledged
  /// instantly, before the provider round-trips and recolours the row.
  Future<void> _recordQuickCompletion(
    HabitCompletionType completionType,
    HabitDefinition habitDefinition,
  ) async {
    await HapticFeedback.lightImpact();
    final now = DateTime.now();
    await getIt<PersistenceLogic>().createHabitCompletionEntry(
      data: HabitCompletionData(
        habitId: habitDefinition.id,
        dateFrom: now,
        dateTo: now,
        completionType: completionType,
      ),
      comment: '',
      habitDefinition: habitDefinition,
    );
    if (!mounted) return;
    final tokens = context.designTokens;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              Icon(
                completionType == HabitCompletionType.fail
                    ? Icons.cancel_rounded
                    : Icons.check_circle_rounded,
                color: habitCompletionColor(completionType),
              ),
              SizedBox(width: tokens.spacing.step4),
              Expanded(child: Text(habitDefinition.name)),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final habitDefinition = getIt<EntitiesCacheService>().getHabitById(
      widget.habitId,
    );

    if (habitDefinition == null) {
      return const SizedBox.shrink();
    }

    final tokens = context.designTokens;
    final messages = context.messages;
    final doneColor = habitCompletionColor(HabitCompletionType.success);

    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.cardItemSpacing),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(tokens.radii.m),
        child: Dismissible(
          key: ValueKey<String>('habit-swipe-${habitDefinition.id}'),
          dismissThresholds: const {
            DismissDirection.startToEnd: 0.4,
            DismissDirection.endToStart: 0.4,
          },
          background: _SwipeActionBackground(
            alignment: Alignment.centerLeft,
            color: habitCompletionColor(HabitCompletionType.success),
            icon: Icons.check_circle_rounded,
            label: messages.completeHabitSuccessButton,
          ),
          secondaryBackground: _SwipeActionBackground(
            alignment: Alignment.centerRight,
            color: habitCompletionColor(HabitCompletionType.fail),
            icon: Icons.cancel_rounded,
            label: messages.completeHabitFailButton,
          ),
          confirmDismiss: (direction) async {
            final completionType = direction == DismissDirection.startToEnd
                ? HabitCompletionType.success
                : HabitCompletionType.fail;
            await _recordQuickCompletion(completionType, habitDefinition);
            // Record, then snap back — the row reflects the new state via its
            // host's state; it is never removed from the list.
            return false;
          },
          child: _HabitCardBody(
            habitDefinition: habitDefinition,
            completedToday: widget.completedToday,
            currentStreak: widget.currentStreak,
            doneColor: doneColor,
            history: widget.history,
            onTapAdd: onTapAdd,
            onQuickComplete: () => _recordQuickCompletion(
              HabitCompletionType.success,
              habitDefinition,
            ),
          ),
        ),
      ),
    );
  }
}

/// The visible row content (icon, name, optional history, trailing action).
/// Split from the swipe wrapper so the layout reads on its own and is testable
/// without driving a gesture.
class _HabitCardBody extends StatelessWidget {
  const _HabitCardBody({
    required this.habitDefinition,
    required this.completedToday,
    required this.currentStreak,
    required this.doneColor,
    required this.onTapAdd,
    required this.onQuickComplete,
    this.history,
  });

  final HabitDefinition habitDefinition;
  final bool completedToday;
  final int currentStreak;
  final Color doneColor;
  final Widget? history;
  final void Function({String? dateString}) onTapAdd;

  /// One-tap "mark done today" — the trailing check records a success directly
  /// (the icon's universal meaning), instead of opening the detail dialog the
  /// row body opens.
  final VoidCallback onQuickComplete;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final titleStyle = tokens.typography.styles.subtitle.subtitle1.copyWith(
      color: tokens.colors.text.highEmphasis,
    );

    return Material(
      color: dsCardSurface(context),
      child: InkWell(
        onTap: onTapAdd,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(tokens.radii.m),
            border: Border.all(
              color: completedToday
                  ? doneColor.withValues(alpha: 0.55)
                  : tokens.colors.decorative.level01,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.step4,
              vertical: tokens.spacing.step3,
            ),
            child: Row(
              children: [
                CategoryIconCompact(
                  habitDefinition.categoryId,
                  size: CategoryIconConstants.iconSizeMedium,
                ),
                SizedBox(width: tokens.spacing.step4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (habitDefinition.priority ?? false) ...[
                            Icon(
                              Icons.star_rounded,
                              size: tokens.spacing.step5,
                              color: starredGold,
                            ),
                            SizedBox(width: tokens.spacing.step2),
                          ],
                          Flexible(
                            child: Text(
                              habitDefinition.name,
                              style: titleStyle,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (currentStreak >= 2) ...[
                            SizedBox(width: tokens.spacing.step3),
                            _StreakChip(count: currentStreak),
                          ],
                        ],
                      ),
                      if (history != null) ...[
                        SizedBox(height: tokens.spacing.step3),
                        history!,
                      ],
                    ],
                  ),
                ),
                SizedBox(width: tokens.spacing.step3),
                _CompleteButton(
                  // Not done → one-tap success (the icon's universal meaning),
                  // shown as a filled accent button so it clearly reads as the
                  // row's primary action. Already done → a quiet status check
                  // that opens the dialog to review/adjust (never a silent
                  // duplicate).
                  completed: completedToday,
                  doneColor: doneColor,
                  semanticLabel: messages.habitCompleteSemanticLabel(
                    habitDefinition.name,
                  ),
                  onPressed: completedToday ? onTapAdd : onQuickComplete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small flame + count shown beside the name when this habit has a running
/// streak — the per-habit "don't break the chain" cue the combined heatmap
/// can't surface. The flame is decorative; the streak is announced via a
/// semantics label so it isn't read as a bare number.
class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Semantics(
      label: context.messages.habitStreakDaysSemantic(count),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            size: tokens.spacing.step5,
            color: tokens.colors.interactive.enabled,
          ),
          SizedBox(width: tokens.spacing.step1),
          Text(
            '$count',
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.text.mediumEmphasis,
              fontWeight: tokens.typography.weight.semiBold,
            ),
          ),
        ],
      ),
    );
  }
}

/// The row's primary action affordance. When the habit is not yet done it is a
/// hollow, accent-ringed 48dp circle with a "+" — unmistakably "tap to log",
/// never confusable with a completed state. Once done it becomes a green
/// check-circle that opens the dialog for review (never a silent duplicate).
/// The 48dp target clears the accessible minimum.
class _CompleteButton extends StatelessWidget {
  const _CompleteButton({
    required this.completed,
    required this.doneColor,
    required this.semanticLabel,
    required this.onPressed,
  });

  final bool completed;
  final Color doneColor;
  final String semanticLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final accent = tokens.colors.interactive.enabled;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: SizedBox(
        width: tokens.spacing.step9,
        height: tokens.spacing.step9,
        child: Material(
          color: Colors.transparent,
          shape: completed
              ? const CircleBorder()
              : CircleBorder(side: BorderSide(color: accent, width: 2)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            // Pop the check in when the habit is completed, so the tap lands
            // with a small reward instead of a silent swap.
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: Icon(
                completed ? Icons.check_circle_rounded : Icons.add_rounded,
                key: ValueKey(completed),
                color: completed ? doneColor : accent,
                size: tokens.spacing.step7,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The coloured reveal behind a row while it is being swiped — an outcome
/// colour with a leading/trailing icon and label so the gesture's effect is
/// legible before the user commits to it.
class _SwipeActionBackground extends StatelessWidget {
  const _SwipeActionBackground({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
  });

  final Alignment alignment;
  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final onColor = tokens.colors.text.highEmphasis;
    return ColoredBox(
      color: color,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step5),
        child: Align(
          alignment: alignment,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: onColor, size: tokens.spacing.step6),
              SizedBox(width: tokens.spacing.step2),
              Text(
                label,
                style: tokens.typography.styles.body.bodyMedium.copyWith(
                  color: onColor,
                  fontWeight: tokens.typography.weight.semiBold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
