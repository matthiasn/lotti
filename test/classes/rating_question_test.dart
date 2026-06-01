import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/rating_question.dart';

void main() {
  group('RatingQuestionOption', () {
    test('JSON round-trip preserves all fields', () {
      const option = RatingQuestionOption(label: 'Good', value: 0.75);
      final decoded = RatingQuestionOption.fromJson(
        jsonDecode(jsonEncode(option.toJson())) as Map<String, dynamic>,
      );

      expect(decoded.label, 'Good');
      expect(decoded.value, 0.75);
      expect(decoded, option);
    });

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

    test('JSON round-trip without options', () {
      const q = RatingQuestion(
        key: 'energy',
        question: 'Energy level?',
        description: 'Low to high energy.',
        // ignore: avoid_redundant_argument_values
        inputType: 'tapBar',
      );

      final decoded = RatingQuestion.fromJson(
        jsonDecode(jsonEncode(q.toJson())) as Map<String, dynamic>,
      );

      expect(decoded.key, 'energy');
      expect(decoded.question, 'Energy level?');
      expect(decoded.description, 'Low to high energy.');
      expect(decoded.inputType, 'tapBar');
      expect(decoded.options, isNull);
      expect(decoded, q);
    });

    test('JSON round-trip with segmented options preserves nested list', () {
      const q = RatingQuestion(
        key: 'challenge',
        question: 'Difficulty?',
        description: 'Challenge-skill balance.',
        inputType: 'segmented',
        options: [
          RatingQuestionOption(label: 'Easy', value: 0),
          RatingQuestionOption(label: 'Medium', value: 0.5),
          RatingQuestionOption(label: 'Hard', value: 1),
        ],
      );

      final decoded = RatingQuestion.fromJson(
        jsonDecode(jsonEncode(q.toJson())) as Map<String, dynamic>,
      );

      expect(decoded.key, 'challenge');
      expect(decoded.inputType, 'segmented');
      expect(decoded.options, hasLength(3));
      expect(decoded.options![0].label, 'Easy');
      expect(decoded.options![1].value, 0.5);
      expect(decoded.options![2].label, 'Hard');
      expect(decoded, q);
    });

    test('boolean inputType round-trips correctly', () {
      const q = RatingQuestion(
        key: 'completed',
        question: 'Did you complete it?',
        description: 'Yes or no.',
        inputType: 'boolean',
      );

      final decoded = RatingQuestion.fromJson(
        jsonDecode(jsonEncode(q.toJson())) as Map<String, dynamic>,
      );

      expect(decoded.inputType, 'boolean');
      expect(decoded, q);
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

    test('equality detects changes in key, question, or description', () {
      const base = RatingQuestion(
        key: 'k',
        question: 'q',
        description: 'd',
      );

      expect(base, isNot(base.copyWith(key: 'k2')));
      expect(base, isNot(base.copyWith(question: 'q2')));
      expect(base, isNot(base.copyWith(description: 'd2')));
    });
  });
}
