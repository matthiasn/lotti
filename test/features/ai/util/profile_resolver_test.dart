import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/model/skill_assignment.dart';
import 'package:lotti/features/ai/util/profile_resolver.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../agents/test_utils.dart';
import 'profile_resolver_test_helpers.dart';

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
    test('typed disabled setup blocks every legacy fallback', () async {
      final result = await resolver.resolveDetailed(
        agentConfig: const AgentConfig(
          profileId: 'legacy-agent-profile',
          inferenceSetup: AgentInferenceSetup(
            mode: AgentInferenceSetupMode.disabled,
            origin: AgentInferenceSetupOrigin.user,
          ),
        ),
        template: makeTestTemplate(profileId: 'legacy-template-profile'),
        version: makeTestTemplateVersion(profileId: 'legacy-version-profile'),
      );

      expect(result.status, AgentSetupResolutionStatus.disabled);
      expect(result.setupOrigin, AgentInferenceSetupOrigin.user);
      expect(result.profile, isNull);
      expect(result.canRun, isFalse);
      verifyNever(() => mockAiConfig.getConfigById(any()));
    });

    test(
      'typed direct model resolves by config id without a profile',
      () async {
        final model = testAiModel(
          id: 'model-config-id',
          providerModelId: 'provider-model-id',
        );
        when(
          () => mockAiConfig.getConfigById('model-config-id'),
        ).thenAnswer((_) async => model);
        when(
          () => mockAiConfig.getConfigById('provider-1'),
        ).thenAnswer((_) async => testInferenceProvider());

        final result = await resolver.resolveDetailed(
          agentConfig: const AgentConfig(
            inferenceSetup: AgentInferenceSetup(
              mode: AgentInferenceSetupMode.configured,
              origin: AgentInferenceSetupOrigin.user,
              thinkingModelOverrideId: 'model-config-id',
            ),
          ),
          template: makeTestTemplate(),
          version: makeTestTemplateVersion(),
        );

        expect(result.status, AgentSetupResolutionStatus.resolved);
        expect(result.source, AgentSetupResolutionSource.directModel);
        expect(result.profile?.thinkingModelId, 'provider-model-id');
        expect(result.routeFingerprint?.modelConfigId, 'model-config-id');
        expect(result.canRun, isTrue);
      },
    );

    test('direct model reports a missing selected base profile', () async {
      final model = testAiModel(
        id: 'model-config-id',
        providerModelId: 'provider-model-id',
      );
      when(
        () => mockAiConfig.getConfigById('missing-profile'),
      ).thenAnswer((_) async => null);
      when(
        () => mockAiConfig.getConfigById('model-config-id'),
      ).thenAnswer((_) async => model);
      when(
        () => mockAiConfig.getConfigById('provider-1'),
      ).thenAnswer((_) async => testInferenceProvider());

      final result = await resolver.resolveDetailed(
        agentConfig: const AgentConfig(
          inferenceSetup: AgentInferenceSetup(
            mode: AgentInferenceSetupMode.configured,
            origin: AgentInferenceSetupOrigin.user,
            baseProfileId: 'missing-profile',
            thinkingModelOverrideId: 'model-config-id',
          ),
        ),
        template: makeTestTemplate(),
        version: makeTestTemplateVersion(),
      );

      expect(result.status, AgentSetupResolutionStatus.resolved);
      expect(result.source, AgentSetupResolutionSource.directModel);
      expect(result.profile?.thinkingModelId, 'provider-model-id');
      expect(result.brokenSelectionId, 'missing-profile');
      expect(result.hasBrokenSelection, isTrue);
    });

    test('typed direct model replaces only the base thinking slot', () async {
      final profile = testInferenceProfile(
        id: 'base-profile',
        thinkingModelId: 'base-thinking',
        transcriptionModelId: 'transcription',
      );
      stubProfile(profile);
      when(() => mockAiConfig.getConfigsByType(AiConfigType.model)).thenAnswer(
        (_) async => [
          testAiModel(
            id: 'base-model',
            providerModelId: 'base-thinking',
            inferenceProviderId: 'base-provider',
          ),
          testAiModel(
            id: 'transcription-model',
            providerModelId: 'transcription',
            inferenceProviderId: 'transcription-provider',
          ),
        ],
      );
      when(
        () => mockAiConfig.getConfigById('base-provider'),
      ).thenAnswer((_) async => testInferenceProvider(id: 'base-provider'));
      when(
        () => mockAiConfig.getConfigById('transcription-provider'),
      ).thenAnswer(
        (_) async => testInferenceProvider(id: 'transcription-provider'),
      );
      final overrideModel = testAiModel(
        id: 'override-model',
        providerModelId: 'override-thinking',
        inferenceProviderId: 'override-provider',
      );
      when(
        () => mockAiConfig.getConfigById('override-model'),
      ).thenAnswer((_) async => overrideModel);
      when(
        () => mockAiConfig.getConfigById('override-provider'),
      ).thenAnswer((_) async => testInferenceProvider(id: 'override-provider'));

      final result = await resolver.resolveDetailed(
        agentConfig: const AgentConfig(
          inferenceSetup: AgentInferenceSetup(
            mode: AgentInferenceSetupMode.configured,
            origin: AgentInferenceSetupOrigin.categorySnapshot,
            baseProfileId: 'base-profile',
            thinkingModelOverrideId: 'override-model',
          ),
        ),
        template: makeTestTemplate(),
        version: makeTestTemplateVersion(),
      );

      expect(result.profile?.thinkingModelId, 'override-thinking');
      expect(result.profile?.transcriptionModelId, 'transcription');
      expect(result.setupOrigin, AgentInferenceSetupOrigin.categorySnapshot);
      expect(result.hasBrokenSelection, isFalse);
    });

    test('broken direct model visibly falls back to configured base', () async {
      final profile = testInferenceProfile(id: 'base-profile');
      stubProfile(profile);
      stubModelResolution();
      when(
        () => mockAiConfig.getConfigById('missing-override'),
      ).thenAnswer((_) async => null);

      final result = await resolver.resolveDetailed(
        agentConfig: const AgentConfig(
          inferenceSetup: AgentInferenceSetup(
            mode: AgentInferenceSetupMode.configured,
            origin: AgentInferenceSetupOrigin.user,
            baseProfileId: 'base-profile',
            thinkingModelOverrideId: 'missing-override',
          ),
        ),
        template: makeTestTemplate(),
        version: makeTestTemplateVersion(),
      );

      expect(result.status, AgentSetupResolutionStatus.resolved);
      expect(result.source, AgentSetupResolutionSource.baseProfile);
      expect(result.brokenSelectionId, 'missing-override');
      expect(result.hasBrokenSelection, isTrue);
    });

    test(
      'typed setup with no usable route is broken without legacy fallback',
      () async {
        when(
          () => mockAiConfig.getConfigById('missing-profile'),
        ).thenAnswer((_) async => null);

        final result = await resolver.resolveDetailed(
          agentConfig: const AgentConfig(
            inferenceSetup: AgentInferenceSetup(
              mode: AgentInferenceSetupMode.configured,
              origin: AgentInferenceSetupOrigin.templateSnapshot,
              baseProfileId: 'missing-profile',
            ),
          ),
          template: makeTestTemplate(),
          version: makeTestTemplateVersion(),
        );

        expect(result.status, AgentSetupResolutionStatus.broken);
        expect(result.profile, isNull);
        expect(result.brokenSelectionId, 'missing-profile');
        verifyNever(() => mockAiConfig.getConfigsByType(AiConfigType.model));
      },
    );

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
      tags: 'glados',
    );
  });
}
