import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/classes/ai_response_type.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/relationships/model/person_capture.dart';
import 'package:lotti/features/relationships/repository/person_timeline_repository.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/service/person_capture_sort_tool.dart';
import 'package:lotti/features/relationships/service/person_capture_sorter.dart';
import 'package:lotti/features/relationships/service/person_recording_summarizer.dart';
import 'package:lotti/features/relationships/state/person_capture_providers.dart';
import 'package:lotti/features/relationships/state/relationship_agent_providers.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/providers/agent_repository_providers.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../helpers/fallbacks.dart';
import '../../../helpers/test_get_it.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../agents/test_data/entity_factories.dart';

void main() {
  final now = DateTime(2026, 8, 13, 14, 5);
  final melious =
      AiConfig.inferenceProvider(
            id: 'melious-provider',
            baseUrl: 'https://api.melious.ai',
            apiKey: 'key',
            name: 'Melious',
            createdAt: DateTime(2026),
            inferenceProviderType: InferenceProviderType.melious,
          )
          as AiConfigInferenceProvider;
  final glm =
      AiConfig.model(
            id: 'model-glm',
            name: 'GLM 5.2',
            providerModelId: 'glm-5.2',
            inferenceProviderId: 'melious-provider',
            createdAt: DateTime(2026),
            inputModalities: const [Modality.text],
            outputModalities: const [Modality.text],
            isReasoningModel: true,
            supportsFunctionCalling: true,
          )
          as AiConfigModel;
  final person = testRelationship.copyWith(
    meta: testRelationship.meta.copyWith(id: 'pip', categoryId: 'cat-1'),
    data: testRelationship.data.copyWith(profileId: 'profile-1'),
  );

  late MockAiConfigRepository aiConfig;
  late MockAgentRepository agents;
  late MockCloudInferenceRepository inference;
  late MockPersistenceLogic persistence;
  late MockRelationshipRepository relationships;
  late MockPersonTimelineRepository timeline;
  late MockEntitiesCacheService cache;
  late TestGetItMocks services;

  Stream<CreateChatCompletionStreamResponse> generateCall() =>
      inference.generate(
        any(),
        model: any(named: 'model'),
        temperature: any(named: 'temperature'),
        baseUrl: any(named: 'baseUrl'),
        apiKey: any(named: 'apiKey'),
        systemMessage: any(named: 'systemMessage'),
        maxCompletionTokens: any(named: 'maxCompletionTokens'),
        provider: any(named: 'provider'),
        tools: any(named: 'tools'),
        toolChoice: any(named: 'toolChoice'),
        geminiThinkingMode: any(named: 'geminiThinkingMode'),
        reasoningEffort: any(named: 'reasoningEffort'),
        impactCollector: any(named: 'impactCollector'),
      );

  setUpAll(registerAllFallbackValues);

  setUp(() async {
    aiConfig = MockAiConfigRepository();
    agents = MockAgentRepository();
    inference = MockCloudInferenceRepository();
    persistence = MockPersistenceLogic();
    relationships = MockRelationshipRepository();
    timeline = MockPersonTimelineRepository();
    cache = MockEntitiesCacheService();
    services = await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..registerSingleton<PersistenceLogic>(persistence)
          ..registerSingleton<EntitiesCacheService>(cache);
      },
    );
    when(() => cache.getCategoryById(any())).thenReturn(null);
    when(() => agents.getEntity(any())).thenAnswer((_) async => null);
    when(() => aiConfig.getConfigById('profile-1')).thenAnswer(
      (_) async => AiConfig.inferenceProfile(
        id: 'profile-1',
        name: 'Mine',
        createdAt: DateTime(2026),
        thinkingModelId: 'model-glm',
      ),
    );
    when(
      () => aiConfig.getConfigsByType(AiConfigType.model),
    ).thenAnswer((_) async => [glm]);
    when(
      () => aiConfig.getConfigById('melious-provider'),
    ).thenAnswer((_) async => melious);
    when(generateCall).thenAnswer(
      (_) => Stream.value(
        CreateChatCompletionStreamResponse(
          id: 'chunk',
          object: 'chat.completion.chunk',
          created: 0,
          choices: [
            ChatCompletionStreamResponseChoice(
              index: 0,
              delta: ChatCompletionStreamResponseDelta(
                toolCalls: [
                  ChatCompletionStreamMessageToolCallChunk(
                    index: 0,
                    id: 'call-1',
                    type: ChatCompletionStreamMessageToolCallChunkType.function,
                    function: ChatCompletionStreamMessageFunctionCall(
                      name: personCaptureSortToolName,
                      arguments: jsonEncode({
                        'items': [
                          {'kind': 'note', 'text': 'Sextants.'},
                        ],
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  });

  tearDown(tearDownTestGetIt);

  ProviderContainer world() {
    final container = ProviderContainer(
      overrides: [
        aiConfigRepositoryProvider.overrideWithValue(aiConfig),
        agentRepositoryProvider.overrideWithValue(agents),
        cloudInferenceRepositoryProvider.overrideWithValue(inference),
        relationshipCategoryProfileLookupProvider.overrideWithValue(
          (_) async => null,
        ),
        domainLoggerProvider.overrideWithValue(MockDomainLogger()),
        persistenceLogicProvider.overrideWithValue(persistence),
        relationshipRepositoryProvider.overrideWithValue(relationships),
        personTimelineRepositoryProvider.overrideWithValue(timeline),
        taskAgentServiceProvider.overrideWithValue(MockTaskAgentService()),
        journalDbProvider.overrideWithValue(services.journalDb),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test("sorts on the person's briefing route, naming it, with one capped, "
      'forced call offering only the sort tool', () async {
    final sorter = world().read(personCaptureSorterProvider);

    final model = await sorter.modelFor(person);
    expect(model?.modelId, 'glm-5.2');
    expect(model?.route.modelName, 'GLM 5.2');
    expect(model?.route.servingProviderName, 'Melious');
    expect(model?.supportsTools, isTrue);

    final result = await sorter.sort(
      person: person,
      transcript: 'Collects sextants.',
      now: now,
    );
    expect(result.outcome, PersonCaptureSortOutcome.sorted);
    expect((result.items.single as PersonCaptureNote).text, 'Sextants.');
    verify(
      () => inference.generate(
        any(),
        model: 'glm-5.2',
        temperature: 0.2,
        baseUrl: any(named: 'baseUrl'),
        apiKey: 'key',
        systemMessage: personCaptureSortSystemMessage,
        maxCompletionTokens: personCaptureSortMaxTokens,
        provider: any(named: 'provider'),
        tools: [personCaptureSortTool],
        toolChoice: personCaptureSortToolChoiceFor('glm-5.2'),
        geminiThinkingMode: GeminiThinkingMode.minimal,
        reasoningEffort: ReasoningEffort.minimal,
        impactCollector: any(named: 'impactCollector'),
      ),
    ).called(1);
  });

  test('the recording summarizer saves through the timeline and sees a '
      'summary already there', () async {
    when(
      () => timeline.saveRecordingSummary(
        audioId: any(named: 'audioId'),
        summary: any(named: 'summary'),
        modelId: any(named: 'modelId'),
        categoryId: any(named: 'categoryId'),
      ),
    ).thenAnswer((_) async => true);
    when(() => services.journalDb.getLinkedEntities('audio-1')).thenAnswer(
      (_) async => const [],
    );
    when(generateCall).thenAnswer(
      (_) => Stream.value(
        CreateChatCompletionStreamResponse(
          id: 'chunk',
          object: 'chat.completion.chunk',
          created: 0,
          choices: [
            ChatCompletionStreamResponseChoice(
              index: 0,
              delta: ChatCompletionStreamResponseDelta(
                toolCalls: [
                  ChatCompletionStreamMessageToolCallChunk(
                    index: 0,
                    id: 'call-1',
                    type: ChatCompletionStreamMessageToolCallChunkType.function,
                    function: ChatCompletionStreamMessageFunctionCall(
                      name: personRecordingSummaryToolName,
                      arguments: jsonEncode({'oneLiner': 'Pip is calm.'}),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    // Pip has an active relationship agent: its route already reads every
    // check-in about them.
    when(() => agents.getEntity(relationshipAgentIdFor('pip'))).thenAnswer(
      (_) async => makeTestIdentity(
        agentId: relationshipAgentIdFor('pip'),
        kind: AgentKinds.relationshipAgent,
      ),
    );
    final summarizer = world().read(personRecordingSummarizerProvider);
    final words = 'Pip talked about the launch at length. ' * 6;

    expect(
      await summarizer.summarize(
        person: person,
        audioId: 'audio-1',
        transcript: words,
      ),
      isTrue,
    );
    verify(
      () => timeline.saveRecordingSummary(
        audioId: 'audio-1',
        summary: 'Pip is calm.',
        modelId: 'glm-5.2',
        categoryId: 'cat-1',
      ),
    ).called(1);
    verify(
      () => inference.generate(
        any(),
        model: 'glm-5.2',
        temperature: 0.2,
        baseUrl: any(named: 'baseUrl'),
        apiKey: 'key',
        systemMessage: personRecordingSummarySystemMessage,
        maxCompletionTokens: personRecordingSummaryMaxTokens,
        provider: any(named: 'provider'),
        tools: [personRecordingSummaryTool],
        toolChoice: personRecordingSummaryToolChoiceFor('glm-5.2'),
        geminiThinkingMode: GeminiThinkingMode.minimal,
        reasoningEffort: ReasoningEffort.minimal,
        impactCollector: any(named: 'impactCollector'),
      ),
    ).called(1);

    when(() => services.journalDb.getLinkedEntities('audio-2')).thenAnswer(
      (_) async => [
        JournalEntity.aiResponse(
          meta: Metadata(
            id: 'summary',
            createdAt: now,
            updatedAt: now,
            dateFrom: now,
            dateTo: now,
          ),
          data: const AiResponseData(
            model: 'm',
            systemMessage: '',
            prompt: '',
            thoughts: '',
            response: 'x',
            type: AiResponseType.audioSummary,
          ),
        ),
      ],
    );
    expect(
      await summarizer.summarize(
        person: person,
        audioId: 'audio-2',
        transcript: words,
      ),
      isFalse,
    );
  });

  test('a person without an active relationship agent gets no summary — '
      'the fallback route never saw their check-ins', () async {
    when(() => services.journalDb.getLinkedEntities(any())).thenAnswer(
      (_) async => const [],
    );
    final summarizer = world().read(personRecordingSummarizerProvider);
    final words = 'Pip talked about the launch at length. ' * 6;

    expect(
      await summarizer.summarize(
        person: person,
        audioId: 'audio-1',
        transcript: words,
      ),
      isFalse,
    );
    when(() => agents.getEntity(relationshipAgentIdFor('pip'))).thenAnswer(
      (_) async => makeTestIdentity(
        agentId: relationshipAgentIdFor('pip'),
        kind: AgentKinds.relationshipAgent,
        lifecycle: AgentLifecycle.dormant,
      ),
    );
    expect(
      await summarizer.summarize(
        person: person,
        audioId: 'audio-1',
        transcript: words,
      ),
      isFalse,
    );
    verifyNever(generateCall);
  });

  test('a person whose route resolves to nothing has no sorter', () async {
    when(() => aiConfig.getDefaultProfileId()).thenAnswer((_) async => 'gone');
    when(() => aiConfig.getConfigById('gone')).thenAnswer((_) async => null);

    final model = await world()
        .read(personCaptureSorterProvider)
        .modelFor(
          person.copyWith(data: person.data.copyWith(profileId: null)),
        );

    expect(model, isNull);
  });

  test("the filer writes a task in the person's privacy through the shared "
      'task path, and links the recording to it', () async {
    final task =
        JournalEntity.task(
              meta: Metadata(
                id: 'task-1',
                createdAt: now,
                updatedAt: now,
                dateFrom: now,
                dateTo: now,
                categoryId: 'cat-1',
              ),
              data: TaskData(
                status: TaskStatus.open(id: 's', createdAt: now, utcOffset: 0),
                dateFrom: now,
                dateTo: now,
                statusHistory: const [],
                title: 'Send the draft',
              ),
            )
            as Task;
    when(
      () => services.journalDb.journalEntityById('pip'),
    ).thenAnswer((_) async => person);
    when(
      () => persistence.createTaskEntry(
        data: any(named: 'data'),
        entryText: any(named: 'entryText'),
        linkedId: any(named: 'linkedId'),
        categoryId: any(named: 'categoryId'),
        private: any(named: 'private'),
        labelIds: any(named: 'labelIds'),
      ),
    ).thenAnswer((_) async => task);
    when(
      () => timeline.isOnTimeline(
        personId: any(named: 'personId'),
        entryId: any(named: 'entryId'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => relationships.linkTask(
        relationshipId: any(named: 'relationshipId'),
        taskId: any(named: 'taskId'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => persistence.createLink(
        fromId: any(named: 'fromId'),
        toId: any(named: 'toId'),
      ),
    ).thenAnswer((_) async => true);

    final unfiled = await world()
        .read(personCaptureFilerProvider)
        .file(
          person: person,
          audioId: 'audio-1',
          items: [
            PersonCaptureTask(
              title: 'Send the draft',
              due: DateTime(2026, 8, 20),
            ),
          ],
          now: now,
        );

    expect(unfiled, isEmpty);
    final data =
        verify(
              () => persistence.createTaskEntry(
                data: captureAny(named: 'data'),
                entryText: any(named: 'entryText'),
                linkedId: any(named: 'linkedId'),
                categoryId: 'cat-1',
                private: person.meta.private,
                labelIds: any(named: 'labelIds'),
              ),
            ).captured.single
            as TaskData;
    expect(data.title, 'Send the draft');
    expect(data.due, DateTime(2026, 8, 20));
    verify(
      () => relationships.linkTask(relationshipId: 'pip', taskId: 'task-1'),
    ).called(1);
    verify(
      () => persistence.createLink(fromId: 'task-1', toId: 'audio-1'),
    ).called(1);
  });
}
