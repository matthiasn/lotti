import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
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

  final testAudioWithTranscript = JournalAudio(
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
          transcript: 'This is the original transcript from AI.',
          created: DateTime(2025),
          library: 'test',
          model: 'test-model',
          detectedLanguage: 'en',
        ),
      ],
    ),
  );

  final testAudioWithEditedText = JournalAudio(
    meta: Metadata(
      id: 'audio-2',
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
          transcript: 'Original transcript.',
          created: DateTime(2025),
          library: 'test',
          model: 'test-model',
          detectedLanguage: 'en',
        ),
      ],
    ),
    entryText: const EntryText(
      plainText: 'User edited and corrected transcript.',
      markdown: 'User edited and corrected transcript.',
    ),
  );

  final testAudioWithoutTranscript = JournalAudio(
    meta: Metadata(
      id: 'audio-3',
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

  group('PromptBuilderHelper - Audio Transcript Placeholder', () {
    group('buildPromptWithData - {{audioTranscript}}', () {
      test('injects original transcript for audio entry', () async {
        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Generate Prompt',
          systemMessage: 'System message',
          userMessage: 'Audio: {{audioTranscript}}\n\nGenerate a prompt.',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025),
          useReasoning: true,
          requiredInputData: const [InputDataType.audioFiles],
          aiResponseType: AiResponseType.promptGeneration,
        );

        final result = await promptBuilder.buildPromptWithData(
          promptConfig: config,
          entity: testAudioWithTranscript,
        );

        expect(result, isNotNull);
        expect(result, contains('This is the original transcript from AI.'));
        expect(result, contains('Generate a prompt.'));
        expect(result, isNot(contains('{{audioTranscript}}')));
      });

      test('uses edited text over original transcript when available',
          () async {
        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Generate Prompt',
          systemMessage: 'System message',
          userMessage: 'Audio: {{audioTranscript}}',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025),
          useReasoning: true,
          requiredInputData: const [InputDataType.audioFiles],
          aiResponseType: AiResponseType.promptGeneration,
        );

        final result = await promptBuilder.buildPromptWithData(
          promptConfig: config,
          entity: testAudioWithEditedText,
        );

        expect(result, isNotNull);
        // Should use edited text, not original transcript
        expect(result, contains('User edited and corrected transcript.'));
        expect(result, isNot(contains('Original transcript.')));
      });

      test('returns fallback message when no transcript available', () async {
        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Generate Prompt',
          systemMessage: 'System message',
          userMessage: 'Audio: {{audioTranscript}}',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025),
          useReasoning: true,
          requiredInputData: const [InputDataType.audioFiles],
          aiResponseType: AiResponseType.promptGeneration,
        );

        final result = await promptBuilder.buildPromptWithData(
          promptConfig: config,
          entity: testAudioWithoutTranscript,
        );

        expect(result, isNotNull);
        expect(result, contains('[No transcription available]'));
      });

      test('returns error message for non-audio entity', () async {
        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Generate Prompt',
          systemMessage: 'System message',
          userMessage: 'Audio: {{audioTranscript}}',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025),
          useReasoning: true,
          requiredInputData: const [InputDataType.audioFiles],
          aiResponseType: AiResponseType.promptGeneration,
        );

        final result = await promptBuilder.buildPromptWithData(
          promptConfig: config,
          entity: testImage,
        );

        expect(result, isNotNull);
        expect(
          result,
          contains('[Audio entry expected but received JournalImage]'),
        );
      });

      test('returns error message for task entity', () async {
        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Generate Prompt',
          systemMessage: 'System message',
          userMessage: 'Audio: {{audioTranscript}}',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025),
          useReasoning: true,
          requiredInputData: const [InputDataType.audioFiles],
          aiResponseType: AiResponseType.promptGeneration,
        );

        final result = await promptBuilder.buildPromptWithData(
          promptConfig: config,
          entity: testTask,
        );

        expect(result, isNotNull);
        expect(result, contains('[Audio entry expected but received Task]'));
      });

      test('leaves prompt unchanged if audioTranscript placeholder not present',
          () async {
        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Image Analysis',
          systemMessage: 'System message',
          userMessage: 'Analyze this image.',
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
        expect(result, equals('Analyze this image.'));
        // No audioTranscript placeholder to replace
        expect(result, isNot(contains('{{audioTranscript}}')));
      });
    });
  });
}
