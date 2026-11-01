import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/link_suggestions/prior_work_cues.dart';
import 'package:lotti/features/ai/link_suggestions/prior_work_mention.dart';

/// The app's languages: every catalog in `lib/l10n/`, regional variants
/// folded into their language.
const _appLanguages = {
  'cs',
  'da',
  'de',
  'en',
  'es',
  'fr',
  'it',
  'nl',
  'pt',
  'ro',
  'sv',
};

void main() {
  test('every relationship has cues in every app language', () {
    for (final set in priorWorkCueSets) {
      expect(
        set.phrasesByLanguage.keys.toSet(),
        _appLanguages,
        reason: set.relation.wireName,
      );
      for (final MapEntry(key: language, value: phrases)
          in set.phrasesByLanguage.entries) {
        expect(phrases, isNotEmpty, reason: '$language ${set.relation}');
      }
    }
  });

  test('each phrase is read as its own relationship, never shadowed by '
      "another set's phrase", () {
    for (final set in priorWorkCueSets) {
      for (final phrase in set.phrases) {
        final mentions = detectPriorWorkMentions(
          'qxz $phrase qkw zzx.',
          sourceId: 'entry',
        );

        expect(mentions, hasLength(1), reason: phrase);
        expect(
          mentions.single.relation,
          set.relation,
          reason: '"$phrase" should read as ${set.relation.wireName}',
        );
        expect(mentions.single.query, 'qxz qkw zzx', reason: phrase);
      }
    }
  });

  test('no phrase is listed under two relationships', () {
    final owner = <String, String>{};
    for (final set in priorWorkCueSets) {
      for (final phrase in set.phrases) {
        final key = phrase.toLowerCase();
        final previous = owner[key];
        expect(
          previous == null || previous == set.relation.wireName,
          isTrue,
          reason: '"$phrase" is under $previous and ${set.relation.wireName}',
        );
        owner[key] = set.relation.wireName;
      }
    }
  });

  test('the plain relationship is tried last', () {
    expect(priorWorkCueSets.last, relatesToCues);
    expect(
      priorWorkCueSets.where((set) => set.relation.isSymmetric),
      [relatesToCues],
    );
  });
}
