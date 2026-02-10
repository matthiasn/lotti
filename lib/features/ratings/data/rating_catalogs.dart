import 'package:lotti/classes/rating_question.dart';
import 'package:lotti/l10n/app_localizations.dart';

/// Factory function that produces a localized list of rating questions.
typedef CatalogFactory = List<RatingQuestion> Function(
  AppLocalizations messages,
);

/// Registry mapping catalog IDs to their factory functions.
///
/// To add a new rating catalog (e.g. for day or task ratings), define a
/// factory function and register it here. The `catalogId` must match the
/// value stored in `RatingData.catalogId`.
final Map<String, CatalogFactory> ratingCatalogRegistry = {
  'session': sessionRatingCatalog,
};

/// Session-end rating catalog: 4 dimensions matching the original
/// hardcoded session rating modal.
List<RatingQuestion> sessionRatingCatalog(AppLocalizations messages) => [
      RatingQuestion(
        key: 'productivity',
        question: messages.sessionRatingProductivityQuestion,
        description: 'Measures subjective productivity during the work '
            'session. 0.0 = completely unproductive, '
            '1.0 = peak productivity.',
      ),
      RatingQuestion(
        key: 'energy',
        question: messages.sessionRatingEnergyQuestion,
        description: 'Measures energy level during the work session. '
            '0.0 = completely drained, 1.0 = fully energized.',
      ),
      RatingQuestion(
        key: 'focus',
        question: messages.sessionRatingFocusQuestion,
        description: 'Measures depth of focus during the work session. '
            '0.0 = constantly distracted, 1.0 = deep unbroken focus.',
      ),
      RatingQuestion(
        key: 'challenge_skill',
        question: messages.sessionRatingDifficultyLabel,
        description: 'Challenge-skill balance (flow state indicator). '
            '0.0 = task was too easy (boredom risk), '
            '0.5 = just right (flow zone), '
            '1.0 = too challenging (anxiety risk).',
        inputType: 'segmented',
        options: [
          RatingQuestionOption(
            label: messages.sessionRatingChallengeTooEasy,
            value: 0,
          ),
          RatingQuestionOption(
            label: messages.sessionRatingChallengeJustRight,
            value: 0.5,
          ),
          RatingQuestionOption(
            label: messages.sessionRatingChallengeTooHard,
            value: 1,
          ),
        ],
      ),
    ];
