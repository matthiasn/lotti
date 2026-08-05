// ignore_for_file: unawaited_futures, avoid_redundant_argument_values

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai/functions/checklist_completion_functions.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/unified_ai_inference_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../mocks/mocks.dart';
import '../test_utils.dart';
import 'unified_ai_inference_repository_test_helpers.dart';

final harness = UnifiedAiInferenceRepositoryTestHarness();

UnifiedAiInferenceRepository get repository => harness.repository;
ProviderContainer get container => harness.container;
MockAiConfigRepository get mockAiConfigRepo => harness.mockAiConfigRepo;
MockAiInputRepository get mockAiInputRepo => harness.mockAiInputRepo;
MockCloudInferenceRepository get mockCloudInferenceRepo =>
    harness.mockCloudInferenceRepo;
MockJournalRepository get mockJournalRepo => harness.mockJournalRepo;
MockDirectory get mockDirectory => harness.mockDirectory;
TestChecklistCompletionService get testChecklistCompletionService =>
    harness.testChecklistCompletionService;
List<Directory> get overrideTempDirs => harness.overrideTempDirs;

void main() {
  setUpAll(harness.setUpAll);
  setUp(harness.setUp);
  tearDown(harness.tearDown);
  tearDownAll(harness.tearDownAll);

  group('Concurrent Safety Tests', () {
    test('runInference calls getEntity to retrieve entity', () async {
      // Setup
      final task = Task(
        meta: createMetadata(),
        data: TaskData(
          status: TaskStatus.inProgress(
            id: 'status-1',
            createdAt: DateTime(2024, 3, 15, 10, 30),
            utcOffset: 0,
          ),
          title: 'Test Task',
          dateFrom: DateTime(2024, 3, 15, 10, 30),
          dateTo: DateTime(2024, 3, 15, 10, 30),
          statusHistory: [],
        ),
      );

      final prompt = createPrompt(id: 'test-prompt', name: 'Test Prompt');

      final model = createModel(
        id: 'model-1',
        inferenceProviderId: 'provider-1',
        providerModelId: 'gpt-4',
      );

      final provider = createProvider(
        id: 'provider-1',
        inferenceProviderType: InferenceProviderType.genericOpenAi,
      );

      when(
        () => mockAiInputRepo.getEntity('test-id'),
      ).thenAnswer((_) async => task);

      when(
        () => mockAiConfigRepo.getConfigById('test-prompt'),
      ).thenAnswer((_) async => prompt);

      when(
        () => mockAiConfigRepo.getConfigById('model-1'),
      ).thenAnswer((_) async => model);

      when(
        () => mockAiConfigRepo.getConfigById('provider-1'),
      ).thenAnswer((_) async => provider);

      when(
        () => mockCloudInferenceRepo.generate(
          any(),
          impactCollector: any(named: 'impactCollector'),
          model: any(named: 'model'),
          temperature: any(named: 'temperature'),
          baseUrl: any(named: 'baseUrl'),
          apiKey: any(named: 'apiKey'),
          systemMessage: any(named: 'systemMessage'),
          provider: any(named: 'provider'),
          maxCompletionTokens: any(named: 'maxCompletionTokens'),
          geminiThinkingMode: any(named: 'geminiThinkingMode'),
        ),
      ).thenAnswer(
        (_) => Stream.value(
          CreateChatCompletionStreamResponse(
            id: 'test-id',
            created: DateTime(2024, 3, 15, 10, 30).millisecondsSinceEpoch,
            choices: [
              const ChatCompletionStreamResponseChoice(
                index: 0,
                delta: ChatCompletionStreamResponseDelta(
                  content: 'Test response',
                ),
              ),
            ],
          ),
        ),
      );

      when(
        () => mockAiInputRepo.createAiResponseEntry(
          data: any(named: 'data'),
          start: any(named: 'start'),
          linkedId: any(named: 'linkedId'),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer((_) async => null);

      final ref = container.read(testRefProvider);
      final repository = UnifiedAiInferenceRepository(ref);

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
      verify(
        () => mockAiInputRepo.getEntity('test-id'),
      ).called(greaterThanOrEqualTo(1));
    });

    test(
      'image analysis handles entity not found during post-processing',
      () async {
        // Create temporary directory for the test
        final tempDir = Directory.systemTemp.createTempSync('image_test');
        overrideTempDirs.add(tempDir);

        // Update the mock directory to point to our temp directory
        when(() => mockDirectory.path).thenReturn(tempDir.path);

        try {
          // Create the directory structure
          Directory('${tempDir.path}/images').createSync();

          // Create the image file
          File(
            '${tempDir.path}/images/test-image.jpg',
          ).writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0]); // JPEG header

          const imageId = 'test-image-id';
          final image = JournalImage(
            meta: Metadata(
              id: imageId,
              createdAt: DateTime(2024, 3, 15, 10, 30),
              updatedAt: DateTime(2024, 3, 15, 10, 30),
              dateFrom: DateTime(2024, 3, 15, 10, 30),
              dateTo: DateTime(2024, 3, 15, 10, 30),
            ),
            data: ImageData(
              capturedAt: DateTime(2024, 3, 15, 10, 30),
              imageId: 'test-image-id',
              imageFile: 'test-image.jpg',
              imageDirectory: '/images/',
            ),
          );

          final promptConfig = createPrompt(
            id: 'image-prompt',
            name: 'Image Analysis',
            aiResponseType: AiResponseType.imageAnalysis,
            requiredInputData: [InputDataType.images],
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

          // Setup: entity found first time, null second time (during post-processing)
          var getEntityCallCount = 0;
          when(() => mockAiInputRepo.getEntity(imageId)).thenAnswer((_) async {
            getEntityCallCount++;
            return getEntityCallCount == 1 ? image : null;
          });

          when(
            () => mockAiConfigRepo.getConfigById('image-prompt'),
          ).thenAnswer((_) async => promptConfig);

          when(
            () => mockAiConfigRepo.getConfigById('model-1'),
          ).thenAnswer((_) async => model);

          when(
            () => mockAiConfigRepo.getConfigById('provider-1'),
          ).thenAnswer((_) async => provider);

          when(
            () => mockAiInputRepo.buildTaskDetailsJson(id: imageId),
          ).thenAnswer((_) async => '{}');

          when(
            () => mockJournalRepo.getLinkedToEntities(
              linkedTo: any(named: 'linkedTo'),
            ),
          ).thenAnswer((_) async => <JournalEntity>[]);

          final mockStream = createMockTextStream([
            'This is an image of a sunset',
          ]);

          stubGenerateWithImages(mockCloudInferenceRepo, stream: mockStream);

          stubCreateAiResponseEntry(mockAiInputRepo);

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
      },
    );

    test(
      'audio transcription handles entity type change during processing',
      () async {
        // Create temporary directory for the test
        final tempDir = Directory.systemTemp.createTempSync('audio_test');
        overrideTempDirs.add(tempDir);

        // Update the mock directory to point to our temp directory
        when(() => mockDirectory.path).thenReturn(tempDir.path);

        try {
          // Create the directory structure
          Directory('${tempDir.path}/audio').createSync();

          // Create the audio file
          File(
            '${tempDir.path}/audio/test-audio.wav',
          ).writeAsBytesSync([1, 2, 3, 4, 5, 6]);

          const audioId = 'test-audio-id';
          final audio = JournalAudio(
            meta: Metadata(
              id: audioId,
              createdAt: DateTime(2024, 3, 15, 10, 30),
              updatedAt: DateTime(2024, 3, 15, 10, 30),
              dateFrom: DateTime(2024, 3, 15, 10, 30),
              dateTo: DateTime(2024, 3, 15, 10, 30),
            ),
            data: AudioData(
              dateFrom: DateTime(2024, 3, 15, 10, 30),
              dateTo: DateTime(2024, 3, 15, 10, 35),
              audioFile: 'test-audio.wav',
              audioDirectory: '/audio/',
              duration: const Duration(minutes: 5),
            ),
          );

          // Create a different entity type with same ID
          final journalEntry = JournalEntity.journalEntry(
            meta: Metadata(
              id: audioId,
              createdAt: DateTime(2024, 3, 15, 10, 30),
              updatedAt: DateTime(2024, 3, 15, 10, 30),
              dateFrom: DateTime(2024, 3, 15, 10, 30),
              dateTo: DateTime(2024, 3, 15, 10, 30),
            ),
            entryText: const EntryText(
              plainText: 'This is now a journal entry',
            ),
          );

          final promptConfig = createPrompt(
            id: 'audio-prompt',
            name: 'Audio Transcription',
            aiResponseType: AiResponseType.audioTranscription,
            requiredInputData: [InputDataType.audioFiles],
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

          // Setup: audio found first time, journal entry second time (type change)
          var getEntityCallCount = 0;
          when(() => mockAiInputRepo.getEntity(audioId)).thenAnswer((_) async {
            getEntityCallCount++;
            return getEntityCallCount == 1 ? audio : journalEntry;
          });

          when(
            () => mockAiConfigRepo.getConfigById('audio-prompt'),
          ).thenAnswer((_) async => promptConfig);

          when(
            () => mockAiConfigRepo.getConfigById('model-1'),
          ).thenAnswer((_) async => model);

          when(
            () => mockAiConfigRepo.getConfigById('provider-1'),
          ).thenAnswer((_) async => provider);

          when(
            () => mockAiInputRepo.buildTaskDetailsJson(id: audioId),
          ).thenAnswer((_) async => '{}');

          when(
            () => mockJournalRepo.getLinkedToEntities(
              linkedTo: any(named: 'linkedTo'),
            ),
          ).thenAnswer((_) async => <JournalEntity>[]);

          final mockStream = createMockTextStream([
            'This is the transcribed audio content',
          ]);

          stubGenerateWithAudio(mockCloudInferenceRepo, stream: mockStream);

          stubCreateAiResponseEntry(mockAiInputRepo);

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
      },
    );

    test(
      'image analysis with concurrent text update preserves user changes',
      () async {
        // Create temporary directory for the test
        final tempDir = Directory.systemTemp.createTempSync('image_test');
        overrideTempDirs.add(tempDir);

        // Update the mock directory to point to our temp directory
        when(() => mockDirectory.path).thenReturn(tempDir.path);

        try {
          // Create the directory structure
          Directory('${tempDir.path}/images').createSync();

          // Create the image file
          File(
            '${tempDir.path}/images/test-image.jpg',
          ).writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0]); // JPEG header

          const imageId = 'test-image-id';
          final originalImage = JournalImage(
            meta: Metadata(
              id: imageId,
              createdAt: DateTime(2024, 3, 15, 10, 30),
              updatedAt: DateTime(2024, 3, 15, 10, 30),
              dateFrom: DateTime(2024, 3, 15, 10, 30),
              dateTo: DateTime(2024, 3, 15, 10, 30),
            ),
            data: ImageData(
              capturedAt: DateTime(2024, 3, 15, 10, 30),
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

          final promptConfig = createPrompt(
            id: 'image-prompt',
            name: 'Image Analysis',
            aiResponseType: AiResponseType.imageAnalysis,
            requiredInputData: [InputDataType.images],
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

          // Setup: original image first time, updated image second time
          var getEntityCallCount = 0;
          when(() => mockAiInputRepo.getEntity(imageId)).thenAnswer((_) async {
            getEntityCallCount++;
            return getEntityCallCount == 1 ? originalImage : updatedImage;
          });

          when(
            () => mockAiConfigRepo.getConfigById('image-prompt'),
          ).thenAnswer((_) async => promptConfig);

          when(
            () => mockAiConfigRepo.getConfigById('model-1'),
          ).thenAnswer((_) async => model);

          when(
            () => mockAiConfigRepo.getConfigById('provider-1'),
          ).thenAnswer((_) async => provider);

          when(
            () => mockAiInputRepo.buildTaskDetailsJson(id: imageId),
          ).thenAnswer((_) async => '{}');

          when(
            () => mockJournalRepo.getLinkedToEntities(
              linkedTo: any(named: 'linkedTo'),
            ),
          ).thenAnswer((_) async => <JournalEntity>[]);

          when(
            () => mockJournalRepo.updateJournalEntity(any()),
          ).thenAnswer((_) async => true);

          final mockStream = createMockTextStream([
            'AI analysis: Beautiful sunset',
          ]);

          stubGenerateWithImages(mockCloudInferenceRepo, stream: mockStream);

          stubCreateAiResponseEntry(mockAiInputRepo);

          // Execute
          await repository.runInference(
            entityId: imageId,
            promptConfig: promptConfig,
            onProgress: (_) {},
            onStatusChange: (_) {},
          );

          // Verify: updateJournalEntity was called with appended text
          final capturedEntity =
              verify(
                    () => mockJournalRepo.updateJournalEntity(captureAny()),
                  ).captured.single
                  as JournalImage;

          // Should append AI analysis to user's text
          expect(
            capturedEntity.entryText?.plainText,
            'User added this description\n\nAI analysis: Beautiful sunset',
          );

          // Verify: getEntity was called twice (initial + post-processing)
          verify(() => mockAiInputRepo.getEntity(imageId)).called(2);
        } finally {
          // Clean up the temporary directory
          tempDir.deleteSync(recursive: true);
        }
      },
    );

    test(
      'audio transcription error handling preserves entity integrity',
      () async {
        // Create temporary directory for the test
        final tempDir = Directory.systemTemp.createTempSync('audio_test');
        overrideTempDirs.add(tempDir);

        // Update the mock directory to point to our temp directory
        when(() => mockDirectory.path).thenReturn(tempDir.path);

        try {
          // Create the directory structure
          Directory('${tempDir.path}/audio').createSync();

          // Create the audio file
          File(
            '${tempDir.path}/audio/test-audio.wav',
          ).writeAsBytesSync([1, 2, 3, 4, 5, 6]);

          const audioId = 'test-audio-id';
          final audio = JournalAudio(
            meta: Metadata(
              id: audioId,
              createdAt: DateTime(2024, 3, 15, 10, 30),
              updatedAt: DateTime(2024, 3, 15, 10, 30),
              dateFrom: DateTime(2024, 3, 15, 10, 30),
              dateTo: DateTime(2024, 3, 15, 10, 30),
            ),
            data: AudioData(
              dateFrom: DateTime(2024, 3, 15, 10, 30),
              dateTo: DateTime(2024, 3, 15, 10, 35),
              audioFile: 'test-audio.wav',
              audioDirectory: '/audio/',
              duration: const Duration(minutes: 5),
            ),
          );

          final promptConfig = createPrompt(
            id: 'audio-prompt',
            name: 'Audio Transcription',
            aiResponseType: AiResponseType.audioTranscription,
            requiredInputData: [InputDataType.audioFiles],
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

          when(
            () => mockAiConfigRepo.getConfigById('audio-prompt'),
          ).thenAnswer((_) async => promptConfig);

          when(
            () => mockAiConfigRepo.getConfigById('model-1'),
          ).thenAnswer((_) async => model);

          when(
            () => mockAiConfigRepo.getConfigById('provider-1'),
          ).thenAnswer((_) async => provider);

          when(
            () => mockAiInputRepo.buildTaskDetailsJson(id: audioId),
          ).thenAnswer((_) async => '{}');

          when(
            () => mockJournalRepo.getLinkedToEntities(
              linkedTo: any(named: 'linkedTo'),
            ),
          ).thenAnswer((_) async => <JournalEntity>[]);

          final mockStream = createMockTextStream(['Transcribed content']);

          stubGenerateWithAudio(mockCloudInferenceRepo, stream: mockStream);

          stubCreateAiResponseEntry(mockAiInputRepo);

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
      },
    );

    group('Tool call accumulation', () {
      test('handles multiple tool calls with empty IDs correctly', () async {
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
            checklistIds: ['checklist-1'],
          ),
        );

        // No need to set up checklist items for this test as we're mocking the tool calls

        final promptConfig = createPrompt(
          id: 'prompt-1',
          name: 'Task Summary',
          requiredInputData: [InputDataType.task],
        );

        final model = createModel(
          id: 'model-1',
          inferenceProviderId: 'provider-1',
          providerModelId: 'gpt-4',
        ).copyWith(supportsFunctionCalling: true);

        final provider = createProvider(
          id: 'provider-1',
          inferenceProviderType: InferenceProviderType.openRouter,
        );

        when(
          () => mockAiInputRepo.getEntity(taskEntity.id),
        ).thenAnswer((_) async => taskEntity);
        when(
          () => mockAiConfigRepo.getConfigById('model-1'),
        ).thenAnswer((_) async => model);
        when(
          () => mockAiConfigRepo.getConfigById('provider-1'),
        ).thenAnswer((_) async => provider);
        when(
          () => mockAiInputRepo.buildTaskDetailsJson(id: taskEntity.id),
        ).thenAnswer((_) async => '{"task": "details"}');

        // Create stream with multiple tool calls with empty IDs
        final streamController = StreamController<CreateChatCompletionStreamResponse>()
          // Add chunks with multiple tool calls, all with empty IDs
          // Since the implementation uses dynamic checking, we can send a custom object
          ..add(
            CreateChatCompletionStreamResponse(
              id: 'test-completion-id',
              choices: [
                ChatCompletionStreamResponseChoice(
                  index: 0,
                  delta: ChatCompletionStreamResponseDelta(
                    toolCalls: [
                      createMockToolCall(
                        index: 0,
                        id: '', // Empty ID
                        functionName: 'suggest_checklist_completion',
                        arguments:
                            '{"checklistItemId":"item-1","reason":"Developed","confidence":"high"}',
                      ),
                      createMockToolCall(
                        index: 0,
                        id: '', // Empty ID
                        functionName: 'suggest_checklist_completion',
                        arguments:
                            '{"checklistItemId":"item-2","reason":"Added tests","confidence":"high"}',
                      ),
                      createMockToolCall(
                        index: 0,
                        id: '', // Empty ID
                        functionName: 'suggest_checklist_completion',
                        arguments:
                            '{"checklistItemId":"item-3","reason":"Released","confidence":"high"}',
                      ),
                    ],
                  ),
                ),
              ],
              created:
                  DateTime(2024, 3, 15, 10, 30).millisecondsSinceEpoch ~/ 1000,
              model: 'test-model',
              object: 'chat.completion.chunk',
            ),
          )
          // Add content chunk
          ..add(createStreamChunk('Task completed'))
          ..close();

        stubGenerate(mockCloudInferenceRepo, stream: streamController.stream);

        // Clear any captured suggestions from previous tests
        testChecklistCompletionService.capturedSuggestions.clear();

        await repository.runInference(
          entityId: taskEntity.id,
          promptConfig: promptConfig,
          onProgress: (_) {},
          onStatusChange: (_) {},
        );

        // Verify all three suggestions were processed
        expect(testChecklistCompletionService.capturedSuggestions.length, 3);
        expect(
          testChecklistCompletionService.capturedSuggestions.map(
            (s) => s.checklistItemId,
          ),
          containsAll(['item-1', 'item-2', 'item-3']),
        );
      });

      test('processes concatenated JSON in tool call arguments', () async {
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

        final promptConfig = createPrompt(
          id: 'prompt-1',
          name: 'Task Summary',
          requiredInputData: [InputDataType.task],
        );

        final model = createModel(
          id: 'model-1',
          inferenceProviderId: 'provider-1',
          providerModelId: 'gpt-4',
        ).copyWith(supportsFunctionCalling: true);

        final provider = createProvider(
          id: 'provider-1',
          inferenceProviderType: InferenceProviderType.openRouter,
        );

        when(
          () => mockAiInputRepo.getEntity(taskEntity.id),
        ).thenAnswer((_) async => taskEntity);
        when(
          () => mockAiConfigRepo.getConfigById('model-1'),
        ).thenAnswer((_) async => model);
        when(
          () => mockAiConfigRepo.getConfigById('provider-1'),
        ).thenAnswer((_) async => provider);
        when(
          () => mockAiInputRepo.buildTaskDetailsJson(id: taskEntity.id),
        ).thenAnswer((_) async => '{"task": "details"}');

        // Create stream with concatenated JSON in a single tool call
        final streamController = StreamController<CreateChatCompletionStreamResponse>()
          ..add(
            createStreamChunkWithToolCalls([
              createMockToolCall(
                index: 0,
                id: 'call-1',
                functionName: 'suggest_checklist_completion',
                arguments:
                    '{"checklistItemId":"item-1","reason":"Done 1","confidence":"high"} '
                    '{"checklistItemId":"item-2","reason":"Done 2","confidence":"medium"} '
                    '{"checklistItemId":"item-3","reason":"Done 3","confidence":"low"}',
              ),
            ]),
          )
          ..add(createStreamChunk('Task completed'))
          ..close();

        stubGenerate(mockCloudInferenceRepo, stream: streamController.stream);

        // Clear any captured suggestions from previous tests
        testChecklistCompletionService.capturedSuggestions.clear();

        await repository.runInference(
          entityId: taskEntity.id,
          promptConfig: promptConfig,
          onProgress: (_) {},
          onStatusChange: (_) {},
        );

        // Verify all three suggestions were parsed from concatenated JSON
        expect(testChecklistCompletionService.capturedSuggestions.length, 3);
        expect(
          testChecklistCompletionService.capturedSuggestions.map(
            (s) => s.checklistItemId,
          ),
          containsAll(['item-1', 'item-2', 'item-3']),
        );
        expect(
          testChecklistCompletionService.capturedSuggestions.map(
            (s) => s.confidence,
          ),
          containsAll([
            ChecklistCompletionConfidence.high,
            ChecklistCompletionConfidence.medium,
            ChecklistCompletionConfidence.low,
          ]),
        );
      });
    });
  });
}
