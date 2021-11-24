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
      identifier: 'panasStep1',
      title: 'Interested',
      answerFormat: panasImageChoiceAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasStep2',
      title: 'Distressed',
      answerFormat: panasImageChoiceAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasStep3',
      title: 'Excited',
      answerFormat: panasImageChoiceAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasStep4',
      title: 'Upset',
      answerFormat: panasImageChoiceAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasStep5',
      title: 'Strong',
      answerFormat: panasImageChoiceAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasStep6',
      title: 'Guilty',
      answerFormat: panasImageChoiceAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasStep7',
      title: 'Scared',
      answerFormat: panasImageChoiceAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasStep8',
      title: 'Hostile',
      answerFormat: panasImageChoiceAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasStep9',
      title: 'Enthusiastic',
      answerFormat: panasImageChoiceAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasStep10',
      title: 'Proud',
      answerFormat: panasImageChoiceAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasStep11',
      title: 'Irritable',
      answerFormat: panasImageChoiceAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasStep12',
      title: 'Alert',
      answerFormat: panasImageChoiceAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasStep13',
      title: 'Ashamed',
      answerFormat: panasImageChoiceAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasStep14',
      title: 'Inspired',
      answerFormat: panasImageChoiceAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasStep15',
      title: 'Nervous',
      answerFormat: panasImageChoiceAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasStep16',
      title: 'Determined',
      answerFormat: panasImageChoiceAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasStep17',
      title: 'Attentive',
      answerFormat: panasImageChoiceAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasStep18',
      title: 'Jittery',
      answerFormat: panasImageChoiceAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasStep19',
      title: 'Active',
      answerFormat: panasImageChoiceAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasStep20',
      title: 'Afraid',
      answerFormat: panasImageChoiceAnswerFormat,
    ),
    panasCompletionStep
  ],
);

void panasResultCallback(RPTaskResult result) {
  // Do anything with the result
  debugPrint(result.toString());
}
