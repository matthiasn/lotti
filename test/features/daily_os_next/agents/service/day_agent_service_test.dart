import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../agents/test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockAgentService agentService;
  late MockAgentRepository repository;
  late MockWakeOrchestrator orchestrator;
  late MockAgentSyncService syncService;
  late MockAgentTemplateService templateService;
  late DayAgentService service;
  late List<String> changedTokens;

  const agentId = 'day-agent-1';
  final testDate = DateTime(2026, 5, 25, 9);
  const dayId = 'dayplan-2026-05-25';
  final now = DateTime(2026, 5, 25, 8);

  AgentIdentityEntity identity({
    String id = agentId,
    String kind = AgentKinds.dayAgent,
    DateTime? createdAt,
  }) {
    return makeTestIdentity(
      id: id,
      agentId: id,
      kind: kind,
      displayName: 'Shepherd',
      currentStateId: 'state-$id',
      createdAt: createdAt ?? now,
      updatedAt: createdAt ?? now,
    );
  }

  AgentStateEntity state({
    String id = 'state-$agentId',
    String stateAgentId = agentId,
    String? activeDayId,
    DateTime? nextWakeAt,
  }) {
    return makeTestState(
      id: id,
      agentId: stateAgentId,
      revision: 0,
      slots: AgentSlots(activeDayId: activeDayId),
      nextWakeAt: nextWakeAt,
      updatedAt: now,
    );
  }

  setUp(() {
    agentService = MockAgentService();
    repository = MockAgentRepository();
    orchestrator = MockWakeOrchestrator();
    syncService = MockAgentSyncService();
    templateService = MockAgentTemplateService();
    changedTokens = [];

    when(() => syncService.upsertEntity(any())).thenAnswer((_) async {});
    when(() => syncService.upsertLink(any())).thenAnswer((_) async {});
    when(
      () => orchestrator.enqueueManualWake(
        agentId: any(named: 'agentId'),
        reason: any(named: 'reason'),
        triggerTokens: any(named: 'triggerTokens'),
      ),
    ).thenReturn(null);
    when(
      () => orchestrator.restorePendingWake(
        agentId: any(named: 'agentId'),
        dueAt: any(named: 'dueAt'),
      ),
    ).thenReturn(null);

    service = DayAgentService(
      agentService: agentService,
      repository: repository,
      orchestrator: orchestrator,
      syncService: syncService,
      templateService: templateService,
      onPersistedStateChanged: changedTokens.add,
    );
  });

  group('DayAgentService', () {
    test('creates one day agent and schedules its creation wake', () async {
      const categoryIds = {'cat-focus'};
      final createdIdentity = identity();
      final initialState = state();
      final template = makeTestTemplate(
        id: dayAgentTemplateId,
        agentId: dayAgentTemplateId,
        kind: AgentTemplateKind.dayAgent,
        modelId: 'models/day',
        profileId: 'profile-day',
      );

      when(
        () => agentService.listAgents(lifecycle: AgentLifecycle.active),
      ).thenAnswer((_) async => []);
      when(
        () => repository.getEntity(dayAgentTemplateId),
      ).thenAnswer((_) async => template);
      when(
        () => agentService.createAgent(
          kind: any(named: 'kind'),
          displayName: any(named: 'displayName'),
          config: any(named: 'config'),
          allowedCategoryIds: categoryIds,
        ),
      ).thenAnswer((_) async => createdIdentity);
      when(
        () => repository.getAgentState(agentId),
      ).thenAnswer((_) async => initialState);

      final result = await withClock(
        Clock.fixed(now),
        () => service.createDayAgent(
          date: testDate,
          allowedCategoryIds: categoryIds,
        ),
      );

      expect(result, createdIdentity);
      final createCall = verify(
        () => agentService.createAgent(
          kind: captureAny(named: 'kind'),
          displayName: captureAny(named: 'displayName'),
          config: captureAny(named: 'config'),
          allowedCategoryIds: categoryIds,
        ),
      ).captured;
      expect(createCall[0], AgentKinds.dayAgent);
      expect(createCall[1], 'Shepherd 2026-05-25');
      expect(
        createCall[2],
        const AgentConfig(modelId: 'models/day', profileId: 'profile-day'),
      );

      final entities = verify(
        () => syncService.upsertEntity(captureAny()),
      ).captured.cast<AgentDomainEntity>();
      final updatedState = entities.single as AgentStateEntity;
      expect(updatedState.slots.activeDayId, dayId);
      expect(updatedState.updatedAt, now);

      final links = verify(
        () => syncService.upsertLink(captureAny()),
      ).captured.cast<AgentLink>();
      final link = links.single as TemplateAssignmentLink;
      expect(link.fromId, dayAgentTemplateId);
      expect(link.toId, agentId);

      verify(
        () => orchestrator.enqueueManualWake(
          agentId: agentId,
          reason: WakeReason.creation.name,
          triggerTokens: {dayId},
        ),
      ).called(1);
      expect(changedTokens, [agentId, dayId]);
    });

    test('rejects duplicate active day agent for the same date', () async {
      final existing = identity();
      when(
        () => agentService.listAgents(lifecycle: AgentLifecycle.active),
      ).thenAnswer((_) async => [existing]);
      when(
        () => repository.getAgentStatesByAgentIds([agentId]),
      ).thenAnswer(
        (_) async => {agentId: state(activeDayId: dayId)},
      );

      await expectLater(
        service.createDayAgent(date: testDate),
        throwsA(isA<StateError>()),
      );

      verifyNever(
        () => agentService.createAgent(
          kind: any(named: 'kind'),
          displayName: any(named: 'displayName'),
          config: any(named: 'config'),
        ),
      );
    });

    test('getDayAgentForDate returns newest matching day agent', () async {
      final older = identity(id: 'older', createdAt: DateTime(2026, 5, 24));
      final newer = identity(id: 'newer', createdAt: DateTime(2026, 5, 25));
      final other = identity(id: 'other', createdAt: DateTime(2026, 5, 26));
      when(
        () => agentService.listAgents(lifecycle: AgentLifecycle.active),
      ).thenAnswer((_) async => [older, other, newer]);
      when(
        () => repository.getAgentStatesByAgentIds(['other', 'newer', 'older']),
      ).thenAnswer(
        (_) async => {
          'older': state(
            id: 'state-older',
            stateAgentId: 'older',
            activeDayId: dayId,
          ),
          'newer': state(
            id: 'state-newer',
            stateAgentId: 'newer',
            activeDayId: dayId,
          ),
          'other': state(
            id: 'state-other',
            stateAgentId: 'other',
            activeDayId: 'dayplan-2026-05-26',
          ),
        },
      );

      final result = await service.getDayAgentForDate(testDate);

      expect(result?.agentId, 'newer');
    });

    test(
      'restoreSubscriptions hydrates pending wakes for active day agents',
      () async {
        final dueAt = DateTime(2026, 5, 25, 6, 30);
        final dayAgent = identity();
        final taskAgent = identity(
          id: 'task-agent',
          kind: AgentKinds.taskAgent,
        );
        when(
          () => agentService.listAgents(lifecycle: AgentLifecycle.active),
        ).thenAnswer((_) async => [taskAgent, dayAgent]);
        when(
          () => repository.getAgentState(agentId),
        ).thenAnswer((_) async => state(activeDayId: dayId, nextWakeAt: dueAt));

        await service.restoreSubscriptions();

        verify(
          () => orchestrator.restorePendingWake(agentId: agentId, dueAt: dueAt),
        ).called(1);
        verifyNever(() => repository.getAgentState('task-agent'));
      },
    );
  });
}
