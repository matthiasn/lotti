import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/service/goal_nudge_interactions.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/ui/goal_banner_animated_text.dart';
import 'package:lotti/features/goals/ui/goal_banner_style.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';

/// One goal banner — the agent's standing voice, rendered per the design
/// handover (1a): the register tints the whole surface so state is legible
/// before a word is read, the persona/goal caption lives in the header row
/// where it can never collide with the CTA, and the CTA is the one
/// pressable-looking element that is actually pressable. Personality comes
/// from type, colour and motion only (ADR 0058).
///
/// Dismissing (X or swipe) is the terminal user verdict that quiets this
/// goal's voice for the rest of the day — honoured absolutely, in every
/// register. The star appears only while this run's one rating is due, in a
/// fixed-width slot so the layout never jumps when it goes.
class GoalBannerCard extends ConsumerWidget {
  const GoalBannerCard({required this.entry, super.key});

  final GoalBannerEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final brief = entry.nudge.brief;
    final style = goalBannerStyle(
      tone: brief.tone,
      accent: brief.accent,
      colors: tokens.colors,
      brightness: Theme.of(context).brightness,
    );
    final ratingDue = GoalNudgeInteractions.ratingDue(entry.nudge);
    final radius = BorderRadius.circular(tokens.radii.l);

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
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            // The card body is the doorway to the conversation about this
            // nudge; rating lives on the star, dismissal on the X.
            onTap: () => beamToNamed('/agents/details/${entry.nudge.agentId}'),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(color: style.border),
              ),
              child: Padding(
                padding: EdgeInsets.all(tokens.spacing.cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _PersonaChip(
                          monogram: _monogram(entry.goalTitle),
                          style: style,
                        ),
                        SizedBox(width: tokens.spacing.step3),
                        // The goal attribution lives HERE, where it can
                        // ellipsize freely — never on the CTA row.
                        Expanded(
                          child: Text(
                            entry.goalTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tokens.typography.styles.others.caption
                                .copyWith(
                                  color: tokens.colors.text.mediumEmphasis,
                                ),
                          ),
                        ),
                        // Fixed-width slots: the star only exists while a
                        // rating is due, but its SLOT always does — the
                        // header never reflows when the star goes.
                        SizedBox(
                          width: tokens.spacing.step8,
                          height: tokens.spacing.step8,
                          child: ratingDue
                              ? IconButton(
                                  onPressed: () =>
                                      _showRatingSheet(context, ref),
                                  tooltip:
                                      context.messages.goalBannerRateTooltip,
                                  icon: Icon(
                                    Icons.star_outline_rounded,
                                    size: tokens.spacing.step5,
                                    color: tokens.colors.text.lowEmphasis,
                                  ),
                                )
                              : null,
                        ),
                        SizedBox(
                          width: tokens.spacing.step8,
                          height: tokens.spacing.step8,
                          child: IconButton(
                            onPressed: () => _dismiss(context, ref),
                            tooltip: context.messages.goalBannerDismissTooltip,
                            icon: Icon(
                              Icons.close_rounded,
                              size: tokens.spacing.step5,
                              color: tokens.colors.text.lowEmphasis,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: tokens.spacing.step2),
                    // Generated copy is never localised and wraps freely —
                    // the layout must hold long German compounds without
                    // collision (handover stress test).
                    GoalBannerAnimatedText(
                      text: brief.headline,
                      animation: brief.animation,
                      style: tokens.typography.styles.body.bodyLarge.copyWith(
                        color: tokens.colors.text.highEmphasis,
                      ),
                    ),
                    if (brief.tagline != null) ...[
                      SizedBox(height: tokens.spacing.step1),
                      Text(
                        brief.tagline!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tokens.typography.styles.body.bodySmall.copyWith(
                          color: tokens.colors.text.mediumEmphasis,
                        ),
                      ),
                    ],
                    if (brief.cta != null) ...[
                      SizedBox(height: tokens.spacing.step3),
                      _CtaPill(
                        label: brief.cta!,
                        style: style,
                        onTap: () => beamToNamed(
                          '/agents/details/${entry.nudge.agentId}',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _monogram(String title) =>
      title.isEmpty ? '·' : title.characters.first.toUpperCase();

  /// Returns whether the dismissal persisted — the Dismissible's
  /// confirmDismiss contract: false snaps the card back into place.
  Future<bool> _dismiss(BuildContext context, WidgetRef ref) async {
    // Everything is captured before the await: the card (and its ref)
    // may be gone when the write settles, but the container outlives it.
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
      // The guards declined — sync advanced the activation mid-tap. The
      // NEW run was never seen and must not be hidden; the refresh below
      // re-renders it.
      container
        ..invalidate(activeGoalNudgesProvider)
        ..invalidate(goalNudgeHistoryProvider);
      return false;
    }
    // The durable write succeeded: suppress the id locally FIRST, so the
    // X visibly works even if the fallible reload below fails and the
    // surfaces keep rendering retained data.
    container
        .read(locallyDismissedNudgeIdsProvider.notifier)
        .add(
          entry.nudge.id,
        );
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

/// The monogram identity chip: accent letter on the accent's chip wash.
/// Typography and colour only — no faces, no imagery (ADR 0058 holds even
/// for identity).
class _PersonaChip extends StatelessWidget {
  const _PersonaChip({required this.monogram, required this.style});

  final String monogram;
  final GoalBannerStyle style;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      width: tokens.spacing.step6,
      height: tokens.spacing.step6,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: style.chipFill,
        shape: BoxShape.circle,
      ),
      child: Text(
        monogram,
        style: tokens.typography.styles.others.overline.copyWith(
          color: style.accent,
        ),
      ),
    );
  }
}

/// The one pressable-looking element that is actually pressable: the
/// accent-washed CTA pill.
class _CtaPill extends StatelessWidget {
  const _CtaPill({
    required this.label,
    required this.style,
    required this.onTap,
  });

  final String label;
  final GoalBannerStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final radius = BorderRadius.circular(tokens.radii.badgesPills);
    return Material(
      color: style.controlFill,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step4,
            vertical: tokens.spacing.step3,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tokens.typography.styles.subtitle.subtitle2.copyWith(
              color: style.accent,
            ),
          ),
        ),
      ),
    );
  }
}
