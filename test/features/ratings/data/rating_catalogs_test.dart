import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/rating_question.dart';
import 'package:lotti/features/ratings/data/rating_catalogs.dart';
import 'package:lotti/l10n/app_localizations.dart';

void main() {
  final messages = lookupAppLocalizations(const Locale('en'));

  group('ratingCatalogRegistry', () {
    test('contains session catalog', () {
      expect(ratingCatalogRegistry, contains('session'));
    });

    test('session catalog factory returns questions', () {
      final questions = ratingCatalogRegistry['session']!(messages);
      expect(questions, isNotEmpty);
    });
  });

  group('sessionRatingCatalog', () {
    late List<RatingQuestion> questions;

    setUp(() {
      questions = sessionRatingCatalog(messages);
    });

    test('returns 4 questions', () {
      expect(questions, hasLength(4));
    });

    test('has correct question keys in order', () {
      final keys = questions.map((q) => q.key).toList();
      expect(keys, [
        'productivity',
        'energy',
        'focus',
        'challenge_skill',
      ]);
    });

    test('all questions have non-empty question text', () {
      for (final q in questions) {
        expect(q.question, isNotEmpty, reason: '${q.key} question is empty');
      }
    });

    test('all questions have non-empty English descriptions', () {
      for (final q in questions) {
        expect(
          q.description,
          isNotEmpty,
          reason: '${q.key} description is empty',
        );
      }
    });

    test('tapBar questions have no options', () {
      final tapBarQuestions =
          questions.where((q) => q.inputType == 'tapBar').toList();
      expect(tapBarQuestions, hasLength(3));
      for (final q in tapBarQuestions) {
        expect(q.options, isNull, reason: '${q.key} should have no options');
      }
    });

    test('productivity question has tapBar input type', () {
      final q = questions.firstWhere((q) => q.key == 'productivity');
      expect(q.inputType, equals('tapBar'));
    });

    test('energy question has tapBar input type', () {
      final q = questions.firstWhere((q) => q.key == 'energy');
      expect(q.inputType, equals('tapBar'));
    });

    test('focus question has tapBar input type', () {
      final q = questions.firstWhere((q) => q.key == 'focus');
      expect(q.inputType, equals('tapBar'));
    });

    test('challenge_skill question has segmented input type', () {
      final q = questions.firstWhere((q) => q.key == 'challenge_skill');
      expect(q.inputType, equals('segmented'));
    });

    test('challenge_skill has 3 options', () {
      final q = questions.firstWhere((q) => q.key == 'challenge_skill');
      expect(q.options, hasLength(3));
    });

    test('challenge_skill options have correct values', () {
      final q = questions.firstWhere((q) => q.key == 'challenge_skill');
      final values = q.options!.map((o) => o.value).toList();
      expect(values, [0.0, 0.5, 1.0]);
    });

    test('challenge_skill options have non-empty labels', () {
      final q = questions.firstWhere((q) => q.key == 'challenge_skill');
      for (final option in q.options!) {
        expect(
          option.label,
          isNotEmpty,
          reason: 'option with value ${option.value} has empty label',
        );
      }
    });

    test('all keys are unique', () {
      final keys = questions.map((q) => q.key).toSet();
      expect(keys, hasLength(questions.length));
    });

    test('descriptions contain scale information', () {
      for (final q in questions) {
        expect(
          q.description,
          contains('0.0'),
          reason: '${q.key} description should reference 0.0 scale endpoint',
        );
        expect(
          q.description,
          contains('1.0'),
          reason: '${q.key} description should reference 1.0 scale endpoint',
        );
      }
    });
  });

  group('RatingQuestion localization', () {
    test('German locale returns different question text', () {
      final deMessages = lookupAppLocalizations(const Locale('de'));
      final enQuestions = sessionRatingCatalog(messages);
      final deQuestions = sessionRatingCatalog(deMessages);

      // Questions should differ between locales
      expect(
        deQuestions.first.question,
        isNot(equals(enQuestions.first.question)),
      );

      // But keys and descriptions stay the same
      expect(deQuestions.first.key, equals(enQuestions.first.key));
      expect(
        deQuestions.first.description,
        equals(enQuestions.first.description),
      );
    });

    test('descriptions are always English regardless of locale', () {
      final deMessages = lookupAppLocalizations(const Locale('de'));
      final deQuestions = sessionRatingCatalog(deMessages);

      for (final q in deQuestions) {
        // English descriptions should not change with locale
        expect(
          q.description.contains(RegExp('[A-Z]')),
          isTrue,
          reason: '${q.key} description should be English',
        );
      }
    });
  });
}
