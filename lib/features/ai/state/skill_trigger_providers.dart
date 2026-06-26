// ignore_for_file: specify_nonobvious_property_types

import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/services/profile_automation_service.dart';
import 'package:lotti/features/ai/services/skill_inference_runner.dart';
import 'package:lotti/features/ai/skills/built_in_skills.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/features/ai/state/unified_ai_controller.dart';
import 'package:lotti/features/ai/util/image_processing_utils.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart' show journalDbProvider;
import 'package:lotti/services/domain_logging.dart';

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
            .watch(entryControllerProvider(params.entityId))
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
/// `overrideModelId` is semantically scoped by the skill's `skillType`: the
/// popup-menu pickers set it when the user chooses a non-default model
/// for one specific entry, and the dispatch in [triggerSkillProvider]
/// forwards it to the matching `SkillInferenceRunner` entry point
/// (transcription, image analysis, and prompt generation honour it today).
/// The runner routes the call to that model + its parent provider instead of
/// the profile slot.
///
/// `geminiThinkingMode` is also per-invocation. When set for a Gemini-backed
/// run, it overrides the selected model row's saved default effort for this
/// call only.
typedef TriggerSkillParams = ({
  String entityId,
  String skillId,
  String? linkedTaskId,
  List<ProcessedReferenceImage>? referenceImages,
  String? overrideModelId,
  GeminiThinkingMode? geminiThinkingMode,
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
        final loggingService = getIt<DomainLogger>();
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
            loggingService.log(
              LogDomain.ai,
              'Skill not found: ${params.skillId}',
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
            loggingService.log(
              LogDomain.ai,
              'Skipping ${params.skillId} for ${params.entityId}: '
              'skill requires full task context but no linked task',
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
              loggingService.log(
                LogDomain.ai,
                'Skipping ${params.skillId} for ${params.entityId}: '
                'no linked task and entry has no category',
                subDomain: 'triggerSkillProvider',
              );
              return;
            }
            resolvedProfile = await resolver.resolveForCategory(categoryId);
          }

          if (resolvedProfile == null) {
            loggingService.log(
              LogDomain.ai,
              'Skipping ${params.skillId} for ${params.entityId} '
              '(linkedTaskId=${params.linkedTaskId}): no profile configured',
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
                overrideModelId: params.overrideModelId,
                geminiThinkingMode: params.geminiThinkingMode,
              );
            case SkillType.imageAnalysis:
              await runner.runImageAnalysis(
                imageEntryId: params.entityId,
                automationResult: automationResult,
                linkedTaskId: params.linkedTaskId,
                overrideModelId: params.overrideModelId,
                geminiThinkingMode: params.geminiThinkingMode,
              );
            case SkillType.promptGeneration:
            case SkillType.imagePromptGeneration:
              await runner.runPromptGeneration(
                entryId: params.entityId,
                automationResult: automationResult,
                linkedTaskId: params.linkedTaskId,
                overrideModelId: params.overrideModelId,
                geminiThinkingMode: params.geminiThinkingMode,
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
                overrideModelId: params.overrideModelId,
              );
          }

          developer.log(
            'triggerSkill: completed for ${params.entityId}',
            name: 'UnifiedAiController',
          );
        } catch (error, stackTrace) {
          loggingService.error(
            LogDomain.ai,
            error,
            stackTrace: stackTrace,
            subDomain: 'triggerSkillProvider',
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
