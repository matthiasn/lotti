import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/model/skill_assignment.dart';
import 'package:lotti/features/ai/services/profile_automation_service.dart';
import 'package:lotti/features/ai/services/skill_inference_runner.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../agents/test_utils.dart';

void main() {
  late MockCloudInferenceRepository mockCloudRepo;
  late MockAiInputRepository mockAiInputRepo;
  late MockJournalRepository mockJournalRepo;
  late MockLoggingService mockLoggingService;
  late MockPromptBuilderHelper mockPromptBuilderHelper;
  late MockTaskSummaryResolver mockTaskSummaryResolver;
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
  }) {
    return JournalEntity.journalAudio(
          meta: Metadata(
            id: id,
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
            dateFrom: DateTime(2024),
            dateTo: DateTime(2024),
          ),
          data: AudioData(
            dateFrom: DateTime(2024),
            dateTo: DateTime(2024),
            duration: const Duration(minutes: 1),
            audioDirectory: audioDirectory,
            audioFile: audioFile,
          ),
        )
        as JournalAudio;
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
      () => mockLoggingService.captureException(
        any<dynamic>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'),
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
      ),
    ).thenReturn(null);
  }

  void stubLoggingEvent() {
    when(
      () => mockLoggingService.captureEvent(
        any<String>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'),
      ),
    ).thenReturn(null);
  }

  setUpAll(registerAllFallbackValues);

  setUp(() async {
    mockCloudRepo = MockCloudInferenceRepository();
    mockAiInputRepo = MockAiInputRepository();
    mockJournalRepo = MockJournalRepository();
    mockLoggingService = MockLoggingService();
    mockPromptBuilderHelper = MockPromptBuilderHelper();
    mockTaskSummaryResolver = MockTaskSummaryResolver();

    container = ProviderContainer();

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
    await getIt.reset();
    getIt.registerSingleton<Directory>(tempDir);
  });

  tearDown(() async {
    container.dispose();
    await getIt.reset();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('SkillInferenceRunner', () {
    group('runTranscription', () {
      test('returns early when skill is null in AutomationResult', () async {
        final result = AutomationResult(
          handled: true,
          resolvedProfile: ResolvedProfile(
            thinkingModelId: 'models/gemini-3-flash-preview',
            thinkingProvider: testInferenceProvider(),
            transcriptionModelId: 'whisper-1',
            transcriptionProvider: testInferenceProvider(id: 'p-audio'),
          ),
        );

        await runner.runTranscription(
          audioEntryId: 'entry-1',
          automationResult: result,
        );

        verifyZeroInteractions(mockCloudRepo);
        verifyZeroInteractions(mockAiInputRepo);
      });

      test('returns early when profile is null in AutomationResult', () async {
        final result = AutomationResult(
          handled: true,
          skill: testSkill,
        );

        await runner.runTranscription(
          audioEntryId: 'entry-1',
          automationResult: result,
        );

        verifyZeroInteractions(mockCloudRepo);
        verifyZeroInteractions(mockAiInputRepo);
      });

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
        final audioDir = Directory('${tempDir.path}/audio');
        await audioDir.create(recursive: true);
        await File('${audioDir.path}/test.aac').writeAsBytes([0x01]);

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

        final audioDir = Directory('${tempDir.path}/audio');
        await audioDir.create(recursive: true);
        await File('${audioDir.path}/test.aac').writeAsBytes([0x01]);

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
          () => mockLoggingService.captureException(
            any<dynamic>(),
            domain: 'SkillInferenceRunner',
            subDomain: 'runTranscription',
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          ),
        ).called(1);
      });
    });

    group('runImageAnalysis', () {
      test('returns early when skill is null in AutomationResult', () async {
        final result = AutomationResult(
          handled: true,
          resolvedProfile: ResolvedProfile(
            thinkingModelId: 'models/gemini-3-flash-preview',
            thinkingProvider: testInferenceProvider(),
            imageRecognitionModelId: 'vision-model',
            imageRecognitionProvider: testInferenceProvider(id: 'p-vision'),
          ),
        );

        await runner.runImageAnalysis(
          imageEntryId: 'img-1',
          automationResult: result,
        );

        verifyZeroInteractions(mockCloudRepo);
        verifyZeroInteractions(mockAiInputRepo);
      });

      test('returns early when profile is null in AutomationResult', () async {
        final result = AutomationResult(
          handled: true,
          skill: testImageSkill,
        );

        await runner.runImageAnalysis(
          imageEntryId: 'img-1',
          automationResult: result,
        );

        verifyZeroInteractions(mockCloudRepo);
        verifyZeroInteractions(mockAiInputRepo);
      });

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

        final imageDir = Directory('${tempDir.path}/images');
        await imageDir.create(recursive: true);
        await File('${imageDir.path}/test.jpg').writeAsBytes([0x01]);

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

        final imageDir = Directory('${tempDir.path}/images');
        await imageDir.create(recursive: true);
        await File('${imageDir.path}/test.jpg').writeAsBytes([0x01]);

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

        final imageDir = Directory('${tempDir.path}/images');
        await imageDir.create(recursive: true);
        await File('${imageDir.path}/test.jpg').writeAsBytes([0x01]);

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
          () => mockLoggingService.captureException(
            any<dynamic>(),
            domain: 'SkillInferenceRunner',
            subDomain: 'runImageAnalysis',
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          ),
        ).called(1);
      });
    });

    group('runPromptGeneration', () {
      test('returns early when skill is null', () async {
        final result = AutomationResult(
          handled: true,
          resolvedProfile: ResolvedProfile(
            thinkingModelId: 'models/gemini-flash',
            thinkingProvider: testInferenceProvider(),
          ),
        );

        await runner.runPromptGeneration(
          audioEntryId: 'entry-1',
          automationResult: result,
        );

        verifyZeroInteractions(mockCloudRepo);
        verifyZeroInteractions(mockAiInputRepo);
      });

      test('returns early when profile is null', () async {
        final result = AutomationResult(
          handled: true,
          skill: testPromptGenSkill,
        );

        await runner.runPromptGeneration(
          audioEntryId: 'entry-1',
          automationResult: result,
        );

        verifyZeroInteractions(mockCloudRepo);
        verifyZeroInteractions(mockAiInputRepo);
      });

      test('returns early when entity is not JournalAudio', () async {
        when(
          () => mockAiInputRepo.getEntity('entry-1'),
        ).thenAnswer((_) async => makeTaskEntity('entry-1'));

        await runner.runPromptGeneration(
          audioEntryId: 'entry-1',
          automationResult: makePromptGenerationResult(),
        );

        verifyZeroInteractions(mockCloudRepo);
      });

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
          audioEntryId: 'audio-prompt',
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
          audioEntryId: 'audio-fallback',
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
          audioEntryId: 'audio-happy',
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

      test('extracts transcript from latest transcript when no entryText',
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
          audioEntryId: 'audio-transcript',
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
      });

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
          audioEntryId: 'audio-empty',
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

      test('logs exception on failure', () async {
        when(
          () => mockAiInputRepo.getEntity('entry-1'),
        ).thenThrow(Exception('DB error'));
        stubLoggingException();

        await runner.runPromptGeneration(
          audioEntryId: 'entry-1',
          automationResult: makePromptGenerationResult(),
        );

        verify(
          () => mockLoggingService.captureException(
            any<dynamic>(),
            domain: 'SkillInferenceRunner',
            subDomain: 'runPromptGeneration',
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          ),
        ).called(1);
      });
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
