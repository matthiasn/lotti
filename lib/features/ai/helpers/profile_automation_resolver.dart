import 'dart:developer' as developer;

import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/service/task_agent_service.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/util/profile_resolver.dart';

const _logTag = 'ProfileAutomationResolver';

/// Resolves the inference profile for a task's agent.
///
/// Wraps [ProfileResolver] with the extra step of looking up the task's agent
/// identity, template, and version — then delegates to
/// [ProfileResolver.resolve()] to use the same resolution chain as agent wakes.
///
/// Returns `null` if:
/// - The task has no agent
/// - The agent has no template or active version
/// - The profile cannot be resolved (missing thinking model)
class ProfileAutomationResolver {
  const ProfileAutomationResolver({
    required TaskAgentService taskAgentService,
    required AgentTemplateService templateService,
    required ProfileResolver profileResolver,
  }) : _taskAgentService = taskAgentService,
       _templateService = templateService,
       _profileResolver = profileResolver;

  final TaskAgentService _taskAgentService;
  final AgentTemplateService _templateService;
  final ProfileResolver _profileResolver;

  /// Resolves the profile for the given [taskId]'s agent.
  ///
  /// Follows the same resolution chain as agent wakes:
  /// `agentConfig.profileId ?? version.profileId ?? template.profileId`
  /// → legacy `modelId` fallback.
  Future<ResolvedProfile?> resolveForTask(String taskId) async {
    // 1. Find the agent for this task.
    final agent = await _taskAgentService.getTaskAgentForTask(taskId);
    if (agent == null) {
      developer.log(
        'No agent found for task $taskId',
        name: _logTag,
      );
      return null;
    }

    // 2. Get the agent's template.
    final template = await _templateService.getTemplateForAgent(agent.agentId);
    if (template == null) {
      developer.log(
        'No template found for agent ${agent.agentId}',
        name: _logTag,
      );
      return null;
    }

    // 3. Get the active version.
    final version = await _templateService.getActiveVersion(template.id);
    if (version == null) {
      developer.log(
        'No active version for template ${template.id}',
        name: _logTag,
      );
      return null;
    }

    // 4. Delegate to ProfileResolver.
    return _profileResolver.resolve(
      agentConfig: agent.config,
      template: template,
      version: version,
    );
  }
}
