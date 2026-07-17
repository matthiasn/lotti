import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/surveys/definitions/panas_survey.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:research_package/model.dart';

List<RPQuestionStep> _questionSteps(RPOrderedTask task) =>
    task.steps.whereType<RPQuestionStep>().toList();

Future<AppLocalizations> _messages(String languageCode) =>
    AppLocalizations.delegate.load(Locale(languageCode));

void main() {
  group('panas survey definition', () {
    test('answer format offers a 1..5 single-choice scale', () async {
      final answerFormat = createPanasAnswerFormat(await _messages('en'));

      expect(answerFormat.answerStyle, RPChoiceAnswerStyle.SingleChoice);
      expect(
        answerFormat.choices.map((choice) => choice.value),
        [1, 2, 3, 4, 5],
      );
    });

    test('task is bracketed by instruction and completion steps', () async {
      final task = createPanasSurveyTask(await _messages('en'));

      expect(task.identifier, 'panasSurveyTask');
      expect(task.steps.first, isA<RPInstructionStep>());
      expect(task.steps.last, isA<RPCompletionStep>());
      expect(task.steps.last.identifier, 'panasCompletion');
    });

    test('contains exactly 20 question steps using the shared scale', () async {
      final task = createPanasSurveyTask(await _messages('en'));
      final questions = _questionSteps(task);

      expect(questions, hasLength(20));
      for (final question in questions) {
        expect(question.answerFormat, same(questions.first.answerFormat));
        expect(question.title, isNotEmpty);
      }
    });

    test('question identifiers are panasQuestion1..panasQuestion20', () async {
      final ids = _questionSteps(
        createPanasSurveyTask(await _messages('en')),
      ).map((question) => question.identifier);

      expect(ids, [for (var i = 1; i <= 20; i++) 'panasQuestion$i']);
    });

    test(
      'positive and negative affect scores partition all 20 questions',
      () async {
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
          createPanasSurveyTask(await _messages('en')),
        ).map((q) => q.identifier).toSet();
        expect(positive.union(negative), questionIds);
      },
    );

    for (final localeCase in [
      (
        languageCode: 'cs',
        instruction: 'Uveď, do jaké míry se takto cítíš právě teď',
        firstEmotion: 'Zaujatý',
        strongestChoice: 'Extrémně',
        completion: 'Děkujeme za vyplnění dotazníku PANAS!',
      ),
      (
        languageCode: 'de',
        instruction: 'Gib an, wie stark du dich genau jetzt',
        firstEmotion: 'Interessiert',
        strongestChoice: 'Extrem',
        completion: 'Danke, dass du PANAS ausgefüllt hast!',
      ),
    ]) {
      test(
        '${localeCase.languageCode} localizes visible PANAS instructions, questions, and choices',
        () async {
          final task = createPanasSurveyTask(
            await _messages(localeCase.languageCode),
          );
          final instruction = task.steps.first as RPInstructionStep;
          final firstQuestion = _questionSteps(task).first;
          final answerFormat =
              firstQuestion.answerFormat as RPChoiceAnswerFormat;
          final completion = task.steps.last as RPCompletionStep;

          expect(instruction.text, contains(localeCase.instruction));
          expect(firstQuestion.title, localeCase.firstEmotion);
          expect(answerFormat.choices.last.text, localeCase.strongestChoice);
          expect(completion.text, localeCase.completion);
        },
      );
    }
  });
}
