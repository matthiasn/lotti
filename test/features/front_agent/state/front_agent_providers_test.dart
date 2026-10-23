import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/workflow/wake_result.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/service/front_agent_service.dart';
import 'package:lotti/features/front_agent/service/front_chat_service.dart';
import 'package:lotti/features/front_agent/service/front_routing_index_builder.dart';
import 'package:lotti/features/front_agent/state/front_agent_providers.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_workflow.dart';
import 'package:lotti/providers/agent_repository_providers.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/providers/update_notifications_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../agents/test_data/entity_factories.dart';
import '../../agents/workflow/task_agent_workflow_test_helpers.dart';

/// A workflow that records what the runner asked of it instead of routing.
class _RecordingWorkflow extends FrontAgentWorkflow {
  _RecordingWorkflow({
    required super.repository,
    required super.syncService,
    required super.conversationRepository,
    required super.cloudInferenceRepository,
    required super.aiConfigRepository,
    required super.indexBuilder,
    required super.domainLogger,
  });

  final calls = <({String messageId, String runKey, String threadId})>[];

  @override
  Future<WakeResult> executeUserMessage({
    required AgentIdentityEntity agentIdentity,
    required String runKey,
    required Set<String> triggerTokens,
    required String threadId,
    required String messageId,
  }) async {
    calls.add((messageId: messageId, runKey: runKey, threadId: threadId));
    return const WakeResult(success: true, reportUpdated: true);
  }
}

void main() {
  setUpAll(registerAllFallbackValues);

  late MockAgentRepository repository;
  late MockAiConfigRepository aiConfigRepository;
  late _RecordingWorkflow recording;
  late ProviderContainer container;

  final identity = makeTestIdentity(
    id: frontAgentId,
    agentId: frontAgentId,
    kind: AgentKinds.frontAgent,
  );

  setUp(() {
    repository = MockAgentRepository();
    aiConfigRepository = MockAiConfigRepository();
    recording = _RecordingWorkflow(
      repository: repository,
      syncService: MockAgentSyncService(),
      conversationRepository: MockConversationRepository(
        MockConversationManager(),
      ),
      cloudInferenceRepository: MockCloudInferenceRepository(),
      aiConfigRepository: aiConfigRepository,
      indexBuilder: FrontRoutingIndexBuilder(
        journalDb: MockJournalDb(),
        agentRepository: repository,
      ),
      domainLogger: MockDomainLogger(),
    );
    container = ProviderContainer(
      overrides: [
        frontAgentWorkflowProvider.overrideWithValue(recording),
        agentRepositoryProvider.overrideWithValue(repository),
        aiConfigRepositoryProvider.overrideWithValue(aiConfigRepository),
        domainLoggerProvider.overrideWithValue(MockDomainLogger()),
      ],
    );
    addTearDown(container.dispose);
  });

  group('frontAgentWakeRunnersProvider', () {
    test('registers exactly the front_agent kind', () {
      final runners = container.read(frontAgentWakeRunnersProvider);
      expect(runners.keys, [AgentKinds.frontAgent]);
    });

    test('a chat token runs the workflow for that message', () async {
      final runner = container.read(
        frontAgentWakeRunnersProvider,
      )[AgentKinds.frontAgent]!;

      final result = await runner(
        agentIdentity: identity,
        runKey: 'run-1',
        triggerTokens: {'other', frontChatMessageTriggerToken('msg-7')},
        threadId: 'thread-1',
      );

      expect(result.reportUpdated, isTrue);
      expect(recording.calls, [
        (messageId: 'msg-7', runKey: 'run-1', threadId: 'thread-1'),
      ]);
    });

    test('any other token is a successful no-op: the front agent has no '
        'scheduled or subscription work', () async {
      final runner = container.read(
        frontAgentWakeRunnersProvider,
      )[AgentKinds.frontAgent]!;

      final result = await runner(
        agentIdentity: identity,
        runKey: 'run-2',
        triggerTokens: {'creation'},
        threadId: 'thread-2',
      );

      expect(result.success, isTrue);
      expect(result.reportUpdated, isFalse);
      expect(recording.calls, isEmpty);
    });
  });

  group('resolveFrontAgentSetup', () {
    test('resolves nothing for an unknown agent id', () async {
      when(() => repository.getEntity('ghost')).thenAnswer((_) async => null);
      final setup = await container.read(
        _setupProvider('ghost').future,
      );
      expect(setup, isNull);
      verifyNever(() => aiConfigRepository.getDefaultProfileId());
    });

    test("resolves the identity's own route, never a template's", () async {
      when(
        () => repository.getEntity(frontAgentId),
      ).thenAnswer((_) async => identity);
      when(
        () => aiConfigRepository.getDefaultProfileId(),
      ).thenAnswer((_) async => null);
      when(
        () => aiConfigRepository.getConfigsByType(any()),
      ).thenAnswer((_) async => const []);

      final setup = await container.read(
        _setupProvider(frontAgentId).future,
      );

      // Nothing configured and no built-in model present: no route.
      expect(setup, isNull);
      verify(() => aiConfigRepository.getDefaultProfileId()).called(1);
    });

    test('hands the registry the resolved setup when the built-in model '
        'is configured', () async {
      final provider =
          AiConfig.inferenceProvider(
                id: 'melious-provider',
                baseUrl: 'https://api.melious.ai',
                apiKey: 'key',
                name: 'Melious',
                createdAt: DateTime(2026),
                inferenceProviderType: InferenceProviderType.melious,
              )
              as AiConfigInferenceProvider;
      final flash =
          AiConfig.model(
                id: 'model-flash',
                name: 'Flash',
                providerModelId: meliousDeepseekV41FlashModelId,
                inferenceProviderId: provider.id,
                createdAt: DateTime(2026),
                inputModalities: const [Modality.text],
                outputModalities: const [Modality.text],
                isReasoningModel: true,
                supportsFunctionCalling: true,
                description: 'flash',
              )
              as AiConfigModel;
      when(
        () => repository.getEntity(frontAgentId),
      ).thenAnswer((_) async => identity);
      when(
        () => aiConfigRepository.getDefaultProfileId(),
      ).thenAnswer((_) async => null);
      when(
        () => aiConfigRepository.getConfigsByType(AiConfigType.model),
      ).thenAnswer((_) async => [flash]);
      when(
        () => aiConfigRepository.getConfigById(provider.id),
      ).thenAnswer((_) async => provider);

      final setup =
          await container.read(_setupProvider(frontAgentId).future)
              as ResolvedAgentSetup?;

      expect(setup?.status, AgentSetupResolutionStatus.resolved);
      expect(setup?.profile?.thinkingModelId, meliousDeepseekV41FlashModelId);
    });
  });

  group('wiring', () {
    test('every provider of the feature builds from its leaves', () {
      final wired = ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(repository),
          aiConfigRepositoryProvider.overrideWithValue(aiConfigRepository),
          domainLoggerProvider.overrideWithValue(MockDomainLogger()),
          journalDbProvider.overrideWithValue(MockJournalDb()),
          agentSyncServiceProvider.overrideWithValue(MockAgentSyncService()),
          agentServiceProvider.overrideWithValue(MockAgentService()),
          wakeOrchestratorProvider.overrideWithValue(MockWakeOrchestrator()),
          updateNotificationsProvider.overrideWithValue(
            MockUpdateNotifications(),
          ),
          cloudInferenceRepositoryProvider.overrideWithValue(
            MockCloudInferenceRepository(),
          ),
          conversationRepositoryProvider.overrideWith(
            () => MockConversationRepository(MockConversationManager()),
          ),
        ],
      );
      addTearDown(wired.dispose);

      // No full-text index is registered in a bare test, so the builder
      // has no corpus matcher.
      final builder = wired.read(frontRoutingIndexBuilderProvider);
      expect(builder.fts5Db, isNull);
      expect(wired.read(frontAgentWorkflowProvider), isA<FrontAgentWorkflow>());
      expect(wired.read(frontAgentServiceProvider), isA<FrontAgentService>());
      expect(wired.read(frontChatServiceProvider), isA<FrontChatService>());
    });
  });
}

/// Exercises the resolver through a provider, the way the registry calls it.
FutureProvider<Object?> _setupProvider(String agentId) =>
    FutureProvider<Object?>((ref) => resolveFrontAgentSetup(ref, agentId));
