import 'package:lotti/l10n/app_localizations.dart';
import 'package:research_package/model.dart';

/// Creates the localized five-point PANAS response scale.
///
/// The numerical values are the scoring contract; only their visible labels
/// vary with the app locale.
RPChoiceAnswerFormat createPanasAnswerFormat(AppLocalizations messages) =>
    RPChoiceAnswerFormat(
      answerStyle: RPChoiceAnswerStyle.SingleChoice,
      choices: [
        RPChoice(text: messages.panasScaleVerySlightlyOrNotAtAll, value: 1),
        RPChoice(text: messages.panasScaleALittle, value: 2),
        RPChoice(text: messages.panasScaleModerately, value: 3),
        RPChoice(text: messages.panasScaleQuiteABit, value: 4),
        RPChoice(text: messages.panasScaleExtremely, value: 5),
      ],
    );

/// Creates the localized PANAS questionnaire.
///
/// Question identifiers stay stable because persisted answers and
/// [panasScoreDefinitions] use them to calculate the positive and negative
/// affect totals. The response labels and all user-visible copy come from the
/// active [AppLocalizations].
RPOrderedTask createPanasSurveyTask(AppLocalizations messages) {
  final answerFormat = createPanasAnswerFormat(messages);
  final questionTitles = [
    messages.panasEmotionInterested,
    messages.panasEmotionDistressed,
    messages.panasEmotionExcited,
    messages.panasEmotionUpset,
    messages.panasEmotionStrong,
    messages.panasEmotionGuilty,
    messages.panasEmotionScared,
    messages.panasEmotionHostile,
    messages.panasEmotionEnthusiastic,
    messages.panasEmotionProud,
    messages.panasEmotionIrritable,
    messages.panasEmotionAlert,
    messages.panasEmotionAshamed,
    messages.panasEmotionInspired,
    messages.panasEmotionNervous,
    messages.panasEmotionDetermined,
    messages.panasEmotionAttentive,
    messages.panasEmotionJittery,
    messages.panasEmotionActive,
    messages.panasEmotionAfraid,
  ];

  return RPOrderedTask(
    identifier: 'panasSurveyTask',
    steps: [
      RPInstructionStep(
        identifier: 'panasInstructions',
        title: messages.panasInstructionTitle,
        text: messages.panasInstructionText,
        footnote: messages.panasInstructionFootnote,
      ),
      for (var index = 0; index < questionTitles.length; index++)
        RPQuestionStep(
          identifier: 'panasQuestion${index + 1}',
          title: questionTitles[index],
          answerFormat: answerFormat,
        ),
      RPCompletionStep(
        identifier: 'panasCompletion',
        title: messages.panasCompletionTitle,
        text: messages.panasCompletionText,
      ),
    ],
  );
}

/// Score buckets for PANAS: two totals, `Positive Affect Score` (10 items) and
/// `Negative Affect Score` (the other 10), each summing Likert 1–5 answers
/// (range 10–50 per bucket). Consumed by `calculateScores`.
Map<String, Set<String>> panasScoreDefinitions = {
  'Positive Affect Score': {
    'panasQuestion1',
    'panasQuestion3',
    'panasQuestion5',
    'panasQuestion9',
    'panasQuestion10',
    'panasQuestion12',
    'panasQuestion14',
    'panasQuestion16',
    'panasQuestion17',
    'panasQuestion19',
  },
  'Negative Affect Score': {
    'panasQuestion2',
    'panasQuestion4',
    'panasQuestion6',
    'panasQuestion7',
    'panasQuestion8',
    'panasQuestion11',
    'panasQuestion13',
    'panasQuestion15',
    'panasQuestion18',
    'panasQuestion20',
  },
};
