import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Selectable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/functions/checklist_completion_functions.dart';
import 'package:lotti/features/ai/helpers/prompt_capability_filter.dart';
import 'package:lotti/features/ai/model/ai_call_impact.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart'
    show aiInputRepositoryProvider;
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/unified_ai_inference_repository.dart';
import 'package:lotti/features/ai/services/checklist_completion_service.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_event.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart'
    show categoryRepositoryProvider;
import 'package:lotti/features/journal/repository/journal_repository.dart'
    show journalRepositoryProvider;
import 'package:lotti/features/labels/repository/labels_repository.dart'
    show labelsRepositoryProvider;
import 'package:lotti/features/tasks/repository/checklist_repository.dart'
    show checklistRepositoryProvider;
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart' show journalDbProvider;
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';
import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../ai_consumption/test_utils.dart';
import '../test_utils.dart';

class MockPromptCapabilityFilter extends Mock
    implements PromptCapabilityFilter {}

class MockDirectory extends Mock implements Directory {}

class TestChecklistCompletionService extends ChecklistCompletionService {
  List<ChecklistCompletionSuggestion> capturedSuggestions = [];

  @override
  FutureOr<List<ChecklistCompletionSuggestion>> build() async => [];

  @override
  void addSuggestions(List<ChecklistCompletionSuggestion> suggestions) {
    capturedSuggestions.addAll(suggestions);
  }
}

class FakeTask extends Fake implements Task {}

class FakeImageData extends Fake implements ImageData {}

class FakeAudioData extends Fake implements AudioData {}

class FakeAiResponseData extends Fake implements AiResponseData {}

class FakeChecklistData extends Fake implements ChecklistData {}

class MockSelectableSimple<T> extends Mock implements Selectable<T> {}

class UnifiedAiInferenceRepositoryTestHarness {
  UnifiedAiInferenceRepository? repository;
  late ProviderContainer container;
  late MockAiConfigRepository mockAiConfigRepo;
  late MockAiInputRepository mockAiInputRepo;
  late MockCloudInferenceRepository mockCloudInferenceRepo;
  late MockJournalRepository mockJournalRepo;
  late MockChecklistRepository mockChecklistRepo;
  late MockAutoChecklistService mockAutoChecklistService;
  late MockLoggingService mockLoggingService;
  late MockJournalDb mockJournalDb;
  late MockDirectory mockDirectory;
  late MockCategoryRepository mockCategoryRepo;
  late MockPromptCapabilityFilter mockPromptCapabilityFilter;
  late MockLabelsRepository mockLabelsRepository;
  late TestChecklistCompletionService testChecklistCompletionService;
  late Directory suiteTempDir;
  late Directory? baseTempDir;
  late List<Directory> overrideTempDirs;

  void setUpAll() {
    registerAllFallbackValues();
    getIt.pushNewScope();
    registerFallbackValue(FakeAiConfigPrompt());
    registerFallbackValue(FakeAiConfigModel());
    registerFallbackValue(FakeAiConfigInferenceProvider());
    registerFallbackValue(FakeMetadata());
    registerFallbackValue(FakeTaskData());
    registerFallbackValue(FakeTask());
    registerFallbackValue(FakeImageData());
    registerFallbackValue(FakeAudioData());
    registerFallbackValue(InferenceStatus.idle);
    registerFallbackValue(FakeAiResponseData());
    registerFallbackValue(fallbackJournalEntity);
    registerFallbackValue(FakeJournalAudio());
    registerFallbackValue(FakeChecklistData());
    registerFallbackValue(FakeChecklistItemData());
    registerFallbackValue(ChatCompletionMessageInputAudioFormat.wav);
    registerFallbackValue(fallbackAiConsumptionEvent);
    suiteTempDir = Directory.systemTemp.createTempSync('lotti_ai_repo_test_');
  }

  void setUp() {
    mockAiConfigRepo = MockAiConfigRepository();
    mockAiInputRepo = MockAiInputRepository();
    mockCloudInferenceRepo = MockCloudInferenceRepository();
    mockJournalRepo = MockJournalRepository();
    mockChecklistRepo = MockChecklistRepository();
    mockAutoChecklistService = MockAutoChecklistService();
    mockLoggingService = MockLoggingService();
    mockJournalDb = MockJournalDb();
    mockDirectory = MockDirectory();
    mockCategoryRepo = MockCategoryRepository();
    mockPromptCapabilityFilter = MockPromptCapabilityFilter();
    mockLabelsRepository = MockLabelsRepository();
    testChecklistCompletionService = TestChecklistCompletionService();

    reset(mockJournalDb);
    getIt
      ..pushNewScope()
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<Directory>(mockDirectory)
      ..registerSingleton<LoggingService>(mockLoggingService);

    baseTempDir = suiteTempDir.createTempSync('t');
    overrideTempDirs = <Directory>[];
    when(() => mockDirectory.path).thenReturn(baseTempDir!.path);
    when(
      () => mockJournalDb.getConfigFlag(enableAiStreamingFlag),
    ).thenAnswer((_) async => false);
    when(
      () => mockJournalRepo.getLinkedEntities(linkedTo: any(named: 'linkedTo')),
    ).thenAnswer((_) async => <JournalEntity>[]);
    when(
      () => mockPromptCapabilityFilter.filterPromptsByPlatform(any()),
    ).thenAnswer((invocation) async {
      final prompts = invocation.positionalArguments[0] as List<AiConfigPrompt>;
      return prompts;
    });

    container = ProviderContainer(
      overrides: [
        aiConfigRepositoryProvider.overrideWithValue(mockAiConfigRepo),
        aiInputRepositoryProvider.overrideWithValue(mockAiInputRepo),
        cloudInferenceRepositoryProvider.overrideWithValue(
          mockCloudInferenceRepo,
        ),
        journalDbProvider.overrideWithValue(mockJournalDb),
        journalRepositoryProvider.overrideWithValue(mockJournalRepo),
        checklistRepositoryProvider.overrideWithValue(mockChecklistRepo),
        categoryRepositoryProvider.overrideWithValue(mockCategoryRepo),
        promptCapabilityFilterProvider.overrideWithValue(
          mockPromptCapabilityFilter,
        ),
        labelsRepositoryProvider.overrideWithValue(mockLabelsRepository),
        checklistCompletionServiceProvider.overrideWith(
          () => testChecklistCompletionService,
        ),
      ],
    );

    final ref = container.read(testRefProvider);
    repository = UnifiedAiInferenceRepository(ref)
      ..autoChecklistServiceForTesting = mockAutoChecklistService;
  }

  Future<void> tearDown() async {
    container.dispose();
    try {
      for (final directory in overrideTempDirs) {
        if (directory.existsSync()) {
          directory.deleteSync(recursive: true);
        }
      }
      when(() => mockDirectory.path).thenReturn(Directory.systemTemp.path);
    } catch (_) {}
    await getIt.popScope();
  }

  Future<void> tearDownAll() async {
    try {
      if (suiteTempDir.existsSync()) {
        suiteTempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
    await getIt.resetScope();
    await getIt.popScope();
  }
}

// Helper methods to create test objects
final fixedDate = DateTime(2025);

Metadata createMetadata({String? id, String? categoryId}) {
  return Metadata(
    id: id ?? 'test-id',
    createdAt: fixedDate,
    updatedAt: fixedDate,
    dateFrom: fixedDate,
    dateTo: fixedDate,
    categoryId: categoryId,
  );
}

AiConfigInferenceProvider createAiProvider({
  required String id,
  required InferenceProviderType type,
}) {
  return AiConfigInferenceProvider(
    id: id,
    name: 'Test Provider',
    baseUrl: 'https://api.test.com',
    apiKey: 'test-key',
    createdAt: DateTime(2024, 3, 15, 10, 30),
    inferenceProviderType: type,
  );
}

AiConfigPrompt createPrompt({
  required String id,
  required String name,
  String defaultModelId = 'model-1',
  List<InputDataType> requiredInputData = const [],
  AiResponseType aiResponseType = AiResponseType.imageAnalysis,
  bool archived = false,
}) {
  return AiConfigPrompt(
    id: id,
    name: name,
    systemMessage: 'System message',
    userMessage: 'User message',
    defaultModelId: defaultModelId,
    modelIds: [defaultModelId],
    createdAt: DateTime(2024, 3, 15, 10, 30),
    useReasoning: false,
    requiredInputData: requiredInputData,
    aiResponseType: aiResponseType,
    archived: archived,
  );
}

AiConfigModel createModel({
  required String id,
  required String inferenceProviderId,
  required String providerModelId,
  GeminiThinkingMode geminiThinkingMode = GeminiThinkingMode.low,
}) {
  return AiConfigModel(
    id: id,
    name: 'Test Model',
    providerModelId: providerModelId,
    inferenceProviderId: inferenceProviderId,
    createdAt: DateTime(2024, 3, 15, 10, 30),
    inputModalities: [Modality.text],
    outputModalities: [Modality.text],
    isReasoningModel: false,
    geminiThinkingMode: geminiThinkingMode,
  );
}

AiConfigInferenceProvider createProvider({
  required String id,
  required InferenceProviderType inferenceProviderType,
}) {
  return AiConfigInferenceProvider(
    id: id,
    baseUrl: 'https://api.example.com',
    apiKey: 'test-api-key',
    name: 'Test Provider',
    createdAt: DateTime(2024, 3, 15, 10, 30),
    inferenceProviderType: inferenceProviderType,
  );
}

CreateChatCompletionStreamResponse createStreamChunk(String content) {
  return CreateChatCompletionStreamResponse(
    id: 'test-completion-id',
    choices: [
      ChatCompletionStreamResponseChoice(
        index: 0,
        delta: ChatCompletionStreamResponseDelta(content: content),
      ),
    ],
    created: DateTime(2024, 3, 15, 10, 30).millisecondsSinceEpoch ~/ 1000,
    model: 'test-model',
    object: 'chat.completion.chunk',
  );
}

/// Creates a mock stream of text chunks. The last chunk includes a stop
/// finish reason and, when given, the [usage] block providers report on the
/// final chunk. Replaces verbose inline [Stream.fromIterable] blocks.
Stream<CreateChatCompletionStreamResponse> createMockTextStream(
  List<String> chunks, {
  CompletionUsage? usage,
}) {
  return Stream.fromIterable([
    for (var i = 0; i < chunks.length; i++)
      CreateChatCompletionStreamResponse(
        id: 'response-${i + 1}',
        choices: [
          ChatCompletionStreamResponseChoice(
            delta: ChatCompletionStreamResponseDelta(content: chunks[i]),
            finishReason: i == chunks.length - 1
                ? ChatCompletionFinishReason.stop
                : null,
            index: 0,
          ),
        ],
        object: 'chat.completion.chunk',
        created: DateTime(2024, 3, 15, 10, 30).millisecondsSinceEpoch ~/ 1000,
        usage: i == chunks.length - 1 ? usage : null,
      ),
  ]);
}

AiInteractionCaptureTestBench registerInteractionCapture() {
  final bench = AiInteractionCaptureTestBench.create()..register();
  addTearDown(bench.unregister);
  return bench;
}

List<AiConsumptionEvent> capturedEvents(AiInteractionCaptureTestBench bench) =>
    verify(
      () => bench.service.recordInteraction(
        attributionId: any(named: 'attributionId'),
        event: captureAny(named: 'event'),
      ),
    ).captured.cast<AiConsumptionEvent>();

/// Stubs `CloudInferenceRepository.generate` to return [stream]. When
/// [impact] is given, the stub writes it into the `InferenceImpactCollector`
/// the repository passed down — mirroring how the Melious adapter reports
/// per-call cost/energy out of band.
void stubGenerate(
  MockCloudInferenceRepository mock, {
  required Stream<CreateChatCompletionStreamResponse> stream,
  MeliousCallImpact? impact,
}) {
  when(
    () => mock.generate(
      any(),
      model: any(named: 'model'),
      temperature: any(named: 'temperature'),
      baseUrl: any(named: 'baseUrl'),
      apiKey: any(named: 'apiKey'),
      systemMessage: any(named: 'systemMessage'),
      maxCompletionTokens: any(named: 'maxCompletionTokens'),
      provider: any(named: 'provider'),
      tools: any(named: 'tools'),
      geminiThinkingMode: any(named: 'geminiThinkingMode'),
      impactCollector: any(named: 'impactCollector'),
    ),
  ).thenAnswer((invocation) {
    if (impact != null) {
      (invocation.namedArguments[#impactCollector] as InferenceImpactCollector?)
              ?.impact =
          impact;
    }
    return stream;
  });
}

/// Stubs `CloudInferenceRepository.generateWithImages` to return [stream].
void stubGenerateWithImages(
  MockCloudInferenceRepository mock, {
  required Stream<CreateChatCompletionStreamResponse> stream,
}) {
  when(
    () => mock.generateWithImages(
      any(),
      provider: any(named: 'provider'),
      model: any(named: 'model'),
      temperature: any(named: 'temperature'),
      images: any(named: 'images'),
      baseUrl: any(named: 'baseUrl'),
      apiKey: any(named: 'apiKey'),
      maxCompletionTokens: any(named: 'maxCompletionTokens'),
      impactCollector: any(named: 'impactCollector'),
    ),
  ).thenAnswer((_) => stream);
}

/// Stubs `CloudInferenceRepository.generateWithAudio` to return [stream].
void stubGenerateWithAudio(
  MockCloudInferenceRepository mock, {
  required Stream<CreateChatCompletionStreamResponse> stream,
}) {
  when(
    () => mock.generateWithAudio(
      any(),
      provider: any(named: 'provider'),
      model: any(named: 'model'),
      audioBase64: any(named: 'audioBase64'),
      baseUrl: any(named: 'baseUrl'),
      apiKey: any(named: 'apiKey'),
      maxCompletionTokens: any(named: 'maxCompletionTokens'),
      stream: any(named: 'stream'),
      audioFormat: any(named: 'audioFormat'),
    ),
  ).thenAnswer((_) => stream);
}

/// Stubs the common context lookups needed before `runInference`:
/// entity fetch, model/provider resolution, and task details JSON.
void stubInferenceContext({
  required MockAiInputRepository mockAiInputRepo,
  required MockAiConfigRepository mockAiConfigRepo,
  required JournalEntity entity,
  required AiConfigModel model,
  required AiConfigInferenceProvider provider,
  String? entityId,
  String taskDetailsJson = '{"task": "Test Task"}',
}) {
  final id = entityId ?? entity.id;
  when(() => mockAiInputRepo.getEntity(id)).thenAnswer((_) async => entity);
  when(
    () => mockAiConfigRepo.getConfigById(model.id),
  ).thenAnswer((_) async => model);
  when(
    () => mockAiConfigRepo.getConfigById(provider.id),
  ).thenAnswer((_) async => provider);
  when(
    () => mockAiInputRepo.buildTaskDetailsJson(id: id),
  ).thenAnswer((_) async => taskDetailsJson);
}

/// Stubs `AiInputRepository.createAiResponseEntry` to return null.
void stubCreateAiResponseEntry(MockAiInputRepository mock) {
  when(
    () => mock.createAiResponseEntry(
      id: any(named: 'id'),
      data: any(named: 'data'),
      start: any(named: 'start'),
      linkedId: any(named: 'linkedId'),
      categoryId: any(named: 'categoryId'),
    ),
  ).thenAnswer((invocation) async {
    final start = invocation.namedArguments[#start] as DateTime;
    return JournalEntity.aiResponse(
          meta: Metadata(
            id: invocation.namedArguments[#id] as String? ?? 'ai-response-1',
            createdAt: start,
            updatedAt: start,
            dateFrom: start,
            dateTo: start,
            categoryId: invocation.namedArguments[#categoryId] as String?,
          ),
          data: invocation.namedArguments[#data] as AiResponseData,
        )
        as AiResponseEntry;
  });
}

CreateChatCompletionStreamResponse createStreamChunkWithToolCalls(
  List<ChatCompletionStreamMessageToolCallChunk> toolCalls,
) {
  return CreateChatCompletionStreamResponse(
    id: 'test-completion-id',
    choices: [
      ChatCompletionStreamResponseChoice(
        index: 0,
        delta: ChatCompletionStreamResponseDelta(toolCalls: toolCalls),
      ),
    ],
    created: DateTime(2024, 3, 15, 10, 30).millisecondsSinceEpoch ~/ 1000,
    model: 'test-model',
    object: 'chat.completion.chunk',
  );
}

ChatCompletionMessageToolCall createMockMessageToolCall({
  required String id,
  required String functionName,
  required String arguments,
}) {
  return ChatCompletionMessageToolCall(
    id: id,
    type: ChatCompletionMessageToolCallType.function,
    function: ChatCompletionMessageFunctionCall(
      name: functionName,
      arguments: arguments,
    ),
  );
}

// Create a mock tool call that mimics the structure the implementation expects
ChatCompletionStreamMessageToolCallChunk createMockToolCall({
  required int index,
  required String? id,
  required String functionName,
  required String arguments,
}) {
  // Use the actual constructor with proper types
  return ChatCompletionStreamMessageToolCallChunk(
    index: index,
    id: id,
    type: ChatCompletionStreamMessageToolCallChunkType.function,
    function: ChatCompletionStreamMessageFunctionCall(
      name: functionName,
      arguments: arguments,
    ),
  );
}
