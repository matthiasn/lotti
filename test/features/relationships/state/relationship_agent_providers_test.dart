import 'dart:async';

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
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/agents/workflow/wake_result.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/state/ai_runtime_settings_controller.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/notifications/repository/notification_repository.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/runtime/relationship_runtime_maintenance.dart';
import 'package:lotti/features/relationships/service/relationship_agent_service.dart';
import 'package:lotti/features/relationships/service/relationship_chat_service.dart';
import 'package:lotti/features/relationships/state/relationship_agent_providers.dart';
import 'package:lotti/features/relationships/workflow/relationship_agent_workflow.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart' show journalDbProvider;
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../categories/test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  // `relationshipReminderServiceProvider` resolves the notification repository
  // from getIt (it is a plain singleton there, not a Riverpod provider), so the
  // real provider graph cannot be built without it. Registered rather than
  // overridden so the graph under test stays the production one.
  setUp(() {
    getIt.registerSingleton<NotificationRepository>(
      MockNotificationRepository(),
    );
  });

  tearDown(() async {
    await getIt.reset();
  });

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

  test('route edits and synced identities request scans, ordinary agent writes '
      'do not', () async {
    final updates = StreamController<Set<String>>.broadcast(sync: true);
    addTearDown(updates.close);
    final notifications = MockUpdateNotifications();
    when(() => notifications.updateStream).thenAnswer((_) => updates.stream);
    final manager = MockScheduledWakeManager();
    final agentService = MockRelationshipAgentService();
    when(
      () => agentService.registerSubscription(agentId),
    ).thenAnswer((_) async {});
    final c = container(
      overrides: [
        maybeUpdateNotificationsProvider.overrideWithValue(notifications),
        scheduledWakeManagerProvider.overrideWithValue(manager),
        relationshipAgentServiceProvider.overrideWithValue(agentService),
        aiConfigRepositoryProvider.overrideWithValue(MockAiConfigRepository()),
      ],
    );
    final maintenance = c
        .listen(relationshipRuntimeMaintenanceProvider, (_, _) {})
        .read();
    await c.read(defaultInferenceProfileControllerProvider.future);

    updates.add({agentId, agentNotification});
    verifyNever(manager.requestCheck);
    for (final token in [
      AgentNotificationScopes.inferenceSetup,
      relationshipNotification,
      categoriesNotification,
    ]) {
      updates.add({token});
      verify(manager.requestCheck).called(1);
    }
    await maintenance.onIdentityReceived(identity());
    verify(manager.requestCheck).called(1);
    c.dispose();
    updates.add({AgentNotificationScopes.inferenceSetup});
    verifyNoMoreInteractions(manager);
  });

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
          // Phase A now also carries the OS-reminder sink, whose service takes
          // a logger; without this the real graph reaches the unoverridable
          // loggingServiceProvider.
          domainLoggerProvider.overrideWithValue(MockDomainLogger()),
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
        updateNotificationsProvider.overrideWithValue(
          MockUpdateNotifications(),
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

  group('relationshipCategoryProfileLookupProvider', () {
    test(
      "answers the category's default profile through the journal db, "
      'and null for a category without one or a category that is gone',
      () async {
        final journalDb = MockJournalDb();
        when(() => journalDb.getCategoryById('cat-with')).thenAnswer(
          (_) async => CategoryTestUtils.createTestCategory(
            id: 'cat-with',
            name: 'Family',
            defaultProfileId: 'profile-family',
          ),
        );
        when(() => journalDb.getCategoryById('cat-without')).thenAnswer(
          (_) async => CategoryTestUtils.createTestCategory(
            id: 'cat-without',
            name: 'Work',
          ),
        );
        when(
          () => journalDb.getCategoryById('cat-gone'),
        ).thenAnswer((_) async => null);
        final c = ProviderContainer(
          overrides: [journalDbProvider.overrideWithValue(journalDb)],
        );
        addTearDown(c.dispose);
        final lookup = c.read(relationshipCategoryProfileLookupProvider);

        expect(await lookup('cat-with'), 'profile-family');
        expect(await lookup('cat-without'), isNull);
        expect(await lookup('cat-gone'), isNull);
      },
    );
  });

  group('relationshipAgentResolvedSetupProvider', () {
    const relationshipId = 'person-1';
    const profileId = 'profile-1';

    late MockAiConfigRepository aiConfigRepository;
    late MockRelationshipRepository relationshipRepository;
    late MockAgentRepository agentRepository;
    late MockJournalDb journalDb;

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

    RelationshipEntry person({String? withProfileId, String? categoryId}) =>
        RelationshipEntry(
          meta: Metadata(
            id: relationshipId,
            createdAt: DateTime(2026, 8),
            updatedAt: DateTime(2026, 8),
            dateFrom: DateTime(2026, 8),
            dateTo: DateTime(2026, 8),
            categoryId: categoryId,
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
      journalDb = MockJournalDb();
      when(
        () => journalDb.getCategoryById(any()),
      ).thenAnswer((_) async => null);
    });

    AiConfigModel stubLocalSetup() {
      when(
        () => agentRepository.getLinksFrom(
          agentId,
          type: AgentLinkTypes.agentRelationship,
        ),
      ).thenAnswer(
        (_) async => [
          AgentLink.agentRelationship(
            id: 'link',
            fromId: agentId,
            toId: relationshipId,
            createdAt: DateTime(2026, 8),
            updatedAt: DateTime(2026, 8),
            vectorClock: null,
          ),
        ],
      );
      when(
        () => relationshipRepository.getRelationshipByIdUnfiltered(
          relationshipId,
        ),
      ).thenAnswer((_) async => person());
      final selectedModel = model('model-local', 'ollama-provider');
      when(
        () => aiConfigRepository.getConfigsByType(AiConfigType.model),
      ).thenAnswer((_) async => [selectedModel]);
      when(
        () => aiConfigRepository.getConfigById(profileId),
      ).thenAnswer((_) async => profile(selectedModel.id));
      when(
        () => aiConfigRepository.getConfigById('ollama-provider'),
      ).thenAnswer((_) async => ollamaProvider);
      when(
        () => aiConfigRepository.getConfigsByType(
          AiConfigType.inferenceProvider,
        ),
      ).thenAnswer((_) async => [ollamaProvider]);
      return selectedModel;
    }

    ProviderContainer setupContainer({
      AgentIdentityEntity? Function()? loadIdentity,
      List<Override> overrides = const [],
    }) {
      final c = ProviderContainer(
        overrides: [
          templateForAgentProvider.overrideWith((ref, id) async => null),
          aiConfigRepositoryProvider.overrideWithValue(aiConfigRepository),
          agentRepositoryProvider.overrideWithValue(agentRepository),
          agentIdentityProvider(
            agentId,
          ).overrideWith(
            (ref) async => loadIdentity == null ? identity() : loadIdentity(),
          ),
          relationshipRepositoryProvider.overrideWithValue(
            relationshipRepository,
          ),
          journalDbProvider.overrideWithValue(journalDb),
          ...overrides,
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test(
      'setup recovers when Settings selects a valid default',
      () async {
        String? defaultId = 'missing-profile';
        when(
          aiConfigRepository.getDefaultProfileId,
        ).thenAnswer((_) async => defaultId);
        when(() => aiConfigRepository.setDefaultProfileId(any())).thenAnswer((
          call,
        ) async {
          defaultId = call.positionalArguments.single as String?;
        });
        final selectedModel = stubLocalSetup();
        final c = setupContainer()
          ..listen(taskAgentResolvedSetupProvider(agentId), (_, _) {});
        await c.read(defaultInferenceProfileControllerProvider.future);
        expect(
          (await c.read(
            taskAgentResolvedSetupProvider(agentId).future,
          ))?.status,
          AgentSetupResolutionStatus.broken,
        );
        await c
            .read(defaultInferenceProfileControllerProvider.notifier)
            .selectProfile(profileId);
        final setup = await c.read(
          taskAgentResolvedSetupProvider(agentId).future,
        );
        expect(setup?.status, AgentSetupResolutionStatus.resolved);
        expect(setup?.profile?.thinkingModelId, selectedModel.providerModelId);
        expect(setup?.profile?.thinkingProvider.id, ollamaProvider.id);
      },
    );

    for (final token in [relationshipNotification, categoriesNotification]) {
      test('setup follows synced route changes from $token', () async {
        final selectedModel = stubLocalSetup();
        final updates = StreamController<Set<String>>.broadcast(sync: true);
        addTearDown(updates.close);
        final notifications = MockUpdateNotifications();
        when(
          () => notifications.updateStream,
        ).thenAnswer((_) => updates.stream);
        final c = setupContainer(
          overrides: [
            maybeUpdateNotificationsProvider.overrideWithValue(notifications),
          ],
        );
        final target = relationshipAgentResolvedSetupProvider(agentId);
        c.listen(target, (_, _) {});
        await c.read(defaultInferenceProfileControllerProvider.future);
        expect(
          (await c.read(target.future))?.status,
          AgentSetupResolutionStatus.broken,
        );

        if (token == relationshipNotification) {
          when(
            () => relationshipRepository.getRelationshipByIdUnfiltered(
              relationshipId,
            ),
          ).thenAnswer((_) async => person(withProfileId: profileId));
        } else {
          when(
            () => relationshipRepository.getRelationshipByIdUnfiltered(
              relationshipId,
            ),
          ).thenAnswer((_) async => person(categoryId: 'category'));
          when(() => journalDb.getCategoryById('category')).thenAnswer(
            (_) async => CategoryTestUtils.createTestCategory(
              id: 'category',
              name: 'Family',
              defaultProfileId: profileId,
            ),
          );
        }
        updates.add({'unrelated-entry'});
        await c.pump();
        expect(
          (await c.read(target.future))?.status,
          AgentSetupResolutionStatus.broken,
        );
        updates.add({token});
        final setup = await c.read(target.future);
        expect(setup?.status, AgentSetupResolutionStatus.resolved);
        expect(setup?.profile?.thinkingModelId, selectedModel.providerModelId);
        expect(setup?.profile?.thinkingProvider.id, ollamaProvider.id);
        c.dispose();
        expect(
          updates.hasListener,
          isFalse,
          reason: 'disposed setup must stop listening for route edits',
        );
      });
    }

    test(
      'disabled AI does not silently use the valid default profile',
      () async {
        stubLocalSetup();
        when(
          aiConfigRepository.getDefaultProfileId,
        ).thenAnswer((_) async => profileId);
        final c = setupContainer(
          loadIdentity: () => identity(
            config: const AgentConfig(
              inferenceSetup: AgentInferenceSetup(
                mode: AgentInferenceSetupMode.disabled,
                origin: AgentInferenceSetupOrigin.user,
              ),
            ),
          ),
        )..listen(relationshipAgentResolvedSetupProvider(agentId), (_, _) {});
        final setup = await c.read(
          relationshipAgentResolvedSetupProvider(agentId).future,
        );
        expect(setup?.status, AgentSetupResolutionStatus.disabled);
        expect(setup?.profile, isNull);
      },
    );

    test(
      'a deleted identity has no setup or default inference route',
      () async {
        stubLocalSetup();
        final c = setupContainer(
          loadIdentity: () => null,
        );
        expect(
          await c.read(relationshipAgentResolvedSetupProvider(agentId).future),
          isNull,
        );
        verifyNever(
          () => agentRepository.getLinksFrom(
            agentId,
            type: AgentLinkTypes.agentRelationship,
          ),
        );
      },
    );

    test(
      'changing the Settings default re-checks maintenance and reports the '
      'route configured',
      () async {
        String? selected;
        when(
          aiConfigRepository.getDefaultProfileId,
        ).thenAnswer((_) async => selected);
        when(
          () => aiConfigRepository.setDefaultProfileId(profileId),
        ).thenAnswer((_) async {
          selected = profileId;
        });
        when(
          () => relationshipRepository.getRelationshipByIdUnfiltered(
            relationshipId,
          ),
        ).thenAnswer((_) async => person());
        when(
          () => aiConfigRepository.getConfigsByType(AiConfigType.model),
        ).thenAnswer(
          (_) async => [
            model('model-glm', 'melious-provider'),
            model('model-local', 'ollama-provider'),
          ],
        );
        when(
          () => aiConfigRepository.getConfigsByType(
            AiConfigType.inferenceProvider,
          ),
        ).thenAnswer((_) async => [meliousProvider, ollamaProvider]);
        when(
          () => aiConfigRepository.getConfigById('melious-provider'),
        ).thenAnswer((_) async => meliousProvider);
        when(
          () => aiConfigRepository.getConfigById('ollama-provider'),
        ).thenAnswer((_) async => ollamaProvider);
        when(
          () => aiConfigRepository.getConfigById(profileId),
        ).thenAnswer((_) async => profile('model-local'));
        final manager = MockScheduledWakeManager();
        final relationshipAgentService = MockRelationshipAgentService();
        when(
          () => relationshipAgentService.watchedRelationshipId(agentId),
        ).thenAnswer((_) async => relationshipId);
        when(
          () => aiConfigRepository.watchConfigsByType(AiConfigType.model),
        ).thenAnswer(
          (_) => Stream.value([model('model-glm', 'melious-provider')]),
        );
        final c = ProviderContainer(
          overrides: [
            agentServiceProvider.overrideWithValue(MockAgentService()),
            agentSyncServiceProvider.overrideWithValue(MockAgentSyncService()),
            relationshipAgentServiceProvider.overrideWithValue(
              relationshipAgentService,
            ),
            scheduledWakeManagerProvider.overrideWithValue(manager),
            domainLoggerProvider.overrideWithValue(MockDomainLogger()),
            aiConfigRepositoryProvider.overrideWithValue(aiConfigRepository),
            relationshipRepositoryProvider.overrideWithValue(
              relationshipRepository,
            ),
            agentRepositoryProvider.overrideWithValue(agentRepository),
            journalDbProvider.overrideWithValue(journalDb),
          ],
        );
        addTearDown(c.dispose);
        c.listen(relationshipRuntimeMaintenanceProvider, (_, _) {});
        final maintenance = c.read(relationshipRuntimeMaintenanceProvider);
        await c.read(
          aiConfigByTypeControllerProvider(AiConfigType.model).future,
        );
        verify(manager.requestCheck).called(1);
        await c
            .read(defaultInferenceProfileControllerProvider.notifier)
            .selectProfile(profileId);
        verify(manager.requestCheck).called(1);
        expect(await maintenance.inferenceIsConfigured!(identity()), isTrue);
        when(
          () => relationshipAgentService.watchedRelationshipId(agentId),
        ).thenAnswer((_) async => null);
        expect(await maintenance.inferenceIsConfigured!(identity()), isFalse);
      },
    );
  });
}
