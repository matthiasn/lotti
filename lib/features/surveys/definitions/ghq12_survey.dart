import 'package:research_package/model.dart';

final ghq12InstructionStep = RPInstructionStep(
  identifier: 'ghq12Instructions',
  title: 'The General Health Questionnaire (GHQ) 12',
  text:
      'The next questions are about how you have been feeling over the last few weeks.',
  footnote: 'Goldberg, D. P. (1972). General Health Questionnaire-12 (GHQ-12)',
);

final ghq12Step1 = RPQuestionStep(
  identifier: 'ghq12Step1',
  title: "Have you recently been able to concentrate on whatever you're doing?",
  answerFormat: RPChoiceAnswerFormat(
    answerStyle: RPChoiceAnswerStyle.SingleChoice,
    choices: [
      RPChoice(text: 'Better than usual', value: 0),
      RPChoice(text: 'Same as usual', value: 1),
      RPChoice(text: 'Less than usual', value: 2),
      RPChoice(text: 'Much less than usual', value: 3),
    ],
  ),
);

final ghq12Step2 = RPQuestionStep(
  identifier: 'ghq12Step2',
  title: 'Have you recently lost much sleep over worry?',
  answerFormat: RPChoiceAnswerFormat(
    answerStyle: RPChoiceAnswerStyle.SingleChoice,
    choices: [
      RPChoice(text: 'Not at all', value: 0),
      RPChoice(text: 'No more than usual', value: 1),
      RPChoice(text: 'Rather more than usual', value: 2),
      RPChoice(text: 'Much more than usual', value: 3),
    ],
  ),
);

final ghq12Step3 = RPQuestionStep(
  identifier: 'ghq12Step3',
  title:
      'Have you recently felt that you were playing a useful part in things?',
  answerFormat: RPChoiceAnswerFormat(
    answerStyle: RPChoiceAnswerStyle.SingleChoice,
    choices: [
      RPChoice(text: 'More so than usual', value: 0),
      RPChoice(text: 'Same as usual', value: 1),
      RPChoice(text: 'Less so than usual', value: 2),
      RPChoice(text: 'Much less than usual', value: 3),
    ],
  ),
);

final ghq12Step4 = RPQuestionStep(
  identifier: 'ghq12Step4',
  title: 'Have you recently felt capable of making decisions about things?',
  answerFormat: RPChoiceAnswerFormat(
    answerStyle: RPChoiceAnswerStyle.SingleChoice,
    choices: [
      RPChoice(text: 'More so than usual', value: 0),
      RPChoice(text: 'Same as usual', value: 1),
      RPChoice(text: 'Less so than usual', value: 2),
      RPChoice(text: 'Much less capable', value: 3),
    ],
  ),
);

final ghq12Step5 = RPQuestionStep(
  identifier: 'ghq12Step5',
  title: 'Have you recently felt constantly under strain?',
  answerFormat: RPChoiceAnswerFormat(
    answerStyle: RPChoiceAnswerStyle.SingleChoice,
    choices: [
      RPChoice(text: 'Not at all', value: 0),
      RPChoice(text: 'No more than usual', value: 1),
      RPChoice(text: 'Rather more than usual', value: 2),
      RPChoice(text: 'Much more than usual', value: 3),
    ],
  ),
);

final ghq12Step6 = RPQuestionStep(
  identifier: 'ghq12Step6',
  title: "Have you recently felt you couldn't overcome your difficulties?",
  answerFormat: RPChoiceAnswerFormat(
    answerStyle: RPChoiceAnswerStyle.SingleChoice,
    choices: [
      RPChoice(text: 'Not at all', value: 0),
      RPChoice(text: 'No more than usual', value: 1),
      RPChoice(text: 'Rather more than usual', value: 2),
      RPChoice(text: 'Much more than usual', value: 3),
    ],
  ),
);

final ghq12Step7 = RPQuestionStep(
  identifier: 'ghq12Step7',
  title:
      'Have you recently been able to enjoy your normal day-to-day activities?',
  answerFormat: RPChoiceAnswerFormat(
    answerStyle: RPChoiceAnswerStyle.SingleChoice,
    choices: [
      RPChoice(text: 'More so than usual', value: 0),
      RPChoice(text: 'Same as usual', value: 1),
      RPChoice(text: 'Less so than usual', value: 2),
      RPChoice(text: 'Much less than usual', value: 3),
    ],
  ),
);

final ghq12Step8 = RPQuestionStep(
  identifier: 'ghq12Step8',
  title: 'Have you recently been able to face up to problems?',
  answerFormat: RPChoiceAnswerFormat(
    answerStyle: RPChoiceAnswerStyle.SingleChoice,
    choices: [
      RPChoice(text: 'More so than usual', value: 0),
      RPChoice(text: 'Same as usual', value: 1),
      RPChoice(text: 'Less able than usual', value: 2),
      RPChoice(text: 'Much less able', value: 3),
    ],
  ),
);

final ghq12Step9 = RPQuestionStep(
  identifier: 'ghq12Step9',
  title: 'Have you recently been feeling unhappy and depressed?',
  answerFormat: RPChoiceAnswerFormat(
    answerStyle: RPChoiceAnswerStyle.SingleChoice,
    choices: [
      RPChoice(text: 'Not at all', value: 0),
      RPChoice(text: 'No more than usual', value: 1),
      RPChoice(text: 'Rather more than usual', value: 2),
      RPChoice(text: 'Much more than usual', value: 3),
    ],
  ),
);

final ghq12Step10 = RPQuestionStep(
  identifier: 'ghq12Step10',
  title: 'Have you recently been losing confidence in yourself?',
  answerFormat: RPChoiceAnswerFormat(
    answerStyle: RPChoiceAnswerStyle.SingleChoice,
    choices: [
      RPChoice(text: 'Not at all', value: 0),
      RPChoice(text: 'No more than usual', value: 1),
      RPChoice(text: 'Rather more than usual', value: 2),
      RPChoice(text: 'Much more than usual', value: 3),
    ],
  ),
);

final ghq12Step11 = RPQuestionStep(
  identifier: 'ghq12Step11',
  title: 'Have you recently been thinking of yourself as a worthless person?',
  answerFormat: RPChoiceAnswerFormat(
    answerStyle: RPChoiceAnswerStyle.SingleChoice,
    choices: [
      RPChoice(text: 'Not at all', value: 0),
      RPChoice(text: 'No more than usual', value: 1),
      RPChoice(text: 'Rather more than usual', value: 2),
      RPChoice(text: 'Much more than usual', value: 3),
    ],
  ),
);

final ghq12Step12 = RPQuestionStep(
  identifier: 'ghq12Step12',
  title:
      'Have you recently been feeling reasonably happy, all things considered?',
  answerFormat: RPChoiceAnswerFormat(
    answerStyle: RPChoiceAnswerStyle.SingleChoice,
    choices: [
      RPChoice(text: 'More so than usual', value: 0),
      RPChoice(text: 'About the same as usual', value: 1),
      RPChoice(text: 'Less so than usual', value: 2),
      RPChoice(text: 'Much less than usual', value: 3),
    ],
  ),
);

RPCompletionStep ghq12CompletionStep = RPCompletionStep(
  identifier: 'ghq12Completion',
  title: 'Finished',
  text: 'Thank you for filling out the GHQ12!',
);

RPOrderedTask ghq12SurveyTask = RPOrderedTask(
  identifier: 'ghq12SurveyTask',
  steps: [
    ghq12InstructionStep,
    ghq12Step1,
    ghq12Step2,
    ghq12Step3,
    ghq12Step4,
    ghq12Step5,
    ghq12Step6,
    ghq12Step7,
    ghq12Step8,
    ghq12Step9,
    ghq12Step10,
    ghq12Step11,
    ghq12Step12,
    ghq12CompletionStep,
  ],
);

Map<String, Set<String>> ghq12ScoreDefinitions = {
  'GHQ12': {
    ghq12Step1.identifier,
    ghq12Step2.identifier,
    ghq12Step3.identifier,
    ghq12Step4.identifier,
    ghq12Step5.identifier,
    ghq12Step6.identifier,
    ghq12Step7.identifier,
    ghq12Step8.identifier,
    ghq12Step9.identifier,
    ghq12Step10.identifier,
    ghq12Step11.identifier,
    ghq12Step12.identifier,
  },
};
