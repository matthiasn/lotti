// ignore_for_file: specify_nonobvious_property_types

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/classes/ai/skill_type.dart';
import 'package:lotti/classes/ai_attribution.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/helpers/sole_linked_task.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/services/profile_automation_service.dart';
import 'package:lotti/features/ai/services/skill_inference_runner.dart';
import 'package:lotti/features/ai/skills/built_in_skills.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_error_controller.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/features/ai/state/skill_entity_provider.dart';
import 'package:lotti/features/ai/state/unified_ai_controller.dart';
import 'package:lotti/features/ai/util/image_processing_utils.dart';
import 'package:lotti/features/ai_consumption/service/ai_attribution_identity_resolver.dart';
import 'package:lotti/features/ai_consumption/service/ai_attribution_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/device_messages.dart';
import 'package:lotti/providers/service_providers.dart'
    show domainLoggerProvider, journalDbProvider;
import 'package:lotti/providers/service_providers.dart';
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
        final entity = ref.watch(skillEntityProvider(params.entityId));
        if (entity == null) return [];

        final registry = ref.watch(skillRegistryProvider);

        // Only show skill types that have a working implementation.
        const supportedTypes = {
          SkillType.transcription,
          SkillType.imageAnalysis,
          SkillType.promptGeneration,
          SkillType.imagePromptGeneration,
          SkillType.imageGeneration,
          SkillType.audioSummary,
        };

        final hasKnownTaskContext =
            entity is Task || params.linkedFromId != null;
        final needsResolvedTaskContext =
            !hasKnownTaskContext &&
            registry.any(
              (skill) =>
                  supportedTypes.contains(skill.skillType) &&
                  (skill.contextPolicy == ContextPolicy.fullTask ||
                      skill.skillType == SkillType.imageGeneration),
            );
        final hasTaskContext =
            hasKnownTaskContext ||
            (needsResolvedTaskContext &&
                await _findLinkedTaskId(entityId: entity.id) != null);

        final hasText =
            entity is JournalEntry ||
            entity is JournalAudio ||
            entity is Task ||
            entity is JournalImage;

        return registry.where((skill) {
          if (!supportedTypes.contains(skill.skillType)) return false;
          if (skill.skillType == SkillType.imageGeneration &&
              (!hasTaskContext ||
                  (entity is! JournalAudio && entity is! JournalEntry))) {
            return false;
          }
          // A recording's summary frames itself by whatever the recording
          // belongs to, or by the speech dictionary alone, so it is offered
          // on every recording — which also makes it the way to finish a
          // recording whose post-processing never did.
          if (!hasTaskContext &&
              skill.contextPolicy == ContextPolicy.fullTask &&
              skill.skillType != SkillType.audioSummary) {
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
/// appropriate `SkillInferenceRunner` method based on the skill type. An image
/// analysis with an `overrideModelId` runs even when no profile resolves.
final triggerSkillProvider = FutureProvider.autoDispose
    .family<void, TriggerSkillParams>(
      (ref, params) async {
        // Keep alive until completion so fire-and-forget callers don't
        // cause the provider to be disposed mid-execution.
        final link = ref.keepAlive();
        final loggingService = ref.watch(domainLoggerProvider);
        try {
          loggingService.log(
            LogDomain.ai,
            'triggerSkill: entityId=${params.entityId}, '
            'skillId=${params.skillId}, linkedTaskId=${params.linkedTaskId}',
            subDomain: 'UnifiedAiController',
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

          final linkedTaskId = await _resolveLinkedTaskId(
            entityId: params.entityId,
            linkedTaskId: params.linkedTaskId,
          );

          // Defensive guard: a skill that needs full task context cannot run
          // without a linked task. The popup filter hides these skills for
          // standalone entries, and the graph lookup above covers task-linked
          // entries whose caller did not pass `linkedTaskId`. A recording's
          // transcription and summary are the exception: they frame
          // themselves by whatever the recording belongs to — a goal
          // check-in transcribes with the task-context skill — and fall back
          // to the speech dictionary.
          if (linkedTaskId == null &&
              skill.contextPolicy == ContextPolicy.fullTask &&
              skill.skillType != SkillType.transcription &&
              skill.skillType != SkillType.audioSummary) {
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
          // back to the entry category's `defaultProfileId`. A recording
          // without a task resolves below, through the transcription rule.
          final resolver = ref.read(profileAutomationResolverProvider);
          final isTranscription = skill.skillType == SkillType.transcription;
          final isSummary = skill.skillType == SkillType.audioSummary;
          // An image analysis on a model the user picked runs without a
          // profile: an entry with no category resolves none, the picker
          // offers no default, and the runner routes straight to that model.
          final runsOnPickedModel =
              skill.skillType == SkillType.imageAnalysis &&
              params.overrideModelId != null;
          ResolvedProfile? resolvedProfile;
          String? entryCategoryId;
          if (linkedTaskId != null) {
            resolvedProfile = await resolver.resolveForSubject(linkedTaskId);
            // A task with no profile of its own — one filed in no category,
            // as a task made in the companion's chat often is — generates on
            // the device's Settings default, the profile the companion
            // herself falls back to. So does cover art whose task profile
            // names no image model, when the default names one. A model the
            // user picked by hand needs no slot, and a default that cannot
            // run the skill either changes nothing: the run then declines or
            // fails where it did before.
            if (_generates(skill) &&
                !_canGenerate(
                  resolvedProfile,
                  skill,
                  overrideModelId: params.overrideModelId,
                )) {
              final fallback = await resolver.resolveDefaultProfile();
              if (_canGenerate(
                fallback,
                skill,
                overrideModelId: params.overrideModelId,
              )) {
                loggingService.log(
                  LogDomain.ai,
                  'triggerSkill: task ${DomainLogger.sanitizeId(linkedTaskId)} '
                  'has no profile that can run ${skill.id}; using the '
                  'Settings default',
                  subDomain: 'triggerSkillProvider',
                );
                resolvedProfile = fallback;
              }
            }
          } else {
            final entity = await ref
                .read(journalDbProvider)
                .journalEntityById(params.entityId);
            final categoryId = entryCategoryId = entity?.categoryId;
            // A transcription resolves below, where the recording's subject
            // is asked before its category.
            if (!isTranscription) {
              if (categoryId != null) {
                resolvedProfile = await resolver.resolveForCategory(
                  categoryId,
                );
              } else if (!isSummary && !runsOnPickedModel) {
                await _declineSkill(
                  ref,
                  entityId: params.entityId,
                  linkedTaskId: params.linkedTaskId,
                  skill: skill,
                  reason: 'no linked task and entry has no category',
                  message: deviceMessages().aiSkillNoProfileConfigured,
                  loggingService: loggingService,
                );
                return;
              }
            }
          }

          // A recording with no task, or whose task's profile cannot
          // transcribe, follows the one transcription rule
          // (`resolveTranscriptionProfile`): the profile of the agent the
          // recording is about — a goal's, a person's — then that subject's
          // own, then the category's, then the Settings default. Asking only
          // the category and the default is what sent a Mistral goal agent's
          // check-ins to the default's Whisper. When nothing can transcribe,
          // the recording declines visibly below; no model is picked outside
          // a profile.
          if (isTranscription &&
              (resolvedProfile == null ||
                  resolvedProfile.transcriptionModelId == null)) {
            final fallback = await ref
                .read(profileAutomationServiceProvider)
                .resolveTranscriptionFallback(
                  subjectId:
                      linkedTaskId ??
                      await _findRecordingSubjectId(
                        ref,
                        entityId: params.entityId,
                      ),
                  categoryId: entryCategoryId,
                );
            if (fallback.handled) {
              resolvedProfile = fallback.resolvedProfile;
            }
          }

          // A recording's summary frames itself by whatever the recording
          // belongs to and needs only a model that can call its tool, so a
          // recording no task or category profile reaches — the shape of a
          // goal check-in — is summarized on the device's Settings default.
          // Without it the menu would offer a summary it then declines.
          if (isSummary && resolvedProfile == null) {
            resolvedProfile = await resolver.resolveDefaultProfile();
          }

          // A profile that resolves but owns no transcription slot is as
          // unable to transcribe as no profile at all, and `runTranscription`
          // returns *before* it starts tracking status — so letting it through
          // reproduces exactly the invisible stall this change exists to end.
          final noTranscriptionRoute =
              isTranscription && resolvedProfile?.transcriptionModelId == null;
          if ((resolvedProfile == null && !runsOnPickedModel) ||
              noTranscriptionRoute) {
            await _declineSkill(
              ref,
              entityId: params.entityId,
              linkedTaskId: linkedTaskId,
              skill: skill,
              reason: isTranscription
                  ? 'no profile and no speech-to-text model could be resolved'
                  : 'no profile configured',
              message: isTranscription
                  ? deviceMessages().aiTranscriptionNoModelConfigured
                  : deviceMessages().aiSkillNoProfileConfigured,
              loggingService: loggingService,
            );
            return;
          }

          loggingService.log(
            LogDomain.ai,
            'triggerSkill: resolved profile for ${params.entityId} '
            '(linkedTaskId=$linkedTaskId), '
            'running ${skill.skillType}',
            subDomain: 'UnifiedAiController',
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
                linkedTaskId: linkedTaskId,
                overrideModelId: params.overrideModelId,
                geminiThinkingMode: params.geminiThinkingMode,
              );
            case SkillType.imageAnalysis:
              await runner.runImageAnalysis(
                imageEntryId: params.entityId,
                automationResult: automationResult,
                linkedTaskId: linkedTaskId,
                overrideModelId: params.overrideModelId,
                geminiThinkingMode: params.geminiThinkingMode,
              );
            case SkillType.promptGeneration:
            case SkillType.imagePromptGeneration:
              await runner.runPromptGeneration(
                entryId: params.entityId,
                automationResult: automationResult,
                linkedTaskId: linkedTaskId,
                referenceImages: params.referenceImages,
                overrideModelId: params.overrideModelId,
                geminiThinkingMode: params.geminiThinkingMode,
              );
            case SkillType.audioSummary:
              await runner.runAudioSummary(
                audioEntryId: params.entityId,
                automationResult: automationResult,
                linkedTaskId: linkedTaskId,
                overrideModelId: params.overrideModelId,
                geminiThinkingMode: params.geminiThinkingMode,
              );
            case SkillType.imageGeneration:
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

          loggingService.log(
            LogDomain.ai,
            'triggerSkill: completed for ${params.entityId}',
            subDomain: 'UnifiedAiController',
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

/// Whether [skill] writes or draws something for a task: a coding, design,
/// research or image prompt, or cover art.
bool _generates(AiConfigSkill skill) => switch (skill.skillType) {
  SkillType.imageGeneration ||
  SkillType.promptGeneration ||
  SkillType.imagePromptGeneration => true,
  SkillType.transcription ||
  SkillType.imageAnalysis ||
  SkillType.audioSummary => false,
};

/// Whether [profile] can run the generating [skill]: any profile writes a
/// prompt on its thinking model, and cover art needs an image-generation
/// model — the profile's own, or one picked by hand ([overrideModelId]).
bool _canGenerate(
  ResolvedProfile? profile,
  AiConfigSkill skill, {
  required String? overrideModelId,
}) =>
    profile != null &&
    (skill.skillType != SkillType.imageGeneration ||
        overrideModelId != null ||
        profile.imageGenerationProvider != null);

/// Records a transcription that will not run, where the user can see it.
///
/// The public half of [_declineSkill], for callers that decide *not* to start
/// a run at all rather than failing to resolve one — a goal whose automatic
/// updates are switched off is the case that exists today. Without it such a
/// recording is indistinguishable from one still being transcribed: the
/// timeline maps "no transcript, nothing running, no durable failure" to
/// pending, so the beat claims progress forever and never offers the Retry
/// that would actually transcribe it.
Future<void> recordTranscriptionDecline(
  Ref ref, {
  required String entityId,
  required String reason,
  required String message,
}) async {
  final skill = findBuiltInSkill(skillTranscribeContextId);
  if (skill == null) return;
  await _declineSkill(
    ref,
    entityId: entityId,
    linkedTaskId: null,
    skill: skill,
    reason: reason,
    message: message,
    loggingService: ref.read(domainLoggerProvider),
  );
}

/// Records a skill run that never started, where the user can see it.
///
/// A decline used to be a log line and nothing else, so the audio beat sat on
/// "Transcribing…" forever while no job existed anywhere — the retry
/// affordance the timeline already ships had no way to appear. This writes
/// both halves of the failed state: the live status the open surface reads,
/// and a failed attribution so the failure survives a restart and the entry
/// still offers Retry on the next launch.
///
/// [message] is what the user reads; [reason] is the English diagnostic that
/// goes to the log, where a support export needs it to be stable rather than
/// translated.
Future<void> _declineSkill(
  Ref ref, {
  required String entityId,
  required String? linkedTaskId,
  required AiConfigSkill skill,
  required String reason,
  required String message,
  required DomainLogger loggingService,
}) async {
  loggingService.log(
    LogDomain.ai,
    'Skipping ${skill.id} for $entityId: $reason',
    subDomain: 'triggerSkillProvider',
  );

  final responseType = skill.skillType.toResponseType;
  // Under the entry, and under its task as a failed run reports: a surface
  // that follows the task — its page, its card in the companion's chat —
  // sees a run that never started as it sees one that failed.
  for (final id in {entityId, ?linkedTaskId}) {
    ref
        .read(
          inferenceErrorControllerProvider((
            id: id,
            aiResponseType: responseType,
          )).notifier,
        )
        .setError(message);
    ref
        .read(
          inferenceStatusControllerProvider((
            id: id,
            aiResponseType: responseType,
          )).notifier,
        )
        .setStatus(InferenceStatus.error);
  }

  // Only transcription has a durable failed state to restore: it is the one
  // whose output carrier is the source entry itself, which is what
  // `getLatestAttributionForArtifact` keys on.
  if (skill.skillType != SkillType.transcription) return;
  if (!getIt.isRegistered<AiAttributionService>() ||
      !getIt.isRegistered<AiAttributionIdentityResolver>()) {
    return;
  }
  try {
    final attributions = getIt<AiAttributionService>();
    final session = await attributions.begin(
      AiAttributionStart(
        workType: AiWorkType.audioTranscription,
        initiator: await getIt<AiAttributionIdentityResolver>()
            .humanInitiator(),
        trigger: AiTriggerSnapshot(
          type: AiTriggerType.manual,
          skillId: skill.id,
        ),
        intendedOutputs: [
          AiArtifactReference(
            type: AiArtifactType.journalAudio,
            id: entityId,
          ),
        ],
        taskId: linkedTaskId,
      ),
    );
    await attributions.finalize(
      await attributions.prepareCompletion(
        attributionId: session.id,
        outputs: const [],
        status: AiWorkStatus.failed,
        errorCode: 'transcription_not_configured',
        errorSummary: reason,
      ),
    );
  } catch (error, stackTrace) {
    // The failure record is diagnostics, not the operation. Losing it must
    // not turn a declined transcription into a thrown one.
    loggingService.error(
      LogDomain.ai,
      error,
      stackTrace: stackTrace,
      subDomain: 'declineSkill',
    );
  }
}

Future<String?> _resolveLinkedTaskId({
  required String entityId,
  required String? linkedTaskId,
}) async {
  if (linkedTaskId != null) return linkedTaskId;

  final db = getIt<JournalDb>();
  final entity = await db.journalEntityById(entityId);
  if (entity == null) return null;
  if (entity is Task) return entity.id;
  return _findLinkedTaskId(entityId: entityId);
}

Future<String?> _findLinkedTaskId({
  required String entityId,
}) async {
  final db = getIt<JournalDb>();

  final outgoingEntitiesFuture = db.getLinkedEntities(entityId);
  final incomingEntitiesFuture = db.getLinkedToEntities(entityId);

  final (outgoingEntities, incomingDbEntities) = await (
    outgoingEntitiesFuture,
    incomingEntitiesFuture,
  ).wait;

  // Either direction counts — the entry linking to a task, or a task linking
  // to the entry as one of its children (the common timeline direction) —
  // and only a single task is an answer.
  return soleLinkedTask([
    ...outgoingEntities,
    ...incomingDbEntities.map(fromDbEntity),
  ])?.id;
}

/// The subject a task-less recording [entityId] is about — the goal, person,
/// project or event whose entry links to it — or null when no such entry
/// does.
///
/// The recorder links a recording FROM its subject, so the subject is among
/// the entries linking *to* the recording. It is what the transcription rule
/// asks first: the agent assigned to it chose a profile, and that choice
/// outranks the category's and the Settings default's.
Future<String?> _findRecordingSubjectId(
  Ref ref, {
  required String entityId,
}) async {
  final parents = await ref
      .read(journalDbProvider)
      .getLinkedToEntities(entityId);
  return parents
      .map(fromDbEntity)
      .where(
        (parent) => switch (parent) {
          GoalEntry() ||
          RelationshipEntry() ||
          ProjectEntry() ||
          JournalEvent() => !parent.isDeleted,
          _ => false,
        },
      )
      .firstOrNull
      ?.id;
}

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
        ref
            .read(domainLoggerProvider)
            .log(
              LogDomain.ai,
              'triggerNewInference called: entityId=${params.entityId}, '
              'promptId=${params.promptId}, '
              'linkedEntityId=${params.linkedEntityId}',
              subDomain: 'UnifiedAiController',
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
