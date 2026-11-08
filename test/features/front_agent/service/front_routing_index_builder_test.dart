import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/agents/agent_link.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_logged_time_chart.dart';
import 'package:lotti/features/front_agent/model/front_pull_requests.dart';
import 'package:lotti/features/front_agent/model/front_routing_index.dart';
import 'package:lotti/features/front_agent/service/front_routing_index_builder.dart';
import 'package:lotti/features/insights/logic/time_bucketing.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../helpers/fts5_stubs.dart';
import '../../../mocks/mocks.dart';
import '../../agents/test_data/entity_factories.dart';
import '../../categories/test_utils.dart';

final _now = DateTime(2026, 10, 23, 9);
final _stamp = DateTime(2026, 10);

Metadata _meta(String id, {String? categoryId, DateTime? updatedAt}) =>
    Metadata(
      id: id,
      createdAt: _stamp,
      updatedAt: updatedAt ?? _stamp,
      dateFrom: _stamp,
      dateTo: _stamp,
      categoryId: categoryId,
    );

Task _task(String id, {String? categoryId = 'work', DateTime? due}) {
  final status = TaskStatus.open(id: 's-$id', createdAt: _stamp, utcOffset: 0);
  return JournalEntity.task(
        meta: _meta(id, categoryId: categoryId),
        data: TaskData(
          status: status,
          statusHistory: [status],
          dateFrom: _stamp,
          dateTo: _stamp,
          title: 'Task $id',
          due: due,
        ),
      )
      as Task;
}

/// A task with the status history [history] — each status's kind and when
/// it was set, in order — its current status the last of them, created on
/// [createdAt].
Task _historyTask(
  String id,
  List<(String, DateTime)> history, {
  String? categoryId = 'work',
  DateTime? createdAt,
  bool keepHistory = true,
}) {
  final statuses = [
    for (final (i, (kind, at)) in history.indexed)
      switch (kind) {
        'done' => TaskStatus.done(id: '$id-$i', createdAt: at, utcOffset: 0),
        'rejected' => TaskStatus.rejected(
          id: '$id-$i',
          createdAt: at,
          utcOffset: 0,
        ),
        _ => TaskStatus.open(id: '$id-$i', createdAt: at, utcOffset: 0),
      },
  ];
  final created = createdAt ?? _stamp;
  return JournalEntity.task(
        meta: Metadata(
          id: id,
          createdAt: created,
          updatedAt: history.last.$2,
          dateFrom: created,
          dateTo: created,
          categoryId: categoryId,
        ),
        data: TaskData(
          status: statuses.last,
          statusHistory: keepHistory ? statuses : const [],
          dateFrom: created,
          dateTo: created,
          title: 'Task $id',
        ),
      )
      as Task;
}

ProjectEntry _project(
  String id, {
  String? categoryId = 'work',
  DateTime? updatedAt,
}) =>
    JournalEntity.project(
          meta: _meta(id, categoryId: categoryId, updatedAt: updatedAt),
          data: ProjectData(
            title: 'Project $id',
            status: ProjectStatus.open(
              id: 'ps-$id',
              createdAt: _stamp,
              utcOffset: 0,
            ),
            dateFrom: _stamp,
            dateTo: _stamp,
          ),
        )
        as ProjectEntry;

RelationshipEntry _person(String id, {String? categoryId = 'work'}) =>
    JournalEntity.relationship(
          meta: _meta(id, categoryId: categoryId),
          data: RelationshipData(
            title: 'Person $id',
            status: RelationshipStatus.active(
              id: 'rs-$id',
              createdAt: _stamp,
              utcOffset: 0,
            ),
          ),
        )
        as RelationshipEntry;

GoalSpecVersionEntity _spec(String agentId, String statement) =>
    AgentDomainEntity.goalSpecVersion(
          id: 'spec:$agentId',
          agentId: agentId,
          version: 1,
          status: GoalSpecVersionStatus.active,
          authoredBy: 'user',
          title: statement,
          statement: statement,
          criteria: const GoalCriterion.habit(
            criterionId: 'c',
            habitId: 'h',
            window: GoalWindow.day(),
            targetCount: 1,
          ),
          createdAt: _stamp,
          vectorClock: null,
        )
        as GoalSpecVersionEntity;

GoalSpecHeadEntity _head(String agentId) =>
    AgentDomainEntity.goalSpecHead(
          id: goalSpecHeadId(agentId),
          agentId: agentId,
          versionId: 'spec:$agentId',
          updatedAt: _stamp,
          vectorClock: null,
        )
        as GoalSpecHeadEntity;

AgentLink _projectLink(String agentId, String projectId) =>
    AgentLink.agentProject(
      id: '$agentId->$projectId',
      fromId: agentId,
      toId: projectId,
      createdAt: _stamp,
      updatedAt: _stamp,
      vectorClock: null,
    );

void main() {
  setUpAll(registerAllFallbackValues);

  late MockJournalDb journalDb;
  late MockAgentRepository agentRepository;
  late MockFts5Db fts5Db;

  FrontRoutingIndexBuilder builder({
    bool withFts = true,
    Future<int> Function()? firstDayOfWeekIndex,
    Future<String?> Function()? githubLogin,
  }) => FrontRoutingIndexBuilder(
    journalDb: journalDb,
    agentRepository: agentRepository,
    fts5Db: withFts ? fts5Db : null,
    firstDayOfWeekIndex: firstDayOfWeekIndex,
    githubLogin: githubLogin,
  );

  setUp(() {
    journalDb = MockJournalDb();
    agentRepository = MockAgentRepository();
    fts5Db = MockFts5Db();
    // Empty world by default; each test seeds the kind it is about.
    when(
      () => journalDb.getTasksDueOnOrBefore(any()),
    ).thenAnswer((_) async => const []);
    when(
      () => journalDb.getOpenTasksForDayAgentCorpus(
        categoryIds: any(named: 'categoryIds'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => const []);
    when(
      () => journalDb.getVisibleProjects(),
    ).thenAnswer((_) async => const []);
    when(() => journalDb.getRelationships()).thenAnswer((_) async => const []);
    when(() => journalDb.getAllCategories()).thenAnswer((_) async => const []);
    when(
      () => journalDb.getAllCategoriesIncludingPrivate(),
    ).thenAnswer((_) async => const []);
    when(
      () => agentRepository.getLatestTaskReportsForTaskIds(any()),
    ).thenAnswer((_) async => const {});
    when(
      () => agentRepository.getLinksToMultiple(any(), type: any(named: 'type')),
    ).thenAnswer((_) async => const {});
    when(
      () => agentRepository.getLatestReportsByAgentIds(any(), any()),
    ).thenAnswer((_) async => const {});
    when(
      () =>
          agentRepository.getAgentIdentitiesByLifecycle(AgentLifecycle.active),
    ).thenAnswer((_) async => const []);
    when(
      () => agentRepository.getEntitiesByIds(any()),
    ).thenAnswer((_) async => const {});
  });

  group('tasks', () {
    test("rows carry status, due date and the owner report's one-liner and "
        'TL;DR; the allow-list reaches the corpus query', () async {
      // The front cap and the query's default are both 200; the stub names
      // the cap so the test still pins it if either side moves.
      when(
        () => journalDb.getOpenTasksForDayAgentCorpus(
          categoryIds: {'work'},
          // ignore: avoid_redundant_argument_values
          limit: frontIndexMaxTasks,
        ),
      ).thenAnswer(
        (_) async => [_task('t1', due: DateTime(2026, 10, 30)), _task('t2')],
      );
      when(
        () => agentRepository.getLatestTaskReportsForTaskIds(['t1', 't2']),
      ).thenAnswer(
        (_) async => {
          't1': makeTestReport(oneLiner: 'Buy the hose.', tldr: 'Hose last.'),
        },
      );

      final index = await builder().build(
        scope: const FrontRoutingScope(allowedCategoryIds: {'work'}),
        now: _now,
      );

      expect(index.tasks.map((r) => r.id), ['t1', 't2']);
      final t1 = index.row(FrontDestinationKind.task, 't1')!;
      expect(t1.title, 'Task t1');
      expect(t1.status, 'OPEN');
      expect(t1.due, DateTime(2026, 10, 30));
      expect(t1.oneLiner, 'Buy the hose.');
      expect(t1.tldr, 'Hose last.');
      expect(index.row(FrontDestinationKind.task, 't2')!.oneLiner, isNull);
      expect(index.tasksTruncated, isFalse);
    });

    test('a corpus at the cap is marked truncated', () async {
      when(
        () => journalDb.getOpenTasksForDayAgentCorpus(
          categoryIds: any(named: 'categoryIds'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async => [
          for (var i = 0; i < frontIndexMaxTasks; i++) _task('t$i'),
        ],
      );
      final index = await builder().build(
        scope: const FrontRoutingScope(),
        now: _now,
      );
      expect(index.tasks, hasLength(frontIndexMaxTasks));
      expect(index.tasksTruncated, isTrue);
    });
  });

  group('projects', () {
    test('filtered through the allow-list, newest first, capped, with the '
        "primary project agent's report", () async {
      when(() => journalDb.getVisibleProjects()).thenAnswer(
        (_) async => [
          _project('old', updatedAt: DateTime(2026, 9)),
          _project('new', updatedAt: DateTime(2026, 10, 20)),
          _project('private', categoryId: 'secret'),
          for (var i = 0; i < frontIndexMaxProjects; i++)
            _project('p$i', updatedAt: DateTime(2026, 10, 10)),
        ],
      );
      when(
        () => agentRepository.getLinksToMultiple(
          any(),
          type: AgentLinkTypes.agentProject,
        ),
      ).thenAnswer(
        (_) async => {
          'new': [_projectLink('pa-new', 'new')],
        },
      );
      when(
        () => agentRepository.getLatestReportsByAgentIds(
          ['pa-new'],
          AgentReportScopes.current,
        ),
      ).thenAnswer(
        (_) async => {
          'pa-new': makeTestReport(oneLiner: 'Cabinets this week.'),
        },
      );

      final index = await builder().build(
        scope: const FrontRoutingScope(allowedCategoryIds: {'work'}),
        now: _now,
      );

      expect(index.projects, hasLength(frontIndexMaxProjects));
      // 52 in scope ('old', 'new' and fifty 'p's); 'private' never counts.
      expect(index.omittedProjects, 2);
      // Newest first before the cap: 'old' (September) is dropped, 'new' kept.
      expect(index.contains(FrontDestinationKind.project, 'old'), isFalse);
      expect(index.contains(FrontDestinationKind.project, 'new'), isTrue);
      expect(index.contains(FrontDestinationKind.project, 'private'), isFalse);
      expect(
        index.row(FrontDestinationKind.project, 'new')!.oneLiner,
        'Cabinets this week.',
      );
      expect(index.row(FrontDestinationKind.project, 'p0')!.oneLiner, isNull);
    });
  });

  group('goals', () {
    test('active goal agents list their statement from the spec head and '
        'their report; other kinds and headless agents are skipped', () async {
      when(
        () => agentRepository.getAgentIdentitiesByLifecycle(
          AgentLifecycle.active,
        ),
      ).thenAnswer(
        (_) async => [
          makeTestIdentity(
            id: 'goal-a',
            agentId: 'goal-a',
            kind: AgentKinds.goalAgent,
          ),
          makeTestIdentity(
            id: 'goal-headless',
            agentId: 'goal-headless',
            kind: AgentKinds.goalAgent,
          ),
          makeTestIdentity(id: 'task-x', agentId: 'task-x'),
        ],
      );
      when(
        () => agentRepository.getEntitiesByIds({
          goalSpecHeadId('goal-a'),
          goalSpecHeadId('goal-headless'),
        }),
      ).thenAnswer(
        (_) async => {goalSpecHeadId('goal-a'): _head('goal-a')},
      );
      when(
        () => agentRepository.getEntitiesByIds({'spec:goal-a'}),
      ).thenAnswer(
        (_) async => {'spec:goal-a': _spec('goal-a', 'Walk 10k steps a day.')},
      );
      when(
        () => agentRepository.getLatestReportsByAgentIds(
          ['goal-a', 'goal-headless'],
          AgentReportScopes.current,
        ),
      ).thenAnswer(
        (_) async => {
          'goal-a': makeTestReport(oneLiner: 'On track this week.'),
        },
      );

      final index = await builder().build(
        scope: const FrontRoutingScope(),
        now: _now,
      );

      expect(index.goals.map((r) => r.id), ['goal-a']);
      final goal = index.goals.single;
      expect(goal.title, 'Walk 10k steps a day.');
      expect(goal.oneLiner, 'On track this week.');
    });

    test('goals are left out when the scope says so', () async {
      final index = await builder().build(
        scope: const FrontRoutingScope(includeGoals: false),
        now: _now,
      );
      expect(index.goals, isEmpty);
      verifyNever(
        () => agentRepository.getAgentIdentitiesByLifecycle(
          AgentLifecycle.active,
        ),
      );
    });
  });

  group('people', () {
    test('are an opt-in: names only, in the allow-list, capped', () async {
      when(() => journalDb.getRelationships()).thenAnswer(
        (_) async => [_person('pip'), _person('hidden', categoryId: 'secret')],
      );

      final without = await builder().build(
        scope: const FrontRoutingScope(allowedCategoryIds: {'work'}),
        now: _now,
      );
      expect(without.people, isEmpty);
      verifyNever(() => journalDb.getRelationships());

      final with_ = await builder().build(
        scope: const FrontRoutingScope(
          allowedCategoryIds: {'work'},
          includePeople: true,
        ),
        now: _now,
      );
      expect(with_.people.map((r) => r.id), ['pip']);
      expect(with_.people.single.title, 'Person pip');
      expect(with_.people.single.oneLiner, isNull);
    });
  });

  group('conversationTasks', () {
    test('rows for the named tasks in the order named, closed ones too, '
        'without what the scope hides or what is gone', () async {
      final done = TaskStatus.done(
        id: 's-done',
        createdAt: _stamp,
        utcOffset: 0,
      );
      final closed = _task('closed');
      final deleted = _task('deleted');
      when(
        () => journalDb.getJournalEntitiesForIds({
          'closed',
          'open',
          'secret',
          'deleted',
          'entry',
        }),
      ).thenAnswer(
        (_) async => [
          _task('open'),
          closed.copyWith(data: closed.data.copyWith(status: done)),
          _task('secret', categoryId: 'secret'),
          deleted.copyWith(
            meta: deleted.meta.copyWith(deletedAt: _stamp),
          ),
          JournalEntity.journalEntry(meta: _meta('entry')),
        ],
      );
      when(
        () =>
            agentRepository.getLatestTaskReportsForTaskIds(['open', 'closed']),
      ).thenAnswer(
        (_) async => {'closed': makeTestReport(oneLiner: 'Pruned.')},
      );

      final rows = await builder().conversationTasks(
        ['closed', 'open', 'secret', 'deleted', 'entry'],
        const FrontRoutingScope(allowedCategoryIds: {'work'}),
      );

      expect(rows.map((r) => r.id), ['closed', 'open']);
      expect(rows.first.status, 'DONE');
      expect(rows.first.oneLiner, 'Pruned.');
    });

    test('leaves out a task in a private category while private entries '
        'are hidden, though the task itself is not private', () async {
      when(() => journalDb.getAllCategories()).thenAnswer(
        (_) async => [CategoryTestUtils.createTestCategory(id: 'work')],
      );
      when(() => journalDb.getAllCategoriesIncludingPrivate()).thenAnswer(
        (_) async => [
          CategoryTestUtils.createTestCategory(id: 'work'),
          CategoryTestUtils.createTestCategory(id: 'diary', private: true),
        ],
      );
      when(
        () => journalDb.getJournalEntitiesForIds({'open', 'inPrivate'}),
      ).thenAnswer(
        (_) async => [_task('open'), _task('inPrivate', categoryId: 'diary')],
      );

      final rows = await builder().conversationTasks(
        ['inPrivate', 'open'],
        const FrontRoutingScope(),
      );

      expect(rows.map((r) => r.id), ['open']);
    });

    test('reads nothing when nothing was named', () async {
      expect(
        await builder().conversationTasks(const [], const FrontRoutingScope()),
        isEmpty,
      );
      verifyNever(() => journalDb.getJournalEntitiesForIds(any()));
    });
  });

  group('corpusMatcher', () {
    test('is null without a full-text index', () {
      expect(
        builder(withFts: false).corpusMatcher(const FrontRoutingScope()),
        isNull,
      );
    });

    test(
      'matches open tasks inside the scope and attaches their reports',
      () async {
        when(
          () => anyMatchIds(fts5Db, 'shed'),
        ).thenAnswer((_) async => ['t9', 'out']);
        when(
          () => journalDb.getJournalEntitiesForIdsUnordered({'t9', 'out'}),
        ).thenAnswer(
          (_) async => [_task('t9'), _task('out', categoryId: 'secret')],
        );
        when(
          () => agentRepository.getLatestTaskReportsForTaskIds(['t9']),
        ).thenAnswer(
          (_) async => {'t9': makeTestReport(oneLiner: 'Roof next.')},
        );

        final matcher = builder().corpusMatcher(
          const FrontRoutingScope(allowedCategoryIds: {'work'}),
        )!;
        final rows = await matcher('shed');

        expect(rows.map((r) => r.id), ['t9']);
        expect(rows.single.kind, FrontDestinationKind.task);
        expect(rows.single.oneLiner, 'Roof next.');
      },
    );
  });

  group('categories', () {
    setUp(() {
      when(() => journalDb.getAllCategories()).thenAnswer(
        (_) async => [
          CategoryTestUtils.createTestCategory(id: 'work', name: 'Work'),
          CategoryTestUtils.createTestCategory(id: 'home', name: 'Home'),
          CategoryTestUtils.createTestCategory(id: 'secret', name: 'Secret'),
          CategoryTestUtils.createTestCategory(
            id: 'old',
            name: 'Old',
            active: false,
          ),
        ],
      );
    });

    test('the index names the active categories in her allow-list, by '
        'name, none chosen without chips', () async {
      final index = await builder().build(
        scope: const FrontRoutingScope(allowedCategoryIds: {'work', 'home'}),
        now: _now,
      );

      expect(
        [for (final c in index.categories) (c.id, c.name, c.chosen)],
        [('home', 'Home', false), ('work', 'Work', false)],
      );
    });

    test('the chips narrow every kind and mark what they chose', () async {
      when(
        () => journalDb.getVisibleProjects(),
      ).thenAnswer(
        (_) async => [_project('pw'), _project('ph', categoryId: 'home')],
      );

      final index = await builder().build(
        scope: const FrontRoutingScope(
          allowedCategoryIds: {'work', 'home'},
          chosenCategoryIds: {'home'},
        ),
        now: _now,
      );

      verify(
        () => journalDb.getOpenTasksForDayAgentCorpus(
          categoryIds: {'home'},
          limit: any(named: 'limit'),
        ),
      ).called(1);
      expect(index.projects.map((r) => r.id), ['ph']);
      expect(
        [for (final c in index.categories) (c.id, c.chosen)],
        [('home', true), ('work', false)],
      );
    });

    test('chips outside the allow-list never widen it', () {
      const scope = FrontRoutingScope(
        allowedCategoryIds: {'work'},
        chosenCategoryIds: {'secret'},
      );
      expect(scope.categoryIds, {'work'});
      expect(
        const FrontRoutingScope(chosenCategoryIds: {'home'}).categoryIds,
        {'home'},
      );
    });
  });

  group('dueTaskLister', () {
    // Today is 2026-10-23: one task overdue, two due today, one due in two
    // days, one in another category.
    setUp(() {
      when(() => journalDb.getTasksDueOnOrBefore(any())).thenAnswer(
        (_) async => [
          _task('b', due: DateTime(2026, 10, 23, 17)),
          _task('late', due: DateTime(2026, 10, 21)),
          _task('a', due: DateTime(2026, 10, 23)),
          _task('soon', due: DateTime(2026, 10, 25, 9)),
          _task('chores', categoryId: 'home', due: DateTime(2026, 10, 22)),
        ],
      );
      when(() => journalDb.getAllCategories()).thenAnswer(
        (_) async => [
          CategoryTestUtils.createTestCategory(id: 'work', name: 'Work'),
          CategoryTestUtils.createTestCategory(id: 'home', name: 'Home'),
        ],
      );
    });

    Future<FrontDueTasks> list(
      FrontDueWindow window, {
      int daysAhead = 0,
      Set<String> categoryIds = const {},
      FrontRoutingScope scope = const FrontRoutingScope(),
    }) => builder().dueTaskLister(scope, now: _now)((
      window: window,
      daysAhead: daysAhead,
      categoryIds: categoryIds,
    ));

    test('today holds what is due today alone, never the overdue', () async {
      final due = await list(FrontDueWindow.today);

      verify(
        () => journalDb.getTasksDueOnOrBefore(DateTime(2026, 10, 23)),
      ).called(1);
      expect(due.window, FrontDueWindow.today);
      expect(due.today, DateTime(2026, 10, 23));
      expect(due.through, due.today);
      expect(due.rows.map((r) => r.id), ['a', 'b']);
      expect(due.rows.first.kind, FrontDestinationKind.task);
      expect(due.rows.first.status, 'OPEN');
    });

    test('overdue holds what was due before today alone', () async {
      final due = await list(FrontDueWindow.overdue, daysAhead: 5);

      // daysAhead does not reach past today for overdue.
      verify(
        () => journalDb.getTasksDueOnOrBefore(DateTime(2026, 10, 23)),
      ).called(1);
      expect(due.rows.map((r) => r.id), ['late', 'chores']);
    });

    test('upcoming reaches the days asked without the overdue; all adds '
        'them, soonest first', () async {
      final upcoming = await list(FrontDueWindow.upcoming, daysAhead: 2);
      expect(upcoming.through, DateTime(2026, 10, 25));
      expect(upcoming.rows.map((r) => r.id), ['a', 'b', 'soon']);

      final all = await list(FrontDueWindow.all, daysAhead: 2);
      expect(all.rows.map((r) => r.id), [
        'late',
        'chores',
        'a',
        'b',
        'soon',
      ]);
      expect(all.categoryNames, {'work': 'Work', 'home': 'Home'});
      expect(all.narrowedTo, isEmpty);
    });

    test('a category named in the question narrows the window', () async {
      final due = await list(FrontDueWindow.overdue, categoryIds: {'home'});

      expect(due.rows.map((r) => r.id), ['chores']);
      expect(due.narrowedTo, ['Home']);
    });

    test('the chips narrow it as well, and a named category inside them '
        'narrows it further', () async {
      const chips = FrontRoutingScope(chosenCategoryIds: {'work'});
      final chosen = await list(FrontDueWindow.overdue, scope: chips);
      expect(chosen.rows.map((r) => r.id), ['late']);

      const both = FrontRoutingScope(chosenCategoryIds: {'work', 'home'});
      final named = await list(
        FrontDueWindow.overdue,
        scope: both,
        categoryIds: {'home'},
      );
      expect(named.rows.map((r) => r.id), ['chores']);
    });

    test('a named category outside the scope never widens it', () async {
      final due = await list(
        FrontDueWindow.overdue,
        scope: const FrontRoutingScope(allowedCategoryIds: {'work'}),
        categoryIds: {'home'},
      );

      expect(due.rows.map((r) => r.id), ['late']);
      expect(due.narrowedTo, isEmpty);
    });

    test('caps the list and counts what it left out', () async {
      when(() => journalDb.getTasksDueOnOrBefore(any())).thenAnswer(
        (_) async => [
          for (var i = 0; i < frontDueTaskLimit + 3; i++)
            _task('t${i.toString().padLeft(2, '0')}', due: _now),
        ],
      );

      final due = await list(FrontDueWindow.today);

      expect(due.rows, hasLength(frontDueTaskLimit));
      expect(due.omitted, 3);
    });
  });

  group('loggedTimeSummarizer', () {
    InsightsTimeRowRecord row(String? categoryId, DateTime from, DateTime to) =>
        (
          entryId: '$categoryId@$from',
          dateFrom: from,
          dateTo: to,
          categoryId: categoryId,
        );

    // Today is Friday 2026-10-23; everything below was logged yesterday.
    setUp(() {
      when(
        () => journalDb.insightsTimeRows(
          start: any(named: 'start'),
          end: any(named: 'end'),
        ),
      ).thenAnswer(
        (_) async => [
          // Started the day before yesterday: only its last 30 minutes count.
          row(
            'work',
            DateTime(2026, 10, 21, 23),
            DateTime(2026, 10, 22, 0, 30),
          ),
          row('work', DateTime(2026, 10, 22, 9), DateTime(2026, 10, 22, 11)),
          // Overlaps the one before it: the shared half hour counts once.
          row(
            'work',
            DateTime(2026, 10, 22, 10),
            DateTime(2026, 10, 22, 11, 30),
          ),
          row('home', DateTime(2026, 10, 22, 20), DateTime(2026, 10, 22, 21)),
          row(null, DateTime(2026, 10, 22, 13), DateTime(2026, 10, 22, 13, 15)),
          // A category deleted since: its time stays, unnamed.
          row(
            'gone',
            DateTime(2026, 10, 22, 14),
            DateTime(2026, 10, 22, 14, 10),
          ),
          // A private category while private entries are hidden: the entry
          // itself is not private, yet none of its time may show.
          row(
            'secret',
            DateTime(2026, 10, 22, 15),
            DateTime(2026, 10, 22, 18),
          ),
        ],
      );
      when(() => journalDb.getAllCategories()).thenAnswer(
        (_) async => [
          CategoryTestUtils.createTestCategory(id: 'work', name: 'Work'),
          CategoryTestUtils.createTestCategory(id: 'home', name: 'Home'),
        ],
      );
      when(() => journalDb.getAllCategoriesIncludingPrivate()).thenAnswer(
        (_) async => [
          CategoryTestUtils.createTestCategory(id: 'work', name: 'Work'),
          CategoryTestUtils.createTestCategory(id: 'home', name: 'Home'),
          CategoryTestUtils.createTestCategory(
            id: 'secret',
            name: 'Secret',
            private: true,
          ),
        ],
      );
      when(() => journalDb.basicLinksForEntryIds(any())).thenAnswer(
        (_) async => const [],
      );
      when(() => journalDb.getJournalEntitiesForIdsUnordered(any())).thenAnswer(
        (_) async => const [],
      );
    });

    EntryLink link(String taskId, String entryId, {bool hidden = false}) =>
        EntryLink.basic(
          id: '$taskId>$entryId',
          fromId: taskId,
          toId: entryId,
          createdAt: _stamp,
          updatedAt: _stamp,
          vectorClock: null,
          hidden: hidden,
        );

    final workMorning = 'work@${DateTime(2026, 10, 22, 9)}';
    final workOverlap = 'work@${DateTime(2026, 10, 22, 10)}';
    final homeEvening = 'home@${DateTime(2026, 10, 22, 20)}';

    void stubTasks() {
      final older = _task('older');
      final newer = _task('newer');
      when(() => journalDb.basicLinksForEntryIds(any())).thenAnswer(
        (_) async => [
          link('older', workMorning),
          link('older', workOverlap),
          // Also linked to the later-started task: the time is the newer's,
          // as the Insights read attributes it.
          link('newer', workOverlap),
          link('home-task', homeEvening),
          // A hidden link attributes nothing.
          link('hidden-task', workMorning, hidden: true),
        ],
      );
      when(() => journalDb.getJournalEntitiesForIdsUnordered(any())).thenAnswer(
        (_) async => [
          older,
          newer.copyWith(
            meta: newer.meta.copyWith(dateFrom: DateTime(2026, 10, 5)),
          ),
          _task('home-task', categoryId: 'home'),
          _task('hidden-task'),
        ],
      );
    }

    test(
      'lists the tasks the time went to, largest first, an entry linked to '
      'two counted for the later started, a hidden link for none',
      () async {
        stubTasks();
        final logged = await builder().loggedTimeSummarizer(
          const FrontRoutingScope(),
          now: _now,
        )((period: FrontTimePeriod.yesterday, categoryIds: const {}));

        expect(
          [for (final task in logged.tasks) (task.row.id, task.seconds)],
          [('older', 2 * 3600), ('newer', 90 * 60), ('home-task', 3600)],
        );
        expect(logged.omittedTasks, 0);
        expect(
          logged.render(),
          contains(
            'Tasks the time went to (3), largest first:\n'
            '- task:older | Task older | OPEN | 2h\n'
            '- task:newer | Task newer | OPEN | 1h 30m\n'
            '- task:home-task | Task home-task | OPEN | 1h',
          ),
        );
      },
    );

    test(
      'a named category keeps its name, every other category and time in '
      'none is one unnamed slice, and only its tasks are listed',
      () async {
        stubTasks();
        final logged = await builder().loggedTimeSummarizer(
          const FrontRoutingScope(),
          now: _now,
        )((period: FrontTimePeriod.yesterday, categoryIds: {'work'}));

        expect(logged.byCategory, [
          (name: 'Work', seconds: 3 * 3600),
          // Home 1h, no category 15m and the deleted one's 10m — never the
          // hidden private category's.
          (name: FrontLoggedTime.otherCategories, seconds: 85 * 60),
        ]);
        expect(logged.named, ['Work']);
        expect(
          [for (final task in logged.tasks) task.row.id],
          [
            'older',
            'newer',
          ],
        );
        expect(logged.chart.namedCategoryIds, {'work'});
        final rendered = logged.render();
        expect(
          rendered,
          contains(
            '(Work named; every other category is "Other categories", '
            'never to be broken down)',
          ),
        );
        expect(rendered, isNot(contains('Home')));
      },
    );

    test(
      'an entry is credited to the task Insights takes its category from: '
      'one with a category before a later-started one without; with none '
      'categorized, the uncategorized one',
      () async {
        final loose = _task('loose', categoryId: null);
        when(() => journalDb.basicLinksForEntryIds(any())).thenAnswer(
          (_) async => [
            link('filed', workMorning),
            link('loose', workMorning),
            link('loose', homeEvening),
          ],
        );
        when(
          () => journalDb.getJournalEntitiesForIdsUnordered(any()),
        ).thenAnswer(
          (_) async => [
            _task('filed'),
            // Started later, but without a category Insights skips it.
            loose.copyWith(
              meta: loose.meta.copyWith(dateFrom: DateTime(2026, 10, 5)),
            ),
          ],
        );

        final logged = await builder().loggedTimeSummarizer(
          const FrontRoutingScope(),
          now: _now,
        )((period: FrontTimePeriod.yesterday, categoryIds: const {}));

        expect(
          [for (final task in logged.tasks) (task.row.id, task.seconds)],
          [('filed', 2 * 3600), ('loose', 3600)],
        );
      },
    );

    test('caps the tasks it lists and counts the rest', () async {
      final ids = [for (var i = 0; i <= frontLoggedTaskLimit; i++) 't$i'];
      when(
        () => journalDb.insightsTimeRows(
          start: any(named: 'start'),
          end: any(named: 'end'),
        ),
      ).thenAnswer(
        (_) async => [
          for (final (i, id) in ids.indexed)
            (
              entryId: 'e-$id',
              dateFrom: DateTime(2026, 10, 22, 0, i),
              dateTo: DateTime(2026, 10, 22, 0, i + 1),
              categoryId: 'work',
            ),
        ],
      );
      when(() => journalDb.basicLinksForEntryIds(any())).thenAnswer(
        (_) async => [for (final id in ids) link(id, 'e-$id')],
      );
      when(() => journalDb.getJournalEntitiesForIdsUnordered(any())).thenAnswer(
        (_) async => [for (final id in ids) _task(id)],
      );

      final logged = await builder().loggedTimeSummarizer(
        const FrontRoutingScope(),
        now: _now,
      )((period: FrontTimePeriod.yesterday, categoryIds: const {}));

      expect(logged.tasks, hasLength(frontLoggedTaskLimit));
      expect(logged.omittedTasks, 1);
      expect(logged.render(), contains('(30, +1 not shown)'));
    });

    test(
      "yesterday reads yesterday's local day and sums each category, "
      'largest first, overlaps once, a hidden private category never',
      () async {
        final logged = await builder().loggedTimeSummarizer(
          const FrontRoutingScope(),
          now: _now,
        )((period: FrontTimePeriod.yesterday, categoryIds: const {}));

        verify(
          () => journalDb.insightsTimeRows(
            start: DateTime(2026, 10, 22),
            end: DateTime(2026, 10, 23),
          ),
        ).called(1);
        expect(logged.period, FrontTimePeriod.yesterday);
        expect(logged.from, DateTime(2026, 10, 22));
        expect(logged.through, DateTime(2026, 10, 22));
        expect(logged.byCategory, [
          (name: 'Work', seconds: 3 * 3600),
          (name: 'Home', seconds: 3600),
          (name: null, seconds: 15 * 60),
          (name: 'Unnamed', seconds: 10 * 60),
        ]);
        // Her reply's chart covers the same day, in every category.
        expect(
          logged.chart,
          FrontLoggedTimeChart(
            range: InsightsRange(
              startDay: epochDay(DateTime(2026, 10, 22)),
              endDayExclusive: epochDay(DateTime(2026, 10, 23)),
            ),
            categoryIds: const {},
          ),
        );
      },
    );

    test('time outside the scope, and in no category once it is narrowed, '
        'is left out', () async {
      for (final scope in const [
        FrontRoutingScope(allowedCategoryIds: {'work'}),
        FrontRoutingScope(chosenCategoryIds: {'work'}),
      ]) {
        final logged = await builder().loggedTimeSummarizer(
          scope,
          now: _now,
        )((period: FrontTimePeriod.yesterday, categoryIds: const {}));
        expect(logged.byCategory, [(name: 'Work', seconds: 3 * 3600)]);
        expect(logged.chart.categoryIds, {'work'});
      }
    });

    test("this week starts on the region's first weekday, Monday without "
        'one, and ends today', () async {
      final sunday =
          await builder(
            firstDayOfWeekIndex: () async => 0,
          ).loggedTimeSummarizer(const FrontRoutingScope(), now: _now)((
            period: FrontTimePeriod.thisWeek,
            categoryIds: const {},
          ));
      verify(
        () => journalDb.insightsTimeRows(
          start: DateTime(2026, 10, 18),
          end: DateTime(2026, 10, 24),
        ),
      ).called(1);
      expect(sunday.through, DateTime(2026, 10, 23));
      // The row from the day before yesterday now counts whole.
      expect(sunday.byCategory.first, (name: 'Work', seconds: 3 * 3600 + 3600));

      final monday = await builder().loggedTimeSummarizer(
        const FrontRoutingScope(),
        now: _now,
      )((period: FrontTimePeriod.thisWeek, categoryIds: const {}));
      expect(monday.from, DateTime(2026, 10, 19));
    });
  });

  group('closedTaskLister', () {
    // Today is Friday 2026-10-23, 09:00; yesterday is the 22nd and the past
    // seven days run from the 17th.
    DateTime oct(int day, [int hour = 12]) => DateTime(2026, 10, day, hour);

    setUp(() {
      when(() => journalDb.getAllCategories()).thenAnswer(
        (_) async => [
          CategoryTestUtils.createTestCategory(id: 'work', name: 'Work'),
          CategoryTestUtils.createTestCategory(id: 'home', name: 'Home'),
        ],
      );
    });

    void closedSince(List<Task> tasks) => when(
      () => journalDb.getTasksUpdatedSince(any()),
    ).thenAnswer((_) async => tasks);

    Future<FrontClosedTasks> list(
      FrontTimePeriod period, {
      Set<String> categoryIds = const {},
      FrontRoutingScope scope = const FrontRoutingScope(),
    }) => builder().closedTaskLister(scope, now: _now)((
      period: period,
      range: null,
    ), categoryIds);

    // Days the call spelled out, both included.
    Future<FrontClosedTasks> listDays(
      DateTime first,
      DateTime last, {
      DateTime? now,
      Set<String> categoryIds = const {},
    }) =>
        builder().closedTaskLister(const FrontRoutingScope(), now: now ?? _now)(
          (
            period: null,
            range: InsightsRange(
              startDay: epochDay(first),
              endDayExclusive: epochDay(last) + 1,
            ),
          ),
          categoryIds,
        );

    List<(String, String, DateTime)> closings(FrontClosedTasks closed) => [
      for (final (:row, :closed) in closed.tasks)
        (row.id, closed.toDbString, closed.createdAt),
    ];

    test('today lists what was completed today, not yesterday, and reads '
        'from the start of the window', () async {
      closedSince([
        _historyTask('today', [('open', oct(1)), ('done', oct(23, 8))]),
        _historyTask('yesterday', [('open', oct(1)), ('done', oct(22, 17))]),
      ]);

      final closed = await list(FrontTimePeriod.today);

      verify(
        () => journalDb.getTasksUpdatedSince(DateTime(2026, 10, 23)),
      ).called(1);
      expect(closings(closed), [('today', 'DONE', oct(23, 8))]);
      expect(closed.from, DateTime(2026, 10, 23));
      expect(closed.through, DateTime(2026, 10, 23));
      expect(closed.tasks.single.row.kind, FrontDestinationKind.task);
    });

    test('the past seven days reach back to the 17th and no further, '
        'oldest first', () async {
      closedSince([
        _historyTask('wed', [('open', oct(1)), ('done', oct(21))]),
        _historyTask('sat', [('open', oct(1)), ('done', oct(17, 0))]),
        _historyTask('fri', [('open', oct(1)), ('done', oct(16, 23))]),
      ]);

      final closed = await list(FrontTimePeriod.past7Days);

      verify(
        () => journalDb.getTasksUpdatedSince(DateTime(2026, 10, 17)),
      ).called(1);
      expect(closings(closed), [
        ('sat', 'DONE', oct(17, 0)),
        ('wed', 'DONE', oct(21)),
      ]);
      expect(closed.from, DateTime(2026, 10, 17));
      expect(closed.through, DateTime(2026, 10, 23));
    });

    test(
      'a task created months ago counts on the day it was completed',
      () async {
        closedSince([
          _historyTask(
            'old',
            [('open', DateTime(2026, 5, 2)), ('done', oct(22, 10))],
            createdAt: DateTime(2026, 5, 2),
          ),
          // Created yesterday, completed long before: never in the window.
          _historyTask(
            'new',
            [('open', DateTime(2026, 4, 2)), ('done', DateTime(2026, 4, 3))],
            createdAt: oct(22),
          ),
        ]);

        final closed = await list(FrontTimePeriod.yesterday);

        expect(closings(closed), [('old', 'DONE', oct(22, 10))]);
      },
    );

    test('a task reopened and completed again reports its latest '
        'completion in the window', () async {
      closedSince([
        // Completed, reopened, completed again: both inside the week.
        _historyTask('twice', [
          ('open', oct(1)),
          ('done', oct(18)),
          ('open', oct(19)),
          ('done', oct(21)),
        ]),
        // Completed before the week, reopened and completed inside it.
        _historyTask('again', [
          ('open', oct(1)),
          ('done', oct(10)),
          ('open', oct(18)),
          ('done', oct(20)),
        ]),
        // Rejected, reopened and completed: it was completed.
        _historyTask('changed', [
          ('open', oct(1)),
          ('rejected', oct(18)),
          ('open', oct(19)),
          ('done', oct(19, 15)),
        ]),
      ]);

      final closed = await list(FrontTimePeriod.past7Days);

      expect(closings(closed), [
        ('changed', 'DONE', oct(19, 15)),
        ('again', 'DONE', oct(20)),
        ('twice', 'DONE', oct(21)),
      ]);
    });

    test('any close inside the window counts, even one reopened since, and '
        'each window reports its own latest close', () async {
      closedSince([
        // Completed yesterday, reopened, rejected today.
        _historyTask('reopened', [
          ('open', oct(1)),
          ('done', oct(22, 9)),
          ('open', oct(22, 10)),
          ('rejected', oct(23, 8)),
        ]),
        // Completed yesterday and again today: yesterday keeps its close.
        _historyTask('both', [
          ('open', oct(1)),
          ('done', oct(22, 11)),
          ('open', oct(23, 7)),
          ('done', oct(23, 8)),
        ]),
        // Completed yesterday, reopened today and still open.
        _historyTask('undone', [
          ('open', oct(1)),
          ('done', oct(22, 15)),
          ('open', oct(23, 7)),
        ]),
      ]);

      final yesterday = await list(FrontTimePeriod.yesterday);
      expect(closings(yesterday), [
        ('reopened', 'DONE', oct(22, 9)),
        ('both', 'DONE', oct(22, 11)),
        ('undone', 'DONE', oct(22, 15)),
      ]);
      // Open now: the card and the tool's line say it was reopened since.
      expect(
        {for (final card in yesterday.cards) card.id: card.reopened},
        {'reopened': false, 'both': false, 'undone': true},
      );
      expect(
        yesterday.render(),
        contains(
          'task:undone | Task undone | completed 2026-10-22 | '
          'reopened since | Work',
        ),
      );
      expect(closings(await list(FrontTimePeriod.today)), [
        ('both', 'DONE', oct(23, 8)),
        ('reopened', 'REJECTED', oct(23, 8)),
      ]);
    });

    test(
      'a reopened task with no close inside the window is not listed',
      () async {
        closedSince([
          // Completed last month, reopened yesterday and still open.
          _historyTask('stale', [
            ('open', oct(1)),
            ('done', oct(2)),
            ('open', oct(22)),
          ]),
        ]);

        final closed = await list(FrontTimePeriod.past7Days);

        expect(closed.tasks, isEmpty);
        expect(
          closed.render(),
          'None: no task completed or rejected past 7 days '
          '(2026-10-17 through 2026-10-23).',
        );
      },
    );

    test('the window runs from its first local midnight, included, to the '
        'midnight after its last day, excluded', () async {
      closedSince([
        _historyTask('first', [('open', oct(1)), ('done', oct(22, 0))]),
        _historyTask('last', [
          ('open', oct(1)),
          ('done', DateTime(2026, 10, 22, 23, 59, 59, 999)),
        ]),
        _historyTask('before', [
          ('open', oct(1)),
          ('done', DateTime(2026, 10, 21, 23, 59, 59, 999)),
        ]),
        _historyTask('after', [('open', oct(1)), ('done', oct(23, 0))]),
        // Stored in UTC, as a synced status may be: compared as an instant.
        _historyTask('utc', [
          ('open', oct(1)),
          ('done', DateTime(2026, 10, 22, 12).toUtc()),
        ]),
      ]);

      final closed = await list(FrontTimePeriod.yesterday);

      expect(closed.tasks.map((t) => t.row.id), ['first', 'utc', 'last']);
    });

    test('this weekend, asked on its Sunday, lists every task completed or '
        'rejected on the Saturday and the Sunday — none missing', () async {
      // Sunday 2026-11-08, 18:00: the bug report's question.
      final sunday = DateTime(2026, 11, 8, 18);
      DateTime nov(int day, [int hour = 12]) => DateTime(2026, 11, day, hour);
      closedSince([
        _historyTask('sat-morning', [('open', oct(1)), ('done', nov(7, 9))]),
        _historyTask('sat-night', [
          ('open', oct(1)),
          ('done', DateTime(2026, 11, 7, 23, 58)),
        ]),
        _historyTask('sun-early', [('open', oct(1)), ('done', nov(8, 0))]),
        _historyTask('sun-dropped', [
          ('open', oct(1)),
          ('rejected', nov(8, 10)),
        ]),
        // Created in May, completed on Saturday.
        _historyTask(
          'old',
          [('open', DateTime(2026, 5, 2)), ('done', nov(7, 15))],
          createdAt: DateTime(2026, 5, 2),
        ),
        // Completed on Saturday, reopened on Sunday.
        _historyTask('reopened', [
          ('open', oct(1)),
          ('done', nov(7, 16)),
          ('open', nov(8, 9)),
        ]),
        // Completed twice over the weekend: the latest counts.
        _historyTask('twice', [
          ('open', oct(1)),
          ('done', nov(7, 11)),
          ('open', nov(7)),
          ('done', nov(8, 14)),
        ]),
        // Friday evening: outside.
        _historyTask('friday', [
          ('open', oct(1)),
          ('done', DateTime(2026, 11, 6, 23, 59)),
        ]),
        // Many more on Saturday afternoon than the answer names.
        for (var i = 0; i < frontClosedTaskLimit; i++)
          _historyTask('bulk-$i', [('open', oct(1)), ('done', nov(7, 13))]),
      ]);

      final closed = await listDays(nov(7), nov(8), now: sunday);

      verify(
        () => journalDb.getTasksUpdatedSince(DateTime(2026, 11, 7)),
      ).called(1);
      final ids = closed.tasks.map((t) => t.row.id).toList();
      expect(ids, hasLength(7 + frontClosedTaskLimit));
      expect(ids, isNot(contains('friday')));
      expect(ids.take(5), [
        'sat-morning',
        'bulk-0',
        'bulk-1',
        'bulk-10',
        'bulk-11',
      ]);
      expect(ids.skip(ids.length - 6), [
        'old',
        'reopened',
        'sat-night',
        'sun-early',
        'sun-dropped',
        'twice',
      ]);
      expect(closed.cards, hasLength(closed.tasks.length));
      expect(closed.period, isNull);
      expect(closed.from, DateTime(2026, 11, 7));
      expect(closed.through, DateTime(2026, 11, 8));
      // Her words get the count and the first rows; the cards get all.
      final render = closed.render();
      expect(
        render,
        startsWith(
          'Tasks completed or rejected 2026-11-07 through 2026-11-08: 37 '
          '(36 completed, 1 rejected; 7 more not shown here, all on the '
          'cards), oldest first:\n',
        ),
      );
      expect(
        '- task:'.allMatches(render),
        hasLength(frontClosedTaskLimit),
      );
    });

    test('a weekend narrowed to a named category lists every task of it '
        'closed then, and none of another', () async {
      DateTime nov(int day, [int hour = 12]) => DateTime(2026, 11, day, hour);
      closedSince([
        _historyTask('lotti-1', [('open', oct(1)), ('done', nov(7))]),
        _historyTask('lotti-2', [('open', oct(1)), ('rejected', nov(8))]),
        _historyTask(
          'chores',
          [('open', oct(1)), ('done', nov(8))],
          categoryId: 'home',
        ),
      ]);

      final closed = await listDays(
        nov(7),
        nov(8),
        now: nov(8, 18),
        categoryIds: {'work'},
      );

      expect(closings(closed), [
        ('lotti-1', 'DONE', nov(7)),
        ('lotti-2', 'REJECTED', nov(8)),
      ]);
      expect(closed.narrowedTo, ['Work']);
      expect(
        closed.render(),
        startsWith(
          'Tasks completed or rejected 2026-11-07 through 2026-11-08 in '
          'Work: 2 (1 completed, 1 rejected), oldest first:',
        ),
      );
    });

    test('completed and rejected come back in one list, each with what '
        'happened to it', () async {
      closedSince([
        _historyTask('shipped', [('open', oct(1)), ('done', oct(20))]),
        _historyTask('dropped', [('open', oct(1)), ('rejected', oct(21))]),
        _historyTask(
          'chores',
          [('open', oct(1)), ('done', oct(22))],
          categoryId: 'home',
        ),
      ]);

      final closed = await list(FrontTimePeriod.past7Days);

      expect(closings(closed), [
        ('shipped', 'DONE', oct(20)),
        ('dropped', 'REJECTED', oct(21)),
        ('chores', 'DONE', oct(22)),
      ]);
      expect(closed.categoryNames, {'work': 'Work', 'home': 'Home'});
    });

    test(
      'a task whose history was never kept closes at its current status',
      () async {
        closedSince([
          _historyTask('legacy', [('done', oct(22))], keepHistory: false),
        ]);

        expect(closings(await list(FrontTimePeriod.yesterday)), [
          ('legacy', 'DONE', oct(22)),
        ]);
      },
    );

    test('a named category narrows it, never widens the scope, and a '
        'private category stays hidden', () async {
      when(() => journalDb.getAllCategoriesIncludingPrivate()).thenAnswer(
        (_) async => [
          CategoryTestUtils.createTestCategory(id: 'work'),
          CategoryTestUtils.createTestCategory(id: 'home'),
          CategoryTestUtils.createTestCategory(id: 'diary', private: true),
        ],
      );
      closedSince([
        _historyTask('work', [('open', oct(1)), ('done', oct(20))]),
        _historyTask(
          'home',
          [('open', oct(1)), ('done', oct(21))],
          categoryId: 'home',
        ),
        _historyTask(
          'diary',
          [('open', oct(1)), ('done', oct(21))],
          categoryId: 'diary',
        ),
      ]);

      final all = await list(FrontTimePeriod.past7Days);
      expect(all.tasks.map((t) => t.row.id), ['work', 'home']);

      final named = await list(
        FrontTimePeriod.past7Days,
        categoryIds: {'home'},
      );
      expect(named.tasks.map((t) => t.row.id), ['home']);
      expect(named.narrowedTo, ['Home']);

      final outside = await list(
        FrontTimePeriod.past7Days,
        scope: const FrontRoutingScope(allowedCategoryIds: {'work'}),
        categoryIds: {'home'},
      );
      expect(outside.tasks.map((t) => t.row.id), ['work']);
      expect(outside.narrowedTo, isEmpty);
    });

    test('keeps every task for the cards and caps only the lines her '
        'answer reads', () async {
      closedSince([
        for (var i = 0; i < frontClosedTaskLimit + 2; i++)
          _historyTask('t$i', [('open', oct(1)), ('done', oct(22))]),
      ]);

      final closed = await list(FrontTimePeriod.yesterday);

      expect(closed.tasks, hasLength(frontClosedTaskLimit + 2));
      expect(closed.cards, hasLength(frontClosedTaskLimit + 2));
      expect(
        '- task:'.allMatches(closed.render()),
        hasLength(frontClosedTaskLimit),
      );
      expect(closed.render(), contains('2 more not shown here'));
    });
  });

  group('pullRequestSummarizer', () {
    PullRequestStatRowRecord row(
      String key,
      DateTime createdAt, {
      String? author = 'pingu',
      String? category = 'work',
    }) => (
      entryId: 'entry-$key',
      key: key,
      taskCategoryId: category,
      title: 'Title $key',
      authorLogin: author,
      createdAt: createdAt,
      mergedAt: null,
      additions: 10,
      deletions: 2,
    );

    setUp(() {
      when(() => journalDb.getAllCategories()).thenAnswer(
        (_) async => [
          CategoryTestUtils.createTestCategory(id: 'work', name: 'Work'),
          CategoryTestUtils.createTestCategory(id: 'home', name: 'Home'),
        ],
      );
      when(() => journalDb.pullRequestStatRows()).thenAnswer(
        (_) async => [
          // Sunday the 18th, Monday the 19th, and Monday the 19th at home.
          row('p/c#1', DateTime(2026, 10, 18, 10)),
          row('p/c#2', DateTime(2026, 10, 19, 10)),
          row('p/c#3', DateTime(2026, 10, 19, 11), category: 'home'),
          row('p/c#4', DateTime(2026, 10, 20, 10), author: 'robby'),
        ],
      );
    });

    test('a named period starts on the first weekday, reads the scope and '
        "counts the user's own pull requests", () async {
      final summary =
          await builder(
            firstDayOfWeekIndex: () async => 0,
            githubLogin: () async => 'pingu',
          ).pullRequestSummarizer(
            const FrontRoutingScope(allowedCategoryIds: {'work'}),
            now: _now,
          )((period: FrontTimePeriod.thisWeek, range: null));

      expect(summary.period, FrontTimePeriod.thisWeek);
      expect(
        summary.chart,
        FrontPullRequestChart(
          range: InsightsRange(
            startDay: epochDay(DateTime(2026, 10, 18)),
            endDayExclusive: epochDay(DateTime(2026, 10, 24)),
          ),
          categoryIds: const {'work'},
          authorLogin: 'pingu',
        ),
      );
      expect(summary.pullRequests.map((pr) => pr.key), ['p/c#2', 'p/c#1']);
    });

    test('days the call spelled out are read as given, every author counted '
        'while no login is known', () async {
      final range = InsightsRange(
        startDay: epochDay(DateTime(2026, 10, 19)),
        endDayExclusive: epochDay(DateTime(2026, 10, 21)),
      );
      final summary = await builder().pullRequestSummarizer(
        const FrontRoutingScope(),
        now: _now,
      )((period: null, range: range));

      expect(summary.period, isNull);
      expect(summary.chart.range, range);
      expect(summary.chart.authorLogin, isNull);
      expect(summary.pullRequests.map((pr) => pr.key), [
        'p/c#4',
        'p/c#3',
        'p/c#2',
      ]);
    });
  });
}
