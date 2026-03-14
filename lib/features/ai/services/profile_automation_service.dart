import 'dart:developer' as developer;

import 'package:lotti/features/ai/helpers/profile_automation_resolver.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/model/skill_assignment.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';

const _logTag = 'ProfileAutomationService';

/// Result of a profile-driven automation attempt.
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
  final ResolvedProfile? resolvedProfile;

  /// The skill definition (available when [handled] is `true`).
  final AiConfigSkill? skill;

  /// The matching skill assignment (available when [handled] is `true`).
  final SkillAssignment? skillAssignment;

  static const notHandled = AutomationResult(handled: false);
}

/// Service for profile-driven automation of AI tasks.
///
/// Resolves the profile for a task's agent and checks whether a matching
/// skill assignment with `automate: true` exists. Returns an
/// [AutomationResult] that tells the caller whether the profile-driven
/// path handled the request.
///
/// The actual inference invocation is left to the caller (e.g., the
/// trigger in Phase 5), which uses the returned skill and profile to
/// build prompts via `SkillPromptBuilder` and invoke inference.
class ProfileAutomationService {
  const ProfileAutomationService({
    required ProfileAutomationResolver resolver,
    required AiConfigRepository aiConfigRepository,
  }) : _resolver = resolver,
       _aiConfigRepository = aiConfigRepository;

  final ProfileAutomationResolver _resolver;
  final AiConfigRepository _aiConfigRepository;

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

    return _tryAutomateSkillType(
      taskId: taskId,
      skillType: SkillType.transcription,
    );
  }

  /// Attempts profile-driven image analysis for a task.
  ///
  /// Returns [AutomationResult.handled] = `true` if an image analysis skill
  /// with `automate: true` was found on the task's agent's profile.
  Future<AutomationResult> tryAnalyzeImage({
    required String taskId,
  }) async {
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
    final result = await _tryAutomateSkillType(
      taskId: taskId,
      skillType: skillType,
    );
    return result.handled;
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
