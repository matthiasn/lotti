import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/ai_input.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/ollama_repository.dart';
import 'package:lotti/features/ai/repository/unified_ai_inference_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ollama/ollama.dart';
import 'package:openai_dart/openai_dart.dart';

class MockAiConfigRepository extends Mock implements AiConfigRepository {}

class MockAiInputRepository extends Mock implements AiInputRepository {}

class MockCloudInferenceRepository extends Mock
    implements CloudInferenceRepository {}

class MockOllamaRepository extends Mock implements OllamaRepository {}

class MockJournalRepository extends Mock implements JournalRepository {}

class MockJournalDb extends Mock implements JournalDb {}

class MockRef extends Mock implements Ref {}

class FakeAiConfigPrompt extends Fake implements AiConfigPrompt {}

class FakeAiConfigModel extends Fake implements AiConfigModel {}

class FakeAiConfigInferenceProvider extends Fake
    implements AiConfigInferenceProvider {}

class FakeMetadata extends Fake implements Metadata {}

class FakeTaskData extends Fake implements TaskData {}

class FakeImageData extends Fake implements ImageData {}

class FakeAudioData extends Fake implements AudioData {}

class FakeCreateChatCompletionStreamResponse extends Fake
    implements CreateChatCompletionStreamResponse {}

class FakeAiResponseData extends Fake implements AiResponseData {}

// Mock class to simulate Ollama response chunk
class MockCompletionChunk {
  MockCompletionChunk({required this.text});
  final String text;
}

void main() {
  late UnifiedAiInferenceRepository repository;
  late MockRef mockRef;
  late MockAiConfigRepository mockAiConfigRepo;
  late MockAiInputRepository mockAiInputRepo;
  late MockCloudInferenceRepository mockCloudInferenceRepo;
  late MockOllamaRepository mockOllamaRepo;
  late MockJournalRepository mockJournalRepo;
  late MockJournalDb mockJournalDb;

  setUpAll(() {
    registerFallbackValue(FakeAiConfigPrompt());
    registerFallbackValue(FakeAiConfigModel());
    registerFallbackValue(FakeAiConfigInferenceProvider());
    registerFallbackValue(FakeMetadata());
    registerFallbackValue(FakeTaskData());
    registerFallbackValue(FakeImageData());
    registerFallbackValue(FakeAudioData());
    registerFallbackValue(InferenceStatus.idle);
    registerFallbackValue(FakeAiResponseData());
  });

  setUp(() {
    mockRef = MockRef();
    mockAiConfigRepo = MockAiConfigRepository();
    mockAiInputRepo = MockAiInputRepository();
    mockCloudInferenceRepo = MockCloudInferenceRepository();
    mockOllamaRepo = MockOllamaRepository();
    mockJournalRepo = MockJournalRepository();
    mockJournalDb = MockJournalDb();

    // Set up GetIt
    if (getIt.isRegistered<JournalDb>()) {
      getIt.unregister<JournalDb>();
    }
    getIt.registerSingleton<JournalDb>(mockJournalDb);

    // Mock getConfigFlag to return false for cloud inference
    when(() => mockJournalDb.getConfigFlag(useCloudInferenceFlag))
        .thenAnswer((_) async => false);

    // Setup mock ref to return mocked repositories
    when(() => mockRef.read(aiConfigRepositoryProvider))
        .thenReturn(mockAiConfigRepo);
    when(() => mockRef.read(aiInputRepositoryProvider))
        .thenReturn(mockAiInputRepo);
    when(() => mockRef.read(cloudInferenceRepositoryProvider))
        .thenReturn(mockCloudInferenceRepo);
    when(() => mockRef.read(ollamaRepositoryProvider))
        .thenReturn(mockOllamaRepo);
    when(() => mockRef.read(journalRepositoryProvider))
        .thenReturn(mockJournalRepo);

    repository = UnifiedAiInferenceRepository(mockRef);
  });

  tearDown(() {
    if (getIt.isRegistered<JournalDb>()) {
      getIt.unregister<JournalDb>();
    }
  });

  group('UnifiedAiInferenceRepository', () {
    group('getActivePromptsForContext', () {
      test('returns prompts matching task entity', () async {
        final taskEntity = Task(
          meta: _createMetadata(),
          data: TaskData(
            status: TaskStatus.started(
              id: 'status-1',
              createdAt: DateTime.now(),
              utcOffset: 0,
            ),
            title: 'Test Task',
            statusHistory: [],
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
          ),
        );

        final taskPrompt = _createPrompt(
          id: 'task-prompt',
          name: 'Task Summary',
          requiredInputData: [InputDataType.task],
          aiResponseType: AiResponseType.taskSummary,
        );

        final imagePrompt = _createPrompt(
          id: 'image-prompt',
          name: 'Image Analysis',
          requiredInputData: [InputDataType.images],
          aiResponseType: AiResponseType.imageAnalysis,
        );

        when(() => mockAiConfigRepo.getConfigsByType(AiConfigType.prompt))
            .thenAnswer((_) async => [taskPrompt, imagePrompt]);

        final result = await repository.getActivePromptsForContext(
          entity: taskEntity,
        );

        expect(result.length, 1);
        expect(result.first.id, 'task-prompt');
      });

      test('returns prompts matching image entity', () async {
        final imageEntity = JournalImage(
          meta: _createMetadata(),
          data: ImageData(
            capturedAt: DateTime.now(),
            imageId: 'test-image',
            imageFile: 'test.jpg',
            imageDirectory: '/images',
          ),
        );

        final taskPrompt = _createPrompt(
          id: 'task-prompt',
          name: 'Task Summary',
          requiredInputData: [InputDataType.task],
          aiResponseType: AiResponseType.taskSummary,
        );

        final imagePrompt = _createPrompt(
          id: 'image-prompt',
          name: 'Image Analysis',
          requiredInputData: [InputDataType.images],
          aiResponseType: AiResponseType.imageAnalysis,
        );

        when(() => mockAiConfigRepo.getConfigsByType(AiConfigType.prompt))
            .thenAnswer((_) async => [taskPrompt, imagePrompt]);

        final result = await repository.getActivePromptsForContext(
          entity: imageEntity,
        );

        expect(result.length, 1);
        expect(result.first.id, 'image-prompt');
      });

      test('returns empty list when no prompts match', () async {
        final journalEntry = JournalEntry(
          meta: _createMetadata(),
        );

        final taskPrompt = _createPrompt(
          id: 'task-prompt',
          name: 'Task Summary',
          requiredInputData: [InputDataType.task],
          aiResponseType: AiResponseType.taskSummary,
        );

        when(() => mockAiConfigRepo.getConfigsByType(AiConfigType.prompt))
            .thenAnswer((_) async => [taskPrompt]);

        final result = await repository.getActivePromptsForContext(
          entity: journalEntry,
        );

        expect(result.isEmpty, true);
      });
    });

    group('runInference', () {
      test('successfully runs inference for text prompt', () async {
        final taskEntity = Task(
          meta: _createMetadata(),
          data: TaskData(
            status: TaskStatus.started(
              id: 'status-1',
              createdAt: DateTime.now(),
              utcOffset: 0,
            ),
            title: 'Test Task',
            statusHistory: [],
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
          ),
        );

        final promptConfig = _createPrompt(
          id: 'prompt-1',
          name: 'Task Summary',
          defaultModelId: 'model-1',
          requiredInputData: [InputDataType.task],
          aiResponseType: AiResponseType.taskSummary,
        );

        final model = _createModel(
          id: 'model-1',
          inferenceProviderId: 'provider-1',
          providerModelId: 'gpt-4',
        );

        final provider = _createProvider(
          id: 'provider-1',
          inferenceProviderType: InferenceProviderType.genericOpenAi,
        );

        final progressUpdates = <String>[];
        final statusChanges = <InferenceStatus>[];

        when(() => mockAiInputRepo.getEntity('test-id'))
            .thenAnswer((_) async => taskEntity);
        when(() => mockAiConfigRepo.getConfigById('model-1'))
            .thenAnswer((_) async => model);
        when(() => mockAiConfigRepo.getConfigById('provider-1'))
            .thenAnswer((_) async => provider);
        when(() => mockAiInputRepo.buildPrompt(
              id: 'test-id',
              aiResponseType: AiResponseType.taskSummary,
            )).thenAnswer((_) async => 'Test prompt');

        // Mock Ollama response stream
        final streamResponse = Stream.fromIterable([
          MockCompletionChunk(text: 'Hello'),
          MockCompletionChunk(text: ' world'),
          MockCompletionChunk(text: '!'),
        ]);

        when(() => mockOllamaRepo.generate(
              any(),
              model: any(named: 'model'),
              temperature: any(named: 'temperature'),
              images: any(named: 'images'),
            )).thenAnswer((_) => streamResponse);

        when(() => mockAiInputRepo.createAiResponseEntry(
              data: any(named: 'data'),
              start: any(named: 'start'),
              linkedId: any(named: 'linkedId'),
              categoryId: any(named: 'categoryId'),
            )).thenAnswer((_) async => {});

        await repository.runInference(
          entityId: 'test-id',
          promptConfig: promptConfig,
          onProgress: (progress) => progressUpdates.add(progress),
          onStatusChange: (status) => statusChanges.add(status),
        );

        expect(progressUpdates, ['Hello', 'Hello world', 'Hello world!']);
        expect(statusChanges, [InferenceStatus.running, InferenceStatus.idle]);

        verify(() => mockAiInputRepo.createAiResponseEntry(
              data: any(named: 'data'),
              start: any(named: 'start'),
              linkedId: 'test-id',
              categoryId: null,
            )).called(1);
      });

      test('handles error during inference', () async {
        final taskEntity = Task(
          meta: _createMetadata(),
          data: TaskData(
            status: TaskStatus.started(
              id: 'status-1',
              createdAt: DateTime.now(),
              utcOffset: 0,
            ),
            title: 'Test Task',
            statusHistory: [],
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
          ),
        );

        final promptConfig = _createPrompt(
          id: 'prompt-1',
          name: 'Task Summary',
          defaultModelId: 'model-1',
          requiredInputData: [InputDataType.task],
          aiResponseType: AiResponseType.taskSummary,
        );

        final statusChanges = <InferenceStatus>[];

        when(() => mockAiInputRepo.getEntity('test-id'))
            .thenAnswer((_) async => taskEntity);
        when(() => mockAiConfigRepo.getConfigById('model-1'))
            .thenThrow(Exception('Model not found'));

        expect(
          () => repository.runInference(
            entityId: 'test-id',
            promptConfig: promptConfig,
            onProgress: (_) {},
            onStatusChange: (status) => statusChanges.add(status),
          ),
          throwsException,
        );

        await Future.delayed(Duration.zero);
        expect(statusChanges, [InferenceStatus.running, InferenceStatus.error]);
      });
    });
  });
}

// Helper methods to create test objects
Metadata _createMetadata() {
  return Metadata(
    id: 'test-id',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    dateFrom: DateTime.now(),
    dateTo: DateTime.now(),
  );
}

AiConfigPrompt _createPrompt({
  required String id,
  required String name,
  String defaultModelId = 'model-1',
  List<InputDataType> requiredInputData = const [],
  AiResponseType aiResponseType = AiResponseType.taskSummary,
}) {
  return AiConfigPrompt(
    id: id,
    name: name,
    systemMessage: 'System message',
    userMessage: 'User message',
    defaultModelId: defaultModelId,
    modelIds: [defaultModelId],
    createdAt: DateTime.now(),
    useReasoning: false,
    requiredInputData: requiredInputData,
    aiResponseType: aiResponseType,
  );
}

AiConfigModel _createModel({
  required String id,
  required String inferenceProviderId,
  required String providerModelId,
}) {
  return AiConfigModel(
    id: id,
    name: 'Test Model',
    providerModelId: providerModelId,
    inferenceProviderId: inferenceProviderId,
    createdAt: DateTime.now(),
    inputModalities: [Modality.text],
    outputModalities: [Modality.text],
    isReasoningModel: false,
  );
}

AiConfigInferenceProvider _createProvider({
  required String id,
  required InferenceProviderType inferenceProviderType,
}) {
  return AiConfigInferenceProvider(
    id: id,
    baseUrl: 'https://api.example.com',
    apiKey: 'test-api-key',
    name: 'Test Provider',
    createdAt: DateTime.now(),
    inferenceProviderType: inferenceProviderType,
  );
}

CreateChatCompletionStreamResponse _createStreamResponse(String content) {
  return CreateChatCompletionStreamResponse(
    id: 'test-response',
    created: DateTime.now().millisecondsSinceEpoch,
    model: 'test-model',
    choices: [
      ChatCompletionStreamResponseChoice(
        index: 0,
        delta: ChatCompletionStreamResponseDelta(
          content: content,
        ),
        finishReason: null,
      ),
    ],
  );
}
