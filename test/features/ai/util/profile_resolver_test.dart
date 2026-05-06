import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/skill_assignment.dart';
import 'package:lotti/features/ai/util/profile_resolver.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../agents/test_utils.dart';

enum _GeneratedProviderResolutionShape {
  cloudWithKey,
  localWithoutKey,
  missingModel,
  missingProvider,
  cloudWithoutKey,
}

class _GeneratedProfileSlotScenario {
  const _GeneratedProfileSlotScenario({
    required this.thinkingShape,
    required this.optionalMask,
    required this.resolvableOptionalMask,
  });

  final _GeneratedProviderResolutionShape thinkingShape;
  final int optionalMask;
  final int resolvableOptionalMask;

  bool get thinkingResolves =>
      thinkingShape == _GeneratedProviderResolutionShape.cloudWithKey ||
      thinkingShape == _GeneratedProviderResolutionShape.localWithoutKey;

  bool get hasHighEnd => optionalMask & 1 != 0;
  bool get hasVision => optionalMask & 2 != 0;
  bool get hasTranscription => optionalMask & 4 != 0;
  bool get hasImageGeneration => optionalMask & 8 != 0;

  bool get highEndResolves => hasHighEnd && resolvableOptionalMask & 1 != 0;
  bool get visionResolves => hasVision && resolvableOptionalMask & 2 != 0;
  bool get transcriptionResolves =>
      hasTranscription && resolvableOptionalMask & 4 != 0;
  bool get imageGenerationResolves =>
      hasImageGeneration && resolvableOptionalMask & 8 != 0;

  AiConfigInferenceProfile profile() {
    return testInferenceProfile(
      id: 'generated-profile',
      thinkingModelId: 'generated-thinking',
      thinkingHighEndModelId: hasHighEnd ? 'generated-high-end' : null,
      imageRecognitionModelId: hasVision ? 'generated-vision' : null,
      transcriptionModelId: hasTranscription ? 'generated-transcription' : null,
      imageGenerationModelId: hasImageGeneration
          ? 'generated-image-generation'
          : null,
      skillAssignments: const [
        SkillAssignment(skillId: 'generated-skill', automate: true),
      ],
    );
  }

  List<AiConfig> models() {
    final models = <AiConfig>[];
    if (thinkingShape != _GeneratedProviderResolutionShape.missingModel) {
      models.add(
        testAiModel(
          id: 'model-thinking',
          providerModelId: 'generated-thinking',
          inferenceProviderId: 'provider-thinking',
        ),
      );
    }
    if (highEndResolves) {
      models.add(_model('model-high-end', 'generated-high-end'));
    }
    if (visionResolves) {
      models.add(_model('model-vision', 'generated-vision'));
    }
    if (transcriptionResolves) {
      models.add(_model('model-transcription', 'generated-transcription'));
    }
    if (imageGenerationResolves) {
      models.add(
        _model('model-image-generation', 'generated-image-generation'),
      );
    }
    return models;
  }

  AiConfigModel _model(String id, String providerModelId) {
    return testAiModel(
      id: id,
      providerModelId: providerModelId,
      inferenceProviderId: 'provider-$id',
    );
  }

  AiConfig? configById(String id) {
    if (id == 'generated-profile') return profile();
    if (id == 'provider-thinking') {
      return switch (thinkingShape) {
        _GeneratedProviderResolutionShape.cloudWithKey => testInferenceProvider(
          id: id,
          apiKey: 'key',
        ),
        _GeneratedProviderResolutionShape.localWithoutKey =>
          testLocalInferenceProvider(id: id),
        _GeneratedProviderResolutionShape.cloudWithoutKey =>
          testInferenceProvider(id: id, apiKey: ''),
        _GeneratedProviderResolutionShape.missingProvider => null,
        _GeneratedProviderResolutionShape.missingModel => throw StateError(
          'Provider should not be resolved without model',
        ),
      };
    }
    if (id.startsWith('provider-model-')) {
      return testInferenceProvider(id: id, apiKey: 'key');
    }
    return null;
  }

  @override
  String toString() {
    return '_GeneratedProfileSlotScenario('
        'thinkingShape: $thinkingShape, '
        'optionalMask: $optionalMask, '
        'resolvableOptionalMask: $resolvableOptionalMask)';
  }
}

extension _AnyGeneratedProfileSlotScenario on glados.Any {
  glados.Generator<_GeneratedProviderResolutionShape>
  get providerResolutionShape =>
      glados.AnyUtils(this).choose(_GeneratedProviderResolutionShape.values);

  glados.Generator<_GeneratedProfileSlotScenario> get profileSlotScenario =>
      glados.CombinableAny(this).combine3(
        providerResolutionShape,
        glados.IntAnys(this).intInRange(0, 15),
        glados.IntAnys(this).intInRange(0, 15),
        (
          _GeneratedProviderResolutionShape thinkingShape,
          int optionalMask,
          int resolvableOptionalMask,
        ) => _GeneratedProfileSlotScenario(
          thinkingShape: thinkingShape,
          optionalMask: optionalMask,
          resolvableOptionalMask: resolvableOptionalMask,
        ),
      );
}

void main() {
  late MockAiConfigRepository mockAiConfig;
  late ProfileResolver resolver;

  setUpAll(() {
    registerFallbackValue(AiConfigType.model);
  });

  setUp(() {
    mockAiConfig = MockAiConfigRepository();
    resolver = ProfileResolver(aiConfigRepository: mockAiConfig);
  });

  /// Stubs model lookup and provider resolution for the given [modelId].
  void stubModelResolution({
    String modelId = 'models/gemini-3-flash-preview',
    String providerId = 'provider-1',
    String apiKey = 'test-key',
  }) {
    when(() => mockAiConfig.getConfigsByType(AiConfigType.model)).thenAnswer(
      (_) async => [
        testAiModel(
          providerModelId: modelId,
          inferenceProviderId: providerId,
        ),
      ],
    );
    when(() => mockAiConfig.getConfigById(providerId)).thenAnswer(
      (_) async => testInferenceProvider(id: providerId, apiKey: apiKey),
    );
  }

  /// Stubs a profile lookup by ID.
  void stubProfile(AiConfigInferenceProfile profile) {
    when(
      () => mockAiConfig.getConfigById(profile.id),
    ).thenAnswer((_) async => profile);
  }

  group('ProfileResolver', () {
    test('resolves profile from agent config profileId', () async {
      final profile = testInferenceProfile(id: 'profile-agent');
      stubProfile(profile);
      stubModelResolution();

      final result = await resolver.resolve(
        agentConfig: const AgentConfig(profileId: 'profile-agent'),
        template: makeTestTemplate(profileId: 'profile-template'),
        version: makeTestTemplateVersion(profileId: 'profile-version'),
      );

      expect(result, isNotNull);
      expect(result!.thinkingModelId, 'models/gemini-3-flash-preview');
      // Verify it used the agent-level profileId, not the version or template.
      verify(() => mockAiConfig.getConfigById('profile-agent')).called(1);
    });

    test('falls back to version profileId when agent has none', () async {
      final profile = testInferenceProfile(id: 'profile-version');
      stubProfile(profile);
      stubModelResolution();

      final result = await resolver.resolve(
        agentConfig: const AgentConfig(),
        template: makeTestTemplate(profileId: 'profile-template'),
        version: makeTestTemplateVersion(profileId: 'profile-version'),
      );

      expect(result, isNotNull);
      verify(() => mockAiConfig.getConfigById('profile-version')).called(1);
    });

    test('falls back to template profileId when version has none', () async {
      final profile = testInferenceProfile(id: 'profile-template');
      stubProfile(profile);
      stubModelResolution();

      final result = await resolver.resolve(
        agentConfig: const AgentConfig(),
        template: makeTestTemplate(profileId: 'profile-template'),
        version: makeTestTemplateVersion(),
      );

      expect(result, isNotNull);
      verify(() => mockAiConfig.getConfigById('profile-template')).called(1);
    });

    test('uses legacy modelId fallback when no profileId anywhere', () async {
      stubModelResolution();

      final result = await resolver.resolve(
        agentConfig: const AgentConfig(),
        template: makeTestTemplate(),
        version: makeTestTemplateVersion(),
      );

      expect(result, isNotNull);
      expect(result!.thinkingModelId, 'models/gemini-3-flash-preview');
      // No profile lookup should have been made.
      verifyNever(() => mockAiConfig.getConfigById('profile-agent'));
    });

    test('falls back to legacy when profile not found', () async {
      when(
        () => mockAiConfig.getConfigById('profile-missing'),
      ).thenAnswer((_) async => null);
      stubModelResolution();

      final result = await resolver.resolve(
        agentConfig: const AgentConfig(profileId: 'profile-missing'),
        template: makeTestTemplate(),
        version: makeTestTemplateVersion(),
      );

      expect(result, isNotNull);
      expect(result!.thinkingModelId, 'models/gemini-3-flash-preview');
    });

    test('returns null when thinking model cannot be resolved', () async {
      final profile = testInferenceProfile(
        id: 'profile-bad',
        thinkingModelId: 'nonexistent-model',
      );
      stubProfile(profile);
      when(
        () => mockAiConfig.getConfigsByType(AiConfigType.model),
      ).thenAnswer((_) async => []);

      final result = await resolver.resolve(
        agentConfig: const AgentConfig(profileId: 'profile-bad'),
        template: makeTestTemplate(),
        version: makeTestTemplateVersion(),
      );

      expect(result, isNull);
    });

    test('resolves profile with all slots populated', () async {
      final profile = testInferenceProfile(
        id: 'profile-full',
        thinkingModelId: 'thinking-model',
        thinkingHighEndModelId: 'thinking-pro-model',
        imageRecognitionModelId: 'vision-model',
        transcriptionModelId: 'audio-model',
        imageGenerationModelId: 'image-gen-model',
      );
      stubProfile(profile);

      // Stub models and providers for each slot.
      when(() => mockAiConfig.getConfigsByType(AiConfigType.model)).thenAnswer(
        (_) async => [
          testAiModel(
            id: 'm1',
            providerModelId: 'thinking-model',
            inferenceProviderId: 'p1',
          ),
          testAiModel(
            id: 'm1-pro',
            providerModelId: 'thinking-pro-model',
            inferenceProviderId: 'p1-pro',
          ),
          testAiModel(
            id: 'm2',
            providerModelId: 'vision-model',
            inferenceProviderId: 'p2',
          ),
          testAiModel(
            id: 'm3',
            providerModelId: 'audio-model',
            inferenceProviderId: 'p3',
          ),
          testAiModel(
            id: 'm4',
            providerModelId: 'image-gen-model',
            inferenceProviderId: 'p4',
          ),
        ],
      );
      when(
        () => mockAiConfig.getConfigById('p1'),
      ).thenAnswer((_) async => testInferenceProvider(id: 'p1'));
      when(
        () => mockAiConfig.getConfigById('p1-pro'),
      ).thenAnswer((_) async => testInferenceProvider(id: 'p1-pro'));
      when(
        () => mockAiConfig.getConfigById('p2'),
      ).thenAnswer((_) async => testInferenceProvider(id: 'p2'));
      when(
        () => mockAiConfig.getConfigById('p3'),
      ).thenAnswer((_) async => testInferenceProvider(id: 'p3'));
      when(
        () => mockAiConfig.getConfigById('p4'),
      ).thenAnswer((_) async => testInferenceProvider(id: 'p4'));

      final result = await resolver.resolve(
        agentConfig: const AgentConfig(profileId: 'profile-full'),
        template: makeTestTemplate(),
        version: makeTestTemplateVersion(),
      );

      expect(result, isNotNull);
      expect(result!.thinkingModelId, 'thinking-model');
      expect(result.thinkingProvider.id, 'p1');
      expect(result.thinkingHighEndModelId, 'thinking-pro-model');
      expect(result.thinkingHighEndProvider, isNotNull);
      expect(result.thinkingHighEndProvider!.id, 'p1-pro');
      expect(result.imageRecognitionModelId, 'vision-model');
      expect(result.imageRecognitionProvider, isNotNull);
      expect(result.transcriptionModelId, 'audio-model');
      expect(result.transcriptionProvider, isNotNull);
      expect(result.imageGenerationModelId, 'image-gen-model');
      expect(result.imageGenerationProvider, isNotNull);
    });

    test('high-end thinking slot fails gracefully when not set', () async {
      final profile = testInferenceProfile(
        id: 'profile-no-highend',
        thinkingModelId: 'thinking-model',
      );
      stubProfile(profile);
      stubModelResolution(modelId: 'thinking-model');

      final result = await resolver.resolve(
        agentConfig: const AgentConfig(profileId: 'profile-no-highend'),
        template: makeTestTemplate(),
        version: makeTestTemplateVersion(),
      );

      expect(result, isNotNull);
      expect(result!.thinkingHighEndModelId, isNull);
      expect(result.thinkingHighEndProvider, isNull);
      // Fallback accessors should return regular thinking slot.
      expect(result.effectiveHighEndModelId, 'thinking-model');
    });

    test('non-thinking slots fail gracefully when model missing', () async {
      final profile = testInferenceProfile(
        id: 'profile-partial',
        thinkingModelId: 'thinking-model',
        imageRecognitionModelId: 'nonexistent-vision',
      );
      stubProfile(profile);

      when(() => mockAiConfig.getConfigsByType(AiConfigType.model)).thenAnswer(
        (_) async => [
          testAiModel(
            providerModelId: 'thinking-model',
            inferenceProviderId: 'p1',
          ),
        ],
      );
      when(
        () => mockAiConfig.getConfigById('p1'),
      ).thenAnswer((_) async => testInferenceProvider(id: 'p1'));

      final result = await resolver.resolve(
        agentConfig: const AgentConfig(profileId: 'profile-partial'),
        template: makeTestTemplate(),
        version: makeTestTemplateVersion(),
      );

      expect(result, isNotNull);
      expect(result!.thinkingModelId, 'thinking-model');
      // Vision model wasn't found, so it should be null (non-fatal).
      expect(result.imageRecognitionProvider, isNull);
    });

    test('carries skill assignments through to resolved profile', () async {
      const assignments = [
        SkillAssignment(skillId: 'skill-transcribe-001', automate: true),
        SkillAssignment(skillId: 'skill-image-analysis-001'),
      ];

      final profile = testInferenceProfile(
        id: 'profile-skills',
        skillAssignments: assignments,
      );
      stubProfile(profile);
      stubModelResolution();

      final result = await resolver.resolve(
        agentConfig: const AgentConfig(profileId: 'profile-skills'),
        template: makeTestTemplate(),
        version: makeTestTemplateVersion(),
      );

      expect(result, isNotNull);
      expect(result!.skillAssignments, hasLength(2));
      expect(result.skillAssignments[0].skillId, 'skill-transcribe-001');
      expect(result.skillAssignments[0].automate, isTrue);
      expect(result.skillAssignments[1].skillId, 'skill-image-analysis-001');
      expect(result.skillAssignments[1].automate, isFalse);
    });

    test('legacy fallback has empty skill assignments', () async {
      stubModelResolution();

      final result = await resolver.resolve(
        agentConfig: const AgentConfig(),
        template: makeTestTemplate(),
        version: makeTestTemplateVersion(),
      );

      expect(result, isNotNull);
      expect(result!.skillAssignments, isEmpty);
    });

    test('resolves local provider with empty API key', () async {
      final profile = testInferenceProfile(
        id: 'profile-local',
        thinkingModelId: 'qwen3.5:9b',
      );
      stubProfile(profile);

      when(() => mockAiConfig.getConfigsByType(AiConfigType.model)).thenAnswer(
        (_) async => [
          testAiModel(
            providerModelId: 'qwen3.5:9b',
            inferenceProviderId: 'provider-local',
          ),
        ],
      );
      when(
        () => mockAiConfig.getConfigById('provider-local'),
      ).thenAnswer((_) async => testLocalInferenceProvider());

      final result = await resolver.resolve(
        agentConfig: const AgentConfig(profileId: 'profile-local'),
        template: makeTestTemplate(),
        version: makeTestTemplateVersion(),
      );

      expect(result, isNotNull);
      expect(result!.thinkingModelId, 'qwen3.5:9b');
      expect(
        result.thinkingProvider.inferenceProviderType,
        InferenceProviderType.ollama,
      );
    });
  });

  group('resolveByProfileId', () {
    test('resolves valid profile by ID', () async {
      final profile = testInferenceProfile(id: 'direct-profile');
      stubProfile(profile);
      stubModelResolution();

      final result = await resolver.resolveByProfileId('direct-profile');

      expect(result, isNotNull);
      expect(result!.thinkingModelId, 'models/gemini-3-flash-preview');
      verify(() => mockAiConfig.getConfigById('direct-profile')).called(1);
    });

    test('returns null when profile not found', () async {
      when(
        () => mockAiConfig.getConfigById('missing-profile'),
      ).thenAnswer((_) async => null);

      final result = await resolver.resolveByProfileId('missing-profile');

      expect(result, isNull);
    });

    test('returns null when profile is wrong type', () async {
      when(
        () => mockAiConfig.getConfigById('wrong-type'),
      ).thenAnswer(
        (_) async => testAiModel(
          id: 'wrong-type',
          providerModelId: 'some-model',
          inferenceProviderId: 'p1',
        ),
      );

      final result = await resolver.resolveByProfileId('wrong-type');

      expect(result, isNull);
    });

    test('carries skill assignments through', () async {
      const assignments = [
        SkillAssignment(skillId: 'skill-1', automate: true),
      ];
      final profile = testInferenceProfile(
        id: 'profile-with-skills',
        skillAssignments: assignments,
      );
      stubProfile(profile);
      stubModelResolution();

      final result = await resolver.resolveByProfileId('profile-with-skills');

      expect(result, isNotNull);
      expect(result!.skillAssignments, hasLength(1));
      expect(result.skillAssignments[0].automate, isTrue);
    });

    glados.Glados(
      glados.any.profileSlotScenario,
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'matches generated profile slot resolution semantics',
      (scenario) async {
        when(
          () => mockAiConfig.getConfigsByType(AiConfigType.model),
        ).thenAnswer((_) async => scenario.models());
        when(
          () => mockAiConfig.getConfigById(any()),
        ).thenAnswer((invocation) async {
          final id = invocation.positionalArguments.single as String;
          return scenario.configById(id);
        });

        final result = await resolver.resolveByProfileId('generated-profile');

        if (!scenario.thinkingResolves) {
          expect(result, isNull, reason: '$scenario');
          return;
        }

        expect(result, isNotNull, reason: '$scenario');
        expect(result!.thinkingModelId, 'generated-thinking');
        expect(result.thinkingProvider.id, 'provider-thinking');
        expect(result.skillAssignments, hasLength(1));
        expect(result.skillAssignments.single.skillId, 'generated-skill');

        expect(
          result.thinkingHighEndModelId,
          scenario.highEndResolves ? 'generated-high-end' : isNull,
          reason: '$scenario',
        );
        expect(
          result.imageRecognitionModelId,
          scenario.visionResolves ? 'generated-vision' : isNull,
          reason: '$scenario',
        );
        expect(
          result.transcriptionModelId,
          scenario.transcriptionResolves ? 'generated-transcription' : isNull,
          reason: '$scenario',
        );
        expect(
          result.imageGenerationModelId,
          scenario.imageGenerationResolves
              ? 'generated-image-generation'
              : isNull,
          reason: '$scenario',
        );
      },
    );
  });
}
