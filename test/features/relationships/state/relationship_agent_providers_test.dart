import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/workflow/wake_result.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/runtime/relationship_runtime_maintenance.dart';
import 'package:lotti/features/relationships/service/relationship_agent_service.dart';
import 'package:lotti/features/relationships/state/relationship_agent_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  const agentId = 'relationship_agent:person-1';

  AgentIdentityEntity identity() =>
      AgentDomainEntity.agent(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.relationshipAgent,
            displayName: 'Anna',
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: '$agentId:state',
            config: const AgentConfig(),
            createdAt: DateTime(2026, 8, 16),
            updatedAt: DateTime(2026, 8, 16),
            vectorClock: null,
          )
          as AgentIdentityEntity;

  ProviderContainer container({List<Override> overrides = const []}) {
    final c = ProviderContainer(
      overrides: [
        agentRepositoryProvider.overrideWithValue(MockAgentRepository()),
        agentSyncServiceProvider.overrideWithValue(MockAgentSyncService()),
        agentServiceProvider.overrideWithValue(MockAgentService()),
        wakeOrchestratorProvider.overrideWithValue(MockWakeOrchestrator()),
        relationshipRepositoryProvider.overrideWithValue(
          MockRelationshipRepository(),
        ),
        domainLoggerProvider.overrideWithValue(MockDomainLogger()),
        ...overrides,
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test(
    'the relationship_agent kind resolves to ITS registered runner — '
    'never the silent task-agent fallback (the documented ADR 0054 trap)',
    () async {
      // The regression the plan mandates: an unregistered kind falls through
      // to the task-agent workflow in agent_wiring.dart without an error.
      // This pins that (a) the kind is present in the contributed runner map
      // and (b) invoking it reaches the relationship Phase A.
      final phaseA = MockRelationshipAgentPhaseA();
      when(
        () => phaseA.execute(
          agentIdentity: any(named: 'agentIdentity'),
          runKey: any(named: 'runKey'),
          triggerTokens: any(named: 'triggerTokens'),
          threadId: any(named: 'threadId'),
        ),
      ).thenAnswer((_) async => const WakeResult(success: true));

      final c = container(
        overrides: [relationshipAgentPhaseAProvider.overrideWithValue(phaseA)],
      );
      final runners = c.read(relationshipAgentWakeRunnersProvider);
      expect(runners.keys, [AgentKinds.relationshipAgent]);

      final result = await runners[AgentKinds.relationshipAgent]!(
        agentIdentity: identity(),
        runKey: 'run-1',
        triggerTokens: {'person-1'},
        threadId: 'thread-1',
      );

      expect(result.success, isTrue);
      verify(
        () => phaseA.execute(
          agentIdentity: any(named: 'agentIdentity'),
          runKey: 'run-1',
          triggerTokens: {'person-1'},
          threadId: 'thread-1',
        ),
      ).called(1);
    },
  );

  test(
    'every wake — cadence, signal, even a fired escalation — takes the '
    'deterministic tier until the LLM tier ships (plan v2 phase 5)',
    () async {
      final phaseA = MockRelationshipAgentPhaseA();
      when(
        () => phaseA.execute(
          agentIdentity: any(named: 'agentIdentity'),
          runKey: any(named: 'runKey'),
          triggerTokens: any(named: 'triggerTokens'),
          threadId: any(named: 'threadId'),
        ),
      ).thenAnswer((_) async => const WakeResult(success: true));
      final c = container(
        overrides: [relationshipAgentPhaseAProvider.overrideWithValue(phaseA)],
      );
      final runner = c.read(
        relationshipAgentWakeRunnersProvider,
      )[AgentKinds.relationshipAgent]!;

      await runner(
        agentIdentity: identity(),
        runKey: 'run-2',
        triggerTokens: {'relationship-escalation:2026-08-08'},
        threadId: 'thread-2',
      );
      verify(
        () => phaseA.execute(
          agentIdentity: any(named: 'agentIdentity'),
          runKey: 'run-2',
          triggerTokens: any(named: 'triggerTokens'),
          threadId: any(named: 'threadId'),
        ),
      ).called(1);
    },
  );

  test(
    'the real Phase A provider wires the escalation callback to the '
    'scheduled-wake manager — a local transition is scanned promptly',
    () async {
      final agentRepository = MockAgentRepository();
      final relationshipRepository = MockRelationshipRepository();
      final wakeManager = MockScheduledWakeManager();
      when(
        () => agentRepository.getEntity(any()),
      ).thenAnswer((_) async => null);
      when(
        () => agentRepository.getLinksFrom(
          agentId,
          type: AgentLinkTypes.agentRelationship,
        ),
      ).thenAnswer(
        (_) async => [
          AgentLink.agentRelationship(
            id: relationshipAgentLinkId(agentId),
            fromId: agentId,
            toId: 'person-1',
            createdAt: DateTime(2026, 8),
            updatedAt: DateTime(2026, 8),
            vectorClock: null,
          ),
        ],
      );
      // Overdue: tracking started 2026-07-01 with the 30-day default.
      when(
        () => relationshipRepository.getRelationshipById('person-1'),
      ).thenAnswer(
        (_) async => RelationshipEntry(
          meta: Metadata(
            id: 'person-1',
            createdAt: DateTime(2026, 7),
            updatedAt: DateTime(2026, 7),
            dateFrom: DateTime(2026, 7),
            dateTo: DateTime(2026, 7),
          ),
          data: RelationshipData(
            title: 'Anna',
            important: true,
            status: RelationshipStatus.active(
              id: 'status-1',
              createdAt: DateTime(2026, 7),
              utcOffset: 0,
            ),
          ),
        ),
      );
      when(
        () => relationshipRepository.getAllCheckInsForRelationship('person-1'),
      ).thenAnswer((_) async => []);
      when(wakeManager.requestCheck).thenAnswer((_) {});
      final syncService = MockAgentSyncService();
      when(() => syncService.upsertEntity(any())).thenAnswer((_) async {});

      final c = ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(agentRepository),
          agentSyncServiceProvider.overrideWithValue(syncService),
          relationshipRepositoryProvider.overrideWithValue(
            relationshipRepository,
          ),
          scheduledWakeManagerProvider.overrideWithValue(wakeManager),
        ],
      );
      addTearDown(c.dispose);

      await withClock(
        Clock.fixed(DateTime(2026, 8, 16, 12)),
        () => c
            .read(relationshipAgentPhaseAProvider)
            .execute(
              agentIdentity: identity(),
              runKey: 'run-3',
              triggerTokens: const {},
              threadId: 'thread-3',
            ),
      );

      verify(wakeManager.requestCheck).called(1);
    },
  );

  test('the provider graph wires the concrete service and maintenance', () {
    final c = container();
    expect(
      c.read(relationshipAgentServiceProvider),
      isA<RelationshipAgentService>(),
    );
    expect(
      c.read(relationshipRuntimeMaintenanceProvider),
      isA<RelationshipRuntimeMaintenance>(),
    );
  });
}
