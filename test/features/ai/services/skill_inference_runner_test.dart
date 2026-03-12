import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/model/skill_assignment.dart';
import 'package:lotti/features/ai/services/profile_automation_service.dart';
import 'package:lotti/features/ai/services/skill_inference_runner.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../agents/test_utils.dart';

void main() {
  late MockCloudInferenceRepository mockCloudRepo;
  late MockAiInputRepository mockAiInputRepo;
  late MockJournalRepository mockJournalRepo;
  late MockLoggingService mockLoggingService;
  late MockPromptBuilderHelper mockPromptBuilderHelper;
  late SkillInferenceRunner runner;

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

  setUp(() {
    mockCloudRepo = MockCloudInferenceRepository();
    mockAiInputRepo = MockAiInputRepository();
    mockJournalRepo = MockJournalRepository();
    mockLoggingService = MockLoggingService();
    mockPromptBuilderHelper = MockPromptBuilderHelper();

    runner = SkillInferenceRunner(
      cloudRepository: mockCloudRepo,
      aiInputRepository: mockAiInputRepo,
      journalRepository: mockJournalRepo,
      loggingService: mockLoggingService,
      promptBuilderHelper: mockPromptBuilderHelper,
    );
  });

  group('SkillInferenceRunner', () {
    group('runTranscription', () {
      test('returns early when entity is null', () async {
        when(
          () => mockAiInputRepo.getEntity('entry-1'),
        ).thenAnswer((_) async => null);

        await runner.runTranscription(
          audioEntryId: 'entry-1',
          automationResult: makeTranscriptionResult(),
          linkedTaskId: 'task-1',
        );

        // Should not attempt any cloud inference
        verifyZeroInteractions(mockCloudRepo);
      });

      test('returns early when entity is not JournalAudio', () async {
        // Return a Task entity instead of audio
        when(
          () => mockAiInputRepo.getEntity('entry-1'),
        ).thenAnswer(
          (_) async => JournalEntity.task(
            meta: Metadata(
              id: 'entry-1',
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
          ),
        );

        await runner.runTranscription(
          audioEntryId: 'entry-1',
          automationResult: makeTranscriptionResult(),
          linkedTaskId: 'task-1',
        );

        verifyZeroInteractions(mockCloudRepo);
      });

      test('logs exception on failure', () async {
        when(
          () => mockAiInputRepo.getEntity('entry-1'),
        ).thenThrow(Exception('DB error'));

        // Stub the logging
        when(
          () => mockLoggingService.captureException(
            any<dynamic>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          ),
        ).thenReturn(null);

        await runner.runTranscription(
          audioEntryId: 'entry-1',
          automationResult: makeTranscriptionResult(),
          linkedTaskId: 'task-1',
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
      test('returns early when entity is null', () async {
        when(
          () => mockAiInputRepo.getEntity('img-1'),
        ).thenAnswer((_) async => null);

        await runner.runImageAnalysis(
          imageEntryId: 'img-1',
          automationResult: makeImageAnalysisResult(),
          linkedTaskId: 'task-1',
        );

        verifyZeroInteractions(mockCloudRepo);
      });

      test('logs exception on failure', () async {
        when(
          () => mockAiInputRepo.getEntity('img-1'),
        ).thenThrow(Exception('DB error'));

        when(
          () => mockLoggingService.captureException(
            any<dynamic>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          ),
        ).thenReturn(null);

        await runner.runImageAnalysis(
          imageEntryId: 'img-1',
          automationResult: makeImageAnalysisResult(),
          linkedTaskId: 'task-1',
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
