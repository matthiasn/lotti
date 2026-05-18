import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/model/skill_assignment.dart';
import 'package:lotti/features/ai/services/profile_automation_service.dart';
import 'package:lotti/features/ai/skills/built_in_skills.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/utils/platform.dart' as platform;
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../agents/test_utils.dart';

enum _GeneratedAutomationOperation {
  transcribeDefault,
  transcribeOptIn,
  transcribeOptOut,
  analyzeImage,
}

enum _GeneratedAutomationAssignmentShape {
  nonAutomatedTarget,
  automatedMissingConfig,
  automatedWrongConfigType,
  automatedMismatchedSkill,
  automatedMatchingSkill,
}

class _GeneratedAutomationAssignmentSpec {
  const _GeneratedAutomationAssignmentSpec({
    required this.shape,
    required this.seed,
  });

  final _GeneratedAutomationAssignmentShape shape;
  final int seed;

  bool get automate =>
      shape != _GeneratedAutomationAssignmentShape.nonAutomatedTarget;

  String skillIdAt(int index) => 'generated-skill-$index-$seed-${shape.name}';

  @override
  String toString() {
    return '_GeneratedAutomationAssignmentSpec('
        'shape: $shape, seed: $seed)';
  }
}

class _GeneratedAutomationServiceScenario {
  const _GeneratedAutomationServiceScenario({
    required this.operation,
    required this.profileMissing,
    required this.modelSlotPresent,
    required this.assignmentSpecs,
  });

  final _GeneratedAutomationOperation operation;
  final bool profileMissing;
  final bool modelSlotPresent;
  final List<_GeneratedAutomationAssignmentSpec> assignmentSpecs;

  SkillType get targetSkillType => switch (operation) {
    _GeneratedAutomationOperation.transcribeDefault ||
    _GeneratedAutomationOperation.transcribeOptIn ||
    _GeneratedAutomationOperation.transcribeOptOut => SkillType.transcription,
    _GeneratedAutomationOperation.analyzeImage => SkillType.imageAnalysis,
  };

  bool get speechOptedOut =>
      operation == _GeneratedAutomationOperation.transcribeOptOut;

  List<SkillAssignment> get assignments => [
    for (var index = 0; index < assignmentSpecs.length; index++)
      SkillAssignment(
        skillId: assignmentSpecs[index].skillIdAt(index),
        automate: assignmentSpecs[index].automate,
      ),
  ];

  List<String> get expectedLookupIds {
    if (profileMissing || speechOptedOut) return const [];
    return [
      for (var index = 0; index < assignmentSpecs.length; index++)
        if (assignmentSpecs[index].automate)
          assignmentSpecs[index].skillIdAt(index),
    ];
  }

  bool get expectedHandled {
    if (profileMissing || speechOptedOut || !modelSlotPresent) {
      return false;
    }
    return matchingAssignmentIndices.length == 1;
  }

  List<int> get matchingAssignmentIndices => [
    for (var index = 0; index < assignmentSpecs.length; index++)
      if (assignmentSpecs[index].shape ==
          _GeneratedAutomationAssignmentShape.automatedMatchingSkill)
        index,
  ];

  int? get handledIndex =>
      expectedHandled ? matchingAssignmentIndices.single : null;

  SkillType skillTypeFor(String skillId) {
    final index = _indexFromSkillId(skillId);
    final shape = assignmentSpecs[index].shape;
    if (shape == _GeneratedAutomationAssignmentShape.automatedMatchingSkill ||
        shape == _GeneratedAutomationAssignmentShape.nonAutomatedTarget) {
      return targetSkillType;
    }
    return targetSkillType == SkillType.transcription
        ? SkillType.imageAnalysis
        : SkillType.transcription;
  }

  AiConfig? configFor(
    String skillId,
    AiConfigSkill Function({
      required String id,
      required SkillType skillType,
    })
    makeGeneratedSkill,
  ) {
    final index = _indexFromSkillId(skillId);
    final shape = assignmentSpecs[index].shape;
    return switch (shape) {
      _GeneratedAutomationAssignmentShape.nonAutomatedTarget =>
        makeGeneratedSkill(id: skillId, skillType: targetSkillType),
      _GeneratedAutomationAssignmentShape.automatedMissingConfig => null,
      _GeneratedAutomationAssignmentShape.automatedWrongConfigType =>
        testInferenceProvider(id: 'generated-provider-$index'),
      _GeneratedAutomationAssignmentShape.automatedMismatchedSkill ||
      _GeneratedAutomationAssignmentShape.automatedMatchingSkill =>
        makeGeneratedSkill(id: skillId, skillType: skillTypeFor(skillId)),
    };
  }

  int _indexFromSkillId(String skillId) {
    final parts = skillId.split('-');
    return int.parse(parts[2]);
  }

  @override
  String toString() {
    return '_GeneratedAutomationServiceScenario('
        'operation: $operation, '
        'profileMissing: $profileMissing, '
        'modelSlotPresent: $modelSlotPresent, '
        'assignmentSpecs: $assignmentSpecs)';
  }
}

extension _AnyGeneratedAutomationServiceScenario on glados.Any {
  glados.Generator<_GeneratedAutomationOperation> get automationOperation =>
      glados.AnyUtils(this).choose(_GeneratedAutomationOperation.values);

  glados.Generator<_GeneratedAutomationAssignmentShape>
  get automationAssignmentShape =>
      glados.AnyUtils(this).choose(_GeneratedAutomationAssignmentShape.values);

  glados.Generator<_GeneratedAutomationAssignmentSpec>
  get automationAssignmentSpec => glados.CombinableAny(this).combine2(
    automationAssignmentShape,
    glados.IntAnys(this).intInRange(0, 1000),
    (
      _GeneratedAutomationAssignmentShape shape,
      int seed,
    ) => _GeneratedAutomationAssignmentSpec(shape: shape, seed: seed),
  );

  glados.Generator<_GeneratedAutomationServiceScenario>
  get automationServiceScenario => glados.CombinableAny(this).combine4(
    automationOperation,
    glados.AnyUtils(this).choose([false, true]),
    glados.AnyUtils(this).choose([false, true]),
    glados.ListAnys(
      this,
    ).listWithLengthInRange(0, 6, automationAssignmentSpec),
    (
      _GeneratedAutomationOperation operation,
      bool profileMissing,
      bool modelSlotPresent,
      List<_GeneratedAutomationAssignmentSpec> assignmentSpecs,
    ) => _GeneratedAutomationServiceScenario(
      operation: operation,
      profileMissing: profileMissing,
      modelSlotPresent: modelSlotPresent,
      assignmentSpecs: assignmentSpecs,
    ),
  );
}

void main() {
  late MockProfileAutomationResolver mockResolver;
  late MockAiConfigRepository mockAiConfig;
  late ProfileAutomationService service;
  // The fallback ranker demotes MLX Audio rows on non-macOS so iOS / Android /
  // Linux / Windows never route mobile audio to the local MLX bridge that
  // ships only on macOS. Force the flag on for the existing suite (which
  // exercises the macOS ranking) and restore it for each test. A dedicated
  // test below pins the non-macOS demotion behaviour.
  late bool originalIsMacOS;

  setUp(() {
    originalIsMacOS = platform.isMacOS;
    platform.isMacOS = true;
    mockResolver = MockProfileAutomationResolver();
    mockAiConfig = MockAiConfigRepository();
    service = ProfileAutomationService(
      resolver: mockResolver,
      aiConfigRepository: mockAiConfig,
    );
    when(
      () => mockAiConfig.getConfigsByType(AiConfigType.model),
    ).thenAnswer((_) async => const <AiConfig>[]);
  });

  tearDown(() {
    platform.isMacOS = originalIsMacOS;
  });

  /// Creates a resolved profile with optional transcription/image providers.
  ResolvedProfile makeProfile({
    List<SkillAssignment> skillAssignments = const [],
    bool withTranscription = false,
    bool withImageRecognition = false,
    bool withImageGeneration = false,
  }) {
    return ResolvedProfile(
      thinkingModelId: 'models/gemini-3-flash-preview',
      thinkingProvider: testInferenceProvider(),
      transcriptionModelId: withTranscription ? 'whisper-1' : null,
      transcriptionProvider: withTranscription
          ? testInferenceProvider(id: 'p-audio')
          : null,
      imageRecognitionModelId: withImageRecognition ? 'vision-model' : null,
      imageRecognitionProvider: withImageRecognition
          ? testInferenceProvider(id: 'p-vision')
          : null,
      imageGenerationModelId: withImageGeneration ? 'image-gen' : null,
      imageGenerationProvider: withImageGeneration
          ? testInferenceProvider(id: 'p-image')
          : null,
      skillAssignments: skillAssignments,
    );
  }

  /// Creates a test skill config with type-appropriate modalities and
  /// instructions.
  AiConfigSkill makeSkill({
    String id = 'skill-001',
    String name = 'Test Skill',
    SkillType skillType = SkillType.transcription,
  }) {
    final (modalities, sysInstr, userInstr) = switch (skillType) {
      SkillType.transcription => (
        const [Modality.audio],
        'Transcribe the audio.',
        'Audio attached.',
      ),
      SkillType.imageAnalysis => (
        const [Modality.image],
        'Analyze the image.',
        'Image attached.',
      ),
      SkillType.imageGeneration => (
        const <Modality>[],
        'Generate an image.',
        'Generate based on description.',
      ),
      SkillType.promptGeneration => (
        const [Modality.audio],
        'Generate a prompt from audio.',
        'Audio attached.',
      ),
      SkillType.imagePromptGeneration => (
        const [Modality.audio],
        'Generate an image prompt from audio.',
        'Audio attached.',
      ),
    };

    return AiConfig.skill(
          id: id,
          name: name,
          skillType: skillType,
          requiredInputModalities: modalities,
          systemInstructions: sysInstr,
          userInstructions: userInstr,
          createdAt: DateTime(2024),
        )
        as AiConfigSkill;
  }

  AiConfigInferenceProvider makeProvider({
    String id = 'provider-mlx',
    String name = 'MLX Audio',
    InferenceProviderType type = InferenceProviderType.mlxAudio,
    String apiKey = '',
  }) {
    return AiConfig.inferenceProvider(
          id: id,
          name: name,
          baseUrl: '',
          inferenceProviderType: type,
          apiKey: apiKey,
          createdAt: DateTime(2024, 3, 15),
        )
        as AiConfigInferenceProvider;
  }

  AiConfigModel makeModel({
    String id = 'model-qwen',
    String name = 'Qwen3 ASR 1.7B (MLX 8-bit)',
    String providerModelId = mlxAudioQwenAsr17B8BitModelId,
    String providerId = 'provider-mlx',
    List<Modality> inputModalities = const [Modality.audio, Modality.text],
    List<Modality> outputModalities = const [Modality.text],
  }) {
    return AiConfig.model(
          id: id,
          name: name,
          providerModelId: providerModelId,
          inferenceProviderId: providerId,
          inputModalities: inputModalities,
          outputModalities: outputModalities,
          isReasoningModel: false,
          createdAt: DateTime(2024, 3, 15),
        )
        as AiConfigModel;
  }

  group('ProfileAutomationService', () {
    group('tryTranscribe', () {
      test(
        'returns handled when transcription skill with automate found',
        () async {
          const assignment = SkillAssignment(
            skillId: 'skill-transcribe',
            automate: true,
          );
          final profile = makeProfile(
            skillAssignments: [assignment],
            withTranscription: true,
          );
          final skill = makeSkill(id: 'skill-transcribe');

          when(
            () => mockResolver.resolveForTask('task-1'),
          ).thenAnswer((_) async => profile);
          when(
            () => mockAiConfig.getConfigById('skill-transcribe'),
          ).thenAnswer((_) async => skill);

          final result = await service.tryTranscribe(taskId: 'task-1');

          expect(result.handled, isTrue);
          expect(result.resolvedProfile, equals(profile));
          expect(result.skill, equals(skill));
          expect(result.skillAssignment, equals(assignment));
        },
      );

      test(
        'returns not-handled when user opted out of speech recognition',
        () async {
          final result = await service.tryTranscribe(
            taskId: 'task-1',
            enableSpeechRecognition: false,
          );

          expect(result.handled, isFalse);
          verifyNever(() => mockResolver.resolveForTask(any()));
          verifyNever(
            () => mockAiConfig.getConfigsByType(AiConfigType.model),
          );
        },
      );

      test('proceeds when enableSpeechRecognition is null '
          '(profile-driven default)', () async {
        const assignment = SkillAssignment(
          skillId: 'skill-transcribe',
          automate: true,
        );
        final profile = makeProfile(
          skillAssignments: [assignment],
          withTranscription: true,
        );
        final skill = makeSkill(id: 'skill-transcribe');

        when(
          () => mockResolver.resolveForTask('task-1'),
        ).thenAnswer((_) async => profile);
        when(
          () => mockAiConfig.getConfigById('skill-transcribe'),
        ).thenAnswer((_) async => skill);

        final result = await service.tryTranscribe(
          taskId: 'task-1',
        );

        expect(result.handled, isTrue);
      });

      test('returns not-handled when no profile resolved', () async {
        when(
          () => mockResolver.resolveForTask('task-1'),
        ).thenAnswer((_) async => null);

        final result = await service.tryTranscribe(taskId: 'task-1');

        expect(result.handled, isFalse);
      });

      test(
        'falls back to the configured recommended MLX speech model when no '
        'profile handles transcription',
        () async {
          final provider = makeProvider();
          final olderQwen = makeModel(
            id: 'model-qwen-small',
            name: 'Qwen3 ASR 0.6B (MLX 8-bit)',
            providerModelId: mlxAudioQwenAsrModelId,
          );
          final recommendedQwen = makeModel();

          when(
            () => mockResolver.resolveForTask('task-1'),
          ).thenAnswer((_) async => null);
          when(
            () => mockAiConfig.getConfigsByType(AiConfigType.model),
          ).thenAnswer((_) async => [olderQwen, recommendedQwen]);
          when(
            () => mockAiConfig.getConfigById('provider-mlx'),
          ).thenAnswer((_) async => provider);

          final result = await service.tryTranscribe(taskId: 'task-1');

          expect(result.handled, isTrue);
          expect(result.skill!.id, skillTranscribeContextId);
          expect(result.skillAssignment!.skillId, skillTranscribeContextId);
          expect(
            result.resolvedProfile!.transcriptionModelId,
            mlxAudioQwenAsr17B8BitModelId,
          );
          expect(result.resolvedProfile!.transcriptionProvider, provider);
        },
      );

      test(
        'does not fall back to cloud transcription providers with no API key',
        () async {
          final provider = makeProvider(
            id: 'provider-openai',
            name: 'OpenAI',
            type: InferenceProviderType.openAi,
          );
          final model = makeModel(
            id: 'model-whisper',
            name: 'Whisper',
            providerModelId: 'whisper-1',
            providerId: provider.id,
          );

          when(
            () => mockResolver.resolveForTask('task-1'),
          ).thenAnswer((_) async => null);
          when(
            () => mockAiConfig.getConfigsByType(AiConfigType.model),
          ).thenAnswer((_) async => [model]);
          when(
            () => mockAiConfig.getConfigById(provider.id),
          ).thenAnswer((_) async => provider);

          final result = await service.tryTranscribe(taskId: 'task-1');

          expect(result.handled, isFalse);
        },
      );

      test(
        'ranks generic MLX speech models ahead of cloud transcription '
        'fallbacks',
        () async {
          final providers = [
            makeProvider(
              id: 'provider-openai',
              type: InferenceProviderType.openAi,
              apiKey: 'sk-openai',
            ),
            makeProvider(
              id: 'provider-whisper',
              type: InferenceProviderType.whisper,
              apiKey: 'sk-whisper',
            ),
            makeProvider(
              id: 'provider-voxtral',
              type: InferenceProviderType.voxtral,
              apiKey: 'sk-voxtral',
            ),
            makeProvider(
              id: 'provider-mistral',
              type: InferenceProviderType.mistral,
              apiKey: 'sk-mistral',
            ),
            makeProvider(
              id: 'provider-ollama',
              type: InferenceProviderType.ollama,
            ),
            makeProvider(),
          ];
          final models = [
            makeModel(
              id: 'model-openai',
              name: 'OpenAI Whisper',
              providerModelId: 'whisper-1',
              providerId: 'provider-openai',
            ),
            makeModel(
              id: 'model-whisper',
              name: 'Whisper Provider',
              providerModelId: 'whisper-large-v3',
              providerId: 'provider-whisper',
            ),
            makeModel(
              id: 'model-voxtral',
              name: 'Voxtral Cloud',
              providerModelId: 'mistralai/Voxtral-Mini-3B-2507',
              providerId: 'provider-voxtral',
            ),
            makeModel(
              id: 'model-mistral',
              name: 'Mistral Voxtral',
              providerModelId: 'voxtral-mini-latest',
              providerId: 'provider-mistral',
            ),
            makeModel(
              id: 'model-ollama',
              name: 'Other Local Audio',
              providerModelId: 'local-audio-model',
              providerId: 'provider-ollama',
            ),
            makeModel(
              id: 'model-mlx',
              name: 'Parakeet MLX',
              providerModelId: mlxAudioParakeetModelId,
            ),
          ];

          when(
            () => mockResolver.resolveForTask('task-1'),
          ).thenAnswer((_) async => null);
          when(
            () => mockAiConfig.getConfigsByType(AiConfigType.model),
          ).thenAnswer((_) async => models);
          for (final provider in providers) {
            when(
              () => mockAiConfig.getConfigById(provider.id),
            ).thenAnswer((_) async => provider);
          }

          final result = await service.tryTranscribe(taskId: 'task-1');

          expect(result.handled, isTrue);
          expect(
            result.resolvedProfile!.transcriptionModelId,
            mlxAudioParakeetModelId,
          );
          expect(
            result
                .resolvedProfile!
                .transcriptionProvider!
                .inferenceProviderType,
            InferenceProviderType.mlxAudio,
          );
        },
      );

      test(
        'demotes MLX Audio rows on non-macOS so cloud STT wins direct fallback',
        () async {
          platform.isMacOS = false;
          final providers = [
            makeProvider(),
            makeProvider(
              id: 'provider-openai',
              type: InferenceProviderType.openAi,
              apiKey: 'sk-test',
            ),
          ];
          final models = [
            makeModel(),
            makeModel(
              id: 'model-openai',
              name: 'OpenAI Whisper',
              providerModelId: 'whisper-1',
              providerId: 'provider-openai',
            ),
          ];

          when(
            () => mockResolver.resolveForTask('task-1'),
          ).thenAnswer((_) async => null);
          when(
            () => mockAiConfig.getConfigsByType(AiConfigType.model),
          ).thenAnswer((_) async => models);
          for (final provider in providers) {
            when(
              () => mockAiConfig.getConfigById(provider.id),
            ).thenAnswer((_) async => provider);
          }

          final result = await service.tryTranscribe(taskId: 'task-1');

          expect(result.handled, isTrue);
          expect(
            result
                .resolvedProfile!
                .transcriptionProvider!
                .inferenceProviderType,
            InferenceProviderType.openAi,
            reason: 'On non-macOS the cloud STT must win over the MLX row.',
          );
        },
      );

      test(
        'sorts same-rank direct transcription fallbacks by model name',
        () async {
          final provider = makeProvider();
          final betaModel = makeModel(
            id: 'model-beta',
            name: 'Beta MLX model',
            providerModelId: mlxAudioParakeetModelId,
          );
          final alphaModel = makeModel(
            id: 'model-alpha',
            name: 'Alpha MLX model',
            providerModelId: mlxAudioVoxtralRealtime4BitModelId,
          );

          when(
            () => mockResolver.resolveForTask('task-1'),
          ).thenAnswer((_) async => null);
          when(
            () => mockAiConfig.getConfigsByType(AiConfigType.model),
          ).thenAnswer((_) async => [betaModel, alphaModel]);
          when(
            () => mockAiConfig.getConfigById(provider.id),
          ).thenAnswer((_) async => provider);

          final result = await service.tryTranscribe(taskId: 'task-1');

          expect(result.handled, isTrue);
          expect(
            result.resolvedProfile!.transcriptionModelId,
            mlxAudioVoxtralRealtime4BitModelId,
          );
        },
      );

      test('returns not-handled when no matching skill type', () async {
        const assignment = SkillAssignment(
          skillId: 'skill-image',
          automate: true,
        );
        final profile = makeProfile(
          skillAssignments: [assignment],
          withTranscription: true,
        );
        final imageSkill = makeSkill(
          id: 'skill-image',
          skillType: SkillType.imageAnalysis,
        );

        when(
          () => mockResolver.resolveForTask('task-1'),
        ).thenAnswer((_) async => profile);
        when(
          () => mockAiConfig.getConfigById('skill-image'),
        ).thenAnswer((_) async => imageSkill);

        final result = await service.tryTranscribe(taskId: 'task-1');

        expect(result.handled, isFalse);
      });

      test('skips skill assignments with automate: false', () async {
        const assignment = SkillAssignment(
          skillId: 'skill-transcribe',
          // automate defaults to false
        );
        final profile = makeProfile(
          skillAssignments: [assignment],
          withTranscription: true,
        );

        when(
          () => mockResolver.resolveForTask('task-1'),
        ).thenAnswer((_) async => profile);

        final result = await service.tryTranscribe(taskId: 'task-1');

        expect(result.handled, isFalse);
        // Should not even look up the skill config.
        verifyNever(() => mockAiConfig.getConfigById(any()));
      });

      test('skips skill when model slot not populated', () async {
        const assignment = SkillAssignment(
          skillId: 'skill-transcribe',
          automate: true,
        );
        // No transcription provider on profile.
        final profile = makeProfile(
          skillAssignments: [assignment],
        );
        final skill = makeSkill(id: 'skill-transcribe');

        when(
          () => mockResolver.resolveForTask('task-1'),
        ).thenAnswer((_) async => profile);
        when(
          () => mockAiConfig.getConfigById('skill-transcribe'),
        ).thenAnswer((_) async => skill);

        final result = await service.tryTranscribe(taskId: 'task-1');

        expect(result.handled, isFalse);
      });

      test('skips skill when config not found', () async {
        const assignment = SkillAssignment(
          skillId: 'skill-missing',
          automate: true,
        );
        final profile = makeProfile(
          skillAssignments: [assignment],
          withTranscription: true,
        );

        when(
          () => mockResolver.resolveForTask('task-1'),
        ).thenAnswer((_) async => profile);
        when(
          () => mockAiConfig.getConfigById('skill-missing'),
        ).thenAnswer((_) async => null);

        final result = await service.tryTranscribe(taskId: 'task-1');

        expect(result.handled, isFalse);
      });
    });

    group('tryAnalyzeImage', () {
      test(
        'returns handled when image analysis skill with automate found',
        () async {
          const assignment = SkillAssignment(
            skillId: 'skill-vision',
            automate: true,
          );
          final profile = makeProfile(
            skillAssignments: [assignment],
            withImageRecognition: true,
          );
          final skill = makeSkill(
            id: 'skill-vision',
            name: 'Image Analysis',
            skillType: SkillType.imageAnalysis,
          );

          when(
            () => mockResolver.resolveForTask('task-1'),
          ).thenAnswer((_) async => profile);
          when(
            () => mockAiConfig.getConfigById('skill-vision'),
          ).thenAnswer((_) async => skill);

          final result = await service.tryAnalyzeImage(taskId: 'task-1');

          expect(result.handled, isTrue);
          expect(result.skill!.skillType, SkillType.imageAnalysis);
        },
      );

      test('returns not-handled when no image recognition provider', () async {
        const assignment = SkillAssignment(
          skillId: 'skill-vision',
          automate: true,
        );
        // No image recognition provider.
        final profile = makeProfile(
          skillAssignments: [assignment],
        );
        final skill = makeSkill(
          id: 'skill-vision',
          skillType: SkillType.imageAnalysis,
        );

        when(
          () => mockResolver.resolveForTask('task-1'),
        ).thenAnswer((_) async => profile);
        when(
          () => mockAiConfig.getConfigById('skill-vision'),
        ).thenAnswer((_) async => skill);

        final result = await service.tryAnalyzeImage(taskId: 'task-1');

        expect(result.handled, isFalse);
      });
    });

    group('AutomationResult', () {
      test('notHandled has correct defaults', () {
        const result = AutomationResult.notHandled;

        expect(result.handled, isFalse);
        expect(result.resolvedProfile, isNull);
        expect(result.skill, isNull);
        expect(result.skillAssignment, isNull);
      });

      test(
        'uses first matching skill when multiple assignments exist',
        () async {
          const assignments = [
            // ignore: avoid_redundant_argument_values
            SkillAssignment(skillId: 'skill-non-auto', automate: false),
            SkillAssignment(skillId: 'skill-image', automate: true),
            SkillAssignment(skillId: 'skill-transcribe', automate: true),
          ];
          final profile = makeProfile(
            skillAssignments: assignments,
            withTranscription: true,
            withImageRecognition: true,
          );
          final transcribeSkill = makeSkill(
            id: 'skill-transcribe',
            // ignore: avoid_redundant_argument_values
            skillType: SkillType.transcription,
          );
          // skill-image is an image analysis skill, not transcription.
          final imageSkill = makeSkill(
            id: 'skill-image',
            skillType: SkillType.imageAnalysis,
          );

          when(
            () => mockResolver.resolveForTask('task-1'),
          ).thenAnswer((_) async => profile);
          when(
            () => mockAiConfig.getConfigById('skill-image'),
          ).thenAnswer((_) async => imageSkill);
          when(
            () => mockAiConfig.getConfigById('skill-transcribe'),
          ).thenAnswer((_) async => transcribeSkill);

          final result = await service.tryTranscribe(taskId: 'task-1');

          expect(result.handled, isTrue);
          expect(result.skill!.id, 'skill-transcribe');
          expect(result.skillAssignment!.skillId, 'skill-transcribe');
        },
      );
    });

    group('ambiguous profiles', () {
      test(
        'returns not-handled when multiple automated skills of same type',
        () async {
          const assignments = [
            SkillAssignment(skillId: 'skill-t1', automate: true),
            SkillAssignment(skillId: 'skill-t2', automate: true),
          ];
          final profile = makeProfile(
            skillAssignments: assignments,
            withTranscription: true,
          );
          final skill1 = makeSkill(id: 'skill-t1');
          final skill2 = makeSkill(id: 'skill-t2');

          when(
            () => mockResolver.resolveForTask('task-1'),
          ).thenAnswer((_) async => profile);
          when(
            () => mockAiConfig.getConfigById('skill-t1'),
          ).thenAnswer((_) async => skill1);
          when(
            () => mockAiConfig.getConfigById('skill-t2'),
          ).thenAnswer((_) async => skill2);

          final result = await service.tryTranscribe(taskId: 'task-1');

          expect(result.handled, isFalse);
        },
      );

      test(
        'returns handled when only one of multiple skills matches type',
        () async {
          const assignments = [
            SkillAssignment(skillId: 'skill-transcribe', automate: true),
            SkillAssignment(skillId: 'skill-image', automate: true),
          ];
          final profile = makeProfile(
            skillAssignments: assignments,
            withTranscription: true,
            withImageRecognition: true,
          );
          final transcribeSkill = makeSkill(id: 'skill-transcribe');
          final imageSkill = makeSkill(
            id: 'skill-image',
            skillType: SkillType.imageAnalysis,
          );

          when(
            () => mockResolver.resolveForTask('task-1'),
          ).thenAnswer((_) async => profile);
          when(
            () => mockAiConfig.getConfigById('skill-transcribe'),
          ).thenAnswer((_) async => transcribeSkill);
          when(
            () => mockAiConfig.getConfigById('skill-image'),
          ).thenAnswer((_) async => imageSkill);

          final result = await service.tryTranscribe(taskId: 'task-1');

          expect(result.handled, isTrue);
          expect(result.skill!.id, 'skill-transcribe');
        },
      );
    });

    glados.Glados(
      glados.any.automationServiceScenario,
      glados.ExploreConfig(numRuns: 180),
    ).test(
      'matches generated automation assignment filtering semantics',
      (scenario) async {
        final localResolver = MockProfileAutomationResolver();
        final localAiConfig = MockAiConfigRepository();
        final localService = ProfileAutomationService(
          resolver: localResolver,
          aiConfigRepository: localAiConfig,
        );
        final actualLookupIds = <String>[];
        var resolverCalls = 0;

        AiConfigSkill makeGeneratedSkill({
          required String id,
          required SkillType skillType,
        }) {
          return makeSkill(
            id: id,
            name: 'Generated $id',
            skillType: skillType,
          );
        }

        final profile = makeProfile(
          skillAssignments: scenario.assignments,
          withTranscription:
              scenario.targetSkillType == SkillType.transcription &&
              scenario.modelSlotPresent,
          withImageRecognition:
              scenario.targetSkillType == SkillType.imageAnalysis &&
              scenario.modelSlotPresent,
        );

        when(
          () => localResolver.resolveForTask('generated-task'),
        ).thenAnswer((_) async {
          resolverCalls++;
          return scenario.profileMissing ? null : profile;
        });
        when(
          () => localAiConfig.getConfigsByType(AiConfigType.model),
        ).thenAnswer((_) async => const <AiConfig>[]);
        when(
          () => localAiConfig.getConfigById(any()),
        ).thenAnswer((invocation) async {
          final skillId = invocation.positionalArguments.single as String;
          actualLookupIds.add(skillId);
          return scenario.configFor(skillId, makeGeneratedSkill);
        });

        final result = switch (scenario.operation) {
          _GeneratedAutomationOperation.transcribeDefault =>
            await localService.tryTranscribe(taskId: 'generated-task'),
          _GeneratedAutomationOperation.transcribeOptIn =>
            await localService.tryTranscribe(
              taskId: 'generated-task',
              enableSpeechRecognition: true,
            ),
          _GeneratedAutomationOperation.transcribeOptOut =>
            await localService.tryTranscribe(
              taskId: 'generated-task',
              enableSpeechRecognition: false,
            ),
          _GeneratedAutomationOperation.analyzeImage =>
            await localService.tryAnalyzeImage(taskId: 'generated-task'),
        };

        expect(
          resolverCalls,
          scenario.speechOptedOut ? 0 : 1,
          reason: '$scenario',
        );
        expect(
          actualLookupIds,
          scenario.expectedLookupIds,
          reason: '$scenario',
        );
        expect(result.handled, scenario.expectedHandled, reason: '$scenario');

        if (!scenario.expectedHandled) {
          expect(result.resolvedProfile, isNull, reason: '$scenario');
          expect(result.skill, isNull, reason: '$scenario');
          expect(result.skillAssignment, isNull, reason: '$scenario');
          return;
        }

        final handledIndex = scenario.handledIndex!;
        final expectedAssignment = scenario.assignments[handledIndex];
        expect(result.resolvedProfile, profile, reason: '$scenario');
        expect(result.skillAssignment, expectedAssignment, reason: '$scenario');
        expect(result.skill, isA<AiConfigSkill>(), reason: '$scenario');
        expect(result.skill!.id, expectedAssignment.skillId);
        expect(result.skill!.skillType, scenario.targetSkillType);
      },
      tags: 'glados',
    );

    group('hasAutomatedSkillType', () {
      test('returns true when skill type is available', () async {
        const assignment = SkillAssignment(
          skillId: 'skill-transcribe',
          automate: true,
        );
        final profile = makeProfile(
          skillAssignments: [assignment],
          withTranscription: true,
        );
        final skill = makeSkill(id: 'skill-transcribe');

        when(
          () => mockResolver.resolveForTask('task-1'),
        ).thenAnswer((_) async => profile);
        when(
          () => mockAiConfig.getConfigById('skill-transcribe'),
        ).thenAnswer((_) async => skill);

        final result = await service.hasAutomatedSkillType(
          taskId: 'task-1',
          skillType: SkillType.transcription,
        );

        expect(result, isTrue);
      });

      test('returns false when no profile resolved', () async {
        when(
          () => mockResolver.resolveForTask('task-1'),
        ).thenAnswer((_) async => null);

        final result = await service.hasAutomatedSkillType(
          taskId: 'task-1',
          skillType: SkillType.transcription,
        );

        expect(result, isFalse);
      });

      test(
        'returns true when direct transcription fallback is available',
        () async {
          final provider = makeProvider();
          final model = makeModel();

          when(
            () => mockResolver.resolveForTask('task-1'),
          ).thenAnswer((_) async => null);
          when(
            () => mockAiConfig.getConfigsByType(AiConfigType.model),
          ).thenAnswer((_) async => [model]);
          when(
            () => mockAiConfig.getConfigById(provider.id),
          ).thenAnswer((_) async => provider);

          final result = await service.hasAutomatedSkillType(
            taskId: 'task-1',
            skillType: SkillType.transcription,
          );

          expect(result, isTrue);
        },
      );

      test('returns false for mismatched skill type', () async {
        const assignment = SkillAssignment(
          skillId: 'skill-vision',
          automate: true,
        );
        final profile = makeProfile(
          skillAssignments: [assignment],
          withImageRecognition: true,
        );
        final skill = makeSkill(
          id: 'skill-vision',
          skillType: SkillType.imageAnalysis,
        );

        when(
          () => mockResolver.resolveForTask('task-1'),
        ).thenAnswer((_) async => profile);
        when(
          () => mockAiConfig.getConfigById('skill-vision'),
        ).thenAnswer((_) async => skill);

        final result = await service.hasAutomatedSkillType(
          taskId: 'task-1',
          skillType: SkillType.transcription,
        );

        expect(result, isFalse);
      });

      test(
        'treats prompt-generation skill types as thinking-model-backed',
        () async {
          for (final skillType in [
            SkillType.promptGeneration,
            SkillType.imagePromptGeneration,
          ]) {
            final skillId = 'skill-${skillType.name}';
            final profile = makeProfile(
              skillAssignments: [
                SkillAssignment(skillId: skillId, automate: true),
              ],
            );
            final skill = makeSkill(id: skillId, skillType: skillType);

            when(
              () => mockResolver.resolveForTask('task-$skillId'),
            ).thenAnswer((_) async => profile);
            when(
              () => mockAiConfig.getConfigById(skillId),
            ).thenAnswer((_) async => skill);

            final result = await service.hasAutomatedSkillType(
              taskId: 'task-$skillId',
              skillType: skillType,
            );

            expect(result, isTrue, reason: skillType.name);
          }
        },
      );

      test(
        'requires an image-generation provider for image-generation skills',
        () async {
          const assignment = SkillAssignment(
            skillId: 'skill-image-gen',
            automate: true,
          );
          final skill = makeSkill(
            id: 'skill-image-gen',
            skillType: SkillType.imageGeneration,
          );

          when(
            () => mockResolver.resolveForTask('task-image-gen-missing'),
          ).thenAnswer(
            (_) async => makeProfile(skillAssignments: [assignment]),
          );
          when(
            () => mockResolver.resolveForTask('task-image-gen-present'),
          ).thenAnswer(
            (_) async => makeProfile(
              skillAssignments: [assignment],
              withImageGeneration: true,
            ),
          );
          when(
            () => mockAiConfig.getConfigById('skill-image-gen'),
          ).thenAnswer((_) async => skill);

          final missingResult = await service.hasAutomatedSkillType(
            taskId: 'task-image-gen-missing',
            skillType: SkillType.imageGeneration,
          );
          final presentResult = await service.hasAutomatedSkillType(
            taskId: 'task-image-gen-present',
            skillType: SkillType.imageGeneration,
          );

          expect(missingResult, isFalse);
          expect(presentResult, isTrue);
        },
      );
    });
  });
}
