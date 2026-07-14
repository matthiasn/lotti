import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
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

/// Agent-kind-neutral alias used by Daily OS and other agent surfaces.
final FutureProviderFamily<ResolvedAgentSetup?, String>
agentResolvedSetupProvider = taskAgentResolvedSetupProvider;

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

final FutureProvider<TaskAgentSetupOptions> taskAgentSetupOptionsProvider =
    FutureProvider.autoDispose<TaskAgentSetupOptions>(
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

/// Backward-compatible name for existing task-agent callers.
bool isTaskAgentThinkingModel(AiConfigModel model) =>
    isAgenticThinkingModel(model);
