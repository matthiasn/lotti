import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/ai/helpers/automatic_image_analysis_trigger.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/model/skill_assignment.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/gemini_inference_repository.dart';
import 'package:lotti/features/ai/services/profile_automation_service.dart';
import 'package:lotti/features/ai/services/skill_inference_runner.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/util/image_processing_utils.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../../agents/test_utils.dart';

enum _GeneratedPromptStreamPartKind { text, whitespace, empty }

class _GeneratedPromptStreamPart {
  const _GeneratedPromptStreamPart({
    required this.kind,
    required this.seed,
  });

  final _GeneratedPromptStreamPartKind kind;
  final int seed;

  String get content => switch (kind) {
    _GeneratedPromptStreamPartKind.text => 'chunk-$seed ',
    _GeneratedPromptStreamPartKind.whitespace => seed.isEven ? ' ' : '\n\t',
    _GeneratedPromptStreamPartKind.empty => '',
  };

  @override
  String toString() {
    return '_GeneratedPromptStreamPart(kind: $kind, seed: $seed)';
  }
}

class _GeneratedPromptStreamScenario {
  const _GeneratedPromptStreamScenario({
    required this.parts,
    required this.includeLinkedTask,
  });

  final List<_GeneratedPromptStreamPart> parts;
  final bool includeLinkedTask;

  String get rawResponse => parts.map((part) => part.content).join();

  String get expectedResponse => rawResponse.trim();

  bool get shouldPersist => expectedResponse.isNotEmpty;

  @override
  String toString() {
    return '_GeneratedPromptStreamScenario('
        'includeLinkedTask: $includeLinkedTask, parts: $parts)';
  }
}

enum _GeneratedPromptSourceKind {
  journalEntry,
  journalAudio,
  missingEntity,
  taskEntity,
}

class _GeneratedPromptGenerationScenario {
  const _GeneratedPromptGenerationScenario({
    required this.streamScenario,
    required this.sourceKind,
    required this.useHighEndModel,
  });

  final _GeneratedPromptStreamScenario streamScenario;
  final _GeneratedPromptSourceKind sourceKind;
  final bool useHighEndModel;

  bool get hasTextBearingEntity =>
      sourceKind == _GeneratedPromptSourceKind.journalEntry ||
      sourceKind == _GeneratedPromptSourceKind.journalAudio;

  bool get shouldPersist =>
      hasTextBearingEntity && streamScenario.shouldPersist;

  String get expectedModel =>
      useHighEndModel ? 'models/gemini-pro' : 'models/gemini-flash';

  @override
  String toString() {
    return '_GeneratedPromptGenerationScenario('
        'sourceKind: $sourceKind, useHighEndModel: $useHighEndModel, '
        'streamScenario: $streamScenario)';
  }
}

extension _AnyGeneratedPromptStreamScenario on glados.Any {
  glados.Generator<_GeneratedPromptStreamPartKind> get promptStreamPartKind =>
      glados.AnyUtils(this).choose(_GeneratedPromptStreamPartKind.values);

  glados.Generator<_GeneratedPromptSourceKind> get promptSourceKind =>
      glados.AnyUtils(this).choose(_GeneratedPromptSourceKind.values);

  glados.Generator<_GeneratedPromptStreamPart> get promptStreamPart =>
      glados.CombinableAny(this).combine2(
        promptStreamPartKind,
        glados.IntAnys(this).intInRange(0, 10000),
        (
          _GeneratedPromptStreamPartKind kind,
          int seed,
        ) => _GeneratedPromptStreamPart(
          kind: kind,
          seed: seed,
        ),
      );

  glados.Generator<_GeneratedPromptStreamScenario> get promptStreamScenario =>
      glados.CombinableAny(this).combine2(
        glados.ListAnys(this).listWithLengthInRange(0, 8, promptStreamPart),
        glados.AnyUtils(this).choose([false, true]),
        (
          List<_GeneratedPromptStreamPart> parts,
          bool includeLinkedTask,
        ) => _GeneratedPromptStreamScenario(
          parts: parts,
          includeLinkedTask: includeLinkedTask,
        ),
      );

  glados.Generator<_GeneratedPromptGenerationScenario>
  get promptGenerationScenario => glados.CombinableAny(this).combine3(
    promptStreamScenario,
    promptSourceKind,
    glados.AnyUtils(this).choose([false, true]),
    (
      _GeneratedPromptStreamScenario streamScenario,
      _GeneratedPromptSourceKind sourceKind,
      bool useHighEndModel,
    ) => _GeneratedPromptGenerationScenario(
      streamScenario: streamScenario,
      sourceKind: sourceKind,
      useHighEndModel: useHighEndModel,
    ),
  );
}

class _GeneratedSkillRunnerBench {
  _GeneratedSkillRunnerBench._({
    required this.cloudRepository,
    required this.aiInputRepository,
    required this.journalRepository,
    required this.loggingService,
    required this.promptBuilderHelper,
    required this.taskSummaryResolver,
    required this.container,
    required this.runner,
  });

  factory _GeneratedSkillRunnerBench.create() {
    final cloudRepository = MockCloudInferenceRepository();
    final aiInputRepository = MockAiInputRepository();
    final journalRepository = MockJournalRepository();
    final loggingService = MockDomainLogger();
    final promptBuilderHelper = MockPromptBuilderHelper();
    final taskSummaryResolver = MockTaskSummaryResolver();
    final container = ProviderContainer();

    late final Ref capturedRef;
    final refProvider = Provider<void>((ref) {
      capturedRef = ref;
    });
    container.read(refProvider);

    final runner = SkillInferenceRunner(
      ref: capturedRef,
      cloudRepository: cloudRepository,
      aiInputRepository: aiInputRepository,
      journalRepository: journalRepository,
      loggingService: loggingService,
      promptBuilderHelper: promptBuilderHelper,
      taskSummaryResolver: taskSummaryResolver,
    );

    return _GeneratedSkillRunnerBench._(
      cloudRepository: cloudRepository,
      aiInputRepository: aiInputRepository,
      journalRepository: journalRepository,
      loggingService: loggingService,
      promptBuilderHelper: promptBuilderHelper,
      taskSummaryResolver: taskSummaryResolver,
      container: container,
      runner: runner,
    );
  }

  final MockCloudInferenceRepository cloudRepository;
  final MockAiInputRepository aiInputRepository;
  final MockJournalRepository journalRepository;
  final MockDomainLogger loggingService;
  final MockPromptBuilderHelper promptBuilderHelper;
  final MockTaskSummaryResolver taskSummaryResolver;
  final ProviderContainer container;
  final SkillInferenceRunner runner;

  InferenceStatus promptStatus(String id) {
    return container.read(
      inferenceStatusControllerProvider(
        id: id,
        aiResponseType: AiResponseType.promptGeneration,
      ),
    );
  }

  void stubLoggingException() {
    when(
      () => loggingService.error(
        any<LogDomain>(),
        any<Object>(),
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
        subDomain: any<String>(named: 'subDomain'),
      ),
    ).thenReturn(null);
  }

  void stubLoggingEvent() {
    when(
      () => loggingService.log(
        any<LogDomain>(),
        any<String>(),
        subDomain: any<String>(named: 'subDomain'),
      ),
    ).thenReturn(null);
  }

  void dispose() {
    container.dispose();
  }
}

void main() {
  late MockCloudInferenceRepository mockCloudRepo;
  late MockAiInputRepository mockAiInputRepo;
  late MockJournalRepository mockJournalRepo;
  late MockDomainLogger mockLoggingService;
  late MockPromptBuilderHelper mockPromptBuilderHelper;
  late MockTaskSummaryResolver mockTaskSummaryResolver;
  late MockAiConfigRepository mockAiConfigRepo;
  late SkillInferenceRunner runner;
  late Directory tempDir;
  late ProviderContainer container;

  final testSkill =
      AiConfig.skill(
            id: 'skill-transcribe',
            name: 'Test Transcription',
            skillType: SkillType.transcription,
            requiredInputModalities: const [Modality.audio],
            systemInstructions: 'Transcribe the audio.',
            userInstructions: 'Please transcribe.',
            createdAt: DateTime(2024),
          )
          as AiConfigSkill;

  final testImageSkill =
      AiConfig.skill(
            id: 'skill-vision',
            name: 'Test Image Analysis',
            skillType: SkillType.imageAnalysis,
            requiredInputModalities: const [Modality.image],
            systemInstructions: 'Analyze the image.',
            userInstructions: 'Please describe.',
            createdAt: DateTime(2024),
          )
          as AiConfigSkill;

  final testPromptGenSkill =
      AiConfig.skill(
            id: 'skill-prompt-gen',
            name: 'Generate Coding Prompt',
            skillType: SkillType.promptGeneration,
            requiredInputModalities: const [Modality.audio],
            contextPolicy: ContextPolicy.fullTask,
            systemInstructions: 'You are a prompt engineer.',
            userInstructions: 'Generate a coding prompt.',
            useReasoning: true,
            createdAt: DateTime(2024),
          )
          as AiConfigSkill;

  AutomationResult makePromptGenerationResult({
    String? thinkingHighEndModelId,
    AiConfigInferenceProvider? thinkingHighEndProvider,
  }) {
    return AutomationResult(
      handled: true,
      resolvedProfile: ResolvedProfile(
        thinkingModelId: 'models/gemini-flash',
        thinkingProvider: testInferenceProvider(id: 'p-flash'),
        thinkingHighEndModelId: thinkingHighEndModelId,
        thinkingHighEndProvider: thinkingHighEndProvider,
      ),
      skill: testPromptGenSkill,
    );
  }

  AutomationResult makeTranscriptionResult() {
    return AutomationResult(
      handled: true,
      resolvedProfile: ResolvedProfile(
        thinkingModelId: 'models/gemini-3-flash-preview',
        thinkingProvider: testInferenceProvider(),
        transcriptionModelId: 'whisper-1',
        transcriptionProvider: testInferenceProvider(id: 'p-audio'),
      ),
      skill: testSkill,
      skillAssignment: const SkillAssignment(
        skillId: 'skill-transcribe',
        automate: true,
      ),
    );
  }

  AutomationResult makeImageAnalysisResult() {
    return AutomationResult(
      handled: true,
      resolvedProfile: ResolvedProfile(
        thinkingModelId: 'models/gemini-3-flash-preview',
        thinkingProvider: testInferenceProvider(),
        imageRecognitionModelId: 'vision-model',
        imageRecognitionProvider: testInferenceProvider(id: 'p-vision'),
      ),
      skill: testImageSkill,
      skillAssignment: const SkillAssignment(
        skillId: 'skill-vision',
        automate: true,
      ),
    );
  }

  JournalEntity makeTaskEntity(String id) {
    return JournalEntity.task(
      meta: Metadata(
        id: id,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        dateFrom: DateTime(2024),
        dateTo: DateTime(2024),
      ),
      data: TaskData(
        title: 'Test task',
        status: TaskStatus.open(
          id: 'status-1',
          createdAt: DateTime(2024),
          utcOffset: 0,
        ),
        statusHistory: const [],
        dateFrom: DateTime(2024),
        dateTo: DateTime(2024),
      ),
    );
  }

  JournalAudio makeAudioEntity({
    String id = 'audio-1',
    String audioDirectory = '/audio/',
    String audioFile = 'test.aac',
    String? plainText,
    String? markdown,
    String? categoryId,
  }) {
    return JournalEntity.journalAudio(
          meta: Metadata(
            id: id,
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
            dateFrom: DateTime(2024),
            dateTo: DateTime(2024),
            categoryId: categoryId,
          ),
          data: AudioData(
            dateFrom: DateTime(2024),
            dateTo: DateTime(2024),
            duration: const Duration(minutes: 1),
            audioDirectory: audioDirectory,
            audioFile: audioFile,
          ),
          entryText: (plainText == null && markdown == null)
              ? null
              : EntryText(
                  plainText: plainText ?? '',
                  markdown: markdown,
                ),
        )
        as JournalAudio;
  }

  JournalEntry makeTextEntry({
    String id = 'text-1',
    String? markdown,
    String? plainText,
    String? categoryId,
  }) {
    return JournalEntity.journalEntry(
          meta: Metadata(
            id: id,
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
            dateFrom: DateTime(2024),
            dateTo: DateTime(2024),
            categoryId: categoryId,
          ),
          entryText: (markdown == null && plainText == null)
              ? null
              : EntryText(
                  plainText: plainText ?? '',
                  markdown: markdown,
                ),
        )
        as JournalEntry;
  }

  JournalImage makeImageEntity({
    String id = 'img-1',
    String imageDirectory = '/images/',
    String imageFile = 'test.jpg',
  }) {
    return JournalEntity.journalImage(
          meta: Metadata(
            id: id,
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
            dateFrom: DateTime(2024),
            dateTo: DateTime(2024),
          ),
          data: ImageData(
            imageId: id,
            imageFile: imageFile,
            imageDirectory: imageDirectory,
            capturedAt: DateTime(2024),
          ),
        )
        as JournalImage;
  }

  /// Creates a stream response chunk with the given content.
  CreateChatCompletionStreamResponse makeStreamChunk(String content) {
    return CreateChatCompletionStreamResponse(
      id: 'resp-1',
      choices: [
        ChatCompletionStreamResponseChoice(
          delta: ChatCompletionStreamResponseDelta(content: content),
          index: 0,
        ),
      ],
      object: 'chat.completion.chunk',
      created: DateTime(2024).millisecondsSinceEpoch ~/ 1000,
    );
  }

  void stubLoggingException() {
    when(
      () => mockLoggingService.error(
        any<LogDomain>(),
        any<Object>(),
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
        subDomain: any<String>(named: 'subDomain'),
      ),
    ).thenReturn(null);
  }

  void stubLoggingEvent() {
    when(
      () => mockLoggingService.log(
        any<LogDomain>(),
        any<String>(),
        subDomain: any<String>(named: 'subDomain'),
      ),
    ).thenReturn(null);
  }

  setUpAll(registerAllFallbackValues);

  setUp(() async {
    mockCloudRepo = MockCloudInferenceRepository();
    mockAiInputRepo = MockAiInputRepository();
    mockJournalRepo = MockJournalRepository();
    mockLoggingService = MockDomainLogger();
    mockPromptBuilderHelper = MockPromptBuilderHelper();
    mockTaskSummaryResolver = MockTaskSummaryResolver();
    mockAiConfigRepo = MockAiConfigRepository();

    container = ProviderContainer(
      overrides: [
        aiConfigRepositoryProvider.overrideWithValue(mockAiConfigRepo),
      ],
    );

    // Capture a live Ref from a simple provider so we can pass it to the
    // SkillInferenceRunner constructor (needed for status updates).
    late final Ref capturedRef;
    final refProvider = Provider<void>((ref) {
      capturedRef = ref;
    });
    container.read(refProvider);

    runner = SkillInferenceRunner(
      ref: capturedRef,
      cloudRepository: mockCloudRepo,
      aiInputRepository: mockAiInputRepo,
      journalRepository: mockJournalRepo,
      loggingService: mockLoggingService,
      promptBuilderHelper: mockPromptBuilderHelper,
      taskSummaryResolver: mockTaskSummaryResolver,
    );

    // Create temp directory for file I/O tests.
    tempDir = await Directory.systemTemp.createTemp('skill_runner_test_');
    await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<Directory>(tempDir);
      },
    );
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestGetIt();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  /// Writes the stub audio file at the path [makeAudioEntity] points to.
  Future<void> createStubAudioFile() async {
    final audioDir = Directory('${tempDir.path}/audio');
    await audioDir.create(recursive: true);
    await File('${audioDir.path}/test.aac').writeAsBytes([0x01]);
  }

  /// Writes the stub image file at the path the image fixtures point to.
  Future<void> createStubImageFile() async {
    final imageDir = Directory('${tempDir.path}/images');
    await imageDir.create(recursive: true);
    await File('${imageDir.path}/test.jpg').writeAsBytes([0x01]);
  }

  group('SkillInferenceRunner', () {
    group('runTranscription', () {
      test(
        'throws StateError when skill is null in AutomationResult',
        () async {
          final result = AutomationResult(
            handled: true,
            resolvedProfile: ResolvedProfile(
              thinkingModelId: 'models/gemini-3-flash-preview',
              thinkingProvider: testInferenceProvider(),
              transcriptionModelId: 'whisper-1',
              transcriptionProvider: testInferenceProvider(id: 'p-audio'),
            ),
          );

          expect(
            () => runner.runTranscription(
              audioEntryId: 'entry-1',
              automationResult: result,
            ),
            throwsStateError,
          );
        },
      );

      test(
        'throws StateError when profile is null in AutomationResult',
        () async {
          final result = AutomationResult(
            handled: true,
            skill: testSkill,
          );

          expect(
            () => runner.runTranscription(
              audioEntryId: 'entry-1',
              automationResult: result,
            ),
            throwsStateError,
          );
        },
      );

      test('returns early when transcription provider is null', () async {
        final result = AutomationResult(
          handled: true,
          resolvedProfile: ResolvedProfile(
            thinkingModelId: 'models/gemini-3-flash-preview',
            thinkingProvider: testInferenceProvider(),
          ),
          skill: testSkill,
          skillAssignment: const SkillAssignment(
            skillId: 'skill-transcribe',
            automate: true,
          ),
        );

        await runner.runTranscription(
          audioEntryId: 'entry-1',
          automationResult: result,
        );

        verifyZeroInteractions(mockCloudRepo);
        verifyZeroInteractions(mockAiInputRepo);
      });

      test('returns early when entity is null', () async {
        when(
          () => mockAiInputRepo.getEntity('entry-1'),
        ).thenAnswer((_) async => null);

        await runner.runTranscription(
          audioEntryId: 'entry-1',
          automationResult: makeTranscriptionResult(),
        );

        verifyZeroInteractions(mockCloudRepo);
      });

      test('returns early when entity is not JournalAudio', () async {
        when(
          () => mockAiInputRepo.getEntity('entry-1'),
        ).thenAnswer((_) async => makeTaskEntity('entry-1'));

        await runner.runTranscription(
          audioEntryId: 'entry-1',
          automationResult: makeTranscriptionResult(),
        );

        verifyZeroInteractions(mockCloudRepo);
      });

      test('happy path: transcribes audio and saves result', () async {
        final audioEntity = makeAudioEntity();

        // Create the audio file on disk.
        final audioDir = Directory('${tempDir.path}/audio');
        await audioDir.create(recursive: true);
        final audioFile = File('${audioDir.path}/test.aac');
        await audioFile.writeAsBytes([0x48, 0x65, 0x6c, 0x6c, 0x6f]);

        // 1. First fetch returns the audio entity.
        when(
          () => mockAiInputRepo.getEntity('audio-1'),
        ).thenAnswer((_) async => audioEntity);

        // 2. Speech dictionary terms.
        when(
          () => mockPromptBuilderHelper.getSpeechDictionaryTerms(audioEntity),
        ).thenAnswer((_) async => ['Flutter', 'Dart']);

        // 3. No linked task context.
        when(
          () => mockTaskSummaryResolver.resolve(any()),
        ).thenAnswer((_) async => null);

        // 4. Cloud inference returns streaming response.
        when(
          () => mockCloudRepo.generateWithAudio(
            any(),
            model: any(named: 'model'),
            audioBase64: any(named: 'audioBase64'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            provider: any(named: 'provider'),
            systemMessage: any(named: 'systemMessage'),
            speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
          ),
        ).thenAnswer(
          (_) => Stream.fromIterable([
            makeStreamChunk('Hello '),
            makeStreamChunk('World'),
          ]),
        );

        // 5. Re-fetch for current state returns same entity.
        // EntityStateHelper calls getEntity again.
        when(
          () => mockAiInputRepo.getEntity('audio-1'),
        ).thenAnswer((_) async => audioEntity);

        // 6. Save journal entity.
        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);

        // 7. Logging.
        stubLoggingEvent();

        await runner.runTranscription(
          audioEntryId: 'audio-1',
          automationResult: makeTranscriptionResult(),
        );

        // Verify cloud inference was called.
        verify(
          () => mockCloudRepo.generateWithAudio(
            any(),
            model: 'whisper-1',
            audioBase64: any(named: 'audioBase64'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            provider: any(named: 'provider'),
            systemMessage: any(named: 'systemMessage'),
            speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
          ),
        ).called(1);

        // Verify journal entity was updated.
        final captured = verify(
          () => mockJournalRepo.updateJournalEntity(captureAny()),
        ).captured;
        expect(captured, hasLength(1));

        final updatedEntity = captured.first as JournalAudio;
        expect(updatedEntity.entryText?.plainText, 'Hello World');
        expect(updatedEntity.data.transcripts, isNotNull);
        expect(updatedEntity.data.transcripts!.last.transcript, 'Hello World');
        expect(updatedEntity.data.transcripts!.last.model, 'whisper-1');
      });

      test('returns early on empty transcription response', () async {
        final audioEntity = makeAudioEntity();

        // Create the audio file on disk.
        await createStubAudioFile();

        when(
          () => mockAiInputRepo.getEntity('audio-1'),
        ).thenAnswer((_) async => audioEntity);
        when(
          () => mockPromptBuilderHelper.getSpeechDictionaryTerms(audioEntity),
        ).thenAnswer((_) async => []);
        when(
          () => mockTaskSummaryResolver.resolve(any()),
        ).thenAnswer((_) async => null);

        // Return empty stream (no chunks).
        when(
          () => mockCloudRepo.generateWithAudio(
            any(),
            model: any(named: 'model'),
            audioBase64: any(named: 'audioBase64'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            provider: any(named: 'provider'),
            systemMessage: any(named: 'systemMessage'),
            speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
          ),
        ).thenAnswer((_) => Stream.fromIterable([]));

        await runner.runTranscription(
          audioEntryId: 'audio-1',
          automationResult: makeTranscriptionResult(),
        );

        // Should not save — empty response.
        verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
      });

      test('builds task context when linkedTaskId is provided', () async {
        final audioEntity = makeAudioEntity();

        await createStubAudioFile();

        when(
          () => mockAiInputRepo.getEntity('audio-1'),
        ).thenAnswer((_) async => audioEntity);
        when(
          () => mockPromptBuilderHelper.getSpeechDictionaryTerms(audioEntity),
        ).thenAnswer((_) async => []);
        when(
          () => mockAiInputRepo.buildTaskDetailsJson(id: 'task-1'),
        ).thenAnswer((_) async => '{"id": "task-1"}');
        when(
          () => mockTaskSummaryResolver.resolve('task-1'),
        ).thenAnswer((_) async => 'Task summary text');
        when(
          () => mockCloudRepo.generateWithAudio(
            any(),
            model: any(named: 'model'),
            audioBase64: any(named: 'audioBase64'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            provider: any(named: 'provider'),
            systemMessage: any(named: 'systemMessage'),
            speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
          ),
        ).thenAnswer(
          (_) => Stream.fromIterable([makeStreamChunk('Transcribed text')]),
        );
        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);
        stubLoggingEvent();

        await runner.runTranscription(
          audioEntryId: 'audio-1',
          automationResult: makeTranscriptionResult(),
          linkedTaskId: 'task-1',
        );

        verify(
          () => mockAiInputRepo.buildTaskDetailsJson(id: 'task-1'),
        ).called(1);
        verify(() => mockTaskSummaryResolver.resolve('task-1')).called(1);
      });

      test(
        'overrideModelId routes the run to the override model + its '
        'parent provider instead of the profile slot — the popup-menu '
        'picker uses this seam to send one voice note to a non-default '
        'model without mutating the profile',
        () async {
          final audioEntity = makeAudioEntity();
          await createStubAudioFile();

          final overrideProvider =
              AiConfig.inferenceProvider(
                    id: 'p-override',
                    baseUrl: 'https://override.example.com',
                    name: 'Override Provider',
                    inferenceProviderType: InferenceProviderType.openAi,
                    apiKey: 'override-key',
                    createdAt: DateTime(2024),
                  )
                  as AiConfigInferenceProvider;
          final overrideModel = AiConfig.model(
            id: 'override-model-id',
            name: 'Mistral Cloud',
            providerModelId: 'mistral/voxtral-mini',
            inferenceProviderId: 'p-override',
            createdAt: DateTime(2024),
            inputModalities: const [Modality.audio, Modality.text],
            outputModalities: const [Modality.text],
            isReasoningModel: false,
          );

          when(
            () => mockAiConfigRepo.getConfigById('override-model-id'),
          ).thenAnswer((_) async => overrideModel);
          when(
            () => mockAiConfigRepo.getConfigById('p-override'),
          ).thenAnswer((_) async => overrideProvider);
          when(
            () => mockAiInputRepo.getEntity('audio-1'),
          ).thenAnswer((_) async => audioEntity);
          when(
            () => mockPromptBuilderHelper.getSpeechDictionaryTerms(audioEntity),
          ).thenAnswer((_) async => const <String>[]);
          when(
            () => mockTaskSummaryResolver.resolve(any()),
          ).thenAnswer((_) async => null);
          when(
            () => mockCloudRepo.generateWithAudio(
              any(),
              model: any(named: 'model'),
              audioBase64: any(named: 'audioBase64'),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              provider: any(named: 'provider'),
              systemMessage: any(named: 'systemMessage'),
              speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
            ),
          ).thenAnswer(
            (_) =>
                Stream.fromIterable([makeStreamChunk('Override transcript')]),
          );
          when(
            () => mockJournalRepo.updateJournalEntity(any()),
          ).thenAnswer((_) async => true);
          stubLoggingEvent();

          await runner.runTranscription(
            audioEntryId: 'audio-1',
            automationResult: makeTranscriptionResult(),
            overrideModelId: 'override-model-id',
          );

          // Inference targeted the override model + provider, NOT the
          // profile slot's `whisper-1` / `p-audio`.
          verify(
            () => mockCloudRepo.generateWithAudio(
              any(),
              model: 'mistral/voxtral-mini',
              audioBase64: any(named: 'audioBase64'),
              baseUrl: 'https://override.example.com',
              apiKey: any(named: 'apiKey'),
              provider: overrideProvider,
              systemMessage: any(named: 'systemMessage'),
              speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
            ),
          ).called(1);

          // Saved transcript records the OVERRIDE model id, not the
          // profile's — important so audit logs reflect what actually
          // ran for this entry.
          final captured = verify(
            () => mockJournalRepo.updateJournalEntity(captureAny()),
          ).captured;
          final updated = captured.first as JournalAudio;
          expect(
            updated.data.transcripts!.last.model,
            'mistral/voxtral-mini',
          );
        },
      );

      test(
        'a stale override modelId (not resolvable to an AiConfigModel) '
        'falls back to the profile slot — stranding the user with a '
        '"transcription does nothing" outcome is worse than ignoring '
        'a deleted-between-picker-and-runner override',
        () async {
          final audioEntity = makeAudioEntity();
          await createStubAudioFile();

          when(
            () => mockAiConfigRepo.getConfigById('stale-id'),
          ).thenAnswer((_) async => null);
          when(
            () => mockAiInputRepo.getEntity('audio-1'),
          ).thenAnswer((_) async => audioEntity);
          when(
            () => mockPromptBuilderHelper.getSpeechDictionaryTerms(audioEntity),
          ).thenAnswer((_) async => const <String>[]);
          when(
            () => mockTaskSummaryResolver.resolve(any()),
          ).thenAnswer((_) async => null);
          when(
            () => mockCloudRepo.generateWithAudio(
              any(),
              model: any(named: 'model'),
              audioBase64: any(named: 'audioBase64'),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              provider: any(named: 'provider'),
              systemMessage: any(named: 'systemMessage'),
              speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
            ),
          ).thenAnswer(
            (_) => Stream.fromIterable([
              makeStreamChunk('Fell back to profile'),
            ]),
          );
          when(
            () => mockJournalRepo.updateJournalEntity(any()),
          ).thenAnswer((_) async => true);
          stubLoggingEvent();

          await runner.runTranscription(
            audioEntryId: 'audio-1',
            automationResult: makeTranscriptionResult(),
            overrideModelId: 'stale-id',
          );

          // Inference used the profile slot model (`whisper-1`) — the
          // stale override was ignored.
          verify(
            () => mockCloudRepo.generateWithAudio(
              any(),
              model: 'whisper-1',
              audioBase64: any(named: 'audioBase64'),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              provider: any(named: 'provider'),
              systemMessage: any(named: 'systemMessage'),
              speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
            ),
          ).called(1);
        },
      );

      test('logs exception on failure', () async {
        when(
          () => mockAiInputRepo.getEntity('entry-1'),
        ).thenThrow(Exception('DB error'));
        stubLoggingException();

        await runner.runTranscription(
          audioEntryId: 'entry-1',
          automationResult: makeTranscriptionResult(),
        );

        verify(
          () => mockLoggingService.error(
            LogDomain.ai,
            any<Object>(),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
            subDomain: 'runTranscription',
          ),
        ).called(1);
      });
    });

    group('runImageAnalysis', () {
      test(
        'throws StateError when skill is null in AutomationResult',
        () async {
          final result = AutomationResult(
            handled: true,
            resolvedProfile: ResolvedProfile(
              thinkingModelId: 'models/gemini-3-flash-preview',
              thinkingProvider: testInferenceProvider(),
              imageRecognitionModelId: 'vision-model',
              imageRecognitionProvider: testInferenceProvider(id: 'p-vision'),
            ),
          );

          expect(
            () => runner.runImageAnalysis(
              imageEntryId: 'img-1',
              automationResult: result,
            ),
            throwsStateError,
          );
        },
      );

      test(
        'throws StateError when profile is null in AutomationResult',
        () async {
          final result = AutomationResult(
            handled: true,
            skill: testImageSkill,
          );

          expect(
            () => runner.runImageAnalysis(
              imageEntryId: 'img-1',
              automationResult: result,
            ),
            throwsStateError,
          );
        },
      );

      test(
        'returns early when image recognition provider is null',
        () async {
          final result = AutomationResult(
            handled: true,
            resolvedProfile: ResolvedProfile(
              thinkingModelId: 'models/gemini-3-flash-preview',
              thinkingProvider: testInferenceProvider(),
            ),
            skill: testImageSkill,
            skillAssignment: const SkillAssignment(
              skillId: 'skill-vision',
              automate: true,
            ),
          );

          await runner.runImageAnalysis(
            imageEntryId: 'img-1',
            automationResult: result,
          );

          verifyZeroInteractions(mockCloudRepo);
          verifyZeroInteractions(mockAiInputRepo);
        },
      );

      test('returns early when entity is null', () async {
        when(
          () => mockAiInputRepo.getEntity('img-1'),
        ).thenAnswer((_) async => null);

        await runner.runImageAnalysis(
          imageEntryId: 'img-1',
          automationResult: makeImageAnalysisResult(),
        );

        verifyZeroInteractions(mockCloudRepo);
      });

      test('returns early when entity is not JournalImage', () async {
        when(
          () => mockAiInputRepo.getEntity('img-1'),
        ).thenAnswer((_) async => makeTaskEntity('img-1'));

        await runner.runImageAnalysis(
          imageEntryId: 'img-1',
          automationResult: makeImageAnalysisResult(),
        );

        verifyZeroInteractions(mockCloudRepo);
      });

      test('happy path: analyzes image and saves result', () async {
        final imageEntity = makeImageEntity();

        // Create the image file on disk.
        final imageDir = Directory('${tempDir.path}/images');
        await imageDir.create(recursive: true);
        final imageFile = File('${imageDir.path}/test.jpg');
        await imageFile.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0]);

        when(
          () => mockAiInputRepo.getEntity('img-1'),
        ).thenAnswer((_) async => imageEntity);
        when(
          () => mockTaskSummaryResolver.resolve(any()),
        ).thenAnswer((_) async => null);

        // Cloud inference returns streaming response.
        when(
          () => mockCloudRepo.generateWithImages(
            any(),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            images: any(named: 'images'),
            provider: any(named: 'provider'),
            systemMessage: any(named: 'systemMessage'),
          ),
        ).thenAnswer(
          (_) => Stream.fromIterable([
            makeStreamChunk('A photo of '),
            makeStreamChunk('a sunset'),
          ]),
        );

        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);
        stubLoggingEvent();

        await runner.runImageAnalysis(
          imageEntryId: 'img-1',
          automationResult: makeImageAnalysisResult(),
        );

        // Verify cloud inference was called with image data.
        verify(
          () => mockCloudRepo.generateWithImages(
            any(),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            model: 'vision-model',
            temperature: null,
            images: [
              base64Encode([0xFF, 0xD8, 0xFF, 0xE0]),
            ],
            provider: any(named: 'provider'),
            systemMessage: any(named: 'systemMessage'),
          ),
        ).called(1);

        // Verify journal entity was updated.
        final captured = verify(
          () => mockJournalRepo.updateJournalEntity(captureAny()),
        ).captured;
        expect(captured, hasLength(1));

        final updatedEntity = captured.first as JournalImage;
        expect(
          updatedEntity.entryText?.plainText,
          'A photo of a sunset',
        );
      });

      test('appends analysis to existing entryText', () async {
        final imageEntity =
            JournalEntity.journalImage(
                  meta: Metadata(
                    id: 'img-1',
                    createdAt: DateTime(2024),
                    updatedAt: DateTime(2024),
                    dateFrom: DateTime(2024),
                    dateTo: DateTime(2024),
                  ),
                  data: ImageData(
                    imageId: 'img-1',
                    imageFile: 'test.jpg',
                    imageDirectory: '/images/',
                    capturedAt: DateTime(2024),
                  ),
                  entryText: const EntryText(
                    plainText: 'Previous text',
                    markdown: 'Previous text',
                  ),
                )
                as JournalImage;

        await createStubImageFile();

        when(
          () => mockAiInputRepo.getEntity('img-1'),
        ).thenAnswer((_) async => imageEntity);
        when(
          () => mockTaskSummaryResolver.resolve(any()),
        ).thenAnswer((_) async => null);
        when(
          () => mockCloudRepo.generateWithImages(
            any(),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            images: any(named: 'images'),
            provider: any(named: 'provider'),
            systemMessage: any(named: 'systemMessage'),
          ),
        ).thenAnswer(
          (_) => Stream.fromIterable([makeStreamChunk('New analysis')]),
        );
        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);
        stubLoggingEvent();

        await runner.runImageAnalysis(
          imageEntryId: 'img-1',
          automationResult: makeImageAnalysisResult(),
        );

        final captured = verify(
          () => mockJournalRepo.updateJournalEntity(captureAny()),
        ).captured;
        final updated = captured.first as JournalImage;
        expect(
          updated.entryText?.markdown,
          'Previous text\n\nNew analysis',
        );
      });

      test('returns early on empty image analysis response', () async {
        final imageEntity = makeImageEntity();

        await createStubImageFile();

        when(
          () => mockAiInputRepo.getEntity('img-1'),
        ).thenAnswer((_) async => imageEntity);
        when(
          () => mockTaskSummaryResolver.resolve(any()),
        ).thenAnswer((_) async => null);
        when(
          () => mockCloudRepo.generateWithImages(
            any(),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            images: any(named: 'images'),
            provider: any(named: 'provider'),
            systemMessage: any(named: 'systemMessage'),
          ),
        ).thenAnswer((_) => Stream.fromIterable([]));

        await runner.runImageAnalysis(
          imageEntryId: 'img-1',
          automationResult: makeImageAnalysisResult(),
        );

        verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
      });

      test('returns empty list for missing image file', () async {
        final imageEntity = makeImageEntity(
          imageFile: 'nonexistent.jpg',
        );

        when(
          () => mockAiInputRepo.getEntity('img-1'),
        ).thenAnswer((_) async => imageEntity);
        when(
          () => mockTaskSummaryResolver.resolve(any()),
        ).thenAnswer((_) async => null);

        await runner.runImageAnalysis(
          imageEntryId: 'img-1',
          automationResult: makeImageAnalysisResult(),
        );

        // Should not call inference — no image data.
        verifyZeroInteractions(mockCloudRepo);
      });

      test('returns empty when image file does not exist', () async {
        final imageEntity = makeImageEntity(
          imageDirectory: '/nonexistent/',
          imageFile: 'missing.jpg',
        );

        when(
          () => mockAiInputRepo.getEntity('img-1'),
        ).thenAnswer((_) async => imageEntity);
        when(
          () => mockTaskSummaryResolver.resolve(any()),
        ).thenAnswer((_) async => null);

        await runner.runImageAnalysis(
          imageEntryId: 'img-1',
          automationResult: makeImageAnalysisResult(),
        );

        // Should not call inference — file does not exist.
        verifyZeroInteractions(mockCloudRepo);
      });

      test('rejects path traversal in image path', () async {
        final imageEntity = makeImageEntity(
          imageDirectory: '/images/../../',
          imageFile: 'etc/passwd',
        );

        when(
          () => mockAiInputRepo.getEntity('img-1'),
        ).thenAnswer((_) async => imageEntity);
        when(
          () => mockTaskSummaryResolver.resolve(any()),
        ).thenAnswer((_) async => null);

        await runner.runImageAnalysis(
          imageEntryId: 'img-1',
          automationResult: makeImageAnalysisResult(),
        );

        // Should not call inference — path escapes documents directory.
        verifyZeroInteractions(mockCloudRepo);
      });

      test('builds task context when linkedTaskId is provided', () async {
        final imageEntity = makeImageEntity();

        await createStubImageFile();

        when(
          () => mockAiInputRepo.getEntity('img-1'),
        ).thenAnswer((_) async => imageEntity);
        when(
          () => mockAiInputRepo.buildTaskDetailsJson(id: 'task-1'),
        ).thenAnswer((_) async => '{"id": "task-1"}');
        when(
          () => mockAiInputRepo.buildLinkedTasksJson('task-1'),
        ).thenAnswer((_) async => '{"linked": []}');
        when(
          () => mockTaskSummaryResolver.resolve('task-1'),
        ).thenAnswer((_) async => 'Task summary');
        when(
          () => mockCloudRepo.generateWithImages(
            any(),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            images: any(named: 'images'),
            provider: any(named: 'provider'),
            systemMessage: any(named: 'systemMessage'),
          ),
        ).thenAnswer(
          (_) => Stream.fromIterable([makeStreamChunk('Analysis')]),
        );
        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);
        stubLoggingEvent();

        await runner.runImageAnalysis(
          imageEntryId: 'img-1',
          automationResult: makeImageAnalysisResult(),
          linkedTaskId: 'task-1',
        );

        verify(
          () => mockAiInputRepo.buildTaskDetailsJson(id: 'task-1'),
        ).called(1);
        verify(
          () => mockAiInputRepo.buildLinkedTasksJson('task-1'),
        ).called(1);
        verify(() => mockTaskSummaryResolver.resolve('task-1')).called(1);
      });

      test('logs exception on failure', () async {
        when(
          () => mockAiInputRepo.getEntity('img-1'),
        ).thenThrow(Exception('DB error'));
        stubLoggingException();

        await runner.runImageAnalysis(
          imageEntryId: 'img-1',
          automationResult: makeImageAnalysisResult(),
        );

        verify(
          () => mockLoggingService.error(
            LogDomain.ai,
            any<Object>(),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
            subDomain: 'runImageAnalysis',
          ),
        ).called(1);
      });

      test(
        'overrideModelId routes the run to the override model + its '
        'parent provider instead of the profile slot — the popup-menu '
        'picker uses this seam to send one photo to a non-default '
        'model without mutating the profile',
        () async {
          final imageEntity = makeImageEntity();
          await createStubImageFile();

          final overrideProvider =
              AiConfig.inferenceProvider(
                    id: 'p-override',
                    baseUrl: 'https://override.example.com',
                    name: 'Override Provider',
                    inferenceProviderType: InferenceProviderType.openAi,
                    apiKey: 'override-key',
                    createdAt: DateTime(2024),
                  )
                  as AiConfigInferenceProvider;
          final overrideModel = AiConfig.model(
            id: 'override-model-id',
            name: 'Claude Sonnet Vision',
            providerModelId: 'claude-sonnet',
            inferenceProviderId: 'p-override',
            createdAt: DateTime(2024),
            inputModalities: const [Modality.image, Modality.text],
            outputModalities: const [Modality.text],
            isReasoningModel: false,
          );

          when(
            () => mockAiConfigRepo.getConfigById('override-model-id'),
          ).thenAnswer((_) async => overrideModel);
          when(
            () => mockAiConfigRepo.getConfigById('p-override'),
          ).thenAnswer((_) async => overrideProvider);
          when(
            () => mockAiInputRepo.getEntity('img-1'),
          ).thenAnswer((_) async => imageEntity);
          when(
            () => mockTaskSummaryResolver.resolve(any()),
          ).thenAnswer((_) async => null);
          when(
            () => mockCloudRepo.generateWithImages(
              any(),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              model: any(named: 'model'),
              temperature: any(named: 'temperature'),
              images: any(named: 'images'),
              provider: any(named: 'provider'),
              systemMessage: any(named: 'systemMessage'),
            ),
          ).thenAnswer(
            (_) => Stream.fromIterable([
              makeStreamChunk('Override analysis'),
            ]),
          );
          when(
            () => mockJournalRepo.updateJournalEntity(any()),
          ).thenAnswer((_) async => true);
          stubLoggingEvent();

          await runner.runImageAnalysis(
            imageEntryId: 'img-1',
            automationResult: makeImageAnalysisResult(),
            overrideModelId: 'override-model-id',
          );

          // Inference targeted the override model + provider, NOT the
          // profile slot's `vision-model` / `p-vision`.
          verify(
            () => mockCloudRepo.generateWithImages(
              any(),
              baseUrl: 'https://override.example.com',
              apiKey: any(named: 'apiKey'),
              model: 'claude-sonnet',
              temperature: null,
              images: any(named: 'images'),
              provider: overrideProvider,
              systemMessage: any(named: 'systemMessage'),
            ),
          ).called(1);
        },
      );

      test(
        'a stale override modelId (not resolvable to an AiConfigModel) '
        'falls back to the profile slot — stranding the user with an '
        '"image analysis does nothing" outcome is worse than ignoring '
        'a deleted-between-picker-and-runner override',
        () async {
          final imageEntity = makeImageEntity();
          await createStubImageFile();

          when(
            () => mockAiConfigRepo.getConfigById('stale-id'),
          ).thenAnswer((_) async => null);
          when(
            () => mockAiInputRepo.getEntity('img-1'),
          ).thenAnswer((_) async => imageEntity);
          when(
            () => mockTaskSummaryResolver.resolve(any()),
          ).thenAnswer((_) async => null);
          when(
            () => mockCloudRepo.generateWithImages(
              any(),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              model: any(named: 'model'),
              temperature: any(named: 'temperature'),
              images: any(named: 'images'),
              provider: any(named: 'provider'),
              systemMessage: any(named: 'systemMessage'),
            ),
          ).thenAnswer(
            (_) => Stream.fromIterable([
              makeStreamChunk('Fell back to profile'),
            ]),
          );
          when(
            () => mockJournalRepo.updateJournalEntity(any()),
          ).thenAnswer((_) async => true);
          stubLoggingEvent();

          await runner.runImageAnalysis(
            imageEntryId: 'img-1',
            automationResult: makeImageAnalysisResult(),
            overrideModelId: 'stale-id',
          );

          // Inference used the profile slot model (`vision-model`)
          // routed via the profile slot's provider `p-vision` — the
          // stale override was ignored. Pinning the provider too
          // catches a hypothetical regression where the runner
          // chooses the right model but the wrong provider.
          verify(
            () => mockCloudRepo.generateWithImages(
              any(),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              model: 'vision-model',
              temperature: null,
              images: any(named: 'images'),
              provider: testInferenceProvider(id: 'p-vision'),
              systemMessage: any(named: 'systemMessage'),
            ),
          ).called(1);
        },
      );

      test(
        'an override modelId whose parent provider does not resolve to '
        'an AiConfigInferenceProvider falls back to the profile slot — '
        'a model row pointing at a stale/deleted provider should not '
        'strand the run, same defensive principle as the missing-model '
        'fallback',
        () async {
          final imageEntity = makeImageEntity();
          await createStubImageFile();

          final orphanModel = AiConfig.model(
            id: 'override-model-id',
            name: 'Orphaned Vision',
            providerModelId: 'orphan-model',
            inferenceProviderId: 'p-missing',
            createdAt: DateTime(2024),
            inputModalities: const [Modality.image, Modality.text],
            outputModalities: const [Modality.text],
            isReasoningModel: false,
          );

          when(
            () => mockAiConfigRepo.getConfigById('override-model-id'),
          ).thenAnswer((_) async => orphanModel);
          when(
            () => mockAiConfigRepo.getConfigById('p-missing'),
          ).thenAnswer((_) async => null);
          when(
            () => mockAiInputRepo.getEntity('img-1'),
          ).thenAnswer((_) async => imageEntity);
          when(
            () => mockTaskSummaryResolver.resolve(any()),
          ).thenAnswer((_) async => null);
          when(
            () => mockCloudRepo.generateWithImages(
              any(),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              model: any(named: 'model'),
              temperature: any(named: 'temperature'),
              images: any(named: 'images'),
              provider: any(named: 'provider'),
              systemMessage: any(named: 'systemMessage'),
            ),
          ).thenAnswer(
            (_) => Stream.fromIterable([
              makeStreamChunk('Fell back to profile'),
            ]),
          );
          when(
            () => mockJournalRepo.updateJournalEntity(any()),
          ).thenAnswer((_) async => true);
          stubLoggingEvent();

          await runner.runImageAnalysis(
            imageEntryId: 'img-1',
            automationResult: makeImageAnalysisResult(),
            overrideModelId: 'override-model-id',
          );

          // Same provider-pinning as the stale-override case above:
          // verifying provider `p-vision` (the profile slot) catches
          // wrong-provider routing that a model-only check would miss.
          verify(
            () => mockCloudRepo.generateWithImages(
              any(),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              model: 'vision-model',
              temperature: null,
              images: any(named: 'images'),
              provider: testInferenceProvider(id: 'p-vision'),
              systemMessage: any(named: 'systemMessage'),
            ),
          ).called(1);
        },
      );
    });

    group('runPromptGeneration', () {
      test('throws StateError when skill is null', () async {
        final result = AutomationResult(
          handled: true,
          resolvedProfile: ResolvedProfile(
            thinkingModelId: 'models/gemini-flash',
            thinkingProvider: testInferenceProvider(),
          ),
        );

        expect(
          () => runner.runPromptGeneration(
            entryId: 'entry-1',
            automationResult: result,
          ),
          throwsStateError,
        );
      });

      test('throws StateError when profile is null', () async {
        final result = AutomationResult(
          handled: true,
          skill: testPromptGenSkill,
        );

        expect(
          () => runner.runPromptGeneration(
            entryId: 'entry-1',
            automationResult: result,
          ),
          throwsStateError,
        );
      });

      test(
        'rejects non-text-bearing entities (Task) and never calls inference',
        () async {
          when(
            () => mockAiInputRepo.getEntity('entry-1'),
          ).thenAnswer((_) async => makeTaskEntity('entry-1'));
          stubLoggingException();

          await runner.runPromptGeneration(
            entryId: 'entry-1',
            automationResult: makePromptGenerationResult(),
          );

          verifyZeroInteractions(mockCloudRepo);
          verify(
            () => mockLoggingService.error(
              LogDomain.ai,
              any<Object>(),
              stackTrace: any<StackTrace?>(named: 'stackTrace'),
              subDomain: 'runPromptGeneration',
            ),
          ).called(1);
        },
      );

      test('logs error when getEntity returns null', () async {
        when(
          () => mockAiInputRepo.getEntity('missing-1'),
        ).thenAnswer((_) async => null);
        stubLoggingException();

        await runner.runPromptGeneration(
          entryId: 'missing-1',
          automationResult: makePromptGenerationResult(),
        );

        verifyZeroInteractions(mockCloudRepo);
        verify(
          () => mockLoggingService.error(
            LogDomain.ai,
            any<Object>(),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
            subDomain: 'runPromptGeneration',
          ),
        ).called(1);
      });

      test(
        'succeeds on a JournalEntry source and threads markdown into prompt',
        () async {
          final textEntry = makeTextEntry(
            id: 'text-prompt',
            markdown: '# Heading\n\nFix the **login** flow.',
            plainText: 'Heading\n\nFix the login flow.',
            categoryId: 'cat-text',
          );

          when(
            () => mockAiInputRepo.getEntity('text-prompt'),
          ).thenAnswer((_) async => textEntry);
          when(
            () => mockAiInputRepo.buildTaskDetailsJson(id: 'task-text'),
          ).thenAnswer((_) async => '{"id": "task-text"}');
          when(
            () => mockAiInputRepo.buildLinkedTasksJson('task-text'),
          ).thenAnswer((_) async => '{"linked": []}');
          when(
            () => mockCloudRepo.generate(
              any(),
              model: any(named: 'model'),
              temperature: any(named: 'temperature'),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              provider: any(named: 'provider'),
              systemMessage: any(named: 'systemMessage'),
            ),
          ).thenAnswer(
            (_) => Stream.fromIterable([
              makeStreamChunk('## Summary\nLogin\n\n## Prompt\nDo the work'),
            ]),
          );
          when(
            () => mockAiInputRepo.createAiResponseEntry(
              data: any(named: 'data'),
              start: any(named: 'start'),
              linkedId: any(named: 'linkedId'),
              categoryId: any(named: 'categoryId'),
            ),
          ).thenAnswer((_) async => null);
          stubLoggingEvent();

          await runner.runPromptGeneration(
            entryId: 'text-prompt',
            automationResult: makePromptGenerationResult(),
            linkedTaskId: 'task-text',
          );

          // Builder should have used markdown (preferred over plainText) and
          // injected it under the **Entry Notes:** header.
          final captured = verify(
            () => mockCloudRepo.generate(
              captureAny(),
              model: any(named: 'model'),
              temperature: any(named: 'temperature'),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              provider: any(named: 'provider'),
              systemMessage: any(named: 'systemMessage'),
            ),
          ).captured;
          final userMessage = captured.first as String;
          expect(userMessage, contains('**Entry Notes:**'));
          expect(userMessage, contains('Fix the **login** flow.'));

          final responseCaptured = verify(
            () => mockAiInputRepo.createAiResponseEntry(
              data: captureAny(named: 'data'),
              start: any(named: 'start'),
              linkedId: captureAny(named: 'linkedId'),
              categoryId: captureAny(named: 'categoryId'),
            ),
          ).captured;
          expect(responseCaptured[1], 'text-prompt');
          expect(responseCaptured[2], 'cat-text');
        },
      );

      test(
        'falls back to plainText when JournalEntry has no markdown',
        () async {
          final textEntry = makeTextEntry(
            id: 'text-plain',
            plainText: 'Plain only body',
          );

          when(
            () => mockAiInputRepo.getEntity('text-plain'),
          ).thenAnswer((_) async => textEntry);
          when(
            () => mockCloudRepo.generate(
              any(),
              model: any(named: 'model'),
              temperature: any(named: 'temperature'),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              provider: any(named: 'provider'),
              systemMessage: any(named: 'systemMessage'),
            ),
          ).thenAnswer(
            (_) => Stream.fromIterable([makeStreamChunk('out')]),
          );
          when(
            () => mockAiInputRepo.createAiResponseEntry(
              data: any(named: 'data'),
              start: any(named: 'start'),
              linkedId: any(named: 'linkedId'),
              categoryId: any(named: 'categoryId'),
            ),
          ).thenAnswer((_) async => null);
          stubLoggingEvent();

          await runner.runPromptGeneration(
            entryId: 'text-plain',
            automationResult: makePromptGenerationResult(),
          );

          final captured = verify(
            () => mockCloudRepo.generate(
              captureAny(),
              model: any(named: 'model'),
              temperature: any(named: 'temperature'),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              provider: any(named: 'provider'),
              systemMessage: any(named: 'systemMessage'),
            ),
          ).captured;
          final userMessage = captured.first as String;
          expect(userMessage, contains('Plain only body'));
        },
      );

      test(
        'injects [Empty note] placeholder when JournalEntry has no text',
        () async {
          final textEntry = makeTextEntry(id: 'text-empty');

          when(
            () => mockAiInputRepo.getEntity('text-empty'),
          ).thenAnswer((_) async => textEntry);
          when(
            () => mockCloudRepo.generate(
              any(),
              model: any(named: 'model'),
              temperature: any(named: 'temperature'),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              provider: any(named: 'provider'),
              systemMessage: any(named: 'systemMessage'),
            ),
          ).thenAnswer(
            (_) => Stream.fromIterable([makeStreamChunk('out')]),
          );
          when(
            () => mockAiInputRepo.createAiResponseEntry(
              data: any(named: 'data'),
              start: any(named: 'start'),
              linkedId: any(named: 'linkedId'),
              categoryId: any(named: 'categoryId'),
            ),
          ).thenAnswer((_) async => null);
          stubLoggingEvent();

          await runner.runPromptGeneration(
            entryId: 'text-empty',
            automationResult: makePromptGenerationResult(),
          );

          final captured = verify(
            () => mockCloudRepo.generate(
              captureAny(),
              model: any(named: 'model'),
              temperature: any(named: 'temperature'),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              provider: any(named: 'provider'),
              systemMessage: any(named: 'systemMessage'),
            ),
          ).captured;
          final userMessage = captured.first as String;
          expect(userMessage, contains('[Empty note]'));
        },
      );

      test('uses high-end thinking model when configured', () async {
        final audioEntity =
            JournalEntity.journalAudio(
                  meta: Metadata(
                    id: 'audio-prompt',
                    createdAt: DateTime(2024),
                    updatedAt: DateTime(2024),
                    dateFrom: DateTime(2024),
                    dateTo: DateTime(2024),
                  ),
                  data: AudioData(
                    dateFrom: DateTime(2024),
                    dateTo: DateTime(2024),
                    duration: const Duration(minutes: 1),
                    audioDirectory: '/audio/',
                    audioFile: 'test.aac',
                  ),
                  entryText: const EntryText(
                    plainText: 'Fix the login bug',
                    markdown: 'Fix the login bug',
                  ),
                )
                as JournalAudio;

        final highEndProvider = testInferenceProvider(id: 'p-pro');

        when(
          () => mockAiInputRepo.getEntity('audio-prompt'),
        ).thenAnswer((_) async => audioEntity);
        when(
          () => mockAiInputRepo.buildTaskDetailsJson(id: 'task-1'),
        ).thenAnswer((_) async => '{"id": "task-1", "title": "Login"}');
        when(
          () => mockAiInputRepo.buildLinkedTasksJson('task-1'),
        ).thenAnswer((_) async => '{"linked": []}');
        when(
          () => mockCloudRepo.generate(
            any(),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            provider: any(named: 'provider'),
            systemMessage: any(named: 'systemMessage'),
          ),
        ).thenAnswer(
          (_) => Stream.fromIterable([
            makeStreamChunk('## Summary\nFix login\n\n'),
            makeStreamChunk('## Prompt\nPlease fix the login bug'),
          ]),
        );
        when(
          () => mockAiInputRepo.createAiResponseEntry(
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => null);
        stubLoggingEvent();

        await runner.runPromptGeneration(
          entryId: 'audio-prompt',
          automationResult: makePromptGenerationResult(
            thinkingHighEndModelId: 'models/gemini-pro',
            thinkingHighEndProvider: highEndProvider,
          ),
          linkedTaskId: 'task-1',
        );

        // Verify it used the high-end model, not the regular thinking model.
        verify(
          () => mockCloudRepo.generate(
            any(),
            model: 'models/gemini-pro',
            temperature: any(named: 'temperature'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            provider: any(named: 'provider'),
            systemMessage: any(named: 'systemMessage'),
          ),
        ).called(1);
      });

      test('falls back to thinking model when high-end not set', () async {
        final audioEntity =
            JournalEntity.journalAudio(
                  meta: Metadata(
                    id: 'audio-fallback',
                    createdAt: DateTime(2024),
                    updatedAt: DateTime(2024),
                    dateFrom: DateTime(2024),
                    dateTo: DateTime(2024),
                  ),
                  data: AudioData(
                    dateFrom: DateTime(2024),
                    dateTo: DateTime(2024),
                    duration: const Duration(minutes: 1),
                    audioDirectory: '/audio/',
                    audioFile: 'test.aac',
                  ),
                  entryText: const EntryText(
                    plainText: 'Some transcript',
                    markdown: 'Some transcript',
                  ),
                )
                as JournalAudio;

        when(
          () => mockAiInputRepo.getEntity('audio-fallback'),
        ).thenAnswer((_) async => audioEntity);
        when(
          () => mockCloudRepo.generate(
            any(),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            provider: any(named: 'provider'),
            systemMessage: any(named: 'systemMessage'),
          ),
        ).thenAnswer(
          (_) => Stream.fromIterable([
            makeStreamChunk('## Summary\nDo something\n\n## Prompt\nDo it'),
          ]),
        );
        when(
          () => mockAiInputRepo.createAiResponseEntry(
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => null);
        stubLoggingEvent();

        // No high-end model configured — should fall back to regular thinking.
        await runner.runPromptGeneration(
          entryId: 'audio-fallback',
          automationResult: makePromptGenerationResult(),
        );

        verify(
          () => mockCloudRepo.generate(
            any(),
            model: 'models/gemini-flash',
            temperature: any(named: 'temperature'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            provider: any(named: 'provider'),
            systemMessage: any(named: 'systemMessage'),
          ),
        ).called(1);
      });

      test('happy path: generates prompt and saves AiResponseEntry', () async {
        final audioEntity =
            JournalEntity.journalAudio(
                  meta: Metadata(
                    id: 'audio-happy',
                    createdAt: DateTime(2024),
                    updatedAt: DateTime(2024),
                    dateFrom: DateTime(2024),
                    dateTo: DateTime(2024),
                    categoryId: 'cat-1',
                  ),
                  data: AudioData(
                    dateFrom: DateTime(2024),
                    dateTo: DateTime(2024),
                    duration: const Duration(minutes: 1),
                    audioDirectory: '/audio/',
                    audioFile: 'test.aac',
                  ),
                  entryText: const EntryText(
                    plainText: 'Fix the login bug on mobile',
                    markdown: 'Fix the login bug on mobile',
                  ),
                )
                as JournalAudio;

        when(
          () => mockAiInputRepo.getEntity('audio-happy'),
        ).thenAnswer((_) async => audioEntity);
        when(
          () => mockAiInputRepo.buildTaskDetailsJson(id: 'task-happy'),
        ).thenAnswer((_) async => '{"id": "task-happy"}');
        when(
          () => mockAiInputRepo.buildLinkedTasksJson('task-happy'),
        ).thenAnswer((_) async => '{"linked_from": [], "linked_to": []}');
        when(
          () => mockCloudRepo.generate(
            any(),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            provider: any(named: 'provider'),
            systemMessage: any(named: 'systemMessage'),
          ),
        ).thenAnswer(
          (_) => Stream.fromIterable([
            makeStreamChunk('## Summary\nFix login bug\n\n'),
            makeStreamChunk('## Prompt\nFix the login bug on mobile'),
          ]),
        );
        when(
          () => mockAiInputRepo.createAiResponseEntry(
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => null);
        stubLoggingEvent();

        await runner.runPromptGeneration(
          entryId: 'audio-happy',
          automationResult: makePromptGenerationResult(),
          linkedTaskId: 'task-happy',
        );

        // Verify AiResponseEntry was created with correct data.
        final captured = verify(
          () => mockAiInputRepo.createAiResponseEntry(
            data: captureAny(named: 'data'),
            start: any(named: 'start'),
            linkedId: captureAny(named: 'linkedId'),
            categoryId: captureAny(named: 'categoryId'),
          ),
        ).captured;

        final data = captured[0] as AiResponseData;
        expect(data.type, AiResponseType.promptGeneration);
        expect(data.response, contains('Fix login bug'));
        expect(data.model, 'models/gemini-flash');

        final linkedId = captured[1] as String;
        expect(linkedId, 'audio-happy');

        final categoryId = captured[2] as String?;
        expect(categoryId, 'cat-1');
      });

      test(
        'extracts transcript from latest transcript when no entryText',
        () async {
          final audioEntity =
              JournalEntity.journalAudio(
                    meta: Metadata(
                      id: 'audio-transcript',
                      createdAt: DateTime(2024),
                      updatedAt: DateTime(2024),
                      dateFrom: DateTime(2024),
                      dateTo: DateTime(2024),
                    ),
                    data: AudioData(
                      dateFrom: DateTime(2024),
                      dateTo: DateTime(2024),
                      duration: const Duration(minutes: 1),
                      audioDirectory: '/audio/',
                      audioFile: 'test.aac',
                      transcripts: [
                        AudioTranscript(
                          created: DateTime(2024),
                          library: 'whisper',
                          model: 'whisper-1',
                          detectedLanguage: 'en',
                          transcript: 'Old transcript',
                          processingTime: const Duration(seconds: 5),
                        ),
                        AudioTranscript(
                          created: DateTime(2024, 6),
                          library: 'whisper',
                          model: 'whisper-2',
                          detectedLanguage: 'en',
                          transcript: 'Latest transcript',
                          processingTime: const Duration(seconds: 3),
                        ),
                      ],
                    ),
                  )
                  as JournalAudio;

          when(
            () => mockAiInputRepo.getEntity('audio-transcript'),
          ).thenAnswer((_) async => audioEntity);
          when(
            () => mockCloudRepo.generate(
              any(),
              model: any(named: 'model'),
              temperature: any(named: 'temperature'),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              provider: any(named: 'provider'),
              systemMessage: any(named: 'systemMessage'),
            ),
          ).thenAnswer(
            (_) => Stream.fromIterable([makeStreamChunk('Generated prompt')]),
          );
          when(
            () => mockAiInputRepo.createAiResponseEntry(
              data: any(named: 'data'),
              start: any(named: 'start'),
              linkedId: any(named: 'linkedId'),
              categoryId: any(named: 'categoryId'),
            ),
          ).thenAnswer((_) async => null);
          stubLoggingEvent();

          await runner.runPromptGeneration(
            entryId: 'audio-transcript',
            automationResult: makePromptGenerationResult(),
          );

          // Verify the user message contains the latest transcript.
          final generateCall = verify(
            () => mockCloudRepo.generate(
              captureAny(),
              model: any(named: 'model'),
              temperature: any(named: 'temperature'),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              provider: any(named: 'provider'),
              systemMessage: any(named: 'systemMessage'),
            ),
          ).captured;
          final userMessage = generateCall.first as String;
          expect(userMessage, contains('Latest transcript'));
        },
      );

      test('returns early on empty response', () async {
        final audioEntity =
            JournalEntity.journalAudio(
                  meta: Metadata(
                    id: 'audio-empty',
                    createdAt: DateTime(2024),
                    updatedAt: DateTime(2024),
                    dateFrom: DateTime(2024),
                    dateTo: DateTime(2024),
                  ),
                  data: AudioData(
                    dateFrom: DateTime(2024),
                    dateTo: DateTime(2024),
                    duration: const Duration(minutes: 1),
                    audioDirectory: '/audio/',
                    audioFile: 'test.aac',
                  ),
                  entryText: const EntryText(
                    plainText: 'Some text',
                    markdown: 'Some text',
                  ),
                )
                as JournalAudio;

        when(
          () => mockAiInputRepo.getEntity('audio-empty'),
        ).thenAnswer((_) async => audioEntity);
        when(
          () => mockCloudRepo.generate(
            any(),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            provider: any(named: 'provider'),
            systemMessage: any(named: 'systemMessage'),
          ),
        ).thenAnswer((_) => Stream.fromIterable([]));
        stubLoggingException();

        await runner.runPromptGeneration(
          entryId: 'audio-empty',
          automationResult: makePromptGenerationResult(),
        );

        verifyNever(
          () => mockAiInputRepo.createAiResponseEntry(
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        );
      });

      glados.Glados(
        glados.any.promptStreamScenario,
        glados.ExploreConfig(numRuns: 120),
      ).test(
        'matches generated prompt stream persistence and status semantics',
        (scenario) async {
          final localCloudRepo = MockCloudInferenceRepository();
          final localAiInputRepo = MockAiInputRepository();
          final localJournalRepo = MockJournalRepository();
          final localLoggingService = MockDomainLogger();
          final localPromptBuilderHelper = MockPromptBuilderHelper();
          final localTaskSummaryResolver = MockTaskSummaryResolver();
          final localContainer = ProviderContainer();

          void stubLocalLoggingException() {
            when(
              () => localLoggingService.error(
                any<LogDomain>(),
                any<Object>(),
                stackTrace: any<StackTrace?>(named: 'stackTrace'),
                subDomain: any<String>(named: 'subDomain'),
              ),
            ).thenReturn(null);
          }

          void stubLocalLoggingEvent() {
            when(
              () => localLoggingService.log(
                any<LogDomain>(),
                any<String>(),
                subDomain: any<String>(named: 'subDomain'),
              ),
            ).thenReturn(null);
          }

          try {
            late final Ref localRef;
            final refProvider = Provider<void>((ref) {
              localRef = ref;
            });
            localContainer.read(refProvider);

            final localRunner = SkillInferenceRunner(
              ref: localRef,
              cloudRepository: localCloudRepo,
              aiInputRepository: localAiInputRepo,
              journalRepository: localJournalRepo,
              loggingService: localLoggingService,
              promptBuilderHelper: localPromptBuilderHelper,
              taskSummaryResolver: localTaskSummaryResolver,
            );

            final entry = makeTextEntry(
              id: 'generated-prompt-entry',
              markdown: 'Generate a useful implementation prompt.',
              plainText: 'Generate a useful implementation prompt.',
              categoryId: 'cat-generated',
            );
            final linkedTaskId = scenario.includeLinkedTask
                ? 'generated-linked-task'
                : null;

            when(
              () => localAiInputRepo.getEntity('generated-prompt-entry'),
            ).thenAnswer((_) async => entry);
            if (linkedTaskId != null) {
              when(
                () => localAiInputRepo.buildTaskDetailsJson(id: linkedTaskId),
              ).thenAnswer((_) async => '{"id": "$linkedTaskId"}');
              when(
                () => localAiInputRepo.buildLinkedTasksJson(linkedTaskId),
              ).thenAnswer((_) async => '{"linked": []}');
            }
            when(
              () => localCloudRepo.generate(
                any(),
                model: any(named: 'model'),
                temperature: any(named: 'temperature'),
                baseUrl: any(named: 'baseUrl'),
                apiKey: any(named: 'apiKey'),
                provider: any(named: 'provider'),
                systemMessage: any(named: 'systemMessage'),
              ),
            ).thenAnswer(
              (_) => Stream.fromIterable(
                scenario.parts.map((part) => makeStreamChunk(part.content)),
              ),
            );

            if (scenario.shouldPersist) {
              when(
                () => localAiInputRepo.createAiResponseEntry(
                  data: any(named: 'data'),
                  start: any(named: 'start'),
                  linkedId: any(named: 'linkedId'),
                  categoryId: any(named: 'categoryId'),
                ),
              ).thenAnswer((_) async => null);
              stubLocalLoggingEvent();
            } else {
              stubLocalLoggingException();
            }

            await localRunner.runPromptGeneration(
              entryId: 'generated-prompt-entry',
              automationResult: makePromptGenerationResult(),
              linkedTaskId: linkedTaskId,
            );

            final status = localContainer.read(
              inferenceStatusControllerProvider(
                id: 'generated-prompt-entry',
                aiResponseType: AiResponseType.promptGeneration,
              ),
            );
            expect(
              status,
              scenario.shouldPersist
                  ? InferenceStatus.idle
                  : InferenceStatus.error,
              reason: '$scenario',
            );
            if (linkedTaskId != null) {
              expect(
                localContainer.read(
                  inferenceStatusControllerProvider(
                    id: linkedTaskId,
                    aiResponseType: AiResponseType.promptGeneration,
                  ),
                ),
                status,
                reason: '$scenario',
              );
            }

            if (!scenario.shouldPersist) {
              verifyNever(
                () => localAiInputRepo.createAiResponseEntry(
                  data: any(named: 'data'),
                  start: any(named: 'start'),
                  linkedId: any(named: 'linkedId'),
                  categoryId: any(named: 'categoryId'),
                ),
              );
              verify(
                () => localLoggingService.error(
                  LogDomain.ai,
                  any<Object>(),
                  stackTrace: any<StackTrace?>(named: 'stackTrace'),
                  subDomain: 'runPromptGeneration',
                ),
              ).called(1);
              return;
            }

            final captured = verify(
              () => localAiInputRepo.createAiResponseEntry(
                data: captureAny(named: 'data'),
                start: any(named: 'start'),
                linkedId: captureAny(named: 'linkedId'),
                categoryId: captureAny(named: 'categoryId'),
              ),
            ).captured;
            final data = captured[0] as AiResponseData;
            expect(
              data.response,
              scenario.expectedResponse,
              reason: '$scenario',
            );
            expect(data.type, AiResponseType.promptGeneration);
            expect(data.skillId, testPromptGenSkill.id);
            expect(captured[1], 'generated-prompt-entry');
            expect(captured[2], 'cat-generated');
          } finally {
            localContainer.dispose();
          }
        },
        tags: 'glados',
      );

      glados.Glados(
        glados.any.promptGenerationScenario,
        glados.ExploreConfig(numRuns: 160),
      ).test(
        'matches generated prompt source, model, and status semantics',
        (scenario) async {
          final bench = _GeneratedSkillRunnerBench.create();

          try {
            const entryId = 'generated-source-entry';
            final linkedTaskId = scenario.streamScenario.includeLinkedTask
                ? 'generated-source-linked-task'
                : null;
            final entity = switch (scenario.sourceKind) {
              _GeneratedPromptSourceKind.journalEntry => makeTextEntry(
                id: entryId,
                markdown: 'Generated **markdown** source',
                plainText: 'Generated plain source',
                categoryId: 'cat-generated',
              ),
              _GeneratedPromptSourceKind.journalAudio => makeAudioEntity(
                id: entryId,
                plainText: 'Generated audio transcript',
                categoryId: 'cat-generated',
              ),
              _GeneratedPromptSourceKind.missingEntity => null,
              _GeneratedPromptSourceKind.taskEntity => makeTaskEntity(entryId),
            };

            when(
              () => bench.aiInputRepository.getEntity(entryId),
            ).thenAnswer((_) async => entity);
            if (scenario.hasTextBearingEntity && linkedTaskId != null) {
              when(
                () => bench.aiInputRepository.buildTaskDetailsJson(
                  id: linkedTaskId,
                ),
              ).thenAnswer((_) async => '{"id": "$linkedTaskId"}');
              when(
                () => bench.aiInputRepository.buildLinkedTasksJson(
                  linkedTaskId,
                ),
              ).thenAnswer((_) async => '{"linked": []}');
            }
            if (scenario.hasTextBearingEntity) {
              when(
                () => bench.cloudRepository.generate(
                  any(),
                  model: any(named: 'model'),
                  temperature: any(named: 'temperature'),
                  baseUrl: any(named: 'baseUrl'),
                  apiKey: any(named: 'apiKey'),
                  provider: any(named: 'provider'),
                  systemMessage: any(named: 'systemMessage'),
                ),
              ).thenAnswer(
                (_) => Stream.fromIterable(
                  scenario.streamScenario.parts.map(
                    (part) => makeStreamChunk(part.content),
                  ),
                ),
              );
            }

            if (scenario.shouldPersist) {
              when(
                () => bench.aiInputRepository.createAiResponseEntry(
                  data: any(named: 'data'),
                  start: any(named: 'start'),
                  linkedId: any(named: 'linkedId'),
                  categoryId: any(named: 'categoryId'),
                ),
              ).thenAnswer((_) async => null);
              bench.stubLoggingEvent();
            } else {
              bench.stubLoggingException();
            }

            final automationResult = scenario.useHighEndModel
                ? makePromptGenerationResult(
                    thinkingHighEndModelId: scenario.expectedModel,
                    thinkingHighEndProvider: testInferenceProvider(id: 'p-pro'),
                  )
                : makePromptGenerationResult();

            await bench.runner.runPromptGeneration(
              entryId: entryId,
              automationResult: automationResult,
              linkedTaskId: linkedTaskId,
            );

            final expectedStatus = scenario.shouldPersist
                ? InferenceStatus.idle
                : InferenceStatus.error;
            expect(
              bench.promptStatus(entryId),
              expectedStatus,
              reason: '$scenario',
            );
            if (linkedTaskId != null) {
              expect(
                bench.promptStatus(linkedTaskId),
                expectedStatus,
                reason: '$scenario',
              );
            }

            if (!scenario.hasTextBearingEntity) {
              verifyNever(
                () => bench.cloudRepository.generate(
                  any(),
                  model: any(named: 'model'),
                  temperature: any(named: 'temperature'),
                  baseUrl: any(named: 'baseUrl'),
                  apiKey: any(named: 'apiKey'),
                  provider: any(named: 'provider'),
                  systemMessage: any(named: 'systemMessage'),
                ),
              );
            } else {
              final generatedCall = verify(
                () => bench.cloudRepository.generate(
                  captureAny(),
                  model: scenario.expectedModel,
                  temperature: any(named: 'temperature'),
                  baseUrl: any(named: 'baseUrl'),
                  apiKey: any(named: 'apiKey'),
                  provider: any(named: 'provider'),
                  systemMessage: any(named: 'systemMessage'),
                ),
              ).captured;
              final prompt = generatedCall.single as String;
              final expectedSourceText =
                  scenario.sourceKind == _GeneratedPromptSourceKind.journalAudio
                  ? 'Generated audio transcript'
                  : 'Generated **markdown** source';
              expect(prompt, contains(expectedSourceText), reason: '$scenario');
            }

            if (!scenario.shouldPersist) {
              verifyNever(
                () => bench.aiInputRepository.createAiResponseEntry(
                  data: any(named: 'data'),
                  start: any(named: 'start'),
                  linkedId: any(named: 'linkedId'),
                  categoryId: any(named: 'categoryId'),
                ),
              );
              verify(
                () => bench.loggingService.error(
                  LogDomain.ai,
                  any<Object>(),
                  stackTrace: any<StackTrace?>(named: 'stackTrace'),
                  subDomain: 'runPromptGeneration',
                ),
              ).called(1);
              return;
            }

            final captured = verify(
              () => bench.aiInputRepository.createAiResponseEntry(
                data: captureAny(named: 'data'),
                start: any(named: 'start'),
                linkedId: captureAny(named: 'linkedId'),
                categoryId: captureAny(named: 'categoryId'),
              ),
            ).captured;
            final data = captured[0] as AiResponseData;
            expect(
              data.response,
              scenario.streamScenario.expectedResponse,
              reason: '$scenario',
            );
            expect(data.model, scenario.expectedModel, reason: '$scenario');
            expect(data.type, AiResponseType.promptGeneration);
            expect(data.skillId, testPromptGenSkill.id);
            expect(captured[1], entryId);
            expect(captured[2], 'cat-generated');
            verify(
              () => bench.loggingService.log(
                LogDomain.ai,
                any<String>(),
                subDomain: 'runPromptGeneration',
              ),
            ).called(1);
          } finally {
            bench.dispose();
          }
        },
        tags: 'glados',
      );

      test('logs exception on failure', () async {
        when(
          () => mockAiInputRepo.getEntity('entry-1'),
        ).thenThrow(Exception('DB error'));
        stubLoggingException();

        await runner.runPromptGeneration(
          entryId: 'entry-1',
          automationResult: makePromptGenerationResult(),
        );

        verify(
          () => mockLoggingService.error(
            LogDomain.ai,
            any<Object>(),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
            subDomain: 'runPromptGeneration',
          ),
        ).called(1);
      });

      test('persists skillId on the AiResponseEntry data', () async {
        final textEntry = makeTextEntry(
          id: 'text-skill-id',
          markdown: 'Some prompt input',
        );

        when(
          () => mockAiInputRepo.getEntity('text-skill-id'),
        ).thenAnswer((_) async => textEntry);
        when(
          () => mockCloudRepo.generate(
            any(),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            provider: any(named: 'provider'),
            systemMessage: any(named: 'systemMessage'),
          ),
        ).thenAnswer(
          (_) => Stream.fromIterable([makeStreamChunk('out')]),
        );
        when(
          () => mockAiInputRepo.createAiResponseEntry(
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => null);
        stubLoggingEvent();

        await runner.runPromptGeneration(
          entryId: 'text-skill-id',
          automationResult: makePromptGenerationResult(),
        );

        final captured = verify(
          () => mockAiInputRepo.createAiResponseEntry(
            data: captureAny(named: 'data'),
            start: any(named: 'start'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).captured;
        final data = captured.single as AiResponseData;
        // The automation result uses `testPromptGenSkill` whose id is
        // 'skill-prompt-gen' — that exact ID must be persisted so the card
        // can render the right skill name.
        expect(data.skillId, 'skill-prompt-gen');
      });

      test(
        'persists imagePromptGeneration responses under the matching '
        'AiResponseType',
        () async {
          final imagePromptSkill =
              AiConfig.skill(
                    id: 'skill-img-prompt',
                    name: 'Generate Image Prompt',
                    skillType: SkillType.imagePromptGeneration,
                    requiredInputModalities: const [Modality.text],
                    contextPolicy: ContextPolicy.fullTask,
                    systemInstructions: 'sys',
                    userInstructions: 'usr',
                    useReasoning: true,
                    createdAt: DateTime(2024),
                  )
                  as AiConfigSkill;

          final result = AutomationResult(
            handled: true,
            resolvedProfile: ResolvedProfile(
              thinkingModelId: 'models/gemini-flash',
              thinkingProvider: testInferenceProvider(),
            ),
            skill: imagePromptSkill,
          );

          final textEntry = makeTextEntry(
            id: 'text-img-prompt',
            markdown: 'A serene watercolor of mist over pines',
          );

          when(
            () => mockAiInputRepo.getEntity('text-img-prompt'),
          ).thenAnswer((_) async => textEntry);
          when(
            () => mockCloudRepo.generate(
              any(),
              model: any(named: 'model'),
              temperature: any(named: 'temperature'),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              provider: any(named: 'provider'),
              systemMessage: any(named: 'systemMessage'),
            ),
          ).thenAnswer(
            (_) => Stream.fromIterable([
              makeStreamChunk('## Summary\n…\n## Prompt\nWatercolor scene'),
            ]),
          );
          when(
            () => mockAiInputRepo.createAiResponseEntry(
              data: any(named: 'data'),
              start: any(named: 'start'),
              linkedId: any(named: 'linkedId'),
              categoryId: any(named: 'categoryId'),
            ),
          ).thenAnswer((_) async => null);
          stubLoggingEvent();

          await runner.runPromptGeneration(
            entryId: 'text-img-prompt',
            automationResult: result,
          );

          final captured = verify(
            () => mockAiInputRepo.createAiResponseEntry(
              data: captureAny(named: 'data'),
              start: any(named: 'start'),
              linkedId: any(named: 'linkedId'),
              categoryId: any(named: 'categoryId'),
            ),
          ).captured;
          final data = captured.single as AiResponseData;
          expect(data.type, AiResponseType.imagePromptGeneration);
        },
      );
    });

    group('runImageGeneration', () {
      final testImageGenSkill =
          AiConfig.skill(
                id: 'skill-image-gen',
                name: 'Generate Cover Art',
                skillType: SkillType.imageGeneration,
                requiredInputModalities: const [Modality.text],
                contextPolicy: ContextPolicy.fullTask,
                systemInstructions: 'You are a visual artist.',
                userInstructions: 'Generate a cover art image.',
                createdAt: DateTime(2024),
              )
              as AiConfigSkill;

      AutomationResult makeImageGenResult() {
        return AutomationResult(
          handled: true,
          resolvedProfile: ResolvedProfile(
            thinkingModelId: 'models/gemini-flash',
            thinkingProvider: testInferenceProvider(),
            imageGenerationModelId: 'models/gemini-image',
            imageGenerationProvider: testInferenceProvider(id: 'p-image'),
          ),
          skill: testImageGenSkill,
        );
      }

      test('logs error when skill is null', () async {
        final result = AutomationResult(
          handled: true,
          resolvedProfile: ResolvedProfile(
            thinkingModelId: 'models/gemini-flash',
            thinkingProvider: testInferenceProvider(),
          ),
        );
        stubLoggingException();

        await runner.runImageGeneration(
          entryId: 'entry-1',
          automationResult: result,
          linkedTaskId: 'task-1',
        );

        verify(
          () => mockLoggingService.error(
            LogDomain.ai,
            any<Object>(),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
            subDomain: 'runImageGeneration',
          ),
        ).called(1);
      });

      test('logs error when profile is null', () async {
        final result = AutomationResult(
          handled: true,
          skill: testImageGenSkill,
        );
        stubLoggingException();

        await runner.runImageGeneration(
          entryId: 'entry-1',
          automationResult: result,
          linkedTaskId: 'task-1',
        );

        verify(
          () => mockLoggingService.error(
            LogDomain.ai,
            any<Object>(),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
            subDomain: 'runImageGeneration',
          ),
        ).called(1);
      });

      test('logs error when no image generation provider', () async {
        final result = AutomationResult(
          handled: true,
          resolvedProfile: ResolvedProfile(
            thinkingModelId: 'models/gemini-flash',
            thinkingProvider: testInferenceProvider(),
            // imageGenerationProvider/ModelId intentionally omitted
          ),
          skill: testImageGenSkill,
        );
        stubLoggingException();

        await runner.runImageGeneration(
          entryId: 'entry-1',
          automationResult: result,
          linkedTaskId: 'task-1',
        );

        verifyZeroInteractions(mockCloudRepo);
        verify(
          () => mockLoggingService.error(
            LogDomain.ai,
            any<Object>(),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
            subDomain: 'runImageGeneration',
          ),
        ).called(1);
      });

      test(
        'rejects non-text-bearing entities (Task) and never calls generator',
        () async {
          when(
            () => mockAiInputRepo.getEntity('entry-1'),
          ).thenAnswer((_) async => makeTaskEntity('entry-1'));
          stubLoggingException();

          await runner.runImageGeneration(
            entryId: 'entry-1',
            automationResult: makeImageGenResult(),
            linkedTaskId: 'task-1',
          );

          verifyNever(
            () => mockCloudRepo.generateImage(
              prompt: any(named: 'prompt'),
              model: any(named: 'model'),
              provider: any(named: 'provider'),
            ),
          );
          verify(
            () => mockLoggingService.error(
              LogDomain.ai,
              any<Object>(),
              stackTrace: any<StackTrace?>(named: 'stackTrace'),
              subDomain: 'runImageGeneration',
            ),
          ).called(1);
        },
      );

      test('logs error when getEntity returns null', () async {
        when(
          () => mockAiInputRepo.getEntity('missing-img'),
        ).thenAnswer((_) async => null);
        stubLoggingException();

        await runner.runImageGeneration(
          entryId: 'missing-img',
          automationResult: makeImageGenResult(),
          linkedTaskId: 'task-1',
        );

        verifyNever(
          () => mockCloudRepo.generateImage(
            prompt: any(named: 'prompt'),
            model: any(named: 'model'),
            provider: any(named: 'provider'),
          ),
        );
        verify(
          () => mockLoggingService.error(
            LogDomain.ai,
            any<Object>(),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
            subDomain: 'runImageGeneration',
          ),
        ).called(1);
      });

      test(
        'accepts a JournalEntry source and threads its text into the prompt',
        () async {
          final textEntry = makeTextEntry(
            id: 'text-img',
            markdown: 'Sunset over mountains, painterly style',
            categoryId: 'cat-img',
          );
          final taskEntity = makeTaskEntity('task-text-img');

          when(
            () => mockAiInputRepo.getEntity('text-img'),
          ).thenAnswer((_) async => textEntry);
          when(
            () => mockAiInputRepo.buildTaskDetailsJson(id: 'task-text-img'),
          ).thenAnswer((_) async => '{"id": "task-text-img"}');
          when(
            () => mockAiInputRepo.buildLinkedTasksJson('task-text-img'),
          ).thenAnswer((_) async => '{"linked": []}');
          when(
            () => mockTaskSummaryResolver.resolve('task-text-img'),
          ).thenAnswer((_) async => 'Mountain photography brief');
          when(
            () => mockCloudRepo.generateImage(
              prompt: any(named: 'prompt'),
              model: any(named: 'model'),
              provider: any(named: 'provider'),
              systemMessage: any(named: 'systemMessage'),
              referenceImages: any(named: 'referenceImages'),
            ),
          ).thenAnswer(
            (_) async => const GeneratedImage(
              bytes: [0x89, 0x50, 0x4E, 0x47],
              mimeType: 'image/png',
            ),
          );

          final mockPersistenceLogic = MockPersistenceLogic();
          getIt
            ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
            ..unregister<DomainLogger>()
            ..registerSingleton<DomainLogger>(mockLoggingService);

          when(
            () => mockPersistenceLogic.createMetadata(
              dateFrom: any(named: 'dateFrom'),
              dateTo: any(named: 'dateTo'),
              uuidV5Input: any(named: 'uuidV5Input'),
              flag: any(named: 'flag'),
              categoryId: any(named: 'categoryId'),
            ),
          ).thenAnswer(
            (_) async => Metadata(
              id: 'gen-img',
              createdAt: DateTime(2024),
              updatedAt: DateTime(2024),
              dateFrom: DateTime(2024),
              dateTo: DateTime(2024),
              categoryId: 'cat-img',
            ),
          );
          when(
            () => mockPersistenceLogic.createDbEntity(
              any(),
              linkedId: any(named: 'linkedId'),
              shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
              enqueueSync: any(named: 'enqueueSync'),
            ),
          ).thenAnswer((_) async => true);
          when(
            () => mockJournalRepo.getJournalEntityById('task-text-img'),
          ).thenAnswer((_) async => taskEntity);
          when(
            () => mockPersistenceLogic.updateTask(
              journalEntityId: any(named: 'journalEntityId'),
              taskData: any(named: 'taskData'),
            ),
          ).thenAnswer((_) async => true);
          stubLoggingEvent();

          await runner.runImageGeneration(
            entryId: 'text-img',
            automationResult: makeImageGenResult(),
            linkedTaskId: 'task-text-img',
          );

          final captured = verify(
            () => mockCloudRepo.generateImage(
              prompt: captureAny(named: 'prompt'),
              model: any(named: 'model'),
              provider: any(named: 'provider'),
              systemMessage: any(named: 'systemMessage'),
              referenceImages: any(named: 'referenceImages'),
            ),
          ).captured;
          final prompt = captured.first as String;
          expect(prompt, contains('**Entry Notes:**'));
          expect(prompt, contains('Sunset over mountains, painterly style'));
        },
      );

      test(
        'threads the [No transcription available] placeholder into the '
        'prompt for an audio entry without transcript or entry text',
        () async {
          // No entryText and no transcripts → _resolveEntryContent falls
          // through to the placeholder for runImageGeneration too.
          final audioEntity = makeAudioEntity(id: 'audio-img');
          final taskEntity = makeTaskEntity('task-audio-img');

          when(
            () => mockAiInputRepo.getEntity('audio-img'),
          ).thenAnswer((_) async => audioEntity);
          when(
            () => mockAiInputRepo.buildTaskDetailsJson(id: 'task-audio-img'),
          ).thenAnswer((_) async => '{"id": "task-audio-img"}');
          when(
            () => mockAiInputRepo.buildLinkedTasksJson('task-audio-img'),
          ).thenAnswer((_) async => '{"linked": []}');
          when(
            () => mockTaskSummaryResolver.resolve('task-audio-img'),
          ).thenAnswer((_) async => 'Audio task brief');
          when(
            () => mockCloudRepo.generateImage(
              prompt: any(named: 'prompt'),
              model: any(named: 'model'),
              provider: any(named: 'provider'),
              systemMessage: any(named: 'systemMessage'),
              referenceImages: any(named: 'referenceImages'),
            ),
          ).thenAnswer(
            (_) async => const GeneratedImage(
              bytes: [0x89, 0x50, 0x4E, 0x47],
              mimeType: 'image/png',
            ),
          );

          final mockPersistenceLogic = MockPersistenceLogic();
          getIt
            ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
            ..unregister<DomainLogger>()
            ..registerSingleton<DomainLogger>(mockLoggingService);

          when(
            () => mockPersistenceLogic.createMetadata(
              dateFrom: any(named: 'dateFrom'),
              dateTo: any(named: 'dateTo'),
              uuidV5Input: any(named: 'uuidV5Input'),
              flag: any(named: 'flag'),
              categoryId: any(named: 'categoryId'),
            ),
          ).thenAnswer(
            (_) async => Metadata(
              id: 'gen-img-audio',
              createdAt: DateTime(2024),
              updatedAt: DateTime(2024),
              dateFrom: DateTime(2024),
              dateTo: DateTime(2024),
            ),
          );
          when(
            () => mockPersistenceLogic.createDbEntity(
              any(),
              linkedId: any(named: 'linkedId'),
              shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
              enqueueSync: any(named: 'enqueueSync'),
            ),
          ).thenAnswer((_) async => true);
          when(
            () => mockJournalRepo.getJournalEntityById('task-audio-img'),
          ).thenAnswer((_) async => taskEntity);
          when(
            () => mockPersistenceLogic.updateTask(
              journalEntityId: any(named: 'journalEntityId'),
              taskData: any(named: 'taskData'),
            ),
          ).thenAnswer((_) async => true);
          stubLoggingEvent();

          await runner.runImageGeneration(
            entryId: 'audio-img',
            automationResult: makeImageGenResult(),
            linkedTaskId: 'task-audio-img',
          );

          final captured = verify(
            () => mockCloudRepo.generateImage(
              prompt: captureAny(named: 'prompt'),
              model: any(named: 'model'),
              provider: any(named: 'provider'),
              systemMessage: any(named: 'systemMessage'),
              referenceImages: any(named: 'referenceImages'),
            ),
          ).captured;
          final prompt = captured.first as String;
          expect(prompt, contains('[No transcription available]'));
        },
      );

      test('logs exception on failure', () async {
        when(
          () => mockAiInputRepo.getEntity('entry-1'),
        ).thenThrow(Exception('DB error'));
        stubLoggingException();

        await runner.runImageGeneration(
          entryId: 'entry-1',
          automationResult: makeImageGenResult(),
          linkedTaskId: 'task-1',
        );

        verify(
          () => mockLoggingService.error(
            LogDomain.ai,
            any<Object>(),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
            subDomain: 'runImageGeneration',
          ),
        ).called(1);
      });

      test(
        'happy path: generates cover art, imports image, and updates task',
        () async {
          final audioEntity =
              JournalEntity.journalAudio(
                    meta: Metadata(
                      id: 'audio-gen',
                      createdAt: DateTime(2024),
                      updatedAt: DateTime(2024),
                      dateFrom: DateTime(2024),
                      dateTo: DateTime(2024),
                      categoryId: 'cat-1',
                    ),
                    data: AudioData(
                      dateFrom: DateTime(2024),
                      dateTo: DateTime(2024),
                      duration: const Duration(minutes: 1),
                      audioDirectory: '/audio/',
                      audioFile: 'test.aac',
                    ),
                    entryText: const EntryText(
                      plainText: 'A sunset over a mountain landscape',
                      markdown: 'A sunset over a mountain landscape',
                    ),
                  )
                  as JournalAudio;

          final taskEntity = makeTaskEntity('task-gen');

          // Stub entity fetching.
          when(
            () => mockAiInputRepo.getEntity('audio-gen'),
          ).thenAnswer((_) async => audioEntity);
          when(
            () => mockAiInputRepo.buildTaskDetailsJson(id: 'task-gen'),
          ).thenAnswer((_) async => '{"id": "task-gen"}');
          when(
            () => mockAiInputRepo.buildLinkedTasksJson('task-gen'),
          ).thenAnswer(
            (_) async => '{"linked_from": [], "linked_to": []}',
          );
          when(
            () => mockTaskSummaryResolver.resolve('task-gen'),
          ).thenAnswer((_) async => 'A task about mountain photography');

          // Stub image generation.
          when(
            () => mockCloudRepo.generateImage(
              prompt: any(named: 'prompt'),
              model: any(named: 'model'),
              provider: any(named: 'provider'),
              systemMessage: any(named: 'systemMessage'),
              referenceImages: any(named: 'referenceImages'),
            ),
          ).thenAnswer(
            (_) async => const GeneratedImage(
              bytes: [0x89, 0x50, 0x4E, 0x47], // PNG header
              mimeType: 'image/png',
            ),
          );

          // Register PersistenceLogic mock in getIt for importGeneratedImageBytes
          // and task update.
          final mockPersistenceLogic = MockPersistenceLogic();
          getIt
            ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
            ..unregister<DomainLogger>()
            ..registerSingleton<DomainLogger>(mockLoggingService);

          when(
            () => mockPersistenceLogic.createMetadata(
              dateFrom: any(named: 'dateFrom'),
              dateTo: any(named: 'dateTo'),
              uuidV5Input: any(named: 'uuidV5Input'),
              flag: any(named: 'flag'),
              categoryId: any(named: 'categoryId'),
            ),
          ).thenAnswer(
            (_) async => Metadata(
              id: 'generated-img-id',
              createdAt: DateTime(2024),
              updatedAt: DateTime(2024),
              dateFrom: DateTime(2024),
              dateTo: DateTime(2024),
              categoryId: 'cat-1',
            ),
          );
          when(
            () => mockPersistenceLogic.createDbEntity(
              any(),
              linkedId: any(named: 'linkedId'),
              shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
              enqueueSync: any(named: 'enqueueSync'),
            ),
          ).thenAnswer((_) async => true);

          // Stub task fetching for cover art assignment.
          when(
            () => mockJournalRepo.getJournalEntityById('task-gen'),
          ).thenAnswer((_) async => taskEntity);

          when(
            () => mockPersistenceLogic.updateTask(
              journalEntityId: any(named: 'journalEntityId'),
              taskData: any(named: 'taskData'),
            ),
          ).thenAnswer((_) async => true);

          stubLoggingEvent();

          // Create a container with the trigger provider overridden.
          final mockTrigger = MockAutomaticImageAnalysisTrigger();
          when(
            () => mockTrigger.triggerAutomaticImageAnalysis(
              imageEntryId: any(named: 'imageEntryId'),
              linkedTaskId: any(named: 'linkedTaskId'),
            ),
          ).thenAnswer((_) async => true);

          // Rebuild runner with a container that has the trigger override.
          final testContainer = ProviderContainer(
            overrides: [
              automaticImageAnalysisTriggerProvider.overrideWithValue(
                mockTrigger,
              ),
            ],
          );
          addTearDown(testContainer.dispose);

          late final Ref capturedRef;
          final refProvider = Provider<void>((ref) {
            capturedRef = ref;
          });
          testContainer.read(refProvider);

          final testRunner = SkillInferenceRunner(
            ref: capturedRef,
            cloudRepository: mockCloudRepo,
            aiInputRepository: mockAiInputRepo,
            journalRepository: mockJournalRepo,
            loggingService: mockLoggingService,
            promptBuilderHelper: mockPromptBuilderHelper,
            taskSummaryResolver: mockTaskSummaryResolver,
          );

          await testRunner.runImageGeneration(
            entryId: 'audio-gen',
            automationResult: makeImageGenResult(),
            linkedTaskId: 'task-gen',
          );

          // Verify image generation was called.
          verify(
            () => mockCloudRepo.generateImage(
              prompt: any(named: 'prompt'),
              model: 'models/gemini-image',
              provider: any(named: 'provider'),
              systemMessage: any(named: 'systemMessage'),
              referenceImages: any(named: 'referenceImages'),
            ),
          ).called(1);

          // Verify task was updated with cover art.
          verify(
            () => mockPersistenceLogic.updateTask(
              journalEntityId: 'task-gen',
              taskData: any(named: 'taskData'),
            ),
          ).called(1);

          // Verify success event was logged.
          verify(
            () => mockLoggingService.log(
              LogDomain.ai,
              any<String>(that: contains('image generation completed')),
              subDomain: 'runImageGeneration',
            ),
          ).called(1);

          // Verify automatic image analysis was triggered.
          verify(
            () => mockTrigger.triggerAutomaticImageAnalysis(
              imageEntryId: any(named: 'imageEntryId'),
              linkedTaskId: 'task-gen',
            ),
          ).called(1);
        },
      );

      test(
        'logs error when linked task not found before cover art save',
        () async {
          final audioEntity =
              JournalEntity.journalAudio(
                    meta: Metadata(
                      id: 'audio-err-1',
                      createdAt: DateTime(2024),
                      updatedAt: DateTime(2024),
                      dateFrom: DateTime(2024),
                      dateTo: DateTime(2024),
                    ),
                    data: AudioData(
                      dateFrom: DateTime(2024),
                      dateTo: DateTime(2024),
                      duration: const Duration(minutes: 1),
                      audioDirectory: '/audio/',
                      audioFile: 'test.aac',
                    ),
                    entryText: const EntryText(
                      plainText: 'test',
                      markdown: 'test',
                    ),
                  )
                  as JournalAudio;

          when(
            () => mockAiInputRepo.getEntity('audio-err-1'),
          ).thenAnswer((_) async => audioEntity);
          when(
            () => mockAiInputRepo.buildTaskDetailsJson(id: 'task-err-1'),
          ).thenAnswer((_) async => '{}');
          when(
            () => mockAiInputRepo.buildLinkedTasksJson('task-err-1'),
          ).thenAnswer((_) async => '{}');
          when(
            () => mockTaskSummaryResolver.resolve('task-err-1'),
          ).thenAnswer((_) async => null);

          when(
            () => mockCloudRepo.generateImage(
              prompt: any(named: 'prompt'),
              model: any(named: 'model'),
              provider: any(named: 'provider'),
              systemMessage: any(named: 'systemMessage'),
              referenceImages: any(named: 'referenceImages'),
            ),
          ).thenAnswer(
            (_) async => const GeneratedImage(
              bytes: [0x89, 0x50, 0x4E, 0x47],
              mimeType: 'image/png',
            ),
          );

          // Linked task not found
          when(
            () => mockJournalRepo.getJournalEntityById('task-err-1'),
          ).thenAnswer((_) async => null);

          stubLoggingException();

          await runner.runImageGeneration(
            entryId: 'audio-err-1',
            automationResult: makeImageGenResult(),
            linkedTaskId: 'task-err-1',
          );

          verify(
            () => mockLoggingService.error(
              LogDomain.ai,
              any<Object>(
                that: isA<StateError>().having(
                  (e) => e.message,
                  'message',
                  contains('not found before cover art save'),
                ),
              ),
              stackTrace: any<StackTrace?>(named: 'stackTrace'),
              subDomain: 'runImageGeneration',
            ),
          ).called(1);
        },
      );

      test(
        'logs error when image import fails',
        () async {
          final audioEntity =
              JournalEntity.journalAudio(
                    meta: Metadata(
                      id: 'audio-err-2',
                      createdAt: DateTime(2024),
                      updatedAt: DateTime(2024),
                      dateFrom: DateTime(2024),
                      dateTo: DateTime(2024),
                    ),
                    data: AudioData(
                      dateFrom: DateTime(2024),
                      dateTo: DateTime(2024),
                      duration: const Duration(minutes: 1),
                      audioDirectory: '/audio/',
                      audioFile: 'test.aac',
                    ),
                    entryText: const EntryText(
                      plainText: 'test',
                      markdown: 'test',
                    ),
                  )
                  as JournalAudio;

          final taskEntity = makeTaskEntity('task-err-2');

          when(
            () => mockAiInputRepo.getEntity('audio-err-2'),
          ).thenAnswer((_) async => audioEntity);
          when(
            () => mockAiInputRepo.buildTaskDetailsJson(id: 'task-err-2'),
          ).thenAnswer((_) async => '{}');
          when(
            () => mockAiInputRepo.buildLinkedTasksJson('task-err-2'),
          ).thenAnswer((_) async => '{}');
          when(
            () => mockTaskSummaryResolver.resolve('task-err-2'),
          ).thenAnswer((_) async => null);

          when(
            () => mockCloudRepo.generateImage(
              prompt: any(named: 'prompt'),
              model: any(named: 'model'),
              provider: any(named: 'provider'),
              systemMessage: any(named: 'systemMessage'),
              referenceImages: any(named: 'referenceImages'),
            ),
          ).thenAnswer(
            (_) async => const GeneratedImage(
              bytes: [0x89, 0x50, 0x4E, 0x47],
              mimeType: 'image/png',
            ),
          );

          when(
            () => mockJournalRepo.getJournalEntityById('task-err-2'),
          ).thenAnswer((_) async => taskEntity);

          // Mock PersistenceLogic so createDbEntity throws (causing
          // importGeneratedImageBytes to return null).
          final mockPersistenceLogic = MockPersistenceLogic();
          getIt
            ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
            ..unregister<DomainLogger>()
            ..registerSingleton<DomainLogger>(mockLoggingService);

          when(
            () => mockPersistenceLogic.createMetadata(
              dateFrom: any(named: 'dateFrom'),
              dateTo: any(named: 'dateTo'),
              uuidV5Input: any(named: 'uuidV5Input'),
              flag: any(named: 'flag'),
              categoryId: any(named: 'categoryId'),
            ),
          ).thenAnswer(
            (_) async => Metadata(
              id: 'gen-img-err2',
              createdAt: DateTime(2024),
              updatedAt: DateTime(2024),
              dateFrom: DateTime(2024),
              dateTo: DateTime(2024),
            ),
          );
          when(
            () => mockPersistenceLogic.createDbEntity(
              any(),
              linkedId: any(named: 'linkedId'),
              shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
              enqueueSync: any(named: 'enqueueSync'),
            ),
          ).thenThrow(Exception('DB write failed'));

          stubLoggingException();

          await runner.runImageGeneration(
            entryId: 'audio-err-2',
            automationResult: makeImageGenResult(),
            linkedTaskId: 'task-err-2',
          );

          verify(
            () => mockLoggingService.error(
              LogDomain.ai,
              any<Object>(),
              stackTrace: any<StackTrace?>(named: 'stackTrace'),
              subDomain: 'runImageGeneration',
            ),
          ).called(1);
        },
      );

      test(
        'logs error when task update returns false',
        () async {
          final audioEntity =
              JournalEntity.journalAudio(
                    meta: Metadata(
                      id: 'audio-err-3',
                      createdAt: DateTime(2024),
                      updatedAt: DateTime(2024),
                      dateFrom: DateTime(2024),
                      dateTo: DateTime(2024),
                      categoryId: 'cat-1',
                    ),
                    data: AudioData(
                      dateFrom: DateTime(2024),
                      dateTo: DateTime(2024),
                      duration: const Duration(minutes: 1),
                      audioDirectory: '/audio/',
                      audioFile: 'test.aac',
                    ),
                    entryText: const EntryText(
                      plainText: 'test',
                      markdown: 'test',
                    ),
                  )
                  as JournalAudio;

          final taskEntity = makeTaskEntity('task-err-3');

          when(
            () => mockAiInputRepo.getEntity('audio-err-3'),
          ).thenAnswer((_) async => audioEntity);
          when(
            () => mockAiInputRepo.buildTaskDetailsJson(id: 'task-err-3'),
          ).thenAnswer((_) async => '{}');
          when(
            () => mockAiInputRepo.buildLinkedTasksJson('task-err-3'),
          ).thenAnswer((_) async => '{}');
          when(
            () => mockTaskSummaryResolver.resolve('task-err-3'),
          ).thenAnswer((_) async => null);

          when(
            () => mockCloudRepo.generateImage(
              prompt: any(named: 'prompt'),
              model: any(named: 'model'),
              provider: any(named: 'provider'),
              systemMessage: any(named: 'systemMessage'),
              referenceImages: any(named: 'referenceImages'),
            ),
          ).thenAnswer(
            (_) async => const GeneratedImage(
              bytes: [0x89, 0x50, 0x4E, 0x47],
              mimeType: 'image/png',
            ),
          );

          when(
            () => mockJournalRepo.getJournalEntityById('task-err-3'),
          ).thenAnswer((_) async => taskEntity);

          final mockPersistenceLogic = MockPersistenceLogic();
          getIt
            ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
            ..unregister<DomainLogger>()
            ..registerSingleton<DomainLogger>(mockLoggingService);

          when(
            () => mockPersistenceLogic.createMetadata(
              dateFrom: any(named: 'dateFrom'),
              dateTo: any(named: 'dateTo'),
              uuidV5Input: any(named: 'uuidV5Input'),
              flag: any(named: 'flag'),
              categoryId: any(named: 'categoryId'),
            ),
          ).thenAnswer(
            (_) async => Metadata(
              id: 'gen-img-err3',
              createdAt: DateTime(2024),
              updatedAt: DateTime(2024),
              dateFrom: DateTime(2024),
              dateTo: DateTime(2024),
            ),
          );
          when(
            () => mockPersistenceLogic.createDbEntity(
              any(),
              linkedId: any(named: 'linkedId'),
              shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
              enqueueSync: any(named: 'enqueueSync'),
            ),
          ).thenAnswer((_) async => true);

          // updateTask returns false (task disappeared)
          when(
            () => mockPersistenceLogic.updateTask(
              journalEntityId: any(named: 'journalEntityId'),
              taskData: any(named: 'taskData'),
            ),
          ).thenAnswer((_) async => false);

          stubLoggingException();

          await runner.runImageGeneration(
            entryId: 'audio-err-3',
            automationResult: makeImageGenResult(),
            linkedTaskId: 'task-err-3',
          );

          verify(
            () => mockLoggingService.error(
              LogDomain.ai,
              any<Object>(
                that: isA<StateError>().having(
                  (e) => e.message,
                  'message',
                  contains('disappeared before cover art update'),
                ),
              ),
              stackTrace: any<StackTrace?>(named: 'stackTrace'),
              subDomain: 'runImageGeneration',
            ),
          ).called(1);
        },
      );

      test(
        'happy path with reference images passes them to generateImage',
        () async {
          final audioEntity =
              JournalEntity.journalAudio(
                    meta: Metadata(
                      id: 'audio-ref',
                      createdAt: DateTime(2024),
                      updatedAt: DateTime(2024),
                      dateFrom: DateTime(2024),
                      dateTo: DateTime(2024),
                    ),
                    data: AudioData(
                      dateFrom: DateTime(2024),
                      dateTo: DateTime(2024),
                      duration: const Duration(minutes: 1),
                      audioDirectory: '/audio/',
                      audioFile: 'test.aac',
                    ),
                    entryText: const EntryText(
                      plainText: 'Like the previous style',
                      markdown: 'Like the previous style',
                    ),
                  )
                  as JournalAudio;

          final taskEntity = makeTaskEntity('task-ref');

          when(
            () => mockAiInputRepo.getEntity('audio-ref'),
          ).thenAnswer((_) async => audioEntity);
          when(
            () => mockAiInputRepo.buildTaskDetailsJson(id: 'task-ref'),
          ).thenAnswer((_) async => '{"id": "task-ref"}');
          when(
            () => mockAiInputRepo.buildLinkedTasksJson('task-ref'),
          ).thenAnswer(
            (_) async => '{"linked_from": [], "linked_to": []}',
          );
          when(
            () => mockTaskSummaryResolver.resolve('task-ref'),
          ).thenAnswer((_) async => null);

          const refImages = [
            ProcessedReferenceImage(
              base64Data: 'abc123',
              mimeType: 'image/jpeg',
              originalId: 'ref-img-1',
            ),
          ];

          when(
            () => mockCloudRepo.generateImage(
              prompt: any(named: 'prompt'),
              model: any(named: 'model'),
              provider: any(named: 'provider'),
              systemMessage: any(named: 'systemMessage'),
              referenceImages: any(named: 'referenceImages'),
            ),
          ).thenAnswer(
            (_) async => const GeneratedImage(
              bytes: [0xFF, 0xD8, 0xFF, 0xE0], // JPEG header
              mimeType: 'image/jpeg',
            ),
          );

          // Register PersistenceLogic mock if not already registered.
          if (!getIt.isRegistered<PersistenceLogic>()) {
            final mockPersistenceLogic = MockPersistenceLogic();
            getIt.registerSingleton<PersistenceLogic>(mockPersistenceLogic);

            when(
              () => mockPersistenceLogic.createMetadata(
                dateFrom: any(named: 'dateFrom'),
                dateTo: any(named: 'dateTo'),
                uuidV5Input: any(named: 'uuidV5Input'),
                flag: any(named: 'flag'),
                categoryId: any(named: 'categoryId'),
              ),
            ).thenAnswer(
              (_) async => Metadata(
                id: 'gen-img-ref',
                createdAt: DateTime(2024),
                updatedAt: DateTime(2024),
                dateFrom: DateTime(2024),
                dateTo: DateTime(2024),
              ),
            );
            when(
              () => mockPersistenceLogic.createDbEntity(
                any(),
                linkedId: any(named: 'linkedId'),
                shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
                enqueueSync: any(named: 'enqueueSync'),
              ),
            ).thenAnswer((_) async => true);
            when(
              () => mockPersistenceLogic.updateTask(
                journalEntityId: any(named: 'journalEntityId'),
                taskData: any(named: 'taskData'),
              ),
            ).thenAnswer((_) async => true);
          }

          getIt
            ..unregister<DomainLogger>()
            ..registerSingleton<DomainLogger>(mockLoggingService);

          when(
            () => mockJournalRepo.getJournalEntityById('task-ref'),
          ).thenAnswer((_) async => taskEntity);

          stubLoggingEvent();

          final mockTrigger = MockAutomaticImageAnalysisTrigger();
          when(
            () => mockTrigger.triggerAutomaticImageAnalysis(
              imageEntryId: any(named: 'imageEntryId'),
              linkedTaskId: any(named: 'linkedTaskId'),
            ),
          ).thenAnswer((_) async => true);

          final testContainer = ProviderContainer(
            overrides: [
              automaticImageAnalysisTriggerProvider.overrideWithValue(
                mockTrigger,
              ),
            ],
          );
          addTearDown(testContainer.dispose);

          late final Ref capturedRef;
          final refProvider = Provider<void>((ref) {
            capturedRef = ref;
          });
          testContainer.read(refProvider);

          final testRunner = SkillInferenceRunner(
            ref: capturedRef,
            cloudRepository: mockCloudRepo,
            aiInputRepository: mockAiInputRepo,
            journalRepository: mockJournalRepo,
            loggingService: mockLoggingService,
            promptBuilderHelper: mockPromptBuilderHelper,
            taskSummaryResolver: mockTaskSummaryResolver,
          );

          await testRunner.runImageGeneration(
            entryId: 'audio-ref',
            automationResult: makeImageGenResult(),
            linkedTaskId: 'task-ref',
            referenceImages: refImages,
          );

          // Verify reference images were passed through.
          verify(
            () => mockCloudRepo.generateImage(
              prompt: any(named: 'prompt'),
              model: 'models/gemini-image',
              provider: any(named: 'provider'),
              systemMessage: any(named: 'systemMessage'),
              referenceImages: refImages,
            ),
          ).called(1);
        },
      );
    });

    group('runTranscription entity-disappeared guard', () {
      test(
        'throws StateError (caught and logged) when audio entity disappears '
        'between transcription and save — second getEntity returns null',
        () async {
          final audioEntity = makeAudioEntity();

          final audioDir = Directory('${tempDir.path}/audio');
          await audioDir.create(recursive: true);
          await File(
            '${audioDir.path}/test.aac',
          ).writeAsBytes([0x48, 0x65, 0x6c, 0x6c, 0x6f]);

          // First call (entity fetch) returns the audio entity;
          // second call (EntityStateHelper re-fetch) returns null
          // to simulate the entity vanishing mid-run.
          var callCount = 0;
          when(
            () => mockAiInputRepo.getEntity('audio-1'),
          ).thenAnswer((_) async {
            callCount++;
            return callCount == 1 ? audioEntity : null;
          });

          when(
            () => mockPromptBuilderHelper.getSpeechDictionaryTerms(audioEntity),
          ).thenAnswer((_) async => []);
          when(
            () => mockTaskSummaryResolver.resolve(any()),
          ).thenAnswer((_) async => null);

          // Return a non-empty response so we reach the re-fetch step.
          when(
            () => mockCloudRepo.generateWithAudio(
              any(),
              model: any(named: 'model'),
              audioBase64: any(named: 'audioBase64'),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              provider: any(named: 'provider'),
              systemMessage: any(named: 'systemMessage'),
              speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
            ),
          ).thenAnswer(
            (_) => Stream.fromIterable([makeStreamChunk('Hello World')]),
          );

          stubLoggingException();

          await runner.runTranscription(
            audioEntryId: 'audio-1',
            automationResult: makeTranscriptionResult(),
          );

          // The StateError is caught by _withStatusTracking and forwarded to
          // the logging service — no entity update must have been attempted.
          verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
          verify(
            () => mockLoggingService.error(
              LogDomain.ai,
              any<Object>(
                that: isA<StateError>().having(
                  (e) => e.message,
                  'message',
                  contains('disappeared mid-run'),
                ),
              ),
              stackTrace: any<StackTrace?>(named: 'stackTrace'),
              subDomain: 'runTranscription',
            ),
          ).called(1);
        },
      );
    });

    group('runImageAnalysis entity-disappeared guard', () {
      test(
        'throws StateError (caught and logged) when image entity disappears '
        'between analysis and save — second getEntity returns null',
        () async {
          final imageEntity = makeImageEntity();

          final imageDir = Directory('${tempDir.path}/images');
          await imageDir.create(recursive: true);
          await File(
            '${imageDir.path}/test.jpg',
          ).writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0]);

          // First call returns the image entity; second call (re-fetch for
          // EntityStateHelper) returns null to simulate disappearance.
          var callCount = 0;
          when(
            () => mockAiInputRepo.getEntity('img-1'),
          ).thenAnswer((_) async {
            callCount++;
            return callCount == 1 ? imageEntity : null;
          });

          when(
            () => mockTaskSummaryResolver.resolve(any()),
          ).thenAnswer((_) async => null);

          // Return a non-empty response so we reach the re-fetch step.
          when(
            () => mockCloudRepo.generateWithImages(
              any(),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              model: any(named: 'model'),
              temperature: any(named: 'temperature'),
              images: any(named: 'images'),
              provider: any(named: 'provider'),
              systemMessage: any(named: 'systemMessage'),
            ),
          ).thenAnswer(
            (_) => Stream.fromIterable([makeStreamChunk('A photo of a cat')]),
          );

          stubLoggingException();

          await runner.runImageAnalysis(
            imageEntryId: 'img-1',
            automationResult: makeImageAnalysisResult(),
          );

          // The StateError is caught by _withStatusTracking and forwarded to
          // the logging service — no journal update must have been attempted.
          verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
          verify(
            () => mockLoggingService.error(
              LogDomain.ai,
              any<Object>(
                that: isA<StateError>().having(
                  (e) => e.message,
                  'message',
                  contains('disappeared mid-run'),
                ),
              ),
              stackTrace: any<StackTrace?>(named: 'stackTrace'),
              subDomain: 'runImageAnalysis',
            ),
          ).called(1);
        },
      );
    });

    group('skillInferenceRunnerProvider factory', () {
      test(
        'creates a SkillInferenceRunner with a null AgentRepository when '
        'AgentDatabase is not registered in getIt — the TaskSummaryResolver '
        'receives null and falls back to empty context',
        () {
          // Ensure DomainLogger is available (provider reads getIt for it).
          getIt
            ..unregister<DomainLogger>()
            ..registerSingleton<DomainLogger>(mockLoggingService);

          final testContainer = ProviderContainer(
            overrides: [
              cloudInferenceRepositoryProvider.overrideWithValue(
                mockCloudRepo,
              ),
              aiInputRepositoryProvider.overrideWithValue(mockAiInputRepo),
              journalRepositoryProvider.overrideWithValue(mockJournalRepo),
            ],
          );
          addTearDown(testContainer.dispose);

          // Reading the provider exercises the factory function including the
          // getIt.isRegistered<AgentDatabase>() branch where no DB is present.
          final result = testContainer.read(skillInferenceRunnerProvider);

          expect(result, isA<SkillInferenceRunner>());
        },
      );

      test(
        'creates a SkillInferenceRunner with an AgentRepository when '
        'AgentDatabase IS registered in getIt — the TaskSummaryResolver '
        'receives a real repository so task-context is available at run time',
        () {
          // Register a mock AgentDatabase so the factory takes the non-null
          // branch.
          if (!getIt.isRegistered<AgentDatabase>()) {
            getIt.registerSingleton<AgentDatabase>(MockAgentDatabase());
          }
          getIt
            ..unregister<DomainLogger>()
            ..registerSingleton<DomainLogger>(mockLoggingService);

          final testContainer = ProviderContainer(
            overrides: [
              cloudInferenceRepositoryProvider.overrideWithValue(
                mockCloudRepo,
              ),
              aiInputRepositoryProvider.overrideWithValue(mockAiInputRepo),
              journalRepositoryProvider.overrideWithValue(mockJournalRepo),
            ],
          );
          addTearDown(testContainer.dispose);

          // Reading the provider exercises the factory function including the
          // getIt.isRegistered<AgentDatabase>() == true branch.
          final result = testContainer.read(skillInferenceRunnerProvider);

          expect(result, isA<SkillInferenceRunner>());
        },
      );
    });

    group('AutomationResult', () {
      test('transcription result has correct fields', () {
        final result = makeTranscriptionResult();

        expect(result.handled, isTrue);
        expect(result.skill!.skillType, SkillType.transcription);
        expect(result.resolvedProfile!.transcriptionProvider, isNotNull);
        expect(result.resolvedProfile!.transcriptionModelId, 'whisper-1');
      });

      test('image analysis result has correct fields', () {
        final result = makeImageAnalysisResult();

        expect(result.handled, isTrue);
        expect(result.skill!.skillType, SkillType.imageAnalysis);
        expect(
          result.resolvedProfile!.imageRecognitionProvider,
          isNotNull,
        );
        expect(
          result.resolvedProfile!.imageRecognitionModelId,
          'vision-model',
        );
      });
    });
  });
}
