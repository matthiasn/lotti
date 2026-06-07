import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/surveys/definitions/ghq12_survey.dart';
import 'package:research_package/model.dart';

List<RPQuestionStep> _questionSteps(RPOrderedTask task) =>
    task.steps.whereType<RPQuestionStep>().toList();

List<int> _choiceValues(RPQuestionStep step) =>
    (step.answerFormat as RPChoiceAnswerFormat).choices
        .map((choice) => choice.value)
        .toList();

List<String> _choiceLabels(RPQuestionStep step) =>
    (step.answerFormat as RPChoiceAnswerFormat).choices
        .map((choice) => choice.text)
        .toList();

void main() {
  group('ghq12 survey definition', () {
    test('task is bracketed by instruction and completion steps', () {
      expect(ghq12SurveyTask.identifier, 'ghq12SurveyTask');
      expect(ghq12SurveyTask.steps.first, isA<RPInstructionStep>());
      expect(ghq12SurveyTask.steps.last, isA<RPCompletionStep>());
      expect(ghq12SurveyTask.steps.last.identifier, 'ghq12Completion');
    });

    test('contains exactly 12 question steps on a 0..3 scale', () {
      final questions = _questionSteps(ghq12SurveyTask);
      expect(questions, hasLength(12));
      for (final question in questions) {
        // Each GHQ-12 item defines its own labels but always scores 0..3.
        expect(_choiceValues(question), [0, 1, 2, 3]);
        expect(question.title, isNotEmpty);

        // Every choice carries a distinct, non-empty label: GHQ-12 items reuse
        // the 0..3 scale but each phrases its four options differently, so a
        // copy/paste slip that blanks or duplicates a label would be a real
        // defect.
        final labels = _choiceLabels(question);
        expect(labels, everyElement(isNotEmpty));
        expect(labels.toSet(), hasLength(4));
      }
    });

    test('question identifiers are ghq12Step1..ghq12Step12', () {
      final ids = _questionSteps(ghq12SurveyTask).map((q) => q.identifier);
      expect(ids, [for (var i = 1; i <= 12; i++) 'ghq12Step$i']);
    });

    test('score definition covers every question step exactly once', () {
      expect(ghq12ScoreDefinitions.keys, ['GHQ12']);
      final questionIds = _questionSteps(
        ghq12SurveyTask,
      ).map((q) => q.identifier).toSet();
      expect(ghq12ScoreDefinitions['GHQ12'], questionIds);
    });
  });
}
