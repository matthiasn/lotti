import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/repository/related_task_finder.dart';
import 'package:lotti/features/ai/repository/vector_search_repository.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/entity_factories.dart';
import '../../../mocks/mocks.dart';

Task _task(String id, String title) =>
    TestTaskFactory.create(id: id, title: title);

final Task _current = _task('current', 'Recount the emperor penguins');
final Task _census = _task('census', 'Colony census export');
final Task _relay = _task('relay', 'Repair the radio relay');

void main() {
  late MockJournalDb db;
  late MockVectorSearchRepository search;
  late Map<String, Task> tasks;
  late Map<String, List<(String, double)>> hits;

  setUp(() {
    db = MockJournalDb();
    search = MockVectorSearchRepository();
    tasks = {
      for (final t in [_current, _census, _relay]) t.meta.id: t,
    };
    hits = {};
    when(
      () => db.linksForEntryIdsBidirectional(any()),
    ).thenAnswer((_) async => []);
    when(() => db.getJournalEntitiesForIdsUnordered(any())).thenAnswer(
      (invocation) async => [
        for (final id in invocation.positionalArguments.first as Set<String>)
          ?tasks[id],
      ],
    );
    when(
      () => search.searchRelatedTasks(
        query: any(named: 'query'),
        k: any(named: 'k'),
        categoryIds: any(named: 'categoryIds'),
      ),
    ).thenAnswer((invocation) async {
      final ranked = hits[invocation.namedArguments[#query] as String] ?? [];
      return VectorSearchResult(
        entities: [for (final (id, _) in ranked) tasks[id]!],
        elapsed: Duration.zero,
        distances: {for (final (id, d) in ranked) id: d},
      );
    });
  });

  RelatedTaskFinder finder({bool withSearch = true, DomainLogger? logger}) =>
      RelatedTaskFinder(
        db: db,
        search: withSearch ? search : null,
        domainLogger: logger,
      );

  List<String> ids(RelatedTaskSearch found) => [
    for (final match in found.matches) match.task.meta.id,
  ];

  EntryLink link(String from, String to, {bool hidden = false}) =>
      EntryLink.blocks(
        id: '$from-$to',
        fromId: from,
        toId: to,
        createdAt: testFixedDate,
        updatedAt: testFixedDate,
        vectorClock: null,
        hidden: hidden,
      );

  test('drops the task itself and every task past the cutoff', () async {
    hits['q'] = [
      ('current', 0.1),
      ('census', RelatedTaskFinder.maxDistance),
      ('relay', RelatedTaskFinder.maxDistance + 0.001),
    ];

    expect(ids(await finder().find('current', ['q'])), ['census']);
  });

  test('leaves out every task already linked, either direction, any type, '
      'hidden links included', () async {
    final sled = _task('sled', 'Sled checks');
    tasks['sled'] = sled;
    hits['q'] = [('census', 0.2), ('relay', 0.3), ('sled', 0.4)];
    when(() => db.linksForEntryIdsBidirectional({'current'})).thenAnswer(
      (_) async => [
        link('current', 'census'),
        link('relay', 'current', hidden: true),
      ],
    );

    expect(ids(await finder().find('current', ['q'])), ['sled']);
  });

  test('equally near tasks are ordered by id, so a rerun never reshuffles '
      'them', () async {
    hits['q'] = [('relay', 0.3), ('census', 0.3)];

    expect(ids(await finder().find('current', ['q'])), ['census', 'relay']);
  });

  test(
    'reads the tasks fresh and drops one deleted since it was embedded',
    () async {
      hits['q'] = [('census', 0.2), ('relay', 0.3)];
      tasks['census'] = _task('census', 'Census, renamed');
      final relay = _task('relay', 'Relay');
      tasks['relay'] = relay.copyWith(
        meta: relay.meta.copyWith(deletedAt: testFixedDate),
      );

      final found = await finder().find('current', ['q']);

      expect(ids(found), ['census']);
      expect(found.matches.single.task.data.title, 'Census, renamed');
    },
  );

  test(
    'a search that did not run is not remembered as nothing found',
    () async {
      when(
        () => search.searchRelatedTasks(
          query: any(named: 'query'),
          k: any(named: 'k'),
          categoryIds: any(named: 'categoryIds'),
        ),
      ).thenAnswer((_) async => VectorSearchResult.notSearched());

      final found = await finder().find('current', ['q']);

      expect(found.matches, isEmpty);
      expect(found.searches, isEmpty);
    },
  );

  test(
    'a search that throws is logged, finds nothing and is not remembered',
    () async {
      final logger = MockDomainLogger();
      when(
        () => search.searchRelatedTasks(
          query: any(named: 'query'),
          k: any(named: 'k'),
          categoryIds: any(named: 'categoryIds'),
        ),
      ).thenThrow(Exception('store closed'));

      final found = await finder(logger: logger).find('current', ['q']);

      expect(found.matches, isEmpty);
      expect(found.searches, isEmpty);
      verify(
        () => logger.error(
          LogDomain.ai,
          any<Object>(),
          errorType: any(named: 'errorType'),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'RelatedTaskFinder',
          message: 'Related-task search failed',
        ),
      ).called(1);
    },
  );

  test('scopes every search to the categories it is given', () async {
    hits['relay work'] = [('relay', 0.3)];

    final found = await finder().find(
      'current',
      ['relay work'],
      categoryIds: {'cat-a'},
    );

    expect(found.matches.single.task.meta.id, 'relay');
    verify(
      () => search.searchRelatedTasks(
        query: 'relay work',
        k: RelatedTaskFinder.hitsPerQuery + 1,
        categoryIds: {'cat-a'},
      ),
    ).called(1);
  });

  test('a task several queries find keeps the nearest, the earliest query '
      'on a tie', () async {
    hits
      ..['first'] = [('census', 0.4)]
      ..['second'] = [('census', 0.4), ('relay', 0.2)]
      ..['third'] = [('relay', 0.1)];

    final found = await finder().find('current', ['first', 'second', 'third']);

    expect(
      found.matches.map((m) => (m.task.meta.id, m.distance, m.queryIndex)),
      [('relay', 0.1, 2), ('census', 0.4, 0)],
    );
  });

  test('reuses earlier searches and runs only the new queries', () async {
    hits['new'] = [('census', 0.2)];

    final found = await finder().find(
      'current',
      ['old', 'new'],
      previous: {
        'old': [(taskId: 'relay', distance: 0.3)],
      },
    );

    expect(found.matches.map((m) => m.task.meta.id), ['census', 'relay']);
    expect(found.searches.keys, ['old', 'new']);
    verifyNever(
      () => search.searchRelatedTasks(
        query: 'old',
        k: any(named: 'k'),
        categoryIds: any(named: 'categoryIds'),
      ),
    );
  });

  test('finds nothing without queries or without a search pipeline', () async {
    expect((await finder().find('current', [])).matches, isEmpty);
    expect(
      (await finder(withSearch: false).find('current', ['q'])).matches,
      isEmpty,
    );
    verifyZeroInteractions(search);
  });

  test('is available only with a pipeline and search by meaning on', () async {
    for (final flag in [true, false]) {
      when(
        () => db.getConfigFlag(enableEmbeddingsFlag),
      ).thenAnswer((_) async => flag);

      expect(await finder().isAvailable, flag);
      expect(await finder(withSearch: false).isAvailable, isFalse);
    }
  });
}
