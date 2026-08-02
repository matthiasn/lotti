import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/rating_question.dart';

void main() {
  group('RatingQuestionOption', () {
    test('equality distinguishes label and value', () {
      const a = RatingQuestionOption(label: 'Yes', value: 1);
      const b = RatingQuestionOption(label: 'Yes', value: 1);
      const c = RatingQuestionOption(label: 'No', value: 0);

      expect(a, b);
      expect(a, isNot(c));
    });
  });

  group('RatingQuestion', () {
    test('defaults inputType to tapBar', () {
      const q = RatingQuestion(
        key: 'productivity',
        question: 'How productive?',
        description: 'Measures productivity.',
      );

      expect(q.inputType, 'tapBar');
      expect(q.options, isNull);
    });

    test('copyWith updates individual fields without touching others', () {
      const q = RatingQuestion(
        key: 'productivity',
        question: 'Productive?',
        description: 'Desc',
      );

      final updated = q.copyWith(question: 'Updated?');

      expect(updated.key, 'productivity');
      expect(updated.question, 'Updated?');
      expect(updated.description, 'Desc');
      expect(updated.inputType, 'tapBar');
    });

    test('copyWith can clear the options list back to null', () {
      const q = RatingQuestion(
        key: 'challenge',
        question: 'Difficulty?',
        description: 'Challenge-skill balance.',
        inputType: 'segmented',
        options: [
          RatingQuestionOption(label: 'Easy', value: 0),
          RatingQuestionOption(label: 'Hard', value: 1),
        ],
      );

      final cleared = q.copyWith(options: null);

      expect(cleared.options, isNull);
      // Clearing options must leave every other field untouched.
      expect(cleared.key, 'challenge');
      expect(cleared.question, 'Difficulty?');
      expect(cleared.description, 'Challenge-skill balance.');
      expect(cleared.inputType, 'segmented');
      expect(cleared, isNot(equals(q)));
    });

    test('equality detects changes in key, question, or description', () {
      const base = RatingQuestion(key: 'k', question: 'q', description: 'd');

      expect(base, isNot(base.copyWith(key: 'k2')));
      expect(base, isNot(base.copyWith(question: 'q2')));
      expect(base, isNot(base.copyWith(description: 'd2')));
    });
  });
}
