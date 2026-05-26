import 'package:flutter/material.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Right-column stack of learning cards on the Drafting screen.
class LearningCardsColumn extends StatelessWidget {
  const LearningCardsColumn({required this.cards, super.key});

  final List<LearningCard> cards;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, card) in cards.indexed) ...[
          if (card.kind == LearningCardKind.nudge)
            _GentleNudgeCard(card: card)
          else
            _StandardLearningCard(card: card),
          if (index < cards.length - 1) SizedBox(height: tokens.spacing.step4),
        ],
      ],
    );
  }
}

class _StandardLearningCard extends StatelessWidget {
  const _StandardLearningCard({required this.card});

  final LearningCard card;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.l),
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      padding: EdgeInsets.all(tokens.spacing.step5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            card.overline,
            style: tokens.typography.styles.others.overline.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step2),
          Text(
            card.summary,
            style: tokens.typography.styles.subtitle.subtitle1.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step3),
          for (final bullet in card.bullets) ...[
            _BulletRow(bullet: bullet),
            SizedBox(height: tokens.spacing.step2),
          ],
        ],
      ),
    );
  }
}

class _BulletRow extends StatelessWidget {
  const _BulletRow({required this.bullet});

  final LearningBullet bullet;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final (icon, color) = switch (bullet.tone) {
      LearningBulletTone.info => (
        Icons.arrow_forward_rounded,
        tokens.colors.alert.info.defaultColor,
      ),
      LearningBulletTone.positive => (
        Icons.auto_awesome_rounded,
        tokens.colors.interactive.enabled,
      ),
      LearningBulletTone.warning => (
        Icons.shuffle_rounded,
        tokens.colors.alert.warning.defaultColor,
      ),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 14, color: color),
        ),
        SizedBox(width: tokens.spacing.step2),
        Expanded(
          child: Text(
            bullet.text,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ),
      ],
    );
  }
}

class _GentleNudgeCard extends StatelessWidget {
  const _GentleNudgeCard({required this.card});

  final LearningCard card;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final teal = tokens.colors.interactive.enabled;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            teal.withValues(alpha: 0.10),
            tokens.colors.alert.info.defaultColor.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(tokens.radii.l),
        border: Border.all(color: teal.withValues(alpha: 0.32)),
      ),
      padding: EdgeInsets.all(tokens.spacing.step5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            card.overline,
            style: tokens.typography.styles.others.overline.copyWith(
              color: teal,
            ),
          ),
          SizedBox(height: tokens.spacing.step3),
          Text(
            card.summary,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step4),
          Row(
            children: [
              // Disabled until the day-agent layer wires the
              // accept/decline round-trip; a no-op handler would imply
              // an affordance that does not yet exist.
              FilledButton(
                onPressed: null,
                style: FilledButton.styleFrom(
                  backgroundColor: teal,
                  foregroundColor: tokens.colors.text.onInteractiveAlert,
                  padding: EdgeInsets.symmetric(
                    horizontal: tokens.spacing.step4,
                    vertical: tokens.spacing.step2,
                  ),
                  textStyle: tokens.typography.styles.body.bodySmall,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(tokens.radii.m),
                  ),
                ),
                child: Text(
                  context.messages.dailyOsNextDraftingNudgeAccept,
                ),
              ),
              SizedBox(width: tokens.spacing.step3),
              TextButton(
                onPressed: null,
                style: TextButton.styleFrom(
                  foregroundColor: tokens.colors.text.mediumEmphasis,
                  padding: EdgeInsets.symmetric(
                    horizontal: tokens.spacing.step3,
                    vertical: tokens.spacing.step2,
                  ),
                  textStyle: tokens.typography.styles.body.bodySmall,
                ),
                child: Text(
                  context.messages.dailyOsNextDraftingNudgeDecline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
