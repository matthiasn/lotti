import 'package:research_package/model.dart';

List<RPChoice> cqf11Choices = [
  RPChoice(text: '0—Better than usual', value: 0),
  RPChoice(text: '1—No worse than usual', value: 1),
  RPChoice(text: '2—Worse than usual', value: 2),
  RPChoice(text: '3—Much worse than usual', value: 3),
];

RPChoiceAnswerFormat cfq11AnswerFormat = RPChoiceAnswerFormat(
  answerStyle: RPChoiceAnswerStyle.SingleChoice,
  choices: cqf11Choices,
);

List<RPImageChoice> cfq11Images = [
  RPImageChoice(
    imageUrl: 'assets/icons/green-0.png',
    value: 0,
    description: 'Better than usual',
  ),
  RPImageChoice(
    imageUrl: 'assets/icons/green-1.png',
    value: 1,
    description: 'No worse than usual',
  ),
  RPImageChoice(
    imageUrl: 'assets/icons/red-2.png',
    value: 2,
    description: 'Worse than usual',
  ),
  RPImageChoice(
    imageUrl: 'assets/icons/red-3.png',
    value: 3,
    description: 'Much worse than usual',
  ),
];

RPImageChoiceAnswerFormat cfq11ImageChoiceAnswerFormat =
    RPImageChoiceAnswerFormat(
  choices: cfq11Images,
);

RPCompletionStep cfq11CompletionStep = RPCompletionStep(
  identifier: 'cfq11Completion',
  title: 'Finished',
  text: 'Thank you for filling out the CFQ11!',
);

RPInstructionStep cfq11InstructionStep = RPInstructionStep(
  identifier: 'cfq11Instructions',
  title: 'Chalder Fatigue Scale (CFQ 11)',
  text:
      'We would like to know more about any problems you have had with feeling '
      'tired, weak or lacking in energy in the last month. Please answer ALL '
      'the questions by ticking the answer which applies to you most closely. '
      'If you have been feeling tired for a long while, then compare yourself '
      'to how you felt when you were last well. Please tick only one box per'
      ' line.\n\n'
      '0—Better than usual, \n1—No worse than usual, \n2—Worse than usual, '
      '\n3—Much worse than usual\n\n',
  footnote:
      'Cella, M. and T. Chalder (2010). "Measuring fatigue in clinical and '
      'community settings." J Psychosom Res 69(1): 17-22.',
);

RPOrderedTask cfq11SurveyTask = RPOrderedTask(
  identifier: 'cfq11SurveyTask',
  steps: [
    cfq11InstructionStep,
    RPQuestionStep(
      identifier: 'cfq11Step1',
      title: 'Do you have problems with tiredness?',
      answerFormat: cfq11ImageChoiceAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'cfq11Step2',
      title: 'Do you need to rest more?',
      answerFormat: cfq11ImageChoiceAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'cfq11Step3',
      title: 'Do you feel sleepy or drowsy?',
      answerFormat: cfq11ImageChoiceAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'cfq11Step4',
      title: 'Do you have problems starting things?',
      answerFormat: cfq11ImageChoiceAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'cfq11Step5',
      title: 'Do you lack energy?',
      answerFormat: cfq11ImageChoiceAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'cfq11Step6',
      title: 'Do you have less strength in your muscles?',
      answerFormat: cfq11ImageChoiceAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'cfq11Step7',
      title: 'Do you feel weak?',
      answerFormat: cfq11ImageChoiceAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'cfq11Step8',
      title: 'Do you have difficulty concentrating?',
      answerFormat: cfq11ImageChoiceAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'cfq11Step9',
      title: 'Do you make slips of the tongue when speaking?',
      answerFormat: cfq11ImageChoiceAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'cfq11Step10',
      title: 'Do you find it more difficult to find the right word?',
      answerFormat: cfq11ImageChoiceAnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'cfq11Step11',
      title: 'How is your memory?',
      answerFormat: cfq11ImageChoiceAnswerFormat,
    ),
    cfq11CompletionStep
  ],
);

Map<String, Set<String>> cfq11ScoreDefinitions = {
  'CFQ11': {
    'cfq11Step1',
    'cfq11Step2',
    'cfq11Step3',
    'cfq11Step4',
    'cfq11Step5',
    'cfq11Step6',
    'cfq11Step7',
    'cfq11Step8',
    'cfq11Step9',
    'cfq11Step10',
    'cfq11Step11',
  },
};
