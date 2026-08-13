/// Shared banner interactions: snooze-first visibility control and the
/// per-activation rating prompt.
library;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/goal_nudge_models.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/logic/goal_banner_snooze.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

enum _GoalBannerVisibilityAction {
  oneHour,
  threeHours,
  sixHours,
  eightHours,
  dismissForDay,
}

extension on _GoalBannerVisibilityAction {
  GoalBannerSnoozeDuration? get duration => switch (this) {
    _GoalBannerVisibilityAction.oneHour => GoalBannerSnoozeDuration.oneHour,
    _GoalBannerVisibilityAction.threeHours =>
      GoalBannerSnoozeDuration.threeHours,
    _GoalBannerVisibilityAction.sixHours => GoalBannerSnoozeDuration.sixHours,
    _GoalBannerVisibilityAction.eightHours =>
      GoalBannerSnoozeDuration.eightHours,
    _GoalBannerVisibilityAction.dismissForDay => null,
  };
}

/// Opens the snooze-first visibility sheet and persists the chosen action.
Future<bool> showGoalBannerSnoozeSheet(
  BuildContext context,
  WidgetRef ref,
  GoalBannerEntry entry,
) async {
  final tokens = context.designTokens;
  final messages = context.messages;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final failedNotice = messages.goalBannerActionFailed;
  final container = ProviderScope.containerOf(context, listen: false);
  final interactions = ref.read(goalNudgeInteractionsProvider);
  final action = await showModalBottomSheet<_GoalBannerVisibilityAction>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.cardPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                messages.goalBannerSnoozeTitle,
                style: tokens.typography.styles.subtitle.subtitle1,
              ),
              SizedBox(height: tokens.spacing.step1),
              Text(
                messages.goalBannerSnoozePrompt,
                style: tokens.typography.styles.body.bodyMedium.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
              SizedBox(height: tokens.spacing.step4),
              for (final option in <(_GoalBannerVisibilityAction, String)>[
                (
                  _GoalBannerVisibilityAction.oneHour,
                  messages.goalBannerSnoozeOneHour,
                ),
                (
                  _GoalBannerVisibilityAction.threeHours,
                  messages.goalBannerSnoozeThreeHours,
                ),
                (
                  _GoalBannerVisibilityAction.sixHours,
                  messages.goalBannerSnoozeSixHours,
                ),
                (
                  _GoalBannerVisibilityAction.eightHours,
                  messages.goalBannerSnoozeEightHours,
                ),
              ]) ...[
                DesignSystemButton(
                  label: option.$2,
                  leadingIcon: Icons.snooze_rounded,
                  size: DesignSystemButtonSize.medium,
                  fullWidth: true,
                  onPressed: () => Navigator.of(sheetContext).pop(option.$1),
                ),
                SizedBox(height: tokens.spacing.step2),
              ],
              SizedBox(height: tokens.spacing.step1),
              DesignSystemButton(
                label: messages.goalBannerDismissForDay,
                variant: DesignSystemButtonVariant.tertiary,
                onPressed: () => Navigator.of(
                  sheetContext,
                ).pop(_GoalBannerVisibilityAction.dismissForDay),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  if (action == null) return false;

  bool persisted;
  try {
    persisted = action == _GoalBannerVisibilityAction.dismissForDay
        ? await interactions.dismissForDay(
            entry.nudge.id,
            forActivation: entry.nudge.activationCount,
          )
        : await interactions.snooze(
            entry.nudge.id,
            duration: action.duration!,
            forActivation: entry.nudge.activationCount,
          );
  } on Object {
    messenger?.showSnackBar(SnackBar(content: Text(failedNotice)));
    return false;
  }
  if (!persisted) {
    container.invalidate(activeGoalNudgesProvider);
    return false;
  }

  final now = clock.now();
  final hiddenUntil = action.duration?.duration == null
      ? goalBannerNextLocalMidnight(now)
      : now.add(action.duration!.duration!);
  container
      .read(locallySnoozedNudgeDeadlinesProvider.notifier)
      .add(entry.nudge.id, hiddenUntil);
  container.invalidate(activeGoalNudgesProvider);
  return true;
}

/// Opens the one-outcome-per-activation rating sheet for [entry].
///
/// Sentinel contract: 1..5 = rating, 0 = the explicit Skip button, null =
/// barrier/back/drag dismissal — which consumes NOTHING, so the one rating
/// opportunity per activation survives an accidental swipe-away.
Future<void> showGoalBannerRatingSheet(
  BuildContext context,
  WidgetRef ref,
  GoalBannerEntry entry,
) async {
  final tokens = context.designTokens;
  final messages = context.messages;
  // Everything the post-sheet code needs is captured NOW: sync can remove
  // the banner (and dispose the calling widget's ref) while the sheet is
  // open, and the container outlives the widget.
  final messenger = ScaffoldMessenger.maybeOf(context);
  final failedNotice = messages.goalBannerActionFailed;
  final container = ProviderScope.containerOf(context, listen: false);
  final interactions = ref.read(goalNudgeInteractionsProvider);
  final outcome = await showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.cardPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              messages.goalBannerRatingTitle,
              style: tokens.typography.styles.subtitle.subtitle1,
            ),
            SizedBox(height: tokens.spacing.step3),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var value = 1; value <= 5; value++)
                  IconButton(
                    onPressed: () => Navigator.of(sheetContext).pop(value),
                    tooltip: '$value',
                    icon: Icon(
                      Icons.star_rate_rounded,
                      size: tokens.spacing.step7,
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                  ),
              ],
            ),
            SizedBox(height: tokens.spacing.step2),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(0),
                child: Text(messages.goalBannerRatingSkip),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (outcome == null) return;
  try {
    await interactions.recordRating(
      entry.nudge.id,
      rating: outcome == 0 ? null : outcome,
      skipped: outcome == 0,
      forActivation: entry.nudge.activationCount,
    );
  } on Object {
    // The banner stays rating-due, so tapping it re-opens the prompt — the
    // notice tells the user their pick did not stick.
    messenger?.showSnackBar(SnackBar(content: Text(failedNotice)));
  }
  container.invalidate(activeGoalNudgesProvider);
}
