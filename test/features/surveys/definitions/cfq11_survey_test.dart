import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/surveys/definitions/cfq11_survey.dart';
import 'package:research_package/model.dart';

List<RPQuestionStep> _questionSteps(RPOrderedTask task) =>
    task.steps.whereType<RPQuestionStep>().toList();

List<int> _choiceValues(RPQuestionStep step) =>
    (step.answerFormat as RPChoiceAnswerFormat).choices
        .map((choice) => choice.value)
        .toList();

void main() {
  group('cfq11 survey definition', () {
    test('answer format offers a 0..3 single-choice scale', () {
      expect(cfq11AnswerFormat.answerStyle, RPChoiceAnswerStyle.SingleChoice);
      expect(
        cfq11AnswerFormat.choices.map((c) => c.value),
        [0, 1, 2, 3],
      );
    });

    test('task is bracketed by instruction and completion steps', () {
      expect(cfq11SurveyTask.identifier, 'cfq11SurveyTask');
      expect(cfq11SurveyTask.steps.first, isA<RPInstructionStep>());
      expect(cfq11SurveyTask.steps.last, isA<RPCompletionStep>());
      expect(cfq11SurveyTask.steps.last.identifier, 'cfq11Completion');
    });

    test('contains exactly 11 question steps using the shared scale', () {
      final questions = _questionSteps(cfq11SurveyTask);
      expect(questions, hasLength(11));
      for (final question in questions) {
        expect(_choiceValues(question), [0, 1, 2, 3]);
        expect(question.title, isNotEmpty);
      }
    });

    test('question identifiers are cfq11Step1..cfq11Step11', () {
      final ids = _questionSteps(cfq11SurveyTask).map((q) => q.identifier);
      expect(ids, [for (var i = 1; i <= 11; i++) 'cfq11Step$i']);
    });

    test('score definition covers every question step exactly once', () {
      expect(cfq11ScoreDefinitions.keys, ['CFQ11']);
      final questionIds = _questionSteps(
        cfq11SurveyTask,
      ).map((q) => q.identifier).toSet();
      expect(cfq11ScoreDefinitions['CFQ11'], questionIds);
    });
  });
}
