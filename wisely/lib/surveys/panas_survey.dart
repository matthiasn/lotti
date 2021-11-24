import 'package:flutter/foundation.dart';
import 'package:research_package/model.dart';

RPInstructionStep panasInstructionStep = RPInstructionStep(
  identifier: 'panasInstructions',
  title:
      'The Positive and Negative Affect Schedule (PANAS; Watson et al., 1988)',
  text: 'Indicate to what extent you feel this way right now, that is, at the '
      'present moment.\n\n'
      '1-Very Slightly or Not at All, 2-A Little, 3-Moderately, 4-Quite a Bit, '
      '5-Extremely',
  footnote: 'Watson, D., Clark, L. A., & Tellegan, A. (1988). Development and '
      'validation of brief measures of positive and negative affect: The PANAS '
      'scales. Journal of Personality and Social Psychology, 54(6), 1063–1070.',
);

List<RPImageChoice> panasImages = [
  RPImageChoice(
    imageUrl: 'assets/icons/gray-1.png',
    value: 1,
    description: 'Very slightly or not at all',
  ),
  RPImageChoice(
    imageUrl: 'assets/icons/gray-2.png',
    value: 2,
    description: 'A little',
  ),
  RPImageChoice(
    imageUrl: 'assets/icons/gray-3.png',
    value: 3,
    description: 'Moderately',
  ),
  RPImageChoice(
    imageUrl: 'assets/icons/gray-4.png',
    value: 4,
    description: 'Quite a bit',
  ),
  RPImageChoice(
    imageUrl: 'assets/icons/gray-5.png',
    value: 5,
    description: 'Extremely',
  ),
];

RPImageChoiceAnswerFormat panasImageChoiceAnswerFormat =
    RPImageChoiceAnswerFormat(choices: panasImages);

RPCompletionStep panasCompletionStep = RPCompletionStep(
    identifier: 'panasCompletion',
    title: 'Finished',
    text: 'Thank you for filling out the PANAS!');

RPOrderedTask panasSurveyTask = RPOrderedTask(
  identifier: 'panasSurveyTask',
  steps: [
    panasInstructionStep,
    RPQuestionStep(
      identifier: 'panasQuestion1',
      title: 'Interested',
      answerFormat: panasImageChoiceAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasQuestion2',
      title: 'Distressed',
      answerFormat: panasImageChoiceAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasQuestion3',
      title: 'Excited',
      answerFormat: panasImageChoiceAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasQuestion4',
      title: 'Upset',
      answerFormat: panasImageChoiceAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasQuestion5',
      title: 'Strong',
      answerFormat: panasImageChoiceAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasQuestion6',
      title: 'Guilty',
      answerFormat: panasImageChoiceAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasQuestion7',
      title: 'Scared',
      answerFormat: panasImageChoiceAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasQuestion8',
      title: 'Hostile',
      answerFormat: panasImageChoiceAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasQuestion9',
      title: 'Enthusiastic',
      answerFormat: panasImageChoiceAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasQuestion10',
      title: 'Proud',
      answerFormat: panasImageChoiceAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasQuestion11',
      title: 'Irritable',
      answerFormat: panasImageChoiceAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasQuestion12',
      title: 'Alert',
      answerFormat: panasImageChoiceAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasQuestion13',
      title: 'Ashamed',
      answerFormat: panasImageChoiceAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasQuestion14',
      title: 'Inspired',
      answerFormat: panasImageChoiceAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasQuestion15',
      title: 'Nervous',
      answerFormat: panasImageChoiceAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasQuestion16',
      title: 'Determined',
      answerFormat: panasImageChoiceAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasQuestion17',
      title: 'Attentive',
      answerFormat: panasImageChoiceAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasQuestion18',
      title: 'Jittery',
      answerFormat: panasImageChoiceAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasQuestion19',
      title: 'Active',
      answerFormat: panasImageChoiceAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasQuestion20',
      title: 'Afraid',
      answerFormat: panasImageChoiceAnswerFormat,
    ),
    panasCompletionStep
  ],
);

Map<String, Set<int>> scores = {
  'Positive Affect Score': {1, 3, 5, 9, 10, 12, 14, 16, 17, 19},
  'Negative Affect Score': {2, 4, 6, 7, 8, 11, 13, 15, 18, 20},
};

void panasResultCallback(RPTaskResult taskResult) {
  Map<String, dynamic> results = taskResult.results;

  for (MapEntry<String, Set<int>> scoreEntry in scores.entries) {
    int score = 0;

    for (int index in scoreEntry.value) {
      RPStepResult stepResult = results['panasQuestion$index'];
      RPImageChoice choice = stepResult.results['answer'];
      int value = choice.value;
      score = score + value;
    }

    debugPrint('${scoreEntry.key}: $score');
  }
}
