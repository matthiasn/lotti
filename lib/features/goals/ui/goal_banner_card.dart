import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/service/goal_nudge_interactions.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/ui/goal_banner_animated_text.dart';
import 'package:lotti/features/goals/ui/goal_banner_style.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// One goal ad, rendered as the procedural text banner ADR 0058
/// specifies: model-authored copy, code-owned presentation. Dismissing is
/// the terminal user verdict (quiets ads for the rest of the day);
/// tapping
/// opens the per-activation rating prompt when one is due.
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
      child: Material(
        color: style.fill,
        borderRadius: BorderRadius.circular(tokens.radii.m),
        child: InkWell(
          borderRadius: BorderRadius.circular(tokens.radii.m),
          onTap: ratingDue ? () => _showRatingSheet(context, ref) : null,
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
                        style: tokens.typography.styles.body.bodyLarge.copyWith(
                          color: tokens.colors.text.highEmphasis,
                        ),
                      ),
                      if (brief.tagline != null) ...[
                        SizedBox(height: tokens.spacing.step1),
                        Text(
                          brief.tagline!,
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
                            Text(
                              brief.cta!,
                              style: tokens.typography.styles.body.bodySmall
                                  .copyWith(color: style.accent),
                            ),
                          const Spacer(),
                          Text(
                            entry.goalTitle,
                            style: tokens.typography.styles.others.caption
                                .copyWith(
                                  color: tokens.colors.text.lowEmphasis,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _dismiss(ref),
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
    );
  }

  Future<void> _dismiss(WidgetRef ref) async {
    await ref.read(goalNudgeInteractionsProvider).dismiss(entry.nudge.id);
    // Interaction writes bypass the notifier by design — refresh the strip.
    ref.invalidate(activeGoalNudgesProvider);
  }

  Future<void> _showRatingSheet(BuildContext context, WidgetRef ref) async {
    final tokens = context.designTokens;
    final messages = context.messages;
    final rating = await showModalBottomSheet<int?>(
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
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: Text(messages.goalBannerRatingSkip),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await ref
        .read(goalNudgeInteractionsProvider)
        .recordRating(
          entry.nudge.id,
          rating: rating,
          skipped: rating == null,
        );
    ref.invalidate(activeGoalNudgesProvider);
  }
}
