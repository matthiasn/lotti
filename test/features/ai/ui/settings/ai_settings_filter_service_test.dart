import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_filter_service.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_filter_state.dart';

void main() {
  group('AiSettingsFilterService', () {
    late AiSettingsFilterService service;
    late List<AiConfigInferenceProvider> testProviders;
    late List<AiConfigModel> testModels;
    late List<AiConfigPrompt> testPrompts;

    setUp(() {
      service = const AiSettingsFilterService();

      testProviders = [
        AiConfig.inferenceProvider(
          id: 'anthropic-provider',
          name: 'Anthropic Provider',
          description: 'Claude models provider',
          inferenceProviderType: InferenceProviderType.anthropic,
          apiKey: 'test-key',
          baseUrl: 'https://api.anthropic.com',
          createdAt: DateTime.now(),
        ) as AiConfigInferenceProvider,
        AiConfig.inferenceProvider(
          id: 'openai-provider',
          name: 'OpenAI Provider',
          description: 'GPT models provider',
          inferenceProviderType: InferenceProviderType.openAi,
          apiKey: 'test-key',
          baseUrl: 'https://api.openai.com',
          createdAt: DateTime.now(),
        ) as AiConfigInferenceProvider,
      ];

      testModels = [
        AiConfig.model(
          id: 'claude-model',
          name: 'Claude Sonnet 3.5',
          description: 'Fast and capable model',
          providerModelId: 'claude-3-5-sonnet-20241022',
          inferenceProviderId: 'anthropic-provider',
          createdAt: DateTime.now(),
          inputModalities: [Modality.text, Modality.image],
          outputModalities: [Modality.text],
          isReasoningModel: false,
        ) as AiConfigModel,
        AiConfig.model(
          id: 'gpt-model',
          name: 'GPT-4',
          description: 'Powerful reasoning model',
          providerModelId: 'gpt-4',
          inferenceProviderId: 'openai-provider',
          createdAt: DateTime.now(),
          inputModalities: [Modality.text],
          outputModalities: [Modality.text],
          isReasoningModel: true,
        ) as AiConfigModel,
        AiConfig.model(
          id: 'multimodal-model',
          name: 'Multimodal Model',
          description: 'Vision and audio capable',
          providerModelId: 'multimodal-1',
          inferenceProviderId: 'anthropic-provider',
          createdAt: DateTime.now(),
          inputModalities: [Modality.text, Modality.image, Modality.audio],
          outputModalities: [Modality.text],
          isReasoningModel: false,
        ) as AiConfigModel,
      ];

      testPrompts = [
        AiConfig.prompt(
          id: 'task-summary',
          name: 'Task Summary',
          description: 'Generate task summaries',
          systemMessage: 'You are a helpful assistant.',
          userMessage: 'Summarize this task: {{task}}',
          defaultModelId: 'claude-model',
          modelIds: ['claude-model'],
          createdAt: DateTime.now(),
          useReasoning: false,
          requiredInputData: [InputDataType.task],
          aiResponseType: AiResponseType.taskSummary,
        ) as AiConfigPrompt,
        AiConfig.prompt(
          id: 'image-analysis',
          name: 'Image Analysis',
          description: 'Analyze images',
          systemMessage: 'You are an image analysis expert.',
          userMessage: 'Analyze this image: {{image}}',
          defaultModelId: 'claude-model',
          modelIds: ['claude-model'],
          createdAt: DateTime.now(),
          useReasoning: false,
          requiredInputData: [InputDataType.images],
          aiResponseType: AiResponseType.imageAnalysis,
        ) as AiConfigPrompt,
      ];
    });

    group('filterProviders', () {
      test('returns all providers when no search query', () {
        final filterState = AiSettingsFilterState.initial();
        final result = service.filterProviders(testProviders, filterState);

        expect(result, hasLength(2));
        expect(result, containsAll(testProviders));
      });

      test('filters providers by name (case insensitive)', () {
        final filterState =
            AiSettingsFilterState.initial().copyWith(searchQuery: 'anthropic');
        final result = service.filterProviders(testProviders, filterState);

        expect(result, hasLength(1));
        expect(result.first.name, 'Anthropic Provider');
      });

      test('filters providers by description', () {
        final filterState =
            AiSettingsFilterState.initial().copyWith(searchQuery: 'claude');
        final result = service.filterProviders(testProviders, filterState);

        expect(result, hasLength(1));
        expect(result.first.description, contains('Claude'));
      });

      test('returns empty list when no matches', () {
        final filterState = AiSettingsFilterState.initial()
            .copyWith(searchQuery: 'nonexistent');
        final result = service.filterProviders(testProviders, filterState);

        expect(result, isEmpty);
      });

      test('handles providers without description', () {
        final providerWithoutDescription = AiConfig.inferenceProvider(
          id: 'test-provider',
          name: 'Test Provider',
          inferenceProviderType: InferenceProviderType.genericOpenAi,
          apiKey: 'test-key',
          baseUrl: 'https://api.test.com',
          createdAt: DateTime.now(),
        ) as AiConfigInferenceProvider;

        final providers = [...testProviders, providerWithoutDescription];
        final filterState =
            AiSettingsFilterState.initial().copyWith(searchQuery: 'test');
        final result = service.filterProviders(providers, filterState);

        expect(result, hasLength(1));
        expect(result.first.name, 'Test Provider');
      });
    });

    group('filterModels', () {
      test('returns all models when no filters', () {
        final filterState = AiSettingsFilterState.initial();
        final result = service.filterModels(testModels, filterState);

        expect(result, hasLength(3));
        expect(result, containsAll(testModels));
      });

      test('filters models by search query', () {
        final filterState =
            AiSettingsFilterState.initial().copyWith(searchQuery: 'claude');
        final result = service.filterModels(testModels, filterState);

        expect(result, hasLength(1));
        expect(result.first.name, 'Claude Sonnet 3.5');
      });

      test('filters models by provider', () {
        final filterState = AiSettingsFilterState.initial()
            .copyWith(selectedProviders: {'anthropic-provider'});
        final result = service.filterModels(testModels, filterState);

        expect(result, hasLength(2));
        expect(
            result.every((m) => m.inferenceProviderId == 'anthropic-provider'),
            isTrue);
      });

      test('filters models by single capability', () {
        final filterState = AiSettingsFilterState.initial()
            .copyWith(selectedCapabilities: {Modality.image});
        final result = service.filterModels(testModels, filterState);

        expect(result, hasLength(2));
        expect(result.every((m) => m.inputModalities.contains(Modality.image)),
            isTrue);
      });

      test('filters models by multiple capabilities (AND logic)', () {
        final filterState = AiSettingsFilterState.initial()
            .copyWith(selectedCapabilities: {Modality.image, Modality.audio});
        final result = service.filterModels(testModels, filterState);

        expect(result, hasLength(1));
        expect(result.first.name, 'Multimodal Model');
      });

      test('filters models by reasoning capability', () {
        final filterState =
            AiSettingsFilterState.initial().copyWith(reasoningFilter: true);
        final result = service.filterModels(testModels, filterState);

        expect(result, hasLength(1));
        expect(result.first.isReasoningModel, isTrue);
      });

      test('combines multiple filters (AND logic)', () {
        const filterState = AiSettingsFilterState(
          searchQuery: 'claude',
          selectedProviders: {'anthropic-provider'},
          selectedCapabilities: {Modality.image},
        );
        final result = service.filterModels(testModels, filterState);

        expect(result, hasLength(1));
        expect(result.first.name, 'Claude Sonnet 3.5');
      });

      test('returns empty list when filters exclude all models', () {
        final filterState = AiSettingsFilterState.initial().copyWith(
          selectedProviders: {'nonexistent-provider'},
        );
        final result = service.filterModels(testModels, filterState);

        expect(result, isEmpty);
      });

      test('ignores empty provider filter', () {
        final filterState = AiSettingsFilterState.initial()
            .copyWith(selectedProviders: <String>{});
        final result = service.filterModels(testModels, filterState);

        expect(result, hasLength(3));
      });
    });

    group('filterPrompts', () {
      test('returns all prompts when no search query', () {
        final filterState = AiSettingsFilterState.initial();
        final result = service.filterPrompts(testPrompts, filterState);

        expect(result, hasLength(2));
        expect(result, containsAll(testPrompts));
      });

      test('filters prompts by name', () {
        final filterState =
            AiSettingsFilterState.initial().copyWith(searchQuery: 'task');
        final result = service.filterPrompts(testPrompts, filterState);

        expect(result, hasLength(1));
        expect(result.first.name, 'Task Summary');
      });

      test('filters prompts by description', () {
        final filterState =
            AiSettingsFilterState.initial().copyWith(searchQuery: 'analyze');
        final result = service.filterPrompts(testPrompts, filterState);

        expect(
            result,
            hasLength(
                1)); // Only "Image Analysis" contains "analyze" in description
      });

      test('returns empty list when no matches', () {
        final filterState = AiSettingsFilterState.initial()
            .copyWith(searchQuery: 'nonexistent');
        final result = service.filterPrompts(testPrompts, filterState);

        expect(result, isEmpty);
      });
    });

    group('edge cases', () {
      test('handles empty lists gracefully', () {
        final filterState = AiSettingsFilterState.initial();

        expect(service.filterProviders([], filterState), isEmpty);
        expect(service.filterModels([], filterState), isEmpty);
        expect(service.filterPrompts([], filterState), isEmpty);
      });

      test('handles case sensitivity correctly', () {
        final filterState =
            AiSettingsFilterState.initial().copyWith(searchQuery: 'CLAUDE');
        final result = service.filterProviders(testProviders, filterState);

        expect(result, hasLength(1));
        expect(result.first.description, contains('Claude'));
      });

      test('trims whitespace in search query', () {
        final filterState = AiSettingsFilterState.initial()
            .copyWith(searchQuery: '  anthropic  ');
        final result = service.filterProviders(testProviders, filterState);

        expect(result, hasLength(1));
      });
    });
  });
}
