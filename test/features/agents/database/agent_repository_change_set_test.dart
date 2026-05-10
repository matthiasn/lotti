import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart' as model;
import 'package:lotti/features/agents/model/change_set.dart';

import '../test_utils.dart';

enum _GeneratedChangeAgentSlot { target, other }

enum _GeneratedChangeTaskSlot { target, other }

enum _GeneratedChangeTemplateSlot { target, other }

final _generatedChangeBase = DateTime(2026, 5, 15, 12);
final _generatedChangeSince = DateTime(2026, 5, 15, 12);

const String _generatedChangeTargetAgentId = 'generated-change-agent-target';
const String _generatedChangeOtherAgentId = 'generated-change-agent-other';
const String _generatedChangeTargetTaskId = 'generated-change-task-target';
const String _generatedChangeOtherTaskId = 'generated-change-task-other';
const String _generatedChangeTargetTemplateId =
    'generated-change-template-target';
const String _generatedChangeOtherTemplateId =
    'generated-change-template-other';

class _GeneratedChangeSetSpec {
  const _GeneratedChangeSetSpec({
    required this.agentSlot,
    required this.taskSlot,
    required this.status,
    required this.deleted,
    required this.createdMinuteOffset,
    required this.seed,
  });

  final _GeneratedChangeAgentSlot agentSlot;
  final _GeneratedChangeTaskSlot taskSlot;
  final ChangeSetStatus status;
  final bool deleted;
  final int createdMinuteOffset;
  final int seed;

  String idAt(int index) => 'generated-change-set-$index-$seed';

  String get agentId => switch (agentSlot) {
    _GeneratedChangeAgentSlot.target => _generatedChangeTargetAgentId,
    _GeneratedChangeAgentSlot.other => _generatedChangeOtherAgentId,
  };

  String get taskId => switch (taskSlot) {
    _GeneratedChangeTaskSlot.target => _generatedChangeTargetTaskId,
    _GeneratedChangeTaskSlot.other => _generatedChangeOtherTaskId,
  };

  bool get isPendingLike {
    return status == ChangeSetStatus.pending ||
        status == ChangeSetStatus.partiallyResolved;
  }

  DateTime createdAt(int index) {
    return _generatedChangeBase.add(
      Duration(minutes: createdMinuteOffset, seconds: index),
    );
  }

  DateTime? deletedAt(int index) {
    return deleted ? createdAt(index).add(const Duration(minutes: 1)) : null;
  }

  @override
  String toString() {
    return '_GeneratedChangeSetSpec('
        'agentSlot: $agentSlot, taskSlot: $taskSlot, status: $status, '
        'deleted: $deleted, createdMinuteOffset: $createdMinuteOffset, '
        'seed: $seed)';
  }
}

class _GeneratedChangeDecisionSpec {
  const _GeneratedChangeDecisionSpec({
    required this.agentSlot,
    required this.taskSlot,
    required this.verdict,
    required this.deleted,
    required this.createdMinuteOffset,
    required this.seed,
  });

  final _GeneratedChangeAgentSlot agentSlot;
  final _GeneratedChangeTaskSlot taskSlot;
  final ChangeDecisionVerdict verdict;
  final bool deleted;
  final int createdMinuteOffset;
  final int seed;

  String idAt(int index) => 'generated-change-decision-$index-$seed';

  String get agentId => switch (agentSlot) {
    _GeneratedChangeAgentSlot.target => _generatedChangeTargetAgentId,
    _GeneratedChangeAgentSlot.other => _generatedChangeOtherAgentId,
  };

  String get taskId => switch (taskSlot) {
    _GeneratedChangeTaskSlot.target => _generatedChangeTargetTaskId,
    _GeneratedChangeTaskSlot.other => _generatedChangeOtherTaskId,
  };

  DateTime createdAt(int index) {
    return _generatedChangeBase.add(
      Duration(minutes: createdMinuteOffset, seconds: index),
    );
  }

  DateTime? deletedAt(int index) {
    return deleted ? createdAt(index).add(const Duration(minutes: 1)) : null;
  }

  @override
  String toString() {
    return '_GeneratedChangeDecisionSpec('
        'agentSlot: $agentSlot, taskSlot: $taskSlot, verdict: $verdict, '
        'deleted: $deleted, createdMinuteOffset: $createdMinuteOffset, '
        'seed: $seed)';
  }
}

class _GeneratedChangeTemplateAssignmentSpec {
  const _GeneratedChangeTemplateAssignmentSpec({
    required this.templateSlot,
    required this.agentSlot,
    required this.deleted,
    required this.createdMinuteOffset,
  });

  final _GeneratedChangeTemplateSlot templateSlot;
  final _GeneratedChangeAgentSlot agentSlot;
  final bool deleted;
  final int createdMinuteOffset;

  String get id =>
      'generated-change-assignment-${templateSlot.name}-${agentSlot.name}';

  String get templateId => switch (templateSlot) {
    _GeneratedChangeTemplateSlot.target => _generatedChangeTargetTemplateId,
    _GeneratedChangeTemplateSlot.other => _generatedChangeOtherTemplateId,
  };

  String get agentId => switch (agentSlot) {
    _GeneratedChangeAgentSlot.target => _generatedChangeTargetAgentId,
    _GeneratedChangeAgentSlot.other => _generatedChangeOtherAgentId,
  };

  DateTime get createdAt {
    return _generatedChangeBase.add(
      Duration(minutes: createdMinuteOffset),
    );
  }

  DateTime? get deletedAt {
    return deleted ? createdAt.add(const Duration(minutes: 1)) : null;
  }

  @override
  String toString() {
    return '_GeneratedChangeTemplateAssignmentSpec('
        'templateSlot: $templateSlot, agentSlot: $agentSlot, '
        'deleted: $deleted, createdMinuteOffset: $createdMinuteOffset)';
  }
}

class _GeneratedChangeQueryScenario {
  const _GeneratedChangeQueryScenario({
    required this.changeSets,
    required this.decisions,
    required this.assignments,
    required this.pendingLimit,
    required this.decisionLimit,
    required this.templateDecisionLimit,
  });

  final List<_GeneratedChangeSetSpec> changeSets;
  final List<_GeneratedChangeDecisionSpec> decisions;
  final List<_GeneratedChangeTemplateAssignmentSpec> assignments;
  final int pendingLimit;
  final int decisionLimit;
  final int templateDecisionLimit;

  Iterable<_GeneratedChangeAgentSlot> get _targetTemplateAgentSlots {
    final finalAssignmentsByNaturalKey =
        <String, _GeneratedChangeTemplateAssignmentSpec>{};
    for (final assignment in assignments) {
      final key =
          '${assignment.templateSlot.name}:${assignment.agentSlot.name}';
      finalAssignmentsByNaturalKey[key] = assignment;
    }

    return finalAssignmentsByNaturalKey.values
        .where(
          (assignment) =>
              assignment.templateSlot == _GeneratedChangeTemplateSlot.target &&
              !assignment.deleted,
        )
        .map((assignment) => assignment.agentSlot);
  }

  List<int> _sortedChangeSetIndexes(Iterable<int> indexes) {
    return indexes.toList()..sort(
      (a, b) => changeSets[b]
          .createdAt(b)
          .compareTo(
            changeSets[a].createdAt(a),
          ),
    );
  }

  List<int> _sortedDecisionIndexes(Iterable<int> indexes) {
    return indexes.toList()..sort(
      (a, b) => decisions[b]
          .createdAt(b)
          .compareTo(
            decisions[a].createdAt(a),
          ),
    );
  }

  List<String> expectedPendingIds({required int limit}) {
    return _sortedChangeSetIndexes(
      Iterable<int>.generate(changeSets.length).where(
        (index) =>
            changeSets[index].agentSlot == _GeneratedChangeAgentSlot.target &&
            changeSets[index].taskSlot == _GeneratedChangeTaskSlot.target &&
            changeSets[index].isPendingLike &&
            !changeSets[index].deleted,
      ),
    ).take(limit).map((index) => changeSets[index].idAt(index)).toList();
  }

  List<String> expectedRecentDecisionIds({required int limit}) {
    return _sortedDecisionIndexes(
      Iterable<int>.generate(decisions.length).where(
        (index) =>
            decisions[index].agentSlot == _GeneratedChangeAgentSlot.target &&
            decisions[index].taskSlot == _GeneratedChangeTaskSlot.target &&
            !decisions[index].deleted,
      ),
    ).take(limit).map((index) => decisions[index].idAt(index)).toList();
  }

  List<String> expectedTemplateDecisionIds({required int limit}) {
    final activeAgentSlots = _targetTemplateAgentSlots.toSet();
    return _sortedDecisionIndexes(
      Iterable<int>.generate(decisions.length).where(
        (index) =>
            activeAgentSlots.contains(decisions[index].agentSlot) &&
            !decisions[index].deleted &&
            !decisions[index].createdAt(index).isBefore(_generatedChangeSince),
      ),
    ).take(limit).map((index) => decisions[index].idAt(index)).toList();
  }

  @override
  String toString() {
    return '_GeneratedChangeQueryScenario('
        'pendingLimit: $pendingLimit, decisionLimit: $decisionLimit, '
        'templateDecisionLimit: $templateDecisionLimit, '
        'changeSets: $changeSets, decisions: $decisions, '
        'assignments: $assignments)';
  }
}

extension _AnyGeneratedChangeQueryScenario on glados.Any {
  glados.Generator<_GeneratedChangeAgentSlot> get changeAgentSlot =>
      glados.AnyUtils(this).choose(_GeneratedChangeAgentSlot.values);

  glados.Generator<_GeneratedChangeTaskSlot> get changeTaskSlot =>
      glados.AnyUtils(this).choose(_GeneratedChangeTaskSlot.values);

  glados.Generator<_GeneratedChangeTemplateSlot> get changeTemplateSlot =>
      glados.AnyUtils(this).choose(_GeneratedChangeTemplateSlot.values);

  glados.Generator<ChangeSetStatus> get changeSetStatus =>
      glados.AnyUtils(this).choose(ChangeSetStatus.values);

  glados.Generator<ChangeDecisionVerdict> get changeDecisionVerdict =>
      glados.AnyUtils(this).choose(ChangeDecisionVerdict.values);

  glados.Generator<_GeneratedChangeSetSpec> get changeSetSpec =>
      glados.CombinableAny(this).combine6(
        changeAgentSlot,
        changeTaskSlot,
        changeSetStatus,
        glados.AnyUtils(this).choose([false, true]),
        glados.IntAnys(this).intInRange(-4, 4),
        glados.IntAnys(this).intInRange(0, 10000),
        (
          _GeneratedChangeAgentSlot agentSlot,
          _GeneratedChangeTaskSlot taskSlot,
          ChangeSetStatus status,
          bool deleted,
          int createdMinuteOffset,
          int seed,
        ) => _GeneratedChangeSetSpec(
          agentSlot: agentSlot,
          taskSlot: taskSlot,
          status: status,
          deleted: deleted,
          createdMinuteOffset: createdMinuteOffset,
          seed: seed,
        ),
      );

  glados.Generator<_GeneratedChangeDecisionSpec> get changeDecisionSpec =>
      glados.CombinableAny(this).combine6(
        changeAgentSlot,
        changeTaskSlot,
        changeDecisionVerdict,
        glados.AnyUtils(this).choose([false, true]),
        glados.IntAnys(this).intInRange(-4, 4),
        glados.IntAnys(this).intInRange(0, 10000),
        (
          _GeneratedChangeAgentSlot agentSlot,
          _GeneratedChangeTaskSlot taskSlot,
          ChangeDecisionVerdict verdict,
          bool deleted,
          int createdMinuteOffset,
          int seed,
        ) => _GeneratedChangeDecisionSpec(
          agentSlot: agentSlot,
          taskSlot: taskSlot,
          verdict: verdict,
          deleted: deleted,
          createdMinuteOffset: createdMinuteOffset,
          seed: seed,
        ),
      );

  glados.Generator<_GeneratedChangeTemplateAssignmentSpec>
  get changeTemplateAssignmentSpec => glados.CombinableAny(this).combine4(
    changeTemplateSlot,
    changeAgentSlot,
    glados.AnyUtils(this).choose([false, true]),
    glados.IntAnys(this).intInRange(-4, 4),
    (
      _GeneratedChangeTemplateSlot templateSlot,
      _GeneratedChangeAgentSlot agentSlot,
      bool deleted,
      int createdMinuteOffset,
    ) => _GeneratedChangeTemplateAssignmentSpec(
      templateSlot: templateSlot,
      agentSlot: agentSlot,
      deleted: deleted,
      createdMinuteOffset: createdMinuteOffset,
    ),
  );

  glados.Generator<_GeneratedChangeQueryScenario> get changeQueryScenario =>
      glados.CombinableAny(this).combine6(
        glados.ListAnys(this).listWithLengthInRange(0, 8, changeSetSpec),
        glados.ListAnys(this).listWithLengthInRange(0, 8, changeDecisionSpec),
        glados.ListAnys(
          this,
        ).listWithLengthInRange(0, 6, changeTemplateAssignmentSpec),
        glados.IntAnys(this).intInRange(1, 4),
        glados.IntAnys(this).intInRange(1, 4),
        glados.IntAnys(this).intInRange(1, 4),
        (
          List<_GeneratedChangeSetSpec> changeSets,
          List<_GeneratedChangeDecisionSpec> decisions,
          List<_GeneratedChangeTemplateAssignmentSpec> assignments,
          int pendingLimit,
          int decisionLimit,
          int templateDecisionLimit,
        ) => _GeneratedChangeQueryScenario(
          changeSets: changeSets,
          decisions: decisions,
          assignments: assignments,
          pendingLimit: pendingLimit,
          decisionLimit: decisionLimit,
          templateDecisionLimit: templateDecisionLimit,
        ),
      );
}

void main() {
  late AgentDatabase db;
  late AgentRepository repo;

  setUp(() {
    db = AgentDatabase(inMemoryDatabase: true, background: false);
    repo = AgentRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  // ── ChangeSet entity roundtrips ──────────────────────────────────────────

  group('ChangeSet entity CRUD', () {
    test('changeSet variant persists and restores correctly', () async {
      final cs = makeTestChangeSet(
        items: const [
          ChangeItem(
            toolName: 'update_task_estimate',
            args: {'minutes': 120},
            humanSummary: 'Set estimate to 2 hours',
          ),
          ChangeItem(
            toolName: 'set_task_title',
            args: {'title': 'Fix login bug'},
            humanSummary: 'Set title to "Fix login bug"',
          ),
        ],
      );
      await repo.upsertEntity(cs);

      final result = await repo.getEntity(cs.id);

      expect(result, isNotNull);
      final restored = result! as ChangeSetEntity;
      expect(restored.id, cs.id);
      expect(restored.agentId, kTestAgentId);
      expect(restored.taskId, 'task-001');
      expect(restored.threadId, 'thread-001');
      expect(restored.runKey, 'run-key-001');
      expect(restored.status, ChangeSetStatus.pending);
      expect(restored.items, hasLength(2));
      expect(restored.items[0].toolName, 'update_task_estimate');
      expect(restored.items[0].args, {'minutes': 120});
      expect(restored.items[0].humanSummary, 'Set estimate to 2 hours');
      expect(restored.items[0].status, ChangeItemStatus.pending);
      expect(restored.items[1].toolName, 'set_task_title');
      expect(restored.resolvedAt, isNull);
    });

    test('changeSet with resolvedAt roundtrips correctly', () async {
      final resolvedAt = DateTime(2024, 6, 15, 14, 30);
      final cs = makeTestChangeSet(
        status: ChangeSetStatus.resolved,
        resolvedAt: resolvedAt,
      );
      await repo.upsertEntity(cs);

      final result = await repo.getEntity(cs.id);

      final restored = result! as ChangeSetEntity;
      expect(restored.status, ChangeSetStatus.resolved);
      expect(restored.resolvedAt, resolvedAt);
    });

    test('all ChangeSetStatus values roundtrip', () async {
      for (final status in ChangeSetStatus.values) {
        final cs = makeTestChangeSet(
          id: 'cs-${status.name}',
          status: status,
        );
        await repo.upsertEntity(cs);

        final result = await repo.getEntity(cs.id);
        final restored = result! as ChangeSetEntity;
        expect(restored.status, status);
      }
    });

    test('ChangeItem status values roundtrip within change set', () async {
      final cs = makeTestChangeSet(
        items: [
          for (final status in ChangeItemStatus.values)
            ChangeItem(
              toolName: 'test_tool',
              args: const {'key': 'value'},
              humanSummary: 'Item with status ${status.name}',
              status: status,
            ),
        ],
      );
      await repo.upsertEntity(cs);

      final result = await repo.getEntity(cs.id);
      final restored = result! as ChangeSetEntity;
      expect(restored.items, hasLength(ChangeItemStatus.values.length));

      for (var i = 0; i < ChangeItemStatus.values.length; i++) {
        expect(restored.items[i].status, ChangeItemStatus.values[i]);
      }
    });
  });

  // ── ChangeDecision entity roundtrips ────────────────────────────────────

  group('ChangeDecision entity CRUD', () {
    test('changeDecision variant persists and restores correctly', () async {
      final decision = makeTestChangeDecision(
        taskId: 'task-001',
        rejectionReason: 'Not applicable',
        verdict: ChangeDecisionVerdict.rejected,
      );
      await repo.upsertEntity(decision);

      final result = await repo.getEntity(decision.id);

      expect(result, isNotNull);
      final restored = result! as ChangeDecisionEntity;
      expect(restored.id, decision.id);
      expect(restored.agentId, kTestAgentId);
      expect(restored.changeSetId, 'cs-001');
      expect(restored.itemIndex, 0);
      expect(restored.toolName, 'update_task_estimate');
      expect(restored.verdict, ChangeDecisionVerdict.rejected);
      expect(restored.taskId, 'task-001');
      expect(restored.rejectionReason, 'Not applicable');
    });

    test('all ChangeDecisionVerdict values roundtrip', () async {
      for (final verdict in ChangeDecisionVerdict.values) {
        final decision = makeTestChangeDecision(
          id: 'cd-${verdict.name}',
          verdict: verdict,
        );
        await repo.upsertEntity(decision);

        final result = await repo.getEntity(decision.id);
        final restored = result! as ChangeDecisionEntity;
        expect(restored.verdict, verdict);
      }
    });

    test('changeDecision without optional fields roundtrips', () async {
      final decision = makeTestChangeDecision();
      await repo.upsertEntity(decision);

      final result = await repo.getEntity(decision.id);
      final restored = result! as ChangeDecisionEntity;
      expect(restored.taskId, isNull);
      expect(restored.rejectionReason, isNull);
    });
  });

  // ── Repository query methods ──────────────────────────────────────────────

  group('getPendingChangeSets', () {
    test('returns pending and partiallyResolved sets for agent', () async {
      // Create change sets with various statuses.
      await repo.upsertEntity(
        makeTestChangeSet(
          id: 'cs-pending',
        ),
      );
      await repo.upsertEntity(
        makeTestChangeSet(
          id: 'cs-partial',
          status: ChangeSetStatus.partiallyResolved,
          createdAt: kAgentTestDate.add(const Duration(hours: 1)),
        ),
      );
      await repo.upsertEntity(
        makeTestChangeSet(
          id: 'cs-resolved',
          status: ChangeSetStatus.resolved,
        ),
      );
      await repo.upsertEntity(
        makeTestChangeSet(
          id: 'cs-expired',
          status: ChangeSetStatus.expired,
        ),
      );

      final results = await repo.getPendingChangeSets(kTestAgentId);

      expect(results, hasLength(2));
      final ids = results.map((cs) => cs.id).toSet();
      expect(ids, containsAll(['cs-pending', 'cs-partial']));
    });

    test('filters by taskId when provided', () async {
      await repo.upsertEntity(
        makeTestChangeSet(
          id: 'cs-task-a',
          taskId: 'task-A',
        ),
      );
      await repo.upsertEntity(
        makeTestChangeSet(
          id: 'cs-task-b',
          taskId: 'task-B',
        ),
      );

      final results = await repo.getPendingChangeSets(
        kTestAgentId,
        taskId: 'task-A',
      );

      expect(results, hasLength(1));
      expect(results.first.taskId, 'task-A');
    });

    test('excludes deleted change sets', () async {
      final cs = makeTestChangeSet();
      await repo.upsertEntity(cs);

      // Soft-delete by upserting with deletedAt set.
      final deleted = AgentDomainEntity.changeSet(
        id: cs.id,
        agentId: cs.agentId,
        taskId: cs.taskId,
        threadId: cs.threadId,
        runKey: cs.runKey,
        status: cs.status,
        items: cs.items,
        createdAt: cs.createdAt,
        vectorClock: cs.vectorClock,
        deletedAt: DateTime(2024, 6, 15),
      );
      await repo.upsertEntity(deleted);

      final results = await repo.getPendingChangeSets(kTestAgentId);
      expect(results, isEmpty);
    });

    test('respects limit parameter', () async {
      for (var i = 0; i < 5; i++) {
        await repo.upsertEntity(
          makeTestChangeSet(
            id: 'cs-$i',
            createdAt: kAgentTestDate.add(Duration(hours: i)),
          ),
        );
      }

      final results = await repo.getPendingChangeSets(
        kTestAgentId,
        limit: 3,
      );

      expect(results, hasLength(3));
    });
  });

  group('getRecentDecisions', () {
    test('returns decisions for agent ordered newest-first', () async {
      for (var i = 0; i < 3; i++) {
        await repo.upsertEntity(
          makeTestChangeDecision(
            id: 'cd-$i',
            itemIndex: i,
            createdAt: kAgentTestDate.add(Duration(hours: i)),
          ),
        );
      }

      final results = await repo.getRecentDecisions(kTestAgentId);

      expect(results, hasLength(3));
      // Newest first (created_at DESC).
      expect(results.first.id, 'cd-2');
      expect(results.last.id, 'cd-0');
    });

    test('filters by taskId when provided', () async {
      await repo.upsertEntity(
        makeTestChangeDecision(
          id: 'cd-task-a',
          taskId: 'task-A',
        ),
      );
      await repo.upsertEntity(
        makeTestChangeDecision(
          id: 'cd-task-b',
          taskId: 'task-B',
        ),
      );

      final results = await repo.getRecentDecisions(
        kTestAgentId,
        taskId: 'task-A',
      );

      expect(results, hasLength(1));
      expect(results.first.taskId, 'task-A');
    });

    test('respects limit parameter', () async {
      for (var i = 0; i < 10; i++) {
        await repo.upsertEntity(
          makeTestChangeDecision(
            id: 'cd-$i',
            itemIndex: i,
            createdAt: kAgentTestDate.add(Duration(hours: i)),
          ),
        );
      }

      final results = await repo.getRecentDecisions(
        kTestAgentId,
        limit: 5,
      );

      expect(results, hasLength(5));
    });
  });

  group('getRecentDecisionsForTemplate', () {
    test('returns decisions across all template instances', () async {
      // Set up template assignment link.
      await repo.upsertLink(makeTestTemplateAssignmentLink());

      // Create decisions for the agent.
      await repo.upsertEntity(
        makeTestChangeDecision(
          id: 'cd-tpl-1',
          createdAt: kAgentTestDate,
        ),
      );
      await repo.upsertEntity(
        makeTestChangeDecision(
          id: 'cd-tpl-2',
          itemIndex: 1,
          createdAt: kAgentTestDate.add(const Duration(hours: 1)),
        ),
      );

      final results = await repo.getRecentDecisionsForTemplate(
        kTestTemplateId,
        since: kAgentTestDate.subtract(const Duration(days: 1)),
      );

      expect(results, hasLength(2));
      // Newest first.
      expect(results.first.id, 'cd-tpl-2');
    });

    test('filters by since parameter in SQL', () async {
      await repo.upsertLink(makeTestTemplateAssignmentLink());

      final oldDate = DateTime(2024);
      final recentDate = DateTime(2024, 3, 15);

      await repo.upsertEntity(
        makeTestChangeDecision(
          id: 'cd-old',
          createdAt: oldDate,
        ),
      );
      await repo.upsertEntity(
        makeTestChangeDecision(
          id: 'cd-recent',
          itemIndex: 1,
          createdAt: recentDate,
        ),
      );

      final results = await repo.getRecentDecisionsForTemplate(
        kTestTemplateId,
        since: DateTime(2024, 3),
      );

      expect(results, hasLength(1));
      expect(results.first.id, 'cd-recent');
    });

    test('returns empty list when no template assignment exists', () async {
      await repo.upsertEntity(makeTestChangeDecision());

      final results = await repo.getRecentDecisionsForTemplate(
        'nonexistent-template',
        since: kAgentTestDate.subtract(const Duration(days: 1)),
      );

      expect(results, isEmpty);
    });
  });

  glados.Glados(
    glados.any.changeQueryScenario,
    glados.ExploreConfig(numRuns: 80),
  ).test(
    'matches generated change-set and decision query semantics',
    (scenario) async {
      final localDb = AgentDatabase(inMemoryDatabase: true, background: false);
      final localRepo = AgentRepository(localDb);

      try {
        for (final assignment in scenario.assignments) {
          await localRepo.upsertLink(
            model.AgentLink.templateAssignment(
              id: assignment.id,
              fromId: assignment.templateId,
              toId: assignment.agentId,
              createdAt: assignment.createdAt,
              updatedAt: assignment.createdAt,
              vectorClock: null,
              deletedAt: assignment.deletedAt,
            ),
          );
        }

        for (var index = 0; index < scenario.changeSets.length; index++) {
          final spec = scenario.changeSets[index];
          await localRepo.upsertEntity(
            makeTestChangeSet(
              id: spec.idAt(index),
              agentId: spec.agentId,
              taskId: spec.taskId,
              threadId: 'generated-thread-$index',
              runKey: 'generated-run-$index',
              status: spec.status,
              createdAt: spec.createdAt(index),
            ).copyWith(
              deletedAt: spec.deletedAt(index),
            ),
          );
        }

        for (var index = 0; index < scenario.decisions.length; index++) {
          final spec = scenario.decisions[index];
          await localRepo.upsertEntity(
            makeTestChangeDecision(
              id: spec.idAt(index),
              agentId: spec.agentId,
              changeSetId: 'generated-change-set-ref-$index',
              itemIndex: index,
              toolName: 'generated_tool',
              verdict: spec.verdict,
              taskId: spec.taskId,
              createdAt: spec.createdAt(index),
            ).copyWith(
              deletedAt: spec.deletedAt(index),
            ),
          );
        }

        final pending = await localRepo.getPendingChangeSets(
          _generatedChangeTargetAgentId,
          taskId: _generatedChangeTargetTaskId,
          limit: scenario.pendingLimit,
        );
        expect(
          pending.map((changeSet) => changeSet.id).toList(),
          scenario.expectedPendingIds(limit: scenario.pendingLimit),
          reason: '$scenario',
        );

        final recentDecisions = await localRepo.getRecentDecisions(
          _generatedChangeTargetAgentId,
          taskId: _generatedChangeTargetTaskId,
          limit: scenario.decisionLimit,
        );
        expect(
          recentDecisions.map((decision) => decision.id).toList(),
          scenario.expectedRecentDecisionIds(limit: scenario.decisionLimit),
          reason: '$scenario',
        );

        final templateDecisions = await localRepo.getRecentDecisionsForTemplate(
          _generatedChangeTargetTemplateId,
          since: _generatedChangeSince,
          limit: scenario.templateDecisionLimit,
        );
        expect(
          templateDecisions.map((decision) => decision.id).toList(),
          scenario.expectedTemplateDecisionIds(
            limit: scenario.templateDecisionLimit,
          ),
          reason: '$scenario',
        );
      } finally {
        await localDb.close();
      }
    },
    tags: 'glados',
  );

  // ── ChangeItem serialization ──────────────────────────────────────────────

  group('ChangeItem JSON serialization', () {
    test('roundtrips through toJson/fromJson', () {
      const item = ChangeItem(
        toolName: 'add_checklist_item',
        args: {'title': 'Design mockup', 'isChecked': false},
        humanSummary: 'Add checklist item: Design mockup',
        status: ChangeItemStatus.confirmed,
      );

      final json = item.toJson();
      final restored = ChangeItem.fromJson(json);

      expect(restored.toolName, item.toolName);
      expect(restored.args, item.args);
      expect(restored.humanSummary, item.humanSummary);
      expect(restored.status, ChangeItemStatus.confirmed);
    });

    test('defaults status to pending when omitted', () {
      const item = ChangeItem(
        toolName: 'test',
        args: <String, dynamic>{},
        humanSummary: 'test',
      );

      expect(item.status, ChangeItemStatus.pending);

      // Also verify JSON roundtrip preserves the default.
      final restored = ChangeItem.fromJson(item.toJson());
      expect(restored.status, ChangeItemStatus.pending);
    });
  });

  group('getProposalLedger', () {
    test('splits items into open and resolved groups, newest-first', () async {
      final oldSet = makeTestChangeSet(
        id: 'cs-old',
        taskId: 'task-ledger',
        createdAt: kAgentTestDate,
        status: ChangeSetStatus.resolved,
        resolvedAt: kAgentTestDate.add(const Duration(hours: 1)),
        items: const [
          ChangeItem(
            toolName: 'set_task_title',
            args: {'title': 'Old title'},
            humanSummary: 'Rename task to "Old title"',
            status: ChangeItemStatus.confirmed,
          ),
        ],
      );
      final newerSet = makeTestChangeSet(
        id: 'cs-new',
        taskId: 'task-ledger',
        createdAt: kAgentTestDate.add(const Duration(hours: 2)),
        items: const [
          ChangeItem(
            toolName: 'update_task_priority',
            args: {'priority': 'P1'},
            humanSummary: 'Set priority to P1',
          ),
          ChangeItem(
            toolName: 'add_checklist_item',
            args: {'title': 'Write migration'},
            humanSummary: 'Add checklist item: "Write migration"',
          ),
        ],
      );
      final confirmedDecision = makeTestChangeDecision(
        id: 'cd-confirm-old',
        changeSetId: 'cs-old',
        toolName: 'set_task_title',
        taskId: 'task-ledger',
        args: const {'title': 'Old title'},
        humanSummary: 'Rename task to "Old title"',
        createdAt: kAgentTestDate.add(const Duration(hours: 1)),
      );

      await repo.upsertEntity(oldSet);
      await repo.upsertEntity(newerSet);
      await repo.upsertEntity(confirmedDecision);

      final ledger = await repo.getProposalLedger(
        kTestAgentId,
        taskId: 'task-ledger',
      );

      expect(ledger.open, hasLength(2));
      // Open items are newest-first by parent change set createdAt.
      expect(ledger.open.first.toolName, 'update_task_priority');
      expect(ledger.open.first.status, ChangeItemStatus.pending);
      expect(
        ledger.open.first.fingerprint,
        ChangeItem.fingerprintFromParts(
          'update_task_priority',
          const {'priority': 'P1'},
        ),
      );

      expect(ledger.resolved, hasLength(1));
      final resolvedEntry = ledger.resolved.single;
      expect(resolvedEntry.toolName, 'set_task_title');
      expect(resolvedEntry.status, ChangeItemStatus.confirmed);
      expect(resolvedEntry.verdict, ChangeDecisionVerdict.confirmed);
      expect(resolvedEntry.resolvedBy, DecisionActor.user);
    });

    test(
      'attaches agent retraction metadata (actor, verdict, retractionReason)',
      () async {
        final retractedSet = makeTestChangeSet(
          id: 'cs-retracted',
          taskId: 'task-retract',
          status: ChangeSetStatus.resolved,
          createdAt: kAgentTestDate,
          items: const [
            ChangeItem(
              toolName: 'update_task_priority',
              args: {'priority': 'P1'},
              humanSummary: 'Set priority to P1',
              status: ChangeItemStatus.retracted,
            ),
          ],
        );
        final retractionDecision = makeTestChangeDecision(
          id: 'cd-retract',
          changeSetId: 'cs-retracted',
          toolName: 'update_task_priority',
          verdict: ChangeDecisionVerdict.retracted,
          actor: DecisionActor.agent,
          taskId: 'task-retract',
          args: const {'priority': 'P1'},
          retractionReason: 'Already P1 on the task',
          humanSummary: 'Set priority to P1',
          createdAt: kAgentTestDate.add(const Duration(minutes: 5)),
        );

        await repo.upsertEntity(retractedSet);
        await repo.upsertEntity(retractionDecision);

        final ledger = await repo.getProposalLedger(
          kTestAgentId,
          taskId: 'task-retract',
        );

        expect(ledger.open, isEmpty);
        expect(ledger.resolved, hasLength(1));
        final entry = ledger.resolved.single;
        expect(entry.status, ChangeItemStatus.retracted);
        expect(entry.verdict, ChangeDecisionVerdict.retracted);
        expect(entry.resolvedBy, DecisionActor.agent);
        expect(entry.reason, 'Already P1 on the task');
      },
    );

    test('filters change sets from other tasks out of the ledger', () async {
      await repo.upsertEntity(
        makeTestChangeSet(
          id: 'cs-target',
          taskId: 'target-task',
          createdAt: kAgentTestDate,
        ),
      );
      await repo.upsertEntity(
        makeTestChangeSet(
          id: 'cs-other',
          taskId: 'other-task',
          createdAt: kAgentTestDate,
        ),
      );

      final ledger = await repo.getProposalLedger(
        kTestAgentId,
        taskId: 'target-task',
      );

      expect(ledger.open, hasLength(1));
      expect(ledger.open.single.changeSetId, 'cs-target');
      expect(ledger.resolved, isEmpty);
    });

    test(
      'returns ProposalLedger.empty when the task has no change sets',
      () async {
        final ledger = await repo.getProposalLedger(
          kTestAgentId,
          taskId: 'task-with-nothing',
        );

        expect(ledger.isEmpty, isTrue);
        expect(ledger.open, isEmpty);
        expect(ledger.resolved, isEmpty);
      },
    );

    test('caps resolved entries at resolvedLimit most-recent', () async {
      // Ten resolved sets, each with one confirmed item.
      for (var i = 0; i < 10; i++) {
        final csId = 'cs-$i';
        await repo.upsertEntity(
          makeTestChangeSet(
            id: csId,
            taskId: 'task-cap',
            status: ChangeSetStatus.resolved,
            createdAt: kAgentTestDate.add(Duration(minutes: i)),
            items: [
              ChangeItem(
                toolName: 'set_task_title',
                args: {'title': 'Title $i'},
                humanSummary: 'Rename $i',
                status: ChangeItemStatus.confirmed,
              ),
            ],
          ),
        );
        await repo.upsertEntity(
          makeTestChangeDecision(
            id: 'cd-$i',
            changeSetId: csId,
            taskId: 'task-cap',
            toolName: 'set_task_title',
            args: {'title': 'Title $i'},
            humanSummary: 'Rename $i',
            createdAt: kAgentTestDate.add(Duration(minutes: i, seconds: 30)),
          ),
        );
      }

      final ledger = await repo.getProposalLedger(
        kTestAgentId,
        taskId: 'task-cap',
        resolvedLimit: 3,
      );

      expect(ledger.resolved, hasLength(3));
      // Newest first — latest three are Title 9, 8, 7.
      expect(ledger.resolved[0].humanSummary, 'Rename 9');
      expect(ledger.resolved[1].humanSummary, 'Rename 8');
      expect(ledger.resolved[2].humanSummary, 'Rename 7');
    });
  });
}
