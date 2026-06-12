// Live Level 2 implementation of the evaluation target seam.
//
// This target keeps the scenario/app-state adapters from the deterministic
// workflow benches, but swaps in the production ConversationRepository and
// CloudInferenceRepository. It is intentionally gated by environment so default
// `flutter test test/eval` discovery never makes model/network calls.

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/constants/provider_config.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';

import 'eval_models.dart';
import 'eval_profile_config.dart';
import 'eval_target.dart';
import 'observing_conversation_repository.dart';
import 'planner_eval_bench.dart';
import 'scripted_agent_behavior.dart';
import 'task_agent_eval_bench.dart';

class LiveEvalSettings {
  const LiveEvalSettings({
    required this.environment,
    required this.enabled,
    required this.runningInCi,
    required this.allowCi,
  });

  factory LiveEvalSettings.fromEnvironment(Map<String, String> environment) {
    return LiveEvalSettings(
      environment: Map<String, String>.unmodifiable(environment),
      enabled: _truthy(environment['LOTTI_EVAL_LIVE']),
      runningInCi: _truthy(environment['CI']),
      allowCi: _truthy(environment['LOTTI_EVAL_ALLOW_CI']),
    );
  }

  final Map<String, String> environment;
  final bool enabled;
  final bool runningInCi;
  final bool allowCi;

  EvalProfileConfig profileConfigFor(EvalProfile profile) {
    validateProfile(profile);
    return profileBindingConfigFor(profile);
  }

  EvalProfileConfig profileBindingConfigFor(EvalProfile profile) {
    return evalProfileConfig(
      profile,
      providerOverride: providerOverrideFor(profile),
    );
  }

  Map<String, bool> envPresenceForProfile(EvalProfile profile) {
    final providerType = _providerTypeFor(profile);
    final profileKey = _profileKey(profile);
    final classKey = profile.isLocal ? 'LOCAL' : 'FRONTIER';
    final providerPrefix = _providerEnvPrefix(providerType);
    final keys = <String>{
      'CI',
      'LOTTI_EVAL_ALLOW_CI',
      'LOTTI_EVAL_LIVE',
      ..._providerKeys(profileKey: profileKey, classKey: classKey),
      ..._modelKeys(
        profileKey: profileKey,
        classKey: classKey,
        providerPrefix: providerPrefix,
        isLocal: profile.isLocal,
      ),
      ..._apiKeyKeys(
        profileKey: profileKey,
        classKey: classKey,
        providerPrefix: providerPrefix,
      ),
      ..._baseUrlKeys(
        profileKey: profileKey,
        classKey: classKey,
        providerPrefix: providerPrefix,
        providerType: providerType,
      ),
    }.toList()..sort();
    return {
      for (final key in keys)
        key: (environment[key]?.trim().isNotEmpty ?? false),
    };
  }

  void validateProfiles(Iterable<EvalProfile> profiles) {
    profiles.forEach(validateProfile);
  }

  void validateProfile(EvalProfile profile) {
    if (!enabled) {
      throw StateError(
        'LOTTI_EVAL_LIVE is not 1; refusing to make live model calls.',
      );
    }
    if (runningInCi && !allowCi) {
      throw StateError(
        'Refusing live eval in CI without LOTTI_EVAL_ALLOW_CI=1.',
      );
    }
    providerOverrideFor(profile);
  }

  EvalProfileProviderOverride providerOverrideFor(EvalProfile profile) {
    final providerType = _providerTypeFor(profile);
    final profileKey = _profileKey(profile);
    final classKey = profile.isLocal ? 'LOCAL' : 'FRONTIER';
    final providerPrefix = _providerEnvPrefix(providerType);
    final providerModelId = _requiredEnv(
      _modelKeys(
        profileKey: profileKey,
        classKey: classKey,
        providerPrefix: providerPrefix,
        isLocal: profile.isLocal,
      ),
      'provider-native model id for profile "${profile.name}"',
    );
    final apiKey = _apiKeyFor(
      profileKey: profileKey,
      classKey: classKey,
      providerType: providerType,
      providerPrefix: providerPrefix,
    );
    final baseUrl = _firstEnv(
      _baseUrlKeys(
        profileKey: profileKey,
        classKey: classKey,
        providerPrefix: providerPrefix,
        providerType: providerType,
      ),
    );

    return EvalProfileProviderOverride(
      providerType: providerType,
      providerModelId: providerModelId,
      apiKey: apiKey,
      baseUrl: baseUrl,
      providerName: 'Live eval ${profile.name}',
    );
  }

  InferenceProviderType _providerTypeFor(EvalProfile profile) {
    final profileKey = _profileKey(profile);
    final classKey = profile.isLocal ? 'LOCAL' : 'FRONTIER';
    final configured = _firstEnv(
      _providerKeys(profileKey: profileKey, classKey: classKey),
    );
    if (configured == null || configured.trim().isEmpty) {
      return profile.isLocal
          ? InferenceProviderType.ollama
          : InferenceProviderType.gemini;
    }
    final providerType = _parseProviderType(configured);
    if (profile.isLocal && providerType != InferenceProviderType.ollama) {
      throw StateError(
        'Local eval profile "${profile.name}" must use ollama; got '
        '${providerType.name}.',
      );
    }
    return providerType;
  }

  String? _apiKeyFor({
    required String profileKey,
    required String classKey,
    required InferenceProviderType providerType,
    required String providerPrefix,
  }) {
    if (!ProviderConfig.requiresApiKey(providerType)) return '';
    return _requiredEnv(
      _apiKeyKeys(
        profileKey: profileKey,
        classKey: classKey,
        providerPrefix: providerPrefix,
      ),
      'API key for provider ${providerType.name}',
    );
  }

  String? _firstEnv(List<String> keys) {
    for (final key in keys) {
      final value = environment[key]?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  String _requiredEnv(List<String> keys, String description) {
    final value = _firstEnv(keys);
    if (value != null) return value;
    throw StateError(
      'Missing $description. Set one of: ${keys.join(', ')}.',
    );
  }
}

class LiveEvalTarget extends EvalTarget {
  LiveEvalTarget({
    required this.settings,
    ProviderContainer? providerContainer,
    ObservingConversationRepository Function()? conversationRepositoryFactory,
    this.profileName = 'live',
  }) : _providerContainer = providerContainer ?? ProviderContainer(),
       _ownsProviderContainer = providerContainer == null,
       _conversationRepositoryFactory =
           conversationRepositoryFactory ?? ObservingConversationRepository.new;

  factory LiveEvalTarget.fromEnvironment({
    Map<String, String>? environment,
  }) {
    return LiveEvalTarget(
      settings: LiveEvalSettings.fromEnvironment(
        environment ?? Platform.environment,
      ),
    );
  }

  final LiveEvalSettings settings;
  final ProviderContainer _providerContainer;
  final bool _ownsProviderContainer;
  final ObservingConversationRepository Function()
  _conversationRepositoryFactory;

  @override
  final String profileName;

  @override
  String get targetKind => 'live';

  @override
  List<EvalProfileExecutionBinding> profileExecutionBindings(
    List<EvalProfile> profiles,
  ) => [
    for (final profile in profiles)
      settings.profileBindingConfigFor(profile).toExecutionBinding(),
  ];

  @override
  Future<AgentRunOutput> run(
    EvalScenario scenario,
    EvalProfile profile, {
    EvalTargetRunContext context = EvalTargetRunContext.direct,
  }) {
    final profileConfig = settings.profileConfigFor(profile);
    final conversationRepository = _conversationRepositoryFactory();
    final cloudInferenceRepository = _providerContainer.read(
      cloudInferenceRepositoryProvider,
    );
    const emptyBehavior = ScriptedAgentBehavior();

    return switch (scenario.agentKind) {
      AgentKind.planningAgent => PlannerEvalBench.runWake(
        scenario,
        profile,
        emptyBehavior,
        context: context,
        conversationRepositoryOverride: conversationRepository,
        cloudInferenceRepositoryOverride: cloudInferenceRepository,
        profileConfigOverride: profileConfig,
        providerEnvPresence: settings.envPresenceForProfile(profile),
      ),
      AgentKind.taskAgent => TaskAgentEvalBench.runWake(
        scenario,
        profile,
        emptyBehavior,
        context: context,
        conversationRepositoryOverride: conversationRepository,
        cloudInferenceRepositoryOverride: cloudInferenceRepository,
        profileConfigOverride: profileConfig,
        providerEnvPresence: settings.envPresenceForProfile(profile),
      ),
    };
  }

  void dispose() {
    if (_ownsProviderContainer) {
      _providerContainer.dispose();
    }
  }
}

List<String> _providerKeys({
  required String profileKey,
  required String classKey,
}) {
  return [
    'LOTTI_EVAL_PROVIDER_$profileKey',
    'LOTTI_EVAL_${profileKey}_PROVIDER',
    'LOTTI_EVAL_${classKey}_PROVIDER',
  ];
}

List<String> _modelKeys({
  required String profileKey,
  required String classKey,
  required String providerPrefix,
  required bool isLocal,
}) {
  return [
    'LOTTI_EVAL_MODEL_$profileKey',
    'LOTTI_EVAL_${profileKey}_MODEL',
    'LOTTI_EVAL_${classKey}_MODEL',
    '${providerPrefix}_MODEL',
    if (isLocal) 'OLLAMA_MODEL',
  ];
}

List<String> _apiKeyKeys({
  required String profileKey,
  required String classKey,
  required String providerPrefix,
}) {
  return [
    'LOTTI_EVAL_API_KEY_$profileKey',
    'LOTTI_EVAL_${profileKey}_API_KEY',
    'LOTTI_EVAL_${classKey}_API_KEY',
    '${providerPrefix}_API_KEY',
  ];
}

List<String> _baseUrlKeys({
  required String profileKey,
  required String classKey,
  required String providerPrefix,
  required InferenceProviderType providerType,
}) {
  return [
    'LOTTI_EVAL_BASE_URL_$profileKey',
    'LOTTI_EVAL_${profileKey}_BASE_URL',
    'LOTTI_EVAL_${classKey}_BASE_URL',
    '${providerPrefix}_BASE_URL',
    if (providerType == InferenceProviderType.ollama) 'OLLAMA_BASE_URL',
  ];
}

String _profileKey(EvalProfile profile) =>
    profile.name.toUpperCase().replaceAll(RegExp('[^A-Z0-9]+'), '_');

InferenceProviderType _parseProviderType(String value) {
  final normalized = value.trim().replaceAll(RegExp('[^A-Za-z0-9]'), '');
  for (final type in InferenceProviderType.values) {
    final candidate = type.name.replaceAll(RegExp('[^A-Za-z0-9]'), '');
    if (candidate.toLowerCase() == normalized.toLowerCase()) return type;
  }
  throw StateError('Unknown inference provider type "$value".');
}

String _providerEnvPrefix(InferenceProviderType providerType) {
  switch (providerType) {
    case InferenceProviderType.openAi:
      return 'OPENAI';
    case InferenceProviderType.genericOpenAi:
      return 'GENERIC_OPENAI';
    case InferenceProviderType.openRouter:
      return 'OPENROUTER';
    case InferenceProviderType.nebiusAiStudio:
      return 'NEBIUS_AI_STUDIO';
    case InferenceProviderType.mlxAudio:
      return 'MLX_AUDIO';
    case InferenceProviderType.voxtral:
    case InferenceProviderType.whisper:
    case InferenceProviderType.ollama:
    case InferenceProviderType.gemini:
    case InferenceProviderType.mistral:
    case InferenceProviderType.anthropic:
    case InferenceProviderType.alibaba:
      break;
  }
  final buffer = StringBuffer();
  for (var i = 0; i < providerType.name.length; i++) {
    final char = providerType.name[i];
    final isUpper = char.toUpperCase() == char && char.toLowerCase() != char;
    if (i > 0 && isUpper) buffer.write('_');
    buffer.write(char.toUpperCase());
  }
  return buffer.toString();
}

bool _truthy(String? value) {
  final normalized = value?.trim().toLowerCase();
  return normalized == '1' || normalized == 'true' || normalized == 'yes';
}
