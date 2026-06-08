import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/memory/memory_links.dart';

void main() {
  group('LinkRelation', () {
    test('wire is the lowercase enum name for every relation', () {
      expect(LinkRelation.refines.wire, 'refines');
      expect(LinkRelation.supersedes.wire, 'supersedes');
      expect(LinkRelation.contradicts.wire, 'contradicts');
      expect(LinkRelation.relates.wire, 'relates');
    });

    test(
      'linkRelationFromWire is case-insensitive and rejects the unknown',
      () {
        expect(linkRelationFromWire('refines'), LinkRelation.refines);
        expect(linkRelationFromWire('SUPERSEDES'), LinkRelation.supersedes);
        expect(linkRelationFromWire('Relates'), LinkRelation.relates);
        expect(linkRelationFromWire('evolves'), isNull);
        expect(linkRelationFromWire(''), isNull);
      },
    );
  });

  group('parseMemoryLinks', () {
    test('parses a single well-formed token', () {
      expect(
        parseMemoryLinks('see [[refines:obs-12ab]] for context'),
        [const MemoryLink(relation: LinkRelation.refines, entryId: 'obs-12ab')],
      );
    });

    test('parses multiple distinct tokens preserving order', () {
      expect(
        parseMemoryLinks(
          'a [[relates:e1]] b [[supersedes:e2]] c [[contradicts:e3]]',
        ),
        const [
          MemoryLink(relation: LinkRelation.relates, entryId: 'e1'),
          MemoryLink(relation: LinkRelation.supersedes, entryId: 'e2'),
          MemoryLink(relation: LinkRelation.contradicts, entryId: 'e3'),
        ],
      );
    });

    test('de-duplicates identical tokens, keeping first-seen order', () {
      expect(
        parseMemoryLinks('[[relates:e1]] [[refines:e2]] [[relates:e1]]'),
        const [
          MemoryLink(relation: LinkRelation.relates, entryId: 'e1'),
          MemoryLink(relation: LinkRelation.refines, entryId: 'e2'),
        ],
      );
    });

    test('drops tokens whose relation is outside the closed vocabulary', () {
      expect(parseMemoryLinks('[[evolves:e1]] [[relates:e2]]'), const [
        MemoryLink(relation: LinkRelation.relates, entryId: 'e2'),
      ]);
    });

    test('ignores malformed tokens and ordinary brackets', () {
      // No colon, a non-letter relation, an interior colon in the id, and a
      // plain double-bracket: none are well-formed `[[relation:id]]` tokens.
      expect(
        parseMemoryLinks('[[note]] [[1:2]] [[relates:a:b]] [[ ]]'),
        isEmpty,
      );
      expect(parseMemoryLinks('plain prose, no links here'), isEmpty);
      expect(parseMemoryLinks(''), isEmpty);
    });

    test('matches relation case-insensitively', () {
      expect(parseMemoryLinks('[[ReFiNeS:e9]]'), const [
        MemoryLink(relation: LinkRelation.refines, entryId: 'e9'),
      ]);
    });
  });

  group('MemoryLink value semantics', () {
    test('equal by relation + entryId', () {
      const a = MemoryLink(relation: LinkRelation.relates, entryId: 'x');
      const b = MemoryLink(relation: LinkRelation.relates, entryId: 'x');
      const c = MemoryLink(relation: LinkRelation.refines, entryId: 'x');
      expect(a, b);
      expect(a == c, isFalse);
      expect(a.toString(), 'MemoryLink(relates:x)');
    });
  });

  group('resolveMemoryLinks', () {
    const link = MemoryLink(relation: LinkRelation.relates, entryId: 'e1');

    test('flags existence against knownIds', () {
      final resolved = resolveMemoryLinks(const [link], knownIds: {'e1'});
      expect(resolved.single.exists, isTrue);
      expect(resolved.single.liveEntryId, 'e1');
      expect(resolved.single.superseded, isFalse);

      final missing = resolveMemoryLinks(const [link], knownIds: {'other'});
      expect(missing.single.exists, isFalse);
    });

    test('leaves liveEntryId at the target when nothing supersedes it', () {
      final resolved = resolveMemoryLinks(const [link], knownIds: {'e1'});
      expect(resolved.single.liveEntryId, 'e1');
    });

    test('follows a single supersession step', () {
      final resolved = resolveMemoryLinks(
        const [link],
        knownIds: {'e1', 'e2'},
        supersededBy: const {'e1': 'e2'},
      );
      expect(resolved.single.liveEntryId, 'e2');
      expect(resolved.single.superseded, isTrue);
    });

    test('follows a multi-step chain to the newest version', () {
      final resolved = resolveMemoryLinks(
        const [link],
        knownIds: {'e1', 'e2', 'e3'},
        supersededBy: const {'e1': 'e2', 'e2': 'e3'},
      );
      expect(resolved.single.liveEntryId, 'e3');
    });

    test('stops on a cycle instead of looping forever', () {
      final resolved = resolveMemoryLinks(
        const [link],
        knownIds: {'e1', 'e2'},
        supersededBy: const {'e1': 'e2', 'e2': 'e1'},
      );
      // Terminates at the last node reached before re-entering the cycle.
      expect(resolved.single.liveEntryId, 'e2');
    });

    test('handles a self-superseding edge', () {
      final resolved = resolveMemoryLinks(
        const [link],
        knownIds: {'e1'},
        supersededBy: const {'e1': 'e1'},
      );
      expect(resolved.single.liveEntryId, 'e1');
      expect(resolved.single.superseded, isFalse);
    });

    test('ResolvedMemoryLink is equal by its fields', () {
      final a = resolveMemoryLinks(const [link], knownIds: {'e1'}).single;
      final b = resolveMemoryLinks(const [link], knownIds: {'e1'}).single;
      final c = resolveMemoryLinks(const [link], knownIds: const {}).single;
      expect(a, b);
      expect(a == c, isFalse);
    });
  });

  group('properties', () {
    const relations = LinkRelation.values;
    const ids = ['a1', 'b2', 'obs-3', 'x_4', 'cap5'];

    glados.Glados2(
      glados.ListAnys(glados.any).listWithLengthInRange(
        0,
        6,
        glados.IntAnys(glados.any).intInRange(0, relations.length),
      ),
      glados.ListAnys(glados.any).listWithLengthInRange(
        0,
        6,
        glados.IntAnys(glados.any).intInRange(0, ids.length),
      ),
      glados.ExploreConfig(numRuns: 40),
    ).test(
      'rendering links then parsing round-trips to the de-duplicated set',
      (relIdx, idIdx) {
        final n = math.min(relIdx.length, idIdx.length);
        final pairs = [
          for (var i = 0; i < n; i++)
            MemoryLink(relation: relations[relIdx[i]], entryId: ids[idIdx[i]]),
        ];
        final deduped = <MemoryLink>[];
        final seen = <MemoryLink>{};
        for (final p in pairs) {
          if (seen.add(p)) deduped.add(p);
        }
        final content = pairs
            .map((p) => '[[${p.relation.wire}:${p.entryId}]]')
            .join(' note ');
        expect(parseMemoryLinks(content), deduped);
      },
      tags: 'glados',
    );

    const fragments = [
      '[[refines:a1]]',
      '[[relates:obs-3]]',
      '[[supersedes:x_4]]',
      '[[bogus:y]]', // unknown relation
      '[[note]]', // no colon
      '[[1:2]]', // non-letter relation
      '[[relates:a:b]]', // interior colon
      'plain prose',
      '[[',
      ']]',
      '::',
    ];

    glados.Glados(
      glados.ListAnys(glados.any).listWithLengthInRange(
        0,
        8,
        glados.IntAnys(glados.any).intInRange(0, fragments.length),
      ),
      glados.ExploreConfig(numRuns: 40),
    ).test(
      'parsing noisy fragment soup never throws and yields only well-formed '
      'links',
      (idx) {
        final content = idx.map((i) => fragments[i]).join(' ');
        final links = parseMemoryLinks(content);
        for (final link in links) {
          expect(link.entryId, isNotEmpty);
          expect(LinkRelation.values, contains(link.relation));
        }
      },
      tags: 'glados',
    );
  });
}
