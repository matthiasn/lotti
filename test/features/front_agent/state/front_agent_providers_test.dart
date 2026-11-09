import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_config.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/agents/front_chat_tokens.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/query/query_chat_providers.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/workflow/wake_result.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/state/ai_runtime_settings_controller.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_door.dart';
import 'package:lotti/features/front_agent/model/front_task_draft.dart';
import 'package:lotti/features/front_agent/service/front_agent_service.dart';
import 'package:lotti/features/front_agent/service/front_chat_service.dart';
import 'package:lotti/features/front_agent/service/front_door_walker.dart';
import 'package:lotti/features/front_agent/service/front_filing_service.dart';
import 'package:lotti/features/front_agent/service/front_routing_index_builder.dart';
import 'package:lotti/features/front_agent/state/front_agent_providers.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_contract.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_model_resolution.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_workflow.dart';
import 'package:lotti/features/github/state/github_providers.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/relationships/state/relationship_agent_providers.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/repositories/journal_repository.dart';
import 'package:lotti/logic/repositories/project_repository.dart';
import 'package:lotti/providers/agent_repository_providers.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/providers/update_notifications_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/device_region.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../helpers/test_get_it.dart';
import '../../../mocks/mocks.dart';
import '../../agents/test_data/entity_factories.dart';
import '../../agents/workflow/task_agent_workflow_test_helpers.dart';
import '../../categories/test_utils.dart';

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
    return result;
  }

  WakeResult result = const WakeResult(success: true, reportUpdated: true);
}

class _MockWalker extends Mock implements FrontDoorWalker {}

void main() {
  setUpAll(registerAllFallbackValues);

  late MockAgentRepository repository;
  late MockAiConfigRepository aiConfigRepository;
  late _RecordingWorkflow recording;
  late _MockWalker walker;
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
    walker = _MockWalker();
    when(() => walker.walk(any())).thenAnswer((_) async {});
    container = ProviderContainer(
      overrides: [
        frontAgentWorkflowProvider.overrideWithValue(recording),
        frontDoorWalkerProvider.overrideWithValue(walker),
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

    /// The front thread holds [pending] as an unanswered turn.
    void stubThread({required bool pending}) {
      final payload = makeTestMessagePayload(
        id: 'msg-7-payload',
        agentId: frontAgentId,
        content: const {'text': 'Hello'},
      );
      final turn = makeTestMessage(
        id: 'msg-7',
        agentId: frontAgentId,
        kind: AgentMessageKind.user,
        contentEntryId: payload.id,
      );
      final reply = makeTestMessage(
        id: 'reply-7',
        agentId: frontAgentId,
        kind: AgentMessageKind.action,
        metadata: const AgentMessageMetadata(
          runKey: 'run-0',
          toolName: FrontAgentToolNames.replyToUser,
          operationId: 'msg-7',
        ),
      );
      when(
        () => repository.getAgentMessages(frontAgentId),
      ).thenAnswer((_) async => [turn, if (!pending) reply]);
    }

    test(
      'a chat token for a pending turn routes it, then walks its doors',
      () async {
        stubThread(pending: true);
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
        verify(() => walker.walk('msg-7')).called(1);
      },
    );

    test("a turn already routed — a recovery wake after the author's own "
        'run — is not routed again, but its doors are still walked', () async {
      stubThread(pending: false);
      final runner = container.read(
        frontAgentWakeRunnersProvider,
      )[AgentKinds.frontAgent]!;

      final result = await runner(
        agentIdentity: identity,
        runKey: 'run-1',
        triggerTokens: {frontChatMessageTriggerToken('msg-7')},
        threadId: 'thread-1',
      );

      expect(result.success, isTrue);
      expect(result.reportUpdated, isFalse);
      expect(recording.calls, isEmpty);
      verify(() => walker.walk('msg-7')).called(1);
    });

    test('a routing turn that failed walks nothing: there is no dispatch to '
        'walk and the recovery record stays pending', () async {
      stubThread(pending: true);
      recording.result = const WakeResult(success: false, error: 'boom');
      final runner = container.read(
        frontAgentWakeRunnersProvider,
      )[AgentKinds.frontAgent]!;

      final result = await runner(
        agentIdentity: identity,
        runKey: 'run-1',
        triggerTokens: {frontChatMessageTriggerToken('msg-7')},
        threadId: 'thread-1',
      );

      expect(result.success, isFalse);
      expect(recording.calls, hasLength(1));
      verifyNever(() => walker.walk(any()));
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
      verifyNever(() => walker.walk(any()));
      verifyNever(() => repository.getAgentMessages(any()));
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

      // Nothing configured and no built-in model present on any provider:
      // no route, after one look per built-in model — and one more by the
      // default-profile controller the resolver watches.
      expect(setup, isNull);
      verify(
        () => aiConfigRepository.getDefaultProfileId(),
      ).called(frontAgentBuiltInModelIds.length + 1);
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
      // A built-in model alone carries no read-aloud model: no cloud voice.
      expect(setup?.profile?.speechProvider, isNull);
    });

    group("her voice follows a profile's read-aloud model", () {
      final mistral =
          AiConfig.inferenceProvider(
                id: 'mistral-provider',
                baseUrl: 'https://api.mistral.ai/v1',
                apiKey: 'key',
                name: 'Mistral',
                createdAt: DateTime(2026),
                inferenceProviderType: InferenceProviderType.mistral,
              )
              as AiConfigInferenceProvider;
      AiConfigModel model(String id, String providerModelId) =>
          AiConfig.model(
                id: id,
                name: id,
                providerModelId: providerModelId,
                inferenceProviderId: mistral.id,
                createdAt: DateTime(2026),
                inputModalities: const [Modality.text],
                outputModalities: const [Modality.text],
                isReasoningModel: false,
                supportsFunctionCalling: true,
              )
              as AiConfigModel;
      final thinking = model('row-large', 'mistral-large-4');
      final voxtral = model('row-voxtral', 'voxtral-mini-tts-3-0');
      final profile =
          AiConfig.inferenceProfile(
                id: 'profile-mistral',
                name: 'Mistral (EU)',
                thinkingModelId: thinking.id,
                speechModelId: voxtral.id,
                createdAt: DateTime(2026),
              )
              as AiConfigInferenceProfile;

      // One provider for the whole test: each `_setupProvider` call is a
      // new one, which would resolve afresh and hide a missed re-resolve.
      late FutureProvider<Object?> setupProvider;

      /// Her setup once it satisfies [where], watched as her surface watches
      /// it: a dependency that changes while she resolves starts her over,
      /// and only a listener sees the value that lands.
      Future<ResolvedAgentSetup?> settled(
        bool Function(ResolvedAgentSetup? setup) where,
      ) {
        final done = Completer<ResolvedAgentSetup?>();
        final sub = container.listen(setupProvider, (_, next) {
          if (next case AsyncData(
            :final value,
          ) when !done.isCompleted && where(value as ResolvedAgentSetup?)) {
            done.complete(value);
          }
        }, fireImmediately: true);
        return done.future.whenComplete(sub.close);
      }

      setUp(() {
        setupProvider = _setupProvider(frontAgentId);
        when(
          () => aiConfigRepository.getConfigsByType(AiConfigType.model),
        ).thenAnswer((_) async => [thinking, voxtral]);
        when(
          () => aiConfigRepository.getConfigById(mistral.id),
        ).thenAnswer((_) async => mistral);
        when(
          () => aiConfigRepository.getConfigById(profile.id),
        ).thenAnswer((_) async => profile);
        when(
          () => aiConfigRepository.setDefaultProfileId(any()),
        ).thenAnswer((_) async {});
      });

      test('the profile she was pointed at, whatever the default', () async {
        when(() => repository.getEntity(frontAgentId)).thenAnswer(
          (_) async => identity.copyWith(
            config: const AgentConfig(
              profileId: 'profile-mistral',
              inferenceSetup: AgentInferenceSetup(
                mode: AgentInferenceSetupMode.configured,
                origin: AgentInferenceSetupOrigin.user,
                baseProfileId: 'profile-mistral',
              ),
            ),
          ),
        );
        when(
          () => aiConfigRepository.getDefaultProfileId(),
        ).thenAnswer((_) async => 'profile-elsewhere');
        final setup = await settled((setup) => setup?.profile != null);

        expect(setup?.profile?.thinkingModel, thinking);
        expect(setup?.profile?.speechProvider, mistral);
        expect(setup?.profile?.speechModel, voxtral);
      });

      test(
        'a new Settings default resolves her again, voice and all',
        () async {
          when(
            () => repository.getEntity(frontAgentId),
          ).thenAnswer((_) async => identity);
          String? defaultId;
          when(
            () => aiConfigRepository.getDefaultProfileId(),
          ).thenAnswer((_) async => defaultId);
          // Nothing configured and no built-in model here: no route at all.
          when(
            () => aiConfigRepository.getConfigsByType(AiConfigType.model),
          ).thenAnswer((_) async => const []);
          final kept = container.listen(setupProvider, (_, _) {});
          addTearDown(kept.close);
          expect(await settled((_) => true), isNull);

          when(
            () => aiConfigRepository.getConfigsByType(AiConfigType.model),
          ).thenAnswer((_) async => [thinking, voxtral]);
          defaultId = 'profile-mistral';
          await container
              .read(defaultInferenceProfileControllerProvider.notifier)
              .selectProfile('profile-mistral');
          final after = await settled((setup) => setup != null);

          expect(after?.profile?.speechProvider, mistral);
          expect(after?.profile?.speechModel, voxtral);
        },
      );
    });
  });

  group('wiring', () {
    test('every provider of the feature builds from its leaves', () async {
      final tokens = MockGitHubTokenStorage();
      when(tokens.readLogin).thenAnswer((_) async => 'pingu');
      final wired = ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(repository),
          aiConfigRepositoryProvider.overrideWithValue(aiConfigRepository),
          domainLoggerProvider.overrideWithValue(MockDomainLogger()),
          journalDbProvider.overrideWithValue(MockJournalDb()),
          fts5DbProvider.overrideWithValue(null),
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
          queryBuilderFactoryProvider.overrideWithValue(
            (scope, agentId, chatId) async => throw UnimplementedError(),
          ),
          taskAgentServiceProvider.overrideWithValue(MockTaskAgentService()),
          projectAgentServiceProvider.overrideWithValue(
            MockProjectAgentService(),
          ),
          goalChatServiceProvider.overrideWithValue(MockGoalChatService()),
          journalRepositoryProvider.overrideWithValue(MockJournalRepository()),
          relationshipChatServiceProvider.overrideWithValue(
            MockRelationshipChatService(),
          ),
          // A Sunday-first region.
          firstDayOfWeekIndexProvider.overrideWith((ref) => 0),
          gitHubTokenStorageProvider.overrideWithValue(tokens),
        ],
      );
      addTearDown(wired.dispose);

      // A host without a full-text index gives the builder no corpus
      // matcher; its weeks start where the device region starts them.
      final builder = wired.read(frontRoutingIndexBuilderProvider);
      expect(builder.fts5Db, isNull);
      expect(await builder.firstDayOfWeekIndex!(), 0);
      // Pull request counts are the user's own: the login the token was
      // checked against.
      expect(await builder.githubLogin!(), 'pingu');
      expect(wired.read(frontAgentWorkflowProvider), isA<FrontAgentWorkflow>());
      expect(wired.read(frontAgentServiceProvider), isA<FrontAgentService>());
      expect(wired.read(frontChatServiceProvider), isA<FrontChatService>());
      expect(wired.read(frontDoorWalkerProvider), isA<FrontDoorWalker>());
      expect(wired.read(frontFilingServiceProvider), isA<FrontFilingService>());
    });
  });

  group("the filing service's adapters", () {
    late MockTimeService timeService;
    const doorId = 'd:door:0';
    late MockPersistenceLogic persistence;
    late MockJournalRepository journalRepository;
    late MockJournalDb journalDb;
    late MockProjectRepository projects;
    late ProviderContainer wired;

    FrontDoorRecord record(FrontDoorOutcome outcome) => FrontDoorRecord(
      segmentIndex: 0,
      text: 'The hinge arrived.',
      kind: FrontDestinationKind.task,
      destinationId: 'garden',
      status: FrontDoorStatus.done,
      claimedAt: DateTime.utc(2026, 10, 26),
      outcome: outcome,
    );

    Metadata meta(String id, {DateTime? deletedAt}) => Metadata(
      id: id,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      dateFrom: DateTime(2026),
      dateTo: DateTime(2026),
      deletedAt: deletedAt,
    );

    setUp(() {
      timeService = MockTimeService();
      persistence = MockPersistenceLogic();
      journalRepository = MockJournalRepository();
      journalDb = MockJournalDb();
      projects = MockProjectRepository();
      when(
        () => projects.inheritProjectFromTask(
          sourceTaskId: any(named: 'sourceTaskId'),
          newTaskId: any(named: 'newTaskId'),
        ),
      ).thenAnswer((_) async => true);
      when(
        () => journalDb.journalEntityById(any()),
      ).thenAnswer((_) async => null);
      // The link the write made is live unless a test says otherwise.
      when(() => journalDb.linksBetween(any(), any())).thenAnswer(
        (invocation) async => [
          link(
            invocation.positionalArguments[0] as String,
            invocation.positionalArguments[1] as String,
          ),
        ],
      );
      final syncService = MockAgentSyncService();
      when(() => syncService.upsertEntity(any())).thenAnswer((_) async {});
      final notifications = MockUpdateNotifications();
      when(() => notifications.notifyUiOnly(any())).thenReturn(null);
      wired = ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(repository),
          agentSyncServiceProvider.overrideWithValue(syncService),
          journalDbProvider.overrideWithValue(journalDb),
          updateNotificationsProvider.overrideWithValue(notifications),
          domainLoggerProvider.overrideWithValue(MockDomainLogger()),
          journalRepositoryProvider.overrideWithValue(journalRepository),
          persistenceLogicProvider.overrideWithValue(persistence),
          timeServiceProvider.overrideWithValue(timeService),
          taskAgentServiceProvider.overrideWithValue(MockTaskAgentService()),
          projectRepositoryProvider.overrideWithValue(projects),
        ],
      );
      addTearDown(wired.dispose);
      when(() => timeService.linkedFrom).thenReturn(null);
      when(() => timeService.stop()).thenAnswer((_) async {});
      // Nothing else is there to delete unless a test says so.
      when(
        () => journalRepository.deleteJournalEntity(any()),
      ).thenAnswer((_) async => false);
      when(
        () => persistence.createMetadata(
          id: any(named: 'id'),
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
          categoryId: any(named: 'categoryId'),
          starred: any(named: 'starred'),
        ),
      ).thenAnswer(
        (invocation) async => meta(invocation.namedArguments[#id] as String),
      );
    });

    void seed(FrontDoorOutcome outcome) {
      when(() => repository.getEntity('$doorId:payload')).thenAnswer(
        (_) async => makeTestMessagePayload(
          id: '$doorId:payload',
          agentId: frontAgentId,
          content: record(outcome).toJson(),
        ),
      );
    }

    void writeAnswers({required bool? verdict}) {
      when(
        () => persistence.createDbEntity(
          any(),
          linkedId: any(named: 'linkedId'),
        ),
      ).thenAnswer((_) async => verdict);
    }

    FrontDoorFiled filed() =>
        FrontDoorRecord.fromJson(
              (verify(
                        () => wired
                            .read(agentSyncServiceProvider)
                            .upsertEntity(captureAny()),
                      ).captured.single
                      as AgentMessagePayloadEntity)
                  .content,
            )!.outcome!
            as FrontDoorFiled;

    test("filing writes the user's words as a text entry linked to the task, "
        'under the id the door names', () async {
      seed(const FrontDoorProposal(ownerId: 'garden'));
      writeAnswers(verdict: true);

      await wired.read(frontFilingServiceProvider).fileUnderOwner(doorId);

      final entry =
          verify(
                () => persistence.createDbEntity(
                  captureAny(),
                  linkedId: 'garden',
                ),
              ).captured.single
              as JournalEntity;
      expect(entry, isA<JournalEntry>());
      expect(entry.entryText?.plainText, 'The hinge arrived.');
      expect(entry.meta.id, frontDoorEntryId(doorId, generation: 0));
      expect(filed().entryId, frontDoorEntryId(doorId, generation: 0));
    });

    test('a write rejected because the entry is already there — the retry '
        'after an interrupted tap — files that entry', () async {
      seed(const FrontDoorProposal(ownerId: 'garden'));
      writeAnswers(verdict: false);
      final id = frontDoorEntryId(doorId, generation: 0);
      when(() => journalDb.journalEntityById(id)).thenAnswer(
        (_) async => JournalEntity.journalEntry(
          meta: meta(id),
          entryText: const EntryText(plainText: 'The hinge arrived.'),
        ),
      );

      await wired.read(frontFilingServiceProvider).fileUnderOwner(doorId);

      expect(filed().entryId, id);
    });

    test('an entry whose task link did not land gets it written once more, '
        'and files when it is live', () async {
      seed(const FrontDoorProposal(ownerId: 'garden'));
      writeAnswers(verdict: true);
      final id = frontDoorEntryId(doorId, generation: 0);
      var repaired = false;
      when(() => journalDb.linksBetween('garden', id)).thenAnswer(
        (_) async => [
          if (repaired)
            link('garden', id)
          else
            link('garden', id, deletedAt: DateTime(2026)),
        ],
      );
      when(
        () => persistence.createLink(fromId: 'garden', toId: id),
      ).thenAnswer((_) async => repaired = true);

      await wired.read(frontFilingServiceProvider).fileUnderOwner(doorId);

      verify(
        () => persistence.createLink(fromId: 'garden', toId: id),
      ).called(1);
      expect(filed().entryId, id);
    });

    test('an entry whose task link stays missing is not filed', () async {
      seed(const FrontDoorProposal(ownerId: 'garden'));
      writeAnswers(verdict: true);
      final id = frontDoorEntryId(doorId, generation: 0);
      when(
        () => journalDb.linksBetween('garden', id),
      ).thenAnswer((_) async => const []);
      when(
        () => persistence.createLink(fromId: 'garden', toId: id),
      ).thenAnswer((_) async => false);

      await expectLater(
        wired.read(frontFilingServiceProvider).fileUnderOwner(doorId),
        throwsStateError,
      );
      verifyNever(
        () => wired.read(agentSyncServiceProvider).upsertEntity(any()),
      );
    });

    test('a rejected write with no live row behind it, or a write that '
        'failed, stores nothing and leaves the proposal', () async {
      seed(const FrontDoorProposal(ownerId: 'garden'));
      final id = frontDoorEntryId(doorId, generation: 0);
      writeAnswers(verdict: false);
      when(() => journalDb.journalEntityById(id)).thenAnswer(
        (_) async => JournalEntity.journalEntry(
          meta: meta(id, deletedAt: DateTime(2026)),
          entryText: const EntryText(plainText: 'gone'),
        ),
      );
      await expectLater(
        wired.read(frontFilingServiceProvider).fileUnderOwner(doorId),
        throwsStateError,
      );

      writeAnswers(verdict: null);
      await expectLater(
        wired.read(frontFilingServiceProvider).fileUnderOwner(doorId),
        throwsStateError,
      );
      verifyNever(
        () => wired.read(agentSyncServiceProvider).upsertEntity(any()),
      );
    });

    FrontDoorEventCreated eventCreated() =>
        FrontDoorRecord.fromJson(
              (verify(
                        () => wired
                            .read(agentSyncServiceProvider)
                            .upsertEntity(captureAny()),
                      ).captured.single
                      as AgentMessagePayloadEntity)
                  .content,
            )!.outcome!
            as FrontDoorEventCreated;

    test('making an event writes a tentative event titled with the words, '
        'dated at the tap, under the id the door names', () async {
      seed(const FrontDoorInbox());
      writeAnswers(verdict: true);
      final at = DateTime(2026, 11, 9, 10);

      await withClock(
        Clock.fixed(at),
        () => wired.read(frontFilingServiceProvider).makeEvent(doorId),
      );

      final id = frontDoorEventId(doorId, generation: 0);
      final event =
          verify(
                () => persistence.createDbEntity(captureAny()),
              ).captured.single
              as JournalEvent;
      expect(event.meta.id, id);
      expect(event.data.title, 'The hinge arrived.');
      expect(event.data.status, EventStatus.tentative);
      expect(event.data.stars, 0);
      verify(
        () => persistence.createMetadata(
          id: id,
          dateFrom: at,
          dateTo: at,
          // Starred, as the Events page's own create makes one.
          starred: true,
        ),
      ).called(1);
      expect(eventCreated().eventId, id);
    });

    test('an event already there — the retry — is the one recorded', () async {
      seed(const FrontDoorInbox());
      writeAnswers(verdict: false);
      final id = frontDoorEventId(doorId, generation: 0);
      when(() => journalDb.journalEntityById(id)).thenAnswer(
        (_) async => JournalEvent(
          meta: meta(id),
          data: const EventData(
            title: 'Written before',
            stars: 0,
            status: EventStatus.tentative,
          ),
        ),
      );

      await wired.read(frontFilingServiceProvider).makeEvent(doorId);

      expect(eventCreated().eventId, id);
    });

    test('a write that stored nothing, or whose id holds something else, '
        'makes no event and leaves the item waiting', () async {
      seed(const FrontDoorInbox());
      final id = frontDoorEventId(doorId, generation: 0);
      writeAnswers(verdict: null);
      await expectLater(
        wired.read(frontFilingServiceProvider).makeEvent(doorId),
        throwsStateError,
      );

      writeAnswers(verdict: false);
      when(() => journalDb.journalEntityById(id)).thenAnswer(
        (_) async => JournalEntity.journalEntry(
          meta: meta(id),
          entryText: const EntryText(plainText: 'not an event'),
        ),
      );
      await expectLater(
        wired.read(frontFilingServiceProvider).makeEvent(doorId),
        throwsStateError,
      );
      verifyNever(
        () => wired.read(agentSyncServiceProvider).upsertEntity(any()),
      );
    });

    Task task(String id, String title) {
      final status = TaskStatus.open(
        id: 's',
        createdAt: DateTime(2026),
        utcOffset: 0,
      );
      return JournalEntity.task(
            meta: meta(id),
            data: TaskData(
              status: status,
              statusHistory: [status],
              dateFrom: DateTime(2026),
              dateTo: DateTime(2026),
              title: title,
            ),
          )
          as Task;
    }

    test('making a task goes through the task creation with the words as '
        'the title, open, under the id the door names', () async {
      seed(const FrontDoorInbox());
      when(
        () => persistence.createTaskEntry(
          data: any(named: 'data'),
          entryText: any(named: 'entryText'),
          categoryId: any(named: 'categoryId'),
          id: any(named: 'id'),
        ),
      ).thenAnswer(
        (invocation) async => task(
          invocation.namedArguments[#id] as String,
          (invocation.namedArguments[#data] as TaskData).title,
        ),
      );

      writeAnswers(verdict: true);
      await wired.read(frontFilingServiceProvider).makeTask(doorId);

      final data =
          verify(
                () => persistence.createTaskEntry(
                  data: captureAny(named: 'data'),
                  entryText: any(named: 'entryText'),
                  categoryId: any(named: 'categoryId'),
                  id: frontDoorTaskId(doorId),
                ),
              ).captured.single
              as TaskData;
      expect(data.title, 'The hinge arrived.');
      expect(data.status, isA<TaskOpen>());
    });

    test('the tap on a dictated follow-up makes the task in its category, '
        'links it to the task it follows and its project, runs the backdated timer and '
        "hands it the category's agent", () async {
      final now = DateTime(2026, 11, 8, 14, 30);
      final started = now.subtract(const Duration(minutes: 5));
      final cache = MockEntitiesCacheService();
      when(() => cache.getCategoryById('garden')).thenReturn(
        CategoryTestUtils.createTestCategory(
          id: 'garden',
          defaultTemplateId: 'template-garden',
        ),
      );
      await setUpTestGetIt(
        additionalSetup: () =>
            getIt.registerSingleton<EntitiesCacheService>(cache),
      );
      addTearDown(tearDownTestGetIt);
      when(() => repository.getEntity('$doorId:payload')).thenAnswer(
        (_) async => makeTestMessagePayload(
          id: '$doorId:payload',
          agentId: frontAgentId,
          content: FrontDoorRecord(
            segmentIndex: 0,
            text: 'A follow-up to that one, started five minutes ago.',
            kind: FrontDestinationKind.newThing,
            status: FrontDoorStatus.done,
            claimedAt: DateTime.utc(2026, 11, 8),
            outcome: const FrontDoorInbox(newKind: FrontNewKind.task),
            task: FrontTaskDraft(
              title: 'Mulch the roses',
              priority: TaskPriority.p1High,
              due: DateTime(2026, 11, 8),
              startedAt: started,
              followsUpTaskId: 'roses',
            ),
          ).toJson(),
        ),
      );
      when(() => journalDb.journalEntityById('roses')).thenAnswer(
        (_) async => JournalEntity.task(
          meta: meta('roses').copyWith(categoryId: 'garden'),
          data: TaskData(
            status: TaskStatus.done(id: 's', createdAt: now, utcOffset: 0),
            statusHistory: const [],
            dateFrom: now,
            dateTo: now,
            title: 'Prune the roses',
          ),
        ),
      );
      final taskId = frontDoorTaskId(doorId);
      when(
        () => persistence.createTaskEntry(
          data: any(named: 'data'),
          entryText: any(named: 'entryText'),
          categoryId: any(named: 'categoryId'),
          id: any(named: 'id'),
        ),
      ).thenAnswer(
        (invocation) async =>
            JournalEntity.task(
                  meta: meta(taskId).copyWith(
                    categoryId:
                        invocation.namedArguments[#categoryId] as String?,
                  ),
                  data: invocation.namedArguments[#data] as TaskData,
                )
                as Task,
      );
      when(
        () => persistence.createLink(
          fromId: any(named: 'fromId'),
          toId: any(named: 'toId'),
          linkType: any(named: 'linkType'),
        ),
      ).thenAnswer((_) async => true);
      when(() => timeService.start(any(), any())).thenAnswer((_) async {});
      // The timer entry must carry the start it was given.
      when(
        () => persistence.createMetadata(
          id: any(named: 'id'),
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer(
        (invocation) async => meta(
          invocation.namedArguments[#id] as String,
        ).copyWith(dateFrom: invocation.namedArguments[#dateFrom] as DateTime),
      );
      final agents = wired.read(taskAgentServiceProvider);
      when(
        () => agents.createTaskAgent(
          taskId: any(named: 'taskId'),
          allowedCategoryIds: any(named: 'allowedCategoryIds'),
          templateId: any(named: 'templateId'),
          profileId: any(named: 'profileId'),
          setupOrigin: any(named: 'setupOrigin'),
          setupOriginEntityId: any(named: 'setupOriginEntityId'),
          awaitContent: any(named: 'awaitContent'),
          automaticUpdatesEnabled: any(named: 'automaticUpdatesEnabled'),
        ),
      ).thenAnswer((_) async => makeTestIdentity());
      writeAnswers(verdict: true);

      await withClock(
        Clock.fixed(now),
        () => wired.read(frontFilingServiceProvider).makeTask(doorId),
      );

      final data =
          verify(
                () => persistence.createTaskEntry(
                  data: captureAny(named: 'data'),
                  entryText: any(named: 'entryText'),
                  categoryId: 'garden',
                  id: taskId,
                ),
              ).captured.single
              as TaskData;
      expect(data.title, 'Mulch the roses');
      expect(data.priority, TaskPriority.p1High);
      expect(data.due, DateTime(2026, 11, 8));
      expect(data.status, isA<TaskInProgress>());
      verify(
        () => persistence.createLink(
          fromId: taskId,
          toId: 'roses',
          linkType: EntryLinkType.followsUp,
        ),
      ).called(1);
      verify(
        () => projects.inheritProjectFromTask(
          sourceTaskId: 'roses',
          newTaskId: taskId,
        ),
      ).called(1);
      final timer =
          verify(
                () => timeService.start(captureAny(), any()),
              ).captured.single
              as JournalEntity;
      expect(timer.meta.id, frontTaskTimerId(taskId));
      expect(timer.meta.dateFrom, started);
      verify(
        () => agents.createTaskAgent(
          taskId: taskId,
          allowedCategoryIds: {'garden'},
          templateId: 'template-garden',
          profileId: any(named: 'profileId'),
          setupOrigin: any(named: 'setupOrigin'),
          setupOriginEntityId: 'garden',
          awaitContent: any(named: 'awaitContent'),
          automaticUpdatesEnabled: any(named: 'automaticUpdatesEnabled'),
        ),
      ).called(1);
    });

    test('a task the creation path refused because it is already there is '
        'the one recorded; one that is not there is nothing', () async {
      seed(const FrontDoorInbox());
      final id = frontDoorTaskId(doorId);
      when(
        () => persistence.createTaskEntry(
          data: any(named: 'data'),
          entryText: any(named: 'entryText'),
          categoryId: any(named: 'categoryId'),
          id: any(named: 'id'),
        ),
      ).thenAnswer((_) async => null);
      when(
        () => journalDb.journalEntityById(id),
      ).thenAnswer((_) async => task(id, 'The hinge arrived.'));

      await wired.read(frontFilingServiceProvider).makeTask(doorId);

      final outcome =
          FrontDoorRecord.fromJson(
                (verify(
                          () => wired
                              .read(agentSyncServiceProvider)
                              .upsertEntity(captureAny()),
                        ).captured.single
                        as AgentMessagePayloadEntity)
                    .content,
              )!.outcome!
              as FrontDoorTaskCreated;
      expect(outcome.taskId, id);

      when(() => journalDb.journalEntityById(id)).thenAnswer((_) async => null);
      await expectLater(
        wired.read(frontFilingServiceProvider).makeTask(doorId),
        throwsStateError,
      );
    });

    test('taking back a task stops the timer running on it, and only '
        'that timer', () async {
      seed(const FrontDoorTaskCreated(taskId: 'task-1'));
      when(
        () => journalRepository.deleteJournalEntity('task-1'),
      ).thenAnswer((_) async => true);
      when(() => timeService.linkedFrom).thenReturn(task('task-1', 'Hose'));

      await wired.read(frontFilingServiceProvider).takeBack(doorId);
      verify(() => timeService.stop()).called(1);

      seed(const FrontDoorTaskCreated(taskId: 'task-1'));
      when(() => timeService.linkedFrom).thenReturn(task('other', 'Nest'));
      await wired.read(frontFilingServiceProvider).takeBack(doorId);
      verifyNever(() => timeService.stop());
    });

    test('taking back a task deletes the copy of the words filed under it '
        'and keeps its timer entry — logged time outlives the task', () async {
      seed(const FrontDoorTaskCreated(taskId: 'task-1'));
      when(
        () => journalRepository.deleteJournalEntity('task-1'),
      ).thenAnswer((_) async => true);

      await wired.read(frontFilingServiceProvider).takeBack(doorId);

      verify(
        () => journalRepository.deleteJournalEntity(frontTaskWordsId('task-1')),
      ).called(1);
      verifyNever(
        () => journalRepository.deleteJournalEntity(frontTaskTimerId('task-1')),
      );
    });

    test(
      'taking back deletes the entry through the journal repository',
      () async {
        seed(const FrontDoorFiled(entryId: 'entry-1', ownerId: 'garden'));
        when(
          () => journalRepository.deleteJournalEntity('entry-1'),
        ).thenAnswer((_) async => true);

        await wired.read(frontFilingServiceProvider).takeBack(doorId);

        verify(
          () => journalRepository.deleteJournalEntity('entry-1'),
        ).called(1);
      },
    );
  });

  group('makeFrontTask', () {
    final now = DateTime(2026, 11, 8, 14, 30);
    const taskId = 'task-made';
    late MockPersistenceLogic persistence;
    late MockJournalDb journalDb;
    late List<(JournalEntity, JournalEntity)> timers;
    late List<Task> assigned;
    late MockProjectRepository projects;
    late MockDomainLogger domainLogger;

    Task made(TaskData data) =>
        JournalEntity.task(
              meta: Metadata(
                id: taskId,
                createdAt: now,
                updatedAt: now,
                dateFrom: now,
                dateTo: now,
                categoryId: 'work',
              ),
              data: data,
            )
            as Task;

    setUp(() {
      persistence = MockPersistenceLogic();
      journalDb = MockJournalDb();
      timers = [];
      assigned = [];
      projects = MockProjectRepository();
      domainLogger = MockDomainLogger();
      when(
        () => persistence.createMetadata(
          id: any(named: 'id'),
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer(
        (invocation) async => Metadata(
          id: invocation.namedArguments[#id] as String,
          createdAt: now,
          updatedAt: now,
          dateFrom: invocation.namedArguments[#dateFrom] as DateTime,
          dateTo: invocation.namedArguments[#dateTo] as DateTime,
          categoryId: invocation.namedArguments[#categoryId] as String?,
        ),
      );
      when(
        () => persistence.createDbEntity(
          any(),
          linkedId: any(named: 'linkedId'),
        ),
      ).thenAnswer((_) async => true);
      when(() => journalDb.linksBetween(any(), any())).thenAnswer(
        (invocation) async => [
          link(
            invocation.positionalArguments[0] as String,
            invocation.positionalArguments[1] as String,
          ),
        ],
      );
    });

    Future<Task?> make(FrontTaskDraft draft) => withClock(
      Clock.fixed(now),
      () => makeFrontTask(
        persistence,
        journalDb,
        draft,
        id: taskId,
        words: 'Fix the login bug, high priority, started ten minutes ago.',
        startTimer: (timer, task) async => timers.add((timer, task)),
        inheritProject: projects.inheritProjectFromTask,
        domainLogger: domainLogger,
        assignAgent: (task) async => assigned.add(task),
      ),
    );

    void stubCreation({required bool written}) =>
        when(
          () => persistence.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            categoryId: any(named: 'categoryId'),
            id: any(named: 'id'),
          ),
        ).thenAnswer(
          (invocation) async => written
              ? made(invocation.namedArguments[#data] as TaskData)
              : null,
        );

    test('fills the task from the draft, files the words under it, runs '
        'a timer from the dictated start and hands it its agent', () async {
      stubCreation(written: true);
      final started = now.subtract(const Duration(minutes: 10));

      final task = await make(
        FrontTaskDraft(
          title: 'Fix the login bug',
          instructions: 'Reproduce on Android first.',
          categoryId: 'work',
          priority: TaskPriority.p1High,
          due: DateTime(2026, 11, 10),
          estimate: const Duration(minutes: 90),
          startedAt: started,
        ),
      );

      final captured = verify(
        () => persistence.createTaskEntry(
          data: captureAny(named: 'data'),
          entryText: captureAny(named: 'entryText'),
          categoryId: 'work',
          id: taskId,
        ),
      ).captured;
      final data = captured[0] as TaskData;
      expect(data.title, 'Fix the login bug');
      expect(data.status, isA<TaskInProgress>());
      expect(data.priority, TaskPriority.p1High);
      expect(data.due, DateTime(2026, 11, 10));
      expect(data.estimate, const Duration(minutes: 90));
      expect(
        (captured[1] as EntryText).plainText,
        'Reproduce on Android first.',
      );

      final entries = verify(
        () => persistence.createDbEntity(captureAny(), linkedId: taskId),
      ).captured.cast<JournalEntity>();
      expect(entries.map((e) => e.meta.id), [
        frontTaskWordsId(taskId),
        frontTaskTimerId(taskId),
      ]);
      expect(
        entries.first.entryText?.plainText,
        'Fix the login bug, high priority, started ten minutes ago.',
      );
      final (timer, timedTask) = timers.single;
      expect(timer.meta.dateFrom, started);
      expect(timedTask.meta.id, taskId);
      expect(assigned.single.meta.id, taskId);
      expect(task?.meta.id, taskId);
    });

    test('a draft without a start is open, untimed, at medium priority — '
        'and a start in the future runs from now', () async {
      stubCreation(written: true);
      await make(const FrontTaskDraft(title: 'Call the vet'));
      final data =
          verify(
                () => persistence.createTaskEntry(
                  data: captureAny(named: 'data'),
                  entryText: any(named: 'entryText'),
                  categoryId: any(named: 'categoryId'),
                  id: taskId,
                ),
              ).captured.single
              as TaskData;
      expect(data.status, isA<TaskOpen>());
      expect(data.priority, TaskPriority.p2Medium);
      expect(timers, isEmpty);

      await make(
        FrontTaskDraft(
          title: 'Call the vet',
          startedAt: now.add(const Duration(minutes: 5)),
        ),
      );
      expect(timers.single.$1.meta.dateFrom, now);
    });

    group('a follow-up', () {
      const followedId = 'task-followed';
      late List<String> events;

      setUp(() {
        events = [];
        stubCreation(written: true);
        when(
          () => persistence.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
            linkType: any(named: 'linkType'),
          ),
        ).thenAnswer((_) async {
          events.add('link');
          return true;
        });
      });

      Future<Task?> makeFollowUp(FrontTaskDraft draft) => withClock(
        Clock.fixed(now),
        () => makeFrontTask(
          persistence,
          journalDb,
          draft,
          id: taskId,
          words: 'Create a follow-up to that one.',
          startTimer: (_, _) async {},
          inheritProject: projects.inheritProjectFromTask,
          domainLogger: domainLogger,
          assignAgent: (_) async => events.add('agent'),
        ),
      );

      void stubFollowedTask() =>
          when(() => journalDb.journalEntityById(followedId)).thenAnswer(
            (_) async => JournalEntity.task(
              meta: Metadata(
                id: followedId,
                createdAt: now,
                updatedAt: now,
                dateFrom: now,
                dateTo: now,
                categoryId: 'garden',
              ),
              data: TaskData(
                status: TaskStatus.done(id: 's', createdAt: now, utcOffset: 0),
                statusHistory: const [],
                dateFrom: now,
                dateTo: now,
                title: 'Prune the roses',
              ),
            ),
          );

      void stubInheritance(Future<bool> Function() answer) =>
          when(
            () => projects.inheritProjectFromTask(
              sourceTaskId: any(named: 'sourceTaskId'),
              newTaskId: any(named: 'newTaskId'),
            ),
          ).thenAnswer((_) {
            events.add('project');
            return answer();
          });

      test('is linked followsUp to the task it follows, takes its category '
          'and its project, and gets its agent only after both', () async {
        stubFollowedTask();
        stubInheritance(() async => true);

        await makeFollowUp(
          const FrontTaskDraft(
            title: 'Mulch the roses',
            followsUpTaskId: followedId,
          ),
        );

        verify(
          () => persistence.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            categoryId: 'garden',
            id: taskId,
          ),
        ).called(1);
        verify(
          () => persistence.createLink(
            fromId: taskId,
            toId: followedId,
            linkType: EntryLinkType.followsUp,
          ),
        ).called(1);
        verify(
          () => projects.inheritProjectFromTask(
            sourceTaskId: followedId,
            newTaskId: taskId,
          ),
        ).called(1);
        expect(events, ['link', 'project', 'agent']);
      });

      test('a followed task in no project leaves the follow-up in none, '
          'and it is still made and handed its agent', () async {
        stubFollowedTask();
        stubInheritance(() async => false);

        await makeFollowUp(
          const FrontTaskDraft(
            title: 'Mulch the roses',
            followsUpTaskId: followedId,
          ),
        );

        expect(events, ['link', 'project', 'agent']);
        verifyNever(
          () => domainLogger.error(
            any(),
            any<Object>(),
            stackTrace: any(named: 'stackTrace'),
            subDomain: any(named: 'subDomain'),
            message: any(named: 'message'),
          ),
        );
      });

      test('a failed project link is logged, never fatal: the follow-up '
          'stands and gets its agent', () async {
        stubFollowedTask();
        stubInheritance(() async => throw StateError('db closed'));

        await makeFollowUp(
          const FrontTaskDraft(
            title: 'Mulch the roses',
            followsUpTaskId: followedId,
          ),
        );

        expect(events, ['link', 'project', 'agent']);
        verify(
          () => domainLogger.error(
            LogDomain.agentWorkflow,
            any<Object>(that: isA<StateError>()),
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'makeFrontTask',
            message: any(named: 'message'),
          ),
        ).called(1);
      });

      test('a category the words named wins over the followed one, and a '
          'followed id that is no task links nothing', () async {
        when(() => journalDb.journalEntityById(followedId)).thenAnswer(
          (_) async => JournalEntity.journalEntry(
            meta: Metadata(
              id: followedId,
              createdAt: now,
              updatedAt: now,
              dateFrom: now,
              dateTo: now,
              categoryId: 'garden',
            ),
          ),
        );

        await makeFollowUp(
          const FrontTaskDraft(
            title: 'Mulch the roses',
            categoryId: 'work',
            followsUpTaskId: followedId,
          ),
        );

        verify(
          () => persistence.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            categoryId: 'work',
            id: taskId,
          ),
        ).called(1);
        expect(events, ['agent']);
        verifyZeroInteractions(projects);
      });

      test('a followed task that cannot be loaded makes the task without a '
          'link or a project', () async {
        when(
          () => journalDb.journalEntityById(followedId),
        ).thenAnswer((_) async => null);

        final task = await makeFollowUp(
          const FrontTaskDraft(
            title: 'Mulch the roses',
            followsUpTaskId: followedId,
          ),
        );

        expect(task?.meta.id, taskId);
        expect(events, ['agent']);
        verifyZeroInteractions(projects);
      });
    });

    test(
      'the retry finds the task already there and adds nothing twice',
      () async {
        stubCreation(written: false);
        final existing = made(
          TaskData(
            status: TaskStatus.open(id: 's', createdAt: now, utcOffset: 0),
            statusHistory: const [],
            dateFrom: now,
            dateTo: now,
            title: 'Fix the login bug',
          ),
        );
        when(
          () => journalDb.journalEntityById(taskId),
        ).thenAnswer((_) async => existing);

        final task = await make(
          FrontTaskDraft(title: 'Fix the login bug', startedAt: now),
        );

        expect(task, same(existing));
        verifyNever(
          () => persistence.createDbEntity(
            any(),
            linkedId: any(named: 'linkedId'),
          ),
        );
        expect(timers, isEmpty);
        expect(assigned, isEmpty);
      },
    );
  });
}

/// Exercises the resolver through a provider, the way the registry calls it.
/// A link from [fromId] to [toId], live unless [deletedAt] is given.
EntryLink link(String fromId, String toId, {DateTime? deletedAt}) =>
    EntryLink.basic(
      id: 'link-$fromId-$toId',
      fromId: fromId,
      toId: toId,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      vectorClock: null,
      deletedAt: deletedAt,
    );

FutureProvider<Object?> _setupProvider(String agentId) =>
    FutureProvider<Object?>((ref) => resolveFrontAgentSetup(ref, agentId));
