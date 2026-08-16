import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/classes/relationship_trigger_tokens.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/workflow/wake_result.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/runtime/relationship_runtime_maintenance.dart';
import 'package:lotti/features/relationships/service/relationship_agent_service.dart';
import 'package:lotti/features/relationships/service/relationship_chat_service.dart';
import 'package:lotti/features/relationships/state/relationship_agent_providers.dart';
import 'package:lotti/features/relationships/workflow/relationship_agent_workflow.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  const agentId = 'relationship_agent:person-1';

  AgentIdentityEntity identity({AgentConfig config = const AgentConfig()}) =>
      AgentDomainEntity.agent(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.relationshipAgent,
            displayName: 'Anna',
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: '$agentId:state',
            config: config,
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
    'the router splits the tiers: escalation and Brief me enter the LLM '
    'tier, a chat token carries its durable turn, everything else stays '
    'deterministic (plan v2 phase 5)',
    () async {
      final phaseA = MockRelationshipAgentPhaseA();
      final workflow = MockRelationshipAgentWorkflow();
      when(
        () => phaseA.execute(
          agentIdentity: any(named: 'agentIdentity'),
          runKey: any(named: 'runKey'),
          triggerTokens: any(named: 'triggerTokens'),
          threadId: any(named: 'threadId'),
        ),
      ).thenAnswer((_) async => const WakeResult(success: true));
      when(
        () => workflow.execute(
          agentIdentity: any(named: 'agentIdentity'),
          runKey: any(named: 'runKey'),
          triggerTokens: any(named: 'triggerTokens'),
          threadId: any(named: 'threadId'),
        ),
      ).thenAnswer((_) async => const WakeResult(success: true));
      when(
        () => workflow.executeUserMessage(
          agentIdentity: any(named: 'agentIdentity'),
          runKey: any(named: 'runKey'),
          triggerTokens: any(named: 'triggerTokens'),
          threadId: any(named: 'threadId'),
          messageId: any(named: 'messageId'),
        ),
      ).thenAnswer((_) async => const WakeResult(success: true));
      final c = container(
        overrides: [
          relationshipAgentPhaseAProvider.overrideWithValue(phaseA),
          relationshipAgentWorkflowProvider.overrideWithValue(workflow),
        ],
      );
      final runner = c.read(
        relationshipAgentWakeRunnersProvider,
      )[AgentKinds.relationshipAgent]!;

      // Escalation token → LLM tier.
      await runner(
        agentIdentity: identity(),
        runKey: 'run-2',
        triggerTokens: {'relationship-escalation:2026-08-08'},
        threadId: 'thread-2',
      );
      verify(
        () => workflow.execute(
          agentIdentity: any(named: 'agentIdentity'),
          runKey: 'run-2',
          triggerTokens: any(named: 'triggerTokens'),
          threadId: any(named: 'threadId'),
        ),
      ).called(1);

      // Brief me token → LLM tier.
      await runner(
        agentIdentity: identity(),
        runKey: 'run-3',
        triggerTokens: const {relationshipReportRefreshTriggerToken},
        threadId: 'thread-3',
      );
      verify(
        () => workflow.execute(
          agentIdentity: any(named: 'agentIdentity'),
          runKey: 'run-3',
          triggerTokens: any(named: 'triggerTokens'),
          threadId: any(named: 'threadId'),
        ),
      ).called(1);

      // Chat token → LLM tier with its durable source turn.
      await runner(
        agentIdentity: identity(),
        runKey: 'run-4',
        triggerTokens: {relationshipChatMessageTriggerToken('msg-1')},
        threadId: 'thread-4',
      );
      verify(
        () => workflow.executeUserMessage(
          agentIdentity: any(named: 'agentIdentity'),
          runKey: 'run-4',
          triggerTokens: any(named: 'triggerTokens'),
          threadId: any(named: 'threadId'),
          messageId: 'msg-1',
        ),
      ).called(1);

      // A plain signal/cadence wake stays on the €0 tier.
      await runner(
        agentIdentity: identity(),
        runKey: 'run-5',
        triggerTokens: {'person-1'},
        threadId: 'thread-5',
      );
      verify(
        () => phaseA.execute(
          agentIdentity: any(named: 'agentIdentity'),
          runKey: 'run-5',
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
        () => relationshipRepository.getRelationshipByIdUnfiltered('person-1'),
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
      when(
        () => agentRepository.getLatestReport(any(), any()),
      ).thenAnswer((_) async => null);
      when(
        () => agentRepository.getEntitiesByAgentId(
          any(),
          type: any(named: 'type'),
        ),
      ).thenAnswer((_) async => []);
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

  test('the provider graph wires the concrete service, maintenance, '
      'workflow and chat service', () {
    final c = container(
      overrides: [
        aiConfigRepositoryProvider.overrideWithValue(MockAiConfigRepository()),
        cloudInferenceRepositoryProvider.overrideWithValue(
          MockCloudInferenceRepository(),
        ),
      ],
    );
    expect(
      c.read(relationshipAgentServiceProvider),
      isA<RelationshipAgentService>(),
    );
    expect(
      c.read(relationshipRuntimeMaintenanceProvider),
      isA<RelationshipRuntimeMaintenance>(),
    );
    expect(
      c.read(relationshipAgentWorkflowProvider),
      isA<RelationshipAgentWorkflow>(),
    );
    expect(
      c.read(relationshipChatServiceProvider),
      isA<RelationshipChatService>(),
    );
  });

  group('relationshipBriefingDisclosureProvider', () {
    const relationshipId = 'person-1';
    const profileId = 'profile-1';

    late MockAiConfigRepository aiConfigRepository;
    late MockRelationshipRepository relationshipRepository;
    late MockAgentRepository agentRepository;

    final meliousProvider =
        AiConfig.inferenceProvider(
              id: 'melious-provider',
              baseUrl: 'https://api.melious.ai',
              apiKey: 'key',
              name: 'Melious',
              createdAt: DateTime(2026),
              inferenceProviderType: InferenceProviderType.melious,
            )
            as AiConfigInferenceProvider;
    final ollamaProvider =
        AiConfig.inferenceProvider(
              id: 'ollama-provider',
              baseUrl: 'http://localhost:11434',
              apiKey: '',
              name: 'Ollama',
              createdAt: DateTime(2026),
              inferenceProviderType: InferenceProviderType.ollama,
            )
            as AiConfigInferenceProvider;

    AiConfigModel model(String id, String providerId) =>
        AiConfig.model(
              id: id,
              name: id,
              providerModelId: id == 'model-glm' ? meliousGlm52ModelId : id,
              inferenceProviderId: providerId,
              createdAt: DateTime(2026),
              inputModalities: const [Modality.text],
              outputModalities: const [Modality.text],
              isReasoningModel: true,
              supportsFunctionCalling: true,
              description: id,
            )
            as AiConfigModel;

    AiConfigInferenceProfile profile(String thinkingModelId) =>
        AiConfig.inferenceProfile(
              id: profileId,
              name: 'My profile',
              createdAt: DateTime(2026),
              thinkingModelId: thinkingModelId,
            )
            as AiConfigInferenceProfile;

    RelationshipEntry person({String? withProfileId}) => RelationshipEntry(
      meta: Metadata(
        id: relationshipId,
        createdAt: DateTime(2026, 8),
        updatedAt: DateTime(2026, 8),
        dateFrom: DateTime(2026, 8),
        dateTo: DateTime(2026, 8),
      ),
      data: RelationshipData(
        title: 'Anna',
        important: true,
        profileId: withProfileId,
        status: RelationshipStatus.active(
          id: 'status-1',
          createdAt: DateTime(2026, 8),
          utcOffset: 0,
        ),
      ),
    );

    setUp(() {
      aiConfigRepository = MockAiConfigRepository();
      relationshipRepository = MockRelationshipRepository();
      agentRepository = MockAgentRepository();
      when(
        () => aiConfigRepository.getConfigsByType(any()),
      ).thenAnswer((_) async => []);
      when(
        () => aiConfigRepository.getConfigById(any()),
      ).thenAnswer((_) async => null);
      when(
        () => agentRepository.getEntity(any()),
      ).thenAnswer((_) async => null);
    });

    Future<String?> disclosure() {
      final c = ProviderContainer(
        overrides: [
          aiConfigRepositoryProvider.overrideWithValue(aiConfigRepository),
          relationshipRepositoryProvider.overrideWithValue(
            relationshipRepository,
          ),
          agentRepositoryProvider.overrideWithValue(agentRepository),
        ],
      );
      addTearDown(c.dispose);
      return c.read(
        relationshipBriefingDisclosureProvider(relationshipId).future,
      );
    }

    test('a fully local profile needs no disclosure', () async {
      when(
        () => relationshipRepository.getRelationshipById(relationshipId),
      ).thenAnswer((_) async => person(withProfileId: profileId));
      when(
        () => aiConfigRepository.getConfigById(profileId),
      ).thenAnswer((_) async => profile('model-local'));
      when(
        () => aiConfigRepository.getConfigsByType(AiConfigType.model),
      ).thenAnswer((_) async => [model('model-local', 'ollama-provider')]);
      when(
        () => aiConfigRepository.getConfigsByType(
          AiConfigType.inferenceProvider,
        ),
      ).thenAnswer((_) async => [ollamaProvider]);

      expect(await disclosure(), isNull);
    });

    test('a cloud-routed profile names its thinking provider', () async {
      when(
        () => relationshipRepository.getRelationshipById(relationshipId),
      ).thenAnswer((_) async => person(withProfileId: profileId));
      when(
        () => aiConfigRepository.getConfigById(profileId),
      ).thenAnswer((_) async => profile('model-glm'));
      when(
        () => aiConfigRepository.getConfigById('model-glm'),
      ).thenAnswer((_) async => model('model-glm', 'melious-provider'));
      when(
        () => aiConfigRepository.getConfigById('melious-provider'),
      ).thenAnswer((_) async => meliousProvider);
      when(
        () => aiConfigRepository.getConfigsByType(AiConfigType.model),
      ).thenAnswer((_) async => [model('model-glm', 'melious-provider')]);
      when(
        () => aiConfigRepository.getConfigsByType(
          AiConfigType.inferenceProvider,
        ),
      ).thenAnswer((_) async => [meliousProvider]);

      expect(await disclosure(), 'Melious');
    });

    test('the agent config profile routes when the relationship has none — '
        'the dialog names the provider Phase B actually uses', () async {
      // The config profile routes through Acme while the default model
      // would route through Melious: identical resolution chains in the
      // dialog and Phase B are exactly what this pins.
      final acmeProvider =
          AiConfig.inferenceProvider(
                id: 'acme-provider',
                baseUrl: 'https://api.acme.ai',
                apiKey: 'key',
                name: 'Acme',
                createdAt: DateTime(2026),
                inferenceProviderType: InferenceProviderType.melious,
              )
              as AiConfigInferenceProvider;
      when(
        () => relationshipRepository.getRelationshipById(relationshipId),
      ).thenAnswer((_) async => person());
      when(
        () => agentRepository.getEntity(
          relationshipAgentIdFor(relationshipId),
        ),
      ).thenAnswer(
        (_) async => identity(config: const AgentConfig(profileId: profileId)),
      );
      when(
        () => aiConfigRepository.getConfigById(profileId),
      ).thenAnswer((_) async => profile('model-acme'));
      when(
        () => aiConfigRepository.getConfigById('model-acme'),
      ).thenAnswer((_) async => model('model-acme', 'acme-provider'));
      when(
        () => aiConfigRepository.getConfigById('acme-provider'),
      ).thenAnswer((_) async => acmeProvider);
      when(
        () => aiConfigRepository.getConfigsByType(AiConfigType.model),
      ).thenAnswer(
        (_) async => [
          model('model-acme', 'acme-provider'),
          model('model-glm', 'melious-provider'),
        ],
      );
      when(
        () => aiConfigRepository.getConfigsByType(
          AiConfigType.inferenceProvider,
        ),
      ).thenAnswer((_) async => [acmeProvider, meliousProvider]);

      expect(await disclosure(), 'Acme');
    });

    test('a dangling profile id falls through to the default cloud model '
        'and still disclosures — never silently local', () async {
      when(
        () => relationshipRepository.getRelationshipById(relationshipId),
      ).thenAnswer((_) async => person(withProfileId: 'gone'));
      when(
        () => aiConfigRepository.getConfigsByType(AiConfigType.model),
      ).thenAnswer((_) async => [model('model-glm', 'melious-provider')]);
      when(
        () => aiConfigRepository.getConfigById('melious-provider'),
      ).thenAnswer((_) async => meliousProvider);

      expect(await disclosure(), 'Melious');
    });

    test('no profile and no resolvable default yields null — the card '
        'proceeds without naming anyone', () async {
      when(
        () => relationshipRepository.getRelationshipById(relationshipId),
      ).thenAnswer((_) async => person());

      expect(await disclosure(), isNull);
    });
  });
}
