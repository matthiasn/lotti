import 'dart:developer' as developer;

import 'package:lotti/features/ai/constants/provider_config.dart';
import 'package:lotti/features/ai/helpers/profile_automation_resolver.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/model/skill_assignment.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/skills/built_in_skills.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/utils/platform.dart' as platform;

const _logTag = 'ProfileAutomationService';
const _fallbackTranscriptionAssignment = SkillAssignment(
  skillId: skillTranscribeContextId,
  automate: true,
);

typedef _TranscriptionFallbackCandidate = ({
  AiConfigModel model,
  AiConfigInferenceProvider provider,
});

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
  });

  final ProfileAutomationResolver _resolver;
  final AiConfigRepository _aiConfigRepository;
  final CategoryAutomationLookup? _categoryAutomationLookup;

  /// The single consent gate for running inference without a user gesture.
  ///
  /// Both automation paths pass through here — the profile path and the
  /// direct-model transcription fallback — because the fallback would
  /// otherwise transcribe for any configured speech-to-text model with no
  /// opt-in at all. Selecting a profile is not consent: seeded profiles ship
  /// `automate: true` assignments, so the category switch is the only place
  /// the user actually says yes.
  Future<bool> _categoryAllowsAutomation(String taskId) async {
    final lookup = _categoryAutomationLookup;
    if (lookup == null) {
      developer.log(
        'No category automation lookup wired — treating automation as off '
        'for task $taskId',
        name: _logTag,
      );
      return false;
    }
    final allowed = await lookup(taskId);
    if (!allowed) {
      developer.log(
        'Automatic inference is off for the category owning task $taskId',
        name: _logTag,
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
      return AutomationResult.notHandled;
    }

    if (!await _categoryAllowsAutomation(taskId)) {
      return AutomationResult.notHandled;
    }

    final profileResult = await _tryAutomateSkillType(
      taskId: taskId,
      skillType: SkillType.transcription,
    );
    if (profileResult.handled) return profileResult;

    return _tryDirectTranscriptionFallback();
  }

  /// Attempts profile-driven image analysis for a task.
  ///
  /// Returns [AutomationResult.handled] = `true` if an image analysis skill
  /// with `automate: true` was found on the task's agent's profile.
  Future<AutomationResult> tryAnalyzeImage({
    required String taskId,
  }) async {
    if (!await _categoryAllowsAutomation(taskId)) {
      return AutomationResult.notHandled;
    }
    return _tryAutomateSkillType(
      taskId: taskId,
      skillType: SkillType.imageAnalysis,
    );
  }

  /// Core resolution: find a matching skill assignment with `automate: true`
  /// for the given [skillType] on the task's agent's profile.
  Future<AutomationResult> _tryAutomateSkillType({
    required String taskId,
    required SkillType skillType,
  }) async {
    // 1. Resolve the profile for the task's agent.
    final resolvedProfile = await _resolver.resolveForTask(taskId);
    if (resolvedProfile == null) {
      return AutomationResult.notHandled;
    }

    // 2. Collect all automated skill assignments matching the requested type.
    final matches = <({SkillAssignment assignment, AiConfigSkill skill})>[];

    for (final assignment in resolvedProfile.skillAssignments) {
      if (!assignment.automate) continue;

      final skillConfig = await _aiConfigRepository.getConfigById(
        assignment.skillId,
      );
      if (skillConfig is! AiConfigSkill) {
        developer.log(
          'Skill ${assignment.skillId} not found or wrong type',
          name: _logTag,
        );
        continue;
      }

      if (skillConfig.skillType != skillType) continue;

      // Verify the profile has the required model slot populated.
      if (!_hasModelSlotForSkillType(resolvedProfile, skillType)) {
        developer.log(
          'Profile has no model slot for $skillType, skipping skill '
          '${skillConfig.name}',
          name: _logTag,
        );
        continue;
      }

      matches.add((assignment: assignment, skill: skillConfig));
    }

    if (matches.isEmpty) return AutomationResult.notHandled;

    // 3. Reject ambiguous profiles with multiple automated skills of the
    //    same type — the context policy could differ silently.
    if (matches.length > 1) {
      developer.log(
        'Ambiguous profile: ${matches.length} automated $skillType '
        'skills found for task $taskId, treating as not handled',
        name: _logTag,
      );
      return AutomationResult.notHandled;
    }

    final match = matches.first;
    developer.log(
      'Profile automation: using skill "${match.skill.name}" for '
      '$skillType on task $taskId',
      name: _logTag,
    );

    return AutomationResult(
      handled: true,
      resolvedProfile: resolvedProfile,
      skill: match.skill,
      skillAssignment: match.assignment,
    );
  }

  /// Checks whether the given task has an automated skill of the given type.
  ///
  /// Convenience wrapper around [_tryAutomateSkillType] for use by checkbox
  /// visibility providers that only need a boolean answer.
  Future<bool> hasAutomatedSkillType({
    required String taskId,
    required SkillType skillType,
  }) async {
    // Mirrors the gate the run paths apply, so an affordance never advertises
    // automation the category has switched off.
    if (!await _categoryAllowsAutomation(taskId)) return false;

    final result = await _tryAutomateSkillType(
      taskId: taskId,
      skillType: skillType,
    );
    if (result.handled) return true;
    if (skillType != SkillType.transcription) return false;

    final fallbackResult = await _tryDirectTranscriptionFallback();
    return fallbackResult.handled;
  }

  /// Whether the direct transcription fallback could run at all — some
  /// configured provider owns a usable speech-to-text model.
  ///
  /// Settings needs this without a task in hand: the fallback transcribes with
  /// no profile involved, so the category's automation switch has something to
  /// control even when the category has no profile selected.
  Future<bool> hasDirectTranscriptionFallback() async {
    final result = await _tryDirectTranscriptionFallback();
    return result.handled;
  }

  /// Finds a configured audio-to-text model that can run transcription without
  /// requiring the task to resolve to an inference profile.
  Future<AutomationResult> _tryDirectTranscriptionFallback() async {
    final skill = findBuiltInSkill(skillTranscribeContextId);
    if (skill == null) return AutomationResult.notHandled;

    final modelConfigs = await _aiConfigRepository.getConfigsByType(
      AiConfigType.model,
    );
    final candidates = <_TranscriptionFallbackCandidate>[];

    for (final model in modelConfigs.whereType<AiConfigModel>()) {
      if (!_isSpeechToTextModel(model)) continue;

      final providerConfig = await _aiConfigRepository.getConfigById(
        model.inferenceProviderId,
      );
      if (providerConfig is! AiConfigInferenceProvider) continue;
      if (_requiresMissingApiKey(providerConfig)) continue;

      candidates.add((model: model, provider: providerConfig));
    }

    if (candidates.isEmpty) return AutomationResult.notHandled;
    candidates.sort(_compareFallbackCandidates);

    final selected = candidates.first;
    developer.log(
      'Using direct transcription fallback model '
      '${selected.model.providerModelId}',
      name: _logTag,
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
