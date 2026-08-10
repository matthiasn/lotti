import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/service/goal_nudge_interactions.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/ui/goal_banner_animated_text.dart';
import 'package:lotti/features/goals/ui/goal_banner_style.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';

/// One goal ad, rendered as the procedural text banner ADR 0058
/// specifies: model-authored copy, code-owned presentation. Tapping the
/// banner opens the goal's page (ADR 0055's banner→conversation flow);
/// the star opens the per-activation rating prompt while one is due;
/// dismissing (X or swipe) is the terminal user verdict that quiets ads
/// for the rest of the day.
class GoalBannerCard extends ConsumerWidget {
  const GoalBannerCard({required this.entry, super.key});

  final GoalBannerEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final style = goalBannerAccentStyle(
      entry.nudge.brief.accent,
      tokens.colors,
    );
    final brief = entry.nudge.brief;
    final ratingDue = GoalNudgeInteractions.ratingDue(entry.nudge);

    return Semantics(
      label: context.messages.goalBannerSemanticLabel(entry.goalTitle),
      // Swipe-away is the second dismissal gesture ADR 0055 specifies
      // (alongside the X); both write the same terminal verdict.
      child: Dismissible(
        key: ValueKey('goal-banner-${entry.nudge.id}'),
        // The write happens INSIDE confirmDismiss: a failure cancels the
        // swipe (the card snaps back), success lets the resize animation
        // run against a provider that already dropped the entry.
        confirmDismiss: (_) => _dismiss(context, ref),
        child: Material(
          color: style.fill,
          borderRadius: BorderRadius.circular(tokens.radii.m),
          child: InkWell(
            borderRadius: BorderRadius.circular(tokens.radii.m),
            // The banner is the doorway to its goal — rating lives on the
            // star so the tap target always leads somewhere.
            onTap: () => beamToNamed('/agents/details/${entry.nudge.agentId}'),
            child: Padding(
              padding: EdgeInsets.all(tokens.spacing.cardPadding),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: tokens.spacing.step1,
                    height: tokens.spacing.step9,
                    decoration: BoxDecoration(
                      color: style.accent,
                      borderRadius: BorderRadius.circular(tokens.radii.xs),
                    ),
                  ),
                  SizedBox(width: tokens.spacing.cardItemSpacing),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GoalBannerAnimatedText(
                          text: brief.headline,
                          animation: brief.animation,
                          style: tokens.typography.styles.body.bodyLarge
                              .copyWith(
                                color: tokens.colors.text.highEmphasis,
                              ),
                        ),
                        if (brief.tagline != null) ...[
                          SizedBox(height: tokens.spacing.step1),
                          Text(
                            brief.tagline!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: tokens.typography.styles.body.bodySmall
                                .copyWith(
                                  color: tokens.colors.text.mediumEmphasis,
                                ),
                          ),
                        ],
                        SizedBox(height: tokens.spacing.step2),
                        Row(
                          children: [
                            if (brief.cta != null)
                              Flexible(
                                child: Text(
                                  brief.cta!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: tokens.typography.styles.body.bodySmall
                                      .copyWith(color: style.accent),
                                ),
                              ),
                            SizedBox(width: tokens.spacing.step2),
                            Expanded(
                              child: Text(
                                entry.goalTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                                style: tokens.typography.styles.others.caption
                                    .copyWith(
                                      color: tokens.colors.text.lowEmphasis,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (ratingDue)
                    IconButton(
                      onPressed: () => _showRatingSheet(context, ref),
                      tooltip: context.messages.goalBannerRateTooltip,
                      icon: Icon(
                        Icons.star_outline_rounded,
                        color: tokens.colors.text.lowEmphasis,
                      ),
                    ),
                  IconButton(
                    onPressed: () => _dismiss(context, ref),
                    tooltip: context.messages.goalBannerDismissTooltip,
                    icon: Icon(
                      Icons.close_rounded,
                      color: tokens.colors.text.lowEmphasis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Returns whether the dismissal persisted — the Dismissible's
  /// confirmDismiss contract: false snaps the card back into place.
  Future<bool> _dismiss(BuildContext context, WidgetRef ref) async {
    // Everything is captured before the await: the card (and its ref)
    // may be gone when the write settles, but the container outlives it.
    final messenger = ScaffoldMessenger.maybeOf(context);
    final failedNotice = context.messages.goalBannerActionFailed;
    final container = ProviderScope.containerOf(context, listen: false);
    final interactions = ref.read(goalNudgeInteractionsProvider);
    try {
      await interactions.dismiss(
        entry.nudge.id,
        forActivation: entry.nudge.activationCount,
      );
    } on Object {
      messenger?.showSnackBar(SnackBar(content: Text(failedNotice)));
      return false;
    }
    // Interaction writes bypass the notifier by design — refresh the
    // strip AND the terminal-history timeline the dismissal just joined.
    container
      ..invalidate(activeGoalNudgesProvider)
      ..invalidate(goalNudgeHistoryProvider);
    return true;
  }

  Future<void> _showRatingSheet(BuildContext context, WidgetRef ref) async {
    final tokens = context.designTokens;
    final messages = context.messages;
    // Everything the post-sheet code needs is captured NOW: sync can
    // remove the banner (and dispose this card's ref) while the sheet is
    // open, and the container outlives the widget.
    final messenger = ScaffoldMessenger.maybeOf(context);
    final failedNotice = messages.goalBannerActionFailed;
    final container = ProviderScope.containerOf(context, listen: false);
    final interactions = ref.read(goalNudgeInteractionsProvider);
    // Sentinel contract: 1..5 = rating, 0 = the explicit Skip button,
    // null = barrier/back/drag dismissal — which consumes NOTHING, so
    // the one rating opportunity per activation survives an accidental
    // swipe-away.
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
      // The banner stays rating-due, so tapping it re-opens the prompt —
      // the notice tells the user their pick did not stick.
      messenger?.showSnackBar(SnackBar(content: Text(failedNotice)));
    }
    container.invalidate(activeGoalNudgesProvider);
  }
}
