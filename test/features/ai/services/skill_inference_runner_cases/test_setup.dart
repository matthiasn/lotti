part of '../skill_inference_runner_test.dart';

/// Stubs the [MockDomainLogger.error] sink so error-path code can log without
/// throwing on an unstubbed call. Shared by the file-level tests and the
/// [_GeneratedSkillRunnerBench] so the stub shape lives in one place.
void _stubLoggingExceptionFor(MockDomainLogger logger) {
  when(
    () => logger.error(
      any<LogDomain>(),
      any<Object>(),
      stackTrace: any<StackTrace?>(named: 'stackTrace'),
      subDomain: any<String>(named: 'subDomain'),
    ),
  ).thenReturn(null);
}

AiInteractionCaptureTestBench _registerInteractionCapture() {
  final bench = AiInteractionCaptureTestBench.create()..register();
  addTearDown(bench.unregister);
  return bench;
}

List<AiConsumptionEvent> _capturedEvents(
  AiInteractionCaptureTestBench bench,
) => verify(
  () => bench.service.recordInteraction(
    attributionId: any(named: 'attributionId'),
    event: captureAny(named: 'event'),
  ),
).captured.cast<AiConsumptionEvent>();

/// Stubs the [MockDomainLogger.log] sink for event-path code. Shared by the
/// file-level tests and the [_GeneratedSkillRunnerBench].
void _stubLoggingEventFor(MockDomainLogger logger) {
  when(
    () => logger.log(
      any<LogDomain>(),
      any<String>(),
      subDomain: any<String>(named: 'subDomain'),
    ),
  ).thenReturn(null);
}

class _SkillInferenceTestSetup {
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
    AiConfigModel? thinkingModel,
    AiConfigInferenceProvider? thinkingProvider,
  }) {
    return AutomationResult(
      handled: true,
      resolvedProfile: ResolvedProfile(
        thinkingModelId:
            thinkingModel?.providerModelId ?? 'models/gemini-flash',
        thinkingProvider:
            thinkingProvider ?? testInferenceProvider(id: 'p-flash'),
        thinkingModel: thinkingModel,
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

  /// Creates a stream response chunk with the given content. Providers report
  /// [usage] on the final chunk, so tests exercising consumption recording
  /// attach it there.
  CreateChatCompletionStreamResponse makeStreamChunk(
    String content, {
    CompletionUsage? usage,
  }) {
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
      usage: usage,
    );
  }

  AiResponseEntry makePersistedResponse(Invocation invocation) {
    final start = invocation.namedArguments[#start] as DateTime;
    return AiResponseEntry(
      meta: Metadata(
        id: invocation.namedArguments[#id] as String? ?? 'ai-response-1',
        createdAt: start,
        updatedAt: start,
        dateFrom: start,
        dateTo: start,
        categoryId: invocation.namedArguments[#categoryId] as String?,
      ),
      data: invocation.namedArguments[#data] as AiResponseData,
    );
  }

  void stubLoggingException() => _stubLoggingExceptionFor(mockLoggingService);

  void stubLoggingEvent() => _stubLoggingEventFor(mockLoggingService);

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

  void registerLifecycle() {
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
      // No category brief unless a case says otherwise: the coding-prompt
      // path reads it beside the task context on every linked run.
      when(
        () => mockAiInputRepo.buildCategoryKnowledge(any()),
      ).thenAnswer((_) async => null);

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
  }

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
}
