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

    glados.Glados(
      glados.any.generatedRatingQuestion,
      glados.ExploreConfig(numRuns: 160),
    ).test('round-trips generated questions through JSON', (scenario) {
      final question = scenario.questionModel;

      final decoded = RatingQuestion.fromJson(
        jsonDecode(jsonEncode(question.toJson())) as Map<String, dynamic>,
      );

      expect(decoded, equals(question), reason: '$scenario');
      expect(
        decoded.inputType,
        scenario.expectedInputType,
        reason: '$scenario',
      );
      expect(decoded.options, question.options, reason: '$scenario');
    }, tags: 'glados');
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

class _GeneratedRatingQuestion {
  const _GeneratedRatingQuestion({
    required this.key,
    required this.question,
    required this.description,
    required this.inputTypeSlot,
    required this.options,
  });

  final String key;
  final String question;
  final String description;
  final int inputTypeSlot;
  final List<_GeneratedRatingQuestionOption> options;

  String? get inputType => switch (inputTypeSlot % 5) {
    0 => null,
    1 => 'tapBar',
    2 => 'segmented',
    3 => 'boolean',
    _ => 'future-input',
  };

  String get expectedInputType => inputType ?? 'tapBar';

  RatingQuestion get questionModel {
    final generatedOptions = options.isEmpty
        ? null
        : options.map((option) => option.option).toList();

    final inputType = this.inputType;
    if (inputType == null) {
      return RatingQuestion(
        key: key,
        question: question,
        description: description,
        options: generatedOptions,
      );
    }

    return RatingQuestion(
      key: key,
      question: question,
      description: description,
      inputType: inputType,
      options: generatedOptions,
    );
  }

  @override
  String toString() {
    return '_GeneratedRatingQuestion('
        'key: "$key", '
        'question: "$question", '
        'description: "$description", '
        'inputTypeSlot: $inputTypeSlot, '
        'options: $options)';
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

  glados.Generator<_GeneratedRatingQuestion> get generatedRatingQuestion =>
      glados.CombinableAny(this).combine5(
        _ratingQuestionText,
        _ratingQuestionText,
        _ratingQuestionText,
        glados.IntAnys(this).intInRange(0, 20),
        glados.ListAnys(this).listWithLengthInRange(
          0,
          4,
          generatedRatingQuestionOption,
        ),
        (
          String key,
          String question,
          String description,
          int inputTypeSlot,
          List<_GeneratedRatingQuestionOption> options,
        ) => _GeneratedRatingQuestion(
          key: key,
          question: question,
          description: description,
          inputTypeSlot: inputTypeSlot,
          options: options,
        ),
      );
}
