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
      description: 'Better than usual'),
  RPImageChoice(
      imageUrl: 'assets/icons/green-1.png',
      value: 1,
      description: 'No worse than usual'),
  RPImageChoice(
      imageUrl: 'assets/icons/red-2.png',
      value: 2,
      description: 'Worse than usual'),
  RPImageChoice(
      imageUrl: 'assets/icons/red-3.png',
      value: 3,
      description: 'Much worse than usual'),
];

RPImageChoiceAnswerFormat imageChoiceAnswerFormat = RPImageChoiceAnswerFormat(
  choices: cfq11Images,
);

RPCompletionStep completionStep = RPCompletionStep(
    identifier: 'completionID',
    title: 'Finished',
    text: 'Thank you for filling out the CFQ11!');

RPInstructionStep instructionStep = RPInstructionStep(
  identifier: 'cfq11Instructions',
  title: 'Welcome!',
  text: ' Chalder Fatigue Scale (CFQ 11)\n\n'
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

RPOrderedTask linearSurveyTask = RPOrderedTask(
  identifier: 'surveyTaskID',
  steps: [
    instructionStep,
    RPFormStep(
      identifier: "formstepID",
      steps: [
        RPQuestionStep(
          identifier: 'cfq11Step1',
          title: 'Do you have problems with tiredness?',
          answerFormat: imageChoiceAnswerFormat,
        ),
        RPQuestionStep(
          identifier: 'cfq11Step2',
          title: 'Do you need to rest more?',
          answerFormat: imageChoiceAnswerFormat,
        ),
        RPQuestionStep(
          identifier: 'cfq11Step3',
          title: 'Do you feel sleepy or drowsy?',
          answerFormat: imageChoiceAnswerFormat,
        ),
        RPQuestionStep(
          identifier: 'cfq11Step4',
          title: 'Do you have problems starting things?',
          answerFormat: imageChoiceAnswerFormat,
        ),
        RPQuestionStep(
          identifier: 'cfq11Step5',
          title: 'Do you lack energy?',
          answerFormat: imageChoiceAnswerFormat,
        ),
        RPQuestionStep(
          identifier: 'cfq11Step6',
          title: 'Do you have less strength in your muscles?',
          answerFormat: imageChoiceAnswerFormat,
        ),
        RPQuestionStep(
          identifier: 'cfq11Step7',
          title: 'Do you feel weak?',
          answerFormat: imageChoiceAnswerFormat,
        ),
        RPQuestionStep(
          identifier: 'cfq11Step8',
          title: 'Do you have difficulty concentrating?',
          answerFormat: imageChoiceAnswerFormat,
        ),
        RPQuestionStep(
          identifier: 'cfq11Step9',
          title: 'Do you make slips of the tongue when speaking?',
          answerFormat: imageChoiceAnswerFormat,
        ),
        RPQuestionStep(
          identifier: 'cfq11Step10',
          title: 'Do you find it more difficult to find the right word?',
          answerFormat: imageChoiceAnswerFormat,
        ),
        RPQuestionStep(
          identifier: 'cfq11Step11',
          title: 'How is your memory?',
          answerFormat: imageChoiceAnswerFormat,
        ),
      ],
      title: 'Chalder Fatigue Scale (CFQ 11)',
    ),
    completionStep
  ],
);
