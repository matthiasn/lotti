import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/util/profile_resolver.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../agents/test_utils.dart';

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
    when(() => mockAiConfig.getConfigById(profile.id))
        .thenAnswer((_) async => profile);
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
      when(() => mockAiConfig.getConfigById('profile-missing'))
          .thenAnswer((_) async => null);
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
      when(() => mockAiConfig.getConfigsByType(AiConfigType.model))
          .thenAnswer((_) async => []);

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
      when(() => mockAiConfig.getConfigById('p1'))
          .thenAnswer((_) async => testInferenceProvider(id: 'p1'));
      when(() => mockAiConfig.getConfigById('p2'))
          .thenAnswer((_) async => testInferenceProvider(id: 'p2'));
      when(() => mockAiConfig.getConfigById('p3'))
          .thenAnswer((_) async => testInferenceProvider(id: 'p3'));
      when(() => mockAiConfig.getConfigById('p4'))
          .thenAnswer((_) async => testInferenceProvider(id: 'p4'));

      final result = await resolver.resolve(
        agentConfig: const AgentConfig(profileId: 'profile-full'),
        template: makeTestTemplate(),
        version: makeTestTemplateVersion(),
      );

      expect(result, isNotNull);
      expect(result!.thinkingModelId, 'thinking-model');
      expect(result.thinkingProvider.id, 'p1');
      expect(result.imageRecognitionModelId, 'vision-model');
      expect(result.imageRecognitionProvider, isNotNull);
      expect(result.transcriptionModelId, 'audio-model');
      expect(result.transcriptionProvider, isNotNull);
      expect(result.imageGenerationModelId, 'image-gen-model');
      expect(result.imageGenerationProvider, isNotNull);
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
      when(() => mockAiConfig.getConfigById('p1'))
          .thenAnswer((_) async => testInferenceProvider(id: 'p1'));

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

    test('resolves local provider with empty API key', () async {
      final profile = testInferenceProfile(
        id: 'profile-local',
        thinkingModelId: 'qwen3:8b',
      );
      stubProfile(profile);

      when(() => mockAiConfig.getConfigsByType(AiConfigType.model)).thenAnswer(
        (_) async => [
          testAiModel(
            providerModelId: 'qwen3:8b',
            inferenceProviderId: 'provider-local',
          ),
        ],
      );
      when(() => mockAiConfig.getConfigById('provider-local'))
          .thenAnswer((_) async => testLocalInferenceProvider());

      final result = await resolver.resolve(
        agentConfig: const AgentConfig(profileId: 'profile-local'),
        template: makeTestTemplate(),
        version: makeTestTemplateVersion(),
      );

      expect(result, isNotNull);
      expect(result!.thinkingModelId, 'qwen3:8b');
      expect(
        result.thinkingProvider.inferenceProviderType,
        InferenceProviderType.ollama,
      );
    });
  });
}
