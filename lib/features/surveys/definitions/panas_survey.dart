import 'package:research_package/model.dart';

final panasInstructionStep = RPInstructionStep(
  identifier: 'panasInstructions',
  title:
      'The Positive and Negative Affect Schedule (PANAS; Watson et al., 1988)',
  text: 'Indicate to what extent you feel this way right now, that is, at the '
      'present moment.\n\n'
      '1-Very Slightly or Not at All,\n'
      '2-A Little,\n'
      '3-Moderately,\n'
      '4-Quite a Bit,\n'
      '5-Extremely',
  footnote: 'Watson, D., Clark, L. A., & Tellegan, A. (1988). Development and '
      'validation of brief measures of positive and negative affect: The PANAS '
      'scales. Journal of Personality and Social Psychology, 54(6), 1063–1070.',
);

final panasAnswerFormat = RPChoiceAnswerFormat(
  answerStyle: RPChoiceAnswerStyle.SingleChoice,
  choices: [
    RPChoice(text: 'Very slightly or not at all', value: 1),
    RPChoice(text: 'A little', value: 2),
    RPChoice(text: 'Moderately', value: 3),
    RPChoice(text: 'Quite a bit', value: 4),
    RPChoice(text: 'Extremely', value: 5),
  ],
);

final panasCompletionStep = RPCompletionStep(
  identifier: 'panasCompletion',
  title: 'Finished',
  text: 'Thank you for filling out the PANAS!',
);

final panasSurveyTask = RPOrderedTask(
  identifier: 'panasSurveyTask',
  steps: [
    panasInstructionStep,
    RPQuestionStep(
      identifier: 'panasQuestion1',
      title: 'Interested',
      answerFormat: panasAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasQuestion2',
      title: 'Distressed',
      answerFormat: panasAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasQuestion3',
      title: 'Excited',
      answerFormat: panasAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasQuestion4',
      title: 'Upset',
      answerFormat: panasAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasQuestion5',
      title: 'Strong',
      answerFormat: panasAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasQuestion6',
      title: 'Guilty',
      answerFormat: panasAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasQuestion7',
      title: 'Scared',
      answerFormat: panasAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasQuestion8',
      title: 'Hostile',
      answerFormat: panasAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasQuestion9',
      title: 'Enthusiastic',
      answerFormat: panasAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasQuestion10',
      title: 'Proud',
      answerFormat: panasAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasQuestion11',
      title: 'Irritable',
      answerFormat: panasAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasQuestion12',
      title: 'Alert',
      answerFormat: panasAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasQuestion13',
      title: 'Ashamed',
      answerFormat: panasAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasQuestion14',
      title: 'Inspired',
      answerFormat: panasAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasQuestion15',
      title: 'Nervous',
      answerFormat: panasAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasQuestion16',
      title: 'Determined',
      answerFormat: panasAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasQuestion17',
      title: 'Attentive',
      answerFormat: panasAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasQuestion18',
      title: 'Jittery',
      answerFormat: panasAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasQuestion19',
      title: 'Active',
      answerFormat: panasAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'panasQuestion20',
      title: 'Afraid',
      answerFormat: panasAnswerFormat,
    ),
    panasCompletionStep,
  ],
);

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
