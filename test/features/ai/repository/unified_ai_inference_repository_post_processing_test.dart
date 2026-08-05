// ignore_for_file: avoid_redundant_argument_values

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/unified_ai_inference_repository.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../mocks/mocks.dart';
import '../test_utils.dart';
import 'unified_ai_inference_repository_test_helpers.dart';

final harness = UnifiedAiInferenceRepositoryTestHarness();

UnifiedAiInferenceRepository? get repository => harness.repository;
set repository(UnifiedAiInferenceRepository? value) =>
    harness.repository = value;
ProviderContainer get container => harness.container;
MockAiConfigRepository get mockAiConfigRepo => harness.mockAiConfigRepo;
MockAiInputRepository get mockAiInputRepo => harness.mockAiInputRepo;
MockCloudInferenceRepository get mockCloudInferenceRepo =>
    harness.mockCloudInferenceRepo;
MockJournalRepository get mockJournalRepo => harness.mockJournalRepo;
MockChecklistRepository get mockChecklistRepo => harness.mockChecklistRepo;
MockAutoChecklistService get mockAutoChecklistService =>
    harness.mockAutoChecklistService;
MockLoggingService get mockLoggingService => harness.mockLoggingService;
MockJournalDb get mockJournalDb => harness.mockJournalDb;
MockDirectory get mockDirectory => harness.mockDirectory;
MockCategoryRepository get mockCategoryRepo => harness.mockCategoryRepo;
MockPromptCapabilityFilter get mockPromptCapabilityFilter =>
    harness.mockPromptCapabilityFilter;
MockLabelsRepository get mockLabelsRepository => harness.mockLabelsRepository;
TestChecklistCompletionService get testChecklistCompletionService =>
    harness.testChecklistCompletionService;
Directory? get baseTempDir => harness.baseTempDir;
List<Directory> get overrideTempDirs => harness.overrideTempDirs;

void main() {
  setUpAll(harness.setUpAll);
  setUp(harness.setUp);
  tearDown(harness.tearDown);
  tearDownAll(harness.tearDownAll);

  group('UnifiedAiInferenceRepository', () {
    group('AI response entry creation', () {
      test(
        'should not create AI response entry for JournalAudio entities',
        () async {
          // Set up test data
          final promptConfig = createPrompt(
            id: 'audio-prompt',
            name: 'Audio Transcription',
            requiredInputData: [InputDataType.audioFiles],
            aiResponseType: AiResponseType.audioTranscription,
          );

          final model = createModel(
            id: 'model-1',
            inferenceProviderId: 'provider-1',
            providerModelId: 'test-model',
          );

          final provider = createProvider(
            id: 'provider-1',
            inferenceProviderType: InferenceProviderType.openAi,
          );

          final tempDir = Directory.systemTemp.createTempSync('audio_test');
          overrideTempDirs.add(tempDir);
          when(() => mockDirectory.path).thenReturn(tempDir.path);

          // Create the audio directory and file
          Directory('${tempDir.path}/audio').createSync(recursive: true);
          final audioFile = File('${tempDir.path}/audio/test.mp3');
          final mockAudioBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6]);
          audioFile.writeAsBytesSync(mockAudioBytes);

          final audioEntity = JournalAudio(
            meta: createMetadata(),
            data: AudioData(
              dateFrom: DateTime(2024, 3, 15, 10, 30),
              dateTo: DateTime(2024, 3, 15, 10, 30),
              audioFile: 'test.mp3',
              audioDirectory: '/audio/',
              duration: const Duration(seconds: 30),
            ),
          );

          // Set up mocks
          when(
            () => mockAiInputRepo.getEntity('test-id'),
          ).thenAnswer((_) async => audioEntity);
          when(
            () => mockAiConfigRepo.getConfigById('model-1'),
          ).thenAnswer((_) async => model);
          when(
            () => mockAiConfigRepo.getConfigById('provider-1'),
          ).thenAnswer((_) async => provider);
          when(
            () => mockAiInputRepo.buildTaskDetailsJson(id: 'test-id'),
          ).thenAnswer((_) async => '{"audio": "test.mp3"}');

          final mockStream = Stream.fromIterable([
            CreateChatCompletionStreamResponse(
              id: 'response-1',
              choices: [
                const ChatCompletionStreamResponseChoice(
                  delta: ChatCompletionStreamResponseDelta(
                    content: 'Transcribed text',
                  ),
                  finishReason: ChatCompletionFinishReason.stop,
                  index: 0,
                ),
              ],
              object: 'chat.completion.chunk',
              created:
                  DateTime(2024, 3, 15, 10, 30).millisecondsSinceEpoch ~/ 1000,
            ),
          ]);
          stubGenerateWithAudio(mockCloudInferenceRepo, stream: mockStream);

          stubCreateAiResponseEntry(mockAiInputRepo);

          when(
            () => mockJournalRepo.updateJournalEntity(any()),
          ).thenAnswer((_) async => true);

          // Mock getLinkedToEntities to return empty list (no linked tasks)
          when(
            () => mockJournalRepo.getLinkedToEntities(linkedTo: 'test-id'),
          ).thenAnswer((_) async => []);

          try {
            // Run inference
            await repository!.runInference(
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
        },
      );

      test(
        'should create AI response entry for non-JournalAudio entities',
        () async {
          // Set up test data with a Task entity (non-JournalAudio)
          final promptConfig = createPrompt(
            id: 'task-prompt',
            name: 'Task Analysis',
            requiredInputData: [InputDataType.task],
          );

          final model = createModel(
            id: 'model-1',
            inferenceProviderId: 'provider-1',
            providerModelId: 'test-model',
          );

          final provider = createProvider(
            id: 'provider-1',
            inferenceProviderType: InferenceProviderType.openAi,
          );

          final taskEntity = Task(
            meta: createMetadata(),
            data: TaskData(
              status: TaskStatus.open(
                id: 'status-1',
                createdAt: DateTime(2024, 3, 15, 10, 30),
                utcOffset: 0,
              ),
              title: 'Test Task',
              statusHistory: [],
              dateFrom: DateTime(2024, 3, 15, 10, 30),
              dateTo: DateTime(2024, 3, 15, 10, 30),
            ),
          );

          // Set up mocks
          when(
            () => mockAiInputRepo.getEntity('test-id'),
          ).thenAnswer((_) async => taskEntity);
          when(
            () => mockAiConfigRepo.getConfigById('model-1'),
          ).thenAnswer((_) async => model);
          when(
            () => mockAiConfigRepo.getConfigById('provider-1'),
          ).thenAnswer((_) async => provider);
          when(
            () => mockAiInputRepo.buildTaskDetailsJson(id: 'test-id'),
          ).thenAnswer((_) async => '{"task": "Test Task"}');

          final mockStream = Stream.fromIterable([
            CreateChatCompletionStreamResponse(
              id: 'response-1',
              choices: [
                const ChatCompletionStreamResponseChoice(
                  delta: ChatCompletionStreamResponseDelta(
                    content: 'Task analysis result',
                  ),
                  finishReason: ChatCompletionFinishReason.stop,
                  index: 0,
                ),
              ],
              object: 'chat.completion.chunk',
              created:
                  DateTime(2024, 3, 15, 10, 30).millisecondsSinceEpoch ~/ 1000,
            ),
          ]);
          stubGenerate(mockCloudInferenceRepo, stream: mockStream);

          stubCreateAiResponseEntry(mockAiInputRepo);

          // Run inference
          await repository!.runInference(
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
        },
      );

      test('image analysis uses task context when linked to a task', () async {
        // Create a temporary directory for the test
        final tempDir = Directory.systemTemp.createTempSync('image_task_test');
        overrideTempDirs.add(tempDir);

        // Update the mock directory to point to our temp directory
        when(() => mockDirectory.path).thenReturn(tempDir.path);

        final imageEntity = JournalImage(
          meta: createMetadata().copyWith(id: 'test-id'),
          data: ImageData(
            capturedAt: DateTime(2024, 3, 15, 10, 30),
            imageId: 'test-image',
            imageFile: 'test.jpg',
            imageDirectory: '/images/',
          ),
        );

        final taskEntity = Task(
          meta: createMetadata().copyWith(id: 'task-id'),
          data: TaskData(
            status: TaskStatus.inProgress(
              id: 'status-1',
              createdAt: DateTime(2024, 3, 15, 10, 30),
              utcOffset: 0,
            ),
            title: 'Database Migration Task',
            statusHistory: [],
            dateFrom: DateTime(2024, 3, 15, 10, 30),
            dateTo: DateTime(2024, 3, 15, 10, 30),
          ),
        );

        // Create the directory structure and file
        Directory('${tempDir.path}/images').createSync(recursive: true);
        final imageFile = File('${tempDir.path}/images/test.jpg');
        final mockImageBytes = Uint8List.fromList([1, 2, 3, 4]);
        imageFile.writeAsBytesSync(mockImageBytes);

        final promptConfig =
            createPrompt(
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

        final model = createModel(
          id: 'model-1',
          inferenceProviderId: 'provider-1',
          providerModelId: 'gpt-4-vision',
        );

        final provider = createProvider(
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
            created:
                DateTime(2024, 3, 15, 10, 30).millisecondsSinceEpoch ~/ 1000,
          ),
        ]);

        when(
          () => mockAiInputRepo.getEntity('test-id'),
        ).thenAnswer((_) async => imageEntity);
        when(
          () => mockAiConfigRepo.getConfigById('model-1'),
        ).thenAnswer((_) async => model);
        when(
          () => mockAiConfigRepo.getConfigById('provider-1'),
        ).thenAnswer((_) async => provider);
        when(
          () => mockJournalRepo.getLinkedToEntities(linkedTo: 'test-id'),
        ).thenAnswer((_) async => [taskEntity]);
        when(
          () => mockAiInputRepo.buildTaskDetailsJson(id: 'task-id'),
        ).thenAnswer(
          (_) async =>
              '{"title": "Database Migration Task", "status": "IN PROGRESS"}',
        );

        stubGenerateWithImages(mockCloudInferenceRepo, stream: mockStream);

        stubCreateAiResponseEntry(mockAiInputRepo);

        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);

        // Create repository after all mocks are set up
        final ref = container.read(testRefProvider);
        final repository = UnifiedAiInferenceRepository(ref)
          ..autoChecklistServiceForTesting = mockAutoChecklistService;

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
          expect(statusChanges, [
            InferenceStatus.running,
            InferenceStatus.idle,
          ]);

          // Verify the prompt was built with task context
          final captured = verify(
            () => mockCloudInferenceRepo.generateWithImages(
              captureAny(),
              impactCollector: any(named: 'impactCollector'),
              provider: any(named: 'provider'),
              model: 'gpt-4-vision',
              temperature: 0.6,
              images: any(named: 'images'),
              baseUrl: 'https://api.example.com',
              apiKey: 'test-api-key',
            ),
          ).captured;

          final capturedPrompt = captured.first as String;

          // The prompt should have the task context injected (placeholder replaced)
          expect(capturedPrompt, contains('Task Context:'));
          expect(capturedPrompt, contains('Database Migration Task'));
          expect(capturedPrompt, contains('IN PROGRESS'));

          // Verify that the image entity was updated without disclaimer
          final updateCaptured = verify(
            () => mockJournalRepo.updateJournalEntity(captureAny()),
          ).captured;

          final updatedEntity = updateCaptured.first as JournalImage;
          expect(
            updatedEntity.entryText?.markdown,
            isNot(contains('Disclaimer')),
          );
          expect(
            updatedEntity.entryText?.markdown,
            contains('ducks by a lake'),
          );
        } finally {
          // Clean up the temporary directory
          tempDir.deleteSync(recursive: true);
        }
      });

      test(
        'image analysis uses generic prompt when not linked to a task',
        () async {
          // Create a temporary directory for the test
          final tempDir = Directory.systemTemp.createTempSync(
            'image_generic_test',
          );
          overrideTempDirs.add(tempDir);

          // Update the mock directory to point to our temp directory
          when(() => mockDirectory.path).thenReturn(tempDir.path);

          final imageEntity = JournalImage(
            meta: createMetadata(),
            data: ImageData(
              capturedAt: DateTime(2024, 3, 15, 10, 30),
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

          final promptConfig =
              createPrompt(
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

          final model = createModel(
            id: 'model-1',
            inferenceProviderId: 'provider-1',
            providerModelId: 'gpt-4-vision',
          );

          final provider = createProvider(
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
              created:
                  DateTime(2024, 3, 15, 10, 30).millisecondsSinceEpoch ~/ 1000,
            ),
          ]);

          when(
            () => mockAiInputRepo.getEntity('test-id'),
          ).thenAnswer((_) async => imageEntity);
          when(
            () => mockAiConfigRepo.getConfigById('model-1'),
          ).thenAnswer((_) async => model);
          when(
            () => mockAiConfigRepo.getConfigById('provider-1'),
          ).thenAnswer((_) async => provider);
          when(
            () => mockJournalRepo.getLinkedToEntities(linkedTo: 'test-id'),
          ).thenAnswer((_) async => []); // No linked entities

          stubGenerateWithImages(mockCloudInferenceRepo, stream: mockStream);

          stubCreateAiResponseEntry(mockAiInputRepo);

          when(
            () => mockJournalRepo.updateJournalEntity(any()),
          ).thenAnswer((_) async => true);

          try {
            await repository!.runInference(
              entityId: 'test-id',
              promptConfig: promptConfig,
              onProgress: (_) {},
              onStatusChange: (_) {},
            );

            // Verify the prompt was built without task context
            final captured = verify(
              () => mockCloudInferenceRepo.generateWithImages(
                captureAny(),
                impactCollector: any(named: 'impactCollector'),
                provider: any(named: 'provider'),
                model: 'gpt-4-vision',
                temperature: 0.6,
                images: any(named: 'images'),
                baseUrl: 'https://api.example.com',
                apiKey: 'test-api-key',
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
        },
      );

      test('audio transcription uses task context when linked to a task', () async {
        // Create a temporary directory for the test
        final tempDir = Directory.systemTemp.createTempSync('audio_task_test');
        overrideTempDirs.add(tempDir);

        // Update the mock directory to point to our temp directory
        when(() => mockDirectory.path).thenReturn(tempDir.path);

        final audioEntity = JournalAudio(
          meta: createMetadata().copyWith(id: 'test-id'),
          data: AudioData(
            dateFrom: DateTime(2024, 3, 15, 10, 30),
            dateTo: DateTime(2024, 3, 15, 10, 30),
            audioDirectory: '/audio/',
            audioFile: 'test.wav',
            duration: const Duration(seconds: 30),
          ),
        );

        final taskEntity = Task(
          meta: createMetadata().copyWith(id: 'task-id'),
          data: TaskData(
            status: TaskStatus.inProgress(
              id: 'status-1',
              createdAt: DateTime(2024, 3, 15, 10, 30),
              utcOffset: 0,
            ),
            title: 'Interview with John Smith',
            statusHistory: [],
            dateFrom: DateTime(2024, 3, 15, 10, 30),
            dateTo: DateTime(2024, 3, 15, 10, 30),
          ),
        );

        // Create the directory structure and file
        Directory('${tempDir.path}/audio').createSync(recursive: true);
        final audioFile = File('${tempDir.path}/audio/test.wav');
        final mockAudioBytes = Uint8List.fromList([1, 2, 3, 4]);
        audioFile.writeAsBytesSync(mockAudioBytes);

        final promptConfig =
            createPrompt(
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

        final model = createModel(
          id: 'model-1',
          inferenceProviderId: 'provider-1',
          providerModelId: 'whisper-1',
        );

        final provider = createProvider(
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
            created:
                DateTime(2024, 3, 15, 10, 30).millisecondsSinceEpoch ~/ 1000,
          ),
        ]);

        when(
          () => mockAiInputRepo.getEntity('test-id'),
        ).thenAnswer((_) async => audioEntity);
        when(
          () => mockAiConfigRepo.getConfigById('model-1'),
        ).thenAnswer((_) async => model);
        when(
          () => mockAiConfigRepo.getConfigById('provider-1'),
        ).thenAnswer((_) async => provider);
        when(
          () => mockJournalRepo.getLinkedToEntities(linkedTo: 'test-id'),
        ).thenAnswer((_) async => [taskEntity]);
        when(
          () => mockAiInputRepo.buildTaskDetailsJson(id: 'task-id'),
        ).thenAnswer(
          (_) async =>
              '{"title": "Interview with John Smith", "status": "IN PROGRESS"}',
        );

        stubGenerateWithAudio(mockCloudInferenceRepo, stream: mockStream);

        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);

        // Create repository after all mocks are set up
        final ref = container.read(testRefProvider);
        final repository = UnifiedAiInferenceRepository(ref)
          ..autoChecklistServiceForTesting = mockAutoChecklistService;

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
          expect(statusChanges, [
            InferenceStatus.running,
            InferenceStatus.idle,
          ]);

          // Verify the prompt was built with task context
          final captured = verify(
            () => mockCloudInferenceRepo.generateWithAudio(
              captureAny(),
              provider: any(named: 'provider'),
              model: 'whisper-1',
              audioBase64: any(named: 'audioBase64'),
              baseUrl: 'https://api.example.com',
              apiKey: 'test-api-key',
              stream: any(named: 'stream'),
              audioFormat: any(named: 'audioFormat'),
            ),
          ).captured;

          final capturedPrompt = captured.first as String;

          // The prompt should have the task context injected (placeholder replaced)
          expect(capturedPrompt, contains('Task Context:'));
          expect(capturedPrompt, contains('Interview with John Smith'));
          expect(capturedPrompt, contains('IN PROGRESS'));
        } finally {
          // Clean up the temporary directory
          tempDir.deleteSync(recursive: true);
        }
      });

      test(
        'audio transcription keeps placeholder when not linked to a task',
        () async {
          // Create a temporary directory for the test
          final tempDir = Directory.systemTemp.createTempSync(
            'audio_no_task_test',
          );
          overrideTempDirs.add(tempDir);

          // Update the mock directory to point to our temp directory
          when(() => mockDirectory.path).thenReturn(tempDir.path);

          final audioEntity = JournalAudio(
            meta: createMetadata(),
            data: AudioData(
              dateFrom: DateTime(2024, 3, 15, 10, 30),
              dateTo: DateTime(2024, 3, 15, 10, 30),
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

          final promptConfig =
              createPrompt(
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

          final model = createModel(
            id: 'model-1',
            inferenceProviderId: 'provider-1',
            providerModelId: 'whisper-1',
          );

          final provider = createProvider(
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
              created:
                  DateTime(2024, 3, 15, 10, 30).millisecondsSinceEpoch ~/ 1000,
            ),
          ]);

          when(
            () => mockAiInputRepo.getEntity('test-id'),
          ).thenAnswer((_) async => audioEntity);
          when(
            () => mockAiConfigRepo.getConfigById('model-1'),
          ).thenAnswer((_) async => model);
          when(
            () => mockAiConfigRepo.getConfigById('provider-1'),
          ).thenAnswer((_) async => provider);
          when(
            () => mockJournalRepo.getLinkedToEntities(linkedTo: 'test-id'),
          ).thenAnswer((_) async => []); // No linked entities

          stubGenerateWithAudio(mockCloudInferenceRepo, stream: mockStream);

          when(
            () => mockJournalRepo.updateJournalEntity(any()),
          ).thenAnswer((_) async => true);

          try {
            await repository!.runInference(
              entityId: 'test-id',
              promptConfig: promptConfig,
              onProgress: (_) {},
              onStatusChange: (_) {},
            );

            // Verify the prompt was built without task context replacement
            final captured = verify(
              () => mockCloudInferenceRepo.generateWithAudio(
                provider: any(named: 'provider'),
                captureAny(),
                model: 'whisper-1',
                audioBase64: any(named: 'audioBase64'),
                baseUrl: 'https://api.example.com',
                apiKey: 'test-api-key',
                stream: any(named: 'stream'),
                audioFormat: any(named: 'audioFormat'),
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
        },
      );
    });
  });
  group('_handlePostProcessing – promptGeneration case (lines 821-827)', () {
    test(
      'promptGeneration response type completes without post-processing',
      () async {
        final taskEntity = Task(
          meta: createMetadata(),
          data: TaskData(
            status: TaskStatus.inProgress(
              id: 'status-1',
              createdAt: DateTime(2024, 3, 15, 10, 30),
              utcOffset: 0,
            ),
            title: 'Test Task',
            statusHistory: const [],
            dateFrom: DateTime(2024, 3, 15, 10, 30),
            dateTo: DateTime(2024, 3, 15, 10, 30),
          ),
        );

        final promptConfig = createPrompt(
          id: 'prompt-gen',
          name: 'Prompt Generation',
          requiredInputData: [InputDataType.task],
          aiResponseType: AiResponseType.promptGeneration,
        );

        final model = createModel(
          id: 'model-1',
          inferenceProviderId: 'provider-1',
          providerModelId: 'gpt-4',
        );

        final provider = createProvider(
          id: 'provider-1',
          inferenceProviderType: InferenceProviderType.genericOpenAi,
        );

        final statusChanges = <InferenceStatus>[];

        stubInferenceContext(
          mockAiInputRepo: mockAiInputRepo,
          mockAiConfigRepo: mockAiConfigRepo,
          entity: taskEntity,
          model: model,
          provider: provider,
        );
        stubGenerate(
          mockCloudInferenceRepo,
          stream: createMockTextStream(['Generated prompt content']),
        );
        stubCreateAiResponseEntry(mockAiInputRepo);

        await repository!.runInference(
          entityId: taskEntity.id,
          promptConfig: promptConfig,
          onProgress: (_) {},
          onStatusChange: statusChanges.add,
        );

        // Should complete normally with no journal entity update
        expect(statusChanges, [InferenceStatus.running, InferenceStatus.idle]);
        verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
      },
    );
  });

  group(
    '_handlePostProcessing – imagePromptGeneration case (lines 828-834)',
    () {
      test(
        'imagePromptGeneration response type completes without post-processing',
        () async {
          final taskEntity = Task(
            meta: createMetadata(),
            data: TaskData(
              status: TaskStatus.inProgress(
                id: 'status-1',
                createdAt: DateTime(2024, 3, 15, 10, 30),
                utcOffset: 0,
              ),
              title: 'Test Task',
              statusHistory: const [],
              dateFrom: DateTime(2024, 3, 15, 10, 30),
              dateTo: DateTime(2024, 3, 15, 10, 30),
            ),
          );

          final promptConfig = createPrompt(
            id: 'img-prompt-gen',
            name: 'Image Prompt Generation',
            requiredInputData: [InputDataType.task],
            aiResponseType: AiResponseType.imagePromptGeneration,
          );

          final model = createModel(
            id: 'model-1',
            inferenceProviderId: 'provider-1',
            providerModelId: 'gpt-4',
          );

          final provider = createProvider(
            id: 'provider-1',
            inferenceProviderType: InferenceProviderType.genericOpenAi,
          );

          final statusChanges = <InferenceStatus>[];

          stubInferenceContext(
            mockAiInputRepo: mockAiInputRepo,
            mockAiConfigRepo: mockAiConfigRepo,
            entity: taskEntity,
            model: model,
            provider: provider,
          );
          stubGenerate(
            mockCloudInferenceRepo,
            stream: createMockTextStream(['A beautiful landscape, 4K']),
          );
          stubCreateAiResponseEntry(mockAiInputRepo);

          await repository!.runInference(
            entityId: taskEntity.id,
            promptConfig: promptConfig,
            onProgress: (_) {},
            onStatusChange: statusChanges.add,
          );

          expect(statusChanges, [
            InferenceStatus.running,
            InferenceStatus.idle,
          ]);
          verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
        },
      );
    },
  );

  group('runInference – imageGeneration legacy guard (line 207)', () {
    test(
      'skips inference for imageGeneration (legacy type, lines 208-213)',
      () async {
        // AiResponseType.imageGeneration is a legacy type — runInference returns
        // early before any status change, identical to taskSummary/checklistUpdates.
        final promptConfig = createPrompt(
          id: 'img-gen',
          name: 'Image Generation',
          requiredInputData: [InputDataType.task],
          aiResponseType: AiResponseType.imageGeneration,
        );

        final statusChanges = <InferenceStatus>[];

        await repository!.runInference(
          entityId: 'test-id',
          promptConfig: promptConfig,
          onProgress: (_) {},
          onStatusChange: statusChanges.add,
        );

        // Early return — no status change, no inference calls
        expect(statusChanges, isEmpty);
        verifyNever(() => mockAiInputRepo.getEntity(any()));
      },
    );
  });

  group('_handlePostProcessing – image analysis updateJournalEntity failure', () {
    test(
      'logs error and continues when updateJournalEntity throws for image',
      () async {
        final tempDir = Directory.systemTemp.createTempSync(
          'image_error_test_',
        );
        overrideTempDirs.add(tempDir);
        when(() => mockDirectory.path).thenReturn(tempDir.path);

        final imageEntity = JournalImage(
          meta: createMetadata(),
          data: ImageData(
            capturedAt: DateTime(2024, 3, 15, 10, 30),
            imageId: 'test-image',
            imageFile: 'test.jpg',
            imageDirectory: '/images/',
          ),
        );

        Directory('${tempDir.path}/images').createSync(recursive: true);
        File(
          '${tempDir.path}/images/test.jpg',
        ).writeAsBytesSync(Uint8List.fromList([1, 2, 3, 4]));

        final promptConfig = createPrompt(
          id: 'img-analysis',
          name: 'Image Analysis',
          requiredInputData: [InputDataType.images],
          aiResponseType: AiResponseType.imageAnalysis,
        );

        final model = createModel(
          id: 'model-1',
          inferenceProviderId: 'provider-1',
          providerModelId: 'gpt-4-vision',
        );

        final provider = createProvider(
          id: 'provider-1',
          inferenceProviderType: InferenceProviderType.genericOpenAi,
        );

        stubInferenceContext(
          mockAiInputRepo: mockAiInputRepo,
          mockAiConfigRepo: mockAiConfigRepo,
          entity: imageEntity,
          model: model,
          provider: provider,
          taskDetailsJson: '{"image":"test.jpg"}',
        );
        when(
          () => mockJournalRepo.getLinkedToEntities(linkedTo: 'test-id'),
        ).thenAnswer((_) async => []);

        // Entity state helper re-fetches the image before update
        when(
          () => mockAiInputRepo.getEntity('test-id'),
        ).thenAnswer((_) async => imageEntity);

        // Make updateJournalEntity throw to cover the error-catch at lines 760-761
        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenThrow(Exception('DB write error'));

        stubGenerateWithImages(
          mockCloudInferenceRepo,
          stream: createMockTextStream(['Analysis result']),
        );
        stubCreateAiResponseEntry(mockAiInputRepo);

        // Should complete without rethrowing
        final statusChanges = <InferenceStatus>[];
        await repository!.runInference(
          entityId: 'test-id',
          promptConfig: promptConfig,
          onProgress: (_) {},
          onStatusChange: statusChanges.add,
        );

        expect(statusChanges, [InferenceStatus.running, InferenceStatus.idle]);
      },
    );
  });

  group(
    '_handlePostProcessing – audio transcription updateJournalEntity failure',
    () {
      test(
        'logs error and continues when updateJournalEntity throws for audio',
        () async {
          final tempDir = Directory.systemTemp.createTempSync(
            'audio_error_test_',
          );
          overrideTempDirs.add(tempDir);
          when(() => mockDirectory.path).thenReturn(tempDir.path);

          final audioEntity = JournalAudio(
            meta: createMetadata(),
            data: AudioData(
              dateFrom: DateTime(2024, 3, 15, 10, 30),
              dateTo: DateTime(2024, 3, 15, 10, 30),
              audioFile: 'test.mp3',
              audioDirectory: '/audio/',
              duration: const Duration(seconds: 30),
            ),
          );

          Directory('${tempDir.path}/audio').createSync(recursive: true);
          File(
            '${tempDir.path}/audio/test.mp3',
          ).writeAsBytesSync(Uint8List.fromList([1, 2, 3, 4, 5]));

          final promptConfig = createPrompt(
            id: 'audio-transcript',
            name: 'Audio Transcription',
            requiredInputData: [InputDataType.audioFiles],
            aiResponseType: AiResponseType.audioTranscription,
          );

          final model = createModel(
            id: 'model-1',
            inferenceProviderId: 'provider-1',
            providerModelId: 'whisper-1',
          );

          final provider = createProvider(
            id: 'provider-1',
            inferenceProviderType: InferenceProviderType.genericOpenAi,
          );

          stubInferenceContext(
            mockAiInputRepo: mockAiInputRepo,
            mockAiConfigRepo: mockAiConfigRepo,
            entity: audioEntity,
            model: model,
            provider: provider,
            taskDetailsJson: '{"audio":"test.mp3"}',
          );
          when(
            () => mockJournalRepo.getLinkedToEntities(linkedTo: 'test-id'),
          ).thenAnswer((_) async => []);

          // Entity state helper re-fetches
          when(
            () => mockAiInputRepo.getEntity('test-id'),
          ).thenAnswer((_) async => audioEntity);

          // Throw to cover lines 814-815
          when(
            () => mockJournalRepo.updateJournalEntity(any()),
          ).thenThrow(Exception('DB write error'));

          stubGenerateWithAudio(
            mockCloudInferenceRepo,
            stream: createMockTextStream(['Transcribed text']),
          );
          stubCreateAiResponseEntry(mockAiInputRepo);

          final statusChanges = <InferenceStatus>[];
          await repository!.runInference(
            entityId: 'test-id',
            promptConfig: promptConfig,
            onProgress: (_) {},
            onStatusChange: statusChanges.add,
          );

          expect(statusChanges, [
            InferenceStatus.running,
            InferenceStatus.idle,
          ]);
        },
      );
    },
  );
}
