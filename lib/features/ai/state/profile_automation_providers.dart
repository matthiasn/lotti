import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/ai/helpers/profile_automation_resolver.dart';
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
  );
}

final profileAutomationServiceProvider = Provider<ProfileAutomationService>(
  profileAutomationService,
  name: 'profileAutomationServiceProvider',
);
ProfileAutomationService profileAutomationService(Ref ref) {
  return ProfileAutomationService(
    resolver: ref.watch(profileAutomationResolverProvider),
    aiConfigRepository: ref.watch(aiConfigRepositoryProvider),
  );
}
