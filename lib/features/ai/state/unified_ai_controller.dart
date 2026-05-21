// ignore_for_file: specify_nonobvious_property_types

import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/repository/unified_ai_inference_repository.dart';
import 'package:lotti/features/ai/services/profile_automation_service.dart';
import 'package:lotti/features/ai/services/skill_inference_runner.dart';
import 'package:lotti/features/ai/skills/built_in_skills.dart';
import 'package:lotti/features/ai/state/active_inference_controller.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/util/ai_error_utils.dart';
import 'package:lotti/features/ai/util/image_processing_utils.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart' show journalDbProvider;
import 'package:lotti/services/logging_service.dart';

/// State object for unified AI inference
@immutable
class UnifiedAiState {
  const UnifiedAiState({
    required this.message,
    this.error,
  });

  final String message;
  final Exception? error;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnifiedAiState &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          error == other.error;

  @override
  int get hashCode => message.hashCode ^ error.hashCode;
}

/// Record type for unified AI controller parameters.
typedef UnifiedAiParams = ({String entityId, String promptId});

/// Controller for running unified AI inference with configurable prompts
/// Note: keepAlive prevents auto-dispose during async operations in catch blocks,
/// ensuring error state persists until the widget can read it.
final unifiedAiControllerProvider =
    NotifierProvider.family<
      UnifiedAiController,
      UnifiedAiState,
      UnifiedAiParams
    >(
      UnifiedAiController.new,
    );

class UnifiedAiController extends Notifier<UnifiedAiState> {
  UnifiedAiController(this._params);

  final UnifiedAiParams _params;

  @override
  UnifiedAiState build() => const UnifiedAiState(message: '');
  Future<void>? _activeInferenceFuture;
  String? _activeLinkedEntityId;
  int _runCounter = 0;
  int? _activeRunId;

  String get entityId => _params.entityId;
  String get promptId => _params.promptId;

  // Helper method to update inference status for both entities
  void _updateInferenceStatus(
    InferenceStatus status,
    AiResponseType responseType, {
    String? linkedEntityId,
  }) {
    ref
        .read(
          inferenceStatusControllerProvider(
            id: entityId,
            aiResponseType: responseType,
          ).notifier,
        )
        .setStatus(status);

    if (linkedEntityId != null) {
      ref
          .read(
            inferenceStatusControllerProvider(
              id: linkedEntityId,
              aiResponseType: responseType,
            ).notifier,
          )
          .setStatus(status);
    }
  }

  // Helper method to start active inference for both entities
  void _startActiveInference(
    String promptId,
    AiResponseType responseType, {
    String? linkedEntityId,
  }) {
    ref
        .read(
          activeInferenceControllerProvider(
            entityId: entityId,
            aiResponseType: responseType,
          ).notifier,
        )
        .startInference(
          promptId: promptId,
          linkedEntityId: linkedEntityId,
        );

    if (linkedEntityId != null) {
      ref
          .read(
            activeInferenceControllerProvider(
              entityId: linkedEntityId,
              aiResponseType: responseType,
            ).notifier,
          )
          .startInference(
            promptId: promptId,
            linkedEntityId: entityId,
          );
    }
  }

  // Helper method to update progress for both entities
  void _updateActiveInferenceProgress(
    String progress,
    AiResponseType responseType, {
    String? linkedEntityId,
  }) {
    ref
        .read(
          activeInferenceControllerProvider(
            entityId: entityId,
            aiResponseType: responseType,
          ).notifier,
        )
        .updateProgress(progress);

    if (linkedEntityId != null) {
      ref
          .read(
            activeInferenceControllerProvider(
              entityId: linkedEntityId,
              aiResponseType: responseType,
            ).notifier,
          )
          .updateProgress(progress);
    }
  }

  // Helper method to clear active inference for both entities
  void _clearActiveInference(
    AiResponseType responseType, {
    String? linkedEntityId,
  }) {
    ref
        .read(
          activeInferenceControllerProvider(
            entityId: entityId,
            aiResponseType: responseType,
          ).notifier,
        )
        .clearInference();

    if (linkedEntityId != null) {
      ref
          .read(
            activeInferenceControllerProvider(
              entityId: linkedEntityId,
              aiResponseType: responseType,
            ).notifier,
          )
          .clearInference();
    }
  }

  Future<void> runInference({String? linkedEntityId}) async {
    final loggingService = getIt<LoggingService>();

    if (_activeInferenceFuture != null) {
      loggingService.captureEvent(
        'Unified AI inference already running for $entityId (prompt: $promptId). '
        'Joining existing run $_activeRunId (incoming linked: $linkedEntityId, active linked: $_activeLinkedEntityId).',
        subDomain: 'runInference',
        domain: 'UnifiedAiController',
      );
      return _activeInferenceFuture!;
    }

    final runId = ++_runCounter;
    _activeRunId = runId;
    _activeLinkedEntityId = linkedEntityId;

    final future = _performInference(
      loggingService: loggingService,
      linkedEntityId: linkedEntityId,
    );
    _activeInferenceFuture = future;

    try {
      await future;
    } finally {
      loggingService.captureEvent(
        'Unified AI inference finished for $entityId (prompt: $promptId). '
        'Run $runId completed with linked: $linkedEntityId.',
        subDomain: 'runInference',
        domain: 'UnifiedAiController',
      );
      if (identical(_activeInferenceFuture, future)) {
        _activeInferenceFuture = null;
        _activeLinkedEntityId = null;
        _activeRunId = null;
      }
    }
  }

  Future<void> _performInference({
    required LoggingService loggingService,
    String? linkedEntityId,
  }) async {
    loggingService.captureEvent(
      'Starting unified AI inference for $entityId (prompt: $promptId, linked: $linkedEntityId, run $_activeRunId)',
      subDomain: 'runInference',
      domain: 'UnifiedAiController',
    );

    try {
      // Fetch the prompt config
      final config = await ref.read(aiConfigByIdProvider(promptId).future);
      if (config == null || config is! AiConfigPrompt) {
        throw Exception('Invalid prompt configuration for ID: $promptId');
      }
      final promptConfig = config;

      // Reset the inference status to idle before starting
      _updateInferenceStatus(
        InferenceStatus.idle,
        promptConfig.aiResponseType,
        linkedEntityId: linkedEntityId,
      );

      // Clear any previous progress message
      state = const UnifiedAiState(message: '');

      // Start tracking this inference
      _startActiveInference(
        promptId,
        promptConfig.aiResponseType,
        linkedEntityId: linkedEntityId,
      );

      final repo = ref.read(unifiedAiInferenceRepositoryProvider);
      await repo.runInference(
        entityId: entityId,
        promptConfig: promptConfig,
        onProgress: (progress) {
          state = UnifiedAiState(message: progress);
          _updateActiveInferenceProgress(
            progress,
            promptConfig.aiResponseType,
            linkedEntityId: linkedEntityId,
          );
        },
        onStatusChange: (status) {
          _updateInferenceStatus(
            status,
            promptConfig.aiResponseType,
            linkedEntityId: linkedEntityId,
          );
          if (status != InferenceStatus.running) {
            _clearActiveInference(
              promptConfig.aiResponseType,
              linkedEntityId: linkedEntityId,
            );
          }
        },
        linkedEntityId: linkedEntityId,
      );
    } catch (e, stackTrace) {
      // Categorize the error for better user feedback
      final inferenceError = AiErrorUtils.categorizeError(
        e,
        stackTrace: stackTrace,
      );

      developer.log(
        'Controller caught exception: ${e.runtimeType}, isException: ${e is Exception}',
        name: 'UnifiedAiController',
      );

      // Set the error message and preserve the original exception
      // Store the original caught exception 'e' directly, not inferenceError.originalError
      final newState = UnifiedAiState(
        message: inferenceError.message,
        error: e is Exception ? e : null,
      );

      developer.log(
        'Setting state with error: ${newState.error?.runtimeType}',
        name: 'UnifiedAiController',
      );

      state = newState;

      developer.log(
        'State after assignment: error=${state.error?.runtimeType}, '
        'entityId=$entityId, promptId=$promptId',
        name: 'UnifiedAiController',
      );

      // Try to set error status if we have prompt config
      try {
        final config = await ref.read(aiConfigByIdProvider(promptId).future);
        if (config != null && config is AiConfigPrompt) {
          loggingService.captureEvent(
            'Setting inference status to ERROR for ${config.aiResponseType}',
            subDomain: 'runInference',
            domain: 'UnifiedAiController',
          );
          _updateInferenceStatus(
            InferenceStatus.error,
            config.aiResponseType,
            linkedEntityId: linkedEntityId,
          );
        }
      } catch (_) {
        // Ignore errors when setting status
      }

      loggingService.captureException(
        inferenceError.originalError ?? e,
        domain: 'UnifiedAiController',
        subDomain: 'runInference',
        stackTrace: stackTrace,
      );
    }
  }
}

/// Record type identifying an entity together with its optional parent task,
/// used as the key for skill-availability providers.
///
/// `linkedFromId` is the parent task id if the entry is linked from a task;
/// `null` for standalone entries.
typedef SkillsAvailabilityParams = ({String entityId, String? linkedFromId});

/// Provider to get available skills for a given entity.
///
/// Filters skills from the built-in skill registry by:
/// 1. Matching the entity type to the skill's `requiredInputModalities`:
///    - [Modality.audio] → entity must be [JournalAudio]
///    - [Modality.image] → entity must be [JournalImage]
///    - [Modality.text] → entity must be one of the four text-bearing
///      surfaces the AI popup is rendered on today
///      ([JournalEntry], [JournalAudio] via its transcript, [Task]
///      via title/notes, [JournalImage] via its overlay text). Other
///      [JournalEntity] variants (measurements, ratings, workouts,
///      etc.) carry no free-form text and are filtered out.
/// 2. Filtering out skills whose `contextPolicy` is
///    [ContextPolicy.fullTask] when the entity has no task context — i.e.
///    the entity itself is not a [Task] and `linkedFromId` is `null`.
///    Standalone entries cannot satisfy a full-task context, so those
///    skills are hidden rather than offered and then silently no-oped.
final availableSkillsForEntityProvider = FutureProvider.autoDispose
    .family<List<AiConfigSkill>, SkillsAvailabilityParams>(
      (ref, params) async {
        final entryState = ref
            .watch(entryControllerProvider(id: params.entityId))
            .value;
        final entity = entryState?.entry;
        if (entity == null) return [];

        final registry = ref.watch(skillRegistryProvider);

        // Only show skill types that have a working implementation.
        const supportedTypes = {
          SkillType.transcription,
          SkillType.imageAnalysis,
          SkillType.promptGeneration,
          SkillType.imagePromptGeneration,
          SkillType.imageGeneration,
        };

        final hasTaskContext = entity is Task || params.linkedFromId != null;
        final hasText =
            entity is JournalEntry ||
            entity is JournalAudio ||
            entity is Task ||
            entity is JournalImage;

        return registry.where((skill) {
          if (!supportedTypes.contains(skill.skillType)) return false;
          if (!hasTaskContext &&
              skill.contextPolicy == ContextPolicy.fullTask) {
            return false;
          }
          final modalities = skill.requiredInputModalities;
          if (modalities.contains(Modality.audio) && entity is! JournalAudio) {
            return false;
          }
          if (modalities.contains(Modality.image) && entity is! JournalImage) {
            return false;
          }
          if (modalities.contains(Modality.text) && !hasText) {
            return false;
          }
          return true;
        }).toList();
      },
    );

/// Provider to check if there are any AI skills available for an entity.
final hasAvailableSkillsProvider = FutureProvider.autoDispose
    .family<bool, SkillsAvailabilityParams>(
      (ref, params) async {
        final skills = await ref.watch(
          availableSkillsForEntityProvider(params).future,
        );
        return skills.isNotEmpty;
      },
    );

/// Record type for trigger skill parameters.
///
/// `overrideTranscriptionModelId` is consumed only by
/// [SkillType.transcription]. Non-transcription skills ignore it. The
/// popup-menu picker sets it when the user chooses a non-default model
/// for one specific voice note; the trigger forwards it to
/// [SkillInferenceRunner.runTranscription], which routes the call to
/// that model + its parent provider instead of the profile slot.
typedef TriggerSkillParams = ({
  String entityId,
  String skillId,
  String? linkedTaskId,
  List<ProcessedReferenceImage>? referenceImages,
  String? overrideTranscriptionModelId,
});

/// Provider to trigger a skill-based inference run.
///
/// Resolves the profile via `ProfileAutomationResolver`, then routes to the
/// appropriate `SkillInferenceRunner` method based on the skill type.
final triggerSkillProvider = FutureProvider.autoDispose
    .family<void, TriggerSkillParams>(
      (ref, params) async {
        // Keep alive until completion so fire-and-forget callers don't
        // cause the provider to be disposed mid-execution.
        final link = ref.keepAlive();
        final loggingService = getIt<LoggingService>();
        try {
          developer.log(
            'triggerSkill: entityId=${params.entityId}, '
            'skillId=${params.skillId}, linkedTaskId=${params.linkedTaskId}',
            name: 'UnifiedAiController',
          );

          final skill = ref
              .read(skillRegistryProvider)
              .where((s) => s.id == params.skillId)
              .firstOrNull;
          if (skill == null) {
            loggingService.captureEvent(
              'Skill not found: ${params.skillId}',
              domain: 'UnifiedAiController',
              subDomain: 'triggerSkillProvider',
            );
            return;
          }

          // Defensive guard: a skill that needs full task context cannot run
          // without a linked task. The popup filter hides these skills for
          // standalone entries, so reaching this branch indicates a caller
          // bug — fail loudly rather than silently no-op.
          if (params.linkedTaskId == null &&
              skill.contextPolicy == ContextPolicy.fullTask) {
            loggingService.captureEvent(
              'Skipping ${params.skillId} for ${params.entityId}: '
              'skill requires full task context but no linked task',
              domain: 'UnifiedAiController',
              subDomain: 'triggerSkillProvider',
            );
            return;
          }

          // Resolve the inference profile. For task-linked entries we use the
          // task's agent / inherited profile; for standalone entries we fall
          // back to the entry category's `defaultProfileId`.
          final resolver = ref.read(profileAutomationResolverProvider);
          ResolvedProfile? resolvedProfile;
          if (params.linkedTaskId != null) {
            resolvedProfile = await resolver.resolveForTask(
              params.linkedTaskId!,
            );
          } else {
            final entity = await ref
                .read(journalDbProvider)
                .journalEntityById(params.entityId);
            final categoryId = entity?.categoryId;
            if (categoryId == null) {
              loggingService.captureEvent(
                'Skipping ${params.skillId} for ${params.entityId}: '
                'no linked task and entry has no category',
                domain: 'UnifiedAiController',
                subDomain: 'triggerSkillProvider',
              );
              return;
            }
            resolvedProfile = await resolver.resolveForCategory(categoryId);
          }

          if (resolvedProfile == null) {
            loggingService.captureEvent(
              'Skipping ${params.skillId} for ${params.entityId} '
              '(linkedTaskId=${params.linkedTaskId}): no profile configured',
              domain: 'UnifiedAiController',
              subDomain: 'triggerSkillProvider',
            );
            return;
          }

          developer.log(
            'triggerSkill: resolved profile for ${params.entityId} '
            '(linkedTaskId=${params.linkedTaskId}), '
            'running ${skill.skillType}',
            name: 'UnifiedAiController',
          );

          final automationResult = AutomationResult(
            handled: true,
            skill: skill,
            resolvedProfile: resolvedProfile,
          );

          final runner = ref.read(skillInferenceRunnerProvider);

          switch (skill.skillType) {
            case SkillType.transcription:
              await runner.runTranscription(
                audioEntryId: params.entityId,
                automationResult: automationResult,
                linkedTaskId: params.linkedTaskId,
                overrideTranscriptionModelId:
                    params.overrideTranscriptionModelId,
              );
            case SkillType.imageAnalysis:
              await runner.runImageAnalysis(
                imageEntryId: params.entityId,
                automationResult: automationResult,
                linkedTaskId: params.linkedTaskId,
              );
            case SkillType.promptGeneration:
            case SkillType.imagePromptGeneration:
              await runner.runPromptGeneration(
                entryId: params.entityId,
                automationResult: automationResult,
                linkedTaskId: params.linkedTaskId,
              );
            case SkillType.imageGeneration:
              final linkedTaskId = params.linkedTaskId;
              if (linkedTaskId == null) {
                throw StateError(
                  'Image generation requires a linkedTaskId, '
                  'but it was null for entity ${params.entityId}',
                );
              }
              await runner.runImageGeneration(
                entryId: params.entityId,
                automationResult: automationResult,
                linkedTaskId: linkedTaskId,
                referenceImages: params.referenceImages,
              );
          }

          developer.log(
            'triggerSkill: completed for ${params.entityId}',
            name: 'UnifiedAiController',
          );
        } catch (error, stackTrace) {
          loggingService.captureException(
            error,
            domain: 'UnifiedAiController',
            subDomain: 'triggerSkillProvider',
            stackTrace: stackTrace,
          );
        } finally {
          link.close();
        }
      },
    );

/// Record type for trigger new inference parameters.
typedef TriggerNewInferenceParams = ({
  String entityId,
  String promptId,
  String? linkedEntityId,
});

/// Provider to trigger a new inference run
final triggerNewInferenceProvider = FutureProvider.autoDispose
    .family<void, TriggerNewInferenceParams>(
      (ref, params) async {
        developer.log(
          'triggerNewInference called: entityId=${params.entityId}, promptId=${params.promptId}, linkedEntityId=${params.linkedEntityId}',
          name: 'UnifiedAiController',
        );
        // Get the controller instance (this will create it if it doesn't exist)
        final controller = ref.read(
          unifiedAiControllerProvider((
            entityId: params.entityId,
            promptId: params.promptId,
          )).notifier,
        );

        // Wait for the inference to complete, passing the linked entity ID
        await controller.runInference(linkedEntityId: params.linkedEntityId);
      },
    );
