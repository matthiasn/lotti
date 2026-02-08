import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ratings/ui/session_rating_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// Read-only summary of a [RatingEntry], shown in the entry detail view.
///
/// Displays each dimension as a labelled progress bar, the challenge-skill
/// value as categorical text, an optional note, and an edit button to re-open
/// the [SessionRatingModal].
class RatingSummary extends StatelessWidget {
  const RatingSummary(this.ratingEntry, {super.key});

  final RatingEntry ratingEntry;

  @override
  Widget build(BuildContext context) {
    final data = ratingEntry.data;
    final messages = context.messages;
    final colorScheme = context.colorScheme;

    final productivity = data.dimensionValue('productivity');
    final energy = data.dimensionValue('energy');
    final focus = data.dimensionValue('focus');
    final challengeSkill = data.dimensionValue('challenge_skill');

    final challengeSkillText = switch (challengeSkill) {
      0.0 => messages.sessionRatingChallengeTooEasy,
      0.5 => messages.sessionRatingChallengeJustRight,
      1.0 => messages.sessionRatingChallengeTooHard,
      _ => null,
    };

    return Padding(
      padding: const EdgeInsets.only(
        top: AppTheme.spacingSmall,
        bottom: AppTheme.spacingMedium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Productivity
          if (productivity != null)
            _DimensionRow(
              label: messages.sessionRatingProductivityQuestion,
              value: productivity,
              color: colorScheme.primary,
            ),

          // Energy
          if (energy != null)
            _DimensionRow(
              label: messages.sessionRatingEnergyQuestion,
              value: energy,
              color: colorScheme.primary,
            ),

          // Focus
          if (focus != null)
            _DimensionRow(
              label: messages.sessionRatingFocusQuestion,
              value: focus,
              color: colorScheme.primary,
            ),

          // Challenge-Skill
          if (challengeSkillText != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spacingSmall),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      messages.sessionRatingDifficultyLabel,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    challengeSkillText,
                    style: context.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

          // Note
          if (data.note != null && data.note!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spacingSmall),
              child: Text(
                data.note!,
                style: context.textTheme.bodyMedium,
              ),
            ),

          // Edit button
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: messages.sessionRatingEditButton,
              onPressed: () => SessionRatingModal.show(
                context,
                data.timeEntryId,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single dimension displayed as label + [LinearProgressIndicator].
class _DimensionRow extends StatelessWidget {
  const _DimensionRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingSmall),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              backgroundColor: context.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}
