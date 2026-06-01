// ignore_for_file: unawaited_futures, avoid_redundant_argument_values

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Selectable;
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/conversions.dart' show toDbEntity;
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/ai/functions/checklist_completion_functions.dart';
import 'package:lotti/features/ai/functions/label_functions.dart';
import 'package:lotti/features/ai/functions/task_functions.dart';
import 'package:lotti/features/ai/helpers/prompt_capability_filter.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/ai_input.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart'
    show aiInputRepositoryProvider;
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/unified_ai_inference_repository.dart';
import 'package:lotti/features/ai/services/checklist_completion_service.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
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
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
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

void main() {
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

  setUpAll(() {
    // Isolate registrations from other files when tests are optimized
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
  });

  late Directory? baseTempDir;
  late List<Directory> overrideTempDirs;

  setUp(() {
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

    // Mock directory path to a writable temp location (unique per test)
    baseTempDir = Directory.systemTemp.createTempSync('lotti_ai_repo_test_');
    overrideTempDirs = <Directory>[];
    when(() => mockDirectory.path).thenReturn(baseTempDir!.path);

    when(
      () => mockJournalDb.getConfigFlag(enableAiStreamingFlag),
    ).thenAnswer((_) async => false);

    // Default mock for getLinkedEntities - returns empty so fallback to getLinkedToEntities
    when(
      () => mockJournalRepo.getLinkedEntities(linkedTo: any(named: 'linkedTo')),
    ).thenAnswer((_) async => <JournalEntity>[]);

    // Set up default behavior for prompt capability filter to pass through all prompts
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

    // Create repository - tests can recreate if needed after setting up specific mocks
    final ref = container.read(testRefProvider);
    repository = UnifiedAiInferenceRepository(ref)
      ..autoChecklistServiceForTesting = mockAutoChecklistService;
  });

  tearDown(() {
    container.dispose();
    // Clean up temp directories if they were created
    // Note: Only remove if it still exists and is empty-ish; ignore errors
    try {
      // Always attempt to remove the base temp dir
      if (baseTempDir != null && baseTempDir!.existsSync()) {
        baseTempDir!.deleteSync(recursive: true);
      }
      // Remove any override dirs registered by tests
      for (final d in overrideTempDirs) {
        if (d.existsSync()) {
          d.deleteSync(recursive: true);
        }
      }
      // Reset stub so following tests don't reuse an overridden path
      when(() => mockDirectory.path).thenReturn(Directory.systemTemp.path);
    } catch (_) {}

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

  tearDownAll(() async {
    // Pop scoped registrations for this file
    await getIt.resetScope();
    await getIt.popScope();
  });

  group('UnifiedAiInferenceRepository', () {
    test('assign_task_labels no-op when all candidates suppressed', () async {
      // Arrange task with suppressed X and Y
      final taskEntity = Task(
        meta: _createMetadata(),
        data: TaskData(
          status: TaskStatus.open(
            id: 'status-1',
            createdAt: DateTime(2024, 3, 15, 10, 30),
            utcOffset: 0,
          ),
          title: 'Test Task',
          statusHistory: const [],
          dateFrom: DateTime(2024, 3, 15, 10, 30),
          dateTo: DateTime(2024, 3, 15, 10, 30),
          aiSuppressedLabelIds: const {'X', 'Y'},
        ),
      );

      final promptConfig = _createPrompt(
        id: 'checklist-updates',
        name: 'Checklist Updates',
        aiResponseType: AiResponseType.imageAnalysis,
      );

      final model = _createModel(
        id: 'model-1',
        inferenceProviderId: 'provider-1',
        providerModelId: 'gpt-4',
      ).copyWith(supportsFunctionCalling: true);

      final provider = _createProvider(
        id: 'provider-1',
        inferenceProviderType: InferenceProviderType.openAi,
      );

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
      ).thenAnswer((_) async => '{"task":"details"}');

      // Shadow flag
      when(
        () => mockJournalDb.getConfigFlag('ai_label_assignment_shadow'),
      ).thenAnswer((_) async => false);

      // Stream a single assign_task_labels tool call for X and Y
      final streamController =
          StreamController<CreateChatCompletionStreamResponse>()
            ..add(
              _createStreamChunkWithToolCalls([
                _createMockToolCall(
                  index: 0,
                  id: 'tool-1',
                  functionName: 'assign_task_labels',
                  arguments: '{"labelIds":["X","Y"]}',
                ),
              ]),
            )
            ..close();

      _stubGenerate(
        mockCloudInferenceRepo,
        stream: streamController.stream,
      );

      // Act
      await repository!.runInference(
        entityId: 'test-id',
        promptConfig: promptConfig,
        onProgress: (_) {},
        onStatusChange: (_) {},
      );

      // Assert: no persistence because both candidates suppressed
      verifyNever(
        () => mockLabelsRepository.addLabels(
          journalEntityId: any(named: 'journalEntityId'),
          addedLabelIds: any(named: 'addedLabelIds'),
        ),
      );
    });

    test('processToolCalls updates checklist items', () async {
      final taskEntity = Task(
        meta: _createMetadata(id: 'task-1'),
        data: TaskData(
          status: TaskStatus.open(
            id: 'status-1',
            createdAt: DateTime(2024, 3, 15, 10, 30),
            utcOffset: 0,
          ),
          title: 'Test Task',
          statusHistory: const [],
          dateFrom: DateTime(2024, 3, 15, 10, 30),
          dateTo: DateTime(2024, 3, 15, 10, 30),
          checklistIds: const ['checklist-1'],
        ),
      );

      // Mock the database query for items - return empty so items are skipped
      // (detailed update behavior is tested in LottiChecklistUpdateHandler tests)
      final mockSelectable = MockSelectableSimple<JournalDbEntity>();
      when(mockSelectable.get).thenAnswer((_) async => []);
      when(() => mockJournalDb.entriesForIds(any())).thenReturn(mockSelectable);

      final toolCalls = [
        _createMockMessageToolCall(
          id: 'tool-update',
          functionName: 'update_checklist_items',
          arguments:
              '{"items":[{"id":"item-1","isChecked":true},{"id":"item-2","isChecked":true}]}',
        ),
      ];

      // Should not throw - the handler will process but skip items not found
      await repository!.processToolCalls(
        toolCalls: toolCalls,
        task: taskEntity,
      );

      // Verify DB was queried for the items
      verify(() => mockJournalDb.entriesForIds(['item-1', 'item-2'])).called(1);
    });
    group('getActivePromptsForContext', () {
      test('returns prompts matching task entity', () async {
        final taskEntity = Task(
          meta: _createMetadata(),
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
          meta: _createMetadata(),
          data: ImageData(
            capturedAt: DateTime(2024, 3, 15, 10, 30),
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
          meta: _createMetadata(),
          data: AudioData(
            dateFrom: DateTime(2024, 3, 15, 10, 30),
            dateTo: DateTime(2024, 3, 15, 10, 30),
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
          meta: _createMetadata(),
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

        final multiInputPrompt = _createPrompt(
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
          meta: _createMetadata(),
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

        final mismatchedPrompt = _createPrompt(
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
          meta: _createMetadata(),
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
          meta: _createMetadata(),
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

        final taskPrompt = _createPrompt(
          id: 'task-prompt',
          name: 'Task Analysis',
          requiredInputData: [InputDataType.task],
          aiResponseType: AiResponseType.imageAnalysis,
        );

        final imagePromptGenPrompt = _createPrompt(
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
          meta: _createMetadata(),
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

        final taskPrompt = _createPrompt(
          id: 'task-prompt',
          name: 'Task Analysis',
          requiredInputData: [InputDataType.task],
          aiResponseType: AiResponseType.imageAnalysis,
        );

        final promptGenPrompt = _createPrompt(
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
        final journalEntry = JournalEntry(
          meta: _createMetadata(),
        );

        final taskPrompt = _createPrompt(
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
            meta: _createMetadata(),
            data: ImageData(
              capturedAt: DateTime(2024, 3, 15, 10, 30),
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
                createdAt: DateTime(2024, 3, 15, 10, 30),
                utcOffset: 0,
              ),
              title: 'Test Task',
              statusHistory: [],
              dateFrom: DateTime(2024, 3, 15, 10, 30),
              dateTo: DateTime(2024, 3, 15, 10, 30),
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
              .getActivePromptsForContext(
                entity: imageEntity,
              );

          expect(resultWithoutTask.length, 1);
          expect(resultWithoutTask.first.id, 'image-prompt');
        },
      );

      test(
        'returns task context prompts only when audio is linked to task',
        () async {
          final audioEntity = JournalAudio(
            meta: _createMetadata(),
            data: AudioData(
              dateFrom: DateTime(2024, 3, 15, 10, 30),
              dateTo: DateTime(2024, 3, 15, 10, 30),
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
                createdAt: DateTime(2024, 3, 15, 10, 30),
                utcOffset: 0,
              ),
              title: 'Test Task',
              statusHistory: [],
              dateFrom: DateTime(2024, 3, 15, 10, 30),
              dateTo: DateTime(2024, 3, 15, 10, 30),
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
              .getActivePromptsForContext(
                entity: audioEntity,
              );

          expect(resultWithoutTask.length, 1);
          expect(resultWithoutTask.first.id, 'audio-prompt');
        },
      );

      test(
        'returns all matching prompts when entity has no category',
        () async {
          final taskEntity = Task(
            meta: _createMetadata(), // No categoryId
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

          final taskPrompt1 = _createPrompt(
            id: 'task-prompt-1',
            name: 'Task Summary 1',
            requiredInputData: [InputDataType.task],
          );

          final taskPrompt2 = _createPrompt(
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
          meta: _createMetadata(categoryId: categoryId),
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

        final taskPrompt = _createPrompt(
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
          meta: _createMetadata(),
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

        final cloudPrompt = _createPrompt(
          id: 'cloud-prompt',
          name: 'Cloud Task Prompt',
          requiredInputData: [InputDataType.task],
        );

        final localPrompt = _createPrompt(
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
          meta: _createMetadata(),
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

        final cloudPrompt = _createPrompt(
          id: 'cloud-prompt',
          name: 'Cloud Task Prompt',
          requiredInputData: [InputDataType.task],
        );

        final localPrompt = _createPrompt(
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
          meta: _createMetadata(),
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

        final prompt1 = _createPrompt(
          id: 'prompt-1',
          name: 'Prompt 1',
          requiredInputData: [InputDataType.task],
        );

        final prompt2 = _createPrompt(
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
          meta: _createMetadata(),
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

        final taskPrompt = _createPrompt(
          id: 'task-prompt',
          name: 'Task Prompt',
          requiredInputData: [InputDataType.task],
        );

        final imagePrompt = _createPrompt(
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

    group('runInference', () {
      test('successfully runs inference for text prompt', () async {
        final taskEntity = Task(
          meta: _createMetadata(),
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

        final mockStream = _createMockTextStream(['Hello', ' world', '!']);

        _stubInferenceContext(
          mockAiInputRepo: mockAiInputRepo,
          mockAiConfigRepo: mockAiConfigRepo,
          entity: taskEntity,
          model: model,
          provider: provider,
        );
        _stubGenerate(mockCloudInferenceRepo, stream: mockStream);
        _stubCreateAiResponseEntry(mockAiInputRepo);

        when(
          () => mockJournalDb.getConfigFlag(enableAiStreamingFlag),
        ).thenAnswer((_) async => true);

        await repository!.runInference(
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
            provider: provider,
            geminiThinkingMode: GeminiThinkingMode.low,
          ),
        ).called(1);
      });

      test(
        'runInference emits single progress update when streaming flag is disabled',
        () async {
          final taskEntity = Task(
            meta: _createMetadata(),
            data: TaskData(
              status: TaskStatus.inProgress(
                id: 'status-1',
                createdAt: DateTime(2024, 1, 1),
                utcOffset: 0,
              ),
              title: 'Test Task',
              statusHistory: const [],
              dateFrom: DateTime(2024, 1, 1),
              dateTo: DateTime(2024, 1, 1),
            ),
          );

          final model = AiConfigModel(
            id: 'model-1',
            name: 'Test Model',
            providerModelId: 'gpt-4',
            inferenceProviderId: 'provider-1',
            createdAt: DateTime(2024),
            inputModalities: const [Modality.text],
            outputModalities: const [Modality.text],
            isReasoningModel: false,
            supportsFunctionCalling: false,
          );

          final provider = AiConfigInferenceProvider(
            id: 'provider-1',
            name: 'Test Provider',
            baseUrl: 'https://api.example.com',
            apiKey: 'test-api-key',
            createdAt: DateTime(2024),
            inferenceProviderType: InferenceProviderType.openAi,
          );

          final promptConfig = _createPrompt(
            id: 'prompt-1',
            name: 'Test Prompt',
            defaultModelId: 'model-1',
            requiredInputData: const [InputDataType.tasksList],
            aiResponseType: AiResponseType.imageAnalysis,
          );

          final progressUpdates = <String>[];
          final statusChanges = <InferenceStatus>[];

          final mockStream = _createMockTextStream(['Hello', ' world', '!']);

          _stubInferenceContext(
            mockAiInputRepo: mockAiInputRepo,
            mockAiConfigRepo: mockAiConfigRepo,
            entity: taskEntity,
            model: model,
            provider: provider,
          );
          _stubGenerate(mockCloudInferenceRepo, stream: mockStream);
          _stubCreateAiResponseEntry(mockAiInputRepo);
          when(
            () => mockJournalDb.getConfigFlag(enableAiStreamingFlag),
          ).thenAnswer((_) async => false);

          await repository!.runInference(
            entityId: 'test-id',
            promptConfig: promptConfig,
            onProgress: progressUpdates.add,
            onStatusChange: statusChanges.add,
          );

          expect(progressUpdates, ['Hello world!']);
          expect(statusChanges, [
            InferenceStatus.running,
            InferenceStatus.idle,
          ]);
        },
      );

      test('successfully runs inference with images', () async {
        // Create a temporary directory for the test
        final tempDir = Directory.systemTemp.createTempSync('image_test');
        overrideTempDirs.add(tempDir);

        // Update the mock directory to point to our temp directory
        when(() => mockDirectory.path).thenReturn(tempDir.path);

        final imageEntity = JournalImage(
          meta: _createMetadata(),
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

        final mockStream = _createMockTextStream(['Image shows', ' a cat']);

        _stubInferenceContext(
          mockAiInputRepo: mockAiInputRepo,
          mockAiConfigRepo: mockAiConfigRepo,
          entity: imageEntity,
          model: model,
          provider: provider,
          taskDetailsJson: '{"image": "test.jpg"}',
        );
        when(
          () => mockJournalRepo.getLinkedToEntities(linkedTo: 'test-id'),
        ).thenAnswer((_) async => []); // No linked task
        _stubGenerateWithImages(mockCloudInferenceRepo, stream: mockStream);
        _stubCreateAiResponseEntry(mockAiInputRepo);

        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);

        when(
          () => mockJournalDb.getConfigFlag(enableAiStreamingFlag),
        ).thenAnswer((_) async => true);

        try {
          await repository!.runInference(
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
              provider: any(named: 'provider'),
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
        overrideTempDirs.add(tempDir);

        // Update the mock directory to point to our temp directory
        when(() => mockDirectory.path).thenReturn(tempDir.path);

        final audioEntity = JournalAudio(
          meta: _createMetadata(),
          data: AudioData(
            dateFrom: DateTime(2024, 3, 15, 10, 30),
            dateTo: DateTime(2024, 3, 15, 10, 30),
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

        final mockStream = _createMockTextStream(['Hello world']);

        _stubInferenceContext(
          mockAiInputRepo: mockAiInputRepo,
          mockAiConfigRepo: mockAiConfigRepo,
          entity: audioEntity,
          model: model,
          provider: provider,
          taskDetailsJson: '{"audio": "test.mp3"}',
        );
        _stubGenerateWithAudio(mockCloudInferenceRepo, stream: mockStream);
        _stubCreateAiResponseEntry(mockAiInputRepo);

        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);

        // Mock getLinkedToEntities to return empty list (no linked tasks)
        when(
          () => mockJournalRepo.getLinkedToEntities(linkedTo: 'test-id'),
        ).thenAnswer((_) async => []);

        try {
          await repository!.runInference(
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
              provider: any(named: 'provider'),
              any(),
              model: 'whisper-1',
              audioBase64: any(named: 'audioBase64'),
              baseUrl: 'https://api.example.com',
              apiKey: 'test-api-key',
              stream: any(named: 'stream'),
              audioFormat: any(named: 'audioFormat'),
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
              createdAt: DateTime(2024, 3, 15, 10, 30),
              utcOffset: 0,
            ),
            title: 'Test Task',
            statusHistory: [],
            dateFrom: DateTime(2024, 3, 15, 10, 30),
            dateTo: DateTime(2024, 3, 15, 10, 30),
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

        final mockStream = _createMockTextStream([
          '<think>Let me analyze this task</think>Task completed successfully',
        ]);

        _stubInferenceContext(
          mockAiInputRepo: mockAiInputRepo,
          mockAiConfigRepo: mockAiConfigRepo,
          entity: taskEntity,
          model: model,
          provider: provider,
        );
        _stubGenerate(mockCloudInferenceRepo, stream: mockStream);
        _stubCreateAiResponseEntry(mockAiInputRepo);
        when(
          () => mockJournalDb.getConfigFlag(enableAiStreamingFlag),
        ).thenAnswer((_) async => true);

        await repository!.runInference(
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
        // Thoughts should have <think> tags stripped during extraction
        expect(data.thoughts, 'Let me analyze this task');
        expect(data.response, 'Task completed successfully');
      });

      test('handles provider not found error', () {
        fakeAsync((async) {
          final taskEntity = Task(
            meta: _createMetadata(),
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

          when(
            () => mockAiInputRepo.getEntity('test-id'),
          ).thenAnswer((_) async => taskEntity);
          when(
            () => mockAiConfigRepo.getConfigById('model-1'),
          ).thenAnswer((_) async => model);
          when(
            () => mockAiConfigRepo.getConfigById('provider-1'),
          ).thenAnswer((_) async => null);

          expect(
            () => repository!.runInference(
              entityId: 'test-id',
              promptConfig: promptConfig,
              onProgress: (_) {},
              onStatusChange: statusChanges.add,
            ),
            throwsA(isA<Exception>()),
          );

          // Deterministically process queued microtasks
          async.flushMicrotasks();
          // Note: Repository no longer emits error status - controller handles it
          expect(statusChanges, [InferenceStatus.running]);
        });
      });

      test('handles build prompt failure', () {
        fakeAsync((async) {
          final taskEntity = Task(
            meta: _createMetadata(),
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
          ).thenAnswer((_) async => null);

          when(
            () => mockCloudInferenceRepo.generate(
              any(),
              model: any(named: 'model'),
              temperature: any(named: 'temperature'),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              systemMessage: any(named: 'systemMessage'),
              provider: any(named: 'provider'),
              geminiThinkingMode: any(named: 'geminiThinkingMode'),
            ),
          ).thenThrow(Exception('Failed to build prompt'));

          expect(
            () => repository!.runInference(
              entityId: 'test-id',
              promptConfig: promptConfig,
              onProgress: (_) {},
              onStatusChange: statusChanges.add,
            ),
            throwsA(isA<Exception>()),
          );

          // Deterministically process queued microtasks
          async.flushMicrotasks();
          // Note: Repository no longer emits error status - controller handles it
          expect(statusChanges, [InferenceStatus.running]);
        });
      });

      test('handles empty stream chunk content', () async {
        final taskEntity = Task(
          meta: _createMetadata(),
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
            created:
                DateTime(2024, 3, 15, 10, 30).millisecondsSinceEpoch ~/ 1000,
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
            created:
                DateTime(2024, 3, 15, 10, 30).millisecondsSinceEpoch ~/ 1000,
          ),
        ]);

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

        _stubGenerate(mockCloudInferenceRepo, stream: mockStream);

        _stubCreateAiResponseEntry(mockAiInputRepo);
        when(
          () => mockJournalDb.getConfigFlag(enableAiStreamingFlag),
        ).thenAnswer((_) async => true);

        await repository!.runInference(
          entityId: 'test-id',
          promptConfig: promptConfig,
          onProgress: progressUpdates.add,
          onStatusChange: statusChanges.add,
        );

        expect(progressUpdates, ['', 'Hello']);
        expect(statusChanges, [InferenceStatus.running, InferenceStatus.idle]);
      });

      test('handles error during inference', () {
        fakeAsync((async) {
          final taskEntity = Task(
            meta: _createMetadata(),
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

          final promptConfig = _createPrompt(
            id: 'prompt-1',
            name: 'Task Summary',
            requiredInputData: [InputDataType.task],
          );

          final statusChanges = <InferenceStatus>[];

          when(
            () => mockAiInputRepo.getEntity('test-id'),
          ).thenAnswer((_) async => taskEntity);
          when(
            () => mockAiConfigRepo.getConfigById('model-1'),
          ).thenThrow(Exception('Model not found'));

          expect(
            () => repository!.runInference(
              entityId: 'test-id',
              promptConfig: promptConfig,
              onProgress: (_) {},
              onStatusChange: statusChanges.add,
            ),
            throwsException,
          );

          // Deterministically process queued microtasks
          async.flushMicrotasks();
          // Note: Repository no longer emits error status - controller handles it
          expect(statusChanges, [InferenceStatus.running]);
        });
      });

      test('handles entity not found error', () {
        fakeAsync((async) {
          final promptConfig = _createPrompt(
            id: 'prompt-1',
            name: 'Task Summary',
            requiredInputData: [InputDataType.task],
          );

          final statusChanges = <InferenceStatus>[];

          when(
            () => mockAiInputRepo.getEntity('test-id'),
          ).thenAnswer((_) async => null);

          expect(
            () => repository!.runInference(
              entityId: 'test-id',
              promptConfig: promptConfig,
              onProgress: (_) {},
              onStatusChange: statusChanges.add,
            ),
            throwsA(isA<Exception>()),
          );

          // Deterministically process queued microtasks
          async.flushMicrotasks();
          // Note: Repository no longer emits error status - controller handles it
          expect(statusChanges, [InferenceStatus.running]);
        });
      });

      test(
        'audio transcription updates both transcripts and entry text',
        () async {
          final tempDir = Directory.systemTemp.createTempSync('audio_test');
          overrideTempDirs.add(tempDir);

          // Update the mock directory to point to our temp directory
          when(() => mockDirectory.path).thenReturn(tempDir.path);

          final audioEntity = JournalAudio(
            meta: _createMetadata(),
            data: AudioData(
              dateFrom: DateTime(2024, 3, 15, 10, 30),
              dateTo: DateTime(2024, 3, 15, 10, 30),
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
                  delta: ChatCompletionStreamResponseDelta(
                    content: transcriptText,
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

          _stubInferenceContext(
            mockAiInputRepo: mockAiInputRepo,
            mockAiConfigRepo: mockAiConfigRepo,
            entity: audioEntity,
            model: model,
            provider: provider,
            taskDetailsJson: '{"audio": "test.mp3"}',
          );
          _stubGenerateWithAudio(mockCloudInferenceRepo, stream: mockStream);

          _stubCreateAiResponseEntry(mockAiInputRepo);

          when(
            () => mockJournalRepo.updateJournalEntity(any()),
          ).thenAnswer((_) async => true);

          // Mock getLinkedToEntities to return empty list (no linked tasks)
          when(
            () => mockJournalRepo.getLinkedToEntities(linkedTo: 'test-id'),
          ).thenAnswer((_) async => []);

          try {
            await repository!.runInference(
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
            final captured = verify(
              () => mockJournalRepo.updateJournalEntity(captureAny()),
            ).captured;
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
                provider: any(named: 'provider'),
                any(),
                model: 'whisper-1',
                audioBase64: any(named: 'audioBase64'),
                baseUrl: 'https://api.example.com',
                apiKey: 'test-api-key',
                stream: any(named: 'stream'),
                audioFormat: any(named: 'audioFormat'),
              ),
            ).called(1);

            // updateJournalEntity verification is already done via the captured call above
          } finally {
            // Clean up the temporary directory
            tempDir.deleteSync(recursive: true);
          }
        },
      );

      test(
        'audio transcription preserves existing transcripts when adding new one',
        () async {
          final tempDir = Directory.systemTemp.createTempSync('audio_test');
          overrideTempDirs.add(tempDir);

          // Update the mock directory to point to our temp directory
          when(() => mockDirectory.path).thenReturn(tempDir.path);

          final existingTranscript = AudioTranscript(
            created: DateTime(2024, 3, 15, 9, 30),
            library: 'Previous Transcription',
            model: 'old-model',
            detectedLanguage: 'en',
            transcript: 'Previous transcript content',
            processingTime: const Duration(seconds: 5),
          );

          final audioEntity = JournalAudio(
            meta: _createMetadata(),
            data: AudioData(
              dateFrom: DateTime(2024, 3, 15, 10, 30),
              dateTo: DateTime(2024, 3, 15, 10, 30),
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
              created:
                  DateTime(2024, 3, 15, 10, 30).millisecondsSinceEpoch ~/ 1000,
            ),
          ]);

          _stubInferenceContext(
            mockAiInputRepo: mockAiInputRepo,
            mockAiConfigRepo: mockAiConfigRepo,
            entity: audioEntity,
            model: model,
            provider: provider,
            taskDetailsJson: '{"audio": "test.mp3"}',
          );
          _stubGenerateWithAudio(mockCloudInferenceRepo, stream: mockStream);

          _stubCreateAiResponseEntry(mockAiInputRepo);

          when(
            () => mockJournalRepo.updateJournalEntity(any()),
          ).thenAnswer((_) async => true);

          // Mock getLinkedToEntities to return empty list (no linked tasks)
          when(
            () => mockJournalRepo.getLinkedToEntities(linkedTo: 'test-id'),
          ).thenAnswer((_) async => []);

          try {
            await repository!.runInference(
              entityId: 'test-id',
              promptConfig: promptConfig,
              onProgress: (_) {},
              onStatusChange: (_) {},
            );

            // Verify that updateJournalEntity was called with the correct data
            final captured = verify(
              () => mockJournalRepo.updateJournalEntity(captureAny()),
            ).captured;
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
            expect(
              updatedEntity.entryText!.plainText,
              newTranscriptText.trim(),
            );
            expect(updatedEntity.entryText!.markdown, newTranscriptText.trim());
          } finally {
            // Clean up the temporary directory
            tempDir.deleteSync(recursive: true);
          }
        },
      );

      test('image analysis appends to existing entry text', () async {
        final tempDir = Directory.systemTemp.createTempSync('image_test');
        overrideTempDirs.add(tempDir);

        // Update the mock directory to point to our temp directory
        when(() => mockDirectory.path).thenReturn(tempDir.path);

        const existingText = 'This is existing text in the image entry.';

        final imageEntity = JournalImage(
          meta: _createMetadata(),
          data: ImageData(
            capturedAt: DateTime(2024, 3, 15, 10, 30),
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
            created:
                DateTime(2024, 3, 15, 10, 30).millisecondsSinceEpoch ~/ 1000,
          ),
        ]);

        _stubInferenceContext(
          mockAiInputRepo: mockAiInputRepo,
          mockAiConfigRepo: mockAiConfigRepo,
          entity: imageEntity,
          model: model,
          provider: provider,
          taskDetailsJson: '{"image": "test.jpg"}',
        );
        when(
          () => mockJournalRepo.getLinkedToEntities(linkedTo: 'test-id'),
        ).thenAnswer((_) async => []); // No linked task
        _stubGenerateWithImages(mockCloudInferenceRepo, stream: mockStream);

        _stubCreateAiResponseEntry(mockAiInputRepo);

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

          // Verify that updateJournalEntity was called with the correct data
          final captured = verify(
            () => mockJournalRepo.updateJournalEntity(captureAny()),
          ).captured;
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
              provider: any(named: 'provider'),
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
        overrideTempDirs.add(tempDir);

        // Update the mock directory to point to our temp directory
        when(() => mockDirectory.path).thenReturn(tempDir.path);

        final imageEntity = JournalImage(
          meta: _createMetadata(),
          data: ImageData(
            capturedAt: DateTime(2024, 3, 15, 10, 30),
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
            created:
                DateTime(2024, 3, 15, 10, 30).millisecondsSinceEpoch ~/ 1000,
          ),
        ]);

        _stubInferenceContext(
          mockAiInputRepo: mockAiInputRepo,
          mockAiConfigRepo: mockAiConfigRepo,
          entity: imageEntity,
          model: model,
          provider: provider,
          taskDetailsJson: '{"image": "test.jpg"}',
        );
        when(
          () => mockJournalRepo.getLinkedToEntities(linkedTo: 'test-id'),
        ).thenAnswer((_) async => []); // No linked task
        _stubGenerateWithImages(mockCloudInferenceRepo, stream: mockStream);

        _stubCreateAiResponseEntry(mockAiInputRepo);

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

          // Verify that updateJournalEntity was called with the correct data
          final captured = verify(
            () => mockJournalRepo.updateJournalEntity(captureAny()),
          ).captured;
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
      test(
        'should not create AI response entry for JournalAudio entities',
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
          overrideTempDirs.add(tempDir);
          when(() => mockDirectory.path).thenReturn(tempDir.path);

          // Create the audio directory and file
          Directory('${tempDir.path}/audio').createSync(recursive: true);
          final audioFile = File('${tempDir.path}/audio/test.mp3');
          final mockAudioBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6]);
          audioFile.writeAsBytesSync(mockAudioBytes);

          final audioEntity = JournalAudio(
            meta: _createMetadata(),
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
          _stubGenerateWithAudio(mockCloudInferenceRepo, stream: mockStream);

          _stubCreateAiResponseEntry(mockAiInputRepo);

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
          _stubGenerate(mockCloudInferenceRepo, stream: mockStream);

          _stubCreateAiResponseEntry(mockAiInputRepo);

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
          meta: _createMetadata().copyWith(id: 'test-id'),
          data: ImageData(
            capturedAt: DateTime(2024, 3, 15, 10, 30),
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
            _createPrompt(
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

        _stubGenerateWithImages(mockCloudInferenceRepo, stream: mockStream);

        _stubCreateAiResponseEntry(mockAiInputRepo);

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
          expect(
            statusChanges,
            [InferenceStatus.running, InferenceStatus.idle],
          );

          // Verify the prompt was built with task context
          final captured = verify(
            () => mockCloudInferenceRepo.generateWithImages(
              captureAny(),
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
            meta: _createMetadata(),
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
              _createPrompt(
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

          _stubGenerateWithImages(mockCloudInferenceRepo, stream: mockStream);

          _stubCreateAiResponseEntry(mockAiInputRepo);

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
          meta: _createMetadata().copyWith(id: 'test-id'),
          data: AudioData(
            dateFrom: DateTime(2024, 3, 15, 10, 30),
            dateTo: DateTime(2024, 3, 15, 10, 30),
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
            _createPrompt(
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

        _stubGenerateWithAudio(mockCloudInferenceRepo, stream: mockStream);

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
          expect(
            statusChanges,
            [InferenceStatus.running, InferenceStatus.idle],
          );

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
            meta: _createMetadata(),
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
              _createPrompt(
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

          _stubGenerateWithAudio(mockCloudInferenceRepo, stream: mockStream);

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

  group('Concurrent Safety Tests', () {
    test('runInference calls getEntity to retrieve entity', () async {
      // Setup
      final task = Task(
        meta: _createMetadata(),
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

          final mockStream = _createMockTextStream([
            'This is an image of a sunset',
          ]);

          _stubGenerateWithImages(mockCloudInferenceRepo, stream: mockStream);

          _stubCreateAiResponseEntry(mockAiInputRepo);

          // Execute
          await repository!.runInference(
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

          final mockStream = _createMockTextStream(
            ['This is the transcribed audio content'],
          );

          _stubGenerateWithAudio(mockCloudInferenceRepo, stream: mockStream);

          _stubCreateAiResponseEntry(mockAiInputRepo);

          // Execute
          await repository!.runInference(
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

          final mockStream = _createMockTextStream([
            'AI analysis: Beautiful sunset',
          ]);

          _stubGenerateWithImages(mockCloudInferenceRepo, stream: mockStream);

          _stubCreateAiResponseEntry(mockAiInputRepo);

          // Execute
          await repository!.runInference(
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

          final mockStream = _createMockTextStream(['Transcribed content']);

          _stubGenerateWithAudio(mockCloudInferenceRepo, stream: mockStream);

          _stubCreateAiResponseEntry(mockAiInputRepo);

          // Execute - should complete without throwing
          await repository!.runInference(
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
          meta: _createMetadata(),
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

        final promptConfig = _createPrompt(
          id: 'prompt-1',
          name: 'Task Summary',
          requiredInputData: [InputDataType.task],
        );

        final model = _createModel(
          id: 'model-1',
          inferenceProviderId: 'provider-1',
          providerModelId: 'gpt-4',
        ).copyWith(supportsFunctionCalling: true);

        final provider = _createProvider(
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
                      _createMockToolCall(
                        index: 0,
                        id: '', // Empty ID
                        functionName: 'suggest_checklist_completion',
                        arguments:
                            '{"checklistItemId":"item-1","reason":"Developed","confidence":"high"}',
                      ),
                      _createMockToolCall(
                        index: 0,
                        id: '', // Empty ID
                        functionName: 'suggest_checklist_completion',
                        arguments:
                            '{"checklistItemId":"item-2","reason":"Added tests","confidence":"high"}',
                      ),
                      _createMockToolCall(
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
          ..add(_createStreamChunk('Task completed'))
          ..close();

        _stubGenerate(
          mockCloudInferenceRepo,
          stream: streamController.stream,
        );

        // Clear any captured suggestions from previous tests
        testChecklistCompletionService.capturedSuggestions.clear();

        await repository!.runInference(
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
          meta: _createMetadata(),
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

        final promptConfig = _createPrompt(
          id: 'prompt-1',
          name: 'Task Summary',
          requiredInputData: [InputDataType.task],
        );

        final model = _createModel(
          id: 'model-1',
          inferenceProviderId: 'provider-1',
          providerModelId: 'gpt-4',
        ).copyWith(supportsFunctionCalling: true);

        final provider = _createProvider(
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
            _createStreamChunkWithToolCalls([
              _createMockToolCall(
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
          ..add(_createStreamChunk('Task completed'))
          ..close();

        _stubGenerate(
          mockCloudInferenceRepo,
          stream: streamController.stream,
        );

        // Clear any captured suggestions from previous tests
        testChecklistCompletionService.capturedSuggestions.clear();

        await repository!.runInference(
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

  group('Batch checklist items parsing in unified repository', () {
    test('parses string fallback with grouping and creates items', () async {
      final taskEntity = Task(
        meta: _createMetadata(),
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
          checklistIds: [],
        ),
      );

      final promptConfig = _createPrompt(
        id: 'prompt-1',
        name: 'Checklist Updates',
        requiredInputData: [InputDataType.task],
        aiResponseType: AiResponseType.imageAnalysis,
      );

      final model = _createModel(
        id: 'model-1',
        inferenceProviderId: 'provider-1',
        providerModelId: 'gpt-4',
      ).copyWith(supportsFunctionCalling: true);

      final provider = _createProvider(
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

      // Stream with one tool call using array-of-objects; grouped comma stays within title
      final streamController =
          StreamController<CreateChatCompletionStreamResponse>()
            ..add(
              _createStreamChunkWithToolCalls([
                _createMockToolCall(
                  index: 0,
                  id: 'call-1',
                  functionName: 'add_multiple_checklist_items',
                  arguments:
                      '{"items": [{"title": "Start database (index cache, warm)"}, {"title": "Verify"}]}',
                ),
              ]),
            )
            ..add(_createStreamChunk('Done'))
            ..close();

      _stubGenerate(
        mockCloudInferenceRepo,
        stream: streamController.stream,
      );

      when(
        () => mockAutoChecklistService.autoCreateChecklist(
          taskId: taskEntity.id,
          suggestions: any(named: 'suggestions'),
          title: any(named: 'title'),
        ),
      ).thenAnswer(
        (_) async => (
          success: true,
          checklistId: 'new-checklist',
          createdItems: <({String id, String title, bool isChecked})>[],
          error: null,
        ),
      );

      await repository!.runInference(
        entityId: taskEntity.id,
        promptConfig: promptConfig,
        onProgress: (_) {},
        onStatusChange: (_) {},
      );

      final captured = verify(
        () => mockAutoChecklistService.autoCreateChecklist(
          taskId: taskEntity.id,
          suggestions: captureAny(named: 'suggestions'),
          title: 'Todos',
        ),
      ).captured;

      // Ensure at least one call with the first parsed item
      expect(captured.length, greaterThanOrEqualTo(1));
      final first = captured.first as List<ChecklistItemData>;
      expect(
        first.any((i) => i.title == 'Start database (index cache, warm)'),
        isTrue,
      );
    });
  });

  group('Add checklist item tool calls', () {
    test('creates new checklist when none exists', () async {
      final taskEntity = Task(
        meta: _createMetadata(),
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
          checklistIds: [], // No existing checklists
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
      ).copyWith(supportsFunctionCalling: true);

      final provider = _createProvider(
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

      // Mock auto checklist creation
      when(
        () => mockAutoChecklistService.autoCreateChecklist(
          taskId: taskEntity.id,
          suggestions: any(named: 'suggestions'),
          title: 'to-do',
        ),
      ).thenAnswer(
        (_) async => (
          success: true,
          checklistId: 'new-checklist-id',
          createdItems: <({String id, String title, bool isChecked})>[],
          error: null,
        ),
      );

      // Create stream with add_multiple_checklist_items tool call
      final streamController =
          StreamController<CreateChatCompletionStreamResponse>()
            ..add(
              _createStreamChunkWithToolCalls([
                _createMockToolCall(
                  index: 0,
                  id: 'call-1',
                  functionName: 'add_multiple_checklist_items',
                  arguments: '{"items": [{"title": "Review documentation"}]}',
                ),
              ]),
            )
            ..add(_createStreamChunk('Task analysis complete'))
            ..close();

      _stubGenerate(
        mockCloudInferenceRepo,
        stream: streamController.stream,
      );

      await repository!.runInference(
        entityId: taskEntity.id,
        promptConfig: promptConfig,
        onProgress: (_) {},
        onStatusChange: (_) {},
      );

      // Verify auto checklist creation was called
      verify(
        () => mockAutoChecklistService.autoCreateChecklist(
          taskId: taskEntity.id,
          suggestions: any(named: 'suggestions'),
          title: 'Todos',
        ),
      ).called(1);
    });

    test('adds item to existing checklist', () async {
      const existingChecklistId = 'existing-checklist-id';
      final taskEntity = Task(
        meta: _createMetadata(),
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
          checklistIds: [existingChecklistId], // Has existing checklist
        ),
      );

      final existingChecklist = Checklist(
        meta: _createMetadata(id: existingChecklistId),
        data: ChecklistData(
          title: 'Existing Checklist',
          linkedChecklistItems: ['item-1', 'item-2'],
          linkedTasks: [taskEntity.id],
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
      ).copyWith(supportsFunctionCalling: true);

      final provider = _createProvider(
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

      // Mock journal repository for fetching existing checklist
      when(
        () => mockJournalRepo.getJournalEntityById(existingChecklistId),
      ).thenAnswer((_) async => existingChecklist);

      // Mock checklist repository for creating item
      final newChecklistItem = ChecklistItem(
        meta: _createMetadata(id: 'new-item-id'),
        data: const ChecklistItemData(
          title: 'New checklist item',
          isChecked: false,
          linkedChecklists: [existingChecklistId],
        ),
      );

      when(
        () => mockChecklistRepo.addItemToChecklist(
          checklistId: existingChecklistId,
          title: 'New checklist item',
          isChecked: false,
          categoryId: taskEntity.meta.categoryId,
          checkedBy: ChangeSource.agent,
        ),
      ).thenAnswer((_) async => newChecklistItem);

      // Create stream with add_multiple_checklist_items tool call
      final streamController =
          StreamController<CreateChatCompletionStreamResponse>()
            ..add(
              _createStreamChunkWithToolCalls([
                _createMockToolCall(
                  index: 0,
                  id: 'call-1',
                  functionName: 'add_multiple_checklist_items',
                  arguments: '{"items": [{"title": "New checklist item"}]}',
                ),
              ]),
            )
            ..add(_createStreamChunk('Task analysis complete'))
            ..close();

      _stubGenerate(
        mockCloudInferenceRepo,
        stream: streamController.stream,
      );

      await repository!.runInference(
        entityId: taskEntity.id,
        promptConfig: promptConfig,
        onProgress: (_) {},
        onStatusChange: (_) {},
      );

      // Verify item was created using atomic method with agent provenance
      verify(
        () => mockChecklistRepo.addItemToChecklist(
          checklistId: existingChecklistId,
          title: 'New checklist item',
          isChecked: false,
          categoryId: taskEntity.meta.categoryId,
          checkedBy: ChangeSource.agent,
        ),
      ).called(1);
    });

    test(
      'creates only one checklist when processing a single batch multi-item call',
      () async {
        final taskEntity = Task(
          meta: _createMetadata(),
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
            checklistIds: [], // No existing checklists
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
        ).copyWith(supportsFunctionCalling: true);

        final provider = _createProvider(
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

        // Mock auto checklist creation
        const newChecklistId = 'new-checklist-id';
        when(
          () => mockAutoChecklistService.autoCreateChecklist(
            taskId: taskEntity.id,
            suggestions: any(named: 'suggestions'),
            title: 'Todos',
          ),
        ).thenAnswer(
          (_) async => (
            success: true,
            checklistId: newChecklistId,
            createdItems: <({String id, String title, bool isChecked})>[],
            error: null,
          ),
        );

        // Mock the task refresh after checklist creation
        final updatedTaskEntity = Task(
          meta: taskEntity.meta,
          data: taskEntity.data.copyWith(
            checklistIds: [newChecklistId],
          ),
        );
        when(
          () => mockJournalDb.journalEntityById(taskEntity.id),
        ).thenAnswer((_) async => updatedTaskEntity);

        // Mock adding items to the newly created checklist
        when(
          () => mockChecklistRepo.addItemToChecklist(
            checklistId: newChecklistId,
            title: any(named: 'title'),
            isChecked: false,
            categoryId: any(named: 'categoryId'),
            checkedBy: ChangeSource.agent,
          ),
        ).thenAnswer(
          (_) async => ChecklistItem(
            meta: _createMetadata(id: 'item-new'),
            data: const ChecklistItemData(
              title: 'Test Item',
              isChecked: false,
              linkedChecklists: [newChecklistId],
              checkedBy: ChangeSource.agent,
            ),
          ),
        );

        // Create stream with a single add_multiple_checklist_items tool call containing multiple items
        final streamController =
            StreamController<CreateChatCompletionStreamResponse>()
              ..add(
                _createStreamChunkWithToolCalls([
                  _createMockToolCall(
                    index: 0,
                    id: 'call-1',
                    functionName: 'add_multiple_checklist_items',
                    arguments:
                        '{"items": [{"title": "First item"}, {"title": "Second item"}, {"title": "Third item"}]}',
                  ),
                  _createMockToolCall(
                    index: 1,
                    id: 'call-2',
                    functionName: 'add_multiple_checklist_items',
                    arguments: '{"items": [{"title": "noop"}]}',
                  ),
                  _createMockToolCall(
                    index: 2,
                    id: 'call-3',
                    functionName: 'add_multiple_checklist_items',
                    arguments: '{"items": [{"title": "noop2"}]}',
                  ),
                ]),
              )
              ..add(_createStreamChunk('Task analysis complete'))
              ..close();

        _stubGenerate(
          mockCloudInferenceRepo,
          stream: streamController.stream,
        );

        await repository!.runInference(
          entityId: taskEntity.id,
          promptConfig: promptConfig,
          onProgress: (_) {},
          onStatusChange: (_) {},
        );

        // Verify that checklist creation was called only once
        verify(
          () => mockAutoChecklistService.autoCreateChecklist(
            taskId: taskEntity.id,
            suggestions: any(named: 'suggestions'),
            title: 'Todos',
          ),
        ).called(1);

        // Verify that the task was refreshed after checklist creation
        verify(() => mockJournalDb.journalEntityById(taskEntity.id)).called(1);

        // Verify that subsequent items were added to the existing checklist
        verify(
          () => mockChecklistRepo.addItemToChecklist(
            checklistId: newChecklistId,
            title: 'Second item',
            isChecked: false,
            categoryId: taskEntity.meta.categoryId,
            checkedBy: ChangeSource.agent,
          ),
        ).called(1);

        verify(
          () => mockChecklistRepo.addItemToChecklist(
            checklistId: newChecklistId,
            title: 'Third item',
            isChecked: false,
            categoryId: taskEntity.meta.categoryId,
            checkedBy: ChangeSource.agent,
          ),
        ).called(1);
      },
    );
  });

  group('Auto-check high confidence suggestions', () {
    final autoCheckTime = DateTime(2026, 2, 28, 23);

    test('automatically checks items with high confidence', () async {
      // Recreate with deterministic clock for checkedAt assertion
      final ref = container.read(testRefProvider);
      repository = UnifiedAiInferenceRepository(ref, clock: () => autoCheckTime)
        ..autoChecklistServiceForTesting = mockAutoChecklistService;
      final taskEntity = Task(
        meta: _createMetadata(),
        data: TaskData(
          status: TaskStatus.open(
            id: 'status-1',
            createdAt: DateTime(2025),
            utcOffset: 0,
          ),
          title: 'Test Task',
          statusHistory: [],
          dateFrom: DateTime(2025),
          dateTo: DateTime(2025),
          checklistIds: ['checklist-1'],
        ),
      );

      final checklistItem = ChecklistItem(
        meta: _createMetadata(id: 'item-1'),
        data: const ChecklistItemData(
          title: 'Test item',
          isChecked: false,
          linkedChecklists: ['checklist-1'],
          // Agent-owned so auto-check is allowed by sovereignty guard
          checkedBy: ChangeSource.agent,
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
      ).copyWith(supportsFunctionCalling: true);

      final provider = _createProvider(
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

      // Mock getting the checklist item
      when(
        () => mockJournalRepo.getJournalEntityById('item-1'),
      ).thenAnswer((_) async => checklistItem);

      // Mock updating the checklist item
      when(
        () => mockChecklistRepo.updateChecklistItem(
          checklistItemId: 'item-1',
          data: any(named: 'data'),
          taskId: taskEntity.id,
        ),
      ).thenAnswer((_) async => true);

      // Create stream with high confidence suggestion
      final streamController =
          StreamController<CreateChatCompletionStreamResponse>()
            ..add(
              _createStreamChunkWithToolCalls([
                _createMockToolCall(
                  index: 0,
                  id: 'call-1',
                  functionName: 'suggest_checklist_completion',
                  arguments:
                      '{"checklistItemId":"item-1","reason":"Task completed","confidence":"high"}',
                ),
              ]),
            )
            ..add(_createStreamChunk('Task analysis complete'))
            ..close();

      _stubGenerate(
        mockCloudInferenceRepo,
        stream: streamController.stream,
      );

      // Clear any captured suggestions from previous tests
      testChecklistCompletionService.capturedSuggestions.clear();
      when(
        () => mockAiInputRepo.buildTaskDetailsJson(id: any(named: 'id')),
      ).thenAnswer((_) async => '{"title": "Test Task"}');

      await repository!.runInference(
        entityId: taskEntity.id,
        promptConfig: promptConfig,
        onProgress: (_) {},
        onStatusChange: (_) {},
      );

      // Verify the item was updated to be checked with agent provenance
      verify(
        () => mockChecklistRepo.updateChecklistItem(
          checklistItemId: 'item-1',
          data: any(
            named: 'data',
            that: isA<ChecklistItemData>()
                .having((d) => d.isChecked, 'isChecked', true)
                .having(
                  (d) => d.checkedBy,
                  'checkedBy',
                  ChangeSource.agent,
                )
                .having(
                  (d) => d.checkedAt,
                  'checkedAt',
                  autoCheckTime,
                ),
          ),
          taskId: taskEntity.id,
        ),
      ).called(1);
    });

    test('does not auto-check items with medium or low confidence', () async {
      final taskEntity = Task(
        meta: _createMetadata(),
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

      final promptConfig = _createPrompt(
        id: 'prompt-1',
        name: 'Task Summary',
        requiredInputData: [InputDataType.task],
      );

      final model = _createModel(
        id: 'model-1',
        inferenceProviderId: 'provider-1',
        providerModelId: 'gpt-4',
      ).copyWith(supportsFunctionCalling: true);

      final provider = _createProvider(
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

      // Create stream with medium confidence suggestion
      final streamController =
          StreamController<CreateChatCompletionStreamResponse>()
            ..add(
              _createStreamChunkWithToolCalls([
                _createMockToolCall(
                  index: 0,
                  id: 'call-1',
                  functionName: 'suggest_checklist_completion',
                  arguments:
                      '{"checklistItemId":"item-2","reason":"Might be done","confidence":"medium"}',
                ),
              ]),
            )
            ..add(_createStreamChunk('Task analysis complete'))
            ..close();

      _stubGenerate(
        mockCloudInferenceRepo,
        stream: streamController.stream,
      );

      // Clear any captured suggestions from previous tests
      testChecklistCompletionService.capturedSuggestions.clear();
      when(
        () => mockAiInputRepo.buildTaskDetailsJson(id: any(named: 'id')),
      ).thenAnswer((_) async => '{"title": "Test Task"}');

      await repository!.runInference(
        entityId: taskEntity.id,
        promptConfig: promptConfig,
        onProgress: (_) {},
        onStatusChange: (_) {},
      );

      // Verify no update was made
      verifyNever(
        () => mockChecklistRepo.updateChecklistItem(
          checklistItemId: any(named: 'checklistItemId'),
          data: any(named: 'data'),
          taskId: any(named: 'taskId'),
        ),
      );
    });

    test('does not update already checked items', () async {
      final taskEntity = Task(
        meta: _createMetadata(),
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

      final alreadyCheckedItem = ChecklistItem(
        meta: _createMetadata(id: 'item-3'),
        data: const ChecklistItemData(
          title: 'Already checked item',
          isChecked: true, // Already checked
          linkedChecklists: ['checklist-1'],
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
      ).copyWith(supportsFunctionCalling: true);

      final provider = _createProvider(
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

      // Mock getting the already checked item
      when(
        () => mockJournalRepo.getJournalEntityById('item-3'),
      ).thenAnswer((_) async => alreadyCheckedItem);

      // Create stream with high confidence suggestion for already checked item
      final streamController =
          StreamController<CreateChatCompletionStreamResponse>()
            ..add(
              _createStreamChunkWithToolCalls([
                _createMockToolCall(
                  index: 0,
                  id: 'call-1',
                  functionName: 'suggest_checklist_completion',
                  arguments:
                      '{"checklistItemId":"item-3","reason":"Task completed","confidence":"high"}',
                ),
              ]),
            )
            ..add(_createStreamChunk('Task analysis complete'))
            ..close();

      _stubGenerate(
        mockCloudInferenceRepo,
        stream: streamController.stream,
      );

      // Clear any captured suggestions from previous tests
      testChecklistCompletionService.capturedSuggestions.clear();
      when(
        () => mockAiInputRepo.buildTaskDetailsJson(id: any(named: 'id')),
      ).thenAnswer((_) async => '{"title": "Test Task"}');

      await repository!.runInference(
        entityId: taskEntity.id,
        promptConfig: promptConfig,
        onProgress: (_) {},
        onStatusChange: (_) {},
      );

      // Verify no update was made since item was already checked
      verifyNever(
        () => mockChecklistRepo.updateChecklistItem(
          checklistItemId: any(named: 'checklistItemId'),
          data: any(named: 'data'),
          taskId: any(named: 'taskId'),
        ),
      );
    });

    test('does not auto-check user-owned items (sovereignty guard)', () async {
      final taskEntity = Task(
        meta: _createMetadata(),
        data: TaskData(
          status: TaskStatus.open(
            id: 'status-1',
            createdAt: DateTime(2025),
            utcOffset: 0,
          ),
          title: 'Test Task',
          statusHistory: [],
          dateFrom: DateTime(2025),
          dateTo: DateTime(2025),
          checklistIds: ['checklist-1'],
        ),
      );

      // User-owned unchecked item — sovereignty guard should block auto-check
      final userOwnedItem = ChecklistItem(
        meta: _createMetadata(id: 'item-user'),
        data: const ChecklistItemData(
          title: 'User unchecked item',
          isChecked: false,
          linkedChecklists: ['checklist-1'],
          checkedBy: ChangeSource.user,
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
      ).copyWith(supportsFunctionCalling: true);

      final provider = _createProvider(
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

      when(
        () => mockJournalRepo.getJournalEntityById('item-user'),
      ).thenAnswer((_) async => userOwnedItem);

      final streamController =
          StreamController<CreateChatCompletionStreamResponse>()
            ..add(
              _createStreamChunkWithToolCalls([
                _createMockToolCall(
                  index: 0,
                  id: 'call-1',
                  functionName: 'suggest_checklist_completion',
                  arguments:
                      '{"checklistItemId":"item-user","reason":"Completed","confidence":"high"}',
                ),
              ]),
            )
            ..add(_createStreamChunk('Task analysis complete'))
            ..close();

      _stubGenerate(
        mockCloudInferenceRepo,
        stream: streamController.stream,
      );

      testChecklistCompletionService.capturedSuggestions.clear();
      when(
        () => mockAiInputRepo.buildTaskDetailsJson(id: any(named: 'id')),
      ).thenAnswer((_) async => '{"title": "Test Task"}');

      await repository!.runInference(
        entityId: taskEntity.id,
        promptConfig: promptConfig,
        onProgress: (_) {},
        onStatusChange: (_) {},
      );

      // Verify NO update was made — sovereignty guard blocks user-owned items
      verifyNever(
        () => mockChecklistRepo.updateChecklistItem(
          checklistItemId: any(named: 'checklistItemId'),
          data: any(named: 'data'),
          taskId: any(named: 'taskId'),
        ),
      );
    });
  });

  group('Additional coverage tests', () {
    late Task taskEntity;
    late AiConfigInferenceProvider aiProvider;
    late AiConfigModel model;

    setUp(() {
      taskEntity = Task(
        meta: _createMetadata(),
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

      aiProvider = _createAiProvider(
        id: 'provider-1',
        type: InferenceProviderType.openAi,
      );

      model = _createModel(
        id: 'model-1',
        providerModelId: 'gpt-4',
        inferenceProviderId: 'provider-1',
      );
    });
    test('autoChecklistServiceForTesting setter works correctly', () {
      final mockAutoChecklistService = MockAutoChecklistService();
      repository!.autoChecklistServiceForTesting = mockAutoChecklistService;
      // The setter is used for testing purposes
      expect(
        () => repository!.autoChecklistServiceForTesting =
            mockAutoChecklistService,
        returnsNormally,
      );
    });

    test('handles model not found error', () async {
      final promptConfig = AiConfigPrompt(
        id: 'prompt-1',
        name: 'Test Prompt',
        systemMessage: 'System',
        userMessage: 'User',
        defaultModelId: 'non-existent-model',
        modelIds: ['non-existent-model'],
        createdAt: DateTime(2024, 3, 15, 10, 30),
        useReasoning: false,
        requiredInputData: [InputDataType.task],
        aiResponseType: AiResponseType.imageAnalysis,
      );

      when(
        () => mockAiInputRepo.getEntity(any()),
      ).thenAnswer((_) async => taskEntity);
      when(
        () => mockAiConfigRepo.getConfigById('non-existent-model'),
      ).thenAnswer((_) async => null);

      await expectLater(
        repository!.runInference(
          entityId: taskEntity.id,
          promptConfig: promptConfig,
          onProgress: (_) {},
          onStatusChange: (_) {},
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Model not found: non-existent-model'),
          ),
        ),
      );
    });

    // Removed conversation approach test due to timeout issues

    test('handles tool calls with empty IDs and fallback to index', () async {
      final promptConfig = AiConfigPrompt(
        id: 'prompt-1',
        name: 'Test Prompt',
        systemMessage: 'System',
        userMessage: 'Update checklist',
        defaultModelId: 'model-1',
        modelIds: ['model-1'],
        createdAt: DateTime(2024, 3, 15, 10, 30),
        useReasoning: false,
        requiredInputData: [InputDataType.task],
        aiResponseType: AiResponseType.imageAnalysis,
      );

      final streamController =
          StreamController<CreateChatCompletionStreamResponse>();

      when(
        () => mockAiInputRepo.getEntity(any()),
      ).thenAnswer((_) async => taskEntity);
      when(
        () => mockAiConfigRepo.getConfigById('model-1'),
      ).thenAnswer((_) async => model);
      when(
        () => mockAiConfigRepo.getConfigById('provider-1'),
      ).thenAnswer((_) async => aiProvider);

      _stubGenerate(
        mockCloudInferenceRepo,
        stream: streamController.stream,
      );

      // Clear any captured suggestions from previous tests
      testChecklistCompletionService.capturedSuggestions.clear();
      when(
        () => mockAiInputRepo.buildTaskDetailsJson(id: any(named: 'id')),
      ).thenAnswer((_) async => '{"title": "Test Task"}');

      final inferenceFuture = repository!.runInference(
        entityId: taskEntity.id,
        promptConfig: promptConfig,
        onProgress: (_) {},
        onStatusChange: (_) {},
      );

      // Add chunks with empty tool call IDs and continuation by index
      streamController
        ..add(
          CreateChatCompletionStreamResponse(
            id: 'response-1',
            choices: [
              const ChatCompletionStreamResponseChoice(
                index: 0,
                delta: ChatCompletionStreamResponseDelta(
                  toolCalls: [
                    ChatCompletionStreamMessageToolCallChunk(
                      index: 0,
                      id: '', // Empty ID - should generate tool_0
                      type:
                          ChatCompletionStreamMessageToolCallChunkType.function,
                      function: ChatCompletionStreamMessageFunctionCall(
                        name: 'add_multiple_checklist_items',
                        arguments: '{"title":',
                      ),
                    ),
                  ],
                ),
              ),
            ],
            object: 'chat.completion.chunk',
            created:
                DateTime(2024, 3, 15, 10, 30).millisecondsSinceEpoch ~/ 1000,
          ),
        )
        // Continue by index without ID
        ..add(
          CreateChatCompletionStreamResponse(
            id: 'response-2',
            choices: [
              const ChatCompletionStreamResponseChoice(
                index: 0,
                delta: ChatCompletionStreamResponseDelta(
                  toolCalls: [
                    ChatCompletionStreamMessageToolCallChunk(
                      index: 0, // Same index, no ID
                      type:
                          ChatCompletionStreamMessageToolCallChunkType.function,
                      function: ChatCompletionStreamMessageFunctionCall(
                        arguments: '"Test item"}',
                      ),
                    ),
                  ],
                ),
              ),
            ],
            object: 'chat.completion.chunk',
            created:
                DateTime(2024, 3, 15, 10, 30).millisecondsSinceEpoch ~/ 1000,
          ),
        );

      await streamController.close();
      await inferenceFuture;

      // Verify that tool calls were processed
      // In real implementation, this would have processed the add_multiple_checklist_items tool call
    });

    test('handles tool call with no ID but with function name', () async {
      final promptConfig = AiConfigPrompt(
        id: 'prompt-1',
        name: 'Test Prompt',
        systemMessage: 'System',
        userMessage: 'Update checklist',
        defaultModelId: 'model-1',
        modelIds: ['model-1'],
        createdAt: DateTime(2024, 3, 15, 10, 30),
        useReasoning: false,
        requiredInputData: [InputDataType.task],
        aiResponseType: AiResponseType.imageAnalysis,
      );

      final streamController =
          StreamController<CreateChatCompletionStreamResponse>();

      when(
        () => mockAiInputRepo.getEntity(any()),
      ).thenAnswer((_) async => taskEntity);
      when(
        () => mockAiConfigRepo.getConfigById('model-1'),
      ).thenAnswer((_) async => model);
      when(
        () => mockAiConfigRepo.getConfigById('provider-1'),
      ).thenAnswer((_) async => aiProvider);

      _stubGenerate(
        mockCloudInferenceRepo,
        stream: streamController.stream,
      );

      // Clear any captured suggestions from previous tests
      testChecklistCompletionService.capturedSuggestions.clear();
      when(
        () => mockAiInputRepo.buildTaskDetailsJson(id: any(named: 'id')),
      ).thenAnswer((_) async => '{"title": "Test Task"}');

      final inferenceFuture = repository!.runInference(
        entityId: taskEntity.id,
        promptConfig: promptConfig,
        onProgress: (_) {},
        onStatusChange: (_) {},
      );

      // Add chunk with no ID but with function name - should create new tool call
      streamController.add(
        CreateChatCompletionStreamResponse(
          id: 'response-1',
          choices: [
            const ChatCompletionStreamResponseChoice(
              index: 0,
              delta: ChatCompletionStreamResponseDelta(
                toolCalls: [
                  ChatCompletionStreamMessageToolCallChunk(
                    index: 0,
                    // No ID field
                    type: ChatCompletionStreamMessageToolCallChunkType.function,
                    function: ChatCompletionStreamMessageFunctionCall(
                      name:
                          'add_multiple_checklist_items', // Has name - indicates new tool call
                      arguments: '{"title": "Item with name but no ID"}',
                    ),
                  ),
                ],
              ),
            ),
          ],
          object: 'chat.completion.chunk',
          created: DateTime(2024, 3, 15, 10, 30).millisecondsSinceEpoch ~/ 1000,
        ),
      );

      await streamController.close();
      await inferenceFuture;

      // Verify that tool call was processed
      // In real implementation, this would have processed the add_multiple_checklist_items tool call
    });

    test('handles provider not found error properly', () async {
      final promptConfig = AiConfigPrompt(
        id: 'prompt-1',
        name: 'Test Prompt',
        systemMessage: 'System',
        userMessage: 'Test message',
        defaultModelId: 'model-1',
        modelIds: ['model-1'],
        createdAt: DateTime(2024, 3, 15, 10, 30),
        useReasoning: false,
        requiredInputData: [InputDataType.task],
        aiResponseType: AiResponseType.imageAnalysis,
      );

      final modelWithBadProvider = AiConfigModel(
        id: 'model-1',
        name: 'Test Model',
        providerModelId: 'test-model',
        inferenceProviderId: 'non-existent-provider',
        createdAt: DateTime(2024, 3, 15, 10, 30),
        inputModalities: [Modality.text],
        outputModalities: [Modality.text],
        isReasoningModel: false,
      );

      when(
        () => mockAiInputRepo.getEntity(any()),
      ).thenAnswer((_) async => taskEntity);
      when(
        () => mockAiConfigRepo.getConfigById('model-1'),
      ).thenAnswer((_) async => modelWithBadProvider);
      when(
        () => mockAiConfigRepo.getConfigById('non-existent-provider'),
      ).thenAnswer((_) async => null); // Provider not found
      when(() => mockAiInputRepo.generate(any())).thenAnswer(
        (_) async => AiInputTaskObject(
          title: 'Test Task',
          status: 'In Progress',
          priority: 'P2',
          estimatedDuration: '1 hour',
          timeSpent: '30 minutes',
          creationDate: DateTime(2024, 3, 15),
          actionItems: [],
          logEntries: [],
        ),
      );
      when(
        () => mockAiInputRepo.buildTaskDetailsJson(id: any(named: 'id')),
      ).thenAnswer((_) async => '{"title": "Test Task"}');

      await expectLater(
        repository!.runInference(
          entityId: taskEntity.id,
          promptConfig: promptConfig,
          onProgress: (_) {},
          onStatusChange: (_) {},
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Provider not found: non-existent-provider'),
          ),
        ),
      );
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
        if (!getIt.isRegistered<AgentDatabase>()) {
          getIt.registerSingleton<AgentDatabase>(mockAgentDb);
        }
        addTearDown(() {
          if (getIt.isRegistered<AgentDatabase>()) {
            getIt.unregister<AgentDatabase>();
          }
        });

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
      if (!getIt.isRegistered<DomainLogger>()) {
        getIt.registerSingleton<DomainLogger>(mockDomainLogger);
      }
      addTearDown(() {
        if (getIt.isRegistered<DomainLogger>()) {
          getIt.unregister<DomainLogger>();
        }
      });

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
          meta: _createMetadata(),
          data: AudioData(
            dateFrom: DateTime(2024, 3, 15, 10, 30),
            dateTo: DateTime(2024, 3, 15, 10, 30),
            audioFile: 'test.mp3',
            audioDirectory: '/audio/',
            duration: const Duration(seconds: 30),
          ),
        );

        final linkedTask = Task(
          meta: _createMetadata().copyWith(id: 'task-id'),
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
        final promptGenPrompt = _createPrompt(
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
          meta: _createMetadata(),
          data: AudioData(
            dateFrom: DateTime(2024, 3, 15, 10, 30),
            dateTo: DateTime(2024, 3, 15, 10, 30),
            audioFile: 'test.mp3',
            audioDirectory: '/audio/',
            duration: const Duration(seconds: 30),
          ),
        );

        final promptGenPrompt = _createPrompt(
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
      final promptConfig = _createPrompt(
        id: 'prompt-1',
        name: 'Task Summary',
        requiredInputData: [InputDataType.task],
      );

      // getEntity returns null → should throw 'Entity not found'
      when(
        () => mockAiInputRepo.getEntity('missing-entity-id'),
      ).thenAnswer((_) async => null);
      when(
        () => mockAiConfigRepo.getConfigById('model-1'),
      ).thenAnswer(
        (_) async => _createModel(
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
        meta: _createMetadata(),
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

      _stubInferenceContext(
        mockAiInputRepo: mockAiInputRepo,
        mockAiConfigRepo: mockAiConfigRepo,
        entity: taskEntity,
        model: model,
        provider: provider,
      );
      _stubGenerate(mockCloudInferenceRepo, stream: mockStream);

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

  group('_handlePostProcessing – promptGeneration case (lines 821-827)', () {
    test(
      'promptGeneration response type completes without post-processing',
      () async {
        final taskEntity = Task(
          meta: _createMetadata(),
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

        final promptConfig = _createPrompt(
          id: 'prompt-gen',
          name: 'Prompt Generation',
          requiredInputData: [InputDataType.task],
          aiResponseType: AiResponseType.promptGeneration,
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

        _stubInferenceContext(
          mockAiInputRepo: mockAiInputRepo,
          mockAiConfigRepo: mockAiConfigRepo,
          entity: taskEntity,
          model: model,
          provider: provider,
        );
        _stubGenerate(
          mockCloudInferenceRepo,
          stream: _createMockTextStream(['Generated prompt content']),
        );
        _stubCreateAiResponseEntry(mockAiInputRepo);

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
            meta: _createMetadata(),
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

          final promptConfig = _createPrompt(
            id: 'img-prompt-gen',
            name: 'Image Prompt Generation',
            requiredInputData: [InputDataType.task],
            aiResponseType: AiResponseType.imagePromptGeneration,
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

          _stubInferenceContext(
            mockAiInputRepo: mockAiInputRepo,
            mockAiConfigRepo: mockAiConfigRepo,
            entity: taskEntity,
            model: model,
            provider: provider,
          );
          _stubGenerate(
            mockCloudInferenceRepo,
            stream: _createMockTextStream(['A beautiful landscape, 4K']),
          );
          _stubCreateAiResponseEntry(mockAiInputRepo);

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
        final promptConfig = _createPrompt(
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
          meta: _createMetadata(),
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

        final promptConfig = _createPrompt(
          id: 'img-analysis',
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

        _stubInferenceContext(
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

        _stubGenerateWithImages(
          mockCloudInferenceRepo,
          stream: _createMockTextStream(['Analysis result']),
        );
        _stubCreateAiResponseEntry(mockAiInputRepo);

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
            meta: _createMetadata(),
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

          final promptConfig = _createPrompt(
            id: 'audio-transcript',
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

          _stubInferenceContext(
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

          _stubGenerateWithAudio(
            mockCloudInferenceRepo,
            stream: _createMockTextStream(['Transcribed text']),
          );
          _stubCreateAiResponseEntry(mockAiInputRepo);

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

  group(
    'processToolCalls – language detection (setTaskLanguage) branches (lines 1120-1178)',
    () {
      Task makeTask({String? languageCode, String id = 'task-lang-test'}) {
        return Task(
          meta: _createMetadata(id: id),
          data: TaskData(
            status: TaskStatus.open(
              id: 'status-1',
              createdAt: DateTime(2024, 3, 15),
              utcOffset: 0,
            ),
            title: 'Language Test Task',
            statusHistory: const [],
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
            languageCode: languageCode,
          ),
        );
      }

      ChatCompletionMessageToolCall langCall(String json) {
        return _createMockMessageToolCall(
          id: 'lang-call-1',
          functionName: TaskFunctions.setTaskLanguage,
          arguments: json,
        );
      }

      test(
        'sets language when task has no language yet (lines 1149-1162)',
        () async {
          final task = makeTask();
          when(
            () => mockJournalRepo.getJournalEntityById(task.id),
          ).thenAnswer((_) async => task);
          when(
            () => mockJournalRepo.updateJournalEntity(any()),
          ).thenAnswer((_) async => true);

          final result = await repository!.processToolCalls(
            toolCalls: [
              langCall(
                '{"languageCode":"en","confidence":"high","reason":"Detected English"}',
              ),
            ],
            task: task,
          );

          expect(result, isTrue); // languageWasSet
          verify(() => mockJournalRepo.updateJournalEntity(any())).called(1);
        },
      );

      test(
        'skips language update when task already has a language set (lines 1171-1174)',
        () async {
          final task = makeTask(languageCode: 'de');
          when(
            () => mockJournalRepo.getJournalEntityById(task.id),
          ).thenAnswer((_) async => task);

          final result = await repository!.processToolCalls(
            toolCalls: [
              langCall(
                '{"languageCode":"en","confidence":"high","reason":"Detected English"}',
              ),
            ],
            task: task,
          );

          expect(result, isFalse); // languageWasSet stays false
          verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
        },
      );

      test(
        'skips language update when freshEntity is not a Task (lines 1138-1143)',
        () async {
          final task = makeTask();
          // Return a non-Task entity to hit line 1138
          when(
            () => mockJournalRepo.getJournalEntityById(task.id),
          ).thenAnswer((_) async => JournalEntry(meta: _createMetadata()));

          final result = await repository!.processToolCalls(
            toolCalls: [
              langCall(
                '{"languageCode":"fr","confidence":"medium","reason":"French"}',
              ),
            ],
            task: task,
          );

          expect(result, isFalse);
          verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
        },
      );

      test(
        'handles updateJournalEntity failure when setting language (lines 1164-1168)',
        () async {
          final task = makeTask();
          when(
            () => mockJournalRepo.getJournalEntityById(task.id),
          ).thenAnswer((_) async => task);
          when(
            () => mockJournalRepo.updateJournalEntity(any()),
          ).thenThrow(Exception('DB write error'));

          // Should not throw despite update failure
          final result = await repository!.processToolCalls(
            toolCalls: [
              langCall(
                '{"languageCode":"es","confidence":"low","reason":"Maybe Spanish"}',
              ),
            ],
            task: task,
          );

          // languageWasSet should be false because update threw
          expect(result, isFalse);
        },
      );

      test(
        'handles malformed setTaskLanguage JSON (lines 1176-1181)',
        () async {
          final task = makeTask();

          // Should not throw — error is caught internally
          final result = await repository!.processToolCalls(
            toolCalls: [
              _createMockMessageToolCall(
                id: 'bad-lang-call',
                functionName: TaskFunctions.setTaskLanguage,
                arguments: 'not-valid-json',
              ),
            ],
            task: task,
          );

          expect(result, isFalse);
          verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
        },
      );
    },
  );

  group(
    'processToolCalls – language triggers auto-rerun when response is empty (lines 619-634)',
    () {
      test(
        're-runs inference when language is detected and response is empty',
        () async {
          final taskEntity = Task(
            meta: _createMetadata(),
            data: TaskData(
              status: TaskStatus.inProgress(
                id: 'status-1',
                createdAt: DateTime(2024, 3, 15, 10, 30),
                utcOffset: 0,
              ),
              title: 'Language Detection Test',
              statusHistory: const [],
              dateFrom: DateTime(2024, 3, 15, 10, 30),
              dateTo: DateTime(2024, 3, 15, 10, 30),
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

          // First call: returns only a language tool call with empty text
          // Second call (re-run): returns actual text
          var callCount = 0;
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
          ).thenAnswer((_) async => '{"task":"details"}');

          when(
            () => mockJournalRepo.getJournalEntityById(taskEntity.id),
          ).thenAnswer((_) async => taskEntity);
          when(
            () => mockJournalRepo.updateJournalEntity(any()),
          ).thenAnswer((_) async => true);

          when(
            () => mockCloudInferenceRepo.generate(
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
            ),
          ).thenAnswer((_) {
            callCount++;
            if (callCount == 1) {
              // First run: language tool call, no text
              return Stream.fromIterable([
                _createStreamChunkWithToolCalls([
                  _createMockToolCall(
                    index: 0,
                    id: 'lang-1',
                    functionName: TaskFunctions.setTaskLanguage,
                    arguments:
                        '{"languageCode":"de","confidence":"high","reason":"German text"}',
                  ),
                ]),
              ]);
            } else {
              // Second run (re-run): returns the actual summary
              return _createMockTextStream(['Task summary in German']);
            }
          });

          _stubCreateAiResponseEntry(mockAiInputRepo);

          final statusChanges = <InferenceStatus>[];
          await repository!.runInference(
            entityId: taskEntity.id,
            promptConfig: promptConfig,
            onProgress: (_) {},
            onStatusChange: statusChanges.add,
          );

          // Both runs completed → language was set and rerun happened
          expect(callCount, 2);
          expect(statusChanges, contains(InferenceStatus.idle));
        },
      );
    },
  );

  group('processToolCalls – suggestChecklistCompletion edge cases', () {
    Task makeTask2({String id = 'task-1'}) {
      return Task(
        meta: _createMetadata(id: id),
        data: TaskData(
          status: TaskStatus.open(
            id: 'status-1',
            createdAt: DateTime(2024, 3, 15),
            utcOffset: 0,
          ),
          title: 'Edge Case Task',
          statusHistory: const [],
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
          checklistIds: const ['checklist-1'],
        ),
      );
    }

    test(
      'skips when arguments contain no valid JSON object (line 906-911 — empty jsonObjects)',
      () async {
        final task = makeTask2();

        final result = await repository!.processToolCalls(
          toolCalls: [
            _createMockMessageToolCall(
              id: 'bad-call',
              functionName:
                  ChecklistCompletionFunctions.suggestChecklistCompletion,
              // No {} braces → no JSON objects found
              arguments: 'no-braces-here',
            ),
          ],
          task: task,
        );

        expect(result, isFalse);
        expect(testChecklistCompletionService.capturedSuggestions, isEmpty);
      },
    );

    test(
      'uses orElse confidence fallback for unknown confidence value (line 932)',
      () async {
        final task = makeTask2();

        when(
          () => mockJournalRepo.getJournalEntityById(any()),
        ).thenAnswer((_) async => null);

        final result = await repository!.processToolCalls(
          toolCalls: [
            _createMockMessageToolCall(
              id: 'unknown-confidence',
              functionName:
                  ChecklistCompletionFunctions.suggestChecklistCompletion,
              // 'extreme' is not a valid confidence level → orElse fallback
              arguments:
                  '{"checklistItemId":"item-x","reason":"Test","confidence":"extreme"}',
            ),
          ],
          task: task,
        );

        expect(result, isFalse);
        expect(testChecklistCompletionService.capturedSuggestions.length, 1);
        expect(
          testChecklistCompletionService.capturedSuggestions.first.confidence,
          ChecklistCompletionConfidence.low,
        );
      },
    );

    test(
      'logs and skips invalid JSON within arguments (lines 942-946)',
      () async {
        final task = makeTask2();

        // A valid outer JSON structure is needed so jsonObjects is non-empty, but
        // the inner content has a broken type cast.
        final result = await repository!.processToolCalls(
          toolCalls: [
            _createMockMessageToolCall(
              id: 'bad-inner',
              functionName:
                  ChecklistCompletionFunctions.suggestChecklistCompletion,
              // checklistItemId is missing → cast to String throws
              arguments: '{"reason":"test","confidence":"high"}',
            ),
          ],
          task: task,
        );

        expect(result, isFalse);
        // No suggestion should have been added because parsing threw
        expect(testChecklistCompletionService.capturedSuggestions, isEmpty);
      },
    );
  });

  group('processToolCalls – add_multiple_checklist_items edge cases', () {
    Task makeTaskNoChecklists() {
      return Task(
        meta: _createMetadata(id: 'task-no-cl'),
        data: TaskData(
          status: TaskStatus.open(
            id: 'status-1',
            createdAt: DateTime(2024, 3, 15),
            utcOffset: 0,
          ),
          title: 'No Checklist Task',
          statusHistory: const [],
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
        ),
      );
    }

    test('skips when items field is not a List (line 958-963)', () async {
      final task = makeTaskNoChecklists();

      final result = await repository!.processToolCalls(
        toolCalls: [
          _createMockMessageToolCall(
            id: 'bad-items',
            functionName:
                ChecklistCompletionFunctions.addMultipleChecklistItems,
            arguments: '{"items":"not-a-list"}',
          ),
        ],
        task: task,
      );

      expect(result, isFalse);
      verifyNever(
        () => mockAutoChecklistService.autoCreateChecklist(
          taskId: any(named: 'taskId'),
          suggestions: any(named: 'suggestions'),
        ),
      );
    });

    test('skips when batch size exceeds maximum (lines 968-973)', () async {
      // Build an array with 21 items (maxBatchSize is 20)
      final items = List.generate(
        21,
        (i) => '{"title":"Item $i","isChecked":false}',
      ).join(',');

      final task = makeTaskNoChecklists();

      final result = await repository!.processToolCalls(
        toolCalls: [
          _createMockMessageToolCall(
            id: 'too-many',
            functionName:
                ChecklistCompletionFunctions.addMultipleChecklistItems,
            arguments: '{"items":[$items]}',
          ),
        ],
        task: task,
      );

      expect(result, isFalse);
      verifyNever(
        () => mockAutoChecklistService.autoCreateChecklist(
          taskId: any(named: 'taskId'),
          suggestions: any(named: 'suggestions'),
        ),
      );
    });

    test(
      'breaks out of loop when task is not found after checklist creation (lines 1031-1036)',
      () async {
        // Task starts with no checklist IDs
        final task = Task(
          meta: _createMetadata(id: 'task-disappears'),
          data: TaskData(
            status: TaskStatus.open(
              id: 'status-1',
              createdAt: DateTime(2024, 3, 15),
              utcOffset: 0,
            ),
            title: 'Disappearing Task',
            statusHistory: const [],
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
            checklistIds: const [],
          ),
        );

        // autoCreateChecklist succeeds
        when(
          () => mockAutoChecklistService.autoCreateChecklist(
            taskId: task.id,
            suggestions: any(named: 'suggestions'),
            title: any(named: 'title'),
          ),
        ).thenAnswer(
          (_) async => (
            success: true,
            checklistId: 'new-cl',
            createdItems: <({String id, String title, bool isChecked})>[],
            error: null,
          ),
        );

        // But the journalDb can no longer find the task after creation
        // (simulates concurrent deletion)
        when(
          () => mockJournalDb.journalEntityById(task.id),
        ).thenAnswer((_) async => null);

        final result = await repository!.processToolCalls(
          toolCalls: [
            _createMockMessageToolCall(
              id: 'add-cl',
              functionName:
                  ChecklistCompletionFunctions.addMultipleChecklistItems,
              arguments:
                  '{"items":[{"title":"Do something","isChecked":false}]}',
            ),
          ],
          task: task,
        );

        expect(result, isFalse);
      },
    );

    test(
      'logs error when autoCreateChecklist fails (lines 1039-1043)',
      () async {
        final task = Task(
          meta: _createMetadata(id: 'task-cl-fail'),
          data: TaskData(
            status: TaskStatus.open(
              id: 'status-1',
              createdAt: DateTime(2024, 3, 15),
              utcOffset: 0,
            ),
            title: 'Failing Checklist Task',
            statusHistory: const [],
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
            checklistIds: const [],
          ),
        );

        when(
          () => mockAutoChecklistService.autoCreateChecklist(
            taskId: task.id,
            suggestions: any(named: 'suggestions'),
            title: any(named: 'title'),
          ),
        ).thenAnswer(
          (_) async => (
            success: false,
            checklistId: null,
            createdItems: null,
            error: 'Creation failed',
          ),
        );

        final result = await repository!.processToolCalls(
          toolCalls: [
            _createMockMessageToolCall(
              id: 'add-fail',
              functionName:
                  ChecklistCompletionFunctions.addMultipleChecklistItems,
              arguments: '{"items":[{"title":"Item 1","isChecked":false}]}',
            ),
          ],
          task: task,
        );

        expect(result, isFalse);
      },
    );
  });

  group(
    'processToolCalls – update_checklist_items failure path (lines 1093-1116)',
    () {
      test(
        'logs when processFunctionCall returns failure (lines 1093-1097)',
        () async {
          final task = Task(
            meta: _createMetadata(id: 'task-update-fail'),
            data: TaskData(
              status: TaskStatus.open(
                id: 'status-1',
                createdAt: DateTime(2024, 3, 15),
                utcOffset: 0,
              ),
              title: 'Update Fail Task',
              statusHistory: const [],
              dateFrom: DateTime(2024, 3, 15),
              dateTo: DateTime(2024, 3, 15),
              checklistIds: const ['checklist-1'],
            ),
          );

          // Invalid JSON structure → processFunctionCall returns failure
          final result = await repository!.processToolCalls(
            toolCalls: [
              _createMockMessageToolCall(
                id: 'bad-update',
                functionName: ChecklistCompletionFunctions.updateChecklistItems,
                arguments: '{"items": "not-array"}',
              ),
            ],
            task: task,
          );

          expect(result, isFalse);
        },
      );

      test(
        'catches exception thrown during update_checklist_items (lines 1110-1115)',
        () async {
          final task = Task(
            meta: _createMetadata(id: 'task-update-throw'),
            data: TaskData(
              status: TaskStatus.open(
                id: 'status-1',
                createdAt: DateTime(2024, 3, 15),
                utcOffset: 0,
              ),
              title: 'Update Throw Task',
              statusHistory: const [],
              dateFrom: DateTime(2024, 3, 15),
              dateTo: DateTime(2024, 3, 15),
              checklistIds: const ['checklist-1'],
            ),
          );

          // DB throws during entriesForIds lookup inside executeUpdates
          final mockSelectable = MockSelectableSimple<JournalDbEntity>();
          when(mockSelectable.get).thenThrow(Exception('DB exploded'));
          when(
            () => mockJournalDb.entriesForIds(any()),
          ).thenReturn(mockSelectable);

          // Should not rethrow; caught internally
          final result = await repository!.processToolCalls(
            toolCalls: [
              _createMockMessageToolCall(
                id: 'throw-update',
                functionName: ChecklistCompletionFunctions.updateChecklistItems,
                arguments: '{"items":[{"id":"item-1","isChecked":true}]}',
              ),
            ],
            task: task,
          );

          expect(result, isFalse);
        },
      );
    },
  );

  group(
    'processToolCalls – assign_task_labels empty requested set (line 1193)',
    () {
      test(
        'skips when parseLabelCallArgs returns empty selected IDs',
        () async {
          final task = Task(
            meta: _createMetadata(id: 'task-empty-labels'),
            data: TaskData(
              status: TaskStatus.open(
                id: 'status-1',
                createdAt: DateTime(2024, 3, 15),
                utcOffset: 0,
              ),
              title: 'Label Task',
              statusHistory: const [],
              dateFrom: DateTime(2024, 3, 15),
              dateTo: DateTime(2024, 3, 15),
            ),
          );

          // Empty labelIds → parseLabelCallArgs returns no selectedIds
          final result = await repository!.processToolCalls(
            toolCalls: [
              _createMockMessageToolCall(
                id: 'empty-labels',
                functionName: LabelFunctions.assignTaskLabels,
                arguments: '{"labelIds":[]}',
              ),
            ],
            task: task,
          );

          expect(result, isFalse);
          verifyNever(
            () => mockLabelsRepository.addLabels(
              journalEntityId: any(named: 'journalEntityId'),
              addedLabelIds: any(named: 'addedLabelIds'),
            ),
          );
        },
      );
    },
  );

  group(
    'processToolCalls – assign_task_labels successful path (lines 1246-1247)',
    () {
      test(
        'calls processAssignment and logs result when labels are valid',
        () async {
          final task = Task(
            meta: _createMetadata(id: 'task-valid-labels'),
            data: TaskData(
              status: TaskStatus.open(
                id: 'status-1',
                createdAt: DateTime(2024, 3, 15),
                utcOffset: 0,
              ),
              title: 'Label Assignment Task',
              statusHistory: const [],
              dateFrom: DateTime(2024, 3, 15),
              dateTo: DateTime(2024, 3, 15),
            ),
          );

          // LabelAssignmentProcessor calls getIt<DomainLogger>() in its
          // constructor — register a mock so the constructor doesn't throw.
          final mockDomainLogger = MockDomainLogger();
          if (!getIt.isRegistered<DomainLogger>()) {
            getIt.registerSingleton<DomainLogger>(mockDomainLogger);
          }
          addTearDown(() {
            if (getIt.isRegistered<DomainLogger>()) {
              getIt.unregister<DomainLogger>();
            }
          });

          // Build real LabelDefinition fixtures — global (no applicableCategoryIds)
          // and not deleted (no deletedAt) so the validator marks them valid.
          LabelDefinition makeLabelDef(String id) => LabelDefinition(
            id: id,
            name: id,
            color: '#000000',
            vectorClock: null,
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
          );
          final labelA = makeLabelDef('label-A');
          final labelB = makeLabelDef('label-B');

          // LabelAssignmentProcessor uses getIt<JournalDb>() directly:
          // stub journalEntityById so task suppression fetch works.
          when(
            () => mockJournalDb.journalEntityById(task.id),
          ).thenAnswer((_) async => task);
          // Return matching LabelDefinition for each requested ID so the
          // LabelValidator places them in the "valid" bucket.
          when(
            () => mockJournalDb.getLabelDefinitionById('label-A'),
          ).thenAnswer((_) async => labelA);
          when(
            () => mockJournalDb.getLabelDefinitionById('label-B'),
          ).thenAnswer((_) async => labelB);
          // Stub addLabels so the repository call in the success path completes.
          when(
            () => mockLabelsRepository.addLabels(
              journalEntityId: task.id,
              addedLabelIds: any(named: 'addedLabelIds'),
            ),
          ).thenAnswer((_) async => true);

          final result = await repository!.processToolCalls(
            toolCalls: [
              _createMockMessageToolCall(
                id: 'valid-labels',
                functionName: LabelFunctions.assignTaskLabels,
                arguments: '{"labelIds":["label-A","label-B"]}',
              ),
            ],
            task: task,
          );

          // processToolCalls returns languageWasSet; label assignment doesn't
          // flip that flag.
          expect(result, isFalse);
          // The success path (lines 1246-1247) must have called addLabels with
          // both validated label IDs.
          final captured = verify(
            () => mockLabelsRepository.addLabels(
              journalEntityId: task.id,
              addedLabelIds: captureAny(named: 'addedLabelIds'),
            ),
          ).captured;
          final assignedIds = captured.single as List<String>;
          expect(assignedIds, containsAll(['label-A', 'label-B']));
          expect(assignedIds, hasLength(2));
        },
      );
    },
  );

  group('processToolCalls – unknown tool call (lines 1261-1262)', () {
    test('logs and skips unknown function name', () async {
      final task = Task(
        meta: _createMetadata(id: 'task-unknown-tool'),
        data: TaskData(
          status: TaskStatus.open(
            id: 'status-1',
            createdAt: DateTime(2024, 3, 15),
            utcOffset: 0,
          ),
          title: 'Unknown Tool Task',
          statusHistory: const [],
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
        ),
      );

      // Should not throw
      final result = await repository!.processToolCalls(
        toolCalls: [
          _createMockMessageToolCall(
            id: 'unknown-tool',
            functionName: 'completely_unknown_function',
            arguments: '{}',
          ),
        ],
        task: task,
      );

      expect(result, isFalse);
    });
  });

  group(
    'processToolCalls – assign_task_labels suppressed-only short-circuit '
    '(lines 1213-1233)',
    () {
      test(
        'skips processAssignment when every requested label is suppressed',
        () async {
          // LabelAssignmentProcessor's constructor resolves getIt<DomainLogger>
          // even though processAssignment is never reached on this path.
          final mockDomainLogger = MockDomainLogger();
          if (!getIt.isRegistered<DomainLogger>()) {
            getIt.registerSingleton<DomainLogger>(mockDomainLogger);
          }
          addTearDown(() {
            if (getIt.isRegistered<DomainLogger>()) {
              getIt.unregister<DomainLogger>();
            }
          });

          // Both requested labels (X, Y) are on the task's suppression set, so
          // `proposed` becomes empty while `requested` is non-empty, taking the
          // suppressed-only short-circuit (builds the skipped list + noop result
          // and logs it, then continues without assigning).
          final task = Task(
            meta: _createMetadata(id: 'task-suppressed-only'),
            data: TaskData(
              status: TaskStatus.open(
                id: 'status-1',
                createdAt: DateTime(2024, 3, 15),
                utcOffset: 0,
              ),
              title: 'Suppressed Labels Task',
              statusHistory: const [],
              dateFrom: DateTime(2024, 3, 15),
              dateTo: DateTime(2024, 3, 15),
              aiSuppressedLabelIds: const {'X', 'Y'},
            ),
          );

          final result = await repository!.processToolCalls(
            toolCalls: [
              _createMockMessageToolCall(
                id: 'suppressed-labels',
                functionName: LabelFunctions.assignTaskLabels,
                arguments: '{"labelIds":["X","Y"]}',
              ),
            ],
            task: task,
          );

          // languageWasSet is never flipped by label assignment.
          expect(result, isFalse);
          // The short-circuit must NOT persist anything: processAssignment is
          // skipped, so addLabels is never invoked.
          verifyNever(
            () => mockLabelsRepository.addLabels(
              journalEntityId: any(named: 'journalEntityId'),
              addedLabelIds: any(named: 'addedLabelIds'),
            ),
          );
        },
      );
    },
  );

  group(
    'processToolCalls – update_checklist_items refreshes task on success '
    '(line 1085 onTaskUpdated)',
    () {
      test(
        'invokes onTaskUpdated after a successful item update',
        () async {
          final task = Task(
            meta: _createMetadata(id: 'task-update-success'),
            data: TaskData(
              status: TaskStatus.open(
                id: 'status-1',
                createdAt: DateTime(2024, 3, 15),
                utcOffset: 0,
              ),
              title: 'Update Success Task',
              statusHistory: const [],
              dateFrom: DateTime(2024, 3, 15),
              dateTo: DateTime(2024, 3, 15),
              checklistIds: const ['checklist-1'],
            ),
          );

          // A real checklist item that belongs to the task's checklist and is
          // currently unchecked — flipping isChecked is a genuine change.
          final checklistItem = ChecklistItem(
            meta: _createMetadata(id: 'item-1'),
            data: const ChecklistItemData(
              title: 'Buy milk',
              isChecked: false,
              linkedChecklists: ['checklist-1'],
              // Agent-owned so the sovereignty guard allows the override.
              checkedBy: ChangeSource.agent,
            ),
          );

          // executeUpdates fetches items via entriesForIds(...).get() and
          // converts each row back through fromDbEntity, so we round-trip the
          // real ChecklistItem through toDbEntity.
          final mockSelectable = MockSelectableSimple<JournalDbEntity>();
          when(
            mockSelectable.get,
          ).thenAnswer((_) async => [toDbEntity(checklistItem)]);
          when(
            () => mockJournalDb.entriesForIds(['item-1']),
          ).thenReturn(mockSelectable);

          // The actual write succeeds, driving successCount > 0.
          when(
            () => mockChecklistRepo.updateChecklistItem(
              checklistItemId: 'item-1',
              data: any(named: 'data'),
              taskId: task.id,
            ),
          ).thenAnswer((_) async => true);

          // After a successful update the handler re-fetches the task; returning
          // a Task triggers the onTaskUpdated callback (line 1085) which swaps
          // currentTask for the refreshed instance.
          final refreshedTask = task.copyWith(
            data: task.data.copyWith(title: 'Refreshed Task Title'),
          );
          when(
            () => mockJournalDb.journalEntityById(task.id),
          ).thenAnswer((_) async => refreshedTask);

          final result = await repository!.processToolCalls(
            toolCalls: [
              _createMockMessageToolCall(
                id: 'update-success',
                functionName: ChecklistCompletionFunctions.updateChecklistItems,
                arguments:
                    '{"items":[{"id":"item-1","isChecked":true,'
                    '"reason":"Confirmed done in the latest standup notes"}]}',
              ),
            ],
            task: task,
          );

          // update_checklist_items never sets language.
          expect(result, isFalse);
          // The write must have happened with the flipped, agent-stamped state.
          verify(
            () => mockChecklistRepo.updateChecklistItem(
              checklistItemId: 'item-1',
              data: any(
                named: 'data',
                that: isA<ChecklistItemData>()
                    .having((d) => d.isChecked, 'isChecked', true)
                    .having(
                      (d) => d.checkedBy,
                      'checkedBy',
                      ChangeSource.agent,
                    ),
              ),
              taskId: task.id,
            ),
          ).called(1);
          // The success branch re-fetched the task to refresh currentTask,
          // proving the onTaskUpdated callback path executed.
          verify(() => mockJournalDb.journalEntityById(task.id)).called(1);
        },
      );
    },
  );
}

// Helper methods to create test objects
final _fixedDate = DateTime(2025);

Metadata _createMetadata({String? id, String? categoryId}) {
  return Metadata(
    id: id ?? 'test-id',
    createdAt: _fixedDate,
    updatedAt: _fixedDate,
    dateFrom: _fixedDate,
    dateTo: _fixedDate,
    categoryId: categoryId,
  );
}

AiConfigInferenceProvider _createAiProvider({
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

AiConfigPrompt _createPrompt({
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
    createdAt: DateTime(2024, 3, 15, 10, 30),
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
    createdAt: DateTime(2024, 3, 15, 10, 30),
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
    created: DateTime(2024, 3, 15, 10, 30).millisecondsSinceEpoch ~/ 1000,
    model: 'test-model',
    object: 'chat.completion.chunk',
  );
}

/// Creates a mock stream of text chunks. The last chunk includes a stop
/// finish reason. Replaces verbose inline [Stream.fromIterable] blocks.
Stream<CreateChatCompletionStreamResponse> _createMockTextStream(
  List<String> chunks,
) {
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
      ),
  ]);
}

/// Stubs `CloudInferenceRepository.generate` to return [stream].
void _stubGenerate(
  MockCloudInferenceRepository mock, {
  required Stream<CreateChatCompletionStreamResponse> stream,
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
    ),
  ).thenAnswer((_) => stream);
}

/// Stubs `CloudInferenceRepository.generateWithImages` to return [stream].
void _stubGenerateWithImages(
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
    ),
  ).thenAnswer((_) => stream);
}

/// Stubs `CloudInferenceRepository.generateWithAudio` to return [stream].
void _stubGenerateWithAudio(
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
void _stubInferenceContext({
  required MockAiInputRepository mockAiInputRepo,
  required MockAiConfigRepository mockAiConfigRepo,
  required JournalEntity entity,
  required AiConfigModel model,
  required AiConfigInferenceProvider provider,
  String? entityId,
  String taskDetailsJson = '{"task": "Test Task"}',
}) {
  final id = entityId ?? entity.id;
  when(
    () => mockAiInputRepo.getEntity(id),
  ).thenAnswer((_) async => entity);
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
void _stubCreateAiResponseEntry(MockAiInputRepository mock) {
  when(
    () => mock.createAiResponseEntry(
      data: any(named: 'data'),
      start: any(named: 'start'),
      linkedId: any(named: 'linkedId'),
      categoryId: any(named: 'categoryId'),
    ),
  ).thenAnswer((_) async => null);
}

CreateChatCompletionStreamResponse _createStreamChunkWithToolCalls(
  List<ChatCompletionStreamMessageToolCallChunk> toolCalls,
) {
  return CreateChatCompletionStreamResponse(
    id: 'test-completion-id',
    choices: [
      ChatCompletionStreamResponseChoice(
        index: 0,
        delta: ChatCompletionStreamResponseDelta(
          toolCalls: toolCalls,
        ),
      ),
    ],
    created: DateTime(2024, 3, 15, 10, 30).millisecondsSinceEpoch ~/ 1000,
    model: 'test-model',
    object: 'chat.completion.chunk',
  );
}

ChatCompletionMessageToolCall _createMockMessageToolCall({
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
ChatCompletionStreamMessageToolCallChunk _createMockToolCall({
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
