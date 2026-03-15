import 'dart:developer' as developer;

import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/service/task_agent_service.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/util/profile_resolver.dart';

const _logTag = 'ProfileAutomationResolver';

/// Callback that returns the `profileId` stored on a task, or `null`.
typedef TaskProfileLookup = Future<String?> Function(String taskId);

/// Resolves the inference profile for a task's agent.
///
/// Wraps [ProfileResolver] with the extra step of looking up the task's agent
/// identity, template, and version — then delegates to
/// [ProfileResolver.resolve()] to use the same resolution chain as agent wakes.
///
/// When the agent path yields no result (no agent, no template, etc.) but the
/// task carries an inherited `profileId` (from its category), the resolver
/// falls back to direct profile resolution via [ProfileResolver.resolveByProfileId].
///
/// Returns `null` if no profile can be resolved through either path.
class ProfileAutomationResolver {
  const ProfileAutomationResolver({
    required TaskAgentService taskAgentService,
    required AgentTemplateService templateService,
    required ProfileResolver profileResolver,
    TaskProfileLookup? taskProfileLookup,
  }) : _taskAgentService = taskAgentService,
       _templateService = templateService,
       _profileResolver = profileResolver,
       _taskProfileLookup = taskProfileLookup;

  final TaskAgentService _taskAgentService;
  final AgentTemplateService _templateService;
  final ProfileResolver _profileResolver;
  final TaskProfileLookup? _taskProfileLookup;

  /// Resolves the profile for the given [taskId]'s agent.
  ///
  /// Resolution order:
  /// 1. Agent path: `agentConfig.profileId ?? version.profileId ??
  ///    template.profileId` → legacy `modelId` fallback.
  /// 2. Task fallback: `task.data.profileId` (inherited from category).
  Future<ResolvedProfile?> resolveForTask(String taskId) async {
    // 1. Try agent-based resolution.
    final agentResult = await _resolveViaAgent(taskId);
    if (agentResult != null) return agentResult;

    // 2. Fall back to the task's own profileId (inherited from category).
    return _resolveViaTaskProfile(taskId);
  }

  Future<ResolvedProfile?> _resolveViaAgent(String taskId) async {
    final agent = await _taskAgentService.getTaskAgentForTask(taskId);
    if (agent == null) {
      developer.log(
        'No agent found for task $taskId',
        name: _logTag,
      );
      return null;
    }

    final template = await _templateService.getTemplateForAgent(agent.agentId);
    if (template == null) {
      developer.log(
        'No template found for agent ${agent.agentId}',
        name: _logTag,
      );
      return null;
    }

    final version = await _templateService.getActiveVersion(template.id);
    if (version == null) {
      developer.log(
        'No active version for template ${template.id}',
        name: _logTag,
      );
      return null;
    }

    return _profileResolver.resolve(
      agentConfig: agent.config,
      template: template,
      version: version,
    );
  }

  Future<ResolvedProfile?> _resolveViaTaskProfile(String taskId) async {
    final lookup = _taskProfileLookup;
    if (lookup == null) return null;

    final profileId = await lookup(taskId);
    if (profileId == null) {
      developer.log(
        'No task-level profileId for task $taskId',
        name: _logTag,
      );
      return null;
    }

    developer.log(
      'Using task-level profileId $profileId for task $taskId',
      name: _logTag,
    );
    return _profileResolver.resolveByProfileId(profileId);
  }
}
