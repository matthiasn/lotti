import 'package:lotti/features/ai/constants/provider_config.dart';
import 'package:lotti/features/ai/helpers/profile_automation_resolver.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/model/skill_assignment.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/skills/built_in_skills.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/platform.dart' as platform;

const _fallbackTranscriptionAssignment = SkillAssignment(
  skillId: skillTranscribeContextId,
  automate: true,
);

typedef _TranscriptionFallbackCandidate = ({
  AiConfigModel model,
  AiConfigInferenceProvider provider,
});

/// The automated skill a profile contributes for one requested skill type.
typedef _AutomatedSkillMatch = ({
  SkillAssignment assignment,
  AiConfigSkill skill,
});

/// Outcome of inspecting a single profile for one skill type.
///
/// An ambiguous outcome is not "no match": it means the profile automates the
/// same skill type more than once, and their context policies could differ
/// silently. That ends the whole walk rather than moving to the next
/// candidate — guessing which of two deliberate assignments the user meant is
/// worse than doing nothing.
typedef _SkillMatchOutcome = ({_AutomatedSkillMatch? match, bool ambiguous});

const _SkillMatchOutcome _noSkillMatch = (match: null, ambiguous: false);
const _SkillMatchOutcome _ambiguousSkillMatch = (match: null, ambiguous: true);

/// Why a resolution walk is running.
///
/// A [probe] answers "should this affordance be visible" from a widget build
/// or a settings screen. It starts no inference, so it must leave no trace: a
/// `resolved` line from a probe reads as an execution record, and decline
/// lines repeated on every rebuild bury the one decision that belongs to the
/// recording actually being diagnosed. Nothing is lost by staying quiet —
/// `automatic_prompt_trigger` calls the [run] path whether or not the
/// checkbox is visible, and that path logs the same decision.
enum _CallIntent { run, probe }

/// Whether the category owning [taskId] has automatic inference switched on.
///
/// Wired to `CategoryDefinition.automaticInferenceEnabledEffective`. An
/// unwired lookup reports `false`: automation is opt-in, so an environment
/// that cannot answer the question must not run inference on its own.
typedef CategoryAutomationLookup = Future<bool> Function(String taskId);

/// Result of an automation attempt.
///
/// When [handled] is `true`, the caller should skip the legacy prompt path.
/// When `false`, the caller should fall through to the existing
/// `category.automaticPrompts` logic.
class AutomationResult {
  const AutomationResult({
    required this.handled,
    this.resolvedProfile,
    this.skill,
    this.skillAssignment,
  });

  /// Whether the profile-driven path handled the request.
  final bool handled;

  /// The resolved profile (available when [handled] is `true`).
  ///
  /// Direct transcription fallback creates an ephemeral profile-shaped value
  /// so the existing skill runner can keep using its profile/model contract
  /// without persisting a new profile row.
  final ResolvedProfile? resolvedProfile;

  /// The skill definition (available when [handled] is `true`).
  final AiConfigSkill? skill;

  /// The matching skill assignment (available when [handled] is `true`).
  final SkillAssignment? skillAssignment;

  static const notHandled = AutomationResult(handled: false);
}

/// Service for profile-driven automation of AI tasks.
///
/// Every entry point is gated on the owning category's automatic-inference
/// switch ([CategoryAutomationLookup]) before any profile is resolved. That
/// switch is the user's only explicit consent to spend tokens without a
/// gesture; picking a profile is not, because seeded profiles arrive with
/// `automate: true` assignments already set.
///
/// Past the gate it resolves the profile for a task's agent and checks whether
/// a matching skill assignment with `automate: true` exists. Returns an
/// [AutomationResult] that tells the caller whether the profile-driven
/// path handled the request.
///
/// Speech recognition has one extra path: if no profile path handles
/// transcription, the service can fall back to a configured audio-to-text model
/// row directly. That keeps mobile/local recording usable when the user has an
/// MLX Audio model configured but cannot pick a desktop-only local profile.
///
/// The actual inference invocation is left to the caller, which uses the
/// returned skill and profile to build prompts via `SkillPromptBuilder` and
/// invoke inference.
class ProfileAutomationService {
  const ProfileAutomationService({
    required this._resolver,
    required this._aiConfigRepository,
    this._categoryAutomationLookup,
    this._domainLogger,
  });

  final ProfileAutomationResolver _resolver;
  final AiConfigRepository _aiConfigRepository;
  final CategoryAutomationLookup? _categoryAutomationLookup;

  /// Where every "did not automate" decision goes.
  ///
  /// This service's whole failure mode is silence: several independent checks
  /// can each decline, and the caller only ever reports the generic "profile
  /// automation did not handle X". Routing the reasons to the app log is what
  /// makes a missing transcript diagnosable from a log export instead of a
  /// code read. Only the run paths write — see [_CallIntent]. Optional so
  /// tests and non-app callers can build the service without a logger.
  final DomainLogger? _domainLogger;

  /// Records why automation declined, under [LogDomain.ai].
  void _logSkip(
    String message, {
    required String subDomain,
    required _CallIntent intent,
  }) {
    if (intent == _CallIntent.probe) return;
    _domainLogger?.log(
      LogDomain.ai,
      message,
      subDomain: subDomain,
    );
  }

  /// Records which profile and skill a run resolved to.
  ///
  /// The counterpart to [_logSkip]: without it a log export shows only the
  /// declines, so "it ran, but with the wrong model" stays as opaque as "it
  /// did not run".
  void _logRun(String message, {required _CallIntent intent}) {
    if (intent == _CallIntent.probe) return;
    _domainLogger?.log(
      LogDomain.ai,
      message,
      subDomain: 'resolved',
    );
  }

  /// The single consent gate for running inference without a user gesture.
  ///
  /// Both automation paths pass through here — the profile path and the
  /// direct-model transcription fallback — because the fallback would
  /// otherwise transcribe for any configured speech-to-text model with no
  /// opt-in at all. Selecting a profile is not consent: seeded profiles ship
  /// `automate: true` assignments, so the category switch is the only place
  /// the user actually says yes.
  Future<bool> _categoryAllowsAutomation(
    String taskId,
    _CallIntent intent,
  ) async {
    final lookup = _categoryAutomationLookup;
    if (lookup == null) {
      _logSkip(
        'no category automation lookup wired — treating automation as off '
        'for task ${DomainLogger.sanitizeId(taskId)}',
        subDomain: 'categoryGate',
        intent: intent,
      );
      return false;
    }
    final allowed = await lookup(taskId);
    if (!allowed) {
      _logSkip(
        'automatic inference is switched off for the category owning task '
        '${DomainLogger.sanitizeId(taskId)}',
        subDomain: 'categoryGate',
        intent: intent,
      );
    }
    return allowed;
  }

  /// Attempts profile-driven transcription for a task.
  ///
  /// Returns [AutomationResult.handled] = `true` if a transcription skill
  /// with `automate: true` was found on the task's agent's profile.
  ///
  /// Respects the user's per-recording opt-out:
  /// - If [enableSpeechRecognition] is `false`, returns not-handled
  ///   immediately (the user explicitly opted out for this recording).
  /// - If `null`, defaults to `true` when a profile-driven transcription
  ///   skill is available with `automate: true`.
  Future<AutomationResult> tryTranscribe({
    required String taskId,
    bool? enableSpeechRecognition,
  }) async {
    // User explicitly opted out for this recording.
    if (enableSpeechRecognition == false) {
      _logSkip(
        'speech recognition was switched off for this recording on task '
        '${DomainLogger.sanitizeId(taskId)}',
        subDomain: 'perRecordingOptOut',
        intent: _CallIntent.run,
      );
      return AutomationResult.notHandled;
    }

    if (!await _categoryAllowsAutomation(taskId, _CallIntent.run)) {
      return AutomationResult.notHandled;
    }

    final profileResult = await _tryAutomateSkillType(
      taskId: taskId,
      skillType: SkillType.transcription,
      intent: _CallIntent.run,
    );
    if (profileResult.handled) return profileResult;

    return _tryDirectTranscriptionFallback(_CallIntent.run);
  }

  /// Attempts profile-driven image analysis for a task.
  ///
  /// Returns [AutomationResult.handled] = `true` if an image analysis skill
  /// with `automate: true` was found on the task's agent's profile.
  Future<AutomationResult> tryAnalyzeImage({
    required String taskId,
  }) async {
    if (!await _categoryAllowsAutomation(taskId, _CallIntent.run)) {
      return AutomationResult.notHandled;
    }
    return _tryAutomateSkillType(
      taskId: taskId,
      skillType: SkillType.imageAnalysis,
      intent: _CallIntent.run,
    );
  }

  /// Core resolution: find the profile that automates [skillType] for [taskId]
  /// and the assignment that does it.
  ///
  /// Walks the task's profiles per capability, most specific first: the
  /// profile driving the task's agent, then the profiles the task inherits
  /// ([ProfileAutomationResolver.resolveAutomationFallbacks]). The first one
  /// that both automates [skillType] and has the matching model slot
  /// populated wins.
  ///
  /// The walk is what keeps a hand-picked thinking model from switching the
  /// category's automation off: that choice resolves to a bare model route
  /// carrying no capability slots and no skill assignments, so transcription
  /// and image analysis fall through to the profile the task inherited from
  /// its category instead of silently not running. Automation the agent's own
  /// profile does own is unaffected — it matches on the first candidate and
  /// the fallbacks are never consulted.
  Future<AutomationResult> _tryAutomateSkillType({
    required String taskId,
    required SkillType skillType,
    required _CallIntent intent,
  }) async {
    final primaryProfile = await _resolver.resolveForTask(taskId);
    if (primaryProfile == null) {
      _logSkip(
        'no profile resolves for task ${DomainLogger.sanitizeId(taskId)} — '
        'trying the profiles it inherits for $skillType',
        subDomain: 'profileResolution',
        intent: intent,
      );
    } else {
      final outcome = await _matchAutomatedSkill(
        profile: primaryProfile,
        skillType: skillType,
        taskId: taskId,
        intent: intent,
      );
      if (outcome.ambiguous) return AutomationResult.notHandled;
      final match = outcome.match;
      if (match != null) {
        _logRun(
          'running $skillType on task ${DomainLogger.sanitizeId(taskId)} '
          'with skill "${match.skill.name}" from the task-linked profile',
          intent: intent,
        );
        return AutomationResult(
          handled: true,
          resolvedProfile: primaryProfile,
          skill: match.skill,
          skillAssignment: match.assignment,
        );
      }
    }

    final fallbacks = await _resolver.resolveAutomationFallbacks(taskId);
    for (final fallbackProfile in fallbacks) {
      final outcome = await _matchAutomatedSkill(
        profile: fallbackProfile,
        skillType: skillType,
        taskId: taskId,
        intent: intent,
      );
      if (outcome.ambiguous) return AutomationResult.notHandled;
      final match = outcome.match;
      if (match == null) continue;

      _logRun(
        'task ${DomainLogger.sanitizeId(taskId)} does not own $skillType — '
        'falling back to the inherited profile, skill "${match.skill.name}"',
        intent: intent,
      );
      return AutomationResult(
        handled: true,
        resolvedProfile: fallbackProfile,
        skill: match.skill,
        skillAssignment: match.assignment,
      );
    }

    _logSkip(
      'no profile automates $skillType for task '
      '${DomainLogger.sanitizeId(taskId)} — walked '
      '${primaryProfile == null ? 0 : 1} task-linked and '
      '${fallbacks.length} inherited profile(s)',
      subDomain: 'profileResolution',
      intent: intent,
    );
    return AutomationResult.notHandled;
  }

  /// Inspects one [profile] for an automated skill of [skillType].
  ///
  /// A match requires all three: an assignment with `automate: true`, a skill
  /// config of the requested type behind it, and the profile's matching model
  /// slot populated — a profile that automates transcription without a
  /// transcription model cannot run it.
  Future<_SkillMatchOutcome> _matchAutomatedSkill({
    required ResolvedProfile profile,
    required SkillType skillType,
    required String taskId,
    required _CallIntent intent,
  }) async {
    final matches = <_AutomatedSkillMatch>[];

    for (final assignment in profile.skillAssignments) {
      if (!assignment.automate) continue;

      final skillConfig = await _aiConfigRepository.getConfigById(
        assignment.skillId,
      );
      if (skillConfig is! AiConfigSkill) {
        _logSkip(
          'skill ${DomainLogger.sanitizeId(assignment.skillId)} is automated '
          'on the profile but its config is missing or not a skill — '
          'ignoring it for $skillType on task '
          '${DomainLogger.sanitizeId(taskId)}',
          subDomain: 'skillMatch',
          intent: intent,
        );
        continue;
      }

      if (skillConfig.skillType != skillType) continue;

      if (!_hasModelSlotForSkillType(profile, skillType)) {
        _logSkip(
          'profile automates $skillType via "${skillConfig.name}" but its '
          '$skillType model slot is empty or unresolvable — skipping it for '
          'task ${DomainLogger.sanitizeId(taskId)}',
          subDomain: 'skillMatch',
          intent: intent,
        );
        continue;
      }

      matches.add((assignment: assignment, skill: skillConfig));
    }

    if (matches.isEmpty) return _noSkillMatch;

    if (matches.length > 1) {
      _logSkip(
        'ambiguous profile: ${matches.length} automated $skillType skills for '
        'task ${DomainLogger.sanitizeId(taskId)} — declining rather than '
        'guessing which one was meant',
        subDomain: 'skillMatch',
        intent: intent,
      );
      return _ambiguousSkillMatch;
    }

    return (match: matches.first, ambiguous: false);
  }

  /// Checks whether the given task has an automated skill of the given type.
  ///
  /// Convenience wrapper around [_tryAutomateSkillType] for use by checkbox
  /// visibility providers that only need a boolean answer.
  ///
  /// Runs as a [_CallIntent.probe]: this is a render-time question, so it
  /// leaves the log alone rather than fabricating execution records on every
  /// rebuild.
  Future<bool> hasAutomatedSkillType({
    required String taskId,
    required SkillType skillType,
  }) async {
    // Mirrors the gate the run paths apply, so an affordance never advertises
    // automation the category has switched off.
    if (!await _categoryAllowsAutomation(taskId, _CallIntent.probe)) {
      return false;
    }

    final result = await _tryAutomateSkillType(
      taskId: taskId,
      skillType: skillType,
      intent: _CallIntent.probe,
    );
    if (result.handled) return true;
    if (skillType != SkillType.transcription) return false;

    final fallbackResult = await _tryDirectTranscriptionFallback(
      _CallIntent.probe,
    );
    return fallbackResult.handled;
  }

  /// Whether the direct transcription fallback could run at all — some
  /// configured provider owns a usable speech-to-text model.
  ///
  /// Settings needs this without a task in hand: the fallback transcribes with
  /// no profile involved, so the category's automation switch has something to
  /// control even when the category has no profile selected.
  ///
  /// Runs as a [_CallIntent.probe] — settings asks this to decide whether to
  /// render a switch, not to transcribe anything.
  Future<bool> hasDirectTranscriptionFallback() async {
    final result = await _tryDirectTranscriptionFallback(_CallIntent.probe);
    return result.handled;
  }

  /// Finds a configured audio-to-text model that can run transcription without
  /// requiring the task to resolve to an inference profile.
  ///
  /// Declines out loud. The profile walk's own decline only reports that no
  /// profile automates transcription, which is the less interesting half when
  /// the user *has* configured a speech-to-text model and it was rejected for
  /// a missing provider or API key — so the tallies below name that instead of
  /// leaving the fallback's failure invisible.
  Future<AutomationResult> _tryDirectTranscriptionFallback(
    _CallIntent intent,
  ) async {
    // Unreachable in practice: the transcribe skill is a compile-time entry in
    // `builtInSkills`. No decline log here — it would be untestable.
    final skill = findBuiltInSkill(skillTranscribeContextId);
    if (skill == null) return AutomationResult.notHandled;

    final modelConfigs = await _aiConfigRepository.getConfigsByType(
      AiConfigType.model,
    );
    final candidates = <_TranscriptionFallbackCandidate>[];
    var speechModelCount = 0;
    var withoutProvider = 0;
    var withoutApiKey = 0;

    for (final model in modelConfigs.whereType<AiConfigModel>()) {
      if (!_isSpeechToTextModel(model)) continue;
      speechModelCount++;

      final providerConfig = await _aiConfigRepository.getConfigById(
        model.inferenceProviderId,
      );
      if (providerConfig is! AiConfigInferenceProvider) {
        withoutProvider++;
        continue;
      }
      if (_requiresMissingApiKey(providerConfig)) {
        withoutApiKey++;
        continue;
      }

      candidates.add((model: model, provider: providerConfig));
    }

    if (candidates.isEmpty) {
      _logSkip(
        speechModelCount == 0
            ? 'no speech-to-text model is configured — the direct '
                  'transcription fallback has nothing to run'
            : 'all $speechModelCount configured speech-to-text model(s) were '
                  'rejected: $withoutProvider without a resolvable provider, '
                  '$withoutApiKey missing an API key',
        subDomain: 'directFallback',
        intent: intent,
      );
      return AutomationResult.notHandled;
    }
    candidates.sort(_compareFallbackCandidates);

    final selected = candidates.first;
    _logRun(
      // Not `providerModelId` / `name`: both are free-text fields the user
      // types, so they can carry private hostnames, deployment names or
      // repository paths. The config id plus the provider type identifies the
      // row for support without exporting anything user-authored.
      'no profile owns transcription — using the direct fallback model '
      '${DomainLogger.sanitizeId(selected.model.id)} on provider type '
      '${selected.provider.inferenceProviderType.name}',
      intent: intent,
    );

    return AutomationResult(
      handled: true,
      resolvedProfile: ResolvedProfile(
        // The transcription runner only consumes the transcription slot. Keep
        // the required thinking fields populated with the same provider so the
        // profile-shaped contract remains valid without creating a DB profile.
        thinkingModelId: selected.model.providerModelId,
        thinkingProvider: selected.provider,
        thinkingModel: selected.model,
        transcriptionModelId: selected.model.providerModelId,
        transcriptionProvider: selected.provider,
        transcriptionModel: selected.model,
        skillAssignments: const [_fallbackTranscriptionAssignment],
      ),
      skill: skill,
      skillAssignment: _fallbackTranscriptionAssignment,
    );
  }

  bool _isSpeechToTextModel(AiConfigModel model) {
    return model.inputModalities.contains(Modality.audio) &&
        model.outputModalities.contains(Modality.text);
  }

  bool _requiresMissingApiKey(AiConfigInferenceProvider provider) {
    return ProviderConfig.requiresApiKey(provider.inferenceProviderType) &&
        provider.apiKey.trim().isEmpty;
  }

  int _compareFallbackCandidates(
    _TranscriptionFallbackCandidate left,
    _TranscriptionFallbackCandidate right,
  ) {
    final rankComparison = _fallbackCandidateRank(
      left,
    ).compareTo(_fallbackCandidateRank(right));
    if (rankComparison != 0) return rankComparison;
    return left.model.name.compareTo(right.model.name);
  }

  int _fallbackCandidateRank(_TranscriptionFallbackCandidate candidate) {
    final type = candidate.provider.inferenceProviderType;
    final providerModelId = candidate.model.providerModelId;

    if (type == InferenceProviderType.mlxAudio) {
      // The MLX Audio native bridge ships only on macOS — see
      // lib/features/ai/util/mlx_audio_channel.dart. Invoking it from any
      // other platform throws an "unsupported" PlatformException, so demote
      // MLX rows past every cloud and local non-MLX candidate instead of
      // letting them top the ranking. Audio recorded on mobile reaches MLX
      // through the synced-audio auto-trigger on a paired desktop, not via
      // this direct fallback.
      if (!platform.isMacOS) return 100;
      if (providerModelId == mlxAudioRecommendedSttModelId) return 0;
      if (isMlxAudioQwenAsrModelId(providerModelId)) return 1;
      return 2;
    }
    if (type == InferenceProviderType.mistral) return 3;
    if (type == InferenceProviderType.melious) return 4;
    if (type == InferenceProviderType.openAi) return 5;
    if (type == InferenceProviderType.whisper) return 6;
    if (type == InferenceProviderType.voxtral) return 7;
    return 10;
  }

  /// Checks whether the resolved profile has a model slot populated for
  /// the given skill type.
  bool _hasModelSlotForSkillType(
    ResolvedProfile profile,
    SkillType skillType,
  ) {
    return switch (skillType) {
      SkillType.transcription => profile.transcriptionProvider != null,
      SkillType.imageAnalysis => profile.imageRecognitionProvider != null,
      SkillType.imageGeneration => profile.imageGenerationProvider != null,
      SkillType.promptGeneration => true, // uses thinking model
      SkillType.imagePromptGeneration => true, // uses thinking model
    };
  }
}
