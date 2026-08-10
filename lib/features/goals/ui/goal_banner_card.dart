import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/service/goal_nudge_interactions.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/ui/goal_banner_actions.dart';
import 'package:lotti/features/goals/ui/goal_banner_animated_text.dart';
import 'package:lotti/features/goals/ui/goal_banner_style.dart';
import 'package:lotti/features/goals/ui/goal_banner_widgets.dart';
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
        confirmDismiss: (_) => dismissGoalBanner(context, ref, entry),
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
                        GoalBannerPersonaChip(
                          monogram: GoalBannerPersonaChip.monogramFor(
                            entry.goalTitle,
                          ),
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
                                  onPressed: () => showGoalBannerRatingSheet(
                                    context,
                                    ref,
                                    entry,
                                  ),
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
                            onPressed: () =>
                                dismissGoalBanner(context, ref, entry),
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
                      GoalBannerCtaPill(
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
}
