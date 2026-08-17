import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/nudges/model/nudge_banner_entry.dart';
import 'package:lotti/features/nudges/service/nudge_interactions.dart';
import 'package:lotti/features/nudges/ui/nudge_banner_actions.dart';
import 'package:lotti/features/nudges/ui/nudge_banner_animated_text.dart';
import 'package:lotti/features/nudges/ui/nudge_banner_style.dart';
import 'package:lotti/features/nudges/ui/nudge_banner_widgets.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';

/// One goal banner — the agent's standing voice, rendered per the design
/// handover (1a): the register tints the whole surface so state is legible
/// before a word is read, the persona/goal caption lives in the header row
/// where it can never collide with the CTA, and the CTA is the one
/// pressable-looking element that is actually pressable. Personality comes
/// from type, colour and motion only (ADR 0058).
///
/// Snooze is the prominent banner action and reveals contextual 1/3/6/8-hour
/// choices; "dismiss for today" lives last in that sheet. The star appears
/// only while this run's one rating is due, in a fixed-width slot so the
/// layout never jumps when it goes.
class GoalBannerCard extends ConsumerWidget {
  const GoalBannerCard({required this.entry, this.onCtaPressed, super.key});

  final NudgeBannerEntry entry;

  /// Overrides the CTA pill's default navigate-to-detail behavior. The goal
  /// detail page passes an anchor-scroll to the evidence it hosts — a CTA on
  /// the page it points at must never be a self-navigation no-op.
  final VoidCallback? onCtaPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final brief = entry.nudge.brief;
    final style = nudgeBannerStyle(
      tone: brief.tone,
      accent: brief.accent,
      colors: tokens.colors,
      brightness: Theme.of(context).brightness,
    );
    final ratingDue = NudgeInteractions.ratingDue(entry.nudge);
    final radius = BorderRadius.circular(tokens.radii.l);

    return Semantics(
      label: context.messages.goalBannerSemanticLabel(entry.subjectTitle),
      child: Material(
        key: ValueKey('goal-banner-${entry.nudge.id}'),
        color: style.fill,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          // The card body is the doorway to the conversation about this
          // nudge; rating and visibility actions own separate controls.
          onTap: () => beamToNamed(entry.tapRoute),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: style.border),
            ),
            child: Padding(
              key: const ValueKey('goal-banner-content-padding'),
              padding: EdgeInsets.fromLTRB(
                tokens.spacing.cardPadding,
                tokens.spacing.step2,
                tokens.spacing.cardPadding,
                tokens.spacing.cardPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      NudgeBannerPersonaChip.forStyle(
                        monogram: NudgeBannerPersonaChip.monogramFor(
                          entry.subjectTitle,
                        ),
                        style: style,
                      ),
                      SizedBox(width: tokens.spacing.step3),
                      // The goal attribution lives HERE, where it can
                      // ellipsize freely — never on the CTA row.
                      Expanded(
                        child: Text(
                          entry.subjectTitle,
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
                        width: TapTargets.minimum,
                        height: TapTargets.minimum,
                        child: ratingDue
                            ? IconButton(
                                onPressed: () => showNudgeBannerRatingSheet(
                                  context,
                                  ref,
                                  entry,
                                ),
                                tooltip:
                                    context.messages.nudgeBannerRateTooltip,
                                icon: Icon(
                                  Icons.star_outline_rounded,
                                  size: tokens.spacing.step5,
                                  color: tokens.colors.text.lowEmphasis,
                                ),
                              )
                            : null,
                      ),
                      DesignSystemButton(
                        key: const ValueKey('goal-banner-snooze'),
                        label: context.messages.nudgeBannerSnoozeLabel,
                        leadingIcon: Icons.snooze_rounded,
                        size: DesignSystemButtonSize.dense,
                        tapTargetSize: MaterialTapTargetSize.padded,
                        onPressed: () => showNudgeBannerSnoozeSheet(
                          context,
                          ref,
                          entry,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: tokens.spacing.step2),
                  // Generated copy is never localised and wraps freely —
                  // the layout must hold long German compounds without
                  // collision (handover stress test).
                  NudgeBannerAnimatedText(
                    text: brief.headline,
                    animation: brief.animation,
                    // One step below bodyLarge, weight carrying the
                    // emphasis: the page title stays the only large voice
                    // in the first screenful.
                    style: tokens.typography.styles.body.bodyMedium.copyWith(
                      color: tokens.colors.text.highEmphasis,
                      fontWeight: tokens.typography.weight.semiBold,
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
                    NudgeBannerCtaPill(
                      label: brief.cta!,
                      style: style,
                      onTap: onCtaPressed ?? () => beamToNamed(entry.tapRoute),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
