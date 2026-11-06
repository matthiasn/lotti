import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/supported_language.dart';
import 'package:lotti/features/goals/logic/goal_briefing_language.dart';

void main() {
  group('resolveGoalBriefingLanguage', () {
    test('a language picked for the goal stands over its journal', () {
      final resolved = resolveGoalBriefingLanguage(chosen: 'fr', journal: 'de');

      expect(resolved.language, SupportedLanguage.fr);
      expect(resolved.source, GoalBriefingLanguageSource.chosen);
      expect(resolved.factsLine, 'fr (French)');
    });

    test('with nothing picked the goal follows its journal', () {
      final resolved = resolveGoalBriefingLanguage(chosen: null, journal: 'de');

      expect(resolved.language, SupportedLanguage.de);
      expect(resolved.source, GoalBriefingLanguageSource.journal);
      expect(resolved.factsLine, 'de (German)');
    });

    test("with neither, FACTS say to follow the user's own words — the "
        'behaviour every goal had before a language could be set', () {
      final resolved = resolveGoalBriefingLanguage(chosen: null, journal: null);

      expect(resolved.language, isNull);
      expect(resolved.source, GoalBriefingLanguageSource.unset);
      expect(resolved.factsLine, goalUnsetLanguageFactsLine);
      expect(resolved.factsLine, contains('userVoice'));
      expect(resolved.factsLine, contains('English when there are none'));
    });

    test('a blank or unsupported pick reads as not set, so the journal '
        'decides instead of a bare code reaching the model', () {
      for (final chosen in ['', '  ', 'xx', 'klingon']) {
        final resolved = resolveGoalBriefingLanguage(
          chosen: chosen,
          journal: 'sv',
        );
        expect(
          resolved.source,
          GoalBriefingLanguageSource.journal,
          reason: chosen,
        );
        expect(resolved.language, SupportedLanguage.sv, reason: chosen);
      }
      expect(
        resolveGoalBriefingLanguage(chosen: 'xx', journal: 'yy').source,
        GoalBriefingLanguageSource.unset,
      );
    });

    test('codes are matched case- and whitespace-insensitively', () {
      expect(
        resolveGoalBriefingLanguage(chosen: ' DE ', journal: null).language,
        SupportedLanguage.de,
      );
    });

    test('two resolutions of the same language and source are equal', () {
      expect(
        resolveGoalBriefingLanguage(chosen: 'de', journal: null),
        resolveGoalBriefingLanguage(chosen: 'de', journal: 'fr'),
      );
      expect(
        resolveGoalBriefingLanguage(chosen: 'de', journal: null),
        isNot(resolveGoalBriefingLanguage(chosen: null, journal: 'de')),
      );
      expect(
        resolveGoalBriefingLanguage(chosen: 'de', journal: null).hashCode,
        resolveGoalBriefingLanguage(chosen: 'de', journal: 'it').hashCode,
      );
    });
  });

  group('goalBriefingLanguageSuggestion', () {
    test('suggests the journal language once it has moved away from the '
        'language picked by hand', () {
      expect(
        goalBriefingLanguageSuggestion(chosen: 'en', journal: 'de'),
        SupportedLanguage.de,
      );
    });

    test('suggests nothing while the pick and the journal agree', () {
      expect(
        goalBriefingLanguageSuggestion(chosen: 'de', journal: 'de'),
        isNull,
      );
    });

    test('a goal that follows its journal needs no suggestion: it already '
        'changes with it', () {
      expect(
        goalBriefingLanguageSuggestion(chosen: null, journal: 'de'),
        isNull,
      );
    });

    test('a journal without a language suggests nothing', () {
      expect(
        goalBriefingLanguageSuggestion(chosen: 'en', journal: null),
        isNull,
      );
      expect(
        goalBriefingLanguageSuggestion(chosen: 'en', journal: 'xx'),
        isNull,
      );
    });
  });

  test('goalSupportedLanguage resolves supported codes only', () {
    expect(goalSupportedLanguage('pt'), SupportedLanguage.pt);
    expect(goalSupportedLanguage(null), isNull);
    expect(goalSupportedLanguage(''), isNull);
    expect(goalSupportedLanguage('zz'), isNull);
  });
}
