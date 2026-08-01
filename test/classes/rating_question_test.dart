import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
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

    glados.Glados(
      glados.any.generatedRatingQuestionOption,
      glados.ExploreConfig(numRuns: 60),
    ).test('round-trips generated options through JSON', (scenario) {
      final option = scenario.option;

      final decoded = RatingQuestionOption.fromJson(
        jsonDecode(jsonEncode(option.toJson())) as Map<String, dynamic>,
      );

      expect(decoded, equals(option), reason: '$scenario');
      expect(decoded.value, option.value, reason: '$scenario');
    }, tags: 'glados');
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

class _GeneratedRatingQuestionOption {
  const _GeneratedRatingQuestionOption({
    required this.label,
    required this.valueSlot,
  });

  final String label;
  final int valueSlot;

  RatingQuestionOption get option => RatingQuestionOption(
    label: label,
    value: valueSlot / 100,
  );

  @override
  String toString() {
    return '_GeneratedRatingQuestionOption('
        'label: "$label", valueSlot: $valueSlot)';
  }
}

extension _AnyRatingQuestion on glados.Any {
  glados.Generator<String> get _ratingQuestionText =>
      glados.AnyUtils(this).choose(const [
        '',
        'productivity',
        'How productive?',
        'Text with "quotes"',
        r'Text with \ slash',
        'Line\nbreak',
      ]);

  glados.Generator<_GeneratedRatingQuestionOption>
  get generatedRatingQuestionOption => glados.CombinableAny(this).combine2(
    _ratingQuestionText,
    glados.IntAnys(this).intInRange(0, 100),
    (
      String label,
      int valueSlot,
    ) => _GeneratedRatingQuestionOption(
      label: label,
      valueSlot: valueSlot,
    ),
  );
}
