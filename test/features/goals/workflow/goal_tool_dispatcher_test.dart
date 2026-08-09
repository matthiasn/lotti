import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/goals/service/goal_spec_revision_service.dart';
import 'package:lotti/features/goals/workflow/goal_agent_contract.dart';
import 'package:lotti/features/goals/workflow/goal_tool_dispatcher.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  const agentId = 'goal-1';
  late MockAgentRepository repository;
  late MockAgentSyncService syncService;
  late List<AgentDomainEntity> upserts;
  late GoalToolDispatcher dispatcher;

  setUp(() {
    repository = MockAgentRepository();
    syncService = MockAgentSyncService();
    upserts = [];
    when(() => repository.getEntity(any())).thenAnswer((_) async => null);
    when(() => syncService.upsertEntity(any())).thenAnswer((invocation) async {
      upserts.add(invocation.positionalArguments.first as AgentDomainEntity);
    });
    dispatcher = GoalToolDispatcher(
      revisionService: GoalSpecRevisionService(
        repository: repository,
        syncService: syncService,
      ),
    );
  });

  void stubSpec() {
    when(() => repository.getEntity(goalSpecHeadId(agentId))).thenAnswer(
      (_) async => AgentDomainEntity.goalSpecHead(
        id: goalSpecHeadId(agentId),
        agentId: agentId,
        versionId: '$agentId:spec-v1',
        updatedAt: DateTime(2026, 8),
        vectorClock: null,
      ),
    );
    when(() => repository.getEntity('$agentId:spec-v1')).thenAnswer(
      (_) async => AgentDomainEntity.goalSpecVersion(
        id: '$agentId:spec-v1',
        agentId: agentId,
        version: 1,
        status: GoalSpecVersionStatus.active,
        authoredBy: 'user',
        title: 'Steps',
        statement: 'Average 10,000 steps per day.',
        criteria: const GoalCriterion.metric(
          criterionId: 'steps',
          dataType: 'cumulative_step_count',
          window: GoalWindow.rollingDays(count: 7),
          aggregation: GoalAggregation.dailySumThenAverage,
          target: 10000,
        ),
        createdAt: DateTime(2026, 8),
        vectorClock: null,
      ),
    );
  }

  test(
    'an accepted revision mints the version and reports what changed',
    () async {
      stubSpec();
      final result = await dispatcher.dispatch(
        GoalAgentToolNames.proposeGoalRevision,
        {
          'changes': {'targetValue': 8000},
          'rationale': 'ease off',
          'sourceThreadId': 'thread-42',
        },
        agentId,
      );
      expect(result.success, isTrue);
      expect(result.mutatedEntityId, '$agentId:spec-v2');
      expect(
        upserts
            .whereType<GoalSpecVersionEntity>()
            .singleWhere((v) => v.id == '$agentId:spec-v2')
            .sourceSessionId,
        'thread-42',
        reason: 'the proposing conversation stays auditable on the version',
      );
      expect(result.output, contains('Goal revised to v2'));
      expect(result.output, contains('target: 10000 → 8000'));
      expect(
        upserts.whereType<GoalSpecHeadEntity>().single.versionId,
        '$agentId:spec-v2',
      );
    },
  );

  test('a refusal keeps the proposal unresolved — success false, nothing '
      'written', () async {
    stubSpec();
    final result = await dispatcher.dispatch(
      GoalAgentToolNames.proposeGoalRevision,
      {
        'changes': {'period': 'fortnight'},
        'rationale': 'r',
      },
      agentId,
    );
    expect(result.success, isFalse);
    expect(result.errorMessage, contains('unrecognized period'));
    expect(upserts, isEmpty);
  });

  test('missing changes and unknown tools are rejected', () async {
    final noChanges = await dispatcher.dispatch(
      GoalAgentToolNames.proposeGoalRevision,
      {'rationale': 'r'},
      agentId,
    );
    expect(noChanges.success, isFalse);
    expect(noChanges.errorMessage, 'Missing changes');

    final unknown = await dispatcher.dispatch('made_up_tool', {}, agentId);
    expect(unknown.success, isFalse);
    expect(unknown.errorMessage, contains('not registered'));
  });
}
