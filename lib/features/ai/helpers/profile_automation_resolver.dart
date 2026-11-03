import 'package:lotti/classes/agents/agent_config.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/util/profile_resolver.dart';
import 'package:lotti/services/domain_logging.dart';

const _logTag = 'ProfileAutomationResolver';

/// The agent assigned to a subject (a task, a project, a person), or null.
typedef AutomationSubjectAgentLookup =
    Future<AgentIdentityEntity?> Function(String subjectId);

/// The template lookups profile resolution needs. The agents feature's
/// `AgentTemplateService` implements it, so this resolver reads templates
/// without depending on that feature.
abstract interface class AgentTemplateVersionLookup {
  /// The template assigned to [agentId], or null.
  Future<AgentTemplateEntity?> getTemplateForAgent(String agentId);

  /// The active version of the template [templateId], or null.
  Future<AgentTemplateVersionEntity?> getActiveVersion(String templateId);
}

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
    required this._domainLogger,
    this._subjectProfileLookup,
    this._categoryProfileLookup,
    this._subjectCategoryLookup,
  });

  final AutomationSubjectAgentLookup _subjectAgentLookup;
  final AgentTemplateVersionLookup _templateService;
  final ProfileResolver _profileResolver;

  /// Receives the resolution traces.
  final DomainLogger _domainLogger;

  final SubjectProfileLookup? _subjectProfileLookup;
  final CategoryProfileLookup? _categoryProfileLookup;
  final SubjectCategoryLookup? _subjectCategoryLookup;

  /// The device's selected Settings default profile, or null when none is
  /// selected or it cannot resolve.
  Future<ResolvedProfile?> resolveDefaultProfile() =>
      _profileResolver.resolveDefaultProfile();

  /// The profile a recording about [subjectId], filed under [categoryId],
  /// transcribes through — the first of these that owns a transcription slot:
  ///
  /// 1. the profile assigned to [subjectId]'s agent (`agentConfig.profileId
  ///    ?? version.profileId ?? template.profileId`);
  /// 2. [subjectId]'s own `profileId` (a person's, inherited at creation);
  /// 3. [categoryId]'s default profile — [subjectId]'s category when
  ///    [categoryId] is null;
  /// 4. the device's Settings default.
  ///
  /// Null when none can transcribe.
  ///
  /// The one rule every recording without a task follows — a goal's
  /// check-in, a person's, a voice note in a category, and the dictation
  /// into their chats — so the model and its settings always come from a
  /// profile the user configured, never from a model picked by provider type
  /// behind their back. A profile that resolves but names no transcription
  /// model is passed over like a missing one: it cannot transcribe either.
  ///
  /// The agent comes first because assigning it a profile is the most
  /// specific choice the user makes: a goal agent set to a cloud profile
  /// whose category, or whose Settings default, names an on-device or a
  /// different cloud model used to transcribe on that one instead — a goal
  /// filed in no category never even reached the agent's profile.
  ///
  /// Silent: render-time probes ask it on every rebuild. The run paths that
  /// act on its answer log which profile they transcribe through.
  Future<ResolvedProfile?> resolveTranscriptionProfile({
    String? subjectId,
    String? categoryId,
  }) async {
    final candidateProfileIds = <String>[];
    String? subjectCategoryId;
    if (subjectId != null) {
      final agentProfileId = await _readSubjectTier(
        subjectId,
        'agent profile',
        () => _agentTranscriptionProfileId(subjectId),
      );
      if (agentProfileId != null) candidateProfileIds.add(agentProfileId);
      final subjectProfileId = await _readSubjectTier(
        subjectId,
        'own profile',
        () async => _subjectProfileLookup?.call(subjectId),
      );
      if (subjectProfileId != null) candidateProfileIds.add(subjectProfileId);
      if (categoryId == null) {
        subjectCategoryId = await _readSubjectTier(
          subjectId,
          'category',
          () => categoryOfSubject(subjectId),
        );
      }
    }
    final effectiveCategoryId = categoryId ?? subjectCategoryId;
    if (effectiveCategoryId != null) {
      final categoryProfileId = await _categoryProfileLookup?.call(
        effectiveCategoryId,
      );
      if (categoryProfileId != null) candidateProfileIds.add(categoryProfileId);
    }

    final asked = <String>{};
    for (final profileId in candidateProfileIds) {
      if (!asked.add(profileId)) continue;
      final profile = _transcribing(
        await _profileResolver.resolveByProfileId(profileId),
      );
      if (profile != null) return profile;
    }
    return _transcribing(await resolveDefaultProfile());
  }

  /// One subject tier of [resolveTranscriptionProfile], read by [read]; null
  /// — the tier passed over — when the read throws.
  ///
  /// A subject whose agent or journal row cannot be read must still reach
  /// the category's profile and the Settings default: People check-ins have
  /// always transcribed through the default when the person could not be
  /// read, and the subject tiers must not take that away.
  Future<String?> _readSubjectTier(
    String subjectId,
    String tier,
    Future<String?> Function() read,
  ) async {
    try {
      return await read();
    } catch (error, stackTrace) {
      _domainLogger.error(
        LogDomain.ai,
        error,
        stackTrace: stackTrace,
        subDomain: _logTag,
        message:
            'Could not read the $tier of subject '
            '${DomainLogger.sanitizeId(subjectId)} for its transcription '
            'profile — passing over that tier',
      );
      return null;
    }
  }

  /// The category [subjectId] is filed under, or null when it has none or
  /// no lookup is wired.
  Future<String?> categoryOfSubject(String subjectId) async =>
      _subjectCategoryLookup?.call(subjectId);

  static ResolvedProfile? _transcribing(ResolvedProfile? profile) =>
      profile?.transcriptionModelId == null ||
          profile?.transcriptionProvider == null
      ? null
      : profile;

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
        _domainLogger.log(
          LogDomain.ai,
          'Automation fallback profile $profileId for subject $subjectId '
          'could not be resolved — skipping',
          subDomain: _logTag,
          level: InsightLevel.warn,
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
      _domainLogger.log(
        LogDomain.ai,
        'resolveProfileIdForSubject: using subject-level profileId '
        '$subjectProfileId for subject $subjectId',
        subDomain: _logTag,
      );
    }
    return subjectProfileId;
  }

  /// The profile [subjectId]'s agent is assigned, for the transcription
  /// rule's first tier — or null when it has no agent or no assignment.
  ///
  /// Goal and person agents are standalone: they have no template, and
  /// their profile lives in `AgentConfig` alone. A typed `inferenceSetup` is
  /// authoritative ([AgentConfigAssignedProfile.assignedProfileId]: its base
  /// profile, or nothing when it is disabled); only an agent without one
  /// keeps the legacy chain, ending on its template's profile when it has a
  /// template at all.
  Future<String?> _agentTranscriptionProfileId(String subjectId) async {
    final agent = await _subjectAgentLookup(subjectId);
    if (agent == null) return null;
    final config = agent.config;
    if (config.inferenceSetup != null) return config.assignedProfileId;
    final assigned = config.assignedProfileId;
    if (assigned != null) return assigned;

    final template = await _templateService.getTemplateForAgent(agent.agentId);
    if (template == null) return null;
    final version = await _templateService.getActiveVersion(template.id);
    return version?.profileId ?? template.profileId;
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
      _domainLogger.log(
        LogDomain.ai,
        'No defaultProfileId for category $categoryId',
        subDomain: _logTag,
      );
      return null;
    }

    _domainLogger.log(
      LogDomain.ai,
      'Using category defaultProfileId $profileId for category $categoryId',
      subDomain: _logTag,
    );
    return _profileResolver.resolveByProfileId(profileId);
  }

  Future<ResolvedProfile?> _resolveViaAgent(String subjectId) async {
    final agent = await _subjectAgentLookup(subjectId);
    if (agent == null) {
      _domainLogger.log(
        LogDomain.ai,
        'No agent found for subject $subjectId',
        subDomain: _logTag,
      );
      return null;
    }

    final template = await _templateService.getTemplateForAgent(agent.agentId);
    if (template == null) {
      // A goal's or a person's agent has no template: its setup, or its own
      // profile, is the whole assignment. Reading nothing here let a
      // category's automated skill win over the agent's chosen profile.
      final standalone = await _resolveStandaloneAgent(agent.config);
      if (standalone == null) {
        _domainLogger.log(
          LogDomain.ai,
          'No template and no assigned profile for agent ${agent.agentId}',
          subDomain: _logTag,
        );
      }
      return standalone?.forAgent(
        agentId: agent.agentId,
        agentName: agent.displayName,
      );
    }

    final version = await _templateService.getActiveVersion(template.id);
    if (version == null) {
      _domainLogger.log(
        LogDomain.ai,
        'No active version for template ${template.id}',
        subDomain: _logTag,
      );
      return null;
    }

    final profile = await _profileResolver.resolve(
      agentConfig: agent.config,
      template: template,
      version: version,
    );
    return profile?.forAgent(
      agentId: agent.agentId,
      agentName: agent.displayName,
    );
  }

  /// The profile a template-less agent is assigned: its typed setup's, which
  /// is authoritative (a disabled or broken one yields nothing), else its own
  /// legacy `profileId`. No Settings default here — the callers' fallbacks
  /// decide what comes after the agent.
  Future<ResolvedProfile?> _resolveStandaloneAgent(AgentConfig config) async {
    final setup = config.inferenceSetup;
    if (setup != null) {
      return (await _profileResolver.resolveSetup(setup)).profile;
    }
    final profileId = config.assignedProfileId;
    return profileId == null
        ? null
        : _profileResolver.resolveByProfileId(profileId);
  }

  Future<ResolvedProfile?> _resolveViaSubjectProfile(String subjectId) async {
    final lookup = _subjectProfileLookup;
    if (lookup == null) return null;

    final profileId = await lookup(subjectId);
    if (profileId == null) {
      _domainLogger.log(
        LogDomain.ai,
        'No subject-level profileId for subject $subjectId',
        subDomain: _logTag,
      );
      return null;
    }

    _domainLogger.log(
      LogDomain.ai,
      'Using subject-level profileId $profileId for subject $subjectId',
      subDomain: _logTag,
    );
    return _profileResolver.resolveByProfileId(profileId);
  }
}
