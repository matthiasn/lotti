import 'package:research_package/model.dart';

final cfq11AnswerFormat = RPChoiceAnswerFormat(
  answerStyle: RPChoiceAnswerStyle.SingleChoice,
  choices: [
    RPChoice(text: 'Better than usual', value: 0),
    RPChoice(text: 'No worse than usual', value: 1),
    RPChoice(text: 'Worse than usual', value: 2),
    RPChoice(text: 'Much worse than usual', value: 3),
  ],
);

final cfq11CompletionStep = RPCompletionStep(
  identifier: 'cfq11Completion',
  title: 'Finished',
  text: 'Thank you for filling out the CFQ11!',
);

final cfq11InstructionStep = RPInstructionStep(
  identifier: 'cfq11Instructions',
  title: 'Chalder Fatigue Scale (CFQ 11)',
  text:
      'We would like to know more about any problems you have had with feeling '
      'tired, weak or lacking in energy in the last month. Please answer ALL '
      'the questions by ticking the answer which applies to you most closely. '
      'If you have been feeling tired for a long while, then compare yourself '
      'to how you felt when you were last well. Please tick only one box per'
      ' line.\n\n'
      '0—Better than usual,\n'
      '1—No worse than usual,\n'
      '2—Worse than usual,\n'
      '3—Much worse than usual',
  footnote:
      'Cella, M. and T. Chalder (2010). "Measuring fatigue in clinical and '
      'community settings." J Psychosom Res 69(1): 17-22.',
);

final cfq11SurveyTask = RPOrderedTask(
  identifier: 'cfq11SurveyTask',
  steps: [
    cfq11InstructionStep,
    RPQuestionStep(
      identifier: 'cfq11Step1',
      title: 'Do you have problems with tiredness?',
      answerFormat: cfq11AnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'cfq11Step2',
      title: 'Do you need to rest more?',
      answerFormat: cfq11AnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'cfq11Step3',
      title: 'Do you feel sleepy or drowsy?',
      answerFormat: cfq11AnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'cfq11Step4',
      title: 'Do you have problems starting things?',
      answerFormat: cfq11AnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'cfq11Step5',
      title: 'Do you lack energy?',
      answerFormat: cfq11AnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'cfq11Step6',
      title: 'Do you have less strength in your muscles?',
      answerFormat: cfq11AnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'cfq11Step7',
      title: 'Do you feel weak?',
      answerFormat: cfq11AnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'cfq11Step8',
      title: 'Do you have difficulty concentrating?',
      answerFormat: cfq11AnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'cfq11Step9',
      title: 'Do you make slips of the tongue when speaking?',
      answerFormat: cfq11AnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'cfq11Step10',
      title: 'Do you find it more difficult to find the right word?',
      answerFormat: cfq11AnswerFormat,
    ),
    RPQuestionStep(
      identifier: 'cfq11Step11',
      title: 'How is your memory?',
      answerFormat: cfq11AnswerFormat,
    ),
    cfq11CompletionStep,
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
