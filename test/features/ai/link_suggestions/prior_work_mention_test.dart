import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' show ExploreConfig, Glados3, any;
// The generator extensions (`intInRange`, `list`, `nonEmptyStringOf`).
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/directed_relation.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/features/ai/link_suggestions/prior_work_cues.dart';
import 'package:lotti/features/ai/link_suggestions/prior_work_mention.dart';

const _plain = DirectedRelation(EntryLinkType.basic);
const _blockedBy = DirectedRelation(EntryLinkType.blocks, inverse: true);
const _blocks = DirectedRelation(EntryLinkType.blocks);
const _followsUp = DirectedRelation(EntryLinkType.followsUp);

PriorWorkMention _single(String text) {
  final mentions = detectPriorWorkMentions(text, sourceId: 'entry');
  expect(mentions, hasLength(1), reason: 'in "$text"');
  return mentions.single;
}

/// Every phrase of every cue set, with its relation.
final List<({String phrase, DirectedRelation relation})> _allPhrases = [
  for (final set in priorWorkCueSets)
    for (final phrase in set.phrases) (phrase: phrase, relation: set.relation),
];

/// Up to six filler words of up to ten letters, built from consonants only so
/// they can never spell a cue — short enough that no sentence reaches
/// [kMaxMentionSentenceLength], which has its own test.
final glados.Generator<List<String>> _filler = any
    .list(any.nonEmptyStringOf('qxzkw'))
    .map(
      (words) => [
        for (final word in words.take(6))
          if (word.length > 10) word.substring(0, 10) else word,
      ],
    );

void main() {
  group('detectPriorWorkMentions', () {
    test('reads the relationship each kind of cue names', () {
      final cases = {
        'Blocked by the payment gateway migration.': _blockedBy,
        'This is a prerequisite for the colony census export.': _blocks,
        'Duplicate of the sled maintenance checklist.': const DirectedRelation(
          EntryLinkType.duplicates,
        ),
        'Bugfix for the fish counter overflow.': const DirectedRelation(
          EntryLinkType.fixes,
        ),
        'Supersedes the hand-written roster sheet.': const DirectedRelation(
          EntryLinkType.supersedes,
        ),
        'Follow-up to the iceberg drift survey.': _followsUp,
        'We tried the heater swap last week already.': _plain,
      };
      for (final MapEntry(key: text, value: relation) in cases.entries) {
        expect(_single(text).relation, relation, reason: text);
      }
    });

    test('searches for the sentence without its cue', () {
      final mention = _single('Follow-up to the iceberg drift survey!');

      expect(mention.query, 'the iceberg drift survey');
      expect(mention.sentence, 'Follow-up to the iceberg drift survey!');
      expect(mention.sourceId, 'entry');
    });

    test('a space and a hyphen in a phrase match each other', () {
      expect(_single('follow up to the drift survey').relation, _followsUp);
      expect(_single('pré requisito para o censo').relation, _blocks);
    });

    test('a specific relationship outranks a plain one earlier in the '
        'sentence', () {
      final mention = _single(
        'Like last time, this is blocked by the heater replacement.',
      );

      expect(mention.relation, _blockedBy);
    });

    test('the earliest specific cue wins', () {
      final mention = _single(
        'Follow-up to the survey, but blocked by the sled repair.',
      );

      expect(mention.relation, _followsUp);
    });

    test('the longest phrase at a position is the one removed', () {
      final mention = _single('Like last time we recount the penguins.');

      expect(mention.relation, _plain);
      expect(mention.query, 'we recount the penguins');
    });

    test('matches whole words only', () {
      expect(
        detectPriorWorkMentions(
          'The dupe offer was a lastingtime deal; unrelated.',
          sourceId: 'entry',
        ),
        isEmpty,
      );
    });

    test('ignores case and curly apostrophes', () {
      expect(_single('BLOCKED BY the radio relay.').relation, _blockedBy);
      expect(
        _single('Come l’ultima volta, contiamo i pinguini.').query,
        'contiamo i pinguini',
      );
    });

    test('a sentence that is only a cue searches by the task title', () {
      expect(_single('Same as last time.').query, isNull);
      expect(_single('Blocked by it.').query, isNull);
    });

    test('finds one mention per sentence, in order, across lines and '
        'punctuation', () {
      final mentions = detectPriorWorkMentions(
        'Counted the colony. Blocked by the radio relay!\n'
        'Wie letztes Mal prüfen wir die Sauerstoffpacks; '
        'nothing else here',
        sourceId: 'note',
      );

      expect(
        mentions.map((m) => (m.relation, m.query)),
        [
          (_blockedBy, 'the radio relay'),
          (_plain, 'prüfen wir die Sauerstoffpacks'),
        ],
      );
      expect(mentions.every((m) => m.sourceId == 'note'), isTrue);
    });

    test('cuts a run-on sentence at its maximum length', () {
      final runOn = 'blocked by the relay ${'qxz ' * 200}';

      final mention = _single(runOn);

      expect(mention.sentence.length, lessThanOrEqualTo(400));
      expect(mention.relation, _blockedBy);
    });

    test('text without a cue yields nothing', () {
      expect(
        detectPriorWorkMentions(
          'Counted 37 penguins and refilled the oxygen packs.',
          sourceId: 'entry',
        ),
        isEmpty,
      );
      expect(detectPriorWorkMentions('', sourceId: 'entry'), isEmpty);
    });

    Glados3(
      any.intInRange(0, _allPhrases.length),
      _filler,
      _filler,
      ExploreConfig(numRuns: 200),
    ).test(
      'a cue among filler words is found with its relation, the filler '
      'being the query',
      (index, before, after) {
        final cue = _allPhrases[index];
        final text = [...before, cue.phrase, ...after].join(' ');

        final mention = _single('$text.');

        expect(mention.relation, cue.relation, reason: cue.phrase);
        final rest = [...before, ...after];
        final words = rest.where((w) => w.length >= 3).length;
        expect(
          mention.query,
          words >= kMinMentionQueryWords ? rest.join(' ') : isNull,
        );
      },
      tags: 'glados',
    );
  });

  group('relationForCandidate', () {
    PriorWorkMention mention(DirectedRelation relation) => PriorWorkMention(
      sourceId: 'entry',
      sentence: 'sentence',
      relation: relation,
      query: 'query',
    );

    test('a closed task neither blocks nor is blocked: the link is plain', () {
      for (final relation in [_blockedBy, _blocks]) {
        expect(
          relationForCandidate(mention(relation), candidateIsClosed: true),
          _plain,
        );
        expect(
          relationForCandidate(mention(relation), candidateIsClosed: false),
          relation,
        );
      }
    });

    test('every other relationship holds whatever the candidate status', () {
      for (final relation in [
        _plain,
        _followsUp,
        const DirectedRelation(EntryLinkType.fixes),
        const DirectedRelation(EntryLinkType.duplicates),
        const DirectedRelation(EntryLinkType.supersedes),
      ]) {
        for (final closed in [true, false]) {
          expect(
            relationForCandidate(mention(relation), candidateIsClosed: closed),
            relation,
          );
        }
      }
    });
  });

  test('a mention is a value', () {
    PriorWorkMention make(String query) => PriorWorkMention(
      sourceId: 'entry',
      sentence: 'sentence',
      relation: _plain,
      query: query,
    );

    expect(make('a'), make('a'));
    expect(make('a').hashCode, make('a').hashCode);
    expect(make('a'), isNot(make('b')));
    expect(make('a').toString(), contains('relates_to'));
  });
}
