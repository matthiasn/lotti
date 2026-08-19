/// Shared banner interactions: snooze-first visibility control and the
/// per-activation rating prompt.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/nudges/model/nudge_banner_entry.dart';
import 'package:lotti/features/nudges/state/nudge_banner_providers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

enum _NudgeBannerVisibilityAction {
  oneHour,
  threeHours,
  sixHours,
  eightHours,
  dismissForDay,
}

extension on _NudgeBannerVisibilityAction {
  NudgeBannerSnoozeDuration? get duration => switch (this) {
    _NudgeBannerVisibilityAction.oneHour => NudgeBannerSnoozeDuration.oneHour,
    _NudgeBannerVisibilityAction.threeHours =>
      NudgeBannerSnoozeDuration.threeHours,
    _NudgeBannerVisibilityAction.sixHours => NudgeBannerSnoozeDuration.sixHours,
    _NudgeBannerVisibilityAction.eightHours =>
      NudgeBannerSnoozeDuration.eightHours,
    // Exhaustiveness only: the dismiss branch never reads a duration.
    _NudgeBannerVisibilityAction.dismissForDay => null, // coverage:ignore-line
  };
}

/// Opens the snooze-first visibility sheet and persists the chosen action.
Future<bool> showNudgeBannerSnoozeSheet(
  BuildContext context,
  WidgetRef ref,
  NudgeBannerEntry entry,
) async {
  final tokens = context.designTokens;
  final messages = context.messages;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final failedNotice = messages.saveFailedRetry;
  final container = ProviderScope.containerOf(context, listen: false);
  final interactions = ref.read(nudgeInteractionsProvider);
  final action = await showModalBottomSheet<_NudgeBannerVisibilityAction>(
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
                messages.nudgeBannerSnoozeTitle,
                style: tokens.typography.styles.subtitle.subtitle1,
              ),
              SizedBox(height: tokens.spacing.step1),
              Text(
                messages.nudgeBannerSnoozePrompt,
                style: tokens.typography.styles.body.bodyMedium.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
              SizedBox(height: tokens.spacing.step4),
              // Compact duration chips, not a wall of full-width primary
              // slabs: four stacked medium buttons gave a quiet quick-pick
              // the visual weight of four competing calls to action.
              Wrap(
                spacing: tokens.spacing.step2,
                runSpacing: tokens.spacing.step2,
                children: [
                  for (final option in <(_NudgeBannerVisibilityAction, String)>[
                    (
                      _NudgeBannerVisibilityAction.oneHour,
                      messages.nudgeBannerSnoozeOneHour,
                    ),
                    (
                      _NudgeBannerVisibilityAction.threeHours,
                      messages.nudgeBannerSnoozeThreeHours,
                    ),
                    (
                      _NudgeBannerVisibilityAction.sixHours,
                      messages.nudgeBannerSnoozeSixHours,
                    ),
                    (
                      _NudgeBannerVisibilityAction.eightHours,
                      messages.nudgeBannerSnoozeEightHours,
                    ),
                  ])
                    DesignSystemButton(
                      label: option.$2,
                      leadingIcon: LottiIcons.snooze,
                      variant: DesignSystemButtonVariant.secondary,
                      size: DesignSystemButtonSize.dense,
                      // Compact PILLS, full-size TARGETS: these are the
                      // sheet's primary choices, not metadata controls.
                      tapTargetSize: MaterialTapTargetSize.padded,
                      onPressed: () =>
                          Navigator.of(sheetContext).pop(option.$1),
                    ),
                ],
              ),
              SizedBox(height: tokens.spacing.step3),
              DesignSystemButton(
                label: messages.nudgeBannerDismissForDay,
                variant: DesignSystemButtonVariant.tertiary,
                onPressed: () => Navigator.of(
                  sheetContext,
                ).pop(_NudgeBannerVisibilityAction.dismissForDay),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  if (action == null) return false;

  DateTime? hiddenUntil;
  try {
    hiddenUntil = action == _NudgeBannerVisibilityAction.dismissForDay
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
  if (hiddenUntil == null) {
    invalidateNudgeBannerSources(container);
    return false;
  }

  container
      .read(locallySnoozedNudgeDeadlinesProvider.notifier)
      .add(entry.nudge.id, entry.nudge.activationCount, hiddenUntil);
  invalidateNudgeBannerSources(container);
  return true;
}

/// Opens the one-outcome-per-activation rating sheet for [entry].
///
/// Sentinel contract: 1..5 = rating, 0 = the explicit Skip button, null =
/// barrier/back/drag dismissal — which consumes NOTHING, so the one rating
/// opportunity per activation survives an accidental swipe-away.
Future<void> showNudgeBannerRatingSheet(
  BuildContext context,
  WidgetRef ref,
  NudgeBannerEntry entry,
) async {
  final tokens = context.designTokens;
  final messages = context.messages;
  // Everything the post-sheet code needs is captured NOW: sync can remove
  // the banner (and dispose the calling widget's ref) while the sheet is
  // open, and the container outlives the widget.
  final messenger = ScaffoldMessenger.maybeOf(context);
  final failedNotice = messages.saveFailedRetry;
  final container = ProviderScope.containerOf(context, listen: false);
  final interactions = ref.read(nudgeInteractionsProvider);
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
              messages.nudgeBannerRatingTitle,
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
                      LottiIcons.star,
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
                child: Text(messages.nudgeBannerRatingSkip),
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
  invalidateNudgeBannerSources(container);
}
