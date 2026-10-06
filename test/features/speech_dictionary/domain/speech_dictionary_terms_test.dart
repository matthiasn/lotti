import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/speech_dictionary/domain/speech_dictionary_terms.dart';

SpeechDictionaryEntry _entry(
  String term, {
  List<String>? categoryIds,
  DateTime? deletedAt,
}) => SpeechDictionaryEntry(
  id: speechDictionaryEntryId(term),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  term: term,
  vectorClock: null,
  categoryIds: categoryIds,
  deletedAt: deletedAt,
);

void main() {
  group('speechDictionaryEntryId', () {
    test('is the same for spellings that differ in case and spacing', () {
      expect(
        speechDictionaryEntryId('  Claude   Code '),
        speechDictionaryEntryId('claude code'),
      );
    });

    test('differs for different terms', () {
      expect(
        speechDictionaryEntryId('Kubernetes'),
        isNot(speechDictionaryEntryId('Cuban Eddies')),
      );
    });

    glados.Glados2<String, int>(
      glados.any.letterOrDigits,
      glados.any.intInRange(0, 4),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'is stable under recasing and padding, so two devices adding the same '
      'term write one entry',
      (word, padding) {
        final padded = '${' ' * padding}${word.toUpperCase()}${' ' * padding}';
        expect(
          speechDictionaryEntryId(padded),
          speechDictionaryEntryId(word.toLowerCase()),
        );
      },
      tags: 'glados',
    );
  });

  group('parseSpeechTerms / formatSpeechTerms', () {
    test('splits on semicolons, trims and drops blanks', () {
      expect(parseSpeechTerms(' macOS ;; Claude Code; '), [
        'macOS',
        'Claude Code',
      ]);
    });

    test('cuts each term to the length limit', () {
      final long = 'x' * (kMaxTermLength + 7);
      expect(parseSpeechTerms(long).single.length, kMaxTermLength);
    });

    test('round-trips through formatting', () {
      const terms = ['Cuban Eddies', 'Cooper Netties'];
      expect(parseSpeechTerms(formatSpeechTerms(terms)), terms);
      expect(formatSpeechTerms(null), '');
    });
  });

  group('scope', () {
    final everywhere = _entry('Lotti');
    final workOnly = _entry('Kubernetes', categoryIds: ['work']);
    final deleted = _entry('Lottie', deletedAt: DateTime(2026, 2));

    test('an entry with no categories applies to every category', () {
      expect(everywhere.appliesToAllCategories, isTrue);
      expect(everywhere.appliesTo('work'), isTrue);
      expect(everywhere.appliesTo(null), isTrue);
      expect(
        _entry('x', categoryIds: const []).appliesToAllCategories,
        isTrue,
      );
    });

    test('a limited entry reaches only its categories', () {
      expect(workOnly.appliesTo('work'), isTrue);
      expect(workOnly.appliesTo('home'), isFalse);
      // A recording without a category gets only the global terms.
      expect(workOnly.appliesTo(null), isFalse);
    });

    test('a deleted entry reaches nothing', () {
      expect(deleted.appliesTo('work'), isFalse);
    });

    test('entriesForCategory keeps the reaching entries in order', () {
      expect(
        entriesForCategory([everywhere, workOnly, deleted], 'home'),
        [everywhere],
      );
      expect(
        entriesForCategory([everywhere, workOnly, deleted], 'work'),
        [everywhere, workOnly],
      );
    });
  });

  group('mergeMisheardForms', () {
    test('appends new forms, skipping blanks, the term and repeats', () {
      expect(
        mergeMisheardForms(
          ['Cuban Eddies'],
          ['', ' cuban eddies ', 'Kubernetes', 'Cooper Netties'],
          term: 'Kubernetes',
        ),
        ['Cuban Eddies', 'Cooper Netties'],
      );
    });

    test('keeps the newest forms when over the cap', () {
      final existing = [for (var i = 0; i < kMaxMisheardForms; i++) 'old$i'];
      final merged = mergeMisheardForms(existing, ['new'], term: 'Term')!;

      expect(merged.length, kMaxMisheardForms);
      expect(merged.first, 'old1');
      expect(merged.last, 'new');
    });

    test('is null when nothing remains', () {
      expect(mergeMisheardForms(null, [' ', 'Term'], term: 'term'), isNull);
    });
  });
}
