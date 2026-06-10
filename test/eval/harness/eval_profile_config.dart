// EvalProfile -> production AI config seeding.
//
// The eval profile label is not evidence by itself. This helper creates the
// same AiConfigProvider/AiConfigModel/AiConfigInferenceProfile rows the
// production ProfileResolver consumes, so scripted and live targets can prove
// which provider-native model actually ran.

import 'package:lotti/features/ai/constants/provider_config.dart';
import 'package:lotti/features/ai/model/ai_config.dart';

import 'eval_endpoint_identity.dart';
import 'eval_models.dart';

class EvalProfileConfig {
  const EvalProfileConfig({
    required this.profile,
    required this.inferenceProfile,
    required this.model,
    required this.provider,
    required this.decoyDuplicateProviderNativeModel,
    required this.decoyProvider,
    required this.legacyVersionModel,
    required this.legacyTemplateModel,
    required this.legacyProvider,
  });

  final EvalProfile profile;
  final AiConfigInferenceProfile inferenceProfile;
  final AiConfigModel model;
  final AiConfigInferenceProvider provider;
  final AiConfigModel decoyDuplicateProviderNativeModel;
  final AiConfigInferenceProvider decoyProvider;
  final AiConfigModel legacyVersionModel;
  final AiConfigModel legacyTemplateModel;
  final AiConfigInferenceProvider legacyProvider;

  String get profileId => inferenceProfile.id;
  String get modelConfigId => model.id;
  String get providerModelId => model.providerModelId;
  String get providerId => provider.id;
  String get providerType => provider.inferenceProviderType.name;
  String get providerEndpointOrigin =>
      evalProviderEndpointOrigin(provider.baseUrl);
  String get providerBaseUrlDigest =>
      evalProviderBaseUrlDigest(provider.baseUrl);

  List<AiConfigModel> get modelRows => [
    decoyDuplicateProviderNativeModel,
    legacyVersionModel,
    legacyTemplateModel,
    model,
  ];

  AiConfig? configById(String id) {
    if (id == profileId) return inferenceProfile;
    if (id == modelConfigId) return model;
    if (id == providerId) return provider;
    if (id == decoyDuplicateProviderNativeModel.id) {
      return decoyDuplicateProviderNativeModel;
    }
    if (id == decoyProvider.id) return decoyProvider;
    if (id == legacyVersionModel.id) return legacyVersionModel;
    if (id == legacyTemplateModel.id) return legacyTemplateModel;
    if (id == legacyProvider.id) return legacyProvider;
    return null;
  }

  ResolvedModelRecord toResolvedModelRecord({
    String? templateId,
    String? templateVersionId,
    String? providerModelId,
    String? providerId,
    InferenceProviderType? providerType,
    String? wakeRunResolvedModelId,
    String? usageModelId,
  }) {
    return ResolvedModelRecord(
      profileId: profileId,
      modelConfigId: modelConfigId,
      providerModelId: providerModelId ?? this.providerModelId,
      providerId: providerId ?? this.providerId,
      providerType: (providerType ?? provider.inferenceProviderType).name,
      providerEndpointOrigin: providerEndpointOrigin,
      providerBaseUrlDigest: providerBaseUrlDigest,
      templateId: templateId,
      templateVersionId: templateVersionId,
      wakeRunResolvedModelId: wakeRunResolvedModelId,
      usageModelId: usageModelId,
    );
  }

  ProviderDecisionRecord toProviderDecisionRecord({
    Map<String, bool> envPresence = const <String, bool>{},
  }) {
    return ProviderDecisionRecord(
      profileName: profile.name,
      modelClass: profile.modelClass,
      isLocal: profile.isLocal,
      profileId: profileId,
      selectedModelConfigId: modelConfigId,
      selectedProviderId: providerId,
      selectedProviderType: providerType,
      selectedProviderModelId: providerModelId,
      selectedProviderEndpointOrigin: providerEndpointOrigin,
      selectedProviderBaseUrlDigest: providerBaseUrlDigest,
      candidateModelConfigIds: [
        for (final row in modelRows) row.id,
      ],
      decoyModelConfigIds: [decoyDuplicateProviderNativeModel.id],
      legacyModelConfigIds: [
        legacyVersionModel.id,
        legacyTemplateModel.id,
      ],
      candidateProviderIds: [
        provider.id,
        decoyProvider.id,
        legacyProvider.id,
      ],
      envPresence: envPresence,
    );
  }

  EvalProfileExecutionBinding toExecutionBinding() {
    return EvalProfileExecutionBinding(
      profileName: profile.name,
      modelClass: profile.modelClass,
      isLocal: profile.isLocal,
      profileId: profileId,
      modelConfigId: modelConfigId,
      providerId: providerId,
      providerType: providerType,
      providerModelId: providerModelId,
      providerEndpointOrigin: providerEndpointOrigin,
      providerBaseUrlDigest: providerBaseUrlDigest,
      providerRequestTemperature:
          provider.inferenceProviderType == InferenceProviderType.openAi
          ? 1
          : profile.temperature,
    );
  }
}

class EvalProfileProviderOverride {
  const EvalProfileProviderOverride({
    required this.providerType,
    required this.providerModelId,
    this.providerId,
    this.providerName,
    this.baseUrl,
    this.apiKey,
  });

  final InferenceProviderType providerType;
  final String providerModelId;
  final String? providerId;
  final String? providerName;
  final String? baseUrl;
  final String? apiKey;
}

EvalProfileConfig evalProfileConfig(
  EvalProfile profile, {
  EvalProfileProviderOverride? providerOverride,
}) {
  if (profile.modelId.trim().isEmpty) {
    throw ArgumentError.value(profile.modelId, 'profile.modelId');
  }
  final classIsLocal =
      profile.modelClass == EvalModelClass.localSmall ||
      profile.modelClass == EvalModelClass.localReasoning;
  if (profile.isLocal != classIsLocal) {
    throw ArgumentError(
      'EvalProfile "${profile.name}" has inconsistent isLocal/modelClass '
      '(${profile.isLocal}/${profile.modelClass.name})',
    );
  }

  final providerType =
      providerOverride?.providerType ??
      (profile.isLocal
          ? InferenceProviderType.ollama
          : InferenceProviderType.gemini);
  final providerId =
      providerOverride?.providerId ?? 'eval-provider-${profile.name}';
  final provider = _provider(
    id: providerId,
    type: providerType,
    apiKey:
        providerOverride?.apiKey ??
        (profile.isLocal ? '' : 'eval-key-${profile.name}'),
    baseUrl: providerOverride?.baseUrl,
    name: providerOverride?.providerName,
  );

  final model =
      AiConfig.model(
            id: profile.modelId,
            name: 'Eval ${profile.name}',
            providerModelId:
                providerOverride?.providerModelId ??
                _providerNativeModelId(profile),
            inferenceProviderId: providerId,
            createdAt: DateTime(2026, 6, 9),
            inputModalities: const [Modality.text],
            outputModalities: const [Modality.text],
            isReasoningModel:
                profile.modelClass == EvalModelClass.localReasoning ||
                profile.modelClass == EvalModelClass.frontierReasoning,
            supportsFunctionCalling: true,
            maxCompletionTokens: profile.maxCompletionTokens,
          )
          as AiConfigModel;

  final inferenceProfile =
      AiConfig.inferenceProfile(
            id: 'eval-profile-${profile.name}',
            name: 'Eval ${profile.name}',
            thinkingModelId: model.id,
            createdAt: DateTime(2026, 6, 9),
            desktopOnly: profile.isLocal,
          )
          as AiConfigInferenceProfile;

  final decoyProviderType = profile.isLocal
      ? InferenceProviderType.gemini
      : InferenceProviderType.ollama;
  final decoyProvider = _provider(
    id: 'eval-provider-${profile.name}-decoy',
    type: decoyProviderType,
    apiKey: profile.isLocal ? 'decoy-key-${profile.name}' : '',
  );
  final decoyDuplicateProviderNativeModel = _model(
    id: '${profile.modelId}-decoy-duplicate-native',
    name: 'Decoy duplicate ${profile.name}',
    providerModelId: model.providerModelId,
    providerId: decoyProvider.id,
    isReasoningModel: model.isReasoningModel,
    maxCompletionTokens: profile.maxCompletionTokens,
  );

  final legacyProvider = _provider(
    id: 'eval-provider-${profile.name}-legacy',
    type: InferenceProviderType.gemini,
    apiKey: 'legacy-key-${profile.name}',
  );
  final legacyVersionModel = _model(
    id: '${profile.modelId}-legacy-version',
    name: 'Legacy version ${profile.name}',
    providerModelId: 'legacy-version-model-must-not-win',
    providerId: legacyProvider.id,
    isReasoningModel: false,
  );
  final legacyTemplateModel = _model(
    id: '${profile.modelId}-legacy-template',
    name: 'Legacy template ${profile.name}',
    providerModelId: 'legacy-template-model-must-not-win',
    providerId: legacyProvider.id,
    isReasoningModel: false,
  );

  return EvalProfileConfig(
    profile: profile,
    inferenceProfile: inferenceProfile,
    model: model,
    provider: provider,
    decoyDuplicateProviderNativeModel: decoyDuplicateProviderNativeModel,
    decoyProvider: decoyProvider,
    legacyVersionModel: legacyVersionModel,
    legacyTemplateModel: legacyTemplateModel,
    legacyProvider: legacyProvider,
  );
}

AiConfigInferenceProvider _provider({
  required String id,
  required InferenceProviderType type,
  required String apiKey,
  String? baseUrl,
  String? name,
}) {
  return AiConfig.inferenceProvider(
        id: id,
        baseUrl: baseUrl ?? ProviderConfig.getDefaultBaseUrl(type),
        apiKey: apiKey,
        name: name ?? ProviderConfig.getDefaultName(type),
        inferenceProviderType: type,
        createdAt: DateTime(2026, 6, 9),
      )
      as AiConfigInferenceProvider;
}

AiConfigModel _model({
  required String id,
  required String name,
  required String providerModelId,
  required String providerId,
  required bool isReasoningModel,
  int? maxCompletionTokens,
}) {
  return AiConfig.model(
        id: id,
        name: name,
        providerModelId: providerModelId,
        inferenceProviderId: providerId,
        createdAt: DateTime(2026, 6, 9),
        inputModalities: const [Modality.text],
        outputModalities: const [Modality.text],
        isReasoningModel: isReasoningModel,
        supportsFunctionCalling: true,
        maxCompletionTokens: maxCompletionTokens,
      )
      as AiConfigModel;
}

String _providerNativeModelId(EvalProfile profile) {
  return switch (profile.modelClass) {
    EvalModelClass.localSmall => 'eval-local-small:${profile.modelId}',
    EvalModelClass.localReasoning => 'eval-local-reasoning:${profile.modelId}',
    EvalModelClass.frontierFast =>
      'models/eval-frontier-fast-${profile.modelId}',
    EvalModelClass.frontierReasoning =>
      'models/eval-frontier-reasoning-${profile.modelId}',
  };
}
