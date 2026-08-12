import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/agents/state/template_query_providers.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';

/// Shared detailed inference resolution used by the task-agent header.
final FutureProviderFamily<ResolvedAgentSetup?, String>
taskAgentResolvedSetupProvider = FutureProvider.autoDispose
    .family<ResolvedAgentSetup?, String>(
      taskAgentResolvedSetup,
      name: 'taskAgentResolvedSetupProvider',
    );

/// Template-backed alias used by task and Daily OS agent surfaces.
///
/// Goal agents use [goalAgentResolvedSetupProvider] because their persisted
/// profile selection does not depend on an agent template.
final FutureProviderFamily<ResolvedAgentSetup?, String>
agentResolvedSetupProvider = taskAgentResolvedSetupProvider;

/// Resolves a goal agent's persisted profile without requiring a template.
final FutureProviderFamily<ResolvedAgentSetup?, String>
goalAgentResolvedSetupProvider = FutureProvider.autoDispose
    .family<ResolvedAgentSetup?, String>(
      goalAgentResolvedSetup,
      name: 'goalAgentResolvedSetupProvider',
    );

Future<ResolvedAgentSetup?> goalAgentResolvedSetup(
  Ref ref,
  String agentId,
) async {
  final identityEntity = await ref.watch(agentIdentityProvider(agentId).future);
  final identity = identityEntity?.mapOrNull(agent: (value) => value);
  if (identity == null || identity.kind != AgentKinds.goalAgent) return null;

  final profileId = identity.config.profileId;
  if (profileId == null) {
    return ResolvedAgentSetup(
      status: AgentSetupResolutionStatus.disabled,
      setupOrigin: identity.config.inferenceSetup?.origin,
    );
  }
  final profile = await ref
      .watch(profileResolverProvider)
      .resolveByProfileId(profileId);
  if (profile == null) {
    return ResolvedAgentSetup(
      status: AgentSetupResolutionStatus.broken,
      setupOrigin: identity.config.inferenceSetup?.origin,
    );
  }
  return ResolvedAgentSetup(
    status: AgentSetupResolutionStatus.resolved,
    profile: profile,
    source: identity.config.inferenceSetup == null
        ? AgentSetupResolutionSource.legacyAgentProfile
        : AgentSetupResolutionSource.baseProfile,
    setupOrigin: identity.config.inferenceSetup?.origin,
  );
}

Future<ResolvedAgentSetup?> taskAgentResolvedSetup(
  Ref ref,
  String agentId,
) async {
  final identityEntity = await ref.watch(agentIdentityProvider(agentId).future);
  final identity = identityEntity?.mapOrNull(agent: (value) => value);
  if (identity == null) return null;

  final templateEntity = await ref.watch(
    templateForAgentProvider(agentId).future,
  );
  final template = templateEntity?.mapOrNull(agentTemplate: (value) => value);
  if (template == null) return null;

  final versionEntity = await ref.watch(
    activeTemplateVersionProvider(template.id).future,
  );
  final version = versionEntity?.mapOrNull(
    agentTemplateVersion: (value) => value,
  );
  if (version == null) return null;

  return ref
      .watch(profileResolverProvider)
      .resolveDetailed(
        agentConfig: identity.config,
        template: template,
        version: version,
      );
}

class TaskAgentSetupOptions {
  const TaskAgentSetupOptions({
    required this.profiles,
    required this.models,
    required this.providers,
  });

  final List<AiConfigInferenceProfile> profiles;
  final List<AiConfigModel> models;
  final List<AiConfigInferenceProvider> providers;
}

/// Cached setup catalog shared by every page of the adaptive agent sheet.
///
/// This deliberately is not auto-disposed: Wolt pages mount independently,
/// and rebuilding the same repository query between pages causes a visible
/// empty-state flash. Repository dependency changes still recompute the value,
/// while consumers use the previous snapshot during that refresh.
final FutureProvider<TaskAgentSetupOptions> taskAgentSetupOptionsProvider =
    FutureProvider<TaskAgentSetupOptions>(
      taskAgentSetupOptions,
      name: 'taskAgentSetupOptionsProvider',
    );

/// Shared catalog for agentic inference pickers.
final FutureProvider<TaskAgentSetupOptions> agentSetupOptionsProvider =
    taskAgentSetupOptionsProvider;

Future<TaskAgentSetupOptions> taskAgentSetupOptions(Ref ref) async {
  final repository = ref.watch(aiConfigRepositoryProvider);
  final values = await Future.wait([
    repository.getConfigsByType(AiConfigType.inferenceProfile),
    repository.getConfigsByType(AiConfigType.model),
    repository.getConfigsByType(AiConfigType.inferenceProvider),
  ]);
  return TaskAgentSetupOptions(
    profiles: values[0].whereType<AiConfigInferenceProfile>().toList(),
    models: values[1]
        .whereType<AiConfigModel>()
        .where(isAgenticThinkingModel)
        .toList(),
    providers: values[2].whereType<AiConfigInferenceProvider>().toList(),
  );
}

bool isAgenticThinkingModel(AiConfigModel model) {
  return model.supportsFunctionCalling &&
      model.inputModalities.contains(Modality.text) &&
      model.outputModalities.contains(Modality.text);
}
