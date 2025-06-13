import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/unified_ai_inference_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

class MockAiConfigRepository extends Mock implements AiConfigRepository {}

class MockAiInputRepository extends Mock implements AiInputRepository {}

class MockCloudInferenceRepository extends Mock
    implements CloudInferenceRepository {}

class MockJournalRepository extends Mock implements JournalRepository {}

class MockJournalDb extends Mock implements JournalDb {}

class MockRef extends Mock implements Ref {}

class MockDirectory extends Mock implements Directory {}

class MockFile extends Mock implements File {}

class FakeAiConfigPrompt extends Fake implements AiConfigPrompt {}

class FakeAiConfigModel extends Fake implements AiConfigModel {}

class FakeAiConfigInferenceProvider extends Fake
    implements AiConfigInferenceProvider {}

class FakeMetadata extends Fake implements Metadata {}

class FakeTaskData extends Fake implements TaskData {}

class FakeImageData extends Fake implements ImageData {}

class FakeAudioData extends Fake implements AudioData {}

class FakeAiResponseData extends Fake implements AiResponseData {}

class FakeJournalEntity extends Fake implements JournalEntity {}

class FakeJournalAudio extends Fake implements JournalAudio {}

void main() {
  late UnifiedAiInferenceRepository repository;
  late MockRef mockRef;
  late MockAiConfigRepository mockAiConfigRepo;
  late MockAiInputRepository mockAiInputRepo;
  late MockCloudInferenceRepository mockCloudInferenceRepo;
  late MockJournalRepository mockJournalRepo;
  late MockJournalDb mockJournalDb;
  late MockDirectory mockDirectory;

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
    registerFallbackValue(FakeJournalEntity());
    registerFallbackValue(FakeJournalAudio());
  });

  setUp(() {
    mockRef = MockRef();
    mockAiConfigRepo = MockAiConfigRepository();
    mockAiInputRepo = MockAiInputRepository();
    mockCloudInferenceRepo = MockCloudInferenceRepository();
    mockJournalRepo = MockJournalRepository();
    mockJournalDb = MockJournalDb();
    mockDirectory = MockDirectory();

    // Set up GetIt
    if (getIt.isRegistered<JournalDb>()) {
      getIt.unregister<JournalDb>();
    }
    if (getIt.isRegistered<Directory>()) {
      getIt.unregister<Directory>();
    }
    getIt
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<Directory>(mockDirectory);

    // Mock directory path
    when(() => mockDirectory.path).thenReturn('/mock/documents');

    // Setup mock ref to return mocked repositories
    when(() => mockRef.read(aiConfigRepositoryProvider))
        .thenReturn(mockAiConfigRepo);
    when(() => mockRef.read(aiInputRepositoryProvider))
        .thenReturn(mockAiInputRepo);
    when(() => mockRef.read(cloudInferenceRepositoryProvider))
        .thenReturn(mockCloudInferenceRepo);
    when(() => mockRef.read(journalRepositoryProvider))
        .thenReturn(mockJournalRepo);

    repository = UnifiedAiInferenceRepository(mockRef);
  });

  tearDown(() {
    if (getIt.isRegistered<JournalDb>()) {
      getIt.unregister<JournalDb>();
    }
    if (getIt.isRegistered<Directory>()) {
      getIt.unregister<Directory>();
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
            imageDirectory: '/images/',
          ),
        );

        final taskPrompt = _createPrompt(
          id: 'task-prompt',
          name: 'Task Summary',
          requiredInputData: [InputDataType.task],
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

      test('returns prompts matching audio entity', () async {
        final audioEntity = JournalAudio(
          meta: _createMetadata(),
          data: AudioData(
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
            audioFile: 'test.mp3',
            audioDirectory: '/audio/',
            duration: const Duration(seconds: 30),
          ),
        );

        final audioPrompt = _createPrompt(
          id: 'audio-prompt',
          name: 'Audio Transcription',
          requiredInputData: [InputDataType.audioFiles],
          aiResponseType: AiResponseType.audioTranscription,
        );

        final taskPrompt = _createPrompt(
          id: 'task-prompt',
          name: 'Task Summary',
          requiredInputData: [InputDataType.task],
        );

        when(() => mockAiConfigRepo.getConfigsByType(AiConfigType.prompt))
            .thenAnswer((_) async => [audioPrompt, taskPrompt]);

        final result = await repository.getActivePromptsForContext(
          entity: audioEntity,
        );

        expect(result.length, 1);
        expect(result.first.id, 'audio-prompt');
      });

      test('returns prompts matching multiple input types', () async {
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

        final multiInputPrompt = _createPrompt(
          id: 'multi-prompt',
          name: 'Multi Input Prompt',
          requiredInputData: [InputDataType.task, InputDataType.tasksList],
        );

        when(() => mockAiConfigRepo.getConfigsByType(AiConfigType.prompt))
            .thenAnswer((_) async => [multiInputPrompt]);

        final result = await repository.getActivePromptsForContext(
          entity: taskEntity,
        );

        expect(result.length, 1);
        expect(result.first.id, 'multi-prompt');
      });

      test('filters out prompts with mismatched input types', () async {
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

        final mismatchedPrompt = _createPrompt(
          id: 'mismatched-prompt',
          name: 'Mismatched Prompt',
          requiredInputData: [InputDataType.task, InputDataType.images],
        );

        when(() => mockAiConfigRepo.getConfigsByType(AiConfigType.prompt))
            .thenAnswer((_) async => [mismatchedPrompt]);

        final result = await repository.getActivePromptsForContext(
          entity: taskEntity,
        );

        expect(result.isEmpty, true);
      });

      test('filters out archived prompts', () async {
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

        final activePrompt = _createPrompt(
          id: 'active-prompt',
          name: 'Active Task Prompt',
          requiredInputData: [InputDataType.task],
        );

        final archivedPrompt = _createPrompt(
          id: 'archived-prompt',
          name: 'Archived Task Prompt',
          requiredInputData: [InputDataType.task],
          archived: true,
        );

        when(() => mockAiConfigRepo.getConfigsByType(AiConfigType.prompt))
            .thenAnswer((_) async => [activePrompt, archivedPrompt]);

        final result = await repository.getActivePromptsForContext(
          entity: taskEntity,
        );

        expect(result.length, 1);
        expect(result.first.id, 'active-prompt');
      });

      test('returns empty list when no prompts match', () async {
        final journalEntry = JournalEntry(
          meta: _createMetadata(),
        );

        final taskPrompt = _createPrompt(
          id: 'task-prompt',
          name: 'Task Summary',
          requiredInputData: [InputDataType.task],
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
          requiredInputData: [InputDataType.task],
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

        // Mock the stream response from cloud inference
        final mockStream = Stream.fromIterable([
          CreateChatCompletionStreamResponse(
            id: 'response-1',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(content: 'Hello'),
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
          CreateChatCompletionStreamResponse(
            id: 'response-2',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(content: ' world'),
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
          CreateChatCompletionStreamResponse(
            id: 'response-3',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(content: '!'),
                finishReason: ChatCompletionFinishReason.stop,
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        ]);

        when(() => mockAiInputRepo.getEntity('test-id'))
            .thenAnswer((_) async => taskEntity);
        when(() => mockAiConfigRepo.getConfigById('model-1'))
            .thenAnswer((_) async => model);
        when(() => mockAiConfigRepo.getConfigById('provider-1'))
            .thenAnswer((_) async => provider);
        when(() => mockAiInputRepo.buildTaskDetailsJson(id: 'test-id'))
            .thenAnswer((_) async => '{"task": "Test Task"}');

        // Mock cloud inference repository
        when(
          () => mockCloudInferenceRepo.generate(
            any(),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            systemMessage: any(named: 'systemMessage'),
          ),
        ).thenAnswer((_) => mockStream);

        when(
          () => mockAiInputRepo.createAiResponseEntry(
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async {});

        await repository.runInference(
          entityId: 'test-id',
          promptConfig: promptConfig,
          onProgress: progressUpdates.add,
          onStatusChange: statusChanges.add,
        );

        expect(progressUpdates, ['Hello', 'Hello world', 'Hello world!']);
        expect(statusChanges, [InferenceStatus.running, InferenceStatus.idle]);

        verify(
          () => mockAiInputRepo.createAiResponseEntry(
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: 'test-id',
            categoryId: any(named: 'categoryId'),
          ),
        ).called(1);

        verify(
          () => mockCloudInferenceRepo.generate(
            any(),
            model: 'gpt-4',
            temperature: 0.6,
            baseUrl: 'https://api.example.com',
            apiKey: 'test-api-key',
            systemMessage: 'System message',
          ),
        ).called(1);
      });

      test('successfully runs inference with images', () async {
        // Create a temporary directory for the test
        final tempDir = Directory.systemTemp.createTempSync('image_test');

        // Update the mock directory to point to our temp directory
        when(() => mockDirectory.path).thenReturn(tempDir.path);

        final imageEntity = JournalImage(
          meta: _createMetadata(),
          data: ImageData(
            capturedAt: DateTime.now(),
            imageId: 'test-image',
            imageFile: 'test.jpg',
            imageDirectory: '/images/',
          ),
        );

        // Create the directory structure and file
        Directory('${tempDir.path}/images').createSync(recursive: true);
        final imageFile = File('${tempDir.path}/images/test.jpg');
        final mockImageBytes = Uint8List.fromList([1, 2, 3, 4]);
        imageFile.writeAsBytesSync(mockImageBytes);

        final promptConfig = _createPrompt(
          id: 'prompt-1',
          name: 'Image Analysis',
          requiredInputData: [InputDataType.images],
          aiResponseType: AiResponseType.imageAnalysis,
        );

        final model = _createModel(
          id: 'model-1',
          inferenceProviderId: 'provider-1',
          providerModelId: 'gpt-4-vision',
        );

        final provider = _createProvider(
          id: 'provider-1',
          inferenceProviderType: InferenceProviderType.genericOpenAi,
        );

        final progressUpdates = <String>[];
        final statusChanges = <InferenceStatus>[];

        final mockStream = Stream.fromIterable([
          CreateChatCompletionStreamResponse(
            id: 'response-1',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta:
                    ChatCompletionStreamResponseDelta(content: 'Image shows'),
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
          CreateChatCompletionStreamResponse(
            id: 'response-2',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(content: ' a cat'),
                finishReason: ChatCompletionFinishReason.stop,
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        ]);

        when(() => mockAiInputRepo.getEntity('test-id'))
            .thenAnswer((_) async => imageEntity);
        when(() => mockAiConfigRepo.getConfigById('model-1'))
            .thenAnswer((_) async => model);
        when(() => mockAiConfigRepo.getConfigById('provider-1'))
            .thenAnswer((_) async => provider);
        when(() => mockAiInputRepo.buildTaskDetailsJson(id: 'test-id'))
            .thenAnswer((_) async => '{"image": "test.jpg"}');

        when(
          () => mockCloudInferenceRepo.generateWithImages(
            any(),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            images: any(named: 'images'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
          ),
        ).thenAnswer((_) => mockStream);

        when(
          () => mockAiInputRepo.createAiResponseEntry(
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async {});

        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((_) async => true);

        try {
          await repository.runInference(
            entityId: 'test-id',
            promptConfig: promptConfig,
            onProgress: progressUpdates.add,
            onStatusChange: statusChanges.add,
          );

          expect(progressUpdates, ['Image shows', 'Image shows a cat']);
          expect(
            statusChanges,
            [InferenceStatus.running, InferenceStatus.idle],
          );

          verify(
            () => mockCloudInferenceRepo.generateWithImages(
              any(),
              model: 'gpt-4-vision',
              temperature: 0.6,
              images: any(named: 'images'),
              baseUrl: 'https://api.example.com',
              apiKey: 'test-api-key',
            ),
          ).called(1);

          verify(() => mockJournalRepo.updateJournalEntity(any())).called(1);
        } finally {
          // Clean up the temporary directory
          tempDir.deleteSync(recursive: true);
        }
      });

      test('successfully runs inference with audio', () async {
        // Create a temporary directory for the test
        final tempDir = Directory.systemTemp.createTempSync('audio_test');

        // Update the mock directory to point to our temp directory
        when(() => mockDirectory.path).thenReturn(tempDir.path);

        final audioEntity = JournalAudio(
          meta: _createMetadata(),
          data: AudioData(
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
            audioFile: 'test.mp3',
            audioDirectory: '/audio/',
            duration: const Duration(seconds: 30),
          ),
        );

        // Create the directory structure and file
        Directory('${tempDir.path}/audio').createSync(recursive: true);
        final audioFile = File('${tempDir.path}/audio/test.mp3');
        final mockAudioBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6]);
        audioFile.writeAsBytesSync(mockAudioBytes);

        final promptConfig = _createPrompt(
          id: 'prompt-1',
          name: 'Audio Transcription',
          requiredInputData: [InputDataType.audioFiles],
          aiResponseType: AiResponseType.audioTranscription,
        );

        final model = _createModel(
          id: 'model-1',
          inferenceProviderId: 'provider-1',
          providerModelId: 'whisper-1',
        );

        final provider = _createProvider(
          id: 'provider-1',
          inferenceProviderType: InferenceProviderType.genericOpenAi,
        );

        final progressUpdates = <String>[];
        final statusChanges = <InferenceStatus>[];

        final mockStream = Stream.fromIterable([
          CreateChatCompletionStreamResponse(
            id: 'response-1',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta:
                    ChatCompletionStreamResponseDelta(content: 'Hello world'),
                finishReason: ChatCompletionFinishReason.stop,
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        ]);

        when(() => mockAiInputRepo.getEntity('test-id'))
            .thenAnswer((_) async => audioEntity);
        when(() => mockAiConfigRepo.getConfigById('model-1'))
            .thenAnswer((_) async => model);
        when(() => mockAiConfigRepo.getConfigById('provider-1'))
            .thenAnswer((_) async => provider);
        when(() => mockAiInputRepo.buildTaskDetailsJson(id: 'test-id'))
            .thenAnswer((_) async => '{"audio": "test.mp3"}');

        when(
          () => mockCloudInferenceRepo.generateWithAudio(
            any(),
            model: any(named: 'model'),
            audioBase64: any(named: 'audioBase64'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
          ),
        ).thenAnswer((_) => mockStream);

        when(
          () => mockAiInputRepo.createAiResponseEntry(
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async {});

        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((_) async => true);

        try {
          await repository.runInference(
            entityId: 'test-id',
            promptConfig: promptConfig,
            onProgress: progressUpdates.add,
            onStatusChange: statusChanges.add,
          );

          expect(progressUpdates, ['Hello world']);
          expect(
            statusChanges,
            [InferenceStatus.running, InferenceStatus.idle],
          );

          verify(
            () => mockCloudInferenceRepo.generateWithAudio(
              any(),
              model: 'whisper-1',
              audioBase64: any(named: 'audioBase64'),
              baseUrl: 'https://api.example.com',
              apiKey: 'test-api-key',
            ),
          ).called(1);

          // updateJournalEntity verification is already done via the captured call above
        } finally {
          // Clean up the temporary directory
          tempDir.deleteSync(recursive: true);
        }
      });

      test('handles reasoning model response with thoughts', () async {
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
          requiredInputData: [InputDataType.task],
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

        final mockStream = Stream.fromIterable([
          CreateChatCompletionStreamResponse(
            id: 'response-1',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(
                  content:
                      '<think>Let me analyze this task</think>Task completed successfully',
                ),
                finishReason: ChatCompletionFinishReason.stop,
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        ]);

        when(() => mockAiInputRepo.getEntity('test-id'))
            .thenAnswer((_) async => taskEntity);
        when(() => mockAiConfigRepo.getConfigById('model-1'))
            .thenAnswer((_) async => model);
        when(() => mockAiConfigRepo.getConfigById('provider-1'))
            .thenAnswer((_) async => provider);
        when(() => mockAiInputRepo.buildTaskDetailsJson(id: 'test-id'))
            .thenAnswer((_) async => '{"task": "Test Task"}');

        when(
          () => mockCloudInferenceRepo.generate(
            any(),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            systemMessage: any(named: 'systemMessage'),
          ),
        ).thenAnswer((_) => mockStream);

        when(
          () => mockAiInputRepo.createAiResponseEntry(
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async {});

        await repository.runInference(
          entityId: 'test-id',
          promptConfig: promptConfig,
          onProgress: progressUpdates.add,
          onStatusChange: statusChanges.add,
        );

        expect(progressUpdates, [
          '<think>Let me analyze this task</think>Task completed successfully',
        ]);
        expect(statusChanges, [InferenceStatus.running, InferenceStatus.idle]);

        // Verify that the AI response entry was created with extracted thoughts
        final captured = verify(
          () => mockAiInputRepo.createAiResponseEntry(
            data: captureAny(named: 'data'),
            start: any(named: 'start'),
            linkedId: 'test-id',
            categoryId: any(named: 'categoryId'),
          ),
        ).captured;

        final data = captured.first as AiResponseData;
        expect(data.thoughts, '<think>Let me analyze this task');
        expect(data.response, 'Task completed successfully');
      });

      test('handles action item suggestions response type', () async {
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
          name: 'Action Item Suggestions',
          requiredInputData: [InputDataType.task],
          aiResponseType: AiResponseType.actionItemSuggestions,
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

        final mockStream = Stream.fromIterable([
          CreateChatCompletionStreamResponse(
            id: 'response-1',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(
                  content:
                      'Here are some suggestions: [{"title": "Review code", "completed": false}]',
                ),
                finishReason: ChatCompletionFinishReason.stop,
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        ]);

        when(() => mockAiInputRepo.getEntity('test-id'))
            .thenAnswer((_) async => taskEntity);
        when(() => mockAiConfigRepo.getConfigById('model-1'))
            .thenAnswer((_) async => model);
        when(() => mockAiConfigRepo.getConfigById('provider-1'))
            .thenAnswer((_) async => provider);
        when(() => mockAiInputRepo.buildTaskDetailsJson(id: 'test-id'))
            .thenAnswer((_) async => '{"task": "Test Task"}');

        when(
          () => mockCloudInferenceRepo.generate(
            any(),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            systemMessage: any(named: 'systemMessage'),
          ),
        ).thenAnswer((_) => mockStream);

        when(
          () => mockAiInputRepo.createAiResponseEntry(
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async {});

        await repository.runInference(
          entityId: 'test-id',
          promptConfig: promptConfig,
          onProgress: progressUpdates.add,
          onStatusChange: statusChanges.add,
        );

        expect(progressUpdates, [
          'Here are some suggestions: [{"title": "Review code", "completed": false}]',
        ]);
        expect(statusChanges, [InferenceStatus.running, InferenceStatus.idle]);

        // Verify that the AI response entry was created with parsed action items
        final captured = verify(
          () => mockAiInputRepo.createAiResponseEntry(
            data: captureAny(named: 'data'),
            start: any(named: 'start'),
            linkedId: 'test-id',
            categoryId: any(named: 'categoryId'),
          ),
        ).captured;

        final data = captured.first as AiResponseData;
        expect(data.suggestedActionItems, isNotNull);
        expect(data.suggestedActionItems!.length, 1);
        expect(data.suggestedActionItems!.first.title, 'Review code');
      });

      test('handles malformed action items JSON gracefully', () async {
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
          name: 'Action Item Suggestions',
          requiredInputData: [InputDataType.task],
          aiResponseType: AiResponseType.actionItemSuggestions,
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

        final mockStream = Stream.fromIterable([
          CreateChatCompletionStreamResponse(
            id: 'response-1',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(
                  content: 'Here are some suggestions: [invalid json}',
                ),
                finishReason: ChatCompletionFinishReason.stop,
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        ]);

        when(() => mockAiInputRepo.getEntity('test-id'))
            .thenAnswer((_) async => taskEntity);
        when(() => mockAiConfigRepo.getConfigById('model-1'))
            .thenAnswer((_) async => model);
        when(() => mockAiConfigRepo.getConfigById('provider-1'))
            .thenAnswer((_) async => provider);
        when(() => mockAiInputRepo.buildTaskDetailsJson(id: 'test-id'))
            .thenAnswer((_) async => '{"task": "Test Task"}');

        when(
          () => mockCloudInferenceRepo.generate(
            any(),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            systemMessage: any(named: 'systemMessage'),
          ),
        ).thenAnswer((_) => mockStream);

        when(
          () => mockAiInputRepo.createAiResponseEntry(
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async {});

        await repository.runInference(
          entityId: 'test-id',
          promptConfig: promptConfig,
          onProgress: progressUpdates.add,
          onStatusChange: statusChanges.add,
        );

        expect(progressUpdates, ['Here are some suggestions: [invalid json}']);
        expect(statusChanges, [InferenceStatus.running, InferenceStatus.idle]);

        // Verify that the AI response entry was created with null action items
        final captured = verify(
          () => mockAiInputRepo.createAiResponseEntry(
            data: captureAny(named: 'data'),
            start: any(named: 'start'),
            linkedId: 'test-id',
            categoryId: any(named: 'categoryId'),
          ),
        ).captured;

        final data = captured.first as AiResponseData;
        expect(data.suggestedActionItems, isEmpty);
      });

      test('handles provider not found error', () async {
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
          requiredInputData: [InputDataType.task],
        );

        final model = _createModel(
          id: 'model-1',
          inferenceProviderId: 'provider-1',
          providerModelId: 'gpt-4',
        );

        final statusChanges = <InferenceStatus>[];

        when(() => mockAiInputRepo.getEntity('test-id'))
            .thenAnswer((_) async => taskEntity);
        when(() => mockAiConfigRepo.getConfigById('model-1'))
            .thenAnswer((_) async => model);
        when(() => mockAiConfigRepo.getConfigById('provider-1'))
            .thenAnswer((_) async => null);

        expect(
          () => repository.runInference(
            entityId: 'test-id',
            promptConfig: promptConfig,
            onProgress: (_) {},
            onStatusChange: statusChanges.add,
          ),
          throwsA(isA<Exception>()),
        );

        await Future<void>.delayed(Duration.zero);
        expect(statusChanges, [InferenceStatus.running, InferenceStatus.error]);
      });

      test('handles build prompt failure', () async {
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
          requiredInputData: [InputDataType.task],
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

        final statusChanges = <InferenceStatus>[];

        when(() => mockAiInputRepo.getEntity('test-id'))
            .thenAnswer((_) async => taskEntity);
        when(() => mockAiConfigRepo.getConfigById('model-1'))
            .thenAnswer((_) async => model);
        when(() => mockAiConfigRepo.getConfigById('provider-1'))
            .thenAnswer((_) async => provider);
        when(() => mockAiInputRepo.buildTaskDetailsJson(id: 'test-id'))
            .thenAnswer((_) async => null);

        when(
          () => mockCloudInferenceRepo.generate(
            any(),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            systemMessage: any(named: 'systemMessage'),
          ),
        ).thenThrow(Exception('Failed to build prompt'));

        expect(
          () => repository.runInference(
            entityId: 'test-id',
            promptConfig: promptConfig,
            onProgress: (_) {},
            onStatusChange: statusChanges.add,
          ),
          throwsA(isA<Exception>()),
        );

        await Future<void>.delayed(Duration.zero);
        expect(statusChanges, [InferenceStatus.running, InferenceStatus.error]);
      });

      test('handles empty stream chunk content', () async {
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
          requiredInputData: [InputDataType.task],
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

        final mockStream = Stream.fromIterable([
          CreateChatCompletionStreamResponse(
            id: 'response-1',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(),
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
          CreateChatCompletionStreamResponse(
            id: 'response-2',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(content: 'Hello'),
                finishReason: ChatCompletionFinishReason.stop,
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        ]);

        when(() => mockAiInputRepo.getEntity('test-id'))
            .thenAnswer((_) async => taskEntity);
        when(() => mockAiConfigRepo.getConfigById('model-1'))
            .thenAnswer((_) async => model);
        when(() => mockAiConfigRepo.getConfigById('provider-1'))
            .thenAnswer((_) async => provider);
        when(() => mockAiInputRepo.buildTaskDetailsJson(id: 'test-id'))
            .thenAnswer((_) async => '{"task": "Test Task"}');

        when(
          () => mockCloudInferenceRepo.generate(
            any(),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            systemMessage: any(named: 'systemMessage'),
          ),
        ).thenAnswer((_) => mockStream);

        when(
          () => mockAiInputRepo.createAiResponseEntry(
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async {});

        await repository.runInference(
          entityId: 'test-id',
          promptConfig: promptConfig,
          onProgress: progressUpdates.add,
          onStatusChange: statusChanges.add,
        );

        expect(progressUpdates, ['', 'Hello']);
        expect(statusChanges, [InferenceStatus.running, InferenceStatus.idle]);
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
          requiredInputData: [InputDataType.task],
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
            onStatusChange: statusChanges.add,
          ),
          throwsException,
        );

        await Future<void>.delayed(Duration.zero);
        expect(statusChanges, [InferenceStatus.running, InferenceStatus.error]);
      });

      test('handles entity not found error', () async {
        final promptConfig = _createPrompt(
          id: 'prompt-1',
          name: 'Task Summary',
          requiredInputData: [InputDataType.task],
        );

        final statusChanges = <InferenceStatus>[];

        when(() => mockAiInputRepo.getEntity('test-id'))
            .thenAnswer((_) async => null);

        expect(
          () => repository.runInference(
            entityId: 'test-id',
            promptConfig: promptConfig,
            onProgress: (_) {},
            onStatusChange: statusChanges.add,
          ),
          throwsA(isA<Exception>()),
        );

        await Future<void>.delayed(Duration.zero);
        expect(statusChanges, [InferenceStatus.running, InferenceStatus.error]);
      });

      test('audio transcription updates both transcripts and entry text',
          () async {
        final tempDir = Directory.systemTemp.createTempSync('audio_test');

        // Update the mock directory to point to our temp directory
        when(() => mockDirectory.path).thenReturn(tempDir.path);

        final audioEntity = JournalAudio(
          meta: _createMetadata(),
          data: AudioData(
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
            audioFile: 'test.mp3',
            audioDirectory: '/audio/',
            duration: const Duration(seconds: 30),
          ),
        );

        // Create the directory structure and file
        Directory('${tempDir.path}/audio').createSync(recursive: true);
        final audioFile = File('${tempDir.path}/audio/test.mp3');
        final mockAudioBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6]);
        audioFile.writeAsBytesSync(mockAudioBytes);

        final promptConfig = _createPrompt(
          id: 'prompt-1',
          name: 'Audio Transcription',
          requiredInputData: [InputDataType.audioFiles],
          aiResponseType: AiResponseType.audioTranscription,
        );

        final model = _createModel(
          id: 'model-1',
          inferenceProviderId: 'provider-1',
          providerModelId: 'whisper-1',
        );

        final provider = _createProvider(
          id: 'provider-1',
          inferenceProviderType: InferenceProviderType.genericOpenAi,
        );

        final progressUpdates = <String>[];
        final statusChanges = <InferenceStatus>[];
        const transcriptText = 'This is the transcribed audio content.';

        final mockStream = Stream.fromIterable([
          CreateChatCompletionStreamResponse(
            id: 'response-1',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta:
                    ChatCompletionStreamResponseDelta(content: transcriptText),
                finishReason: ChatCompletionFinishReason.stop,
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        ]);

        when(() => mockAiInputRepo.getEntity('test-id'))
            .thenAnswer((_) async => audioEntity);
        when(() => mockAiConfigRepo.getConfigById('model-1'))
            .thenAnswer((_) async => model);
        when(() => mockAiConfigRepo.getConfigById('provider-1'))
            .thenAnswer((_) async => provider);
        when(() => mockAiInputRepo.buildTaskDetailsJson(id: 'test-id'))
            .thenAnswer((_) async => '{"audio": "test.mp3"}');

        when(
          () => mockCloudInferenceRepo.generateWithAudio(
            any(),
            model: any(named: 'model'),
            audioBase64: any(named: 'audioBase64'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
          ),
        ).thenAnswer((_) => mockStream);

        when(
          () => mockAiInputRepo.createAiResponseEntry(
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async {});

        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((_) async => true);

        try {
          await repository.runInference(
            entityId: 'test-id',
            promptConfig: promptConfig,
            onProgress: progressUpdates.add,
            onStatusChange: statusChanges.add,
          );

          expect(progressUpdates, [transcriptText]);
          expect(
            statusChanges,
            [InferenceStatus.running, InferenceStatus.idle],
          );

          // Verify that updateJournalEntity was called with the correct data
          final captured =
              verify(() => mockJournalRepo.updateJournalEntity(captureAny()))
                  .captured;
          final updatedEntity = captured.first as JournalAudio;

          // Verify that the transcript was added to the transcripts array
          expect(updatedEntity.data.transcripts, isNotNull);
          expect(updatedEntity.data.transcripts!.length, 1);
          expect(
            updatedEntity.data.transcripts!.first.transcript,
            transcriptText.trim(),
          );
          expect(
            updatedEntity.data.transcripts!.first.library,
            'AI Transcription',
          );

          // Verify that the entry text was updated with the transcript
          expect(updatedEntity.entryText, isNotNull);
          expect(updatedEntity.entryText!.plainText, transcriptText.trim());
          expect(updatedEntity.entryText!.markdown, transcriptText.trim());

          verify(
            () => mockCloudInferenceRepo.generateWithAudio(
              any(),
              model: 'whisper-1',
              audioBase64: any(named: 'audioBase64'),
              baseUrl: 'https://api.example.com',
              apiKey: 'test-api-key',
            ),
          ).called(1);

          // updateJournalEntity verification is already done via the captured call above
        } finally {
          // Clean up the temporary directory
          tempDir.deleteSync(recursive: true);
        }
      });

      test(
          'audio transcription preserves existing transcripts when adding new one',
          () async {
        final tempDir = Directory.systemTemp.createTempSync('audio_test');

        // Update the mock directory to point to our temp directory
        when(() => mockDirectory.path).thenReturn(tempDir.path);

        final existingTranscript = AudioTranscript(
          created: DateTime.now().subtract(const Duration(hours: 1)),
          library: 'Previous Transcription',
          model: 'old-model',
          detectedLanguage: 'en',
          transcript: 'Previous transcript content',
          processingTime: const Duration(seconds: 5),
        );

        final audioEntity = JournalAudio(
          meta: _createMetadata(),
          data: AudioData(
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
            audioFile: 'test.mp3',
            audioDirectory: '/audio/',
            duration: const Duration(seconds: 30),
            transcripts: [existingTranscript],
          ),
        );

        // Create the directory structure and file
        Directory('${tempDir.path}/audio').createSync(recursive: true);
        final audioFile = File('${tempDir.path}/audio/test.mp3');
        final mockAudioBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6]);
        audioFile.writeAsBytesSync(mockAudioBytes);

        final promptConfig = _createPrompt(
          id: 'prompt-1',
          name: 'Audio Transcription',
          requiredInputData: [InputDataType.audioFiles],
          aiResponseType: AiResponseType.audioTranscription,
        );

        final model = _createModel(
          id: 'model-1',
          inferenceProviderId: 'provider-1',
          providerModelId: 'whisper-1',
        );

        final provider = _createProvider(
          id: 'provider-1',
          inferenceProviderType: InferenceProviderType.genericOpenAi,
        );

        const newTranscriptText = 'This is the new AI transcription.';

        final mockStream = Stream.fromIterable([
          CreateChatCompletionStreamResponse(
            id: 'response-1',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(
                  content: newTranscriptText,
                ),
                finishReason: ChatCompletionFinishReason.stop,
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        ]);

        when(() => mockAiInputRepo.getEntity('test-id'))
            .thenAnswer((_) async => audioEntity);
        when(() => mockAiConfigRepo.getConfigById('model-1'))
            .thenAnswer((_) async => model);
        when(() => mockAiConfigRepo.getConfigById('provider-1'))
            .thenAnswer((_) async => provider);
        when(() => mockAiInputRepo.buildTaskDetailsJson(id: 'test-id'))
            .thenAnswer((_) async => '{"audio": "test.mp3"}');

        when(
          () => mockCloudInferenceRepo.generateWithAudio(
            any(),
            model: any(named: 'model'),
            audioBase64: any(named: 'audioBase64'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
          ),
        ).thenAnswer((_) => mockStream);

        when(
          () => mockAiInputRepo.createAiResponseEntry(
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async {});

        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((_) async => true);

        try {
          await repository.runInference(
            entityId: 'test-id',
            promptConfig: promptConfig,
            onProgress: (_) {},
            onStatusChange: (_) {},
          );

          // Verify that updateJournalEntity was called with the correct data
          final captured =
              verify(() => mockJournalRepo.updateJournalEntity(captureAny()))
                  .captured;
          final updatedEntity = captured.first as JournalAudio;

          // Verify that both transcripts are present (existing + new)
          expect(updatedEntity.data.transcripts, isNotNull);
          expect(updatedEntity.data.transcripts!.length, 2);

          // Check that the existing transcript is preserved
          expect(
            updatedEntity.data.transcripts!.first.transcript,
            'Previous transcript content',
          );
          expect(
            updatedEntity.data.transcripts!.first.library,
            'Previous Transcription',
          );

          // Check that the new transcript was added
          expect(
            updatedEntity.data.transcripts!.last.transcript,
            newTranscriptText.trim(),
          );
          expect(
            updatedEntity.data.transcripts!.last.library,
            'AI Transcription',
          );

          // Verify that the entry text was updated with the new transcript
          expect(updatedEntity.entryText, isNotNull);
          expect(updatedEntity.entryText!.plainText, newTranscriptText.trim());
          expect(updatedEntity.entryText!.markdown, newTranscriptText.trim());
        } finally {
          // Clean up the temporary directory
          tempDir.deleteSync(recursive: true);
        }
      });

      test('image analysis appends to existing entry text', () async {
        final tempDir = Directory.systemTemp.createTempSync('image_test');

        // Update the mock directory to point to our temp directory
        when(() => mockDirectory.path).thenReturn(tempDir.path);

        const existingText = 'This is existing text in the image entry.';

        final imageEntity = JournalImage(
          meta: _createMetadata(),
          data: ImageData(
            capturedAt: DateTime.now(),
            imageId: 'test-image',
            imageFile: 'test.jpg',
            imageDirectory: '/images/',
          ),
          entryText: const EntryText(
            plainText: 'This is existing text in the image entry.',
            markdown: 'This is existing text in the image entry.',
          ),
        );

        // Create the directory structure and file
        Directory('${tempDir.path}/images').createSync(recursive: true);
        final imageFile = File('${tempDir.path}/images/test.jpg');
        final mockImageBytes = Uint8List.fromList([1, 2, 3, 4]);
        imageFile.writeAsBytesSync(mockImageBytes);

        final promptConfig = _createPrompt(
          id: 'prompt-1',
          name: 'Image Analysis',
          requiredInputData: [InputDataType.images],
          aiResponseType: AiResponseType.imageAnalysis,
        );

        final model = _createModel(
          id: 'model-1',
          inferenceProviderId: 'provider-1',
          providerModelId: 'gpt-4-vision',
        );

        final provider = _createProvider(
          id: 'provider-1',
          inferenceProviderType: InferenceProviderType.genericOpenAi,
        );

        const analysisText =
            'This image shows a beautiful landscape with mountains.';

        final mockStream = Stream.fromIterable([
          CreateChatCompletionStreamResponse(
            id: 'response-1',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(content: analysisText),
                finishReason: ChatCompletionFinishReason.stop,
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        ]);

        when(() => mockAiInputRepo.getEntity('test-id'))
            .thenAnswer((_) async => imageEntity);
        when(() => mockAiConfigRepo.getConfigById('model-1'))
            .thenAnswer((_) async => model);
        when(() => mockAiConfigRepo.getConfigById('provider-1'))
            .thenAnswer((_) async => provider);
        when(() => mockAiInputRepo.buildTaskDetailsJson(id: 'test-id'))
            .thenAnswer((_) async => '{"image": "test.jpg"}');

        when(
          () => mockCloudInferenceRepo.generateWithImages(
            any(),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            images: any(named: 'images'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
          ),
        ).thenAnswer((_) => mockStream);

        when(
          () => mockAiInputRepo.createAiResponseEntry(
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async {});

        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((_) async => true);

        try {
          await repository.runInference(
            entityId: 'test-id',
            promptConfig: promptConfig,
            onProgress: (_) {},
            onStatusChange: (_) {},
          );

          // Verify that updateJournalEntity was called with the correct data
          final captured =
              verify(() => mockJournalRepo.updateJournalEntity(captureAny()))
                  .captured;
          final updatedEntity = captured.first as JournalImage;

          // Verify that the entry text contains both the original text and the analysis
          expect(updatedEntity.entryText, isNotNull);
          expect(updatedEntity.entryText!.markdown, contains(existingText));
          expect(updatedEntity.entryText!.markdown, contains(analysisText));
          expect(
            updatedEntity.entryText!.markdown,
            contains('Disclaimer: the image analysis was generated by AI'),
          );

          // Verify the structure: original text + newlines + analysis
          final expectedPattern = RegExp(
            r'This is existing text.*\n\n```\nDisclaimer.*\n\n.*This image shows',
            dotAll: true,
          );
          expect(updatedEntity.entryText!.markdown, matches(expectedPattern));

          verify(
            () => mockCloudInferenceRepo.generateWithImages(
              any(),
              model: 'gpt-4-vision',
              temperature: 0.6,
              images: any(named: 'images'),
              baseUrl: 'https://api.example.com',
              apiKey: 'test-api-key',
            ),
          ).called(1);
        } finally {
          // Clean up the temporary directory
          tempDir.deleteSync(recursive: true);
        }
      });

      test('image analysis works correctly with empty entry text', () async {
        final tempDir = Directory.systemTemp.createTempSync('image_test');

        // Update the mock directory to point to our temp directory
        when(() => mockDirectory.path).thenReturn(tempDir.path);

        final imageEntity = JournalImage(
          meta: _createMetadata(),
          data: ImageData(
            capturedAt: DateTime.now(),
            imageId: 'test-image',
            imageFile: 'test.jpg',
            imageDirectory: '/images/',
          ),
          // No entryText - should be null
        );

        // Create the directory structure and file
        Directory('${tempDir.path}/images').createSync(recursive: true);
        final imageFile = File('${tempDir.path}/images/test.jpg');
        final mockImageBytes = Uint8List.fromList([1, 2, 3, 4]);
        imageFile.writeAsBytesSync(mockImageBytes);

        final promptConfig = _createPrompt(
          id: 'prompt-1',
          name: 'Image Analysis',
          requiredInputData: [InputDataType.images],
          aiResponseType: AiResponseType.imageAnalysis,
        );

        final model = _createModel(
          id: 'model-1',
          inferenceProviderId: 'provider-1',
          providerModelId: 'gpt-4-vision',
        );

        final provider = _createProvider(
          id: 'provider-1',
          inferenceProviderType: InferenceProviderType.genericOpenAi,
        );

        const analysisText =
            'This image shows a beautiful landscape with mountains.';

        final mockStream = Stream.fromIterable([
          CreateChatCompletionStreamResponse(
            id: 'response-1',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(content: analysisText),
                finishReason: ChatCompletionFinishReason.stop,
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        ]);

        when(() => mockAiInputRepo.getEntity('test-id'))
            .thenAnswer((_) async => imageEntity);
        when(() => mockAiConfigRepo.getConfigById('model-1'))
            .thenAnswer((_) async => model);
        when(() => mockAiConfigRepo.getConfigById('provider-1'))
            .thenAnswer((_) async => provider);
        when(() => mockAiInputRepo.buildTaskDetailsJson(id: 'test-id'))
            .thenAnswer((_) async => '{"image": "test.jpg"}');

        when(
          () => mockCloudInferenceRepo.generateWithImages(
            any(),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            images: any(named: 'images'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
          ),
        ).thenAnswer((_) => mockStream);

        when(
          () => mockAiInputRepo.createAiResponseEntry(
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async {});

        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((_) async => true);

        try {
          await repository.runInference(
            entityId: 'test-id',
            promptConfig: promptConfig,
            onProgress: (_) {},
            onStatusChange: (_) {},
          );

          // Verify that updateJournalEntity was called with the correct data
          final captured =
              verify(() => mockJournalRepo.updateJournalEntity(captureAny()))
                  .captured;
          final updatedEntity = captured.first as JournalImage;

          // Verify that the entry text contains only the analysis (no existing text to append to)
          expect(updatedEntity.entryText, isNotNull);
          expect(updatedEntity.entryText!.markdown, contains(analysisText));
          expect(
            updatedEntity.entryText!.markdown,
            contains('Disclaimer: the image analysis was generated by AI'),
          );

          // Should start with the disclaimer since there's no existing text
          expect(
            updatedEntity.entryText!.markdown,
            startsWith('```\nDisclaimer'),
          );
        } finally {
          // Clean up the temporary directory
          tempDir.deleteSync(recursive: true);
        }
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
  bool archived = false,
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
    archived: archived,
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
