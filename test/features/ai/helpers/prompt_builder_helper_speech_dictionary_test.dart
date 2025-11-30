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

  final testCategory = CategoryDefinition(
    id: 'category-1',
    name: 'Test Category',
    createdAt: DateTime(2025),
    updatedAt: DateTime(2025),
    vectorClock: null,
    private: false,
    active: true,
    color: '#FF0000',
    speechDictionary: ['macOS', 'iPhone', 'Kirkjubaejarklaustur'],
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

  group('PromptBuilderHelper - Speech Dictionary', () {
    group('buildSystemMessageWithData', () {
      // Note: {{speech_dictionary}} is intentionally NOT supported in system messages
      // to avoid token waste from duplication. Use it only in user messages.

      test('does not process speech_dictionary placeholder in system message',
          () async {
        // Speech dictionary is only supported in user messages for efficiency
        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Audio Transcription',
          systemMessage:
              'You are a transcription assistant.\n\n{{speech_dictionary}}',
          userMessage: 'Transcribe the audio.',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025),
          useReasoning: false,
          requiredInputData: const [InputDataType.audioFiles],
          aiResponseType: AiResponseType.audioTranscription,
        );

        final result = await promptBuilder.buildSystemMessageWithData(
          promptConfig: config,
          entity: testTask,
        );

        // Placeholder should remain unchanged - not processed in system messages
        expect(
          result,
          equals('You are a transcription assistant.\n\n{{speech_dictionary}}'),
        );
        // Cache service should NOT be called for system message placeholder
        verifyNever(() => mockEntitiesCacheService.getCategoryById(any()));
      });

      test('returns system message unchanged', () async {
        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Simple Prompt',
          systemMessage: 'You are a helpful assistant.',
          userMessage: 'Do something.',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025),
          useReasoning: false,
          requiredInputData: const [],
          aiResponseType: AiResponseType.taskSummary,
        );

        final result = await promptBuilder.buildSystemMessageWithData(
          promptConfig: config,
          entity: testTask,
        );

        expect(result, equals('You are a helpful assistant.'));
      });
    });

    group('buildPromptWithData - speech_dictionary in user message', () {
      test('injects speech dictionary into user message for task', () async {
        when(() => mockEntitiesCacheService.getCategoryById('category-1'))
            .thenReturn(testCategory);

        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Audio Transcription',
          systemMessage: 'System message',
          userMessage: '{{speech_dictionary}}\n\nTranscribe this audio.',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025),
          useReasoning: false,
          requiredInputData: const [],
          aiResponseType: AiResponseType.audioTranscription,
        );

        final result = await promptBuilder.buildPromptWithData(
          promptConfig: config,
          entity: testTask,
        );

        expect(result, isNotNull);
        expect(
          result,
          contains('IMPORTANT - SPEECH DICTIONARY (MUST USE)'),
        );
        expect(result, contains('["macOS", "iPhone", "Kirkjubaejarklaustur"]'));
        expect(result, contains('Transcribe this audio.'));
      });

      test('injects speech dictionary for audio entry linked to task',
          () async {
        when(() => mockJournalRepository.getLinkedToEntities(
              linkedTo: 'audio-1',
            )).thenAnswer((_) async => [testTask]);
        when(() => mockEntitiesCacheService.getCategoryById('category-1'))
            .thenReturn(testCategory);

        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Audio Transcription',
          systemMessage: 'System message',
          userMessage: '{{speech_dictionary}}\n\nTranscribe this audio.',
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
        expect(
          result,
          contains('["macOS", "iPhone", "Kirkjubaejarklaustur"]'),
        );
      });

      test('injects speech dictionary for image entry linked to task',
          () async {
        when(() => mockJournalRepository.getLinkedToEntities(
              linkedTo: 'image-1',
            )).thenAnswer((_) async => [testTask]);
        when(() => mockEntitiesCacheService.getCategoryById('category-1'))
            .thenReturn(testCategory);

        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Image Analysis',
          systemMessage: 'System message',
          userMessage: '{{speech_dictionary}}\n\nAnalyze this image.',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025),
          useReasoning: false,
          requiredInputData: const [],
          aiResponseType: AiResponseType.imageAnalysis,
        );

        final result = await promptBuilder.buildPromptWithData(
          promptConfig: config,
          entity: testImage,
        );

        expect(result, isNotNull);
        expect(
          result,
          contains('["macOS", "iPhone", "Kirkjubaejarklaustur"]'),
        );
      });

      test('replaces with empty when getCategoryById throws exception',
          () async {
        // This tests the catch block in _buildSpeechDictionaryPromptText
        when(() => mockEntitiesCacheService.getCategoryById('category-1'))
            .thenThrow(Exception('Cache service error'));

        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Audio Transcription',
          systemMessage: 'System message',
          userMessage: '{{speech_dictionary}}\n\nTranscribe.',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025),
          useReasoning: false,
          requiredInputData: const [],
          aiResponseType: AiResponseType.audioTranscription,
        );

        final result = await promptBuilder.buildPromptWithData(
          promptConfig: config,
          entity: testTask,
        );

        // Exception should be caught and placeholder replaced with empty string
        expect(result, equals('\n\nTranscribe.'));
        expect(result, isNot(contains('SPEECH DICTIONARY')));
      });

      test('replaces with empty when audio not linked to any task', () async {
        when(() => mockJournalRepository.getLinkedToEntities(
              linkedTo: 'audio-1',
            )).thenAnswer((_) async => []);

        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Audio Transcription',
          systemMessage: 'System message',
          userMessage: '{{speech_dictionary}}\n\nTranscribe this audio.',
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

        expect(result, equals('\n\nTranscribe this audio.'));
      });

      test('replaces with empty when task has no categoryId', () async {
        // Task without a category ID
        final taskNoCategory = Task(
          data: testTask.data,
          meta: Metadata(
            id: 'task-no-cat',
            createdAt: DateTime(2025),
            dateFrom: DateTime(2025),
            dateTo: DateTime(2025),
            updatedAt: DateTime(2025),
            // No categoryId
          ),
        );

        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Audio Transcription',
          systemMessage: 'System message',
          userMessage: '{{speech_dictionary}}\n\nTranscribe.',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025),
          useReasoning: false,
          requiredInputData: const [],
          aiResponseType: AiResponseType.audioTranscription,
        );

        final result = await promptBuilder.buildPromptWithData(
          promptConfig: config,
          entity: taskNoCategory,
        );

        // Task without category should result in empty replacement
        expect(result, equals('\n\nTranscribe.'));
        expect(result, isNot(contains('SPEECH DICTIONARY')));
      });

      test('replaces with empty when category not found in cache', () async {
        // Category lookup returns null
        when(() => mockEntitiesCacheService.getCategoryById('category-1'))
            .thenReturn(null);

        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Audio Transcription',
          systemMessage: 'System message',
          userMessage: '{{speech_dictionary}}\n\nTranscribe.',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025),
          useReasoning: false,
          requiredInputData: const [],
          aiResponseType: AiResponseType.audioTranscription,
        );

        final result = await promptBuilder.buildPromptWithData(
          promptConfig: config,
          entity: testTask,
        );

        // Category not found should result in empty replacement
        expect(result, equals('\n\nTranscribe.'));
        expect(result, isNot(contains('SPEECH DICTIONARY')));
      });

      test('handles multiple dictionary terms correctly', () async {
        final categoryWithManyTerms = CategoryDefinition(
          id: 'category-many',
          name: 'Category with Many Terms',
          createdAt: DateTime(2025),
          updatedAt: DateTime(2025),
          vectorClock: null,
          private: false,
          active: true,
          color: '#FF0000',
          speechDictionary: [
            'TensorFlow',
            'PyTorch',
            'scikit-learn',
            'NumPy',
            'pandas',
          ],
        );

        final taskWithManyTerms = Task(
          data: testTask.data,
          meta: testTask.meta.copyWith(categoryId: 'category-many'),
        );

        when(() => mockEntitiesCacheService.getCategoryById('category-many'))
            .thenReturn(categoryWithManyTerms);

        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Audio Transcription',
          systemMessage: 'You are a transcription assistant.',
          userMessage: '{{speech_dictionary}}',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025),
          useReasoning: false,
          requiredInputData: const [],
          aiResponseType: AiResponseType.audioTranscription,
        );

        final result = await promptBuilder.buildPromptWithData(
          promptConfig: config,
          entity: taskWithManyTerms,
        );

        expect(result, contains('TensorFlow'));
        expect(result, contains('PyTorch'));
        expect(result, contains('scikit-learn'));
        expect(result, contains('NumPy'));
        expect(result, contains('pandas'));
        expect(
          result,
          contains(
              '["TensorFlow", "PyTorch", "scikit-learn", "NumPy", "pandas"]'),
        );
      });

      test('handles single dictionary term correctly', () async {
        final categoryWithOneTerm = CategoryDefinition(
          id: 'category-one',
          name: 'Category with One Term',
          createdAt: DateTime(2025),
          updatedAt: DateTime(2025),
          vectorClock: null,
          private: false,
          active: true,
          color: '#FF0000',
          speechDictionary: ['Anthropic'],
        );

        final taskWithOneTerm = Task(
          data: testTask.data,
          meta: testTask.meta.copyWith(categoryId: 'category-one'),
        );

        when(() => mockEntitiesCacheService.getCategoryById('category-one'))
            .thenReturn(categoryWithOneTerm);

        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Audio Transcription',
          systemMessage: 'You are a transcription assistant.',
          userMessage: '{{speech_dictionary}}',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025),
          useReasoning: false,
          requiredInputData: const [],
          aiResponseType: AiResponseType.audioTranscription,
        );

        final result = await promptBuilder.buildPromptWithData(
          promptConfig: config,
          entity: taskWithOneTerm,
        );

        expect(result, contains('["Anthropic"]')); // Single term in JSON array
      });

      test('handles empty dictionary list', () async {
        final categoryWithEmptyList = CategoryDefinition(
          id: 'category-empty',
          name: 'Category with Empty List',
          createdAt: DateTime(2025),
          updatedAt: DateTime(2025),
          vectorClock: null,
          private: false,
          active: true,
          color: '#FF0000',
          speechDictionary: [],
        );

        final taskWithEmptyList = Task(
          data: testTask.data,
          meta: testTask.meta.copyWith(categoryId: 'category-empty'),
        );

        when(() => mockEntitiesCacheService.getCategoryById('category-empty'))
            .thenReturn(categoryWithEmptyList);

        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Audio Transcription',
          systemMessage: 'You are a transcription assistant.',
          userMessage: '{{speech_dictionary}}\n\nTranscribe.',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025),
          useReasoning: false,
          requiredInputData: const [],
          aiResponseType: AiResponseType.audioTranscription,
        );

        final result = await promptBuilder.buildPromptWithData(
          promptConfig: config,
          entity: taskWithEmptyList,
        );

        // Empty dictionary returns empty string replacement
        expect(result, equals('\n\nTranscribe.'));
        expect(result, isNot(contains('SPEECH DICTIONARY')));
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
          name: 'Audio Transcription',
          systemMessage: 'You are a transcription assistant.',
          userMessage: '{{speech_dictionary}}\n\nTranscribe.',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025),
          useReasoning: false,
          requiredInputData: const [],
          aiResponseType: AiResponseType.audioTranscription,
        );

        final result = await promptBuilder.buildPromptWithData(
          promptConfig: config,
          entity: testTask,
        );

        // When cache service is not registered, placeholder is replaced with empty
        expect(result, equals('\n\nTranscribe.'));
      });
    });

    group('special character handling', () {
      test('escapes quotes in dictionary terms', () async {
        final categoryWithQuotes = CategoryDefinition(
          id: 'category-1',
          name: 'Test Category',
          createdAt: DateTime(2025),
          updatedAt: DateTime(2025),
          vectorClock: null,
          private: false,
          active: true,
          color: '#FF0000',
          speechDictionary: ['Term with "quotes"', 'Normal term'],
        );

        when(() => mockEntitiesCacheService.getCategoryById('category-1'))
            .thenReturn(categoryWithQuotes);

        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Audio Transcription',
          systemMessage: 'You are a transcription assistant.',
          userMessage: '{{speech_dictionary}}',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025),
          useReasoning: false,
          requiredInputData: const [],
          aiResponseType: AiResponseType.audioTranscription,
        );

        final result = await promptBuilder.buildPromptWithData(
          promptConfig: config,
          entity: testTask,
        );

        // Verify quotes are escaped
        expect(result, contains(r'\"quotes\"'));
        expect(result, contains(r'["Term with \"quotes\"", "Normal term"]'));
      });

      test('escapes backslashes in dictionary terms', () async {
        final categoryWithBackslash = CategoryDefinition(
          id: 'category-1',
          name: 'Test Category',
          createdAt: DateTime(2025),
          updatedAt: DateTime(2025),
          vectorClock: null,
          private: false,
          active: true,
          color: '#FF0000',
          speechDictionary: [r'Path\To\File', 'Normal'],
        );

        when(() => mockEntitiesCacheService.getCategoryById('category-1'))
            .thenReturn(categoryWithBackslash);

        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Audio Transcription',
          systemMessage: 'You are a transcription assistant.',
          userMessage: '{{speech_dictionary}}',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025),
          useReasoning: false,
          requiredInputData: const [],
          aiResponseType: AiResponseType.audioTranscription,
        );

        final result = await promptBuilder.buildPromptWithData(
          promptConfig: config,
          entity: testTask,
        );

        // Verify backslashes are escaped
        expect(result, contains(r'\\'));
      });

      test('escapes newlines in dictionary terms', () async {
        final categoryWithNewline = CategoryDefinition(
          id: 'category-1',
          name: 'Test Category',
          createdAt: DateTime(2025),
          updatedAt: DateTime(2025),
          vectorClock: null,
          private: false,
          active: true,
          color: '#FF0000',
          speechDictionary: ['Term with\nnewline', 'Normal'],
        );

        when(() => mockEntitiesCacheService.getCategoryById('category-1'))
            .thenReturn(categoryWithNewline);

        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Audio Transcription',
          systemMessage: 'You are a transcription assistant.',
          userMessage: '{{speech_dictionary}}',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025),
          useReasoning: false,
          requiredInputData: const [],
          aiResponseType: AiResponseType.audioTranscription,
        );

        final result = await promptBuilder.buildPromptWithData(
          promptConfig: config,
          entity: testTask,
        );

        // Verify newlines are escaped
        expect(result, contains(r'\n'));
        // Verify it doesn't contain actual newline in the term part
        expect(result, contains(r'Term with\nnewline'));
      });

      test('includes casing guidance in prompt', () async {
        when(() => mockEntitiesCacheService.getCategoryById('category-1'))
            .thenReturn(testCategory);

        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Audio Transcription',
          systemMessage: 'You are a transcription assistant.',
          userMessage: '{{speech_dictionary}}',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025),
          useReasoning: false,
          requiredInputData: const [],
          aiResponseType: AiResponseType.audioTranscription,
        );

        final result = await promptBuilder.buildPromptWithData(
          promptConfig: config,
          entity: testTask,
        );

        // Verify casing guidance is included
        expect(result, contains('MUST use the exact spelling and casing'));
        expect(result, contains('macOS'));
      });
    });
  });
}
