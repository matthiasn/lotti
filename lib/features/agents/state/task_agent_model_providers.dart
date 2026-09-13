import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/agents/state/template_query_providers.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/ai_runtime_settings_controller.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/relationships/state/relationship_agent_providers.dart';

/// Shared detailed inference resolution used by agent headers and setup sheets.
/// Relationship agents resolve their standalone defaults before template lookup.
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

/// Resolves a goal agent's persisted profile or built-in runtime route without
/// requiring a template.
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

  ref.watch(
    defaultInferenceProfileControllerProvider.select((value) => value.value),
  );
  return ref
      .watch(profileResolverProvider)
      .resolveStandalone(
        agentConfig: identity.config,
        legacyModelId: meliousGlm52ModelId,
      );
}

Future<ResolvedAgentSetup?> taskAgentResolvedSetup(
  Ref ref,
  String agentId,
) async {
  final identityEntity = await ref.watch(agentIdentityProvider(agentId).future);
  final identity = identityEntity?.mapOrNull(agent: (value) => value);
  if (identity == null) return null;
  if (identity.kind == AgentKinds.relationshipAgent) {
    return ref.watch(relationshipAgentResolvedSetupProvider(agentId).future);
  }

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

  ref.watch(
    defaultInferenceProfileControllerProvider.select((value) => value.value),
  );

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

/// Live AI configs of one type, the stream every catalog below derives from.
///
/// Kept alive alongside [taskAgentSetupOptionsProvider]; a new emission —
/// a model added, a provider deleted, a profile edited, on this device or
/// arriving through sync — recomputes the catalog without a restart.
final StreamProviderFamily<List<AiConfig>, AiConfigType>
aiConfigsByTypeProvider = StreamProvider.family<List<AiConfig>, AiConfigType>(
  (ref, type) => ref.watch(aiConfigRepositoryProvider).watchConfigsByType(type),
  name: 'aiConfigsByTypeProvider',
);

/// Cached setup catalog shared by every page of the adaptive agent sheet.
///
/// This deliberately is not auto-disposed: Wolt pages mount independently,
/// and rebuilding the same repository query between pages causes a visible
/// empty-state flash. A change to any of the three config streams recomputes
/// the value, while consumers use the previous snapshot during that refresh.
final FutureProvider<TaskAgentSetupOptions> taskAgentSetupOptionsProvider =
    FutureProvider<TaskAgentSetupOptions>(
      taskAgentSetupOptions,
      name: 'taskAgentSetupOptionsProvider',
    );

/// Shared catalog for agentic inference pickers.
final FutureProvider<TaskAgentSetupOptions> agentSetupOptionsProvider =
    taskAgentSetupOptionsProvider;

Future<TaskAgentSetupOptions> taskAgentSetupOptions(Ref ref) async {
  final values = await Future.wait([
    ref.watch(aiConfigsByTypeProvider(AiConfigType.inferenceProfile).future),
    ref.watch(aiConfigsByTypeProvider(AiConfigType.model).future),
    ref.watch(aiConfigsByTypeProvider(AiConfigType.inferenceProvider).future),
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
