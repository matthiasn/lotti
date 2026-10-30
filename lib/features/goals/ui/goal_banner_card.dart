import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/design_system/components/ds_quiet_ink.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/nudges/logic/nudge_private_copy.dart';
import 'package:lotti/features/nudges/model/nudge_banner_entry.dart';
import 'package:lotti/features/nudges/service/nudge_interactions.dart';
import 'package:lotti/features/nudges/ui/nudge_banner_actions.dart';
import 'package:lotti/features/nudges/ui/nudge_banner_animated_text.dart';
import 'package:lotti/features/nudges/ui/nudge_banner_quiet_actions.dart';
import 'package:lotti/features/nudges/ui/nudge_banner_style.dart';
import 'package:lotti/features/nudges/ui/nudge_banner_widgets.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';

/// One goal banner — the agent's standing voice, rendered per the design
/// handover (1a): the register tints the whole surface so state is legible
/// before a word is read, the persona/goal caption lives in the header row
/// where it can never collide with the CTA, and the CTA is the one
/// pressable-looking element that is actually pressable. Personality comes
/// from type, colour and motion only (ADR 0058).
///
/// Snooze and the rating star are the header's quiet secondary voice
/// ([NudgeBannerQuietActions]): Snooze reveals contextual 1/3/6/8-hour
/// choices with "dismiss for today" last in that sheet, and the star appears
/// only while this run's one rating is due, in a slot the group always holds
/// so the header never reflows when it goes.
class GoalBannerCard extends ConsumerWidget {
  const GoalBannerCard({required this.entry, this.onCtaPressed, super.key});

  final NudgeBannerEntry entry;

  /// Overrides where the card goes — the CTA pill and the body tap alike,
  /// one doorway with one verb. The goal detail page passes the verb the
  /// CTA names (log today, open the check-in composer, or scroll to the
  /// evidence it hosts), because a card on the page it points at must never
  /// be a self-navigation no-op.
  final VoidCallback? onCtaPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The card hard-codes goal semantics (the semantic label below); the
    // dock switches on kind before reaching it, and a misrouted entry must
    // fail loudly in debug rather than announce "Goal banner" for a person.
    assert(
      entry.kind == NudgeBannerKind.goal,
      'GoalBannerCard renders goal entries only',
    );
    final tokens = context.designTokens;
    final brief = nudgeDisplayBrief(
      entry.nudge,
      showPrivate: ref.watch(configFlagProvider(privateFlag)).value ?? false,
    );
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
        // The card body is the doorway to the conversation about this
        // nudge; rating and visibility actions own separate controls. The
        // doorway stays quiet: Material's hover overlay washed the whole
        // banner like one enormous button, while the CTA pill below is the
        // element that actually advertises pressability.
        child: DsQuietInk(
          borderRadius: radius,
          focusRing: true,
          // One doorway, one verb: the body goes where the pill goes, so
          // on the goal's own page it anchors rather than self-navigates.
          onTap: onCtaPressed ?? () => beamToNamed(entry.tapRoute),
          builder: (context, highlighted) => DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: style.border),
            ),
            child: Padding(
              key: const ValueKey('goal-banner-content-padding'),
              // One interval everywhere. The 48dp header row carries step3
              // of slack around its glyphs, the headline a line's leading,
              // the pill its floor's slack: a step2 top inset, a step1 gap
              // and step4 before the pill all render as the same measure as
              // the bottom cardPadding, once that slack is counted.
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
                      SizedBox(width: tokens.spacing.step2),
                      NudgeBannerQuietActions(
                        ratingDue: ratingDue,
                        compact: !isDesktopLayout(context),
                        snoozeKey: const ValueKey('goal-banner-snooze'),
                        onRate: () => showNudgeBannerRatingSheet(
                          context,
                          ref,
                          entry,
                        ),
                        onSnooze: () => showNudgeBannerSnoozeSheet(
                          context,
                          ref,
                          entry,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: tokens.spacing.step1),
                  // Generated copy is never localised and wraps freely —
                  // the layout must hold long German compounds without
                  // collision (handover stress test).
                  NudgeBannerAnimatedText(
                    text: brief.headline,
                    animation: brief.animation,
                    // Whole, like the dock: one truncation policy for the
                    // same model copy on both surfaces.
                    maxLines: null,
                    // The subtitle tier: a step below the page title,
                    // weight carrying the emphasis, so the title stays the
                    // only large voice in the first screenful. The dock
                    // sets its headline in the same style.
                    style: tokens.typography.styles.subtitle.subtitle1.copyWith(
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
                    SizedBox(height: tokens.spacing.step4),
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
