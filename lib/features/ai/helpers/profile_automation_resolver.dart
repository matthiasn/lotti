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

/// Callback that returns the `categoryId` owning a task, or `null`.
typedef TaskCategoryLookup = Future<String?> Function(String taskId);

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
///
/// [resolveForTask] answers "which profile drives this task's agent". That is
/// the right question for the thinking route and the wrong one for automated
/// capabilities, which is what [resolveAutomationFallbacks] exists for.
class ProfileAutomationResolver {
  const ProfileAutomationResolver({
    required this._taskAgentService,
    required this._templateService,
    required this._profileResolver,
    this._taskProfileLookup,
    this._categoryProfileLookup,
    this._taskCategoryLookup,
  });

  final TaskAgentService _taskAgentService;
  final AgentTemplateService _templateService;
  final ProfileResolver _profileResolver;
  final TaskProfileLookup? _taskProfileLookup;
  final CategoryProfileLookup? _categoryProfileLookup;
  final TaskCategoryLookup? _taskCategoryLookup;

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

  /// Profiles that can supply an automated capability [resolveForTask] does
  /// not own, most specific first and without duplicates.
  ///
  /// The agent's profile drives the *thinking* route, and picking a thinking
  /// model by hand resolves to a bare model route — no capability slots, no
  /// skill assignments at all. Treating that as the last word switches the
  /// category's automatic transcription and image analysis off as a side
  /// effect of a model choice, and no later model change brings them back.
  /// The same hole opens for a task created before its category had a default
  /// profile, and for a profile that carries a thinking model but not every
  /// capability the category configured.
  ///
  /// Order:
  /// 1. `task.data.profileId` (inherited from the category at creation).
  /// 2. The owning category's current `defaultProfileId`.
  ///
  /// Callers walk this list *per capability* and take the first profile that
  /// actually owns the slot they need, so a profile deliberately chosen for
  /// this task still wins every capability it does own.
  ///
  /// Profiles that cannot be loaded are skipped rather than ending the walk.
  Future<List<ResolvedProfile>> resolveAutomationFallbacks(
    String taskId,
  ) async {
    final candidateProfileIds = <String>{};

    final taskProfileId = await _taskProfileLookup?.call(taskId);
    if (taskProfileId != null) candidateProfileIds.add(taskProfileId);

    final categoryId = await _taskCategoryLookup?.call(taskId);
    if (categoryId != null) {
      final categoryProfileId = await _categoryProfileLookup?.call(categoryId);
      if (categoryProfileId != null) candidateProfileIds.add(categoryProfileId);
    }

    final resolved = <ResolvedProfile>[];
    for (final profileId in candidateProfileIds) {
      final profile = await _profileResolver.resolveByProfileId(profileId);
      if (profile == null) {
        developer.log(
          'Automation fallback profile $profileId for task $taskId could not '
          'be resolved — skipping',
          name: _logTag,
        );
        continue;
      }
      resolved.add(profile);
    }
    return resolved;
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
