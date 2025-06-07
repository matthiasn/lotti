import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_navigation_service.dart';

void main() {
  group('AiSettingsNavigationService', () {
    late AiSettingsNavigationService service;
    late AiConfig testProvider;
    late AiConfig testModel;
    late AiConfig testPrompt;

    setUp(() {
      service = const AiSettingsNavigationService();

      testProvider = AiConfig.inferenceProvider(
        id: 'test-provider-id',
        name: 'Test Provider',
        inferenceProviderType: InferenceProviderType.anthropic,
        apiKey: 'test-key',
        baseUrl: 'https://api.test.com',
        createdAt: DateTime.now(),
      );

      testModel = AiConfig.model(
        id: 'test-model-id',
        name: 'Test Model',
        providerModelId: 'test-model',
        inferenceProviderId: 'test-provider-id',
        createdAt: DateTime.now(),
        inputModalities: [Modality.text],
        outputModalities: [Modality.text],
        isReasoningModel: false,
      );

      testPrompt = AiConfig.prompt(
        id: 'test-prompt-id',
        name: 'Test Prompt',
        systemMessage: 'Test system message',
        userMessage: 'Test user message',
        defaultModelId: 'test-model-id',
        modelIds: ['test-model-id'],
        createdAt: DateTime.now(),
        useReasoning: false,
        requiredInputData: [InputDataType.task],
        aiResponseType: AiResponseType.taskSummary,
      );
    });

    group('title helper methods', () {
      test('getCreatePageTitle returns correct titles', () {
        expect(
          service.getCreatePageTitle(AiConfigInferenceProvider),
          'Add AI Inference Provider',
        );
        expect(
          service.getCreatePageTitle(AiConfigModel),
          'Add AI Model',
        );
        expect(
          service.getCreatePageTitle(AiConfigPrompt),
          'Add AI Prompt',
        );
        expect(
          service.getCreatePageTitle(String),
          'Add AI Configuration',
        );
      });

      test('getEditPageTitle returns correct titles', () {
        expect(
          service.getEditPageTitle(AiConfigInferenceProvider),
          'Edit AI Inference Provider',
        );
        expect(
          service.getEditPageTitle(AiConfigModel),
          'Edit AI Model',
        );
        expect(
          service.getEditPageTitle(AiConfigPrompt),
          'Edit AI Prompt',
        );
        expect(
          service.getEditPageTitle(String),
          'Edit AI Configuration',
        );
      });
    });

    group('permission checks', () {
      test('canEditConfig returns true for all configs by default', () {
        expect(service.canEditConfig(testProvider), isTrue);
        expect(service.canEditConfig(testModel), isTrue);
        expect(service.canEditConfig(testPrompt), isTrue);
      });

      test('canDeleteConfig returns true for all configs by default', () {
        expect(service.canDeleteConfig(testProvider), isTrue);
        expect(service.canDeleteConfig(testModel), isTrue);
        expect(service.canDeleteConfig(testPrompt), isTrue);
      });
    });

    group('config type determination', () {
      test('correctly identifies provider configs', () {
        expect(testProvider, isA<AiConfigInferenceProvider>());
      });

      test('correctly identifies model configs', () {
        expect(testModel, isA<AiConfigModel>());
      });

      test('correctly identifies prompt configs', () {
        expect(testPrompt, isA<AiConfigPrompt>());
      });
    });

    group('navigation validation', () {
      test('navigation methods accept correct config types', () {
        // Test that methods exist and accept the expected parameters
        expect(
            service.getCreatePageTitle(AiConfigInferenceProvider), isNotEmpty);
        expect(service.getCreatePageTitle(AiConfigModel), isNotEmpty);
        expect(service.getCreatePageTitle(AiConfigPrompt), isNotEmpty);

        expect(service.getEditPageTitle(AiConfigInferenceProvider), isNotEmpty);
        expect(service.getEditPageTitle(AiConfigModel), isNotEmpty);
        expect(service.getEditPageTitle(AiConfigPrompt), isNotEmpty);
      });

      test('permission methods work with all config types', () {
        // Test provider config
        expect(service.canEditConfig(testProvider), isNotNull);
        expect(service.canDeleteConfig(testProvider), isNotNull);

        // Test model config
        expect(service.canEditConfig(testModel), isNotNull);
        expect(service.canDeleteConfig(testModel), isNotNull);

        // Test prompt config
        expect(service.canEditConfig(testPrompt), isNotNull);
        expect(service.canDeleteConfig(testPrompt), isNotNull);
      });
    });

    group('service instantiation', () {
      test('service can be instantiated as const', () {
        const service1 = AiSettingsNavigationService();
        const service2 = AiSettingsNavigationService();

        // Services should be equivalent
        expect(service1.runtimeType, service2.runtimeType);
      });

      test('service methods are deterministic', () {
        const service1 = AiSettingsNavigationService();
        const service2 = AiSettingsNavigationService();

        expect(
          service1.getCreatePageTitle(AiConfigInferenceProvider),
          service2.getCreatePageTitle(AiConfigInferenceProvider),
        );

        expect(
          service1.getEditPageTitle(AiConfigModel),
          service2.getEditPageTitle(AiConfigModel),
        );
      });
    });
  });
}
