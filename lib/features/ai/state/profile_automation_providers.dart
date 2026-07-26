import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/ai/helpers/profile_automation_resolver.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/services/profile_automation_service.dart';
import 'package:lotti/features/ai/util/profile_resolver.dart';
import 'package:lotti/providers/service_providers.dart' show journalDbProvider;

final profileResolverProvider = Provider<ProfileResolver>(
  profileResolver,
  name: 'profileResolverProvider',
);
ProfileResolver profileResolver(Ref ref) {
  return ProfileResolver(
    aiConfigRepository: ref.watch(aiConfigRepositoryProvider),
  );
}

final profileAutomationResolverProvider = Provider<ProfileAutomationResolver>(
  profileAutomationResolver,
  name: 'profileAutomationResolverProvider',
);
ProfileAutomationResolver profileAutomationResolver(Ref ref) {
  return ProfileAutomationResolver(
    taskAgentService: ref.watch(taskAgentServiceProvider),
    templateService: ref.watch(agentTemplateServiceProvider),
    profileResolver: ref.watch(profileResolverProvider),
    taskProfileLookup: (taskId) async {
      final entity = await ref
          .read(journalDbProvider)
          .journalEntityById(taskId);
      if (entity is Task) return entity.data.profileId;
      return null;
    },
    categoryProfileLookup: (categoryId) async {
      final category = await ref
          .read(journalDbProvider)
          .getCategoryById(categoryId);
      return category?.defaultProfileId;
    },
    taskCategoryLookup: (taskId) async {
      final entity = await ref
          .read(journalDbProvider)
          .journalEntityById(taskId);
      return entity?.meta.categoryId;
    },
  );
}

/// Whether a category's automatic-inference switch has anything to control.
///
/// Keyed by the category's `defaultProfileId` (nullable). True when that
/// profile carries at least one `automate: true` skill assignment — the
/// "profile is set to automatic" case — or when the direct transcription
/// fallback could run, which needs no profile at all. Showing the switch in
/// that second case is what keeps mobile recording (MLX Audio model, no
/// desktop-only profile selectable) from losing automation with no way to
/// turn it back on.
final FutureProviderFamily<bool, String?> categoryAutomationAvailableProvider =
    FutureProvider.family<bool, String?>(
      categoryAutomationAvailable,
      name: 'categoryAutomationAvailableProvider',
    );
Future<bool> categoryAutomationAvailable(Ref ref, String? profileId) async {
  if (profileId != null) {
    final config = await ref
        .watch(aiConfigRepositoryProvider)
        .getConfigById(profileId);
    if (config is AiConfigInferenceProfile &&
        config.skillAssignments.any((assignment) => assignment.automate)) {
      return true;
    }
  }
  return ref
      .watch(profileAutomationServiceProvider)
      .hasDirectTranscriptionFallback();
}

final profileAutomationServiceProvider = Provider<ProfileAutomationService>(
  profileAutomationService,
  name: 'profileAutomationServiceProvider',
);
ProfileAutomationService profileAutomationService(Ref ref) {
  return ProfileAutomationService(
    resolver: ref.watch(profileAutomationResolverProvider),
    aiConfigRepository: ref.watch(aiConfigRepositoryProvider),
    categoryAutomationLookup: (taskId) async {
      final db = ref.read(journalDbProvider);
      final entity = await db.journalEntityById(taskId);
      final categoryId = entity?.meta.categoryId;
      // No entry or no category means nothing opted in — automation stays off
      // rather than defaulting to "run it".
      if (categoryId == null) return false;
      final category = await db.getCategoryById(categoryId);
      return category?.automaticInferenceEnabledEffective ?? false;
    },
    domainLogger: ref.watch(domainLoggerProvider),
  );
}
