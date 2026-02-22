import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/service/agent_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockAgentRepository mockRepository;
  late MockWakeOrchestrator mockOrchestrator;
  late MockAgentSyncService mockSyncService;
  late AgentService service;

  setUp(() {
    mockRepository = MockAgentRepository();
    mockOrchestrator = MockWakeOrchestrator();
    mockSyncService = MockAgentSyncService();

    // Stub syncService write methods
    when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {});
    when(() => mockSyncService.upsertLink(any())).thenAnswer((_) async {});

    service = AgentService(
      repository: mockRepository,
      orchestrator: mockOrchestrator,
      syncService: mockSyncService,
    );
  });

  group('AgentService', () {
    group('createAgent', () {
      test('creates identity, state, and link, then returns identity',
          () async {
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
          () => mockSyncService.upsertEntity(captureAny()),
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
        verify(() => mockSyncService.upsertLink(any())).called(1);
      });

      test('creates identity with default empty allowedCategoryIds', () async {
        final identity = await service.createAgent(
          kind: 'task_agent',
          displayName: 'Agent No Categories',
          config: const AgentConfig(),
        );

        expect(identity.allowedCategoryIds, isEmpty);
      });

      test('creates state with currentStateId matching state entity id',
          () async {
        final identity = await service.createAgent(
          kind: 'task_agent',
          displayName: 'Agent',
          config: const AgentConfig(),
        );

        final calls = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;
        final savedState = calls[1] as AgentStateEntity;

        expect(identity.currentStateId, savedState.id);
      });
    });

    group('getAgent', () {
      test('returns identity for existing agent', () async {
        final identity = makeTestIdentity(id: 'agent-1', agentId: 'agent-1');

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
        final activeAgent = makeTestIdentity(
          id: 'a1',
          agentId: 'a1',
          displayName: 'Active',
        );
        final dormantAgent = makeTestIdentity(
          id: 'a2',
          agentId: 'a2',
          displayName: 'Dormant',
          lifecycle: AgentLifecycle.dormant,
        );

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
          content: 'All good',
        ) as AgentReportEntity;

        when(() => mockRepository.getLatestReport('agent-1', 'current'))
            .thenAnswer((_) async => report);

        final result = await service.getAgentReport('agent-1');

        expect(result, isNotNull);
        expect(result!.id, 'report-1');
        expect(result.scope, 'current');
        expect(result.content, 'All good');
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
        final identity = makeTestIdentity(id: 'agent-1', agentId: 'agent-1');

        when(() => mockRepository.getEntity('agent-1'))
            .thenAnswer((_) async => identity);
        // syncService stubs set up in setUp
        when(() => mockOrchestrator.removeSubscriptions('agent-1'))
            .thenReturn(null);

        final result = await service.pauseAgent('agent-1');

        expect(result, isTrue);

        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;
        final updated = captured.first as AgentIdentityEntity;
        expect(updated.lifecycle, AgentLifecycle.dormant);
        expect(updated.destroyedAt, isNull);

        verify(() => mockOrchestrator.removeSubscriptions('agent-1')).called(1);
      });
    });

    group('resumeAgent', () {
      test('sets lifecycle to active and returns true', () async {
        final identity = makeTestIdentity(
          id: 'agent-1',
          agentId: 'agent-1',
          lifecycle: AgentLifecycle.dormant,
        );

        when(() => mockRepository.getEntity('agent-1'))
            .thenAnswer((_) async => identity);
        // syncService stubs set up in setUp

        final result = await service.resumeAgent('agent-1');

        expect(result, isTrue);

        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;
        final updated = captured.first as AgentIdentityEntity;
        expect(updated.lifecycle, AgentLifecycle.active);
        expect(updated.destroyedAt, isNull);
      });
    });

    group('destroyAgent', () {
      test(
          'sets lifecycle to destroyed, sets destroyedAt, '
          'and unregisters subscriptions', () async {
        final identity = makeTestIdentity(id: 'agent-1', agentId: 'agent-1');

        when(() => mockRepository.getEntity('agent-1'))
            .thenAnswer((_) async => identity);
        // syncService stubs set up in setUp
        when(() => mockOrchestrator.removeSubscriptions('agent-1'))
            .thenReturn(null);

        final result = await service.destroyAgent('agent-1');

        expect(result, isTrue);

        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;
        final updated = captured.first as AgentIdentityEntity;
        expect(updated.lifecycle, AgentLifecycle.destroyed);
        expect(updated.destroyedAt, isNotNull);

        verify(() => mockOrchestrator.removeSubscriptions('agent-1')).called(1);
      });
    });

    // Consolidated: all three lifecycle methods return false for missing agents.
    for (final entry in <String, Future<bool> Function(AgentService, String)>{
      'pauseAgent': (s, id) => s.pauseAgent(id),
      'resumeAgent': (s, id) => s.resumeAgent(id),
      'destroyAgent': (s, id) => s.destroyAgent(id),
    }.entries) {
      test('${entry.key} returns false for non-existent agent', () async {
        when(() => mockRepository.getEntity('non-existent'))
            .thenAnswer((_) async => null);

        final result = await entry.value(service, 'non-existent');

        expect(result, isFalse);
        verifyNever(() => mockSyncService.upsertEntity(any()));
      });
    }

    group('deleteAgent', () {
      test('destroys agent first if not already destroyed, then hard-deletes',
          () async {
        final identity = makeTestIdentity(id: 'agent-1', agentId: 'agent-1');

        when(() => mockRepository.getEntity('agent-1'))
            .thenAnswer((_) async => identity);
        // syncService stubs set up in setUp
        when(() => mockOrchestrator.removeSubscriptions('agent-1'))
            .thenReturn(null);
        when(() => mockRepository.hardDeleteAgent('agent-1'))
            .thenAnswer((_) async {});

        await service.deleteAgent('agent-1');

        // destroyAgent path: upsertEntity called with destroyed lifecycle
        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;
        expect(captured, hasLength(1));
        final updated = captured.first as AgentIdentityEntity;
        expect(updated.lifecycle, AgentLifecycle.destroyed);
        expect(updated.destroyedAt, isNotNull);

        // subscriptions removed via destroyAgent
        verify(() => mockOrchestrator.removeSubscriptions('agent-1')).called(1);

        // hard-delete called after destroy
        verify(() => mockRepository.hardDeleteAgent('agent-1')).called(1);
      });

      test('skips lifecycle update for already-destroyed agent', () async {
        final destroyedIdentity = makeTestIdentity(
          id: 'agent-2',
          agentId: 'agent-2',
          displayName: 'Destroyed Agent',
          lifecycle: AgentLifecycle.destroyed,
        );

        when(() => mockRepository.getEntity('agent-2'))
            .thenAnswer((_) async => destroyedIdentity);
        when(() => mockOrchestrator.removeSubscriptions('agent-2'))
            .thenReturn(null);
        when(() => mockRepository.hardDeleteAgent('agent-2'))
            .thenAnswer((_) async {});

        await service.deleteAgent('agent-2');

        // no lifecycle update for an already-destroyed agent
        verifyNever(() => mockSyncService.upsertEntity(any()));

        // subscriptions still removed
        verify(() => mockOrchestrator.removeSubscriptions('agent-2')).called(1);

        // hard-delete still called
        verify(() => mockRepository.hardDeleteAgent('agent-2')).called(1);
      });

      test('handles non-existent agent gracefully', () async {
        when(() => mockRepository.getEntity('non-existent'))
            .thenAnswer((_) async => null);
        when(() => mockOrchestrator.removeSubscriptions('non-existent'))
            .thenReturn(null);
        when(() => mockRepository.hardDeleteAgent('non-existent'))
            .thenAnswer((_) async {});

        await service.deleteAgent('non-existent');

        // no lifecycle update when agent not found
        verifyNever(() => mockSyncService.upsertEntity(any()));

        // subscriptions removed even when agent not found
        verify(() => mockOrchestrator.removeSubscriptions('non-existent'))
            .called(1);

        // hard-delete still called
        verify(() => mockRepository.hardDeleteAgent('non-existent')).called(1);
      });
    });
  });
}
