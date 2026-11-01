import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/directed_relation.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/link_suggestions/task_link_suggestion.dart';
import 'package:lotti/features/ai/link_suggestions/task_link_suggestion_detector.dart';
import 'package:lotti/features/ai/repository/vector_search_repository.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/entity_factories.dart';
import '../../../mocks/mocks.dart';
import 'link_suggestion_fixtures.dart';

const _plain = DirectedRelation(EntryLinkType.basic);
const _blockedBy = DirectedRelation(EntryLinkType.blocks, inverse: true);
const _followsUp = DirectedRelation(EntryLinkType.followsUp);

/// A journal and a search by meaning, both in memory.
///
/// [tasks] is every task the journal holds; [hits] answers each query with
/// task ids and distances, in the order the search would rank them.
class _Bench {
  _Bench({
    required this.task,
    this.entries = const [],
    List<Task> tasks = const [],
    this.hits = const {},
    this.links = const [],
    this.embeddingsOn = true,
  }) : tasks = {
         for (final t in [task, ...tasks]) t.meta.id: t,
       } {
    when(() => db.journalEntityById(any())).thenAnswer(
      (invocation) async =>
          this.tasks[invocation.positionalArguments.first as String],
    );
    when(
      () => db.getConfigFlag(enableEmbeddingsFlag),
    ).thenAnswer((_) async => embeddingsOn);
    when(
      () => db.getLinkedEntities(task.meta.id),
    ).thenAnswer((_) async => entries);
    when(
      () => db.linksForEntryIdsBidirectional({task.meta.id}),
    ).thenAnswer((_) async => links);
    when(() => db.getJournalEntitiesForIdsUnordered(any())).thenAnswer(
      (invocation) async => [
        for (final id in invocation.positionalArguments.first as Set<String>)
          ?this.tasks[id],
      ],
    );
    when(
      () => search.searchRelatedTasks(
        query: any(named: 'query'),
        k: any(named: 'k'),
      ),
    ).thenAnswer((invocation) async {
      final query = invocation.namedArguments[#query] as String;
      final ranked = hits[query] ?? const [];
      return VectorSearchResult(
        entities: [for (final (id, _) in ranked) this.tasks[id]!],
        elapsed: Duration.zero,
        distances: {for (final (id, distance) in ranked) id: distance},
      );
    });
  }

  final Task task;
  final List<JournalEntity> entries;
  final Map<String, Task> tasks;
  final Map<String, List<(String, double)>> hits;
  final List<EntryLink> links;
  final bool embeddingsOn;

  final db = MockJournalDb();
  final search = MockVectorSearchRepository();
  final logger = MockDomainLogger();

  TaskLinkSuggestionDetector detector({bool withSearch = true}) =>
      TaskLinkSuggestionDetector(
        db: db,
        search: withSearch ? search : null,
        domainLogger: logger,
      );

  Future<TaskLinkSuggestionScan> scan({TaskLinkSuggestionScan? previous}) =>
      detector().scan(task.meta.id, previous: previous);

  List<String> get searchedQueries => verify(
    () => search.searchRelatedTasks(
      query: captureAny(named: 'query'),
      k: any(named: 'k'),
    ),
  ).captured.cast<String>();
}

final Task _current = linkTask('current', 'Recount the emperor penguins');
final Task _census = linkTask('census', 'Colony census export');
final Task _relay = linkTask('relay', 'Repair the radio relay');
final Task _sled = linkTask('sled', 'Sled maintenance checklist');

(String, double) _hit(Task task, double distance) => (task.meta.id, distance);

void main() {
  test('suggests the tasks a mention is close to, with the relation it '
      'names', () async {
    final bench = _Bench(
      task: _current,
      entries: [logEntry('e1', 'Blocked by the radio relay repair today.')],
      tasks: [_relay, _census],
      hits: {
        'the radio relay repair today': [
          _hit(_relay, 0.31),
          _hit(_census, 0.48),
        ],
      },
    );

    final scan = await bench.scan();

    expect(
      scan.suggestions.map((s) => (s.targetTaskId, s.relation, s.distance)),
      [('relay', _blockedBy, 0.31), ('census', _blockedBy, 0.48)],
    );
    final first = scan.suggestions.first;
    expect(first.sourceTaskId, 'current');
    expect(first.targetTitle, 'Repair the radio relay');
    expect(first.mention.sourceId, 'e1');
    expect(first.mentionedAt, testFixedDate);
    expect(bench.searchedQueries, ['the radio relay repair today']);
  });

  test('drops the task itself and every task past the cutoff', () async {
    final bench = _Bench(
      task: _current,
      entries: [logEntry('e1', 'Follow-up to the census export work.')],
      tasks: [_census, _sled],
      hits: {
        'the census export work': [
          _hit(_current, 0.12),
          _hit(_census, TaskLinkSuggestionDetector.maxDistance),
          _hit(_sled, TaskLinkSuggestionDetector.maxDistance + 0.001),
        ],
      },
    );

    final scan = await bench.scan();

    expect(scan.suggestions.map((s) => s.targetTaskId), ['census']);
    expect(scan.suggestions.single.relation, _followsUp);
  });

  test('never suggests a task already linked, by any link in either '
      'direction', () async {
    final bench = _Bench(
      task: _current,
      entries: [logEntry('e1', 'Same problem as the relay and sled work.')],
      tasks: [_relay, _sled, _census],
      hits: {
        'the relay and sled work': [
          _hit(_relay, 0.2),
          _hit(_sled, 0.3),
          _hit(_census, 0.4),
        ],
      },
      links: [
        plainLink('current', 'e1'),
        plainLink('relay', 'current', hidden: true),
        EntryLink.blocks(
          id: 'current-sled',
          fromId: 'current',
          toId: 'sled',
          createdAt: testFixedDate,
          updatedAt: testFixedDate,
          vectorClock: null,
        ),
      ],
    );

    final scan = await bench.scan();

    expect(scan.suggestions.map((s) => s.targetTaskId), ['census']);
  });

  test('a closed task is suggested as a plain link, never as a blocker', () {
    final doneRelay = linkTask('relay', 'Repair the radio relay', closed: true);
    final bench = _Bench(
      task: _current,
      entries: [logEntry('e1', 'Waiting on the radio relay repair.')],
      tasks: [doneRelay],
      hits: {
        'the radio relay repair': [_hit(doneRelay, 0.2)],
      },
    );

    expect(
      bench.scan().then((s) => s.suggestions.single.relation),
      completion(_plain),
    );
  });

  test('a sentence that is only a cue is searched by the task title', () async {
    final bench = _Bench(
      task: _current,
      entries: [logEntry('e1', 'Same as last time.')],
      tasks: [_census],
      hits: {
        'Recount the emperor penguins': [_hit(_census, 0.4)],
      },
    );

    final scan = await bench.scan();

    expect(bench.searchedQueries, ['Recount the emperor penguins']);
    expect(scan.suggestions.single.mention.query, isNull);
  });

  test('reads the newest entries first, the notes last, and searches at '
      'most maxMentions sentences', () async {
    final task = linkTask(
      'current',
      'Recount the emperor penguins',
      notes: 'Similar to the old census sheet.',
    );
    final bench = _Bench(
      task: task,
      entries: [
        logEntry('old', 'Like last time we count beaks first.'),
        logEntry(
          'new',
          'Blocked by the relay fix. Follow-up to the sled checks. '
              'See also the oxygen packs.',
          minutesAfter: 10,
        ),
        logEntry('middle', 'Previously we used tally sheets.', minutesAfter: 5),
      ],
    );

    await bench.scan();

    expect(
      bench.searchedQueries,
      [
        'the relay fix',
        'the sled checks',
        'the oxygen packs',
        'we used tally sheets',
      ],
    );
    expect(
      TaskLinkSuggestionDetector.maxMentions,
      4,
      reason: 'the expectation above lists exactly maxMentions queries',
    );
  });

  test('offers at most maxSuggestions, nearest first', () async {
    final others = [
      for (var i = 0; i < 5; i++) linkTask('t$i', 'Task $i'),
    ];
    final bench = _Bench(
      task: _current,
      entries: [logEntry('e1', 'Related to the colony census work.')],
      tasks: others,
      hits: {
        'the colony census work': [
          for (var i = 0; i < 5; i++) _hit(others[i], 0.5 - i / 100),
        ],
      },
    );

    final scan = await bench.scan();

    expect(scan.suggestions.map((s) => s.targetTaskId), ['t4', 't3', 't2']);
  });

  test('a task two mentions point at keeps the nearer mention', () async {
    final bench = _Bench(
      task: _current,
      entries: [
        logEntry('older', 'Follow-up to the census export.'),
        logEntry('newer', 'Related to the census numbers.', minutesAfter: 1),
      ],
      tasks: [_census],
      hits: {
        'the census numbers': [_hit(_census, 0.45)],
        'the census export': [_hit(_census, 0.2)],
      },
    );

    final suggestion = (await bench.scan()).suggestions.single;

    expect(suggestion.distance, 0.2);
    expect(suggestion.relation, _followsUp);
    expect(suggestion.mention.sourceId, 'older');
    expect(suggestion.mentionedAt, testFixedDate);
  });

  test(
    'reuses the previous scan’s searches but reads the tasks again',
    () async {
      final bench = _Bench(
        task: _current,
        entries: [logEntry('e1', 'Follow-up to the census export.')],
        tasks: [_census],
        hits: {
          'the census export': [_hit(_census, 0.2)],
        },
      );
      final first = await bench.scan();
      bench.tasks['census'] = linkTask('census', 'Census export, renamed');
      clearInteractions(bench.search);

      final second = await bench.scan(previous: first);

      verifyNever(
        () => bench.search.searchRelatedTasks(
          query: any(named: 'query'),
          k: any(named: 'k'),
        ),
      );
      expect(second.suggestions.single.targetTitle, 'Census export, renamed');
      expect(second.searches, first.searches);
    },
  );

  test('a deleted or vanished candidate is not suggested', () async {
    final deleted = linkTask('sled', 'Sled', deletedAt: testFixedDate);
    final bench = _Bench(
      task: _current,
      entries: [logEntry('e1', 'Related to the sled and census work.')],
      tasks: [deleted],
      hits: {
        'the sled and census work': [_hit(deleted, 0.2)],
      },
    );
    bench.tasks.remove('missing');

    expect((await bench.scan()).suggestions, isEmpty);
  });

  test(
    'a failed search is logged, yields nothing and is not remembered',
    () async {
      final bench = _Bench(
        task: _current,
        entries: [logEntry('e1', 'Follow-up to the census export.')],
      );
      when(
        () => bench.search.searchRelatedTasks(
          query: any(named: 'query'),
          k: any(named: 'k'),
        ),
      ).thenThrow(Exception('store closed'));

      final scan = await bench.scan();

      expect(scan.suggestions, isEmpty);
      expect(scan.searches, isEmpty);
      verify(
        () => bench.logger.error(
          LogDomain.ai,
          any<Object>(),
          errorType: any(named: 'errorType'),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'TaskLinkSuggestionDetector',
          message: 'Related-task search failed',
        ),
      ).called(1);
    },
  );

  test('watches the task, all its text entries and the suggested tasks; '
      'skips deleted entries and media', () async {
    final image = TestImageFactory.create(id: 'image');
    final bench = _Bench(
      task: _current,
      entries: [
        logEntry('e1', 'Follow-up to the census export.'),
        logEntry(
          'gone',
          'Blocked by the relay repair.',
          deletedAt: testFixedDate,
        ),
        image,
      ],
      tasks: [_census],
      hits: {
        'the census export': [_hit(_census, 0.2)],
      },
    );

    final scan = await bench.scan();

    expect(scan.watchedIds, {'current', 'e1', 'census'});
    expect(bench.searchedQueries, ['the census export']);
  });

  group('searches nothing', () {
    test('when search by meaning is switched off', () async {
      final bench = _Bench(
        task: _current,
        entries: [logEntry('e1', 'Follow-up to the census export.')],
        embeddingsOn: false,
      );

      final scan = await bench.scan();

      expect(scan.suggestions, isEmpty);
      expect(scan.watchedIds, {'current'});
      verifyZeroInteractions(bench.search);
    });

    test('when this device runs no embedding pipeline', () async {
      final bench = _Bench(
        task: _current,
        entries: [logEntry('e1', 'Follow-up to the census export.')],
      );

      final scan = await bench
          .detector(withSearch: false)
          .scan(_current.meta.id);

      expect(scan.suggestions, isEmpty);
      verifyNever(() => bench.db.getLinkedEntities(any()));
    });

    test('for a deleted task or one that is not a task', () async {
      final bench = _Bench(
        task: linkTask('current', 'Gone', deletedAt: testFixedDate),
        entries: [logEntry('e1', 'Follow-up to the census export.')],
      );
      when(
        () => bench.db.journalEntityById('entry'),
      ).thenAnswer((_) async => logEntry('entry', 'text'));

      expect(await bench.scan(), same(TaskLinkSuggestionScan.empty));
      expect(
        await bench.detector().scan('entry'),
        same(TaskLinkSuggestionScan.empty),
      );
      verifyZeroInteractions(bench.search);
    });

    test('when no sentence mentions other work', () async {
      final bench = _Bench(
        task: _current,
        entries: [logEntry('e1', 'Counted 37 penguins and fed them.')],
      );

      final scan = await bench.scan();

      expect(scan.suggestions, isEmpty);
      expect(scan.watchedIds, {'current', 'e1'});
      verifyZeroInteractions(bench.search);
    });
  });
}
