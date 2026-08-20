import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/ai/helpers/automatic_image_analysis_trigger.dart';
import 'package:lotti/features/ai/helpers/entity_state_helper.dart';
import 'package:lotti/features/ai/helpers/prompt_builder_helper.dart';
import 'package:lotti/features/ai/helpers/skill_prompt_builder.dart';
import 'package:lotti/features/ai/model/ai_call_impact.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/image_generation_error.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/repository/ai_consumption_mapping.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/gemini_thinking_config.dart';
import 'package:lotti/features/ai/repository/task_summary_resolver.dart';
import 'package:lotti/features/ai/repository/tool_call_accumulator.dart';
import 'package:lotti/features/ai/repository/transcription_exception.dart';
import 'package:lotti/features/ai/services/profile_automation_service.dart';
import 'package:lotti/features/ai/skills/built_in_skills.dart';
import 'package:lotti/features/ai/skills/entry_summary_tool.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/image_generation_error_controller.dart';
import 'package:lotti/features/ai/state/inference_error_controller.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/util/image_processing_utils.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_event.dart';
import 'package:lotti/features/ai_consumption/service/ai_attribution_identity_resolver.dart';
import 'package:lotti/features/ai_consumption/service/ai_attribution_service.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/image_import.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:openai_dart/openai_dart.dart';

part 'skill_inference_runner_internals.dart';

const _logTag = 'SkillInferenceRunner';

/// Shortest transcript worth summarizing, in characters.
///
/// Below this the collapsed card's existing transcript-prefix fallback is
/// already the whole content, so a summary would spend a model call to
/// restate it. Measured on the resolved entry content (an edit if there is
/// one, otherwise the latest transcript), not on the audio duration — a long
/// recording of silence is not worth summarizing either.
const _audioSummaryMinChars = 200;

/// Service that invokes inference using skill-built prompts and
/// profile-resolved models, bypassing the legacy prompt system entirely.
///
/// Holds the four skill inference paths (transcription, image analysis,
/// prompt generation, image generation) plus the shared model/slot
/// resolution, status-tracking, and content-preparation helpers they depend
/// on. The public `run*` methods are real, mockable class members so
/// `MockSkillInferenceRunner` intercepts the public API.
class SkillInferenceRunner {
  const SkillInferenceRunner({
    required this._ref,
    required this._cloudRepository,
    required this._aiInputRepository,
    required this._journalRepository,
    required this._loggingService,
    required this._promptBuilderHelper,
    required this._taskSummaryResolver,
  });

  final Ref _ref;
  final CloudInferenceRepository _cloudRepository;
  final AiInputRepository _aiInputRepository;
  final JournalRepository _journalRepository;
  final DomainLogger _loggingService;
  final PromptBuilderHelper _promptBuilderHelper;
  final TaskSummaryResolver _taskSummaryResolver;

  /// Formats pre-fetched speech dictionary terms into a prompt fragment.
  static String _formatSpeechDictionaryText(List<String> terms) {
    if (terms.isEmpty) return '';

    String escapeForJson(String s) => s
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n');
    final termsJson = terms.map((t) => '"${escapeForJson(t)}"').join(', ');

    return 'IMPORTANT - SPEECH DICTIONARY (MUST USE):\n'
        'The following terms are domain-specific and MUST be spelled exactly '
        'as shown when they appear in the audio.\n'
        'Required spellings: [$termsJson]';
  }

  /// Run skill-based transcription on an audio entry.
  ///
  /// When [overrideModelId] is non-null and resolves to a valid
  /// `AiConfigModel`, the run uses that model and its parent provider
  /// instead of the profile's transcription slot. This is the
  /// per-invocation override path used by the popup-menu picker, so the
  /// user can route a single voice note to a different model without
  /// changing the entire profile. A stale or unresolvable override
  /// falls back to the profile slot (with a warning log) — stranding
  /// the user is worse than ignoring a stale id.
  /// [onError] receives the raw exception when the run fails.
  ///
  /// This method deliberately never throws — `_withStatusTracking` catches
  /// everything, logs it and reports it through
  /// [inferenceStatusControllerProvider] / [inferenceErrorControllerProvider],
  /// which is all a fire-and-forget caller needs. A caller that is *waiting*
  /// on the transcript needs more than that: a failed run writes no
  /// `entryText`, so silence is indistinguishable from a slow model and the
  /// caller sits on a spinner until its own timeout. [onError] is that
  /// signal, and it fires for the same failures the error controller shows.
  Future<void> runTranscription({
    required String audioEntryId,
    required AutomationResult automationResult,
    String? linkedTaskId,
    String? overrideModelId,
    GeminiThinkingMode? geminiThinkingMode,
    void Function(Object error)? onError,
  }) async {
    final skill = automationResult.skill;
    final profile = automationResult.resolvedProfile;
    if (skill == null || profile == null) {
      throw StateError(
        'AutomationResult missing skill or profile for $audioEntryId: '
        'skill=${skill != null}, profile=${profile != null}',
      );
    }
    final target = await _resolveTranscriptionTarget(
      profile: profile,
      overrideModelId: overrideModelId,
    );
    final provider = target.provider;
    final modelId = target.modelId;
    final effectiveThinkingMode = _geminiThinkingModeForTarget(
      target,
      geminiThinkingMode,
    );
    if (provider == null || modelId == null) {
      developer.log(
        'Profile missing transcription provider/model for $audioEntryId',
        name: _logTag,
      );
      return;
    }

    await _withStatusTracking(
      entityId: audioEntryId,
      responseType: skill.skillType.toResponseType,
      subDomain: 'runTranscription',
      linkedTaskId: linkedTaskId,
      onError: onError,
      body: () async {
        // 1. Fetch the audio entity.
        final entity = await _aiInputRepository.getEntity(audioEntryId);
        if (entity is! JournalAudio) {
          throw StateError('Entity $audioEntryId is not a JournalAudio');
        }

        // 2. Build context for prompts (fetch terms once, reuse for both
        // prompt text and provider-level context biasing).
        final speechDictionaryTerms = await _promptBuilderHelper
            .getSpeechDictionaryTerms(entity);
        final speechDictionary = _formatSpeechDictionaryText(
          speechDictionaryTerms,
        );
        final taskContext = linkedTaskId != null
            ? await _aiInputRepository.buildTaskDetailsJson(id: linkedTaskId)
            : null;
        final currentTaskSummary = await _buildCurrentTaskSummary(
          entity,
          linkedTaskId,
        );

        // 3. Build prompts via SkillPromptBuilder.
        const promptBuilder = SkillPromptBuilder();
        final promptResult = promptBuilder.build(
          skill: skill,
          speechDictionary: speechDictionary,
          taskContext: taskContext,
          currentTaskSummary: currentTaskSummary,
        );

        // 4. Prepare audio data.
        final fullPath = await AudioUtils.getFullAudioPath(entity);
        final file = File(fullPath);
        final bytes = await file.readAsBytes();
        final audioBase64 = base64Encode(bytes);

        // 5. Call inference with separate system/user messages.
        final start = DateTime.now();
        final transcriptId = uuid.v4();
        final attribution = await _beginAttribution(
          workType: AiWorkType.audioTranscription,
          source: entity,
          output: AiArtifactReference(
            type: AiArtifactType.journalAudio,
            id: audioEntryId,
            subId: transcriptId,
          ),
          skill: skill,
          automationResult: automationResult,
          taskId: linkedTaskId,
        );
        final impactCollector =
            provider.inferenceProviderType == InferenceProviderType.melious
            ? InferenceImpactCollector()
            : null;
        final responseStream = impactCollector == null
            ? _cloudRepository.generateWithAudio(
                promptResult.userMessage,
                model: modelId,
                audioBase64: audioBase64,
                baseUrl: provider.baseUrl,
                apiKey: provider.apiKey,
                provider: provider,
                systemMessage: promptResult.systemMessage,
                geminiThinkingMode: effectiveThinkingMode,
                speechDictionaryTerms: speechDictionaryTerms.isNotEmpty
                    ? speechDictionaryTerms
                    : null,
              )
            : _cloudRepository.generateWithAudio(
                promptResult.userMessage,
                model: modelId,
                audioBase64: audioBase64,
                baseUrl: provider.baseUrl,
                apiKey: provider.apiKey,
                provider: provider,
                systemMessage: promptResult.systemMessage,
                geminiThinkingMode: effectiveThinkingMode,
                speechDictionaryTerms: speechDictionaryTerms.isNotEmpty
                    ? speechDictionaryTerms
                    : null,
                impactCollector: impactCollector,
              );

        // 6. Collect streaming response.
        final collected = await _collectStream(responseStream);

        // The Melious chat-audio adapter supplies provider-reported billing
        // and environmental impact through this collector; other providers
        // leave it empty.
        final attributionEnvelope = await _recordAttributedConsumption(
          attribution: attribution,
          entryId: audioEntryId,
          taskId: linkedTaskId,
          categoryId: entity.meta.categoryId,
          skillId: skill.id,
          provider: provider,
          modelId: modelId,
          responseType: skill.skillType.toResponseType,
          usage: collected.usage,
          impact: impactCollector?.impact,
          start: start,
          interactionKind: AiInteractionKind.audioTranscription,
          requestText:
              '${promptResult.systemMessage}\n${promptResult.userMessage}',
          responseText: collected.content,
        );

        final response = collected.content.trim();
        if (response.isEmpty) {
          throw StateError('Empty transcription response for $audioEntryId');
        }

        // 7. Save result — create AudioTranscript + update entryText.
        final currentAudio =
            await EntityStateHelper.getCurrentEntityState<JournalAudio>(
              entityId: audioEntryId,
              aiInputRepo: _aiInputRepository,
              entityTypeName: 'audio transcription',
            );
        if (currentAudio == null) {
          throw StateError('Audio entity $audioEntryId disappeared mid-run');
        }

        final transcript = AudioTranscript(
          created: DateTime.now(),
          library: provider.name,
          model: modelId,
          detectedLanguage: '-',
          transcript: response,
          processingTime: DateTime.now().difference(start),
          id: transcriptId,
          aiAttribution: attributionEnvelope,
        );

        final existingTranscripts = currentAudio.data.transcripts ?? [];
        final updated = currentAudio.copyWith(
          data: currentAudio.data.copyWith(
            transcripts: [...existingTranscripts, transcript],
          ),
          entryText: EntryText(
            plainText: response,
            markdown: response,
          ),
        );
        await _journalRepository.updateJournalEntity(updated);
        await _finalizeAttribution(attributionEnvelope);

        _loggingService.log(
          LogDomain.ai,
          'Skill-based transcription completed for $audioEntryId '
          '(${response.length} chars)',
          subDomain: 'runTranscription',
        );
      },
    );

    // Outside the status-tracking body on purpose. Inside it, the
    // transcription's own Siri-waveform bar kept animating through the summary
    // call — reporting "transcribing" for a run that had already written its
    // transcript. The summary tracks its own status, and awaiting here still
    // orders it before the caller's agent nudge so the agent's first read sees
    // the summary.
    await _maybeRunAudioSummary(
      audioEntryId: audioEntryId,
      automationResult: automationResult,
      linkedTaskId: linkedTaskId,
    );
  }

  /// Run skill-based image analysis on an image entry.
  ///
  /// When [overrideModelId] is non-null and resolves to a valid
  /// `AiConfigModel`, the run uses that model and its parent provider
  /// instead of the profile's image-recognition slot. This is the
  /// per-invocation override path used by the popup-menu picker, so
  /// the user can route a single photo to a different model without
  /// changing the entire profile. A stale or unresolvable override
  /// falls back to the profile slot (with a warning log) — stranding
  /// the user is worse than ignoring a stale id.
  ///
  /// After the attributed path stores the analysis, every parent **task** of
  /// the image (all tasks linking to it, plus [linkedTaskId] when present —
  /// non-task parents are skipped) is marked dirty via the standard
  /// child-changed notification pairs, so each parent task's agent picks the
  /// new analysis up on its normal subscription wake.
  Future<void> runImageAnalysis({
    required String imageEntryId,
    required AutomationResult automationResult,
    String? linkedTaskId,
    String? overrideModelId,
    GeminiThinkingMode? geminiThinkingMode,
  }) async {
    final skill = automationResult.skill;
    final profile = automationResult.resolvedProfile;
    if (skill == null || profile == null) {
      throw StateError(
        'AutomationResult missing skill or profile for $imageEntryId: '
        'skill=${skill != null}, profile=${profile != null}',
      );
    }
    final target = await _resolveImageAnalysisTarget(
      profile: profile,
      overrideModelId: overrideModelId,
    );
    final provider = target.provider;
    final modelId = target.modelId;
    final effectiveThinkingMode = _geminiThinkingModeForTarget(
      target,
      geminiThinkingMode,
    );
    if (provider == null || modelId == null) {
      developer.log(
        'Profile missing image recognition provider/model for $imageEntryId',
        name: _logTag,
      );
      return;
    }

    await _withStatusTracking(
      entityId: imageEntryId,
      responseType: skill.skillType.toResponseType,
      subDomain: 'runImageAnalysis',
      linkedTaskId: linkedTaskId,
      body: () async {
        // 1. Fetch the image entity.
        final entity = await _aiInputRepository.getEntity(imageEntryId);
        if (entity is! JournalImage) {
          throw StateError('Entity $imageEntryId is not a JournalImage');
        }

        // 2. Build context for prompts.
        final taskContext = linkedTaskId != null
            ? await _aiInputRepository.buildTaskDetailsJson(id: linkedTaskId)
            : null;
        final linkedTasks = linkedTaskId != null
            ? await _aiInputRepository.buildLinkedTasksJson(linkedTaskId)
            : null;
        final currentTaskSummary = await _buildCurrentTaskSummary(
          entity,
          linkedTaskId,
        );

        // 3. Build prompts via SkillPromptBuilder.
        //
        // Tiers are requested only when the resolved vision model can call
        // tools. Plenty of capable vision models cannot, and this skill has
        // shipped on a free-text contract for a long time — so tool support
        // upgrades the output rather than gating it, and a model without it
        // keeps producing exactly what it produces today.
        final useTieredSummary = target.model?.supportsFunctionCalling ?? false;
        const promptBuilder = SkillPromptBuilder();
        final promptResult = promptBuilder.build(
          skill: skill,
          taskContext: taskContext,
          linkedTasks: linkedTasks,
          currentTaskSummary: currentTaskSummary,
          requestTieredSummary: useTieredSummary,
        );

        // 4. Prepare image data.
        final images = await _prepareImageData(entity);
        if (images.isEmpty) {
          throw StateError('No image data available for $imageEntryId');
        }

        // 5. Call inference with separate system/user messages.
        final start = DateTime.now();
        final responseId = uuid.v4();
        final attribution = await _beginAttribution(
          workType: AiWorkType.imageAnalysis,
          source: entity,
          output: AiArtifactReference(
            type: AiArtifactType.journalAiResponse,
            id: responseId,
          ),
          skill: skill,
          automationResult: automationResult,
          taskId: linkedTaskId,
        );
        final impactCollector = InferenceImpactCollector();
        final responseStream = _cloudRepository.generateWithImages(
          promptResult.userMessage,
          baseUrl: provider.baseUrl,
          apiKey: provider.apiKey,
          model: modelId,
          temperature: null,
          images: images,
          provider: provider,
          systemMessage: promptResult.systemMessage,
          tools: useTieredSummary ? [entrySummaryTool] : null,
          toolChoice: useTieredSummary ? entrySummaryToolChoice : null,
          geminiThinkingMode: effectiveThinkingMode,
          impactCollector: impactCollector,
        );

        // 6. Collect streaming response.
        final collected = await _collectStream(responseStream);

        // Decode the tiers when we asked for them. Unlike the audio summary,
        // a rejected tool call does NOT fail the run and buys no retry: the
        // analysis is the artifact users have always got, the tiers only make
        // it easier to scan, and losing an analysis to reclaim a one-liner
        // would be a bad trade. A model that answered in prose instead simply
        // lands on the untiered path below.
        EntrySummary? tiers;
        if (useTieredSummary) {
          try {
            tiers = parseEntrySummaryToolCall(collected.toolCalls);
          } on EntrySummaryToolException catch (e) {
            _loggingService.log(
              LogDomain.ai,
              'Image analysis tiers unavailable for $imageEntryId '
              '(${e.reason}) — falling back to the prose analysis',
              subDomain: 'runImageAnalysis',
            );
          }
        }

        final attributionEnvelope = await _recordAttributedConsumption(
          attribution: attribution,
          entryId: imageEntryId,
          taskId: linkedTaskId,
          categoryId: entity.meta.categoryId,
          skillId: skill.id,
          provider: provider,
          modelId: modelId,
          responseType: skill.skillType.toResponseType,
          usage: collected.usage,
          impact: impactCollector.impact,
          start: start,
          interactionKind: AiInteractionKind.imageAnalysis,
          requestText:
              '${promptResult.systemMessage}\n${promptResult.userMessage}',
          responseText: collected.content,
        );

        // The tool's `summary` argument IS the analysis when tiers came back;
        // otherwise the streamed prose is, exactly as before.
        final response = tiers?.summary ?? collected.content.trim();
        if (response.isEmpty) {
          throw StateError(
            'Empty image analysis response for $imageEntryId',
          );
        }

        // 7. Re-read before persisting either projection so a source deleted
        // mid-run cannot leave a detached analysis behind.
        final currentImage =
            await EntityStateHelper.getCurrentEntityState<JournalImage>(
              entityId: imageEntryId,
              aiInputRepo: _aiInputRepository,
              entityTypeName: 'image analysis',
            );
        if (currentImage == null) {
          throw StateError('Image entity $imageEntryId disappeared mid-run');
        }

        // Attributed clients save analysis as its own authoritative output.
        // The compatibility path below remains the only write when the new
        // service is not registered (older tests/partial composition roots).
        if (attribution != null) {
          final aiResponse = await _aiInputRepository.createAiResponseEntry(
            id: responseId,
            data: AiResponseData(
              model: modelId,
              systemMessage: promptResult.systemMessage,
              prompt: promptResult.userMessage,
              thoughts: '',
              response: response,
              oneLiner: tiers?.oneLiner,
              tldr: tiers?.tldr,
              skillId: skill.id,
              type: skill.skillType.toResponseType,
              aiAttribution: attributionEnvelope,
            ),
            start: start,
            linkedId: imageEntryId,
            categoryId: entity.meta.categoryId,
          );
          if (aiResponse == null) {
            throw StateError(
              'Failed to persist image analysis for $imageEntryId',
            );
          }
          await _finalizeAttribution(attributionEnvelope);

          // The analysis entry is linked FROM the image, so its creation only
          // notifies the image and response ids — notification propagation is
          // one hop, and the parent tasks never hear about it. Emit the same
          // child-changed pairs `updateDbEntity` produces when the image
          // itself is edited — for EVERY parent task of the image, not just
          // the resolved [linkedTaskId]: an image can be linked from several
          // tasks, and each parent's agent needs its normal subscription wake
          // (120 s coalescing, automatic-updates opt-in / stale-marking) to
          // pick up the new analysis. Non-task parents are skipped — only
          // task contexts render image analyses, so waking their agents
          // would burn inference on invisible content. [linkedTaskId] is
          // unioned in because task resolution may have matched an outgoing
          // image→task link the incoming-parents query does not cover. The
          // legacy branch below needs no equivalent: its image update
          // propagates on its own.
          await _notifyParentTasksOfNestedResponse(
            sourceEntryId: imageEntryId,
            linkedTaskId: linkedTaskId,
            subDomain: 'runImageAnalysis',
          );
        } else {
          final originalText = currentImage.entryText?.markdown ?? '';
          final amendedText = originalText.isEmpty
              ? response
              : '$originalText\n\n$response';

          final updated = currentImage.copyWith(
            entryText: EntryText(
              plainText: amendedText,
              markdown: amendedText,
            ),
          );
          await _journalRepository.updateJournalEntity(updated);
        }

        _loggingService.log(
          LogDomain.ai,
          'Skill-based image analysis completed for $imageEntryId '
          '(${response.length} chars)',
          subDomain: 'runImageAnalysis',
        );
      },
    );
  }

  /// Runs the profile's automated audio-summary skill, if it has one.
  ///
  /// Hangs off the end of [runTranscription] rather than off each of its six
  /// callers (automatic recording trigger, synced-audio dispatcher, manual
  /// picker, relationship and goal check-ins, Daily OS capture) so every route
  /// that produces a transcript gets the same follow-up exactly once.
  ///
  /// Four gates, all deliberate:
  /// - **A task must be resolved.** The summary is framed by the task it
  ///   belongs to, and the skill's `fullTask` context policy has nothing to
  ///   read without one. Goal and person check-ins and standalone voice notes
  ///   transcribe as before and get no summary.
  /// - **The transcription itself must have been automated**, which is what a
  ///   non-null `skillAssignment` means: only `ProfileAutomationService`'s
  ///   automated paths set it, and only those passed the category's
  ///   automatic-inference consent check. The manual picker and
  ///   `requestTranscription` both build an assignment-less result, and both
  ///   deliberately skip that check because a button press is its own consent.
  ///   That consent covers the transcription the user asked for — not a second
  ///   model call they did not. Manual users reach the summary through the
  ///   "Summarize Recording" skill in the same menu.
  /// - **The profile must assign the summary skill with `automate: true`.**
  ///   Reuses the already-resolved profile rather than walking resolution
  ///   again.
  /// - **Failures never propagate.** The transcript is persisted and is the
  ///   valuable artifact; letting a summary failure surface here would mark
  ///   the whole transcription run as failed and invite a retry that
  ///   re-transcribes audio that transcribed fine.
  Future<void> _maybeRunAudioSummary({
    required String audioEntryId,
    required AutomationResult automationResult,
    required String? linkedTaskId,
  }) async {
    if (linkedTaskId == null) return;
    if (automationResult.skillAssignment == null) return;
    final profile = automationResult.resolvedProfile;
    if (profile == null) return;

    try {
      final assignment = profile.skillAssignments
          .where((a) => a.automate)
          .map(
            (a) => (assignment: a, skill: findBuiltInSkill(a.skillId)),
          )
          .where((pair) => pair.skill?.skillType == SkillType.audioSummary)
          .firstOrNull;
      if (assignment == null) return;

      await runAudioSummary(
        audioEntryId: audioEntryId,
        automationResult: AutomationResult(
          handled: true,
          skill: assignment.skill,
          skillAssignment: assignment.assignment,
          resolvedProfile: profile,
        ),
        linkedTaskId: linkedTaskId,
      );
    } catch (e, stackTrace) {
      // Belt and braces, and unreachable today: `runAudioSummary` routes every
      // operational failure through `_withStatusTracking`, which swallows and
      // reports rather than rethrows, and its two programmer-error throws are
      // both guarded above. Kept because this is the seam that protects a
      // *persisted transcript* from a future change to that contract — the
      // cost of being wrong here is losing the transcription's result to a
      // summary bug, which is exactly the trade this method exists to prevent.
      _loggingService.error(
        LogDomain.ai,
        e,
        stackTrace: stackTrace,
        subDomain: 'maybeRunAudioSummary',
      );
    }
  }

  /// Run skill-based summarization of an audio recording's transcript.
  ///
  /// Produces a three-tier summary — one-liner, TLDR, full markdown — as an
  /// [AiResponseEntry] linked to the audio entry, mirroring how an image
  /// analysis hangs off its image. The one-liner is what the collapsed audio
  /// card shows in place of the raw transcript's first line.
  ///
  /// The summary is a **point-in-time snapshot**: the task context is built
  /// here, at run time, and frozen into the prompt. Re-running later against a
  /// changed task produces a different summary, and both are kept — readers
  /// take the newest.
  ///
  /// Runs on the profile's thinking slot (see [_resolveAudioSummaryTarget])
  /// and publishes through a pinned tool call, so the tiers arrive as typed
  /// arguments rather than prose anyone has to parse. A model that ends its
  /// turn without calling the tool gets exactly one forced retry before the
  /// run gives up.
  ///
  /// Returns silently without persisting anything when the transcript is
  /// shorter than [_audioSummaryMinChars] — a one-liner of a one-sentence note
  /// is pure cost, and the collapsed card's transcript-prefix fallback already
  /// reads fine at that length.
  Future<void> runAudioSummary({
    required String audioEntryId,
    required AutomationResult automationResult,
    String? linkedTaskId,
    String? overrideModelId,
    GeminiThinkingMode? geminiThinkingMode,
  }) async {
    final skill = automationResult.skill;
    final profile = automationResult.resolvedProfile;
    if (skill == null || profile == null) {
      throw StateError(
        'AutomationResult missing skill or profile for $audioEntryId: '
        'skill=${skill != null}, profile=${profile != null}',
      );
    }
    final target = await _resolveAudioSummaryTarget(
      profile: profile,
      overrideModelId: overrideModelId,
    );
    // Like prompt generation, the fallback here is the profile's *required*
    // thinking slot, so the resolved target always carries a provider and a
    // model id — unlike the optional transcription / image slots, which is
    // why those paths null-check and this one does not.
    final provider = target.provider!;
    final modelId = target.modelId!;
    final effectiveThinkingMode = _geminiThinkingModeForTarget(
      target,
      geminiThinkingMode,
    );

    // The thinking slot is constrained to tool-capable models by the profile
    // form, so this is an assertion rather than a fallback: it only fires for
    // a profile seeded programmatically (bypassing the picker) or a model row
    // whose user-editable capability flag is wrong. Skipping is the honest
    // outcome — firing a pinned tool call at a model that cannot call tools
    // burns the call and returns nothing usable.
    if (target.model != null && !target.model!.supportsFunctionCalling) {
      _loggingService.log(
        LogDomain.ai,
        'Skipping audio summary for $audioEntryId: resolved model $modelId '
        'is not marked as supporting function calling',
        subDomain: 'runAudioSummary',
      );
      return;
    }

    await _withStatusTracking(
      entityId: audioEntryId,
      responseType: skill.skillType.toResponseType,
      subDomain: 'runAudioSummary',
      linkedTaskId: linkedTaskId,
      body: () async {
        // 1. Fetch the audio entity.
        final entity = await _aiInputRepository.getEntity(audioEntryId);
        if (entity is! JournalAudio) {
          throw StateError('Entity $audioEntryId is not a JournalAudio');
        }

        // 2. Resolve the text to summarize — an edit wins over the raw
        // transcript, same precedence every other consumer uses.
        final entryContent = _resolveEntryContent(entity);
        if (entryContent.length < _audioSummaryMinChars) {
          _loggingService.log(
            LogDomain.ai,
            'Skipping audio summary for $audioEntryId: transcript is '
            '${entryContent.length} chars, under the '
            '$_audioSummaryMinChars minimum',
            subDomain: 'runAudioSummary',
          );
          return;
        }

        // 3. Build task context. This is the snapshot the summary is framed
        // by; it is deliberately read now rather than referenced later.
        final (String? taskContext, String? linkedTasks) = linkedTaskId != null
            ? await (
                _aiInputRepository.buildTaskDetailsJson(id: linkedTaskId),
                _aiInputRepository.buildLinkedTasksJson(linkedTaskId),
              ).wait
            : (null, null);

        // 4. Build prompts via SkillPromptBuilder.
        const promptBuilder = SkillPromptBuilder();
        final promptResult = promptBuilder.build(
          skill: skill,
          entryContent: entryContent,
          taskContext: taskContext,
          linkedTasks: linkedTasks,
        );

        // 5. Call inference with the summary tool pinned.
        final start = DateTime.now();
        final responseId = uuid.v4();
        final attribution = await _beginAttribution(
          workType: AiWorkType.audioSummary,
          source: entity,
          output: AiArtifactReference(
            type: AiArtifactType.journalAiResponse,
            id: responseId,
          ),
          skill: skill,
          automationResult: automationResult,
          taskId: linkedTaskId,
        );
        // Each attempt gets its OWN collector. `InferenceImpactCollector` is a
        // single mutable slot, so sharing one across the retry would let the
        // second call's impact overwrite the first's and silently drop a real
        // provider charge from the ledger.
        Future<
          ({
            String content,
            List<ChatCompletionMessageToolCall> toolCalls,
            CompletionUsage? usage,
            MeliousCallImpact? impact,
          })
        >
        callModel(String userMessage) async {
          final collector = InferenceImpactCollector();
          final result = await _collectStream(
            _cloudRepository.generate(
              userMessage,
              model: modelId,
              temperature: null,
              baseUrl: provider.baseUrl,
              apiKey: provider.apiKey,
              provider: provider,
              systemMessage: promptResult.systemMessage,
              tools: [entrySummaryTool],
              toolChoice: entrySummaryToolChoice,
              geminiThinkingMode: effectiveThinkingMode,
              impactCollector: collector,
            ),
          );
          return (
            content: result.content,
            toolCalls: result.toolCalls,
            usage: result.usage,
            impact: collector.impact,
          );
        }

        // 6. Decode the tool call. One forced retry covers the common
        // failure — a model that narrates instead of calling, or emits a
        // one-liner over the length cap — without turning a persistently
        // misbehaving model into an unbounded retry loop.
        //
        // Spend from BOTH attempts is billed, and it is billed even when the
        // retry also fails: the provider ran the calls either way, so throwing
        // before the ledger write would make a model that never produces a
        // usable summary look free — exactly the model whose cost the user
        // most needs to see.
        var attempt = await callModel(promptResult.userMessage);
        var usage = attempt.usage;
        var impact = attempt.impact;
        EntrySummary? summary;
        EntrySummaryToolException? failure;

        try {
          summary = parseEntrySummaryToolCall(attempt.toolCalls);
        } on EntrySummaryToolException catch (first) {
          _loggingService.log(
            LogDomain.ai,
            'Audio summary tool call rejected for $audioEntryId '
            '(${first.reason}) — retrying once',
            subDomain: 'runAudioSummary',
          );
          attempt = await callModel(
            '${promptResult.userMessage}\n\n'
            'Your previous response was rejected: ${first.reason}. '
            'Call the $entrySummaryToolName tool with all three arguments '
            'and respond with nothing else.',
          );
          usage = _mergeUsage(usage, attempt.usage);
          impact = _mergeImpact(impact, attempt.impact);
          try {
            summary = parseEntrySummaryToolCall(attempt.toolCalls);
          } on EntrySummaryToolException catch (second) {
            failure = second;
          }
        }

        final attributionEnvelope = await _recordAttributedConsumption(
          attribution: attribution,
          entryId: audioEntryId,
          taskId: linkedTaskId,
          categoryId: entity.meta.categoryId,
          skillId: skill.id,
          provider: provider,
          modelId: modelId,
          responseType: skill.skillType.toResponseType,
          usage: usage,
          impact: impact,
          start: start,
          interactionKind: AiInteractionKind.textGeneration,
          requestText:
              '${promptResult.systemMessage}\n${promptResult.userMessage}',
          responseText: summary?.summary ?? '',
        );

        if (summary == null) {
          throw failure!;
        }

        // 7. Re-read the source before persisting so a recording deleted
        // mid-run cannot leave a detached summary behind.
        final currentAudio =
            await EntityStateHelper.getCurrentEntityState<JournalAudio>(
              entityId: audioEntryId,
              aiInputRepo: _aiInputRepository,
              entityTypeName: 'audio summary',
            );
        if (currentAudio == null) {
          throw StateError('Audio entity $audioEntryId disappeared mid-run');
        }

        // 8. Persist as an AiResponseEntry linked to the AUDIO entry, never
        // to the task: the summary is about this recording, and the collapsed
        // card resolves it by walking the recording's linked responses.
        final aiResponse = await _aiInputRepository.createAiResponseEntry(
          id: responseId,
          data: AiResponseData(
            model: modelId,
            systemMessage: promptResult.systemMessage,
            prompt: promptResult.userMessage,
            thoughts: '',
            response: summary.summary,
            oneLiner: summary.oneLiner,
            tldr: summary.tldr,
            skillId: skill.id,
            type: skill.skillType.toResponseType,
            aiAttribution: attributionEnvelope,
          ),
          start: start,
          linkedId: audioEntryId,
          categoryId: entity.meta.categoryId,
        );
        if (aiResponse == null) {
          throw StateError('Failed to persist audio summary for $audioEntryId');
        }
        await _finalizeAttribution(attributionEnvelope);

        await _notifyParentTasksOfNestedResponse(
          sourceEntryId: audioEntryId,
          linkedTaskId: linkedTaskId,
          subDomain: 'runAudioSummary',
        );

        _loggingService.log(
          LogDomain.ai,
          'Skill-based audio summary completed for $audioEntryId '
          '(${summary.summary.length} chars)',
          subDomain: 'runAudioSummary',
        );
      },
    );
  }

  /// Run skill-based prompt generation on a [JournalAudio] or [JournalEntry].
  ///
  /// Uses the profile's high-end thinking model (falling back to the regular
  /// thinking model) to transform the entry's content (audio transcript or
  /// typed text) plus task context into a detailed prompt. The result is
  /// saved as an [AiResponseEntry] linked to the source entry.
  /// When [referenceImages] is non-empty and the resolved target model still
  /// supports image input, they are forwarded with the text as a multimodal
  /// prompt-generation request.
  Future<void> runPromptGeneration({
    required String entryId,
    required AutomationResult automationResult,
    String? linkedTaskId,
    List<ProcessedReferenceImage>? referenceImages,
    String? overrideModelId,
    GeminiThinkingMode? geminiThinkingMode,
  }) async {
    final skill = automationResult.skill;
    final profile = automationResult.resolvedProfile;
    if (skill == null || profile == null) {
      throw StateError(
        'AutomationResult missing skill or profile for $entryId: '
        'skill=${skill != null}, profile=${profile != null}',
      );
    }
    final target = await _resolvePromptGenerationTarget(
      profile: profile,
      overrideModelId: overrideModelId,
    );
    // Unlike the optional transcription/image slots, the prompt-generation
    // fallback is the profile's required thinking slot, so the resolved
    // target always carries a provider and model id.
    final provider = target.provider!;
    final modelId = target.modelId!;
    final effectiveThinkingMode = _geminiThinkingModeForTarget(
      target,
      geminiThinkingMode,
    );

    await _withStatusTracking(
      entityId: entryId,
      responseType: skill.skillType.toResponseType,
      subDomain: 'runPromptGeneration',
      linkedTaskId: linkedTaskId,
      body: () async {
        // 1. Fetch the source entity.
        final entity = await _aiInputRepository.getEntity(entryId);
        if (entity == null) {
          throw StateError('Entity $entryId not found for prompt generation');
        }
        if (entity is! JournalAudio && entity is! JournalEntry) {
          throw StateError(
            'Entity $entryId is not a JournalAudio or JournalEntry '
            '(got ${entity.runtimeType}); prompt generation requires a '
            'text-bearing entry',
          );
        }

        // 2. Extract the entry content (transcript or typed text).
        final entryContent = _resolveEntryContent(entity);

        // 3. Build task context (parallel for independent calls).
        final (String? taskContext, String? linkedTasks) = linkedTaskId != null
            ? await (
                _aiInputRepository.buildTaskDetailsJson(id: linkedTaskId),
                _aiInputRepository.buildLinkedTasksJson(linkedTaskId),
              ).wait
            : (null, null);

        // 4. Build prompts via SkillPromptBuilder.
        const promptBuilder = SkillPromptBuilder();
        final promptResult = promptBuilder.build(
          skill: skill,
          entryContent: entryContent,
          taskContext: taskContext,
          linkedTasks: linkedTasks,
        );

        // 5. Call inference, using the existing multimodal request path only
        // when the user selected task images. Empty selection is deliberately
        // identical to the historical text-only request.
        final start = DateTime.now();
        final responseId = uuid.v4();
        final attribution = await _beginAttribution(
          workType: skill.skillType == SkillType.promptGeneration
              ? AiWorkType.codingPrompt
              : AiWorkType.textGeneration,
          source: entity,
          output: AiArtifactReference(
            type: AiArtifactType.journalAiResponse,
            id: responseId,
          ),
          skill: skill,
          automationResult: automationResult,
          taskId: linkedTaskId,
        );
        final impactCollector = InferenceImpactCollector();
        final requestedImageCount = referenceImages?.length ?? 0;
        final resolvedModel = target.model;
        final selectedImages =
            resolvedModel != null &&
                supportsChatImageInput(
                  model: resolvedModel,
                  provider: target.provider,
                )
            ? referenceImages ?? const []
            : const <ProcessedReferenceImage>[];
        if (requestedImageCount > 0 && selectedImages.isEmpty) {
          _loggingService.log(
            LogDomain.ai,
            resolvedModel == null
                ? 'Dropping $requestedImageCount selected image(s) for '
                      '$entryId: model metadata is unavailable for $modelId'
                : 'Dropping $requestedImageCount selected image(s) for '
                      '$entryId: resolved model $modelId does not accept '
                      'chat images',
            subDomain: 'runPromptGeneration',
          );
        }
        final responseStream = selectedImages.isEmpty
            ? _cloudRepository.generate(
                promptResult.userMessage,
                model: modelId,
                temperature: null,
                baseUrl: provider.baseUrl,
                apiKey: provider.apiKey,
                provider: provider,
                systemMessage: promptResult.systemMessage,
                geminiThinkingMode: effectiveThinkingMode,
                impactCollector: impactCollector,
              )
            : _cloudRepository.generateWithImages(
                promptResult.userMessage,
                model: modelId,
                temperature: null,
                baseUrl: provider.baseUrl,
                apiKey: provider.apiKey,
                provider: provider,
                systemMessage: promptResult.systemMessage,
                images: selectedImages
                    .map((image) => image.base64Data)
                    .toList(growable: false),
                geminiThinkingMode: effectiveThinkingMode,
                impactCollector: impactCollector,
              );

        // 6. Collect streaming response.
        final collected = await _collectStream(responseStream);

        final attributionEnvelope = await _recordAttributedConsumption(
          attribution: attribution,
          entryId: entryId,
          taskId: linkedTaskId,
          categoryId: entity.meta.categoryId,
          skillId: skill.id,
          provider: provider,
          modelId: modelId,
          responseType: skill.skillType.toResponseType,
          usage: collected.usage,
          impact: impactCollector.impact,
          start: start,
          interactionKind: AiInteractionKind.textGeneration,
          requestText:
              '${promptResult.systemMessage}\n${promptResult.userMessage}',
          responseText: collected.content,
        );

        final response = collected.content.trim();
        if (response.isEmpty) {
          throw StateError(
            'Empty prompt generation response for $entryId',
          );
        }

        // 7. Save result as AiResponseEntry. The response type is derived
        // from the skill so the same runner can serve both
        // `promptGeneration` and `imagePromptGeneration` skills without
        // mislabelling persisted responses. The `skillId` lets the UI
        // distinguish sibling prompt-generation skills (coding / design /
        // research) that share the same response type.
        final data = AiResponseData(
          model: modelId,
          systemMessage: promptResult.systemMessage,
          prompt: promptResult.userMessage,
          thoughts: '',
          response: response,
          skillId: skill.id,
          type: skill.skillType.toResponseType,
          aiAttribution: attributionEnvelope,
        );

        // Coding prompts attach to the parent task (like cover art) so each
        // generated prompt becomes part of the task context and later prompts
        // can build on earlier ones. Scoped to `SkillType.promptGeneration`
        // (coding / design / research); image-prompt generation keeps its
        // entry link. Falls back to the source entry when there is no parent
        // task.
        final linkedId =
            skill.skillType == SkillType.promptGeneration &&
                linkedTaskId != null
            ? linkedTaskId
            : entryId;

        final aiResponse = attributionEnvelope == null
            ? await _aiInputRepository.createAiResponseEntry(
                data: data,
                start: start,
                linkedId: linkedId,
                categoryId: entity.meta.categoryId,
              )
            : await _aiInputRepository.createAiResponseEntry(
                id: responseId,
                data: data,
                start: start,
                linkedId: linkedId,
                categoryId: entity.meta.categoryId,
              );
        if (aiResponse == null) {
          throw StateError('Failed to persist generated prompt for $entryId');
        }
        await _finalizeAttribution(attributionEnvelope);

        // Additionally link the coding prompt back to the source entry so it
        // shows in both the task's and the originating audio/text entry's
        // linked-entries lists. Skipped when the primary link already IS the
        // source entry (no parent task, or image-prompt generation), which
        // would otherwise create a duplicate self-link.
        //
        // Isolated in its own try/catch: the prompt is already persisted and
        // linked to the task, so a failed back-link must not propagate to
        // `_withStatusTracking` and mark the whole run as `error` — that would
        // risk a user-triggered retry creating a duplicate prompt. Log and
        // move on instead.
        if (linkedId != entryId) {
          try {
            final linked = await _aiInputRepository.createLink(
              fromId: entryId,
              toId: aiResponse.id,
            );
            if (!linked) {
              _loggingService.log(
                LogDomain.ai,
                'Secondary link from $entryId to ${aiResponse.id} not created',
                subDomain: 'runPromptGeneration',
              );
            }
          } catch (error, stackTrace) {
            _loggingService.error(
              LogDomain.ai,
              error,
              stackTrace: stackTrace,
              subDomain: 'runPromptGeneration',
              message:
                  'Secondary link from $entryId to ${aiResponse.id} failed',
            );
          }
        }

        _loggingService.log(
          LogDomain.ai,
          'Skill-based prompt generation completed for $entryId '
          '(${response.length} chars)',
          subDomain: 'runPromptGeneration',
        );
      },
    );
  }

  /// Run skill-based image generation on a [JournalAudio] or [JournalEntry].
  ///
  /// Generates a cover art image using the task context, the entry's content
  /// (audio transcript or typed text), and optional reference images. The
  /// generated image is automatically imported as a [JournalImage] and set
  /// as the task's cover art.
  Future<void> runImageGeneration({
    required String entryId,
    required AutomationResult automationResult,
    required String linkedTaskId,
    List<ProcessedReferenceImage>? referenceImages,
    String? overrideModelId,
  }) async {
    // Derive the response type from the skill when present so future skill
    // variants (or test stubs) drive the status controller correctly.
    // Falls back to `imageGeneration` only when the automation result is
    // misconfigured — that path immediately throws inside `_withStatusTracking`.
    final responseType =
        automationResult.skill?.skillType.toResponseType ??
        AiResponseType.imageGeneration;

    // Clear any error from a previous attempt so the UI starts this run fresh.
    _setImageGenerationError(
      null,
      entityId: entryId,
      linkedTaskId: linkedTaskId,
    );

    await _withStatusTracking(
      entityId: entryId,
      responseType: responseType,
      subDomain: 'runImageGeneration',
      linkedTaskId: linkedTaskId,
      onError: (error) {
        // Surface the provider's verbatim reason to the UI when we have one
        // (e.g. a Gemini `finishReason`); other failures (network, internal)
        // carry no provider reason and fall back to a generic message.
        final providerReason = error is ImageGenerationException
            ? error.providerReason
            : null;
        _setImageGenerationError(
          providerReason,
          entityId: entryId,
          linkedTaskId: linkedTaskId,
        );
      },
      body: () async {
        // 0. Validate automation result — inside status tracking so the UI
        // transitions to running before any early throw/return (prevents the
        // progress view from spinning forever on misconfigured profiles).
        final skill = automationResult.skill;
        final profile = automationResult.resolvedProfile;
        if (skill == null || profile == null) {
          throw StateError(
            'AutomationResult missing skill or profile for $entryId: '
            'skill=${skill != null}, profile=${profile != null}',
          );
        }
        // Honour the per-invocation model override (chosen in the
        // provider→model picker) when it resolves, otherwise fall back to the
        // profile's image-generation slot.
        final target = await _resolveImageGenerationTarget(
          profile: profile,
          overrideModelId: overrideModelId,
        );
        final provider = target.provider;
        final modelId = target.modelId;
        if (provider == null || modelId == null) {
          throw StateError(
            'Profile missing image generation provider/model for '
            '$entryId',
          );
        }

        // 1. Fetch the source entity (transcript or typed description).
        final entity = await _aiInputRepository.getEntity(entryId);
        if (entity == null) {
          throw StateError('Entity $entryId not found for image generation');
        }
        if (entity is! JournalAudio && entity is! JournalEntry) {
          throw StateError(
            'Entity $entryId is not a JournalAudio or JournalEntry '
            '(got ${entity.runtimeType}); image generation requires a '
            'text-bearing entry',
          );
        }

        // 2. Extract the entry content (user's description).
        final entryContent = _resolveEntryContent(entity);

        // 3. Build task context and summary in parallel.
        final (taskContext, linkedTasks) = await (
          _aiInputRepository.buildTaskDetailsJson(id: linkedTaskId),
          _aiInputRepository.buildLinkedTasksJson(linkedTaskId),
        ).wait;
        final currentTaskSummary = await _buildCurrentTaskSummary(
          entity,
          linkedTaskId,
        );

        // 4. Build prompts via SkillPromptBuilder.
        const promptBuilder = SkillPromptBuilder();
        final promptResult = promptBuilder.build(
          skill: skill,
          entryContent: entryContent,
          taskContext: taskContext,
          linkedTasks: linkedTasks,
          currentTaskSummary: currentTaskSummary,
        );

        // 5. Generate image via the cloud inference repository.
        developer.log(
          'Generating cover art for task $linkedTaskId '
          '(${referenceImages?.length ?? 0} reference images)',
          name: _logTag,
        );

        final start = DateTime.now();
        final imageId = uuid.v1();
        final attribution = await _beginAttribution(
          workType: AiWorkType.imageGeneration,
          source: entity,
          output: AiArtifactReference(
            type: AiArtifactType.journalImage,
            id: imageId,
          ),
          skill: skill,
          automationResult: automationResult,
          taskId: linkedTaskId,
        );
        final impactCollector = InferenceImpactCollector();
        final generatedImage = await _cloudRepository.generateImage(
          prompt: promptResult.userMessage,
          model: modelId,
          provider: provider,
          systemMessage: promptResult.systemMessage,
          referenceImages: referenceImages,
          impactCollector: impactCollector,
        );

        // 6. Verify linked task still exists and get its category.
        final taskEntity = await _journalRepository.getJournalEntityById(
          linkedTaskId,
        );

        // Image generation is a single request (no token stream), so tokens
        // are null; impact comes from the collector for Melious. Record
        // before the task-existence check below: the billed call already
        // happened, so a task deleted mid-flight must not erase its
        // cost/impact record.
        final attributionEnvelope = await _recordAttributedConsumption(
          attribution: attribution,
          entryId: entryId,
          taskId: linkedTaskId,
          categoryId: taskEntity is Task ? taskEntity.meta.categoryId : null,
          skillId: skill.id,
          provider: provider,
          modelId: modelId,
          responseType: skill.skillType.toResponseType,
          usage: null,
          impact: impactCollector.impact,
          start: start,
          interactionKind: AiInteractionKind.imageGeneration,
          requestText:
              '${promptResult.systemMessage}\n${promptResult.userMessage}',
          responseText: generatedImage.mimeType,
        );

        if (taskEntity is! Task) {
          throw StateError(
            'Linked task $linkedTaskId not found before cover art save',
          );
        }

        // 7. Import the generated image as a JournalImage linked to the task.
        final extension =
            generatedImage.mimeType.split('/').lastOrNull ?? 'png';
        final importedImageId = await importGeneratedImageBytes(
          data: Uint8List.fromList(generatedImage.bytes),
          fileExtension: extension,
          linkedId: linkedTaskId,
          categoryId: taskEntity.meta.categoryId,
          imageId: imageId,
          aiAttribution: attributionEnvelope,
        );

        if (importedImageId == null) {
          throw StateError(
            'Failed to import generated image for task $linkedTaskId',
          );
        }
        await _finalizeAttribution(attributionEnvelope);

        // 8. Set the image as cover art on the task.
        //
        // Uses `importedImageId` (the JournalImage entity's real id), NOT
        // `imageId` (the pre-generated id passed into `ImageData.imageId`
        // for attribution purposes). `createImageEntry` derives the actual
        // entity id from a uuidV5 hash of the encoded `ImageData` — it does
        // NOT reuse `imageData.imageId` as the entity id — so the two
        // values are different. Setting `coverArtId` to `imageId` silently
        // pointed the task at an id nothing was ever stored under: the
        // cover art generated successfully but never rendered anywhere.
        final updatedData = taskEntity.data.copyWith(
          coverArtId: importedImageId,
        );
        final didUpdate = await getIt<PersistenceLogic>().updateTask(
          journalEntityId: linkedTaskId,
          taskData: updatedData,
        );
        if (!didUpdate) {
          throw StateError(
            'Linked task $linkedTaskId disappeared before cover art update',
          );
        }

        _loggingService.log(
          LogDomain.ai,
          'Skill-based image generation completed for task $linkedTaskId '
          '(imageId: $importedImageId)',
          subDomain: 'runImageGeneration',
        );

        // 9. Trigger automatic image analysis on the newly created cover art,
        // treating it exactly like a manual photo drop.
        unawaited(
          _ref
              .read(automaticImageAnalysisTriggerProvider)
              .triggerAutomaticImageAnalysis(
                imageEntryId: importedImageId,
                linkedTaskId: linkedTaskId,
              ),
        );
      },
    );
  }

  /// Sums the billable and environmental impact of two attempts at the same
  /// logical call.
  ///
  /// The counterpart to [_mergeUsage], and needed for the same reason: both
  /// provider calls really happened, so reporting only the retry's cost would
  /// understate spend. Only the additive quantities are summed. The
  /// descriptive fields (data centre, provider id, PUE, renewable share) are
  /// taken from whichever attempt reported them — both attempts hit the same
  /// provider and model, so they describe one place, not two.
  ///
  /// `costCreditsDecimal` is a provider-formatted string rather than a number.
  /// It is deliberately dropped once two attempts are merged: guessing at
  /// decimal arithmetic on someone else's formatting would report a precise
  /// figure that is not the provider's, and `costCredits` already carries the
  /// summed value.
  static MeliousCallImpact? _mergeImpact(
    MeliousCallImpact? a,
    MeliousCallImpact? b,
  ) {
    if (a == null) return b;
    if (b == null) return a;
    double? sum(double? x, double? y) =>
        x == null && y == null ? null : (x ?? 0) + (y ?? 0);
    return MeliousCallImpact(
      energyKwh: sum(a.energyKwh, b.energyKwh),
      carbonGCo2: sum(a.carbonGCo2, b.carbonGCo2),
      waterLiters: sum(a.waterLiters, b.waterLiters),
      costCredits: sum(a.costCredits, b.costCredits),
      renewablePercent: a.renewablePercent ?? b.renewablePercent,
      pue: a.pue ?? b.pue,
      dataCenter: a.dataCenter ?? b.dataCenter,
      providerId: a.providerId ?? b.providerId,
    );
  }

  /// Sums the token usage of two attempts at the same logical call.
  ///
  /// The audio-summary retry issues a second request, and both are real spend.
  /// Reporting only the second would understate the cost of a model that
  /// needed prompting twice — exactly the model whose cost the user most needs
  /// to see. Null operands pass through so a provider that reports usage on
  /// only one attempt still contributes what it did report.
  static CompletionUsage? _mergeUsage(CompletionUsage? a, CompletionUsage? b) {
    if (a == null) return b;
    if (b == null) return a;
    int? sum(int? x, int? y) =>
        x == null && y == null ? null : (x ?? 0) + (y ?? 0);
    final aDetails = a.completionTokensDetails;
    final bDetails = b.completionTokensDetails;
    final aPrompt = a.promptTokensDetails;
    final bPrompt = b.promptTokensDetails;
    return CompletionUsage(
      promptTokens: sum(a.promptTokens, b.promptTokens),
      completionTokens: sum(a.completionTokens, b.completionTokens),
      totalTokens: sum(a.totalTokens, b.totalTokens),
      completionTokensDetails: aDetails == null && bDetails == null
          ? null
          : CompletionTokensDetails(
              reasoningTokens: sum(
                aDetails?.reasoningTokens,
                bDetails?.reasoningTokens,
              ),
              audioTokens: sum(aDetails?.audioTokens, bDetails?.audioTokens),
            ),
      // Carried for the same reason as the completion details: the
      // consumption event reads `cachedTokens` off this, so dropping it would
      // report null cached input on exactly the runs that retried.
      promptTokensDetails: aPrompt == null && bPrompt == null
          ? null
          : PromptTokensDetails(
              cachedTokens: sum(aPrompt?.cachedTokens, bPrompt?.cachedTokens),
              audioTokens: sum(aPrompt?.audioTokens, bPrompt?.audioTokens),
            ),
    );
  }

  /// Marks every parent task of [sourceEntryId] stale after an
  /// [AiResponseEntry] was linked beneath it.
  ///
  /// A response entry linked FROM its source only notifies the source and
  /// response ids — notification propagation is one hop, so the parent tasks
  /// never hear about it. This emits the same child-changed pairs
  /// `updateDbEntity` produces when the source entry itself is edited, for
  /// EVERY parent task rather than just the resolved [linkedTaskId]: one
  /// recording or image can be linked from several tasks, and each parent's
  /// agent needs its normal subscription wake (120 s coalescing,
  /// automatic-updates opt-in / stale-marking) to pick the new content up.
  ///
  /// Non-task parents are skipped — only task contexts render nested AI
  /// responses, so waking their agents would burn inference on content the
  /// user cannot see. [linkedTaskId] is unioned in because task resolution
  /// may have matched an outgoing entry→task link that the incoming-parents
  /// query does not cover.
  ///
  /// Never throws: the response is already persisted by the time this runs,
  /// so a failed parent lookup degrades to notifying the resolved task alone
  /// rather than failing the whole run.
  Future<void> _notifyParentTasksOfNestedResponse({
    required String sourceEntryId,
    required String subDomain,
    String? linkedTaskId,
  }) async {
    final staleIds = <String>{?linkedTaskId};
    try {
      final parents = await _journalRepository.getLinkedToEntities(
        linkedTo: sourceEntryId,
      );
      staleIds.addAll(
        parents.whereType<Task>().map((parent) => parent.meta.id),
      );
    } catch (e) {
      _loggingService.log(
        LogDomain.ai,
        'parent lookup for stale notification failed: $e',
        subDomain: subDomain,
      );
    }
    if (staleIds.isNotEmpty) {
      getIt<UpdateNotifications>().notify({
        for (final id in staleIds) ...{id, propagatedNotification(id)},
      });
    }
  }

  /// Drains a chat-completion stream, concatenating content deltas, capturing
  /// the last reported [CompletionUsage] (providers emit usage on the final
  /// chunk), and reassembling any streamed tool calls. Shared by the
  /// transcription, image-analysis, prompt-generation and audio-summary paths
  /// so the accumulation logic lives in one place.
  ///
  /// Tool-call deltas arrive fragmented — a name in one chunk, its JSON
  /// arguments spread across many more, sometimes without ids — so they go
  /// through [ToolCallAccumulator] rather than being read off a single chunk.
  /// Paths that send no `tools` simply get an empty `toolCalls` list; the
  /// collector stays one method because a skill either reads structured
  /// output or does not, and both need identical content/usage handling.
  Future<
    ({
      String content,
      CompletionUsage? usage,
      List<ChatCompletionMessageToolCall> toolCalls,
    })
  >
  _collectStream(
    Stream<CreateChatCompletionStreamResponse> stream,
  ) async {
    final buffer = StringBuffer();
    final toolCallAccumulator = ToolCallAccumulator();
    CompletionUsage? usage;
    await for (final chunk in stream) {
      if (chunk.usage != null) usage = chunk.usage;
      final delta = chunk.choices?.firstOrNull?.delta;
      final content = delta?.content;
      if (content != null) {
        buffer.write(content);
      }
      toolCallAccumulator.processChunk(delta);
    }
    return (
      content: buffer.toString(),
      usage: usage,
      toolCalls: toolCallAccumulator.toToolCalls(),
    );
  }

  Future<AiAttributionSession?> _beginAttribution({
    required AiWorkType workType,
    required JournalEntity source,
    required AiArtifactReference output,
    required AiConfigSkill skill,
    required AutomationResult automationResult,
    required String? taskId,
  }) async {
    if (!getIt.isRegistered<AiAttributionService>() ||
        !getIt.isRegistered<AiAttributionIdentityResolver>()) {
      return null;
    }
    final identity = getIt<AiAttributionIdentityResolver>();
    final human = await identity.humanInitiator();
    final automatic = automationResult.skillAssignment?.automate ?? false;
    final actor = automatic
        ? AiActorSnapshot(
            type: AiActorType.automation,
            id: 'automation:${skill.id}',
            displayName: skill.name,
            humanPrincipalId: human.humanPrincipalId,
          )
        : human;
    return getIt<AiAttributionService>().begin(
      AiAttributionStart(
        workType: workType,
        initiator: actor,
        trigger: AiTriggerSnapshot(
          type: automatic ? AiTriggerType.automatic : AiTriggerType.manual,
          skillId: skill.id,
        ),
        intendedOutputs: [output],
        taskId: taskId,
        categoryId: source.meta.categoryId,
      ),
    );
  }

  Future<AiWorkAttribution?> _recordAttributedConsumption({
    required AiAttributionSession? attribution,
    required String entryId,
    required String? taskId,
    required String? categoryId,
    required String skillId,
    required AiConfigInferenceProvider provider,
    required String modelId,
    required AiResponseType responseType,
    required CompletionUsage? usage,
    required MeliousCallImpact? impact,
    required DateTime start,
    required AiInteractionKind interactionKind,
    required String requestText,
    required String responseText,
  }) async {
    if (attribution == null) {
      return null;
    }

    final interactionId = uuid.v4();
    final completedAt = DateTime.now();
    final requestDigest = sha256.convert(utf8.encode(requestText)).toString();
    final responseDigest = sha256.convert(utf8.encode(responseText)).toString();
    final event = _consumptionEvent(
      id: interactionId,
      entryId: entryId,
      taskId: taskId,
      categoryId: categoryId,
      skillId: skillId,
      provider: provider,
      modelId: modelId,
      responseType: responseType,
      usage: usage,
      impact: impact,
      start: start,
      completedAt: completedAt,
      interactionKind: interactionKind,
      requestDigest: requestDigest,
      responseDigest: responseDigest,
    );
    await getIt<AiAttributionService>().recordInteraction(
      attributionId: attribution.id,
      event: event,
    );
    return getIt<AiAttributionService>().prepareCompletion(
      attributionId: attribution.id,
      outputs: attribution.intendedOutputs,
    );
  }

  Future<void> _finalizeAttribution(
    AiWorkAttribution? envelope,
  ) async {
    if (envelope == null || !getIt.isRegistered<AiAttributionService>()) {
      return;
    }
    await getIt<AiAttributionService>().finalize(envelope);
  }

  AiConsumptionEvent _consumptionEvent({
    required String id,
    required String entryId,
    required String? taskId,
    required String? categoryId,
    required String skillId,
    required AiConfigInferenceProvider provider,
    required String modelId,
    required AiResponseType responseType,
    required CompletionUsage? usage,
    required MeliousCallImpact? impact,
    required DateTime start,
    required DateTime completedAt,
    AiInteractionKind? interactionKind,
    String? requestDigest,
    String? responseDigest,
  }) => AiConsumptionEvent(
    id: id,
    createdAt: start,
    providerType: provider.inferenceProviderType,
    responseType: responseType.consumptionResponseType,
    vectorClock: null,
    interactionKind: interactionKind,
    completedAt: completedAt,
    requestDigest: requestDigest,
    responseDigest: responseDigest,
    interactionParameters: {
      'model': modelId,
      'providerType': provider.inferenceProviderType.name,
    },
    entryId: entryId,
    taskId: taskId,
    categoryId: categoryId,
    skillId: skillId,
    providerModelId: modelId,
    durationMs: completedAt.difference(start).inMilliseconds,
    inputTokens: usage?.promptTokens,
    outputTokens: usage?.completionTokens,
    cachedInputTokens: usage?.promptTokensDetails?.cachedTokens,
    thoughtsTokens: usage?.completionTokensDetails?.reasoningTokens,
    totalTokens: usage?.totalTokens,
    credits: impact?.costCredits,
    costCreditsDecimal: impact?.costCreditsDecimal,
    energyKwh: impact?.energyKwh,
    carbonGCo2: impact?.carbonGCo2,
    waterLiters: impact?.waterLiters,
    renewablePercent: impact?.renewablePercent,
    pue: impact?.pue,
    dataCenter: impact?.dataCenter,
    upstreamProviderId: impact?.providerId,
  );
}

/// Resolved (provider, modelId, model) tuple returned by the per-slot
/// resolver helpers. Fields may be null when the override is unresolvable and
/// the profile slot is also empty — the caller short-circuits with a "missing
/// provider/model" log in that case. The `model` field carries the resolved
/// `AiConfigModel` row so per-model settings (e.g. Gemini thinking mode)
/// survive resolution.
typedef _InferenceTarget = ({
  AiConfigInferenceProvider? provider,
  String? modelId,
  AiConfigModel? model,
});

/// Identifier for which profile slot a per-invocation override is targeting.
/// The [label] is interpolated into warning logs so a future slot kind only
/// needs a new enum value, not a new magic-string literal that could
/// typo-drift across the codebase.
enum _OverrideSlotKind {
  transcription('transcription'),
  imageAnalysis('image analysis'),
  promptGeneration('prompt generation'),
  imageGeneration('image generation'),
  audioSummary('audio summary');

  const _OverrideSlotKind(this.label);

  /// Human-readable form used in developer-log messages.
  final String label;
}

final skillInferenceRunnerProvider = Provider<SkillInferenceRunner>(
  skillInferenceRunner,
  name: 'skillInferenceRunnerProvider',
);
SkillInferenceRunner skillInferenceRunner(Ref ref) {
  final taskSummaryResolver = TaskSummaryResolver(
    getIt.isRegistered<AgentDatabase>()
        ? AgentRepository(getIt<AgentDatabase>())
        : null,
  );

  return SkillInferenceRunner(
    ref: ref,
    cloudRepository: ref.watch(cloudInferenceRepositoryProvider),
    aiInputRepository: ref.watch(aiInputRepositoryProvider),
    journalRepository: ref.watch(journalRepositoryProvider),
    loggingService: getIt<DomainLogger>(),
    taskSummaryResolver: taskSummaryResolver,
    promptBuilderHelper: PromptBuilderHelper(
      aiInputRepository: ref.watch(aiInputRepositoryProvider),
      journalRepository: ref.watch(journalRepositoryProvider),
      taskSummaryResolver: taskSummaryResolver,
    ),
  );
}
