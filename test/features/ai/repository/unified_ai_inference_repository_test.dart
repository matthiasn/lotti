// ignore_for_file: avoid_redundant_argument_values

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/unified_ai_inference_repository.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
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
    group('getActivePromptsForContext', () {
      test('returns prompts matching task entity', () async {
        final taskEntity = Task(
          meta: createMetadata(),
          data: TaskData(
            status: TaskStatus.inProgress(
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

        final taskPrompt = createPrompt(
          id: 'task-prompt',
          name: 'Task Summary',
          requiredInputData: [InputDataType.task],
        );

        final imagePrompt = createPrompt(
          id: 'image-prompt',
          name: 'Image Analysis',
          requiredInputData: [InputDataType.images],
          aiResponseType: AiResponseType.imageAnalysis,
        );

        when(
          () => mockAiConfigRepo.getConfigsByType(AiConfigType.prompt),
        ).thenAnswer((_) async => [taskPrompt, imagePrompt]);

        final result = await repository!.getActivePromptsForContext(
          entity: taskEntity,
        );

        expect(result.length, 1);
        expect(result.first.id, 'task-prompt');
      });

      test('returns prompts matching image entity', () async {
        final imageEntity = JournalImage(
          meta: createMetadata(),
          data: ImageData(
            capturedAt: DateTime(2024, 3, 15, 10, 30),
            imageId: 'test-image',
            imageFile: 'test.jpg',
            imageDirectory: '/images/',
          ),
        );

        final taskPrompt = createPrompt(
          id: 'task-prompt',
          name: 'Task Summary',
          requiredInputData: [InputDataType.task],
        );

        final imagePrompt = createPrompt(
          id: 'image-prompt',
          name: 'Image Analysis',
          requiredInputData: [InputDataType.images],
          aiResponseType: AiResponseType.imageAnalysis,
        );

        when(
          () => mockAiConfigRepo.getConfigsByType(AiConfigType.prompt),
        ).thenAnswer((_) async => [taskPrompt, imagePrompt]);

        final result = await repository!.getActivePromptsForContext(
          entity: imageEntity,
        );

        expect(result.length, 1);
        expect(result.first.id, 'image-prompt');
      });

      test('returns prompts matching audio entity', () async {
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

        final audioPrompt = createPrompt(
          id: 'audio-prompt',
          name: 'Audio Transcription',
          requiredInputData: [InputDataType.audioFiles],
          aiResponseType: AiResponseType.audioTranscription,
        );

        final taskPrompt = createPrompt(
          id: 'task-prompt',
          name: 'Task Summary',
          requiredInputData: [InputDataType.task],
        );

        when(
          () => mockAiConfigRepo.getConfigsByType(AiConfigType.prompt),
        ).thenAnswer((_) async => [audioPrompt, taskPrompt]);

        final result = await repository!.getActivePromptsForContext(
          entity: audioEntity,
        );

        expect(result.length, 1);
        expect(result.first.id, 'audio-prompt');
      });

      test('returns prompts matching multiple input types', () async {
        final taskEntity = Task(
          meta: createMetadata(),
          data: TaskData(
            status: TaskStatus.inProgress(
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

        final multiInputPrompt = createPrompt(
          id: 'multi-prompt',
          name: 'Multi Input Prompt',
          requiredInputData: [InputDataType.task, InputDataType.tasksList],
        );

        when(
          () => mockAiConfigRepo.getConfigsByType(AiConfigType.prompt),
        ).thenAnswer((_) async => [multiInputPrompt]);

        final result = await repository!.getActivePromptsForContext(
          entity: taskEntity,
        );

        expect(result.length, 1);
        expect(result.first.id, 'multi-prompt');
      });

      test('filters out prompts with mismatched input types', () async {
        final taskEntity = Task(
          meta: createMetadata(),
          data: TaskData(
            status: TaskStatus.inProgress(
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

        final mismatchedPrompt = createPrompt(
          id: 'mismatched-prompt',
          name: 'Mismatched Prompt',
          requiredInputData: [InputDataType.task, InputDataType.images],
        );

        when(
          () => mockAiConfigRepo.getConfigsByType(AiConfigType.prompt),
        ).thenAnswer((_) async => [mismatchedPrompt]);

        final result = await repository!.getActivePromptsForContext(
          entity: taskEntity,
        );

        expect(result.isEmpty, true);
      });

      test('filters out archived prompts', () async {
        final taskEntity = Task(
          meta: createMetadata(),
          data: TaskData(
            status: TaskStatus.inProgress(
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

        final activePrompt = createPrompt(
          id: 'active-prompt',
          name: 'Active Task Prompt',
          requiredInputData: [InputDataType.task],
        );

        final archivedPrompt = createPrompt(
          id: 'archived-prompt',
          name: 'Archived Task Prompt',
          requiredInputData: [InputDataType.task],
          archived: true,
        );

        when(
          () => mockAiConfigRepo.getConfigsByType(AiConfigType.prompt),
        ).thenAnswer((_) async => [activePrompt, archivedPrompt]);

        final result = await repository!.getActivePromptsForContext(
          entity: taskEntity,
        );

        expect(result.length, 1);
        expect(result.first.id, 'active-prompt');
      });

      test('filters out imagePromptGeneration for task entities', () async {
        final taskEntity = Task(
          meta: createMetadata(),
          data: TaskData(
            status: TaskStatus.inProgress(
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

        final taskPrompt = createPrompt(
          id: 'task-prompt',
          name: 'Task Analysis',
          requiredInputData: [InputDataType.task],
          aiResponseType: AiResponseType.imageAnalysis,
        );

        final imagePromptGenPrompt = createPrompt(
          id: 'image-prompt-gen',
          name: 'Image Prompt Generation',
          requiredInputData: [InputDataType.task],
          aiResponseType: AiResponseType.imagePromptGeneration,
        );

        when(
          () => mockAiConfigRepo.getConfigsByType(AiConfigType.prompt),
        ).thenAnswer((_) async => [taskPrompt, imagePromptGenPrompt]);

        final result = await repository!.getActivePromptsForContext(
          entity: taskEntity,
        );

        // imagePromptGeneration should be filtered out for task entities
        // (it requires audio entry input for the transcript)
        expect(result.length, 1);
        expect(result.first.id, 'task-prompt');
        expect(result.any((p) => p.id == 'image-prompt-gen'), false);
      });

      test('filters out promptGeneration for task entities', () async {
        final taskEntity = Task(
          meta: createMetadata(),
          data: TaskData(
            status: TaskStatus.inProgress(
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

        final taskPrompt = createPrompt(
          id: 'task-prompt',
          name: 'Task Analysis',
          requiredInputData: [InputDataType.task],
          aiResponseType: AiResponseType.imageAnalysis,
        );

        final promptGenPrompt = createPrompt(
          id: 'prompt-gen',
          name: 'Coding Prompt Generation',
          requiredInputData: [InputDataType.task],
          aiResponseType: AiResponseType.promptGeneration,
        );

        when(
          () => mockAiConfigRepo.getConfigsByType(AiConfigType.prompt),
        ).thenAnswer((_) async => [taskPrompt, promptGenPrompt]);

        final result = await repository!.getActivePromptsForContext(
          entity: taskEntity,
        );

        // promptGeneration should be filtered out for task entities
        // (it requires audio entry input for the transcript)
        expect(result.length, 1);
        expect(result.first.id, 'task-prompt');
        expect(result.any((p) => p.id == 'prompt-gen'), false);
      });

      test('returns empty list when no prompts match', () async {
        final journalEntry = JournalEntry(meta: createMetadata());

        final taskPrompt = createPrompt(
          id: 'task-prompt',
          name: 'Task Summary',
          requiredInputData: [InputDataType.task],
        );

        when(
          () => mockAiConfigRepo.getConfigsByType(AiConfigType.prompt),
        ).thenAnswer((_) async => [taskPrompt]);

        final result = await repository!.getActivePromptsForContext(
          entity: journalEntry,
        );

        expect(result.isEmpty, true);
      });

      test(
        'returns task context prompts only when image is linked to task',
        () async {
          final imageEntity = JournalImage(
            meta: createMetadata(),
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
              title: 'Test Task',
              statusHistory: [],
              dateFrom: DateTime(2024, 3, 15, 10, 30),
              dateTo: DateTime(2024, 3, 15, 10, 30),
            ),
          );

          final imagePrompt = createPrompt(
            id: 'image-prompt',
            name: 'Image Analysis',
            requiredInputData: [InputDataType.images],
            aiResponseType: AiResponseType.imageAnalysis,
          );

          final imageTaskPrompt = createPrompt(
            id: 'image-task-prompt',
            name: 'Image Analysis with Task Context',
            requiredInputData: [InputDataType.images, InputDataType.task],
            aiResponseType: AiResponseType.imageAnalysis,
          );

          when(
            () => mockAiConfigRepo.getConfigsByType(AiConfigType.prompt),
          ).thenAnswer((_) async => [imagePrompt, imageTaskPrompt]);

          // Test with linked task
          when(
            () => mockJournalRepo.getLinkedToEntities(linkedTo: 'test-id'),
          ).thenAnswer((_) async => [taskEntity]);

          final resultWithTask = await repository!.getActivePromptsForContext(
            entity: imageEntity,
          );

          expect(resultWithTask.length, 2);
          expect(resultWithTask.map((p) => p.id).toSet(), {
            'image-prompt',
            'image-task-prompt',
          });

          // Test without linked task
          when(
            () => mockJournalRepo.getLinkedToEntities(linkedTo: 'test-id'),
          ).thenAnswer((_) async => []);

          final resultWithoutTask = await repository!
              .getActivePromptsForContext(entity: imageEntity);

          expect(resultWithoutTask.length, 1);
          expect(resultWithoutTask.first.id, 'image-prompt');
        },
      );

      test(
        'returns task context prompts only when audio is linked to task',
        () async {
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

          final taskEntity = Task(
            meta: createMetadata().copyWith(id: 'task-id'),
            data: TaskData(
              status: TaskStatus.inProgress(
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

          final audioPrompt = createPrompt(
            id: 'audio-prompt',
            name: 'Audio Transcription',
            requiredInputData: [InputDataType.audioFiles],
            aiResponseType: AiResponseType.audioTranscription,
          );

          final audioTaskPrompt = createPrompt(
            id: 'audio-task-prompt',
            name: 'Audio Transcription with Task Context',
            requiredInputData: [InputDataType.audioFiles, InputDataType.task],
            aiResponseType: AiResponseType.audioTranscription,
          );

          when(
            () => mockAiConfigRepo.getConfigsByType(AiConfigType.prompt),
          ).thenAnswer((_) async => [audioPrompt, audioTaskPrompt]);

          // Test with linked task
          when(
            () => mockJournalRepo.getLinkedToEntities(linkedTo: 'test-id'),
          ).thenAnswer((_) async => [taskEntity]);

          final resultWithTask = await repository!.getActivePromptsForContext(
            entity: audioEntity,
          );

          expect(resultWithTask.length, 2);
          expect(resultWithTask.map((p) => p.id).toSet(), {
            'audio-prompt',
            'audio-task-prompt',
          });

          // Test without linked task
          when(
            () => mockJournalRepo.getLinkedToEntities(linkedTo: 'test-id'),
          ).thenAnswer((_) async => []);

          final resultWithoutTask = await repository!
              .getActivePromptsForContext(entity: audioEntity);

          expect(resultWithoutTask.length, 1);
          expect(resultWithoutTask.first.id, 'audio-prompt');
        },
      );

      test(
        'returns all matching prompts when entity has no category',
        () async {
          final taskEntity = Task(
            meta: createMetadata(), // No categoryId
            data: TaskData(
              status: TaskStatus.inProgress(
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

          final taskPrompt1 = createPrompt(
            id: 'task-prompt-1',
            name: 'Task Summary 1',
            requiredInputData: [InputDataType.task],
          );

          final taskPrompt2 = createPrompt(
            id: 'task-prompt-2',
            name: 'Task Summary 2',
            requiredInputData: [InputDataType.task],
          );

          when(
            () => mockAiConfigRepo.getConfigsByType(AiConfigType.prompt),
          ).thenAnswer((_) async => [taskPrompt1, taskPrompt2]);

          final result = await repository!.getActivePromptsForContext(
            entity: taskEntity,
          );

          expect(result.length, 2);
          expect(result.map((p) => p.id).toSet(), {
            'task-prompt-1',
            'task-prompt-2',
          });
        },
      );

      test('returns all prompts when category not found', () async {
        const categoryId = 'category-1';
        final taskEntity = Task(
          meta: createMetadata(categoryId: categoryId),
          data: TaskData(
            status: TaskStatus.inProgress(
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

        final taskPrompt = createPrompt(
          id: 'task-prompt',
          name: 'Task Summary',
          requiredInputData: [InputDataType.task],
        );

        // Category not found - returns null
        when(
          () => mockCategoryRepo.getCategoryById(categoryId),
        ).thenAnswer((_) async => null);
        when(
          () => mockAiConfigRepo.getConfigsByType(AiConfigType.prompt),
        ).thenAnswer((_) async => [taskPrompt]);

        final result = await repository!.getActivePromptsForContext(
          entity: taskEntity,
        );

        // Should return all matching prompts when category not found
        expect(result.length, 1);
        expect(result.first.id, 'task-prompt');
      });

      // Platform filtering integration tests
      test('filters prompts by platform capability on mobile', () async {
        final taskEntity = Task(
          meta: createMetadata(),
          data: TaskData(
            status: TaskStatus.inProgress(
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

        final cloudPrompt = createPrompt(
          id: 'cloud-prompt',
          name: 'Cloud Task Prompt',
          requiredInputData: [InputDataType.task],
        );

        final localPrompt = createPrompt(
          id: 'local-prompt',
          name: 'Local Task Prompt',
          requiredInputData: [InputDataType.task],
        );

        when(
          () => mockAiConfigRepo.getConfigsByType(AiConfigType.prompt),
        ).thenAnswer((_) async => [cloudPrompt, localPrompt]);

        // Mock platform filter to simulate mobile filtering
        when(
          () => mockPromptCapabilityFilter.filterPromptsByPlatform(any()),
        ).thenAnswer((invocation) async {
          final prompts =
              invocation.positionalArguments[0] as List<AiConfigPrompt>;
          // Simulate mobile: filter out local-prompt
          return prompts.where((p) => p.id == 'cloud-prompt').toList();
        });

        final result = await repository!.getActivePromptsForContext(
          entity: taskEntity,
        );

        expect(result.length, 1);
        expect(result.first.id, 'cloud-prompt');

        // Verify filter was called
        verify(
          () => mockPromptCapabilityFilter.filterPromptsByPlatform(any()),
        ).called(1);
      });

      test('returns all prompts on desktop (no filtering)', () async {
        final taskEntity = Task(
          meta: createMetadata(),
          data: TaskData(
            status: TaskStatus.inProgress(
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

        final cloudPrompt = createPrompt(
          id: 'cloud-prompt',
          name: 'Cloud Task Prompt',
          requiredInputData: [InputDataType.task],
        );

        final localPrompt = createPrompt(
          id: 'local-prompt',
          name: 'Local Task Prompt',
          requiredInputData: [InputDataType.task],
        );

        when(
          () => mockAiConfigRepo.getConfigsByType(AiConfigType.prompt),
        ).thenAnswer((_) async => [cloudPrompt, localPrompt]);

        // Mock platform filter to simulate desktop (no filtering)
        when(
          () => mockPromptCapabilityFilter.filterPromptsByPlatform(any()),
        ).thenAnswer((invocation) async {
          final prompts =
              invocation.positionalArguments[0] as List<AiConfigPrompt>;
          return prompts; // Desktop: return all
        });

        final result = await repository!.getActivePromptsForContext(
          entity: taskEntity,
        );

        expect(result.length, 2);
        expect(result.map((p) => p.id).toSet(), {
          'cloud-prompt',
          'local-prompt',
        });

        // Verify filter was called
        verify(
          () => mockPromptCapabilityFilter.filterPromptsByPlatform(any()),
        ).called(1);
      });

      test('platform filter is called exactly once per invocation', () async {
        final taskEntity = Task(
          meta: createMetadata(),
          data: TaskData(
            status: TaskStatus.inProgress(
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

        final prompt1 = createPrompt(
          id: 'prompt-1',
          name: 'Prompt 1',
          requiredInputData: [InputDataType.task],
        );

        final prompt2 = createPrompt(
          id: 'prompt-2',
          name: 'Prompt 2',
          requiredInputData: [InputDataType.task],
        );

        when(
          () => mockAiConfigRepo.getConfigsByType(AiConfigType.prompt),
        ).thenAnswer((_) async => [prompt1, prompt2]);

        await repository!.getActivePromptsForContext(entity: taskEntity);

        // Verify exactly one call to filter
        verify(
          () => mockPromptCapabilityFilter.filterPromptsByPlatform(any()),
        ).called(1);
      });

      test('handles platform filter with mixed prompt types', () async {
        final taskEntity = Task(
          meta: createMetadata(),
          data: TaskData(
            status: TaskStatus.inProgress(
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

        final taskPrompt = createPrompt(
          id: 'task-prompt',
          name: 'Task Prompt',
          requiredInputData: [InputDataType.task],
        );

        final imagePrompt = createPrompt(
          id: 'image-prompt',
          name: 'Image Prompt',
          requiredInputData: [InputDataType.images],
          aiResponseType: AiResponseType.imageAnalysis,
        );

        when(
          () => mockAiConfigRepo.getConfigsByType(AiConfigType.prompt),
        ).thenAnswer((_) async => [taskPrompt, imagePrompt]);

        // Platform filter simulates filtering (returns only task-prompt)
        when(
          () => mockPromptCapabilityFilter.filterPromptsByPlatform(any()),
        ).thenAnswer((invocation) async {
          final prompts =
              invocation.positionalArguments[0] as List<AiConfigPrompt>;
          // After entity type filtering, only task-prompt should be passed
          expect(prompts.length, 1);
          expect(prompts.first.id, 'task-prompt');
          return prompts;
        });

        final result = await repository!.getActivePromptsForContext(
          entity: taskEntity,
        );

        expect(result.length, 1);
        expect(result.first.id, 'task-prompt');
      });
    });
  });
  // ---------------------------------------------------------------------------
  // New coverage tests for previously uncovered branches
  // ---------------------------------------------------------------------------

  group('Constructor with AgentDatabase registered in GetIt', () {
    test(
      'creates repository using AgentRepository when AgentDatabase is registered',
      () {
        // Register a mock AgentDatabase in GetIt before constructing the repo
        final mockAgentDb = MockAgentDatabase();
        // Registered in this test's GetIt scope; tearDown pops the scope.
        getIt.registerSingleton<AgentDatabase>(mockAgentDb);

        // Constructing the repository should hit the branch at line 69
        final ref = container.read(testRefProvider);
        final repo = UnifiedAiInferenceRepository(ref)
          ..autoChecklistServiceForTesting = mockAutoChecklistService;

        // The object should be constructed without error
        expect(repo, isNotNull);
      },
    );
  });

  group('autoChecklistService lazy getter', () {
    test('creates AutoChecklistService lazily when not set via testing setter', () {
      // AutoChecklistService internally calls getIt<DomainLogger>(), register it.
      final mockDomainLogger = MockDomainLogger();
      // Registered in this test's GetIt scope; tearDown pops the scope.
      getIt.registerSingleton<DomainLogger>(mockDomainLogger);

      // Create a fresh repository WITHOUT calling autoChecklistServiceForTesting
      final ref = container.read(testRefProvider);
      final repo = UnifiedAiInferenceRepository(ref);
      // Accessing the getter should initialise _autoChecklistService (line 89)
      final svc = repo.autoChecklistService;
      expect(svc, isNotNull);
      // Second access returns the same instance (lazy initialised once)
      expect(repo.autoChecklistService, same(svc));
    });
  });

  group('_isPromptActiveForEntity – JournalAudio + promptGeneration + hasTask', () {
    test(
      'returns true when audio is linked to a task and prompt is promptGeneration',
      () async {
        // This covers lines 182-185 (special case for audio + promptGeneration)
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

        final linkedTask = Task(
          meta: createMetadata().copyWith(id: 'task-id'),
          data: TaskData(
            status: TaskStatus.inProgress(
              id: 'status-1',
              createdAt: DateTime(2024, 3, 15, 10, 30),
              utcOffset: 0,
            ),
            title: 'Linked Task',
            statusHistory: [],
            dateFrom: DateTime(2024, 3, 15, 10, 30),
            dateTo: DateTime(2024, 3, 15, 10, 30),
          ),
        );

        // promptGeneration requires task context but NOT audio files
        final promptGenPrompt = createPrompt(
          id: 'prompt-gen',
          name: 'Coding Prompt Generation',
          requiredInputData: [InputDataType.task],
          aiResponseType: AiResponseType.promptGeneration,
        );

        when(
          () => mockAiConfigRepo.getConfigsByType(AiConfigType.prompt),
        ).thenAnswer((_) async => [promptGenPrompt]);

        // Audio linked to task → should return the prompt
        when(
          () => mockJournalRepo.getLinkedToEntities(linkedTo: 'test-id'),
        ).thenAnswer((_) async => [linkedTask]);

        final result = await repository!.getActivePromptsForContext(
          entity: audioEntity,
        );

        expect(result.length, 1);
        expect(result.first.id, 'prompt-gen');
      },
    );

    test(
      'returns false when audio has no linked task and prompt is promptGeneration',
      () async {
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

        final promptGenPrompt = createPrompt(
          id: 'prompt-gen',
          name: 'Coding Prompt Generation',
          requiredInputData: [InputDataType.task],
          aiResponseType: AiResponseType.promptGeneration,
        );

        when(
          () => mockAiConfigRepo.getConfigsByType(AiConfigType.prompt),
        ).thenAnswer((_) async => [promptGenPrompt]);

        // No linked task → should NOT return prompt
        when(
          () => mockJournalRepo.getLinkedToEntities(linkedTo: 'test-id'),
        ).thenAnswer((_) async => []);

        final result = await repository!.getActivePromptsForContext(
          entity: audioEntity,
        );

        expect(result.isEmpty, true);
      },
    );
  });

  group('runInference – legacy type guard', () {
    test(
      'skips inference for legacy taskSummary response type (lines 208-210)',
      () async {
        final legacyPrompt = AiConfigPrompt(
          id: 'legacy-task-summary',
          name: 'Legacy Task Summary',
          systemMessage: 'System',
          userMessage: 'User',
          defaultModelId: 'model-1',
          modelIds: ['model-1'],
          createdAt: DateTime(2024, 3, 15),
          useReasoning: false,
          requiredInputData: const [InputDataType.task],
          // ignore: deprecated_member_use_from_same_package
          aiResponseType: AiResponseType.taskSummary,
        );

        final statusChanges = <InferenceStatus>[];

        // Should return without calling any inference machinery
        await repository!.runInference(
          entityId: 'test-id',
          promptConfig: legacyPrompt,
          onProgress: (_) {},
          onStatusChange: statusChanges.add,
        );

        // Status never changed because we returned early
        expect(statusChanges, isEmpty);
        verifyNever(() => mockAiInputRepo.getEntity(any()));
      },
    );

    test('skips inference for legacy checklistUpdates response type', () async {
      final legacyPrompt = AiConfigPrompt(
        id: 'legacy-checklist',
        name: 'Legacy Checklist Updates',
        systemMessage: 'System',
        userMessage: 'User',
        defaultModelId: 'model-1',
        modelIds: ['model-1'],
        createdAt: DateTime(2024, 3, 15),
        useReasoning: false,
        requiredInputData: const [InputDataType.task],
        // ignore: deprecated_member_use_from_same_package
        aiResponseType: AiResponseType.checklistUpdates,
      );

      final statusChanges = <InferenceStatus>[];

      await repository!.runInference(
        entityId: 'test-id',
        promptConfig: legacyPrompt,
        onProgress: (_) {},
        onStatusChange: statusChanges.add,
      );

      expect(statusChanges, isEmpty);
      verifyNever(() => mockAiInputRepo.getEntity(any()));
    });
  });

  group('runInference – entity not found error', () {
    test('throws when entity cannot be found (line 253)', () async {
      final promptConfig = createPrompt(
        id: 'prompt-1',
        name: 'Task Summary',
        requiredInputData: [InputDataType.task],
      );

      // getEntity returns null → should throw 'Entity not found'
      when(
        () => mockAiInputRepo.getEntity('missing-entity-id'),
      ).thenAnswer((_) async => null);
      when(() => mockAiConfigRepo.getConfigById('model-1')).thenAnswer(
        (_) async => createModel(
          id: 'model-1',
          inferenceProviderId: 'provider-1',
          providerModelId: 'gpt-4',
        ),
      );

      await expectLater(
        repository!.runInference(
          entityId: 'missing-entity-id',
          promptConfig: promptConfig,
          onProgress: (_) {},
          onStatusChange: (_) {},
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Entity not found: missing-entity-id'),
          ),
        ),
      );
    });
  });

  group('runInference – usage tokens captured (line 333)', () {
    test('captures usage data from stream chunk', () async {
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
        id: 'prompt-1',
        name: 'Task Summary',
        requiredInputData: [InputDataType.task],
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

      // A stream that includes a chunk with usage data
      // ignore: prefer_const_constructors
      final chunkWithUsage = CreateChatCompletionStreamResponse(
        id: 'response-with-usage',
        choices: [
          const ChatCompletionStreamResponseChoice(
            index: 0,
            delta: ChatCompletionStreamResponseDelta(content: 'Answer'),
            finishReason: ChatCompletionFinishReason.stop,
          ),
        ],
        usage: const CompletionUsage(
          promptTokens: 50,
          completionTokens: 20,
          totalTokens: 70,
        ),
        object: 'chat.completion.chunk',
        created: 1710493800,
      );
      final mockStream = Stream.fromIterable([chunkWithUsage]);

      stubInferenceContext(
        mockAiInputRepo: mockAiInputRepo,
        mockAiConfigRepo: mockAiConfigRepo,
        entity: taskEntity,
        model: model,
        provider: provider,
      );
      stubGenerate(mockCloudInferenceRepo, stream: mockStream);

      AiResponseData? capturedData;
      when(
        () => mockAiInputRepo.createAiResponseEntry(
          data: captureAny(named: 'data'),
          start: any(named: 'start'),
          linkedId: any(named: 'linkedId'),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer((invocation) async {
        capturedData = invocation.namedArguments[#data] as AiResponseData;
        return null;
      });

      await repository!.runInference(
        entityId: taskEntity.id,
        promptConfig: promptConfig,
        onProgress: (_) {},
        onStatusChange: (_) {},
      );

      // Usage tokens should have been captured and placed in the response data
      expect(capturedData, isNotNull);
      expect(capturedData!.inputTokens, 50);
      expect(capturedData!.outputTokens, 20);
    });
  });

  group('extractJsonObjects', () {
    test('returns empty list for empty and brace-free input', () {
      expect(extractJsonObjects(''), isEmpty);
      expect(extractJsonObjects('no json here, just text'), isEmpty);
    });

    test('ignores stray closing braces before an object', () {
      expect(extractJsonObjects('}{"a":1}'), ['{"a":1}']);
    });

    test('keeps nested objects as a single result', () {
      expect(extractJsonObjects('{"a": {"b": 2}}'), ['{"a": {"b": 2}}']);
    });

    test('ignores braces inside string literals', () {
      expect(extractJsonObjects('{"reason": "The user selected {Item}"}'), [
        '{"reason": "The user selected {Item}"}',
      ]);
      // Unbalanced brace inside a string must not open/close objects.
      expect(extractJsonObjects('{"a": "}"}{"b": 2}'), [
        '{"a": "}"}',
        '{"b": 2}',
      ]);
    });

    test('handles escaped quotes inside string literals', () {
      expect(extractJsonObjects(r'{"a": "say \"hi\" {x}"}'), [
        r'{"a": "say \"hi\" {x}"}',
      ]);
    });

    glados.Glados(
      glados.any.jsonObjectsScenario,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'N concatenated well-formed JSON objects round-trip in order',
      (scenario) {
        final extracted = extractJsonObjects(scenario.concatenated);

        expect(
          extracted.length,
          scenario.objects.length,
          reason: 'input: ${scenario.concatenated}',
        );
        for (var i = 0; i < extracted.length; i++) {
          expect(
            jsonDecode(extracted[i]),
            scenario.objects[i],
            reason: 'object $i of input: ${scenario.concatenated}',
          );
        }
      },
      tags: 'glados',
    );
  });
}

/// A generated list of well-formed JSON objects plus their concatenation
/// with brace-free separator noise — the exact shape AI providers produce
/// when they glue several tool-call argument objects together.
class _JsonObjectsScenario {
  _JsonObjectsScenario({
    required int count,
    required int seed,
    required this.separator,
  }) : objects = List.generate(count, (i) => _buildObject(seed, i));

  final List<Map<String, Object?>> objects;
  final String separator;

  static Map<String, Object?> _buildObject(int seed, int i) {
    return switch ((seed + i) % 4) {
      0 => {'key$i': 'text value $i'},
      1 => {'key$i': seed + i},
      2 => {'key$i': i.isEven},
      // Nested braces are balanced, so they must survive extraction.
      _ => {
        'key$i': {'inner': i},
      },
    };
  }

  String get concatenated =>
      separator + objects.map(jsonEncode).join(separator) + separator;

  @override
  String toString() =>
      '_JsonObjectsScenario(objects: $objects, separator: "$separator")';
}

extension _AnyJsonObjectsScenario on glados.Any {
  glados.Generator<_JsonObjectsScenario> get jsonObjectsScenario => combine3(
    intInRange(0, 7),
    intInRange(0, 1000),
    choose(const ['', ' ', '\n', ', ', ' noise without braces ']),
    (int count, int seed, String separator) =>
        _JsonObjectsScenario(count: count, seed: seed, separator: separator),
  );
}
