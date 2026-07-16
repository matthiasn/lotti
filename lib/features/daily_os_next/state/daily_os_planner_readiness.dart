import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/util/profile_resolver.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_service.dart';

/// Whether the day-planning flow has a resolvable thinking route.
///
/// Uses the same [ProfileResolver] chain as `DayAgentWorkflow`: an existing
/// planner resolves through its assigned template and config; before the first
/// capture, the seeded Shepherd template is resolved with the config that
/// planner creation will copy.
///
/// Route resolution waits for [agentInitializationProvider] so the default
/// template and active version have finished seeding before an absent row is
/// interpreted as "not ready". This is load-bearing for the rollout backfill:
/// that migration persists its first readiness result and must not permanently
/// misclassify an already-configured upgrader during concurrent app startup.
///
/// **Reactivity boundary.** The agent-initialization future is a bootstrap
/// barrier; the inference provider/model/profile config streams are the live
/// inputs. Readiness therefore recomputes when a user connects or edits an AI
/// provider — the path that actually flips a new user from not-ready to ready,
/// and the one this gate exists to follow. The other inputs
/// [hasResolvableDailyOsPlannerThinkingRoute] reads (the planner entity, its
/// assigned template, that template's active version, and the planner's own
/// config) are *not* subscribed: `agentRepositoryProvider` and
/// `agentTemplateServiceProvider` yield service instances, not data streams, so
/// watching them conveys no invalidation. Writes to those settle for the app
/// session's remaining reads.
///
/// That is tolerable rather than correct. Planner creation is the one such
/// write on the new-user path, and it cannot strand this gate: the plan it
/// creates trips `hasEverHadPlan`, which closes the walkthrough regardless of
/// readiness. The rest (republishing the Day agent template's active version,
/// reassigning its model/profile) are advanced actions on a surface a
/// mid-onboarding user is not in. Subscribing to `agentUpdateStreamProvider`
/// would close the gap, but it changes when the walkthrough arms and belongs
/// with its own tests rather than riding along here.
///
/// Lives in its own library rather than beside either onboarding gate because
/// both consume it: the Daily OS walkthrough gate treats it as live
/// eligibility, and the onboarding rollout backfill
/// (`onboarding_rollout.dart`) reads it once to decide whether an install was
/// already set up before the rollout. Keeping it here is what stops those two
/// libraries from importing each other in a cycle.
final FutureProvider<bool> dailyOsOnboardingProviderReadyProvider =
    FutureProvider<bool>((ref) async {
      final agentInitializationFuture = ref.watch(
        agentInitializationProvider.future,
      );
      final configFutures = [
        ref.watch(
          aiConfigByTypeControllerProvider(
            AiConfigType.inferenceProvider,
          ).future,
        ),
        ref.watch(aiConfigByTypeControllerProvider(AiConfigType.model).future),
        ref.watch(
          aiConfigByTypeControllerProvider(
            AiConfigType.inferenceProfile,
          ).future,
        ),
      ];
      final agentRepository = ref.watch(agentRepositoryProvider);
      final templateService = ref.watch(agentTemplateServiceProvider);
      final profileResolver = ref.watch(profileResolverProvider);

      await agentInitializationFuture;
      await Future.wait(configFutures);
      return hasResolvableDailyOsPlannerThinkingRoute(
        agentRepository: agentRepository,
        templateService: templateService,
        profileResolver: profileResolver,
      );
    }, name: 'dailyOsOnboardingProviderReadyProvider');

/// Resolves the exact thinking route a Daily OS drafting wake would use.
///
/// Read-only: it never creates the planner. When no planner exists yet it
/// mirrors [DayAgentService.getOrCreatePlannerAgent] by applying the seeded
/// template's model/profile config to a transient [AgentConfig].
Future<bool> hasResolvableDailyOsPlannerThinkingRoute({
  required AgentRepository agentRepository,
  required AgentTemplateService templateService,
  required ProfileResolver profileResolver,
}) async {
  final plannerEntity = await agentRepository.getEntity(dailyOsPlannerAgentId);
  final planner = plannerEntity is AgentIdentityEntity ? plannerEntity : null;
  final template = planner == null
      ? await templateService.getTemplate(dayAgentTemplateId)
      : await templateService.getTemplateForAgent(planner.agentId);
  if (template == null) return false;

  final version = await templateService.getActiveVersion(template.id);
  if (version == null) return false;

  final config =
      planner?.config ??
      AgentConfig(modelId: template.modelId, profileId: template.profileId);
  final resolved = await profileResolver.resolve(
    agentConfig: config,
    template: template,
    version: version,
  );
  return resolved != null;
}
