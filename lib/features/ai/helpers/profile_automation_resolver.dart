import 'dart:developer' as developer;

import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/service/task_agent_service.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/util/profile_resolver.dart';

const _logTag = 'ProfileAutomationResolver';

/// Callback that returns the `profileId` stored on a task, or `null`.
typedef TaskProfileLookup = Future<String?> Function(String taskId);

/// Callback that returns the default `profileId` stored on a category, or
/// `null` when the category has none configured.
typedef CategoryProfileLookup = Future<String?> Function(String categoryId);

/// Resolves the inference profile for a task's agent — or, for entries that
/// have no parent task, for the entry's category.
///
/// Wraps [ProfileResolver] with the extra step of looking up the task's agent
/// identity, template, and version — then delegates to
/// [ProfileResolver.resolve()] to use the same resolution chain as agent wakes.
///
/// When the agent path yields no result (no agent, no template, etc.) but the
/// task carries an inherited `profileId` (from its category), the resolver
/// falls back to direct profile resolution via [ProfileResolver.resolveByProfileId].
///
/// Standalone entries (audio notes, image notes) skip the task and resolve
/// directly via [resolveForCategory], reading the category's
/// `defaultProfileId`.
///
/// Returns `null` if no profile can be resolved through any path.
class ProfileAutomationResolver {
  const ProfileAutomationResolver({
    required TaskAgentService taskAgentService,
    required AgentTemplateService templateService,
    required ProfileResolver profileResolver,
    TaskProfileLookup? taskProfileLookup,
    CategoryProfileLookup? categoryProfileLookup,
  }) : _taskAgentService = taskAgentService,
       _templateService = templateService,
       _profileResolver = profileResolver,
       _taskProfileLookup = taskProfileLookup,
       _categoryProfileLookup = categoryProfileLookup;

  final TaskAgentService _taskAgentService;
  final AgentTemplateService _templateService;
  final ProfileResolver _profileResolver;
  final TaskProfileLookup? _taskProfileLookup;
  final CategoryProfileLookup? _categoryProfileLookup;

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

  /// Returns the raw profile id for [taskId] using the same resolution chain
  /// as [resolveForTask], but without invoking [ProfileResolver] — callers
  /// (the synced-audio dispatcher) need the underlying inference profile
  /// directly so they can read `pinnedHostId` and run `profileIsLocal`, both
  /// of which the resolved view either hides or silently distorts (unresolved
  /// optional slots become null on the resolved view, masking referenced
  /// cloud configs).
  ///
  /// Order (identical to [resolveForTask], minus the legacy `modelId`
  /// fallback — `modelId` resolves to a model, not a profile, so it can't
  /// carry pin/locality data and is intentionally out of scope here):
  /// 1. Agent path: `agentConfig.profileId ?? version.profileId ??
  ///    template.profileId`.
  /// 2. Task fallback: `task.data.profileId`.
  ///
  /// Mirrors [resolveForTask] but returns the raw profile id.
  ///
  /// Returns `null` when neither path yields a profile id.
  Future<String?> resolveProfileIdForTask(String taskId) async {
    final agentId = await _resolveProfileIdViaAgent(taskId);
    if (agentId != null) return agentId;

    final lookup = _taskProfileLookup;
    if (lookup == null) return null;
    final taskId0 = await lookup(taskId);
    if (taskId0 != null) {
      developer.log(
        'resolveProfileIdForTask: using task-level profileId $taskId0 for '
        'task $taskId',
        name: _logTag,
      );
    }
    return taskId0;
  }

  Future<String?> _resolveProfileIdViaAgent(String taskId) async {
    final agent = await _taskAgentService.getTaskAgentForTask(taskId);
    if (agent == null) return null;

    final template = await _templateService.getTemplateForAgent(agent.agentId);
    if (template == null) return null;

    final version = await _templateService.getActiveVersion(template.id);
    if (version == null) return null;

    return agent.config.profileId ?? version.profileId ?? template.profileId;
  }

  /// Resolves the profile from a category's `defaultProfileId`.
  ///
  /// Used for entries that have no parent task — the category's configured
  /// inference profile is the only signal available. Returns `null` if no
  /// lookup is wired, the category has no `defaultProfileId`, or the resolved
  /// profile config cannot be loaded.
  Future<ResolvedProfile?> resolveForCategory(String categoryId) async {
    final lookup = _categoryProfileLookup;
    if (lookup == null) return null;

    final profileId = await lookup(categoryId);
    if (profileId == null) {
      developer.log(
        'No defaultProfileId for category $categoryId',
        name: _logTag,
      );
      return null;
    }

    developer.log(
      'Using category defaultProfileId $profileId for category $categoryId',
      name: _logTag,
    );
    return _profileResolver.resolveByProfileId(profileId);
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
