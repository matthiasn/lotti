import 'dart:developer' as developer;

import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/service/subject_agent_lookup.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/util/profile_resolver.dart';

const _logTag = 'ProfileAutomationResolver';

/// Callback that returns the `profileId` stored on a subject entity, or
/// `null`.
typedef SubjectProfileLookup = Future<String?> Function(String subjectId);

/// Callback that returns the default `profileId` stored on a category, or
/// `null` when the category has none configured.
typedef CategoryProfileLookup = Future<String?> Function(String categoryId);

/// Callback that returns the `categoryId` owning a subject entity, or `null`.
typedef SubjectCategoryLookup = Future<String?> Function(String subjectId);

/// Resolves the inference profile for a subject entity's agent — or, for
/// entries that have no subject at all, for the entry's category.
///
/// A *subject* is whatever a recording or an image hangs off: a task, a
/// project, an event, a person. All of them can own an agent, all of them can
/// carry an inherited `profileId`, and all of them belong to a category — so
/// none of this resolution is task-shaped, and pinning it to tasks is what
/// left a spoken check-in with no profile to transcribe through.
///
/// Wraps [ProfileResolver] with the extra step of looking up the subject's
/// agent identity, template, and version — then delegates to
/// [ProfileResolver.resolve()] to use the same resolution chain as agent
/// wakes.
///
/// When the agent path yields no result (no agent, no template, etc.) but the
/// subject carries an inherited `profileId` (from its category), the resolver
/// falls back to direct profile resolution via
/// [ProfileResolver.resolveByProfileId].
///
/// Standalone entries (audio notes, image notes) skip the subject and resolve
/// directly via [resolveForCategory], reading the category's
/// `defaultProfileId`.
///
/// Returns `null` if no profile can be resolved through any path.
///
/// [resolveForSubject] answers "which profile drives this entity's agent".
/// That is the right question for the thinking route and the wrong one for
/// automated capabilities, which is what [resolveAutomationFallbacks] exists
/// for.
class ProfileAutomationResolver {
  const ProfileAutomationResolver({
    required this._subjectAgentLookup,
    required this._templateService,
    required this._profileResolver,
    this._subjectProfileLookup,
    this._categoryProfileLookup,
    this._subjectCategoryLookup,
  });

  final SubjectAgentLookup _subjectAgentLookup;
  final AgentTemplateService _templateService;
  final ProfileResolver _profileResolver;
  final SubjectProfileLookup? _subjectProfileLookup;
  final CategoryProfileLookup? _categoryProfileLookup;
  final SubjectCategoryLookup? _subjectCategoryLookup;

  /// Resolves the profile for the given [subjectId]'s agent.
  ///
  /// Resolution order:
  /// 1. Agent path: `agentConfig.profileId ?? version.profileId ??
  ///    template.profileId` → legacy `modelId` fallback.
  /// 2. Subject fallback: the entity's own `profileId` (inherited from its
  ///    category).
  Future<ResolvedProfile?> resolveForSubject(String subjectId) async {
    // 1. Try agent-based resolution.
    final agentResult = await _resolveViaAgent(subjectId);
    if (agentResult != null) return agentResult;

    // 2. Fall back to the subject's own profileId (inherited from category).
    return _resolveViaSubjectProfile(subjectId);
  }

  /// Profiles that can supply an automated capability [resolveForSubject] does
  /// not own, most specific first and without duplicates.
  ///
  /// The agent's profile drives the *thinking* route, and picking a thinking
  /// model by hand resolves to a bare model route — no capability slots, no
  /// skill assignments at all. Treating that as the last word switches the
  /// category's automatic transcription and image analysis off as a side
  /// effect of a model choice, and no later model change brings them back.
  /// The same hole opens for a subject created before its category had a
  /// default profile, and for a profile that carries a thinking model but not
  /// every capability the category configured.
  ///
  /// Order:
  /// 1. The subject's own `profileId` (inherited from the category at
  ///    creation).
  /// 2. The owning category's current `defaultProfileId`.
  ///
  /// Callers walk this list *per capability* and take the first profile that
  /// actually owns the slot they need, so a profile deliberately chosen for
  /// this subject still wins every capability it does own.
  ///
  /// Profiles that cannot be loaded are skipped rather than ending the walk.
  Future<List<ResolvedProfile>> resolveAutomationFallbacks(
    String subjectId,
  ) async {
    final candidateProfileIds = <String>{};

    final subjectProfileId = await _subjectProfileLookup?.call(subjectId);
    if (subjectProfileId != null) candidateProfileIds.add(subjectProfileId);

    final categoryId = await _subjectCategoryLookup?.call(subjectId);
    if (categoryId != null) {
      final categoryProfileId = await _categoryProfileLookup?.call(categoryId);
      if (categoryProfileId != null) candidateProfileIds.add(categoryProfileId);
    }

    final resolved = <ResolvedProfile>[];
    for (final profileId in candidateProfileIds) {
      final profile = await _profileResolver.resolveByProfileId(profileId);
      if (profile == null) {
        developer.log(
          'Automation fallback profile $profileId for subject $subjectId '
          'could not be resolved — skipping',
          name: _logTag,
        );
        continue;
      }
      resolved.add(profile);
    }
    return resolved;
  }

  /// Returns the raw profile id for [subjectId] using the same resolution
  /// chain as [resolveForSubject], but without invoking [ProfileResolver] —
  /// callers (the synced-audio dispatcher) need the underlying inference
  /// profile directly so they can read `pinnedHostId` and run
  /// `profileIsLocal`, both of which the resolved view either hides or
  /// silently distorts (unresolved optional slots become null on the resolved
  /// view, masking referenced cloud configs).
  ///
  /// Order (identical to [resolveForSubject], minus the legacy `modelId`
  /// fallback — `modelId` resolves to a model, not a profile, so it can't
  /// carry pin/locality data and is intentionally out of scope here):
  /// 1. Agent path: `agentConfig.profileId ?? version.profileId ??
  ///    template.profileId`.
  /// 2. Subject fallback: the entity's own `profileId`.
  ///
  /// Mirrors [resolveForSubject] but returns the raw profile id.
  ///
  /// Returns `null` when neither path yields a profile id.
  Future<String?> resolveProfileIdForSubject(String subjectId) async {
    final agentProfileId = await _resolveProfileIdViaAgent(subjectId);
    if (agentProfileId != null) return agentProfileId;

    final lookup = _subjectProfileLookup;
    if (lookup == null) return null;
    final subjectProfileId = await lookup(subjectId);
    if (subjectProfileId != null) {
      developer.log(
        'resolveProfileIdForSubject: using subject-level profileId '
        '$subjectProfileId for subject $subjectId',
        name: _logTag,
      );
    }
    return subjectProfileId;
  }

  Future<String?> _resolveProfileIdViaAgent(String subjectId) async {
    final agent = await _subjectAgentLookup(subjectId);
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

  Future<ResolvedProfile?> _resolveViaAgent(String subjectId) async {
    final agent = await _subjectAgentLookup(subjectId);
    if (agent == null) {
      developer.log(
        'No agent found for subject $subjectId',
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

  Future<ResolvedProfile?> _resolveViaSubjectProfile(String subjectId) async {
    final lookup = _subjectProfileLookup;
    if (lookup == null) return null;

    final profileId = await lookup(subjectId);
    if (profileId == null) {
      developer.log(
        'No subject-level profileId for subject $subjectId',
        name: _logTag,
      );
      return null;
    }

    developer.log(
      'Using subject-level profileId $profileId for subject $subjectId',
      name: _logTag,
    );
    return _profileResolver.resolveByProfileId(profileId);
  }
}
