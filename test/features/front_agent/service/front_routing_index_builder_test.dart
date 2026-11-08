import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/agents/agent_link.dart';
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
  }) => FrontRoutingIndexBuilder(
    journalDb: journalDb,
    agentRepository: agentRepository,
    fts5Db: withFts ? fts5Db : null,
    firstDayOfWeekIndex: firstDayOfWeekIndex,
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
    });

    test(
      "yesterday reads yesterday's local day and sums each category, "
      'largest first, overlaps once, a hidden private category never',
      () async {
        final logged = await builder().loggedTimeSummarizer(
          const FrontRoutingScope(),
          now: _now,
        )(FrontTimePeriod.yesterday);

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
        )(FrontTimePeriod.yesterday);
        expect(logged.byCategory, [(name: 'Work', seconds: 3 * 3600)]);
        expect(logged.chart.categoryIds, {'work'});
      }
    });

    test("this week starts on the region's first weekday, Monday without "
        'one, and ends today', () async {
      final sunday =
          await builder(
            firstDayOfWeekIndex: () async => 0,
          ).loggedTimeSummarizer(const FrontRoutingScope(), now: _now)(
            FrontTimePeriod.thisWeek,
          );
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
      )(FrontTimePeriod.thisWeek);
      expect(monday.from, DateTime(2026, 10, 19));
    });
  });
}
