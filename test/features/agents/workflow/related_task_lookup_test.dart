import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/workflow/related_task_lookup.dart';
import 'package:lotti/features/ai/repository/related_task_finder.dart';
import 'package:lotti/features/ai/repository/vector_search_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/entity_factories.dart';
import '../../../mocks/mocks.dart';

const _current = 'current';

Task _task(String id, {bool private = false}) =>
    TestTaskFactory.create(id: id, title: 'Task $id', private: private);

AgentReportEntity _report({
  String? oneLiner,
  String? tldr,
  String content = 'The whole report.',
}) => AgentReportEntity(
  id: 'report',
  agentId: 'agent',
  scope: 'current',
  createdAt: testFixedDate,
  vectorClock: null,
  content: content,
  oneLiner: oneLiner,
  tldr: tldr,
);

void main() {
  late MockJournalDb db;
  late MockVectorSearchRepository search;
  late MockAgentRepository agents;
  late Map<String, Task> tasks;
  late List<(String, double)> hits;
  late Map<String, AgentReportEntity> reports;

  setUp(() {
    db = MockJournalDb();
    search = MockVectorSearchRepository();
    agents = MockAgentRepository();
    tasks = {};
    hits = [];
    reports = {};
    when(
      () => db.linksForEntryIdsBidirectional(any()),
    ).thenAnswer((_) async => []);
    when(() => db.getJournalEntitiesForIdsUnordered(any())).thenAnswer(
      (invocation) async => [
        for (final id in invocation.positionalArguments.first as Set<String>)
          ?tasks[id],
      ],
    );
    when(() => db.journalEntityById(any())).thenAnswer(
      (invocation) async => tasks[invocation.positionalArguments.first],
    );
    when(
      () => search.searchRelatedTasks(
        query: any(named: 'query'),
        k: any(named: 'k'),
        categoryIds: any(named: 'categoryIds'),
      ),
    ).thenAnswer(
      (_) async => VectorSearchResult(
        entities: [for (final (id, _) in hits) tasks[id]!],
        elapsed: Duration.zero,
        distances: {for (final (id, d) in hits) id: d},
      ),
    );
    when(() => agents.getLatestTaskReportsForTaskIds(any())).thenAnswer(
      (invocation) async => {
        for (final id in invocation.positionalArguments.first as List<String>)
          id: ?reports[id],
      },
    );
  });

  RelatedTaskLookup lookup({Set<String> categories = const {'cat-a'}}) =>
      RelatedTaskLookup(
        finder: RelatedTaskFinder(db: db, search: search),
        journalDb: db,
        agentRepository: agents,
        allowedCategoryIds: categories,
      );

  void found(List<Task> nearestFirst) {
    for (final task in nearestFirst) {
      tasks[task.meta.id] = task;
    }
    hits = [
      for (var i = 0; i < nearestFirst.length; i++)
        (nearestFirst[i].meta.id, 0.1 + i / 100),
    ];
  }

  group('find', () {
    test('answers with id, title, status and one-liner, nearest first, and '
        'remembers what it returned', () async {
      found([_task('relay'), _task('census')]);
      reports['relay'] = _report(oneLiner: ' Waiting on parts ');
      final sut = lookup();

      final answer =
          jsonDecode(await sut.find(_current, '  the relay  ')) as Map;

      expect(answer['query'], 'the relay');
      expect(answer['tasks'], [
        {
          'id': 'relay',
          'title': 'Task relay',
          'status': 'OPEN',
          'oneLiner': 'Waiting on parts',
        },
        {'id': 'census', 'title': 'Task census', 'status': 'OPEN'},
      ]);
      expect(answer.containsKey('note'), isFalse);
      expect(sut.foundIds, {'relay', 'census'});
    });

    test("searches only the agent's categories", () async {
      found([_task('relay')]);

      await lookup(categories: {'cat-a', 'cat-b'}).find(_current, 'relay');

      verify(
        () => search.searchRelatedTasks(
          query: 'relay',
          k: any(named: 'k'),
          categoryIds: {'cat-a', 'cat-b'},
        ),
      ).called(1);
    });

    test('never returns a private task, nor remembers one', () async {
      found([_task('secret', private: true), _task('census')]);
      final sut = lookup();

      final answer = jsonDecode(await sut.find(_current, 'census')) as Map;

      expect(
        (answer['tasks'] as List).map((t) => (t as Map)['id']),
        ['census'],
      );
      expect(sut.foundIds, {'census'});
    });

    test('answers with at most maxResults tasks', () async {
      found([for (var i = 0; i < 6; i++) _task('t$i')]);

      final answer = jsonDecode(await lookup().find(_current, 'q')) as Map;

      expect(answer['tasks'] as List, hasLength(RelatedTaskLookup.maxResults));
    });

    test('bounds a long query', () async {
      final long = 'x' * (RelatedTaskLookup.maxQueryLength + 50);

      await lookup().find(_current, long);

      verify(
        () => search.searchRelatedTasks(
          query: 'x' * RelatedTaskLookup.maxQueryLength,
          k: any(named: 'k'),
          categoryIds: any(named: 'categoryIds'),
        ),
      ).called(1);
    });

    test('with nothing close enough, says so and proposes nothing', () async {
      final answer = jsonDecode(await lookup().find(_current, 'q')) as Map;

      expect(answer['tasks'], isEmpty);
      expect(answer['note'], contains('Do not propose a link'));
      verifyNever(() => agents.getLatestTaskReportsForTaskIds(any()));
    });

    test(
      'a search that could not run says so, not that nothing is close',
      () async {
        when(
          () => search.searchRelatedTasks(
            query: any(named: 'query'),
            k: any(named: 'k'),
            categoryIds: any(named: 'categoryIds'),
          ),
        ).thenAnswer((_) async => VectorSearchResult.notSearched());

        final answer = jsonDecode(await lookup().find(_current, 'q')) as Map;

        expect(answer['tasks'], isEmpty);
        expect(answer['note'], contains('could not run'));
        expect(answer['note'], isNot(contains('close enough')));
      },
    );

    test('an agent with no categories searches nothing', () async {
      final answer =
          jsonDecode(await lookup(categories: {}).find(_current, 'q')) as Map;

      expect(answer['tasks'], isEmpty);
      verifyZeroInteractions(search);
    });
  });

  group('details', () {
    setUp(() => tasks['relay'] = _task('relay'));

    test("reads the task and its agent's one-liner and TL;DR", () async {
      reports['relay'] = _report(
        oneLiner: 'Parts ordered',
        tldr: '- ETA Friday',
      );

      final answer = jsonDecode((await lookup().details('relay'))!) as Map;

      expect(answer, {
        'id': 'relay',
        'title': 'Task relay',
        'status': 'OPEN',
        'oneLiner': 'Parts ordered',
        'tldr': '- ETA Friday',
      });
    });

    test('adds the whole report when asked for it', () async {
      reports['relay'] = _report(tldr: 'Short', content: 'The long story.');

      final answer =
          jsonDecode((await lookup().details('relay', fullReport: true))!)
              as Map;

      expect(answer['report'], 'The long story.');
      expect(answer['tldr'], 'Short');
    });

    test('a task without a report says so', () async {
      final answer = jsonDecode((await lookup().details('relay'))!) as Map;

      expect(answer['note'], contains('no agent report yet'));
      expect(answer.containsKey('tldr'), isFalse);
    });

    test('a task that is gone has no details', () async {
      final deleted = _task('gone');
      tasks['gone'] = deleted.copyWith(
        meta: deleted.meta.copyWith(deletedAt: testFixedDate),
      );

      expect(await lookup().details('gone'), isNull);
      expect(await lookup().details('missing'), isNull);
    });
  });
}
