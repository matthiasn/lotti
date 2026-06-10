import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/constants/provider_config.dart';
import 'package:lotti/features/ai/model/ai_config.dart';

import 'eval_endpoint_identity.dart';
import 'eval_models.dart';
import 'eval_profile_config.dart';
import 'profiles.dart';

void main() {
  test('local profile seeds an Ollama model config id slot', () {
    final config = evalProfileConfig(kLocalSmallProfile);

    expect(config.profileId, 'eval-profile-local-small');
    expect(config.modelConfigId, kLocalSmallProfile.modelId);
    expect(config.inferenceProfile.thinkingModelId, config.model.id);
    expect(config.provider.inferenceProviderType, InferenceProviderType.ollama);
    expect(config.provider.isUsable, isTrue);
    expect(config.providerModelId, startsWith('eval-local-small:'));
    expect(config.modelRows.first.id, contains('decoy-duplicate-native'));
    expect(config.modelRows.first.providerModelId, config.providerModelId);
    expect(config.configById(config.profileId), config.inferenceProfile);
  });

  test('frontier profile seeds a Gemini model config id slot', () {
    final config = evalProfileConfig(kFrontierProfile);

    expect(config.profileId, 'eval-profile-frontier-gemini');
    expect(config.modelConfigId, kFrontierProfile.modelId);
    expect(config.inferenceProfile.thinkingModelId, config.model.id);
    expect(config.provider.inferenceProviderType, InferenceProviderType.gemini);
    expect(config.provider.apiKey, isNotEmpty);
    expect(
      config.providerModelId,
      startsWith('models/eval-frontier-reasoning-'),
    );
    expect(config.modelRows.first.providerModelId, config.providerModelId);
    expect(config.legacyVersionModel.providerModelId, contains('legacy'));
  });

  test('provider override binds a profile to a live provider-native model', () {
    final config = evalProfileConfig(
      kFrontierFastProfile,
      providerOverride: const EvalProfileProviderOverride(
        providerType: InferenceProviderType.openAi,
        providerModelId: 'gpt-5-mini-live-eval',
        apiKey: 'live-key',
        baseUrl: 'https://example.invalid/v1',
      ),
    );

    expect(config.provider.inferenceProviderType, InferenceProviderType.openAi);
    expect(config.provider.apiKey, 'live-key');
    expect(config.provider.baseUrl, 'https://example.invalid/v1');
    expect(config.providerEndpointOrigin, 'https://example.invalid');
    expect(
      config.providerBaseUrlDigest,
      evalProviderBaseUrlDigest('https://example.invalid/v1/'),
    );
    expect(
      config.providerBaseUrlDigest,
      isNot(evalProviderBaseUrlDigest('https://example.invalid/v2')),
    );
    expect(config.model.providerModelId, 'gpt-5-mini-live-eval');
    expect(config.model.inferenceProviderId, config.provider.id);
    expect(config.modelRows.last.id, kFrontierFastProfile.modelId);
  });

  test('provider decision records candidates without secret values', () {
    final config = evalProfileConfig(
      kFrontierFastProfile,
      providerOverride: const EvalProfileProviderOverride(
        providerType: InferenceProviderType.openAi,
        providerModelId: 'gpt-5-mini-live-eval',
        apiKey: 'super-secret',
      ),
    );

    final decision = config.toProviderDecisionRecord(
      envPresence: const {
        'OPENAI_API_KEY': true,
        'LOTTI_EVAL_FRONTIER_MODEL': true,
      },
    );
    final json = decision.toJson().toString();

    expect(decision.profileName, kFrontierFastProfile.name);
    expect(decision.modelClass, EvalModelClass.frontierFast);
    expect(decision.selectedModelConfigId, kFrontierFastProfile.modelId);
    expect(decision.selectedProviderType, 'openAi');
    expect(decision.selectedProviderModelId, 'gpt-5-mini-live-eval');
    expect(
      decision.candidateModelConfigIds,
      contains(config.decoyDuplicateProviderNativeModel.id),
    );
    expect(decision.decoyModelConfigIds, [
      config.decoyDuplicateProviderNativeModel.id,
    ]);
    expect(
      decision.legacyModelConfigIds,
      contains(config.legacyTemplateModel.id),
    );
    expect(decision.candidateProviderIds, contains(config.legacyProvider.id));
    expect(decision.envPresence['OPENAI_API_KEY'], isTrue);
    expect(json, isNot(contains('super-secret')));
  });

  test('rejects inconsistent local/frontier profile labels', () {
    const bad = EvalProfile(
      name: 'bad-local-frontier',
      isLocal: true,
      modelClass: EvalModelClass.frontierReasoning,
      modelId: 'bad-model',
    );

    expect(() => evalProfileConfig(bad), throwsArgumentError);
  });
}
