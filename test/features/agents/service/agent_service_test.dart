import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/service/agent_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockAgentRepository mockRepository;
  late MockWakeOrchestrator mockOrchestrator;
  late AgentService service;

  setUp(() {
    mockRepository = MockAgentRepository();
    mockOrchestrator = MockWakeOrchestrator();
    service = AgentService(
      repository: mockRepository,
      orchestrator: mockOrchestrator,
    );
  });

  group('AgentService', () {
    group('createAgent', () {
      test('creates identity, state, and link, then returns identity',
          () async {
        when(() => mockRepository.upsertEntity(any())).thenAnswer((_) async {});
        when(() => mockRepository.upsertLink(any())).thenAnswer((_) async {});

        final identity = await service.createAgent(
          kind: 'task_agent',
          displayName: 'Test Agent',
          config: const AgentConfig(),
          allowedCategoryIds: {'cat-1', 'cat-2'},
        );

        expect(identity, isA<AgentIdentityEntity>());
        expect(identity.kind, 'task_agent');
        expect(identity.displayName, 'Test Agent');
        expect(identity.lifecycle, AgentLifecycle.active);
        expect(identity.mode, AgentInteractionMode.autonomous);
        expect(identity.allowedCategoryIds, {'cat-1', 'cat-2'});
        expect(identity.config, const AgentConfig());
        expect(identity.id, identity.agentId);

        // Verify identity entity was persisted
        final identityCalls = verify(
          () => mockRepository.upsertEntity(captureAny()),
        ).captured;
        expect(identityCalls, hasLength(2));

        final savedIdentity = identityCalls[0] as AgentIdentityEntity;
        expect(savedIdentity.kind, 'task_agent');
        expect(savedIdentity.displayName, 'Test Agent');

        final savedState = identityCalls[1] as AgentStateEntity;
        expect(savedState.agentId, identity.agentId);
        expect(savedState.revision, 0);
        expect(savedState.slots, const AgentSlots());

        // Verify link was created
        verify(() => mockRepository.upsertLink(any())).called(1);
      });

      test('creates identity with default empty allowedCategoryIds', () async {
        when(() => mockRepository.upsertEntity(any())).thenAnswer((_) async {});
        when(() => mockRepository.upsertLink(any())).thenAnswer((_) async {});

        final identity = await service.createAgent(
          kind: 'task_agent',
          displayName: 'Agent No Categories',
          config: const AgentConfig(),
        );

        expect(identity.allowedCategoryIds, isEmpty);
      });

      test('creates state with currentStateId matching state entity id',
          () async {
        when(() => mockRepository.upsertEntity(any())).thenAnswer((_) async {});
        when(() => mockRepository.upsertLink(any())).thenAnswer((_) async {});

        final identity = await service.createAgent(
          kind: 'task_agent',
          displayName: 'Agent',
          config: const AgentConfig(),
        );

        final calls = verify(
          () => mockRepository.upsertEntity(captureAny()),
        ).captured;
        final savedState = calls[1] as AgentStateEntity;

        expect(identity.currentStateId, savedState.id);
      });
    });

    group('getAgent', () {
      test('returns identity for existing agent', () async {
        final identity = AgentDomainEntity.agent(
          id: 'agent-1',
          agentId: 'agent-1',
          kind: 'task_agent',
          displayName: 'Test Agent',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(),
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
        ) as AgentIdentityEntity;

        when(() => mockRepository.getEntity('agent-1'))
            .thenAnswer((_) async => identity);

        final result = await service.getAgent('agent-1');

        expect(result, isNotNull);
        expect(result!.id, 'agent-1');
        expect(result.kind, 'task_agent');
        expect(result.displayName, 'Test Agent');
      });

      test('returns null for non-existent agent', () async {
        when(() => mockRepository.getEntity('non-existent'))
            .thenAnswer((_) async => null);

        final result = await service.getAgent('non-existent');

        expect(result, isNull);
      });

      test('returns null when entity is not an agent identity', () async {
        final stateEntity = AgentDomainEntity.agentState(
          id: 'state-1',
          agentId: 'agent-1',
          revision: 0,
          slots: const AgentSlots(),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
        );

        when(() => mockRepository.getEntity('state-1'))
            .thenAnswer((_) async => stateEntity);

        final result = await service.getAgent('state-1');

        expect(result, isNull);
      });
    });

    group('listAgents', () {
      test('returns all agents from repository', () async {
        when(() => mockRepository.getAllAgentIdentities())
            .thenAnswer((_) async => <AgentIdentityEntity>[]);

        final result = await service.listAgents();

        expect(result, isEmpty);
        verify(() => mockRepository.getAllAgentIdentities()).called(1);
      });

      test('filters by lifecycle when provided', () async {
        final activeAgent = AgentDomainEntity.agent(
          id: 'a1',
          agentId: 'a1',
          kind: 'task_agent',
          displayName: 'Active',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 's1',
          config: const AgentConfig(),
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
        ) as AgentIdentityEntity;

        final dormantAgent = AgentDomainEntity.agent(
          id: 'a2',
          agentId: 'a2',
          kind: 'task_agent',
          displayName: 'Dormant',
          lifecycle: AgentLifecycle.dormant,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 's2',
          config: const AgentConfig(),
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
        ) as AgentIdentityEntity;

        when(() => mockRepository.getAllAgentIdentities())
            .thenAnswer((_) async => [activeAgent, dormantAgent]);

        final result =
            await service.listAgents(lifecycle: AgentLifecycle.active);

        expect(result, hasLength(1));
        expect(result.first.id, 'a1');
      });
    });

    group('getAgentReport', () {
      test('delegates to repository with default scope', () async {
        final report = AgentDomainEntity.agentReport(
          id: 'report-1',
          agentId: 'agent-1',
          scope: 'current',
          createdAt: DateTime(2024, 3, 15),
          vectorClock: null,
          content: const {'summary': 'All good'},
        ) as AgentReportEntity;

        when(() => mockRepository.getLatestReport('agent-1', 'current'))
            .thenAnswer((_) async => report);

        final result = await service.getAgentReport('agent-1');

        expect(result, isNotNull);
        expect(result!.id, 'report-1');
        expect(result.scope, 'current');
        expect(result.content, {'summary': 'All good'});
        verify(() => mockRepository.getLatestReport('agent-1', 'current'))
            .called(1);
      });

      test('delegates to repository with custom scope', () async {
        when(() => mockRepository.getLatestReport('agent-1', 'weekly'))
            .thenAnswer((_) async => null);

        final result = await service.getAgentReport('agent-1', 'weekly');

        expect(result, isNull);
        verify(() => mockRepository.getLatestReport('agent-1', 'weekly'))
            .called(1);
      });
    });

    group('pauseAgent', () {
      test('sets lifecycle to dormant and unregisters subscriptions', () async {
        final identity = AgentDomainEntity.agent(
          id: 'agent-1',
          agentId: 'agent-1',
          kind: 'task_agent',
          displayName: 'Test Agent',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(),
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
        );

        when(() => mockRepository.getEntity('agent-1'))
            .thenAnswer((_) async => identity);
        when(() => mockRepository.upsertEntity(any())).thenAnswer((_) async {});
        when(() => mockOrchestrator.removeSubscriptions('agent-1'))
            .thenReturn(null);

        await service.pauseAgent('agent-1');

        final captured = verify(
          () => mockRepository.upsertEntity(captureAny()),
        ).captured;
        final updated = captured.first as AgentIdentityEntity;
        expect(updated.lifecycle, AgentLifecycle.dormant);
        expect(updated.destroyedAt, isNull);

        verify(() => mockOrchestrator.removeSubscriptions('agent-1')).called(1);
      });

      test('handles non-existent agent gracefully', () async {
        when(() => mockRepository.getEntity('non-existent'))
            .thenAnswer((_) async => null);
        when(() => mockOrchestrator.removeSubscriptions('non-existent'))
            .thenReturn(null);

        // Should not throw
        await service.pauseAgent('non-existent');

        verifyNever(() => mockRepository.upsertEntity(any()));
        verify(() => mockOrchestrator.removeSubscriptions('non-existent'))
            .called(1);
      });
    });

    group('resumeAgent', () {
      test('sets lifecycle to active', () async {
        final identity = AgentDomainEntity.agent(
          id: 'agent-1',
          agentId: 'agent-1',
          kind: 'task_agent',
          displayName: 'Test Agent',
          lifecycle: AgentLifecycle.dormant,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(),
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
        );

        when(() => mockRepository.getEntity('agent-1'))
            .thenAnswer((_) async => identity);
        when(() => mockRepository.upsertEntity(any())).thenAnswer((_) async {});

        await service.resumeAgent('agent-1');

        final captured = verify(
          () => mockRepository.upsertEntity(captureAny()),
        ).captured;
        final updated = captured.first as AgentIdentityEntity;
        expect(updated.lifecycle, AgentLifecycle.active);
        expect(updated.destroyedAt, isNull);
      });

      test('handles non-existent agent gracefully', () async {
        when(() => mockRepository.getEntity('non-existent'))
            .thenAnswer((_) async => null);

        await service.resumeAgent('non-existent');

        verifyNever(() => mockRepository.upsertEntity(any()));
      });
    });

    group('destroyAgent', () {
      test(
          'sets lifecycle to destroyed, sets destroyedAt, '
          'and unregisters subscriptions', () async {
        final identity = AgentDomainEntity.agent(
          id: 'agent-1',
          agentId: 'agent-1',
          kind: 'task_agent',
          displayName: 'Test Agent',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(),
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
        );

        when(() => mockRepository.getEntity('agent-1'))
            .thenAnswer((_) async => identity);
        when(() => mockRepository.upsertEntity(any())).thenAnswer((_) async {});
        when(() => mockOrchestrator.removeSubscriptions('agent-1'))
            .thenReturn(null);

        await service.destroyAgent('agent-1');

        final captured = verify(
          () => mockRepository.upsertEntity(captureAny()),
        ).captured;
        final updated = captured.first as AgentIdentityEntity;
        expect(updated.lifecycle, AgentLifecycle.destroyed);
        expect(updated.destroyedAt, isNotNull);

        verify(() => mockOrchestrator.removeSubscriptions('agent-1')).called(1);
      });

      test('handles non-existent agent gracefully', () async {
        when(() => mockRepository.getEntity('non-existent'))
            .thenAnswer((_) async => null);
        when(() => mockOrchestrator.removeSubscriptions('non-existent'))
            .thenReturn(null);

        await service.destroyAgent('non-existent');

        verifyNever(() => mockRepository.upsertEntity(any()));
        verify(() => mockOrchestrator.removeSubscriptions('non-existent'))
            .called(1);
      });
    });
  });
}
