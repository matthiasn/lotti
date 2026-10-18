import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/memory/memory_links.dart';
import 'package:lotti/features/agents/memory/memory_search.dart';
import 'package:lotti/features/agents/sync/agent_log_compactor_models.dart';
import 'package:lotti/features/ai/service/text_chunker.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  MemoryLogHit hit(
    String id,
    String text, {
    String type = 'checkIn',
    bool edited = false,
    String? supersededBy,
    List<ResolvedMemoryLink> links = const [],
  }) => MemoryLogHit(
    contentEntryId: id,
    at: DateTime.utc(2026, 4, 2, 21),
    type: type,
    text: text,
    edited: edited,
    links: links,
    supersededByEntryId: supersededBy,
  );

  group('parseMemorySearchRequest', () {
    test('reads keywords, ids and a limit', () {
      final request = parseMemorySearchRequest({
        'query': '  colony walk ',
        'ids': [' a ', '', 7, 'b'],
        'limit': 3,
      })!;

      expect(request.query, 'colony walk');
      expect(request.ids, {'a', 'b'});
      expect(request.limit, 3);
    });

    test('clamps the limit and defaults a missing one', () {
      expect(parseMemorySearchRequest({'query': 'x', 'limit': 99})!.limit, 20);
      expect(parseMemorySearchRequest({'query': 'x', 'limit': 0})!.limit, 1);
      expect(parseMemorySearchRequest({'query': 'x', 'limit': '5'})!.limit, 8);
      expect(parseMemorySearchRequest({'query': 'x'})!.limit, 8);
    });

    test('ids without a limit return every id asked for, up to 20; an '
        'explicit limit is honoured for ids as for keywords', () {
      expect(
        parseMemorySearchRequest({
          'ids': ['a', 'b', 'c'],
        })!.limit,
        3,
      );
      expect(
        parseMemorySearchRequest({
          'ids': [for (var i = 0; i < 30; i++) 'id$i'],
        })!.limit,
        20,
      );
      expect(
        parseMemorySearchRequest({
          'ids': ['a', 'b'],
          'limit': 1,
        })!.limit,
        1,
      );
    });

    test('asks for something to search for', () {
      expect(parseMemorySearchRequest({}), isNull);
      expect(
        parseMemorySearchRequest({'query': '  ', 'ids': <String>[]}),
        isNull,
      );
    });
  });

  group('runMemorySearch', () {
    late MockAgentLogCompactor compactor;

    setUp(() {
      compactor = MockAgentLogCompactor();
      when(
        () => compactor.searchLog(
          any(),
          query: any(named: 'query'),
          limit: any(named: 'limit'),
          extraKnownIds: any(named: 'extraKnownIds'),
        ),
      ).thenAnswer((_) async => [hit('k', 'keyword hit')]);
      when(
        () => compactor.resolveByIds(
          any(),
          ids: any(named: 'ids'),
          limit: any(named: 'limit'),
          extraKnownIds: any(named: 'extraKnownIds'),
        ),
      ).thenAnswer((_) async => [hit('i', 'id hit')]);
    });

    test('keywords search the log with the limit', () async {
      final hits = await runMemorySearch(compactor, 'agent-1', (
        query: 'colony',
        ids: const {},
        limit: 5,
      ));

      expect(hits.single.contentEntryId, 'k');
      verify(
        () => compactor.searchLog(
          'agent-1',
          query: 'colony',
          limit: 5,
        ),
      ).called(1);
    });

    test('ids pull entries up directly, ahead of any keywords', () async {
      final hits = await runMemorySearch(
        compactor,
        'agent-1',
        (query: 'colony', ids: const {'i'}, limit: 5),
        extraKnownIds: const {'known'},
      );

      expect(hits.single.contentEntryId, 'i');
      verify(
        () => compactor.resolveByIds(
          'agent-1',
          ids: const {'i'},
          limit: 5,
          extraKnownIds: const {'known'},
        ),
      ).called(1);
      verifyNever(
        () => compactor.searchLog(
          any(),
          query: any(named: 'query'),
          limit: any(named: 'limit'),
          extraKnownIds: any(named: 'extraKnownIds'),
        ),
      );
    });
  });

  group('formatMemorySearchResult', () {
    const byKeyword = (query: 'colony', ids: <String>{}, limit: 8);

    test('says when nothing matches', () {
      expect(
        formatMemorySearchResult(byKeyword, const []),
        'No memory entries match "colony".',
      );
      expect(
        formatMemorySearchResult((query: '', ids: {'a', 'b'}, limit: 8), []),
        'No memory entries match ids a, b.',
      );
    });

    test('lists each hit with its date, kind, id, links and supersession', () {
      final out = formatMemorySearchResult(byKeyword, [
        hit(
          'obs-1',
          'Walks calm the colony.',
          type: 'observation',
          edited: true,
          supersededBy: 'obs-2',
          links: const [
            ResolvedMemoryLink(
              link: MemoryLink(relation: LinkRelation.refines, entryId: 'gone'),
              exists: false,
              liveEntryId: 'gone',
            ),
          ],
        ),
      ]);

      expect(
        out,
        'Found 1 memory match(es) for "colony" (most recent first):\n'
        '- [2026-04-02T21:00:00.000Z] (observation, edited) (id: obs-1) '
        'Walks calm the colony. [superseded by obs-2]\n'
        '  links: refines:gone (not found)',
      );
    });

    test('unbounded by default: a long hit comes back whole', () {
      final long = List.filled(500, 'krill').join(' ');
      expect(
        formatMemorySearchResult(byKeyword, [hit('a', long)]),
        contains(long),
      );
    });

    test('a hit budget cuts each hit to fit', () {
      final long = List.filled(500, 'krill').join(' ');
      final out = formatMemorySearchResult(byKeyword, [
        hit('a', long),
      ], hitTokenBudget: 40);

      final line = out.split('\n')[1];
      expect(line, endsWith('…'));
      expect(TextChunker.estimateTokens(line), lessThan(80));
    });

    test('a total budget stops listing and says how many were left out', () {
      final hits = [
        for (var i = 0; i < 6; i++)
          hit('h$i', List.filled(60, 'krill').join(' ')),
      ];

      final out = formatMemorySearchResult(
        byKeyword,
        hits,
        totalTokenBudget: 200,
      );

      final listed = out.split('\n').where((l) => l.startsWith('- ')).length;
      expect(listed, inInclusiveRange(1, 5));
      expect(out, contains('Found 6 memory match(es)'));
      expect(
        out,
        endsWith(
          '(${6 - listed} more not shown — narrow the query or pull them up '
          'by id.)',
        ),
      );
    });

    test('under a hit budget a note full of links lists eight and counts '
        'the rest; unbudgeted, it lists them all', () {
      final links = [
        for (var i = 0; i < 12; i++)
          ResolvedMemoryLink(
            link: MemoryLink(relation: LinkRelation.relates, entryId: 'e$i'),
            exists: true,
            liveEntryId: 'e$i',
          ),
      ];
      final note = hit('n', 'A note.', links: links);

      final budgeted = formatMemorySearchResult(byKeyword, [
        note,
      ], hitTokenBudget: 250);
      expect(
        RegExp('relates:').allMatches(budgeted),
        hasLength(memorySearchBudgetedLinksPerHit),
      );
      expect(budgeted, endsWith('(+4 more)'));

      final whole = formatMemorySearchResult(byKeyword, [note]);
      expect(RegExp('relates:').allMatches(whole), hasLength(12));
      expect(whole, isNot(contains('more)')));
    });

    test('the first hit is always listed, even past a tiny total budget', () {
      final out = formatMemorySearchResult(
        byKeyword,
        [hit('a', List.filled(80, 'krill').join(' '))],
        totalTokenBudget: 1,
      );

      expect(out, contains('(id: a)'));
      expect(out, isNot(contains('not shown')));
    });
  });
}
