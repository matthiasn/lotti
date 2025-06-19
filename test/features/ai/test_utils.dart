import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

export 'package:flutter_localizations/flutter_localizations.dart';
// Re-export commonly used imports for convenience
export 'package:flutter_riverpod/flutter_riverpod.dart'
    show Override, ProviderScope;
export 'package:lotti/features/ai/repository/ai_config_repository.dart'
    show aiConfigRepositoryProvider;
export 'package:lotti/features/ai/state/consts.dart';
export 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart'
    show aiConfigByTypeControllerProvider;
export 'package:lotti/l10n/app_localizations.dart';

/// Shared mock classes for AI feature tests
class MockAiConfigRepository extends Mock implements AiConfigRepository {}

class MockAiConfigByTypeController extends AiConfigByTypeController {
  MockAiConfigByTypeController(this._configs);

  final List<AiConfig> _configs;

  @override
  Stream<List<AiConfig>> build({required AiConfigType configType}) {
    return Stream.value(_configs);
  }
}

/// Test data factory for creating consistent test configurations
class AiTestDataFactory {
  static AiConfigInferenceProvider createTestProvider({
    String id = 'test-provider',
    String name = 'Test Provider',
    String? description = 'Test provider description',
    InferenceProviderType type = InferenceProviderType.anthropic,
    String apiKey = 'test-api-key',
    String baseUrl = 'https://api.test.com',
  }) {
    return AiConfig.inferenceProvider(
      id: id,
      name: name,
      description: description,
      inferenceProviderType: type,
      apiKey: apiKey,
      baseUrl: baseUrl,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    ) as AiConfigInferenceProvider;
  }

  static AiConfigModel createTestModel({
    String id = 'test-model',
    String name = 'Test Model',
    String? description = 'Test model description',
    String providerModelId = 'test-provider-model-id',
    String inferenceProviderId = 'test-provider',
    List<Modality> inputModalities = const [Modality.text],
    List<Modality> outputModalities = const [Modality.text],
    bool isReasoningModel = false,
  }) {
    return AiConfig.model(
      id: id,
      name: name,
      description: description,
      providerModelId: providerModelId,
      inferenceProviderId: inferenceProviderId,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      inputModalities: inputModalities,
      outputModalities: outputModalities,
      isReasoningModel: isReasoningModel,
    ) as AiConfigModel;
  }

  static AiConfigPrompt createTestPrompt({
    String id = 'test-prompt',
    String name = 'Test Prompt',
    String? description = 'Test prompt description',
    String systemMessage = 'Test system message',
    String userMessage = 'Test user message',
    String defaultModelId = 'test-model',
    List<String> modelIds = const ['test-model'],
    bool useReasoning = false,
    List<InputDataType> requiredInputData = const [InputDataType.task],
    AiResponseType aiResponseType = AiResponseType.taskSummary,
  }) {
    return AiConfig.prompt(
      id: id,
      name: name,
      description: description,
      systemMessage: systemMessage,
      userMessage: userMessage,
      defaultModelId: defaultModelId,
      modelIds: modelIds,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      useReasoning: useReasoning,
      requiredInputData: requiredInputData,
      aiResponseType: aiResponseType,
    ) as AiConfigPrompt;
  }

  static List<AiConfig> createMixedTestConfigs() {
    return [
      createTestProvider(
        id: 'anthropic-provider',
        name: 'Anthropic Provider',
      ),
      createTestProvider(
        id: 'openai-provider',
        name: 'OpenAI Provider',
        type: InferenceProviderType.openAi,
      ),
      createTestModel(
        id: 'claude-model',
        name: 'Claude Sonnet 3.5',
        inferenceProviderId: 'anthropic-provider',
        inputModalities: [Modality.text, Modality.image],
      ),
      createTestModel(
        id: 'gpt-model',
        name: 'GPT-4',
        inferenceProviderId: 'openai-provider',
        isReasoningModel: true,
      ),
      createTestPrompt(
        id: 'analysis-prompt',
        name: 'Analysis Prompt',
        defaultModelId: 'claude-model',
      ),
    ];
  }
}

/// Shared test setup utilities
class AiTestSetup {
  /// Registers fallback values for mocktail
  static void registerFallbackValues() {
    registerFallbackValue(
      AiTestDataFactory.createTestProvider(
        id: 'fallback-id',
        name: 'Fallback Provider',
        type: InferenceProviderType.genericOpenAi,
        baseUrl: 'https://api.example.com',
      ),
    );
  }

  /// Creates a MaterialApp with proper localization for testing
  static Widget createTestApp({
    required Widget child,
    List<Override> providerOverrides = const [],
  }) {
    return ProviderScope(
      overrides: providerOverrides,
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );
  }

  /// Creates provider overrides for AI config controllers
  static List<Override> createControllerOverrides({
    List<AiConfig>? providers,
    List<AiConfig>? models,
    List<AiConfig>? prompts,
    AiConfigRepository? repository,
  }) {
    final overrides = <Override>[];

    if (repository != null) {
      overrides.add(aiConfigRepositoryProvider.overrideWithValue(repository));
    }

    if (providers != null) {
      overrides.add(
        aiConfigByTypeControllerProvider(
          configType: AiConfigType.inferenceProvider,
        ).overrideWith(() => MockAiConfigByTypeController(providers)),
      );
    }

    if (models != null) {
      overrides.add(
        aiConfigByTypeControllerProvider(
          configType: AiConfigType.model,
        ).overrideWith(() => MockAiConfigByTypeController(models)),
      );
    }

    if (prompts != null) {
      overrides.add(
        aiConfigByTypeControllerProvider(
          configType: AiConfigType.prompt,
        ).overrideWith(() => MockAiConfigByTypeController(prompts)),
      );
    }

    return overrides;
  }
}

/// Shared test widget builders
class AiTestWidgets {
  /// Creates a standard test widget with AI config repository and localization
  static Widget createTestWidget({
    required Widget child,
    AiConfigRepository? repository,
    List<AiConfig>? providers,
    List<AiConfig>? models,
    List<AiConfig>? prompts,
  }) {
    final overrides = AiTestSetup.createControllerOverrides(
      repository: repository,
      providers: providers,
      models: models,
      prompts: prompts,
    );

    return AiTestSetup.createTestApp(
      providerOverrides: overrides,
      child: child,
    );
  }
}
