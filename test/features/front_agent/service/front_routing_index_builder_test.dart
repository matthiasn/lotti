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
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_routing_index.dart';
import 'package:lotti/features/front_agent/service/front_routing_index_builder.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../helpers/fts5_stubs.dart';
import '../../../mocks/mocks.dart';
import '../../agents/test_data/entity_factories.dart';

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

  FrontRoutingIndexBuilder builder({bool withFts = true}) =>
      FrontRoutingIndexBuilder(
        journalDb: journalDb,
        agentRepository: agentRepository,
        fts5Db: withFts ? fts5Db : null,
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
        scope: const FrontRoutingScope(categoryIds: {'work'}),
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
        scope: const FrontRoutingScope(categoryIds: {'work'}),
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
        scope: const FrontRoutingScope(categoryIds: {'work'}),
        now: _now,
      );
      expect(without.people, isEmpty);
      verifyNever(() => journalDb.getRelationships());

      final with_ = await builder().build(
        scope: const FrontRoutingScope(
          categoryIds: {'work'},
          includePeople: true,
        ),
        now: _now,
      );
      expect(with_.people.map((r) => r.id), ['pip']);
      expect(with_.people.single.title, 'Person pip');
      expect(with_.people.single.oneLiner, isNull);
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
          const FrontRoutingScope(categoryIds: {'work'}),
        )!;
        final rows = await matcher('shed');

        expect(rows.map((r) => r.id), ['t9']);
        expect(rows.single.kind, FrontDestinationKind.task);
        expect(rows.single.oneLiner, 'Roof next.');
      },
    );
  });
}
