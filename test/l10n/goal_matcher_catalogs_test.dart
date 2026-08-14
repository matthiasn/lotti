import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/l10n/app_localizations.dart';

/// Guards the two word lists the goal matcher parses out of the catalogs:
/// `goalFormMeasurementVerbs` and `goalFormGenericIntentionWords`
/// (`_catalogWords` in
/// `lib/features/goals/ui/pages/create_goal_agent_page.dart`).
///
/// They are the only ARB entries that are not shown to anyone — they are
/// data the matcher runs on — so a translator has no way to see that
/// dropping the key, translating the commas into a sentence, or shipping a
/// multi-word entry has silently disabled habit matching for that language.
/// Nothing else in the suite would catch it either.
void main() {
  // Every shipped list is a couple of dozen inflections deep; the shortest
  // today is 18 entries. Twelve is comfortably below that while still
  // failing a stub, a truncation, or commas translated away into prose
  // (which collapses the whole value into a single "entry").
  const minimumEntries = 12;

  // What `_words` can produce from user text: it replaces every
  // non-letter/digit run with a space and splits on whitespace, so an entry
  // carrying a space, a hyphen or an apostrophe can never match anything and
  // is dead weight in the list.
  final singleToken = RegExp(r'^[\p{L}\p{N}]+$', unicode: true);

  final english = lookupAppLocalizations(const Locale('en'));

  for (final locale in AppLocalizations.supportedLocales) {
    final messages = lookupAppLocalizations(locale);
    final catalogs = <String, String>{
      'goalFormMeasurementVerbs': messages.goalFormMeasurementVerbs,
      'goalFormGenericIntentionWords': messages.goalFormGenericIntentionWords,
    };
    final englishCatalogs = <String, String>{
      'goalFormMeasurementVerbs': english.goalFormMeasurementVerbs,
      'goalFormGenericIntentionWords': english.goalFormGenericIntentionWords,
    };

    group('goal matcher catalogs (${locale.toLanguageTag()})', () {
      for (final entry in catalogs.entries) {
        final key = entry.key;
        final value = entry.value;

        test('$key is a usable comma-separated word list', () {
          expect(value.trim(), isNotEmpty, reason: '$key is empty in $locale');

          final words = value.split(',');
          expect(
            words.length,
            greaterThanOrEqualTo(minimumEntries),
            reason:
                '$key in $locale parses to ${words.length} entries — the '
                'commas were probably translated away or the list truncated',
          );

          for (final word in words) {
            expect(
              word.trim(),
              isNotEmpty,
              reason: '$key in $locale has an empty entry (a stray comma)',
            );
            expect(
              word,
              word.trim(),
              reason:
                  '$key in $locale pads "$word" with whitespace; keep the '
                  'list canonical so a diff shows real changes',
            );
            expect(
              word,
              matches(singleToken),
              reason:
                  '$key in $locale contains "$word", which is not a single '
                  'word — the matcher tokenises user text on whitespace and '
                  'punctuation, so this entry can never match',
            );
          }
        });

        // A key missing from a translated ARB is filled from the English
        // template, which reads as a healthy list while matching nothing a
        // user of that language ever writes.
        if (locale.languageCode != 'en') {
          test('$key is translated rather than the English fallback', () {
            expect(
              value,
              isNot(englishCatalogs[key]),
              reason:
                  '$key in $locale is verbatim English — the key was likely '
                  'dropped from app_${locale.languageCode}.arb',
            );
          });
        }
      }
    });
  }

  // Deliberately not asserted: that entries are lowercase. `_catalogWords`
  // lowercases the whole value before splitting, and the user's text is
  // lowercased too, so an uppercase entry matches exactly as well — pinning
  // the case would test the ARB's typography, not the matcher's behaviour.
}
