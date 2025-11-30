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

  final testCategoryNoDict = CategoryDefinition(
    id: 'category-2',
    name: 'Category Without Dictionary',
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

  final testTaskNoCategory = Task(
    data: TaskData(
      title: 'Task Without Category',
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
      id: 'task-2',
      createdAt: DateTime(2025),
      dateFrom: DateTime(2025),
      dateTo: DateTime(2025),
      updatedAt: DateTime(2025),
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
      test(
          'injects speech dictionary into system message for task with category',
          () async {
        when(() => mockEntitiesCacheService.getCategoryById('category-1'))
            .thenReturn(testCategory);

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

        expect(result, contains('You are a transcription assistant.'));
        expect(
          result,
          contains(
              'The following are correct spellings for domain-specific terms'),
        );
        expect(result, contains('macOS, iPhone, Kirkjubaejarklaustur'));
      });

      test('replaces placeholder with empty string when task has no category',
          () async {
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
          entity: testTaskNoCategory,
        );

        expect(result, equals('You are a transcription assistant.\n\n'));
        expect(result, isNot(contains('domain-specific terms')));
      });

      test(
          'replaces placeholder with empty string when category has no dictionary',
          () async {
        when(() => mockEntitiesCacheService.getCategoryById('category-2'))
            .thenReturn(testCategoryNoDict);

        final taskWithEmptyDictCategory = Task(
          data: testTask.data,
          meta: testTask.meta.copyWith(categoryId: 'category-2'),
        );

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
          entity: taskWithEmptyDictCategory,
        );

        expect(result, equals('You are a transcription assistant.\n\n'));
      });

      test('replaces placeholder with empty string when category not found',
          () async {
        when(() => mockEntitiesCacheService.getCategoryById('category-1'))
            .thenReturn(null);

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

        expect(result, equals('You are a transcription assistant.\n\n'));
      });

      test('leaves system message unchanged when no placeholder present',
          () async {
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
        verifyNever(() => mockEntitiesCacheService.getCategoryById(any()));
      });

      test('handles exception gracefully and replaces with empty string',
          () async {
        when(() => mockEntitiesCacheService.getCategoryById('category-1'))
            .thenThrow(Exception('Cache error'));

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

        expect(result, equals('You are a transcription assistant.\n\n'));
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
          contains(
              'The following are correct spellings for domain-specific terms'),
        );
        expect(result, contains('macOS, iPhone, Kirkjubaejarklaustur'));
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
          contains('macOS, iPhone, Kirkjubaejarklaustur'),
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
          contains('macOS, iPhone, Kirkjubaejarklaustur'),
        );
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
          systemMessage:
              'You are a transcription assistant.\n\n{{speech_dictionary}}',
          userMessage: 'Transcribe.',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025),
          useReasoning: false,
          requiredInputData: const [],
          aiResponseType: AiResponseType.audioTranscription,
        );

        final result = await promptBuilder.buildSystemMessageWithData(
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
          contains('TensorFlow, PyTorch, scikit-learn, NumPy, pandas'),
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
          systemMessage:
              'You are a transcription assistant.\n\n{{speech_dictionary}}',
          userMessage: 'Transcribe.',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025),
          useReasoning: false,
          requiredInputData: const [],
          aiResponseType: AiResponseType.audioTranscription,
        );

        final result = await promptBuilder.buildSystemMessageWithData(
          promptConfig: config,
          entity: taskWithOneTerm,
        );

        expect(result, contains('Anthropic'));
        expect(result, isNot(contains(', '))); // No comma since only one term
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
          systemMessage:
              'You are a transcription assistant.\n\n{{speech_dictionary}}',
          userMessage: 'Transcribe.',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025),
          useReasoning: false,
          requiredInputData: const [],
          aiResponseType: AiResponseType.audioTranscription,
        );

        final result = await promptBuilder.buildSystemMessageWithData(
          promptConfig: config,
          entity: taskWithEmptyList,
        );

        expect(result, equals('You are a transcription assistant.\n\n'));
        expect(result, isNot(contains('domain-specific terms')));
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
          systemMessage:
              'You are a transcription assistant.\n\n{{speech_dictionary}}',
          userMessage: 'Transcribe.',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025),
          useReasoning: false,
          requiredInputData: const [],
          aiResponseType: AiResponseType.audioTranscription,
        );

        final result = await promptBuilder.buildSystemMessageWithData(
          promptConfig: config,
          entity: testTask,
        );

        expect(result, equals('You are a transcription assistant.\n\n'));
      });
    });
  });
}
