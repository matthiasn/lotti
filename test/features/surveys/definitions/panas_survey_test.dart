import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/surveys/definitions/panas_survey.dart';
import 'package:research_package/model.dart';

List<RPQuestionStep> _questionSteps(RPOrderedTask task) =>
    task.steps.whereType<RPQuestionStep>().toList();

void main() {
  group('panas survey definition', () {
    test('answer format offers a 1..5 single-choice scale', () {
      expect(panasAnswerFormat.answerStyle, RPChoiceAnswerStyle.SingleChoice);
      expect(
        panasAnswerFormat.choices.map((c) => c.value),
        [1, 2, 3, 4, 5],
      );
    });

    test('task is bracketed by instruction and completion steps', () {
      expect(panasSurveyTask.identifier, 'panasSurveyTask');
      expect(panasSurveyTask.steps.first, isA<RPInstructionStep>());
      expect(panasSurveyTask.steps.last, isA<RPCompletionStep>());
      expect(panasSurveyTask.steps.last.identifier, 'panasCompletion');
    });

    test('contains exactly 20 question steps using the shared scale', () {
      final questions = _questionSteps(panasSurveyTask);
      expect(questions, hasLength(20));
      for (final question in questions) {
        expect(question.answerFormat, same(panasAnswerFormat));
        expect(question.title, isNotEmpty);
      }
    });

    test('question identifiers are panasQuestion1..panasQuestion20', () {
      final ids = _questionSteps(panasSurveyTask).map((q) => q.identifier);
      expect(ids, [for (var i = 1; i <= 20; i++) 'panasQuestion$i']);
    });

    test('positive and negative affect scores partition all 20 questions', () {
      final positive = panasScoreDefinitions['Positive Affect Score']!;
      final negative = panasScoreDefinitions['Negative Affect Score']!;

      expect(panasScoreDefinitions.keys, [
        'Positive Affect Score',
        'Negative Affect Score',
      ]);
      expect(positive, hasLength(10));
      expect(negative, hasLength(10));
      // Disjoint groups.
      expect(positive.intersection(negative), isEmpty);
      // Together they reference exactly the survey's question steps.
      final questionIds = _questionSteps(
        panasSurveyTask,
      ).map((q) => q.identifier).toSet();
      expect(positive.union(negative), questionIds);
    });
  });
}
