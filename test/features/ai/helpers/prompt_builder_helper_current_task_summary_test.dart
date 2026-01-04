import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai/helpers/prompt_builder_helper.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../labels/label_assignment_processor_test.dart' as label_test
    show MockLabelsRepository;

class MockAiInputRepository extends Mock implements AiInputRepository {}

class MockJournalRepository extends Mock implements JournalRepository {}

class MockChecklistRepository extends Mock implements ChecklistRepository {}

class MockEntitiesCacheService extends Mock implements EntitiesCacheService {}

void main() {
  late PromptBuilderHelper promptBuilder;
  late MockAiInputRepository mockAiInputRepository;
  late MockJournalRepository mockJournalRepository;
  late MockChecklistRepository mockChecklistRepository;
  late label_test.MockLabelsRepository mockLabelsRepository;
  late MockEntitiesCacheService mockEntitiesCacheService;

  final testTask = Task(
    data: TaskData(
      title: 'Test Task',
      checklistIds: const [],
      status: TaskStatus.open(
        id: 'status',
        createdAt: DateTime(2025),
        utcOffset: 0,
      ),
      statusHistory: const [],
      dateFrom: DateTime(2025),
      dateTo: DateTime(2025),
    ),
    meta: Metadata(
      id: 'task-1',
      createdAt: DateTime(2025),
      dateFrom: DateTime(2025),
      dateTo: DateTime(2025),
      updatedAt: DateTime(2025),
      categoryId: 'category-1',
    ),
  );

  final testAudio = JournalAudio(
    meta: Metadata(
      id: 'audio-1',
      createdAt: DateTime(2025),
      dateFrom: DateTime(2025),
      dateTo: DateTime(2025),
      updatedAt: DateTime(2025),
    ),
    data: AudioData(
      audioFile: 'test.m4a',
      audioDirectory: '/tmp',
      dateFrom: DateTime(2025),
      dateTo: DateTime(2025),
      duration: const Duration(seconds: 30),
      transcripts: [
        AudioTranscript(
          transcript: 'Test transcript',
          created: DateTime(2025),
          library: 'test',
          model: 'test-model',
          detectedLanguage: 'en',
        ),
      ],
    ),
  );

  final testImage = JournalImage(
    meta: Metadata(
      id: 'image-1',
      createdAt: DateTime(2025),
      dateFrom: DateTime(2025),
      dateTo: DateTime(2025),
      updatedAt: DateTime(2025),
    ),
    data: ImageData(
      imageId: 'image-1',
      imageFile: 'test.jpg',
      imageDirectory: '/tmp',
      capturedAt: DateTime(2025),
    ),
  );

  AiResponseEntry buildTaskSummary({
    required String id,
    required String response,
    required DateTime dateFrom,
  }) {
    return AiResponseEntry(
      meta: Metadata(
        id: id,
        createdAt: dateFrom,
        dateFrom: dateFrom,
        dateTo: dateFrom,
        updatedAt: dateFrom,
      ),
      data: AiResponseData(
        response: response,
        type: AiResponseType.taskSummary,
        model: 'test-model',
        systemMessage: 'System message',
        prompt: 'Test prompt',
        thoughts: '',
        promptId: 'prompt-1',
      ),
    );
  }

  setUpAll(() {
    registerFallbackValue(fallbackJournalEntity);
  });

  setUp(() {
    mockAiInputRepository = MockAiInputRepository();
    mockJournalRepository = MockJournalRepository();
    mockChecklistRepository = MockChecklistRepository();
    mockLabelsRepository = label_test.MockLabelsRepository();
    mockEntitiesCacheService = MockEntitiesCacheService();

    // Register mock EntitiesCacheService
    if (getIt.isRegistered<EntitiesCacheService>()) {
      getIt.unregister<EntitiesCacheService>();
    }
    getIt.registerSingleton<EntitiesCacheService>(mockEntitiesCacheService);

    // Default stubs
    when(() => mockLabelsRepository.getAllLabels()).thenAnswer((_) async => []);
    when(() => mockLabelsRepository.getLabelUsageCounts())
        .thenAnswer((_) async => {});
    when(() => mockLabelsRepository.buildLabelTuples(any()))
        .thenAnswer((_) async => []);
    when(
      () => mockAiInputRepository.buildTaskDetailsJson(
        id: any<String>(named: 'id'),
      ),
    ).thenAnswer((_) async => null);

    promptBuilder = PromptBuilderHelper(
      aiInputRepository: mockAiInputRepository,
      journalRepository: mockJournalRepository,
      checklistRepository: mockChecklistRepository,
      labelsRepository: mockLabelsRepository,
    );
  });

  tearDown(() async {
    if (getIt.isRegistered<EntitiesCacheService>()) {
      getIt.unregister<EntitiesCacheService>();
    }
  });

  group('PromptBuilderHelper - Current Task Summary Placeholder', () {
    group('buildPromptWithData - {{current_task_summary}}', () {
      test('injects latest task summary for task entity', () async {
        final summary1 = buildTaskSummary(
          id: 'summary-1',
          response: 'Old summary from yesterday',
          dateFrom: DateTime(2025),
        );
        final summary2 = buildTaskSummary(
          id: 'summary-2',
          response: 'Latest summary with learnings and annoyances',
          dateFrom: DateTime(2025, 1, 2),
        );

        when(() =>
                mockJournalRepository.getLinkedToEntities(linkedTo: 'task-1'))
            .thenAnswer((_) async => [summary1, summary2]);

        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Generate Image',
          systemMessage: 'System message',
          userMessage: 'Summary: {{current_task_summary}}\n\nGenerate image.',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025),
          useReasoning: false,
          requiredInputData: const [],
          aiResponseType: AiResponseType.imageGeneration,
        );

        final result = await promptBuilder.buildPromptWithData(
          promptConfig: config,
          entity: testTask,
        );

        expect(result, isNotNull);
        expect(
            result, contains('Latest summary with learnings and annoyances'));
        expect(result, isNot(contains('Old summary from yesterday')));
        expect(result, isNot(contains('{{current_task_summary}}')));
      });

      test('returns fallback when no task summary exists', () async {
        when(() =>
                mockJournalRepository.getLinkedToEntities(linkedTo: 'task-1'))
            .thenAnswer((_) async => []);

        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Generate Image',
          systemMessage: 'System message',
          userMessage: 'Summary: {{current_task_summary}}',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025),
          useReasoning: false,
          requiredInputData: const [],
          aiResponseType: AiResponseType.imageGeneration,
        );

        final result = await promptBuilder.buildPromptWithData(
          promptConfig: config,
          entity: testTask,
        );

        expect(result, isNotNull);
        expect(result, contains('[No task summary available]'));
      });

      test('finds linked task for audio entity and injects its summary',
          () async {
        final summary = buildTaskSummary(
          id: 'summary-1',
          response: 'Task summary for linked task',
          dateFrom: DateTime(2025),
        );

        // Audio links TO task-1 (via getLinkedEntities)
        when(() => mockJournalRepository.getLinkedEntities(linkedTo: 'audio-1'))
            .thenAnswer((_) async => [testTask]);
        // Task-1 has linked summaries
        when(() =>
                mockJournalRepository.getLinkedToEntities(linkedTo: 'task-1'))
            .thenAnswer((_) async => [summary]);

        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Generate Image',
          systemMessage: 'System message',
          userMessage: 'Summary: {{current_task_summary}}',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025),
          useReasoning: false,
          requiredInputData: const [],
          aiResponseType: AiResponseType.imageGeneration,
        );

        final result = await promptBuilder.buildPromptWithData(
          promptConfig: config,
          entity: testAudio,
        );

        expect(result, isNotNull);
        expect(result, contains('Task summary for linked task'));
      });

      test('returns fallback when audio not linked to any task', () async {
        // Audio doesn't link TO any task
        when(() => mockJournalRepository.getLinkedEntities(linkedTo: 'audio-1'))
            .thenAnswer((_) async => []);
        // Fallback: no tasks link TO audio either
        when(() =>
                mockJournalRepository.getLinkedToEntities(linkedTo: 'audio-1'))
            .thenAnswer((_) async => []);

        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Generate Image',
          systemMessage: 'System message',
          userMessage: 'Summary: {{current_task_summary}}',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025),
          useReasoning: false,
          requiredInputData: const [],
          aiResponseType: AiResponseType.imageGeneration,
        );

        final result = await promptBuilder.buildPromptWithData(
          promptConfig: config,
          entity: testAudio,
        );

        expect(result, isNotNull);
        expect(result, contains('[No task summary available]'));
      });

      test('finds linked task for image entity and injects its summary',
          () async {
        final summary = buildTaskSummary(
          id: 'summary-1',
          response: 'Task summary via image',
          dateFrom: DateTime(2025),
        );

        // Image links TO task-1 (via getLinkedEntities)
        when(() => mockJournalRepository.getLinkedEntities(linkedTo: 'image-1'))
            .thenAnswer((_) async => [testTask]);
        // Task-1 has linked summaries
        when(() =>
                mockJournalRepository.getLinkedToEntities(linkedTo: 'task-1'))
            .thenAnswer((_) async => [summary]);

        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Generate Image',
          systemMessage: 'System message',
          userMessage: 'Summary: {{current_task_summary}}',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025),
          useReasoning: false,
          requiredInputData: const [],
          aiResponseType: AiResponseType.imageGeneration,
        );

        final result = await promptBuilder.buildPromptWithData(
          promptConfig: config,
          entity: testImage,
        );

        expect(result, isNotNull);
        expect(result, contains('Task summary via image'));
      });

      test('ignores non-taskSummary AI responses', () async {
        // Create a different type of AI response
        final transcriptionResponse = AiResponseEntry(
          meta: Metadata(
            id: 'ai-response-1',
            createdAt: DateTime(2025, 1, 2),
            dateFrom: DateTime(2025, 1, 2),
            dateTo: DateTime(2025, 1, 2),
            updatedAt: DateTime(2025, 1, 2),
          ),
          data: const AiResponseData(
            response: 'This is a transcription, not a summary',
            type: AiResponseType.audioTranscription,
            model: 'test-model',
            systemMessage: 'System message',
            prompt: 'Transcription prompt',
            thoughts: '',
            promptId: 'prompt-1',
          ),
        );

        when(() =>
                mockJournalRepository.getLinkedToEntities(linkedTo: 'task-1'))
            .thenAnswer((_) async => [transcriptionResponse]);

        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Generate Image',
          systemMessage: 'System message',
          userMessage: 'Summary: {{current_task_summary}}',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025),
          useReasoning: false,
          requiredInputData: const [],
          aiResponseType: AiResponseType.imageGeneration,
        );

        final result = await promptBuilder.buildPromptWithData(
          promptConfig: config,
          entity: testTask,
        );

        expect(result, isNotNull);
        // Should return fallback since no taskSummary type found
        expect(result, contains('[No task summary available]'));
      });

      test('selects most recent summary when multiple exist', () async {
        final oldSummary = buildTaskSummary(
          id: 'summary-old',
          response: 'Old summary',
          dateFrom: DateTime(2025),
        );
        final middleSummary = buildTaskSummary(
          id: 'summary-middle',
          response: 'Middle summary',
          dateFrom: DateTime(2025, 1, 5),
        );
        final newestSummary = buildTaskSummary(
          id: 'summary-newest',
          response: 'Newest summary',
          dateFrom: DateTime(2025, 1, 10),
        );

        // Return in mixed order to test sorting
        when(() =>
                mockJournalRepository.getLinkedToEntities(linkedTo: 'task-1'))
            .thenAnswer(
          (_) async => [middleSummary, oldSummary, newestSummary],
        );

        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Generate Image',
          systemMessage: 'System message',
          userMessage: 'Summary: {{current_task_summary}}',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025),
          useReasoning: false,
          requiredInputData: const [],
          aiResponseType: AiResponseType.imageGeneration,
        );

        final result = await promptBuilder.buildPromptWithData(
          promptConfig: config,
          entity: testTask,
        );

        expect(result, isNotNull);
        expect(result, contains('Newest summary'));
        expect(result, isNot(contains('Old summary')));
        expect(result, isNot(contains('Middle summary')));
      });

      test('leaves prompt unchanged if placeholder not present', () async {
        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Simple Prompt',
          systemMessage: 'System message',
          userMessage: 'Generate something without task summary.',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025),
          useReasoning: false,
          requiredInputData: const [],
          aiResponseType: AiResponseType.imageGeneration,
        );

        final result = await promptBuilder.buildPromptWithData(
          promptConfig: config,
          entity: testTask,
        );

        expect(result, isNotNull);
        expect(result, equals('Generate something without task summary.'));
        // Should not have called getLinkedToEntities since placeholder absent
        verifyNever(
          () => mockJournalRepository.getLinkedToEntities(
              linkedTo: any(named: 'linkedTo')),
        );
      });

      test('handles error gracefully and returns fallback', () async {
        when(() =>
                mockJournalRepository.getLinkedToEntities(linkedTo: 'task-1'))
            .thenThrow(Exception('Database error'));

        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Generate Image',
          systemMessage: 'System message',
          userMessage: 'Summary: {{current_task_summary}}',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025),
          useReasoning: false,
          requiredInputData: const [],
          aiResponseType: AiResponseType.imageGeneration,
        );

        final result = await promptBuilder.buildPromptWithData(
          promptConfig: config,
          entity: testTask,
        );

        expect(result, isNotNull);
        expect(result, contains('[No task summary available]'));
      });
    });
  });
}
