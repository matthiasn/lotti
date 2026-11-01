import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_config.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_model_resolution.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../agents/test_data/entity_factories.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockAiConfigRepository aiConfigRepository;
  late MockDomainLogger domainLogger;

  final provider =
      AiConfig.inferenceProvider(
            id: 'melious-provider',
            baseUrl: 'https://api.melious.ai',
            apiKey: 'key',
            name: 'Melious',
            createdAt: DateTime(2026),
            inferenceProviderType: InferenceProviderType.melious,
          )
          as AiConfigInferenceProvider;
  final flash =
      AiConfig.model(
            id: 'model-flash',
            name: 'DeepSeek Flash',
            providerModelId: meliousDeepseekV41FlashModelId,
            inferenceProviderId: provider.id,
            createdAt: DateTime(2026),
            inputModalities: const [Modality.text],
            outputModalities: const [Modality.text],
            isReasoningModel: true,
            supportsFunctionCalling: true,
            description: 'flash',
          )
          as AiConfigModel;
  final glm =
      AiConfig.model(
            id: 'model-glm',
            name: 'GLM',
            providerModelId: 'glm-5.2',
            inferenceProviderId: provider.id,
            createdAt: DateTime(2026),
            inputModalities: const [Modality.text],
            outputModalities: const [Modality.text],
            isReasoningModel: true,
            supportsFunctionCalling: true,
            description: 'glm',
          )
          as AiConfigModel;
  final glmProfile = AiConfigInferenceProfile(
    id: 'profile-glm',
    name: 'GLM profile',
    thinkingModelId: glm.providerModelId,
    imageRecognitionModelId: glm.providerModelId,
    createdAt: DateTime(2026),
  );

  Future<FrontModelResolution?> resolve(AgentConfig config) =>
      resolveFrontAgentModel(
        agentIdentity: makeTestIdentity(
          kind: AgentKinds.frontAgent,
          config: config,
        ),
        aiConfigRepository: aiConfigRepository,
        domainLogger: domainLogger,
      );

  setUp(() {
    aiConfigRepository = MockAiConfigRepository();
    domainLogger = MockDomainLogger();
    final byId = <String, AiConfig>{
      provider.id: provider,
      flash.id: flash,
      glm.id: glm,
      glmProfile.id: glmProfile,
      // Slot resolution may look a model up by either id.
      flash.providerModelId: flash,
      glm.providerModelId: glm,
    };
    when(
      () => aiConfigRepository.getConfigById(any()),
    ).thenAnswer((invocation) async {
      return byId[invocation.positionalArguments.first as String];
    });
    when(
      () => aiConfigRepository.getConfigsByType(AiConfigType.model),
    ).thenAnswer((_) async => [glm, flash]);
    when(
      () => aiConfigRepository.getDefaultProfileId(),
    ).thenAnswer((_) async => null);
  });

  test('the built-in route is the cheap flash model, Melious first, then '
      "Mistral's", () {
    expect(frontAgentBuiltInModelIds, [
      meliousDeepseekV41FlashModelId,
      mistralDeepseekV41Flash1017ModelId,
    ]);
  });

  test(
    'with only Mistral set up, the built-in model routes through it',
    () async {
      final mistral =
          AiConfig.inferenceProvider(
                id: 'mistral-provider',
                baseUrl: 'https://api.mistral.ai/v1',
                apiKey: 'key',
                name: 'Mistral',
                createdAt: DateTime(2026),
                inferenceProviderType: InferenceProviderType.mistral,
              )
              as AiConfigInferenceProvider;
      final mistralFlash =
          AiConfig.model(
                id: 'model-mistral-flash',
                name: 'DeepSeek Flash',
                providerModelId: mistralDeepseekV41Flash1017ModelId,
                inferenceProviderId: mistral.id,
                createdAt: DateTime(2026),
                inputModalities: const [Modality.text],
                outputModalities: const [Modality.text],
                isReasoningModel: true,
                supportsFunctionCalling: true,
              )
              as AiConfigModel;
      final byId = <String, AiConfig>{
        mistral.id: mistral,
        mistralFlash.id: mistralFlash,
        mistralFlash.providerModelId: mistralFlash,
      };
      when(
        () => aiConfigRepository.getConfigById(any()),
      ).thenAnswer(
        (invocation) async =>
            byId[invocation.positionalArguments.first as String],
      );
      when(
        () => aiConfigRepository.getConfigsByType(AiConfigType.model),
      ).thenAnswer((_) async => [mistralFlash]);

      final resolved = await resolve(const AgentConfig());

      expect(resolved, isNotNull);
      expect(resolved!.modelId, mistralDeepseekV41Flash1017ModelId);
      expect(resolved.provider.id, mistral.id);
      expect(resolved.setup.source, AgentSetupResolutionSource.legacyModel);
    },
  );

  test('with nothing configured, the built-in cheap model routes', () async {
    final resolved = await resolve(const AgentConfig());

    expect(resolved, isNotNull);
    expect(resolved!.modelId, meliousDeepseekV41FlashModelId);
    expect(resolved.provider.id, provider.id);
    expect(resolved.setup.source, AgentSetupResolutionSource.legacyModel);
    expect(resolved.setup.status, AgentSetupResolutionStatus.resolved);
  });

  test("the identity's own profile wins over the built-in model", () async {
    final resolved = await resolve(AgentConfig(profileId: glmProfile.id));

    expect(resolved!.modelId, 'glm-5.2');
    expect(
      resolved.setup.source,
      AgentSetupResolutionSource.legacyAgentProfile,
    );
  });

  test('a disabled explicit setup resolves to nothing — no fallback', () async {
    final resolved = await resolve(
      const AgentConfig(
        inferenceSetup: AgentInferenceSetup(
          mode: AgentInferenceSetupMode.disabled,
          origin: AgentInferenceSetupOrigin.user,
        ),
      ),
    );

    expect(resolved, isNull);
    verifyNever(() => aiConfigRepository.getConfigsByType(any()));
  });

  test('a selected but unresolvable Settings default fails closed rather '
      'than routing through the built-in model', () async {
    when(
      () => aiConfigRepository.getDefaultProfileId(),
    ).thenAnswer((_) async => 'profile-gone');

    final resolved = await resolve(const AgentConfig());

    expect(resolved, isNull);
    verifyNever(() => aiConfigRepository.getConfigsByType(any()));
  });

  test('a configured explicit setup routes through its base profile', () async {
    final resolved = await resolve(
      AgentConfig(
        inferenceSetup: AgentInferenceSetup(
          mode: AgentInferenceSetupMode.configured,
          origin: AgentInferenceSetupOrigin.user,
          baseProfileId: glmProfile.id,
        ),
      ),
    );

    expect(resolved!.modelId, 'glm-5.2');
    expect(resolved.setup.source, AgentSetupResolutionSource.baseProfile);
    expect(resolved.setup.setupOrigin, AgentInferenceSetupOrigin.user);
  });
}
