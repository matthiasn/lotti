import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/ai/helpers/profile_automation_resolver.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/services/profile_automation_service.dart';
import 'package:lotti/features/ai/util/profile_resolver.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'profile_automation_providers.g.dart';

@Riverpod(keepAlive: true)
ProfileResolver profileResolver(Ref ref) {
  return ProfileResolver(
    aiConfigRepository: ref.watch(aiConfigRepositoryProvider),
  );
}

@Riverpod(keepAlive: true)
ProfileAutomationResolver profileAutomationResolver(Ref ref) {
  return ProfileAutomationResolver(
    taskAgentService: ref.watch(taskAgentServiceProvider),
    templateService: ref.watch(agentTemplateServiceProvider),
    profileResolver: ref.watch(profileResolverProvider),
  );
}

@Riverpod(keepAlive: true)
ProfileAutomationService profileAutomationService(Ref ref) {
  return ProfileAutomationService(
    resolver: ref.watch(profileAutomationResolverProvider),
    aiConfigRepository: ref.watch(aiConfigRepositoryProvider),
  );
}
