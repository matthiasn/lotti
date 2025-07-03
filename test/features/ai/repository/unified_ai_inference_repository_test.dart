import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_data.dart';
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
import 'package:lotti/features/ai/services/auto_checklist_service.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

class MockAiConfigRepository extends Mock implements AiConfigRepository {}

class MockAiInputRepository extends Mock implements AiInputRepository {}

class MockCloudInferenceRepository extends Mock
    implements CloudInferenceRepository {}

class MockJournalRepository extends Mock implements JournalRepository {}

class MockChecklistRepository extends Mock implements ChecklistRepository {}

class MockAutoChecklistService extends Mock implements AutoChecklistService {}

class MockLoggingService extends Mock implements LoggingService {}

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
  late MockChecklistRepository mockChecklistRepo;
  late MockAutoChecklistService mockAutoChecklistService;
  late MockLoggingService mockLoggingService;
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
    mockChecklistRepo = MockChecklistRepository();
    mockAutoChecklistService = MockAutoChecklistService();
    mockLoggingService = MockLoggingService();
    mockJournalDb = MockJournalDb();
    mockDirectory = MockDirectory();

    // Set up GetIt
    if (getIt.isRegistered<JournalDb>()) {
      getIt.unregister<JournalDb>();
    }
    if (getIt.isRegistered<Directory>()) {
      getIt.unregister<Directory>();
    }
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
    getIt
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<Directory>(mockDirectory)
      ..registerSingleton<LoggingService>(mockLoggingService);

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
    when(() => mockRef.read(checklistRepositoryProvider))
        .thenReturn(mockChecklistRepo);

    repository = UnifiedAiInferenceRepository(mockRef)

      // Set up the mock auto-checklist service for testing
      ..autoChecklistServiceForTesting = mockAutoChecklistService;
  });

  tearDown(() {
    if (getIt.isRegistered<JournalDb>()) {
      getIt.unregister<JournalDb>();
    }
    if (getIt.isRegistered<Directory>()) {
      getIt.unregister<Directory>();
    }
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
  });

  group('UnifiedAiInferenceRepository', () {
    group('getActivePromptsForContext', () {
      test('returns prompts matching task entity', () async {
        final taskEntity = Task(
          meta: _createMetadata(),
          data: TaskData(
            status: TaskStatus.inProgress(
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
            status: TaskStatus.inProgress(
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
            status: TaskStatus.inProgress(
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
            status: TaskStatus.inProgress(
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

      test('returns task context prompts only when image is linked to task',
          () async {
        final imageEntity = JournalImage(
          meta: _createMetadata(),
          data: ImageData(
            capturedAt: DateTime.now(),
            imageId: 'test-image',
            imageFile: 'test.jpg',
            imageDirectory: '/images/',
          ),
        );

        final taskEntity = Task(
          meta: _createMetadata().copyWith(id: 'task-id'),
          data: TaskData(
            status: TaskStatus.inProgress(
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

        final imagePrompt = _createPrompt(
          id: 'image-prompt',
          name: 'Image Analysis',
          requiredInputData: [InputDataType.images],
          aiResponseType: AiResponseType.imageAnalysis,
        );

        final imageTaskPrompt = _createPrompt(
          id: 'image-task-prompt',
          name: 'Image Analysis with Task Context',
          requiredInputData: [InputDataType.images, InputDataType.task],
          aiResponseType: AiResponseType.imageAnalysis,
        );

        when(() => mockAiConfigRepo.getConfigsByType(AiConfigType.prompt))
            .thenAnswer((_) async => [imagePrompt, imageTaskPrompt]);

        // Test with linked task
        when(() => mockJournalRepo.getLinkedToEntities(linkedTo: 'test-id'))
            .thenAnswer((_) async => [taskEntity]);

        final resultWithTask = await repository.getActivePromptsForContext(
          entity: imageEntity,
        );

        expect(resultWithTask.length, 2);
        expect(resultWithTask.map((p) => p.id).toSet(),
            {'image-prompt', 'image-task-prompt'});

        // Test without linked task
        when(() => mockJournalRepo.getLinkedToEntities(linkedTo: 'test-id'))
            .thenAnswer((_) async => []);

        final resultWithoutTask = await repository.getActivePromptsForContext(
          entity: imageEntity,
        );

        expect(resultWithoutTask.length, 1);
        expect(resultWithoutTask.first.id, 'image-prompt');
      });

      test('returns task context prompts only when audio is linked to task',
          () async {
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

        final taskEntity = Task(
          meta: _createMetadata().copyWith(id: 'task-id'),
          data: TaskData(
            status: TaskStatus.inProgress(
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

        final audioPrompt = _createPrompt(
          id: 'audio-prompt',
          name: 'Audio Transcription',
          requiredInputData: [InputDataType.audioFiles],
          aiResponseType: AiResponseType.audioTranscription,
        );

        final audioTaskPrompt = _createPrompt(
          id: 'audio-task-prompt',
          name: 'Audio Transcription with Task Context',
          requiredInputData: [InputDataType.audioFiles, InputDataType.task],
          aiResponseType: AiResponseType.audioTranscription,
        );

        when(() => mockAiConfigRepo.getConfigsByType(AiConfigType.prompt))
            .thenAnswer((_) async => [audioPrompt, audioTaskPrompt]);

        // Test with linked task
        when(() => mockJournalRepo.getLinkedToEntities(linkedTo: 'test-id'))
            .thenAnswer((_) async => [taskEntity]);

        final resultWithTask = await repository.getActivePromptsForContext(
          entity: audioEntity,
        );

        expect(resultWithTask.length, 2);
        expect(resultWithTask.map((p) => p.id).toSet(),
            {'audio-prompt', 'audio-task-prompt'});

        // Test without linked task
        when(() => mockJournalRepo.getLinkedToEntities(linkedTo: 'test-id'))
            .thenAnswer((_) async => []);

        final resultWithoutTask = await repository.getActivePromptsForContext(
          entity: audioEntity,
        );

        expect(resultWithoutTask.length, 1);
        expect(resultWithoutTask.first.id, 'audio-prompt');
      });
    });

    group('runInference', () {
      test('successfully runs inference for text prompt', () async {
        final taskEntity = Task(
          meta: _createMetadata(),
          data: TaskData(
            status: TaskStatus.inProgress(
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
        ).thenAnswer((_) async => null);

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
        when(() => mockJournalRepo.getLinkedToEntities(linkedTo: 'test-id'))
            .thenAnswer((_) async => []); // No linked task
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
            provider: any(named: 'provider'),
          ),
        ).thenAnswer((_) => mockStream);

        when(
          () => mockAiInputRepo.createAiResponseEntry(
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => null);

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
              provider: any(named: 'provider'),
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
            provider: any(named: 'provider'),
          ),
        ).thenAnswer((_) => mockStream);

        when(
          () => mockAiInputRepo.createAiResponseEntry(
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => null);

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
              provider: any(named: 'provider'),
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
            status: TaskStatus.inProgress(
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
        ).thenAnswer((_) async => null);

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
            status: TaskStatus.inProgress(
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
        ).thenAnswer((_) async => null);

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
            status: TaskStatus.inProgress(
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
        ).thenAnswer((_) async => null);

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

      test(
          'auto-creates checklist first time, then shows manual suggestions second time',
          () async {
        final taskEntity = Task(
          meta: _createMetadata(),
          data: TaskData(
            status: TaskStatus.inProgress(
              id: 'status-1',
              createdAt: DateTime.now(),
              utcOffset: 0,
            ),
            title: 'Test Task',
            statusHistory: [],
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
            checklistIds: [], // Empty checklist IDs to trigger auto-creation
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

        final createdAiResponseEntry = AiResponseEntry(
          data: const AiResponseData(
            model: 'gpt-4',
            systemMessage: 'system',
            prompt: 'prompt',
            thoughts: '',
            response: 'response',
          ),
          meta: Metadata(
            id: 'created-ai-response-id',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
            starred: false,
            flag: EntryFlag.none,
          ),
        );

        when(() => mockAiInputRepo.getEntity('test-id'))
            .thenAnswer((_) async => taskEntity);
        when(() => mockAiConfigRepo.getConfigById('model-1'))
            .thenAnswer((_) async => model);
        when(() => mockAiConfigRepo.getConfigById('provider-1'))
            .thenAnswer((_) async => provider);
        when(() => mockAiInputRepo.buildTaskDetailsJson(id: 'test-id'))
            .thenAnswer((_) async => '{"task": "Test Task"}');

        // Mock the JournalDb for AutoChecklistService.shouldAutoCreate
        when(() => mockJournalDb.journalEntityById('test-id'))
            .thenAnswer((_) async => taskEntity);

        // Mock for fallback path when aiResponseEntry is null
        when(() => mockJournalRepo.getLinkedEntities(linkedTo: 'test-id'))
            .thenAnswer((_) async => [createdAiResponseEntry]);

        // Mock different responses for first run vs re-run
        var callCount = 0;
        when(
          () => mockCloudInferenceRepo.generate(
            any(),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            systemMessage: any(named: 'systemMessage'),
          ),
        ).thenAnswer((_) {
          callCount++;
          if (callCount == 1) {
            // First call: return suggestions
            return Stream.fromIterable([
              CreateChatCompletionStreamResponse(
                id: 'response-1',
                choices: [
                  const ChatCompletionStreamResponseChoice(
                    delta: ChatCompletionStreamResponseDelta(
                      content:
                          '[{"title": "Review code", "completed": false}, {"title": "Write tests", "completed": true}]',
                    ),
                    index: 0,
                  ),
                ],
                object: 'chat.completion.chunk',
                created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              ),
            ]);
          } else {
            // Second call (re-run): return empty suggestions
            return Stream.fromIterable([
              CreateChatCompletionStreamResponse(
                id: 'response-2',
                choices: [
                  const ChatCompletionStreamResponseChoice(
                    delta: ChatCompletionStreamResponseDelta(
                      content: '[]', // Empty suggestions on re-run
                    ),
                    index: 0,
                  ),
                ],
                object: 'chat.completion.chunk',
                created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              ),
            ]);
          }
        });

        when(
          () => mockAiInputRepo.createAiResponseEntry(
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => createdAiResponseEntry);

        // Mock auto-checklist service
        when(() => mockAutoChecklistService.shouldAutoCreate(taskId: 'test-id'))
            .thenAnswer((_) async => true);
        when(() => mockAutoChecklistService.autoCreateChecklist(
                  taskId: 'test-id',
                  suggestions: any(named: 'suggestions'),
                  shouldAutoCreate: any(named: 'shouldAutoCreate'),
                ))
            .thenAnswer((_) async =>
                (success: true, checklistId: 'checklist-123', error: null));

        // Mock for re-run: getConfigsByType should return the prompt for re-run lookup
        when(() => mockAiConfigRepo.getConfigsByType(AiConfigType.prompt))
            .thenAnswer((_) async => [promptConfig]);

        // Mock checklist repository for auto-creation
        // Task has no existing checklists, so shouldAutoCreate will return true
        when(() => mockChecklistRepo.createChecklist(
              taskId: 'test-id',
              items: any(named: 'items'),
              title: any(named: 'title'),
            )).thenAnswer((_) async => JournalEntity.checklist(
              meta: _createMetadata(),
              data: const ChecklistData(
                title: 'AI Suggestions',
                linkedChecklistItems: [],
                linkedTasks: ['test-id'],
              ),
            ));

        // Inject the mock AutoChecklistService for this test
        repository.autoChecklistServiceForTesting = mockAutoChecklistService;

        // Act
        await repository.runInference(
          entityId: 'test-id',
          promptConfig: promptConfig,
          onProgress: (_) {},
          onStatusChange: (_) {},
        );

        // Assert
        // Verify that autoChecklistService.autoCreateChecklist is called once
        verify(() => mockAutoChecklistService.autoCreateChecklist(
              taskId: 'test-id',
              suggestions: any(named: 'suggestions'),
              shouldAutoCreate: any(named: 'shouldAutoCreate'),
            )).called(1);

        // Verify that cloud inference is called twice (initial run + re-run)
        verify(() => mockCloudInferenceRepo.generate(
              any(),
              model: any(named: 'model'),
              temperature: any(named: 'temperature'),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              systemMessage: any(named: 'systemMessage'),
            )).called(2);

        // Verify that createAiResponseEntry is called twice (initial + re-run)
        final capturedData = verify(() => mockAiInputRepo.createAiResponseEntry(
              data: captureAny(named: 'data'),
              start: any(named: 'start'),
              linkedId: any(named: 'linkedId'),
              categoryId: any(named: 'categoryId'),
            )).captured;

        expect(capturedData.length, equals(2));

        // First call should have suggestions
        final firstCallData = capturedData[0] as AiResponseData;
        expect(firstCallData.suggestedActionItems, isNotNull);
        expect(firstCallData.suggestedActionItems!.length, equals(2));
        expect(firstCallData.suggestedActionItems![0].title,
            equals('Review code'));
        expect(firstCallData.suggestedActionItems![1].title,
            equals('Write tests'));

        // Second call (re-run) should have empty suggestions
        final secondCallData = capturedData[1] as AiResponseData;
        expect(secondCallData.suggestedActionItems, isNotNull);
        expect(secondCallData.suggestedActionItems!.length, equals(0));
      });

      test('handles provider not found error', () async {
        final taskEntity = Task(
          meta: _createMetadata(),
          data: TaskData(
            status: TaskStatus.inProgress(
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
            status: TaskStatus.inProgress(
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
            status: TaskStatus.inProgress(
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
        ).thenAnswer((_) async => null);

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
            status: TaskStatus.inProgress(
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

      test('handles task title update error during post-processing', () async {
        final taskEntity = Task(
          meta: _createMetadata(),
          data: TaskData(
            status: TaskStatus.inProgress(
              id: 'status-1',
              createdAt: DateTime.now(),
              utcOffset: 0,
            ),
            title: 'TODO', // Short title that should be replaced
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

        const responseWithTitle = '''
# Implement user authentication system

Some task summary content...''';

        final mockStream = Stream.fromIterable([
          CreateChatCompletionStreamResponse(
            id: 'response-1',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(
                    content: responseWithTitle),
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
            .thenAnswer((_) async => '{"task": "TODO"}');

        when(
          () => mockCloudInferenceRepo.generate(
            any(),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            systemMessage: any(named: 'systemMessage'),
            maxCompletionTokens: any(named: 'maxCompletionTokens'),
          ),
        ).thenAnswer((_) => mockStream);

        when(
          () => mockAiInputRepo.createAiResponseEntry(
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => null);

        // Mock the journal repository to throw an exception when updating the task
        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenThrow(Exception('Database update failed'));

        final statusChanges = <InferenceStatus>[];

        // Should not throw even though title update fails
        await repository.runInference(
          entityId: 'test-id',
          promptConfig: promptConfig,
          onProgress: (_) {},
          onStatusChange: statusChanges.add,
        );

        // Verify that the inference still completes successfully
        expect(statusChanges, [InferenceStatus.running, InferenceStatus.idle]);

        // Verify that updateJournalEntity was called (and failed)
        verify(() => mockJournalRepo.updateJournalEntity(any())).called(1);
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
            provider: any(named: 'provider'),
          ),
        ).thenAnswer((_) => mockStream);

        when(
          () => mockAiInputRepo.createAiResponseEntry(
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => null);

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
            'Test Provider',
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
              provider: any(named: 'provider'),
            ),
          ).called(1);

          // updateJournalEntity verification is already done via the captured call above
        } finally {
          // Clean up the temporary directory
          tempDir.deleteSync(recursive: true);
        }
      });

      test('task summary extracts title and updates task when title is short',
          () async {
        final taskEntity = Task(
          meta: _createMetadata(),
          data: TaskData(
            status: TaskStatus.inProgress(
              id: 'status-1',
              createdAt: DateTime.now(),
              utcOffset: 0,
            ),
            title: 'TODO', // Short title that should be replaced
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

        const responseWithTitle = '''
# Implement user authentication system

Achieved results:
✅ Set up database schema for users
✅ Created login API endpoint

Remaining steps:
1. Implement password reset functionality
2. Add session management
3. Create user profile page''';

        final mockStream = Stream.fromIterable([
          CreateChatCompletionStreamResponse(
            id: 'response-1',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(
                    content: responseWithTitle),
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
            .thenAnswer((_) async => '{"task": "TODO"}');

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
        ).thenAnswer((_) async => null);

        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((_) async => true);

        await repository.runInference(
          entityId: 'test-id',
          promptConfig: promptConfig,
          onProgress: (_) {},
          onStatusChange: (_) {},
        );

        // Verify that updateJournalEntity was called with updated title
        final captured =
            verify(() => mockJournalRepo.updateJournalEntity(captureAny()))
                .captured;
        final updatedEntity = captured.first as Task;

        expect(
            updatedEntity.data.title, 'Implement user authentication system');
      });

      test(
          'task summary does not update title when existing title is long enough',
          () async {
        final taskEntity = Task(
          meta: _createMetadata(),
          data: TaskData(
            status: TaskStatus.inProgress(
              id: 'status-1',
              createdAt: DateTime.now(),
              utcOffset: 0,
            ),
            title: 'This is an existing task with a good title',
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

        const responseWithTitle = '''
# Better task title from AI

Achieved results:
✅ Task already has a good title''';

        final mockStream = Stream.fromIterable([
          CreateChatCompletionStreamResponse(
            id: 'response-1',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(
                    content: responseWithTitle),
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
        ).thenAnswer((_) async => null);

        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((_) async => true);

        await repository.runInference(
          entityId: 'test-id',
          promptConfig: promptConfig,
          onProgress: (_) {},
          onStatusChange: (_) {},
        );

        // Verify that updateJournalEntity was NOT called
        verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
      });

      test('task summary handles response without title gracefully', () async {
        final taskEntity = Task(
          meta: _createMetadata(),
          data: TaskData(
            status: TaskStatus.inProgress(
              id: 'status-1',
              createdAt: DateTime.now(),
              utcOffset: 0,
            ),
            title: 'TODO',
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

        const responseWithoutTitle = '''
Achieved results:
✅ Some work done

Remaining steps:
1. More work to do''';

        final mockStream = Stream.fromIterable([
          CreateChatCompletionStreamResponse(
            id: 'response-1',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(
                    content: responseWithoutTitle),
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
            .thenAnswer((_) async => '{"task": "TODO"}');

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
        ).thenAnswer((_) async => null);

        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((_) async => true);

        await repository.runInference(
          entityId: 'test-id',
          promptConfig: promptConfig,
          onProgress: (_) {},
          onStatusChange: (_) {},
        );

        // Verify that updateJournalEntity was NOT called since no title was found
        verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
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
            provider: any(named: 'provider'),
          ),
        ).thenAnswer((_) => mockStream);

        when(
          () => mockAiInputRepo.createAiResponseEntry(
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => null);

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
            'Test Provider',
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
        when(() => mockJournalRepo.getLinkedToEntities(linkedTo: 'test-id'))
            .thenAnswer((_) async => []); // No linked task
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
            provider: any(named: 'provider'),
          ),
        ).thenAnswer((_) => mockStream);

        when(
          () => mockAiInputRepo.createAiResponseEntry(
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => null);

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
            isNot(contains('Disclaimer')), // No disclaimer anymore
          );

          // Verify the structure: original text + newlines + analysis
          const expectedText = '$existingText\n\n$analysisText';
          expect(updatedEntity.entryText!.markdown, equals(expectedText));

          verify(
            () => mockCloudInferenceRepo.generateWithImages(
              any(),
              model: 'gpt-4-vision',
              temperature: 0.6,
              images: any(named: 'images'),
              baseUrl: 'https://api.example.com',
              apiKey: 'test-api-key',
              provider: any(named: 'provider'),
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
        when(() => mockJournalRepo.getLinkedToEntities(linkedTo: 'test-id'))
            .thenAnswer((_) async => []); // No linked task
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
            provider: any(named: 'provider'),
          ),
        ).thenAnswer((_) => mockStream);

        when(
          () => mockAiInputRepo.createAiResponseEntry(
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => null);

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
          expect(updatedEntity.entryText!.markdown, equals(analysisText));
          expect(
            updatedEntity.entryText!.markdown,
            isNot(contains('Disclaimer')), // No disclaimer anymore
          );
        } finally {
          // Clean up the temporary directory
          tempDir.deleteSync(recursive: true);
        }
      });
    });

    group('AI response entry creation', () {
      test('should not create AI response entry for JournalAudio entities',
          () async {
        // Set up test data
        final promptConfig = _createPrompt(
          id: 'audio-prompt',
          name: 'Audio Transcription',
          requiredInputData: [InputDataType.audioFiles],
          aiResponseType: AiResponseType.audioTranscription,
        );

        final model = _createModel(
          id: 'model-1',
          inferenceProviderId: 'provider-1',
          providerModelId: 'test-model',
        );

        final provider = _createProvider(
          id: 'provider-1',
          inferenceProviderType: InferenceProviderType.openAi,
        );

        final tempDir = Directory.systemTemp.createTempSync('audio_test');
        when(() => mockDirectory.path).thenReturn(tempDir.path);

        // Create the audio directory and file
        Directory('${tempDir.path}/audio').createSync(recursive: true);
        final audioFile = File('${tempDir.path}/audio/test.mp3');
        final mockAudioBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6]);
        audioFile.writeAsBytesSync(mockAudioBytes);

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

        // Set up mocks
        when(() => mockAiInputRepo.getEntity('test-id'))
            .thenAnswer((_) async => audioEntity);
        when(() => mockAiConfigRepo.getConfigById('model-1'))
            .thenAnswer((_) async => model);
        when(() => mockAiConfigRepo.getConfigById('provider-1'))
            .thenAnswer((_) async => provider);
        when(() => mockAiInputRepo.buildTaskDetailsJson(id: 'test-id'))
            .thenAnswer((_) async => '{"audio": "test.mp3"}');

        final mockStream = Stream.fromIterable([
          CreateChatCompletionStreamResponse(
            id: 'response-1',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(
                    content: 'Transcribed text'),
                finishReason: ChatCompletionFinishReason.stop,
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        ]);
        when(
          () => mockCloudInferenceRepo.generateWithAudio(
            any(),
            model: any(named: 'model'),
            audioBase64: any(named: 'audioBase64'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            provider: any(named: 'provider'),
          ),
        ).thenAnswer((_) => mockStream);

        when(
          () => mockAiInputRepo.createAiResponseEntry(
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => null);

        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((_) async => true);

        try {
          // Run inference
          await repository.runInference(
            entityId: 'test-id',
            promptConfig: promptConfig,
            onProgress: (_) {},
            onStatusChange: (_) {},
          );

          // Verify that createAiResponseEntry was NOT called for JournalAudio
          verifyNever(
            () => mockAiInputRepo.createAiResponseEntry(
              data: any(named: 'data'),
              start: any(named: 'start'),
              linkedId: any(named: 'linkedId'),
              categoryId: any(named: 'categoryId'),
            ),
          );

          // Verify that the journal entity was still updated with the transcript
          verify(() => mockJournalRepo.updateJournalEntity(any())).called(1);
        } finally {
          tempDir.deleteSync(recursive: true);
        }
      });

      test('should create AI response entry for non-JournalAudio entities',
          () async {
        // Set up test data with a Task entity (non-JournalAudio)
        final promptConfig = _createPrompt(
          id: 'task-prompt',
          name: 'Task Analysis',
          requiredInputData: [InputDataType.task],
        );

        final model = _createModel(
          id: 'model-1',
          inferenceProviderId: 'provider-1',
          providerModelId: 'test-model',
        );

        final provider = _createProvider(
          id: 'provider-1',
          inferenceProviderType: InferenceProviderType.openAi,
        );

        final taskEntity = Task(
          meta: _createMetadata(),
          data: TaskData(
            status: TaskStatus.open(
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

        // Set up mocks
        when(() => mockAiInputRepo.getEntity('test-id'))
            .thenAnswer((_) async => taskEntity);
        when(() => mockAiConfigRepo.getConfigById('model-1'))
            .thenAnswer((_) async => model);
        when(() => mockAiConfigRepo.getConfigById('provider-1'))
            .thenAnswer((_) async => provider);
        when(() => mockAiInputRepo.buildTaskDetailsJson(id: 'test-id'))
            .thenAnswer((_) async => '{"task": "Test Task"}');

        final mockStream = Stream.fromIterable([
          CreateChatCompletionStreamResponse(
            id: 'response-1',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(
                    content: 'Task analysis result'),
                finishReason: ChatCompletionFinishReason.stop,
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        ]);
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
        ).thenAnswer((_) async => null);

        // Run inference
        await repository.runInference(
          entityId: 'test-id',
          promptConfig: promptConfig,
          onProgress: (_) {},
          onStatusChange: (_) {},
        );

        // Verify that createAiResponseEntry WAS called for non-JournalAudio entity
        verify(
          () => mockAiInputRepo.createAiResponseEntry(
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: 'test-id',
            categoryId: any(named: 'categoryId'),
          ),
        ).called(1);

        // For taskSummary type, the journal entity is not updated directly
        // Only specific response types like audioTranscription update the entity
      });

      test('image analysis uses task context when linked to a task', () async {
        // Create a temporary directory for the test
        final tempDir = Directory.systemTemp.createTempSync('image_task_test');

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

        final taskEntity = Task(
          meta: _createMetadata().copyWith(id: 'task-id'),
          data: TaskData(
            status: TaskStatus.inProgress(
              id: 'status-1',
              createdAt: DateTime.now(),
              utcOffset: 0,
            ),
            title: 'Database Migration Task',
            statusHistory: [],
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
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
        ).copyWith(
          userMessage: '''
Analyze the provided image(s) in the context of this task:

**Task Context:**
```json
{{task}}
```

Extract ONLY information from the image that is relevant to this task. Be concise and focus on task-related content.

If the image is NOT relevant to the task:
- Provide a brief 1-2 sentence summary explaining why it's off-topic
- Use a slightly humorous or salty tone if appropriate
- Example: "This appears to be a photo of ducks by a lake, which seems unrelated to your database migration task. Moving on..."

If the image IS relevant:
- Extract key information that helps with the task
- Be direct and concise
- Focus on actionable insights or important details''',
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
                delta: ChatCompletionStreamResponseDelta(
                  content:
                      'This appears to be a photo of ducks by a lake, which seems unrelated to your database migration task. Moving on...',
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
            .thenAnswer((_) async => imageEntity);
        when(() => mockAiConfigRepo.getConfigById('model-1'))
            .thenAnswer((_) async => model);
        when(() => mockAiConfigRepo.getConfigById('provider-1'))
            .thenAnswer((_) async => provider);
        when(() => mockJournalRepo.getLinkedToEntities(linkedTo: 'test-id'))
            .thenAnswer((_) async => [taskEntity]);
        when(() =>
            mockAiInputRepo.buildTaskDetailsJson(
                id: 'task-id')).thenAnswer((_) async =>
            '{"title": "Database Migration Task", "status": "IN PROGRESS"}');

        when(
          () => mockCloudInferenceRepo.generateWithImages(
            any(),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            images: any(named: 'images'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            provider: any(named: 'provider'),
          ),
        ).thenAnswer((_) => mockStream);

        when(
          () => mockAiInputRepo.createAiResponseEntry(
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => null);

        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((_) async => true);

        try {
          await repository.runInference(
            entityId: 'test-id',
            promptConfig: promptConfig,
            onProgress: progressUpdates.add,
            onStatusChange: statusChanges.add,
          );

          expect(progressUpdates, [
            'This appears to be a photo of ducks by a lake, which seems unrelated to your database migration task. Moving on...',
          ]);
          expect(
            statusChanges,
            [InferenceStatus.running, InferenceStatus.idle],
          );

          // Verify the prompt was built with task context
          final captured = verify(
            () => mockCloudInferenceRepo.generateWithImages(
              captureAny(),
              model: 'gpt-4-vision',
              temperature: 0.6,
              images: any(named: 'images'),
              baseUrl: 'https://api.example.com',
              apiKey: 'test-api-key',
              provider: any(named: 'provider'),
            ),
          ).captured;

          final capturedPrompt = captured.first as String;
          expect(capturedPrompt, contains('Database Migration Task'));
          expect(capturedPrompt, contains('"status": "IN PROGRESS"'));

          // Verify that the image entity was updated without disclaimer
          final updateCaptured = verify(
            () => mockJournalRepo.updateJournalEntity(captureAny()),
          ).captured;

          final updatedEntity = updateCaptured.first as JournalImage;
          expect(
              updatedEntity.entryText?.markdown, isNot(contains('Disclaimer')));
          expect(
              updatedEntity.entryText?.markdown, contains('ducks by a lake'));
        } finally {
          // Clean up the temporary directory
          tempDir.deleteSync(recursive: true);
        }
      });

      test('image analysis uses generic prompt when not linked to a task',
          () async {
        // Create a temporary directory for the test
        final tempDir =
            Directory.systemTemp.createTempSync('image_generic_test');

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
        ).copyWith(
          userMessage: '''
Analyze the provided image(s) in the context of this task:

**Task Context:**
```json
{{task}}
```

Extract ONLY information from the image that is relevant to this task. Be concise and focus on task-related content.''',
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

        final mockStream = Stream.fromIterable([
          CreateChatCompletionStreamResponse(
            id: 'response-1',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(
                  content: 'The image shows a cat sitting on a windowsill.',
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
            .thenAnswer((_) async => imageEntity);
        when(() => mockAiConfigRepo.getConfigById('model-1'))
            .thenAnswer((_) async => model);
        when(() => mockAiConfigRepo.getConfigById('provider-1'))
            .thenAnswer((_) async => provider);
        when(() => mockJournalRepo.getLinkedToEntities(linkedTo: 'test-id'))
            .thenAnswer((_) async => []); // No linked entities

        when(
          () => mockCloudInferenceRepo.generateWithImages(
            any(),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            images: any(named: 'images'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            provider: any(named: 'provider'),
          ),
        ).thenAnswer((_) => mockStream);

        when(
          () => mockAiInputRepo.createAiResponseEntry(
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => null);

        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((_) async => true);

        try {
          await repository.runInference(
            entityId: 'test-id',
            promptConfig: promptConfig,
            onProgress: (_) {},
            onStatusChange: (_) {},
          );

          // Verify the prompt was built without task context
          final captured = verify(
            () => mockCloudInferenceRepo.generateWithImages(
              captureAny(),
              model: 'gpt-4-vision',
              temperature: 0.6,
              images: any(named: 'images'),
              baseUrl: 'https://api.example.com',
              apiKey: 'test-api-key',
              provider: any(named: 'provider'),
            ),
          ).captured;

          final capturedPrompt = captured.first as String;
          // When no task is linked, the prompt should keep the {{task}} placeholder
          expect(capturedPrompt, contains('{{task}}'));
          expect(capturedPrompt, contains('Task Context'));
        } finally {
          // Clean up the temporary directory
          tempDir.deleteSync(recursive: true);
        }
      });

      test('audio transcription uses task context when linked to a task',
          () async {
        // Create a temporary directory for the test
        final tempDir = Directory.systemTemp.createTempSync('audio_task_test');

        // Update the mock directory to point to our temp directory
        when(() => mockDirectory.path).thenReturn(tempDir.path);

        final audioEntity = JournalAudio(
          meta: _createMetadata(),
          data: AudioData(
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
            audioDirectory: '/audio/',
            audioFile: 'test.wav',
            duration: const Duration(seconds: 30),
          ),
        );

        final taskEntity = Task(
          meta: _createMetadata().copyWith(id: 'task-id'),
          data: TaskData(
            status: TaskStatus.inProgress(
              id: 'status-1',
              createdAt: DateTime.now(),
              utcOffset: 0,
            ),
            title: 'Interview with John Smith',
            statusHistory: [],
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
          ),
        );

        // Create the directory structure and file
        Directory('${tempDir.path}/audio').createSync(recursive: true);
        final audioFile = File('${tempDir.path}/audio/test.wav');
        final mockAudioBytes = Uint8List.fromList([1, 2, 3, 4]);
        audioFile.writeAsBytesSync(mockAudioBytes);

        final promptConfig = _createPrompt(
          id: 'prompt-1',
          name: 'Audio Transcription with Task Context',
          requiredInputData: [InputDataType.audioFiles],
          aiResponseType: AiResponseType.audioTranscription,
        ).copyWith(
          userMessage: '''
Please transcribe the provided audio. 
Format the transcription clearly with proper punctuation and paragraph breaks where appropriate. 
If there are multiple speakers, try to indicate speaker changes. 
Note any significant non-speech audio events [in brackets]. Remove filler words.

Take into account the following task context:

**Task Context:**
```json
{{task}}
```

The task context will provide additional information about the task, such as the project, 
goal, and any relevant details such as names of people or places. If in doubt 
about names or concepts mentioned in the audio, then the task context should
be consulted to ensure accuracy.''',
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
                delta: ChatCompletionStreamResponseDelta(
                  content:
                      'John Smith: Thank you for having me. Let me tell you about our latest project.',
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
        when(() => mockJournalRepo.getLinkedToEntities(linkedTo: 'test-id'))
            .thenAnswer((_) async => [taskEntity]);
        when(() =>
            mockAiInputRepo.buildTaskDetailsJson(
                id: 'task-id')).thenAnswer((_) async =>
            '{"title": "Interview with John Smith", "status": "IN PROGRESS"}');

        when(
          () => mockCloudInferenceRepo.generateWithAudio(
            any(),
            model: any(named: 'model'),
            audioBase64: any(named: 'audioBase64'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            provider: any(named: 'provider'),
          ),
        ).thenAnswer((_) => mockStream);

        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((_) async => true);

        try {
          await repository.runInference(
            entityId: 'test-id',
            promptConfig: promptConfig,
            onProgress: progressUpdates.add,
            onStatusChange: statusChanges.add,
          );

          expect(progressUpdates, [
            'John Smith: Thank you for having me. Let me tell you about our latest project.',
          ]);
          expect(
            statusChanges,
            [InferenceStatus.running, InferenceStatus.idle],
          );

          // Verify the prompt was built with task context
          final captured = verify(
            () => mockCloudInferenceRepo.generateWithAudio(
              captureAny(),
              model: 'whisper-1',
              audioBase64: any(named: 'audioBase64'),
              baseUrl: 'https://api.example.com',
              apiKey: 'test-api-key',
              provider: any(named: 'provider'),
            ),
          ).captured;

          final capturedPrompt = captured.first as String;
          expect(capturedPrompt, contains('Interview with John Smith'));
          expect(capturedPrompt, contains('"status": "IN PROGRESS"'));
          expect(capturedPrompt, isNot(contains('{{task}}')));
        } finally {
          // Clean up the temporary directory
          tempDir.deleteSync(recursive: true);
        }
      });

      test('audio transcription keeps placeholder when not linked to a task',
          () async {
        // Create a temporary directory for the test
        final tempDir =
            Directory.systemTemp.createTempSync('audio_no_task_test');

        // Update the mock directory to point to our temp directory
        when(() => mockDirectory.path).thenReturn(tempDir.path);

        final audioEntity = JournalAudio(
          meta: _createMetadata(),
          data: AudioData(
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
            audioDirectory: '/audio/',
            audioFile: 'test.wav',
            duration: const Duration(seconds: 30),
          ),
        );

        // Create the directory structure and file
        Directory('${tempDir.path}/audio').createSync(recursive: true);
        final audioFile = File('${tempDir.path}/audio/test.wav');
        final mockAudioBytes = Uint8List.fromList([1, 2, 3, 4]);
        audioFile.writeAsBytesSync(mockAudioBytes);

        final promptConfig = _createPrompt(
          id: 'prompt-1',
          name: 'Audio Transcription with Task Context',
          requiredInputData: [InputDataType.audioFiles],
          aiResponseType: AiResponseType.audioTranscription,
        ).copyWith(
          userMessage: '''
Please transcribe the provided audio.

Take into account the following task context:

**Task Context:**
```json
{{task}}
```''',
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

        final mockStream = Stream.fromIterable([
          CreateChatCompletionStreamResponse(
            id: 'response-1',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(
                  content: 'This is the transcribed audio content.',
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
        when(() => mockJournalRepo.getLinkedToEntities(linkedTo: 'test-id'))
            .thenAnswer((_) async => []); // No linked entities

        when(
          () => mockCloudInferenceRepo.generateWithAudio(
            any(),
            model: any(named: 'model'),
            audioBase64: any(named: 'audioBase64'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            provider: any(named: 'provider'),
          ),
        ).thenAnswer((_) => mockStream);

        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((_) async => true);

        try {
          await repository.runInference(
            entityId: 'test-id',
            promptConfig: promptConfig,
            onProgress: (_) {},
            onStatusChange: (_) {},
          );

          // Verify the prompt was built without task context replacement
          final captured = verify(
            () => mockCloudInferenceRepo.generateWithAudio(
              captureAny(),
              model: 'whisper-1',
              audioBase64: any(named: 'audioBase64'),
              baseUrl: 'https://api.example.com',
              apiKey: 'test-api-key',
              provider: any(named: 'provider'),
            ),
          ).captured;

          final capturedPrompt = captured.first as String;
          // When no task is linked, the prompt should keep the {{task}} placeholder
          expect(capturedPrompt, contains('{{task}}'));
          expect(capturedPrompt, contains('Task Context'));
        } finally {
          // Clean up the temporary directory
          tempDir.deleteSync(recursive: true);
        }
      });
    });
  });

  group('_rerunActionItemSuggestions', () {
    test('re-runs with same prompt after auto-checklist creation', () async {
      final taskEntity = Task(
        meta: _createMetadata(),
        data: TaskData(
          status: TaskStatus.inProgress(
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

      // This test verifies that the re-run uses the same prompt
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

      final mockStream = Stream.fromIterable([
        CreateChatCompletionStreamResponse(
          id: 'response-1',
          choices: [
            const ChatCompletionStreamResponseChoice(
              delta: ChatCompletionStreamResponseDelta(
                content: '[{"title": "Review code", "completed": false}]',
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
          .thenAnswer((_) async => taskEntity.copyWith(
                data: taskEntity.data.copyWith(checklistIds: []),
              ));
      when(() => mockAiConfigRepo.getConfigById('model-1'))
          .thenAnswer((_) async => model);
      when(() => mockAiConfigRepo.getConfigById('provider-1'))
          .thenAnswer((_) async => provider);
      when(() => mockAiInputRepo.buildTaskDetailsJson(id: 'test-id'))
          .thenAnswer((_) async => '{"task": "Test Task"}');
      when(() => mockJournalDb.journalEntityById('test-id'))
          .thenAnswer((_) async => taskEntity.copyWith(
                data: taskEntity.data.copyWith(checklistIds: []),
              ));

      when(() => mockCloudInferenceRepo.generate(
            any(),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            systemMessage: any(named: 'systemMessage'),
          )).thenAnswer((_) => mockStream);

      when(() => mockAiInputRepo.createAiResponseEntry(
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          )).thenAnswer((_) async => null);

      // Mock auto-checklist service
      when(() => mockAutoChecklistService.shouldAutoCreate(taskId: 'test-id'))
          .thenAnswer((_) async => true);
      when(() => mockAutoChecklistService.autoCreateChecklist(
                taskId: 'test-id',
                suggestions: any(named: 'suggestions'),
                shouldAutoCreate: any(named: 'shouldAutoCreate'),
              ))
          .thenAnswer((_) async =>
              (success: true, checklistId: 'checklist-123', error: null));

      repository.autoChecklistServiceForTesting = mockAutoChecklistService;

      await repository.runInference(
        entityId: 'test-id',
        promptConfig: promptConfig,
        onProgress: (_) {},
        onStatusChange: (_) {},
      );

      // Verify that the cloud inference was called twice (initial run + re-run)
      // This confirms the re-run happened with the same prompt
      verify(() => mockCloudInferenceRepo.generate(
            any(),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            systemMessage: any(named: 'systemMessage'),
          )).called(2);
    });

    test('handles exception during re-run gracefully', () async {
      final taskEntity = Task(
        meta: _createMetadata(),
        data: TaskData(
          status: TaskStatus.inProgress(
            id: 'status-1',
            createdAt: DateTime.now(),
            utcOffset: 0,
          ),
          title: 'Test Task',
          statusHistory: [],
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
          checklistIds: [], // Empty to trigger auto-creation
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

      final mockStream = Stream.fromIterable([
        CreateChatCompletionStreamResponse(
          id: 'response-1',
          choices: [
            const ChatCompletionStreamResponseChoice(
              delta: ChatCompletionStreamResponseDelta(
                content: '[{"title": "Review code", "completed": false}]',
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
      when(() => mockJournalDb.journalEntityById('test-id'))
          .thenAnswer((_) async => taskEntity);

      when(() => mockCloudInferenceRepo.generate(
            any(),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            systemMessage: any(named: 'systemMessage'),
          )).thenAnswer((_) => mockStream);

      when(() => mockAiInputRepo.createAiResponseEntry(
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          )).thenAnswer((_) async => null);

      // Mock auto-checklist service
      when(() => mockAutoChecklistService.shouldAutoCreate(taskId: 'test-id'))
          .thenAnswer((_) async => true);
      when(() => mockAutoChecklistService.autoCreateChecklist(
                taskId: 'test-id',
                suggestions: any(named: 'suggestions'),
                shouldAutoCreate: any(named: 'shouldAutoCreate'),
              ))
          .thenAnswer((_) async =>
              (success: true, checklistId: 'checklist-123', error: null));

      // Mock successful prompt lookup but exception during re-run
      final actionItemPrompt = _createPrompt(
        id: 'action-prompt',
        name: 'Action Item Suggestions',
        requiredInputData: [InputDataType.task],
        aiResponseType: AiResponseType.actionItemSuggestions,
      );
      when(() => mockAiConfigRepo.getConfigsByType(AiConfigType.prompt))
          .thenAnswer((_) async => [actionItemPrompt]);

      repository.autoChecklistServiceForTesting = mockAutoChecklistService;

      // Should not throw exception even if re-run fails
      await repository.runInference(
        entityId: 'test-id',
        promptConfig: promptConfig,
        onProgress: (_) {},
        onStatusChange: (_) {},
      );

      // Verify that auto-checklist creation was attempted
      verify(() => mockAutoChecklistService.autoCreateChecklist(
            taskId: 'test-id',
            suggestions: any(named: 'suggestions'),
            shouldAutoCreate: any(named: 'shouldAutoCreate'),
          )).called(1);
    });
  });

  group('Concurrent modification protection', () {
    late Task initialTask;
    late Task updatedTask;
    late AiConfigPrompt taskSummaryPrompt;
    late AiConfigPrompt actionItemsPrompt;
    late AiConfigModel model;
    late AiConfigInferenceProvider provider;

    setUp(() {
      initialTask = Task(
        meta: _createMetadata(),
        data: TaskData(
          status: TaskStatus.inProgress(
            id: 'status-1',
            createdAt: DateTime.now(),
            utcOffset: 0,
          ),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now().add(const Duration(hours: 1)),
          statusHistory: [],
          title: 'Old', // Short title to trigger AI update
        ),
      );

      updatedTask = Task(
        meta: _createMetadata(),
        data: TaskData(
          status: TaskStatus.inProgress(
            id: 'status-1',
            createdAt: DateTime.now(),
            utcOffset: 0,
          ),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now().add(const Duration(hours: 1)),
          statusHistory: [],
          title: 'Updated by user during AI processing',
          checklistIds: ['checklist-1'], // User added checklist
        ),
      );

      taskSummaryPrompt = _createPrompt(
        id: 'summary-prompt',
        name: 'Task Summary',
        requiredInputData: [InputDataType.task],
      );

      actionItemsPrompt = _createPrompt(
        id: 'action-items-prompt',
        name: 'Action Items',
        aiResponseType: AiResponseType.actionItemSuggestions,
        requiredInputData: [InputDataType.task],
      );

      model = _createModel(
        id: 'model-1',
        inferenceProviderId: 'provider-1',
        providerModelId: 'test-model',
      );

      provider = _createProvider(
        id: 'provider-1',
        inferenceProviderType: InferenceProviderType.openAi,
      );
    });

    test('task summary uses current task state, not captured state', () async {
      // Setup: AI captures initial task state
      when(() => mockAiInputRepo.getEntity('test-id'))
          .thenAnswer((_) async => initialTask);

      when(() => mockAiConfigRepo.getConfigById('summary-prompt'))
          .thenAnswer((_) async => taskSummaryPrompt);

      when(() => mockAiConfigRepo.getConfigById('model-1'))
          .thenAnswer((_) async => model);

      when(() => mockAiConfigRepo.getConfigById('provider-1'))
          .thenAnswer((_) async => provider);

      when(() => mockAiInputRepo.buildTaskDetailsJson(id: 'test-id'))
          .thenAnswer((_) async => '{"title": "Old", "status": "IN PROGRESS"}');

      // Setup: During AI processing, user updates task
      var getEntityCallCount = 0;
      when(() => mockAiInputRepo.getEntity('test-id')).thenAnswer((_) async {
        getEntityCallCount++;
        if (getEntityCallCount == 1) {
          return initialTask; // First call - initial capture
        } else {
          return updatedTask; // Second call - current state in post-processing
        }
      });

      when(() => mockJournalRepo.updateJournalEntity(any()))
          .thenAnswer((_) async => true);

      final mockStream = Stream.fromIterable([
        _createStreamChunk('# Better Task Title\n\nThis is a good summary.'),
      ]);

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
      ).thenAnswer((_) async => null);

      // Execute: Run AI inference
      await repository.runInference(
        entityId: 'test-id',
        promptConfig: taskSummaryPrompt,
        onProgress: (_) {},
        onStatusChange: (_) {},
      );

      // Verify: Should get current entity state twice (initial + post-processing)
      verify(() => mockAiInputRepo.getEntity('test-id')).called(2);

      // Verify: Should not update title because current task has long title
      verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
    });

    test('action item suggestions uses current task state for auto-creation',
        () async {
      // Setup: Initial task has no checklists
      when(() => mockAiInputRepo.getEntity('test-id'))
          .thenAnswer((_) async => initialTask);

      when(() => mockAiConfigRepo.getConfigById('action-items-prompt'))
          .thenAnswer((_) async => actionItemsPrompt);

      when(() => mockAiConfigRepo.getConfigById('model-1'))
          .thenAnswer((_) async => model);

      when(() => mockAiConfigRepo.getConfigById('provider-1'))
          .thenAnswer((_) async => provider);

      when(() => mockAiInputRepo.buildTaskDetailsJson(id: 'test-id'))
          .thenAnswer((_) async => '{"title": "Old", "actionItems": []}');

      // Setup: Current task state has checklist added by user
      var getEntityCallCount = 0;
      when(() => mockAiInputRepo.getEntity('test-id')).thenAnswer((_) async {
        getEntityCallCount++;
        if (getEntityCallCount == 1) {
          return initialTask; // First call - initial capture
        } else {
          return updatedTask; // Second call - current state in post-processing
        }
      });

      // Setup: Auto-checklist service should work with current task
      when(() => mockAutoChecklistService.shouldAutoCreate(taskId: 'test-id'))
          .thenAnswer((_) async => false); // Task already has checklists

      final mockStream = Stream.fromIterable([
        _createStreamChunk('[{"title": "Do something", "completed": false}]'),
      ]);

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
      ).thenAnswer((_) async => null);

      // Set the mock auto checklist service
      repository.autoChecklistServiceForTesting = mockAutoChecklistService;

      // Execute: Run AI inference
      await repository.runInference(
        entityId: 'test-id',
        promptConfig: actionItemsPrompt,
        onProgress: (_) {},
        onStatusChange: (_) {},
      );

      // Verify: Should check auto-creation with current task ID
      verify(() => mockAutoChecklistService.shouldAutoCreate(taskId: 'test-id'))
          .called(1);

      // Verify: Should not auto-create since current task has checklists
      verifyNever(() => mockAutoChecklistService.autoCreateChecklist(
            taskId: any(named: 'taskId'),
            suggestions: any(named: 'suggestions'),
            shouldAutoCreate: any(named: 'shouldAutoCreate'),
          ));
    });

    test('handles entity not found during post-processing gracefully',
        () async {
      // Setup: Initial task exists
      when(() => mockAiInputRepo.getEntity('test-id'))
          .thenAnswer((_) async => initialTask);

      when(() => mockAiConfigRepo.getConfigById('summary-prompt'))
          .thenAnswer((_) async => taskSummaryPrompt);

      when(() => mockAiConfigRepo.getConfigById('model-1'))
          .thenAnswer((_) async => model);

      when(() => mockAiConfigRepo.getConfigById('provider-1'))
          .thenAnswer((_) async => provider);

      when(() => mockAiInputRepo.buildTaskDetailsJson(id: 'test-id'))
          .thenAnswer((_) async => '{"title": "Old"}');

      // Setup: Entity gets deleted during AI processing
      var getEntityCallCount = 0;
      when(() => mockAiInputRepo.getEntity('test-id')).thenAnswer((_) async {
        getEntityCallCount++;
        if (getEntityCallCount == 1) {
          return initialTask; // First call - initial capture
        } else {
          return null; // Second call - entity deleted
        }
      });

      final mockStream = Stream.fromIterable([
        _createStreamChunk('# Better Task Title\n\nThis is a good summary.'),
      ]);

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
      ).thenAnswer((_) async => null);

      // Execute: Should not throw when entity is deleted
      await repository.runInference(
        entityId: 'test-id',
        promptConfig: taskSummaryPrompt,
        onProgress: (_) {},
        onStatusChange: (_) {},
      );

      // Verify: Should attempt to get current entity but not crash
      verify(() => mockAiInputRepo.getEntity('test-id')).called(2);

      // Verify: Should not attempt to update non-existent entity
      verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
    });

    test('handles getEntity error during post-processing gracefully', () async {
      // Setup: Initial task exists
      when(() => mockAiInputRepo.getEntity('test-id'))
          .thenAnswer((_) async => initialTask);

      when(() => mockAiConfigRepo.getConfigById('summary-prompt'))
          .thenAnswer((_) async => taskSummaryPrompt);

      when(() => mockAiConfigRepo.getConfigById('model-1'))
          .thenAnswer((_) async => model);

      when(() => mockAiConfigRepo.getConfigById('provider-1'))
          .thenAnswer((_) async => provider);

      when(() => mockAiInputRepo.buildTaskDetailsJson(id: 'test-id'))
          .thenAnswer((_) async => '{"title": "Old"}');

      // Setup: Error occurs when getting current entity state
      var getEntityCallCount = 0;
      when(() => mockAiInputRepo.getEntity('test-id')).thenAnswer((_) async {
        getEntityCallCount++;
        if (getEntityCallCount == 1) {
          return initialTask; // First call - initial capture
        } else {
          throw Exception('Database error'); // Second call - error
        }
      });

      final mockStream = Stream.fromIterable([
        _createStreamChunk('# Better Task Title\n\nThis is a good summary.'),
      ]);

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
      ).thenAnswer((_) async => null);

      // Execute: Should not throw when getEntity fails
      await repository.runInference(
        entityId: 'test-id',
        promptConfig: taskSummaryPrompt,
        onProgress: (_) {},
        onStatusChange: (_) {},
      );

      // Verify: Should attempt to get current entity but handle error gracefully
      verify(() => mockAiInputRepo.getEntity('test-id')).called(2);

      // Verify: Should not attempt to update when error occurs
      verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
    });

    test('handles action item suggestions when current entity is not a task',
        () async {
      final taskEntity = Task(
        meta: _createMetadata(),
        data: TaskData(
          status: TaskStatus.inProgress(
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

      // Create a different entity type to simulate corruption/race condition
      final nonTaskEntity = JournalImage(
        meta: _createMetadata(),
        data: ImageData(
          capturedAt: DateTime.now(),
          imageId: 'test-image',
          imageFile: 'test.jpg',
          imageDirectory: '/images/',
        ),
      );

      final promptConfig = _createPrompt(
        id: 'action-items-prompt',
        name: 'Action Items',
        aiResponseType: AiResponseType.actionItemSuggestions,
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

      const actionItemsResponse = '''
[
  {"completed": false, "title": "Review requirements"},
  {"completed": false, "title": "Create test plan"}
]''';

      final mockStream = Stream.fromIterable([
        CreateChatCompletionStreamResponse(
          id: 'response-1',
          choices: [
            const ChatCompletionStreamResponseChoice(
              delta: ChatCompletionStreamResponseDelta(
                  content: actionItemsResponse),
              finishReason: ChatCompletionFinishReason.stop,
              index: 0,
            ),
          ],
          object: 'chat.completion.chunk',
          created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        ),
      ]);

      // Setup: First call returns task, second call returns non-task entity
      var getEntityCallCount = 0;
      when(() => mockAiInputRepo.getEntity('test-id')).thenAnswer((_) async {
        getEntityCallCount++;
        if (getEntityCallCount == 1) {
          return taskEntity; // First call - initial capture
        } else {
          return nonTaskEntity; // Second call - corrupted/changed entity type
        }
      });

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
          maxCompletionTokens: any(named: 'maxCompletionTokens'),
        ),
      ).thenAnswer((_) => mockStream);

      when(
        () => mockAiInputRepo.createAiResponseEntry(
          data: any(named: 'data'),
          start: any(named: 'start'),
          linkedId: any(named: 'linkedId'),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer((_) async => null);

      // Should not throw even when entity type changes
      await repository.runInference(
        entityId: 'test-id',
        promptConfig: promptConfig,
        onProgress: (_) {},
        onStatusChange: (_) {},
      );

      // Verify that entity was checked twice (initial and current state)
      verify(() => mockAiInputRepo.getEntity('test-id')).called(2);

      // Verify that auto-checklist service was never called since entity type changed
      verifyNever(() => mockAutoChecklistService.shouldAutoCreate(
          taskId: any(named: 'taskId')));
      verifyNever(() => mockAutoChecklistService.autoCreateChecklist(
            taskId: any(named: 'taskId'),
            suggestions: any(named: 'suggestions'),
            shouldAutoCreate: any(named: 'shouldAutoCreate'),
          ));
    });

    test('handles auto-checklist creation failure gracefully', () async {
      final taskEntity = Task(
        meta: _createMetadata(),
        data: TaskData(
          status: TaskStatus.inProgress(
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
        id: 'action-items-prompt',
        name: 'Action Items',
        aiResponseType: AiResponseType.actionItemSuggestions,
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

      const actionItemsResponse = '''
[
  {"completed": false, "title": "Review requirements"},
  {"completed": false, "title": "Create test plan"}
]''';

      final mockStream = Stream.fromIterable([
        CreateChatCompletionStreamResponse(
          id: 'response-1',
          choices: [
            const ChatCompletionStreamResponseChoice(
              delta: ChatCompletionStreamResponseDelta(
                  content: actionItemsResponse),
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
          maxCompletionTokens: any(named: 'maxCompletionTokens'),
        ),
      ).thenAnswer((_) => mockStream);

      when(
        () => mockAiInputRepo.createAiResponseEntry(
          data: any(named: 'data'),
          start: any(named: 'start'),
          linkedId: any(named: 'linkedId'),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer((_) async => null);

      // Mock auto-checklist service to return failure
      when(() => mockAutoChecklistService.shouldAutoCreate(
          taskId: any(named: 'taskId'))).thenAnswer((_) async => true);
      when(() => mockAutoChecklistService.autoCreateChecklist(
            taskId: any(named: 'taskId'),
            suggestions: any(named: 'suggestions'),
            shouldAutoCreate: any(named: 'shouldAutoCreate'),
          )).thenAnswer((_) async => (
            success: false,
            checklistId: null,
            error: 'Failed to create checklist',
          ));

      // Should not throw even when auto-checklist creation fails
      await repository.runInference(
        entityId: 'test-id',
        promptConfig: promptConfig,
        onProgress: (_) {},
        onStatusChange: (_) {},
      );

      // Verify that auto-checklist creation was attempted
      verify(() => mockAutoChecklistService.shouldAutoCreate(taskId: 'test-id'))
          .called(1);
      verify(() => mockAutoChecklistService.autoCreateChecklist(
            taskId: 'test-id',
            suggestions: any(named: 'suggestions'),
            shouldAutoCreate: true,
          )).called(1);

      // Verify that re-run was NOT attempted since creation failed
      verify(() => mockAiInputRepo.getEntity('test-id')).called(
          2); // Initial call + current state check in action item processing
    });

    test('handles exception in action item suggestions processing', () async {
      final taskEntity = Task(
        meta: _createMetadata(),
        data: TaskData(
          status: TaskStatus.inProgress(
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
        id: 'action-items-prompt',
        name: 'Action Items',
        aiResponseType: AiResponseType.actionItemSuggestions,
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

      const actionItemsResponse = '''
[
  {"completed": false, "title": "Review requirements"},
  {"completed": false, "title": "Create test plan"}
]''';

      final mockStream = Stream.fromIterable([
        CreateChatCompletionStreamResponse(
          id: 'response-1',
          choices: [
            const ChatCompletionStreamResponseChoice(
              delta: ChatCompletionStreamResponseDelta(
                  content: actionItemsResponse),
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
          maxCompletionTokens: any(named: 'maxCompletionTokens'),
        ),
      ).thenAnswer((_) => mockStream);

      when(
        () => mockAiInputRepo.createAiResponseEntry(
          data: any(named: 'data'),
          start: any(named: 'start'),
          linkedId: any(named: 'linkedId'),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer((_) async => null);

      // Mock auto-checklist service to throw an exception
      when(() => mockAutoChecklistService.shouldAutoCreate(
              taskId: any(named: 'taskId')))
          .thenThrow(Exception('Auto-checklist service error'));

      // Should not throw even when auto-checklist service throws exception
      await repository.runInference(
        entityId: 'test-id',
        promptConfig: promptConfig,
        onProgress: (_) {},
        onStatusChange: (_) {},
      );

      // Verify that shouldAutoCreate was called and threw exception
      verify(() => mockAutoChecklistService.shouldAutoCreate(taskId: 'test-id'))
          .called(1);

      // Verify that autoCreateChecklist was never called due to exception
      verifyNever(() => mockAutoChecklistService.autoCreateChecklist(
            taskId: any(named: 'taskId'),
            suggestions: any(named: 'suggestions'),
            shouldAutoCreate: any(named: 'shouldAutoCreate'),
          ));
    });
  });

  group('Concurrent Safety Tests', () {
    test('runInference calls getEntity to retrieve entity', () async {
      // Setup
      final task = Task(
        meta: _createMetadata(),
        data: TaskData(
          status: TaskStatus.inProgress(
            id: 'status-1',
            createdAt: DateTime.now(),
            utcOffset: 0,
          ),
          title: 'Test Task',
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
          statusHistory: [],
        ),
      );

      final prompt = _createPrompt(
        id: 'test-prompt',
        name: 'Test Prompt',
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

      when(() => mockAiInputRepo.getEntity('test-id'))
          .thenAnswer((_) async => task);

      when(() => mockAiConfigRepo.getConfigById('test-prompt'))
          .thenAnswer((_) async => prompt);

      when(() => mockAiConfigRepo.getConfigById('model-1'))
          .thenAnswer((_) async => model);

      when(() => mockAiConfigRepo.getConfigById('provider-1'))
          .thenAnswer((_) async => provider);

      when(() => mockCloudInferenceRepo.generate(
            any(),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            systemMessage: any(named: 'systemMessage'),
            maxCompletionTokens: any(named: 'maxCompletionTokens'),
          )).thenAnswer((_) => Stream.value(
            CreateChatCompletionStreamResponse(
              id: 'test-id',
              created: DateTime.now().millisecondsSinceEpoch,
              choices: [
                const ChatCompletionStreamResponseChoice(
                  index: 0,
                  delta: ChatCompletionStreamResponseDelta(
                    content: 'Test response',
                  ),
                ),
              ],
            ),
          ));

      when(() => mockAiInputRepo.createAiResponseEntry(
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          )).thenAnswer((_) async => null);

      final repository = UnifiedAiInferenceRepository(mockRef);

      // Act - Run inference which should call getEntity
      await repository.runInference(
        entityId: 'test-id',
        promptConfig: prompt,
        onProgress: (_) {},
        onStatusChange: (_) {},
      );

      // Assert - Verify that getEntity was called
      // It may be called twice: once in runInference and potentially once in _getCurrentEntityState
      // depending on the aiResponseType
      verify(() => mockAiInputRepo.getEntity('test-id'))
          .called(greaterThanOrEqualTo(1));
    });

    test('image analysis handles entity not found during post-processing',
        () async {
      // Create temporary directory for the test
      final tempDir = Directory.systemTemp.createTempSync('image_test');

      // Update the mock directory to point to our temp directory
      when(() => mockDirectory.path).thenReturn(tempDir.path);

      try {
        // Create the directory structure
        Directory('${tempDir.path}/images').createSync();

        // Create the image file
        File('${tempDir.path}/images/test-image.jpg')
            .writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0]); // JPEG header

        const imageId = 'test-image-id';
        final image = JournalImage(
          meta: Metadata(
            id: imageId,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
          ),
          data: ImageData(
            capturedAt: DateTime.now(),
            imageId: 'test-image-id',
            imageFile: 'test-image.jpg',
            imageDirectory: '/images/',
          ),
        );

        final promptConfig = _createPrompt(
          id: 'image-prompt',
          name: 'Image Analysis',
          aiResponseType: AiResponseType.imageAnalysis,
          requiredInputData: [InputDataType.images],
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

        // Setup: entity found first time, null second time (during post-processing)
        var getEntityCallCount = 0;
        when(() => mockAiInputRepo.getEntity(imageId)).thenAnswer((_) async {
          getEntityCallCount++;
          return getEntityCallCount == 1 ? image : null;
        });

        when(() => mockAiConfigRepo.getConfigById('image-prompt'))
            .thenAnswer((_) async => promptConfig);

        when(() => mockAiConfigRepo.getConfigById('model-1'))
            .thenAnswer((_) async => model);

        when(() => mockAiConfigRepo.getConfigById('provider-1'))
            .thenAnswer((_) async => provider);

        when(() => mockAiInputRepo.buildTaskDetailsJson(id: imageId))
            .thenAnswer((_) async => '{}');

        when(() => mockJournalRepo.getLinkedToEntities(
                linkedTo: any(named: 'linkedTo')))
            .thenAnswer((_) async => <JournalEntity>[]);

        final mockStream = Stream.fromIterable([
          _createStreamChunk('This is an image of a sunset'),
        ]);

        when(
          () => mockCloudInferenceRepo.generateWithImages(
            any(),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            images: any(named: 'images'),
            provider: any(named: 'provider'),
          ),
        ).thenAnswer((_) => mockStream);

        when(
          () => mockAiInputRepo.createAiResponseEntry(
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => null);

        // Execute
        await repository.runInference(
          entityId: imageId,
          promptConfig: promptConfig,
          onProgress: (_) {},
          onStatusChange: (_) {},
        );

        // Verify: updateJournalEntity should NOT be called since entity was not found
        verifyNever(() => mockJournalRepo.updateJournalEntity(any()));

        // Verify: getEntity was called twice (initial + post-processing)
        verify(() => mockAiInputRepo.getEntity(imageId)).called(2);
      } finally {
        // Clean up the temporary directory
        tempDir.deleteSync(recursive: true);
      }
    });

    test('audio transcription handles entity type change during processing',
        () async {
      // Create temporary directory for the test
      final tempDir = Directory.systemTemp.createTempSync('audio_test');

      // Update the mock directory to point to our temp directory
      when(() => mockDirectory.path).thenReturn(tempDir.path);

      try {
        // Create the directory structure
        Directory('${tempDir.path}/audio').createSync();

        // Create the audio file
        File('${tempDir.path}/audio/test-audio.wav')
            .writeAsBytesSync([1, 2, 3, 4, 5, 6]);

        const audioId = 'test-audio-id';
        final audio = JournalAudio(
          meta: Metadata(
            id: audioId,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
          ),
          data: AudioData(
            dateFrom: DateTime.now(),
            dateTo: DateTime.now().add(const Duration(minutes: 5)),
            audioFile: 'test-audio.wav',
            audioDirectory: '/audio/',
            duration: const Duration(minutes: 5),
          ),
        );

        // Create a different entity type with same ID
        final journalEntry = JournalEntity.journalEntry(
          meta: Metadata(
            id: audioId,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
          ),
          entryText: const EntryText(plainText: 'This is now a journal entry'),
        );

        final promptConfig = _createPrompt(
          id: 'audio-prompt',
          name: 'Audio Transcription',
          aiResponseType: AiResponseType.audioTranscription,
          requiredInputData: [InputDataType.audioFiles],
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

        // Setup: audio found first time, journal entry second time (type change)
        var getEntityCallCount = 0;
        when(() => mockAiInputRepo.getEntity(audioId)).thenAnswer((_) async {
          getEntityCallCount++;
          return getEntityCallCount == 1 ? audio : journalEntry;
        });

        when(() => mockAiConfigRepo.getConfigById('audio-prompt'))
            .thenAnswer((_) async => promptConfig);

        when(() => mockAiConfigRepo.getConfigById('model-1'))
            .thenAnswer((_) async => model);

        when(() => mockAiConfigRepo.getConfigById('provider-1'))
            .thenAnswer((_) async => provider);

        when(() => mockAiInputRepo.buildTaskDetailsJson(id: audioId))
            .thenAnswer((_) async => '{}');

        when(() => mockJournalRepo.getLinkedToEntities(
                linkedTo: any(named: 'linkedTo')))
            .thenAnswer((_) async => <JournalEntity>[]);

        final mockStream = Stream.fromIterable([
          _createStreamChunk('This is the transcribed audio content'),
        ]);

        when(
          () => mockCloudInferenceRepo.generateWithAudio(
            any(),
            model: any(named: 'model'),
            audioBase64: any(named: 'audioBase64'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            provider: any(named: 'provider'),
          ),
        ).thenAnswer((_) => mockStream);

        when(
          () => mockAiInputRepo.createAiResponseEntry(
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => null);

        // Execute
        await repository.runInference(
          entityId: audioId,
          promptConfig: promptConfig,
          onProgress: (_) {},
          onStatusChange: (_) {},
        );

        // Verify: updateJournalEntity should NOT be called since entity type changed
        verifyNever(() => mockJournalRepo.updateJournalEntity(any()));

        // Verify: getEntity was called twice (initial + post-processing)
        verify(() => mockAiInputRepo.getEntity(audioId)).called(2);
      } finally {
        // Clean up the temporary directory
        tempDir.deleteSync(recursive: true);
      }
    });

    test('image analysis with concurrent text update preserves user changes',
        () async {
      // Create temporary directory for the test
      final tempDir = Directory.systemTemp.createTempSync('image_test');

      // Update the mock directory to point to our temp directory
      when(() => mockDirectory.path).thenReturn(tempDir.path);

      try {
        // Create the directory structure
        Directory('${tempDir.path}/images').createSync();

        // Create the image file
        File('${tempDir.path}/images/test-image.jpg')
            .writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0]); // JPEG header

        const imageId = 'test-image-id';
        final originalImage = JournalImage(
          meta: Metadata(
            id: imageId,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
          ),
          data: ImageData(
            capturedAt: DateTime.now(),
            imageId: 'test-image-id',
            imageFile: 'test-image.jpg',
            imageDirectory: '/images/',
          ),
        );

        // User updates image with text during AI processing
        final updatedImage = JournalImage(
          meta: originalImage.meta,
          data: originalImage.data,
          entryText: const EntryText(
            plainText: 'User added this description',
            markdown: 'User added this description',
          ),
        );

        final promptConfig = _createPrompt(
          id: 'image-prompt',
          name: 'Image Analysis',
          aiResponseType: AiResponseType.imageAnalysis,
          requiredInputData: [InputDataType.images],
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

        // Setup: original image first time, updated image second time
        var getEntityCallCount = 0;
        when(() => mockAiInputRepo.getEntity(imageId)).thenAnswer((_) async {
          getEntityCallCount++;
          return getEntityCallCount == 1 ? originalImage : updatedImage;
        });

        when(() => mockAiConfigRepo.getConfigById('image-prompt'))
            .thenAnswer((_) async => promptConfig);

        when(() => mockAiConfigRepo.getConfigById('model-1'))
            .thenAnswer((_) async => model);

        when(() => mockAiConfigRepo.getConfigById('provider-1'))
            .thenAnswer((_) async => provider);

        when(() => mockAiInputRepo.buildTaskDetailsJson(id: imageId))
            .thenAnswer((_) async => '{}');

        when(() => mockJournalRepo.getLinkedToEntities(
                linkedTo: any(named: 'linkedTo')))
            .thenAnswer((_) async => <JournalEntity>[]);

        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((_) async => true);

        final mockStream = Stream.fromIterable([
          _createStreamChunk('AI analysis: Beautiful sunset'),
        ]);

        when(
          () => mockCloudInferenceRepo.generateWithImages(
            any(),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            images: any(named: 'images'),
            provider: any(named: 'provider'),
          ),
        ).thenAnswer((_) => mockStream);

        when(
          () => mockAiInputRepo.createAiResponseEntry(
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => null);

        // Execute
        await repository.runInference(
          entityId: imageId,
          promptConfig: promptConfig,
          onProgress: (_) {},
          onStatusChange: (_) {},
        );

        // Verify: updateJournalEntity was called with appended text
        final capturedEntity = verify(
          () => mockJournalRepo.updateJournalEntity(captureAny()),
        ).captured.single as JournalImage;

        // Should append AI analysis to user's text
        expect(capturedEntity.entryText?.plainText,
            'User added this description\n\nAI analysis: Beautiful sunset');

        // Verify: getEntity was called twice (initial + post-processing)
        verify(() => mockAiInputRepo.getEntity(imageId)).called(2);
      } finally {
        // Clean up the temporary directory
        tempDir.deleteSync(recursive: true);
      }
    });

    test('audio transcription error handling preserves entity integrity',
        () async {
      // Create temporary directory for the test
      final tempDir = Directory.systemTemp.createTempSync('audio_test');

      // Update the mock directory to point to our temp directory
      when(() => mockDirectory.path).thenReturn(tempDir.path);

      try {
        // Create the directory structure
        Directory('${tempDir.path}/audio').createSync();

        // Create the audio file
        File('${tempDir.path}/audio/test-audio.wav')
            .writeAsBytesSync([1, 2, 3, 4, 5, 6]);

        const audioId = 'test-audio-id';
        final audio = JournalAudio(
          meta: Metadata(
            id: audioId,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
          ),
          data: AudioData(
            dateFrom: DateTime.now(),
            dateTo: DateTime.now().add(const Duration(minutes: 5)),
            audioFile: 'test-audio.wav',
            audioDirectory: '/audio/',
            duration: const Duration(minutes: 5),
          ),
        );

        final promptConfig = _createPrompt(
          id: 'audio-prompt',
          name: 'Audio Transcription',
          aiResponseType: AiResponseType.audioTranscription,
          requiredInputData: [InputDataType.audioFiles],
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

        // Setup: getEntity throws error during post-processing
        var getEntityCallCount = 0;
        when(() => mockAiInputRepo.getEntity(audioId)).thenAnswer((_) async {
          getEntityCallCount++;
          if (getEntityCallCount == 1) {
            return audio;
          } else {
            throw Exception('Database error');
          }
        });

        when(() => mockAiConfigRepo.getConfigById('audio-prompt'))
            .thenAnswer((_) async => promptConfig);

        when(() => mockAiConfigRepo.getConfigById('model-1'))
            .thenAnswer((_) async => model);

        when(() => mockAiConfigRepo.getConfigById('provider-1'))
            .thenAnswer((_) async => provider);

        when(() => mockAiInputRepo.buildTaskDetailsJson(id: audioId))
            .thenAnswer((_) async => '{}');

        when(() => mockJournalRepo.getLinkedToEntities(
                linkedTo: any(named: 'linkedTo')))
            .thenAnswer((_) async => <JournalEntity>[]);

        final mockStream = Stream.fromIterable([
          _createStreamChunk('Transcribed content'),
        ]);

        when(
          () => mockCloudInferenceRepo.generateWithAudio(
            any(),
            model: any(named: 'model'),
            audioBase64: any(named: 'audioBase64'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            provider: any(named: 'provider'),
          ),
        ).thenAnswer((_) => mockStream);

        when(
          () => mockAiInputRepo.createAiResponseEntry(
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => null);

        // Execute - should complete without throwing
        await repository.runInference(
          entityId: audioId,
          promptConfig: promptConfig,
          onProgress: (_) {},
          onStatusChange: (_) {},
        );

        // Verify: updateJournalEntity should NOT be called due to error
        verifyNever(() => mockJournalRepo.updateJournalEntity(any()));

        // Verify: getEntity was called twice (initial + attempted post-processing)
        verify(() => mockAiInputRepo.getEntity(audioId)).called(2);
      } finally {
        // Clean up the temporary directory
        tempDir.deleteSync(recursive: true);
      }
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

CreateChatCompletionStreamResponse _createStreamChunk(String content) {
  return CreateChatCompletionStreamResponse(
    id: 'test-completion-id',
    choices: [
      ChatCompletionStreamResponseChoice(
        index: 0,
        delta: ChatCompletionStreamResponseDelta(content: content),
      ),
    ],
    created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    model: 'test-model',
    object: 'chat.completion.chunk',
  );
}
