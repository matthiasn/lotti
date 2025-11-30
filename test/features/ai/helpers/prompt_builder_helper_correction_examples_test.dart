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

  final testCategoryWithExamples = CategoryDefinition(
    id: 'category-1',
    name: 'Test Category',
    createdAt: DateTime(2025),
    updatedAt: DateTime(2025),
    vectorClock: null,
    private: false,
    active: true,
    color: '#FF0000',
    correctionExamples: [
      ChecklistCorrectionExample(
        before: 'test flight',
        after: 'TestFlight',
        capturedAt: DateTime(2025, 1, 3),
      ),
      ChecklistCorrectionExample(
        before: 'mac os',
        after: 'macOS',
        capturedAt: DateTime(2025, 1, 2),
      ),
      ChecklistCorrectionExample(
        before: 'i phone',
        after: 'iPhone',
        capturedAt: DateTime(2025),
      ),
    ],
  );

  final testCategoryNoExamples = CategoryDefinition(
    id: 'category-2',
    name: 'Category No Examples',
    createdAt: DateTime(2025),
    updatedAt: DateTime(2025),
    vectorClock: null,
    private: false,
    active: true,
    color: '#00FF00',
  );

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
    ),
  );

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

  group('PromptBuilderHelper - Correction Examples', () {
    group('buildPromptWithData - correction_examples placeholder', () {
      test('injects correction examples for checklistUpdates response type',
          () async {
        when(() => mockEntitiesCacheService.getCategoryById('category-1'))
            .thenReturn(testCategoryWithExamples);

        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Checklist Updates',
          systemMessage: 'System message',
          userMessage:
              '{{correction_examples}}\n\nUpdate the checklist based on this.',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025),
          useReasoning: false,
          requiredInputData: const [],
          aiResponseType: AiResponseType.checklistUpdates,
        );

        final result = await promptBuilder.buildPromptWithData(
          promptConfig: config,
          entity: testTask,
        );

        expect(result, isNotNull);
        expect(result, contains('USER-PROVIDED CORRECTION EXAMPLES'));
        expect(result, contains('manually corrected these checklist item'));
        expect(result, contains('"test flight" → "TestFlight"'));
        expect(result, contains('"mac os" → "macOS"'));
        expect(result, contains('"i phone" → "iPhone"'));
        expect(result, contains('Update the checklist based on this.'));
      });

      test('injects correction examples for audioTranscription response type',
          () async {
        when(() => mockJournalRepository.getLinkedToEntities(
              linkedTo: 'audio-1',
            )).thenAnswer((_) async => [testTask]);
        when(() => mockEntitiesCacheService.getCategoryById('category-1'))
            .thenReturn(testCategoryWithExamples);

        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Audio Transcription',
          systemMessage: 'System message',
          userMessage: '{{correction_examples}}\n\nTranscribe this audio.',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025),
          useReasoning: false,
          requiredInputData: const [],
          aiResponseType: AiResponseType.audioTranscription,
        );

        final result = await promptBuilder.buildPromptWithData(
          promptConfig: config,
          entity: testAudio,
        );

        expect(result, isNotNull);
        expect(result, contains('USER-PROVIDED CORRECTION EXAMPLES'));
        expect(result, contains('"test flight" → "TestFlight"'));
      });

      test('does not inject for non-checklist/audio response types', () async {
        when(() => mockEntitiesCacheService.getCategoryById('category-1'))
            .thenReturn(testCategoryWithExamples);

        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Task Summary',
          systemMessage: 'System message',
          userMessage: '{{correction_examples}}\n\nSummarize this.',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025),
          useReasoning: false,
          requiredInputData: const [],
          aiResponseType: AiResponseType.taskSummary,
        );

        final result = await promptBuilder.buildPromptWithData(
          promptConfig: config,
          entity: testTask,
        );

        // Placeholder should remain unchanged for non-supported types
        expect(result, contains('{{correction_examples}}'));
      });

      test('replaces with empty when category has no examples', () async {
        final taskNoExamples = Task(
          data: testTask.data,
          meta: testTask.meta.copyWith(categoryId: 'category-2'),
        );

        when(() => mockEntitiesCacheService.getCategoryById('category-2'))
            .thenReturn(testCategoryNoExamples);

        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Checklist Updates',
          systemMessage: 'System message',
          userMessage: '{{correction_examples}}\n\nUpdate.',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025),
          useReasoning: false,
          requiredInputData: const [],
          aiResponseType: AiResponseType.checklistUpdates,
        );

        final result = await promptBuilder.buildPromptWithData(
          promptConfig: config,
          entity: taskNoExamples,
        );

        expect(result, equals('\n\nUpdate.'));
        expect(result, isNot(contains('corrections')));
      });

      test('replaces with empty when category not found', () async {
        when(() => mockEntitiesCacheService.getCategoryById('category-1'))
            .thenReturn(null);

        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Checklist Updates',
          systemMessage: 'System message',
          userMessage: '{{correction_examples}}\n\nUpdate.',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025),
          useReasoning: false,
          requiredInputData: const [],
          aiResponseType: AiResponseType.checklistUpdates,
        );

        final result = await promptBuilder.buildPromptWithData(
          promptConfig: config,
          entity: testTask,
        );

        expect(result, equals('\n\nUpdate.'));
      });

      test('replaces with empty when task has no categoryId', () async {
        final taskNoCategory = Task(
          data: testTask.data,
          meta: Metadata(
            id: 'task-no-cat',
            createdAt: DateTime(2025),
            dateFrom: DateTime(2025),
            dateTo: DateTime(2025),
            updatedAt: DateTime(2025),
          ),
        );

        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Checklist Updates',
          systemMessage: 'System message',
          userMessage: '{{correction_examples}}\n\nUpdate.',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025),
          useReasoning: false,
          requiredInputData: const [],
          aiResponseType: AiResponseType.checklistUpdates,
        );

        final result = await promptBuilder.buildPromptWithData(
          promptConfig: config,
          entity: taskNoCategory,
        );

        expect(result, equals('\n\nUpdate.'));
      });

      test('handles exception in category lookup gracefully', () async {
        when(() => mockEntitiesCacheService.getCategoryById('category-1'))
            .thenThrow(Exception('Cache error'));

        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Checklist Updates',
          systemMessage: 'System message',
          userMessage: '{{correction_examples}}\n\nUpdate.',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025),
          useReasoning: false,
          requiredInputData: const [],
          aiResponseType: AiResponseType.checklistUpdates,
        );

        final result = await promptBuilder.buildPromptWithData(
          promptConfig: config,
          entity: testTask,
        );

        // Exception should be caught and placeholder replaced with empty
        expect(result, equals('\n\nUpdate.'));
      });

      test('sorts examples by capturedAt descending (most recent first)',
          () async {
        when(() => mockEntitiesCacheService.getCategoryById('category-1'))
            .thenReturn(testCategoryWithExamples);

        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Checklist Updates',
          systemMessage: 'System message',
          userMessage: '{{correction_examples}}',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025),
          useReasoning: false,
          requiredInputData: const [],
          aiResponseType: AiResponseType.checklistUpdates,
        );

        final result = await promptBuilder.buildPromptWithData(
          promptConfig: config,
          entity: testTask,
        );

        // Examples should appear in order: test flight (Jan 3), mac os (Jan 2), i phone (Jan 1)
        expect(result, isNotNull);
        final testFlightIndex = result!.indexOf('test flight');
        final macOsIndex = result.indexOf('mac os');
        final iPhoneIndex = result.indexOf('i phone');

        expect(testFlightIndex, lessThan(macOsIndex));
        expect(macOsIndex, lessThan(iPhoneIndex));
      });

      test('escapes quotes in before/after text', () async {
        final categoryWithQuotes = CategoryDefinition(
          id: 'category-quotes',
          name: 'Category Quotes',
          createdAt: DateTime(2025),
          updatedAt: DateTime(2025),
          vectorClock: null,
          private: false,
          active: true,
          color: '#FF0000',
          correctionExamples: [
            ChecklistCorrectionExample(
              before: 'said "hello"',
              after: 'said "Hello"',
              capturedAt: DateTime(2025),
            ),
          ],
        );

        final taskWithQuotes = Task(
          data: testTask.data,
          meta: testTask.meta.copyWith(categoryId: 'category-quotes'),
        );

        when(() => mockEntitiesCacheService.getCategoryById('category-quotes'))
            .thenReturn(categoryWithQuotes);

        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Checklist Updates',
          systemMessage: 'System message',
          userMessage: '{{correction_examples}}',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025),
          useReasoning: false,
          requiredInputData: const [],
          aiResponseType: AiResponseType.checklistUpdates,
        );

        final result = await promptBuilder.buildPromptWithData(
          promptConfig: config,
          entity: taskWithQuotes,
        );

        // Quotes should be escaped
        expect(result, contains(r'\"hello\"'));
        expect(result, contains(r'\"Hello\"'));
      });

      test('handles examples with null capturedAt', () async {
        final categoryNullDates = CategoryDefinition(
          id: 'category-null-dates',
          name: 'Category Null Dates',
          createdAt: DateTime(2025),
          updatedAt: DateTime(2025),
          vectorClock: null,
          private: false,
          active: true,
          color: '#FF0000',
          correctionExamples: [
            const ChecklistCorrectionExample(
              before: 'example one',
              after: 'Example One',
            ),
            ChecklistCorrectionExample(
              before: 'example two',
              after: 'Example Two',
              capturedAt: DateTime(2025),
            ),
          ],
        );

        final taskNullDates = Task(
          data: testTask.data,
          meta: testTask.meta.copyWith(categoryId: 'category-null-dates'),
        );

        when(() =>
                mockEntitiesCacheService.getCategoryById('category-null-dates'))
            .thenReturn(categoryNullDates);

        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Checklist Updates',
          systemMessage: 'System message',
          userMessage: '{{correction_examples}}',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025),
          useReasoning: false,
          requiredInputData: const [],
          aiResponseType: AiResponseType.checklistUpdates,
        );

        final result = await promptBuilder.buildPromptWithData(
          promptConfig: config,
          entity: taskNullDates,
        );

        // Should handle null dates without throwing
        expect(result, contains('example one'));
        expect(result, contains('example two'));
      });

      test('handles empty correctionExamples list', () async {
        final categoryEmptyList = CategoryDefinition(
          id: 'category-empty',
          name: 'Category Empty',
          createdAt: DateTime(2025),
          updatedAt: DateTime(2025),
          vectorClock: null,
          private: false,
          active: true,
          color: '#FF0000',
          correctionExamples: [],
        );

        final taskEmpty = Task(
          data: testTask.data,
          meta: testTask.meta.copyWith(categoryId: 'category-empty'),
        );

        when(() => mockEntitiesCacheService.getCategoryById('category-empty'))
            .thenReturn(categoryEmptyList);

        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Checklist Updates',
          systemMessage: 'System message',
          userMessage: '{{correction_examples}}\n\nUpdate.',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025),
          useReasoning: false,
          requiredInputData: const [],
          aiResponseType: AiResponseType.checklistUpdates,
        );

        final result = await promptBuilder.buildPromptWithData(
          promptConfig: config,
          entity: taskEmpty,
        );

        expect(result, equals('\n\nUpdate.'));
      });
    });

    group('EntitiesCacheService not registered', () {
      test('replaces with empty string when cache service not registered',
          () async {
        // Unregister the cache service
        if (getIt.isRegistered<EntitiesCacheService>()) {
          getIt.unregister<EntitiesCacheService>();
        }

        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Checklist Updates',
          systemMessage: 'System message',
          userMessage: '{{correction_examples}}\n\nUpdate.',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025),
          useReasoning: false,
          requiredInputData: const [],
          aiResponseType: AiResponseType.checklistUpdates,
        );

        final result = await promptBuilder.buildPromptWithData(
          promptConfig: config,
          entity: testTask,
        );

        // When cache service is not registered, placeholder is replaced with empty
        expect(result, equals('\n\nUpdate.'));
      });
    });
  });
}
