/// The two user verdicts on a banner — dismissal and the per-activation
/// rating — shared by every surface that renders one (the card, the dock).
/// Both write through `goalNudgeInteractionsProvider` and reconcile the
/// reactive surfaces afterwards; the widgets only decide WHERE the
/// affordances sit.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Dismisses [entry]'s banner — the terminal user verdict that quiets this
/// goal's voice for the rest of the day, honoured in every register.
///
/// Returns whether the dismissal persisted (the `Dismissible.confirmDismiss`
/// contract: false snaps a swiped card back into place). Everything is
/// captured before the first await: the calling widget may be gone when the
/// write settles, but the container outlives it.
Future<bool> dismissGoalBanner(
  BuildContext context,
  WidgetRef ref,
  GoalBannerEntry entry,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final failedNotice = context.messages.goalBannerActionFailed;
  final container = ProviderScope.containerOf(context, listen: false);
  final interactions = ref.read(goalNudgeInteractionsProvider);
  bool persisted;
  try {
    persisted = await interactions.dismiss(
      entry.nudge.id,
      forActivation: entry.nudge.activationCount,
    );
  } on Object {
    messenger?.showSnackBar(SnackBar(content: Text(failedNotice)));
    return false;
  }
  if (!persisted) {
    // The guards declined — sync advanced the activation mid-tap. The NEW
    // run was never seen and must not be hidden; the refresh below
    // re-renders it.
    container
      ..invalidate(activeGoalNudgesProvider)
      ..invalidate(goalNudgeHistoryProvider);
    return false;
  }
  // The durable write succeeded: suppress the id locally FIRST, so the X
  // visibly works even if the fallible reload below fails and the surfaces
  // keep rendering retained data.
  container
      .read(locallyDismissedNudgeIdsProvider.notifier)
      .add(
        entry.nudge.id,
      );
  // Interaction writes bypass the notifier by design — refresh the banner
  // surfaces AND the terminal-history timeline the dismissal just joined.
  container
    ..invalidate(activeGoalNudgesProvider)
    ..invalidate(goalNudgeHistoryProvider);
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
