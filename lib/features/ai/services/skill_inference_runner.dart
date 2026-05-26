import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/ai/helpers/automatic_image_analysis_trigger.dart';
import 'package:lotti/features/ai/helpers/entity_state_helper.dart';
import 'package:lotti/features/ai/helpers/prompt_builder_helper.dart';
import 'package:lotti/features/ai/helpers/skill_prompt_builder.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/task_summary_resolver.dart';
import 'package:lotti/features/ai/services/profile_automation_service.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/util/image_processing_utils.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/image_import.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'skill_inference_runner.g.dart';

const _logTag = 'SkillInferenceRunner';

/// Service that invokes inference using skill-built prompts and
/// profile-resolved models, bypassing the legacy prompt system entirely.
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
  final LoggingService _loggingService;
  final PromptBuilderHelper _promptBuilderHelper;
  final TaskSummaryResolver _taskSummaryResolver;

  /// Updates the [InferenceStatusController] for an entity (and optionally
  /// its linked task) so the Siri waveform animation reflects the current
  /// skill inference state.
  void _setStatus(
    InferenceStatus status, {
    required String entityId,
    required AiResponseType responseType,
    String? linkedTaskId,
  }) {
    _ref
        .read(
          inferenceStatusControllerProvider(
            id: entityId,
            aiResponseType: responseType,
          ).notifier,
        )
        .setStatus(status);

    if (linkedTaskId != null) {
      _ref
          .read(
            inferenceStatusControllerProvider(
              id: linkedTaskId,
              aiResponseType: responseType,
            ).notifier,
          )
          .setStatus(status);
    }
  }

  /// Wraps a skill inference body with status tracking.
  ///
  /// Sets status to [InferenceStatus.running] before [body], then
  /// [InferenceStatus.idle] on success or [InferenceStatus.error] on failure.
  /// This guarantees the status is always reset, even on early returns.
  Future<void> _withStatusTracking({
    required String entityId,
    required AiResponseType responseType,
    required String subDomain,
    required Future<void> Function() body,
    String? linkedTaskId,
  }) async {
    _setStatus(
      InferenceStatus.running,
      entityId: entityId,
      responseType: responseType,
      linkedTaskId: linkedTaskId,
    );
    try {
      await body();
      _setStatus(
        InferenceStatus.idle,
        entityId: entityId,
        responseType: responseType,
        linkedTaskId: linkedTaskId,
      );
    } catch (e, stack) {
      _setStatus(
        InferenceStatus.error,
        entityId: entityId,
        responseType: responseType,
        linkedTaskId: linkedTaskId,
      );
      _loggingService.captureException(
        e,
        domain: _logTag,
        subDomain: subDomain,
        stackTrace: stack,
      );
    }
  }

  /// Resolves the `(provider, modelId)` pair that a transcription run
  /// should target. Prefers [overrideModelId] when it resolves to a
  /// real `AiConfigModel` + parent `AiConfigInferenceProvider`; falls
  /// back to the profile's transcription slot when the override is
  /// null OR unresolvable. The fallback path logs a warning so a
  /// stale override surfaced in logs, not user-visible stranding.
  Future<_InferenceTarget> _resolveTranscriptionTarget({
    required ResolvedProfile profile,
    required String? overrideModelId,
  }) {
    return _resolveOverrideTarget(
      overrideModelId: overrideModelId,
      slotKind: _OverrideSlotKind.transcription,
      fallback: () => (
        provider: profile.transcriptionProvider,
        modelId: profile.transcriptionModelId,
      ),
    );
  }

  /// Resolves the `(provider, modelId)` pair that an image-analysis
  /// run should target. Same shape as [_resolveTranscriptionTarget]
  /// but reads the profile's image-recognition slot for the fallback
  /// path. Override resolution is identical: override must point at a
  /// real `AiConfigModel` with a resolvable parent
  /// `AiConfigInferenceProvider`, otherwise we fall back to the
  /// profile slot with a warning log.
  Future<_InferenceTarget> _resolveImageAnalysisTarget({
    required ResolvedProfile profile,
    required String? overrideModelId,
  }) {
    return _resolveOverrideTarget(
      overrideModelId: overrideModelId,
      slotKind: _OverrideSlotKind.imageAnalysis,
      fallback: () => (
        provider: profile.imageRecognitionProvider,
        modelId: profile.imageRecognitionModelId,
      ),
    );
  }

  /// Shared override-or-fallback resolver used by both
  /// [_resolveTranscriptionTarget] and [_resolveImageAnalysisTarget].
  /// Keeps the override → fallback flow in one place so the warning
  /// log shape and resolution rules stay aligned across slot kinds.
  Future<_InferenceTarget> _resolveOverrideTarget({
    required String? overrideModelId,
    required _OverrideSlotKind slotKind,
    required _InferenceTarget Function() fallback,
  }) async {
    if (overrideModelId == null) {
      return fallback();
    }
    final repo = _ref.read(aiConfigRepositoryProvider);
    final modelConfig = await repo.getConfigById(overrideModelId);
    if (modelConfig is! AiConfigModel) {
      developer.log(
        'Override ${slotKind.label} modelId $overrideModelId did not '
        'resolve to an AiConfigModel; falling back to profile slot',
        name: _logTag,
      );
      return fallback();
    }
    final providerConfig = await repo.getConfigById(
      modelConfig.inferenceProviderId,
    );
    if (providerConfig is! AiConfigInferenceProvider) {
      developer.log(
        'Override ${slotKind.label} model ${modelConfig.id} has no '
        'resolvable parent provider ${modelConfig.inferenceProviderId}; '
        'falling back to profile slot',
        name: _logTag,
      );
      return fallback();
    }
    return (
      provider: providerConfig,
      modelId: modelConfig.providerModelId,
    );
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
  Future<void> runTranscription({
    required String audioEntryId,
    required AutomationResult automationResult,
    String? linkedTaskId,
    String? overrideModelId,
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
        final responseStream = _cloudRepository.generateWithAudio(
          promptResult.userMessage,
          model: modelId,
          audioBase64: audioBase64,
          baseUrl: provider.baseUrl,
          apiKey: provider.apiKey,
          provider: provider,
          systemMessage: promptResult.systemMessage,
          speechDictionaryTerms: speechDictionaryTerms.isNotEmpty
              ? speechDictionaryTerms
              : null,
        );

        // 6. Collect streaming response.
        final buffer = StringBuffer();
        await for (final chunk in responseStream) {
          final content = chunk.choices?.firstOrNull?.delta?.content;
          if (content != null) {
            buffer.write(content);
          }
        }

        final response = buffer.toString().trim();
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

        _loggingService.captureEvent(
          'Skill-based transcription completed for $audioEntryId '
          '(${response.length} chars)',
          domain: _logTag,
          subDomain: 'runTranscription',
        );
      },
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
  Future<void> runImageAnalysis({
    required String imageEntryId,
    required AutomationResult automationResult,
    String? linkedTaskId,
    String? overrideModelId,
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
        const promptBuilder = SkillPromptBuilder();
        final promptResult = promptBuilder.build(
          skill: skill,
          taskContext: taskContext,
          linkedTasks: linkedTasks,
          currentTaskSummary: currentTaskSummary,
        );

        // 4. Prepare image data.
        final images = await _prepareImageData(entity);
        if (images.isEmpty) {
          throw StateError('No image data available for $imageEntryId');
        }

        // 5. Call inference with separate system/user messages.
        final responseStream = _cloudRepository.generateWithImages(
          promptResult.userMessage,
          baseUrl: provider.baseUrl,
          apiKey: provider.apiKey,
          model: modelId,
          temperature: null,
          images: images,
          provider: provider,
          systemMessage: promptResult.systemMessage,
        );

        // 6. Collect streaming response.
        final buffer = StringBuffer();
        await for (final chunk in responseStream) {
          final content = chunk.choices?.firstOrNull?.delta?.content;
          if (content != null) {
            buffer.write(content);
          }
        }

        final response = buffer.toString().trim();
        if (response.isEmpty) {
          throw StateError(
            'Empty image analysis response for $imageEntryId',
          );
        }

        // 7. Save result — append to entryText.
        final currentImage =
            await EntityStateHelper.getCurrentEntityState<JournalImage>(
              entityId: imageEntryId,
              aiInputRepo: _aiInputRepository,
              entityTypeName: 'image analysis',
            );
        if (currentImage == null) {
          throw StateError('Image entity $imageEntryId disappeared mid-run');
        }

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

        _loggingService.captureEvent(
          'Skill-based image analysis completed for $imageEntryId '
          '(${response.length} chars)',
          domain: _logTag,
          subDomain: 'runImageAnalysis',
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
  Future<void> runPromptGeneration({
    required String entryId,
    required AutomationResult automationResult,
    String? linkedTaskId,
  }) async {
    final skill = automationResult.skill;
    final profile = automationResult.resolvedProfile;
    if (skill == null || profile == null) {
      throw StateError(
        'AutomationResult missing skill or profile for $entryId: '
        'skill=${skill != null}, profile=${profile != null}',
      );
    }
    final provider = profile.effectiveHighEndProvider;
    final modelId = profile.effectiveHighEndModelId;

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

        // 5. Call inference with text-only (no audio/image upload).
        final start = DateTime.now();
        final responseStream = _cloudRepository.generate(
          promptResult.userMessage,
          model: modelId,
          temperature: null,
          baseUrl: provider.baseUrl,
          apiKey: provider.apiKey,
          provider: provider,
          systemMessage: promptResult.systemMessage,
          geminiThinkingMode: profile.effectiveHighEndModel?.geminiThinkingMode,
        );

        // 6. Collect streaming response.
        final buffer = StringBuffer();
        await for (final chunk in responseStream) {
          final content = chunk.choices?.firstOrNull?.delta?.content;
          if (content != null) {
            buffer.write(content);
          }
        }

        final response = buffer.toString().trim();
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
        );

        await _aiInputRepository.createAiResponseEntry(
          data: data,
          start: start,
          linkedId: entryId,
          categoryId: entity.meta.categoryId,
        );

        _loggingService.captureEvent(
          'Skill-based prompt generation completed for $entryId '
          '(${response.length} chars)',
          domain: _logTag,
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
  }) async {
    // Derive the response type from the skill when present so future skill
    // variants (or test stubs) drive the status controller correctly.
    // Falls back to `imageGeneration` only when the automation result is
    // misconfigured — that path immediately throws inside `_withStatusTracking`.
    final responseType =
        automationResult.skill?.skillType.toResponseType ??
        AiResponseType.imageGeneration;

    await _withStatusTracking(
      entityId: entryId,
      responseType: responseType,
      subDomain: 'runImageGeneration',
      linkedTaskId: linkedTaskId,
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
        final provider = profile.imageGenerationProvider;
        final modelId = profile.imageGenerationModelId;
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

        final generatedImage = await _cloudRepository.generateImage(
          prompt: promptResult.userMessage,
          model: modelId,
          provider: provider,
          systemMessage: promptResult.systemMessage,
          referenceImages: referenceImages,
        );

        // 6. Verify linked task still exists and get its category.
        final taskEntity = await _journalRepository.getJournalEntityById(
          linkedTaskId,
        );
        if (taskEntity is! Task) {
          throw StateError(
            'Linked task $linkedTaskId not found before cover art save',
          );
        }

        // 7. Import the generated image as a JournalImage linked to the task.
        final extension =
            generatedImage.mimeType.split('/').lastOrNull ?? 'png';
        final imageId = await importGeneratedImageBytes(
          data: Uint8List.fromList(generatedImage.bytes),
          fileExtension: extension,
          linkedId: linkedTaskId,
          categoryId: taskEntity.meta.categoryId,
        );

        if (imageId == null) {
          throw StateError(
            'Failed to import generated image for task $linkedTaskId',
          );
        }

        // 8. Set the image as cover art on the task.
        final updatedData = taskEntity.data.copyWith(coverArtId: imageId);
        final didUpdate = await getIt<PersistenceLogic>().updateTask(
          journalEntityId: linkedTaskId,
          taskData: updatedData,
        );
        if (!didUpdate) {
          throw StateError(
            'Linked task $linkedTaskId disappeared before cover art update',
          );
        }

        _loggingService.captureEvent(
          'Skill-based image generation completed for task $linkedTaskId '
          '(imageId: $imageId)',
          domain: _logTag,
          subDomain: 'runImageGeneration',
        );

        // 9. Trigger automatic image analysis on the newly created cover art,
        // treating it exactly like a manual photo drop.
        unawaited(
          _ref
              .read(automaticImageAnalysisTriggerProvider)
              .triggerAutomaticImageAnalysis(
                imageEntryId: imageId,
                linkedTaskId: linkedTaskId,
              ),
        );
      },
    );
  }

  /// Resolves the textual content of a source entry for skill input.
  ///
  /// For [JournalAudio]: prioritises user-edited text, then falls back to
  /// the latest transcript, then a placeholder. Matches the historic
  /// "audio transcript" resolution semantics.
  ///
  /// For [JournalEntry]: uses the entry's text body directly.
  ///
  /// For any other entity type: returns a placeholder.
  static String _resolveEntryContent(JournalEntity entity) {
    if (entity is JournalAudio) {
      final editedText = entity.entryText?.plainText.trim();
      if (editedText != null && editedText.isNotEmpty) {
        return editedText;
      }

      final transcripts = entity.data.transcripts;
      if (transcripts != null && transcripts.isNotEmpty) {
        final latestTranscript = transcripts.reduce(
          (current, candidate) =>
              candidate.created.isAfter(current.created) ? candidate : current,
        );
        final transcriptText = latestTranscript.transcript.trim();
        if (transcriptText.isNotEmpty) {
          return transcriptText;
        }
      }

      return '[No transcription available]';
    }

    if (entity is JournalEntry) {
      final markdown = entity.entryText?.markdown?.trim();
      if (markdown != null && markdown.isNotEmpty) {
        return markdown;
      }
      final plain = entity.entryText?.plainText.trim();
      if (plain != null && plain.isNotEmpty) {
        return plain;
      }
      return '[Empty note]';
    }

    return '[No entry content available]';
  }

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

  Future<String?> _buildCurrentTaskSummary(
    JournalEntity entity,
    String? linkedTaskId,
  ) async {
    final taskId = linkedTaskId ?? (entity is Task ? entity.id : null);
    if (taskId == null) return null;

    return _taskSummaryResolver.resolve(taskId);
  }

  Future<List<String>> _prepareImageData(JournalImage image) async {
    final fullPath = getFullImagePath(image);

    // Defense-in-depth: ensure the resolved path stays within the documents
    // directory. The imageDirectory/imageFile values come from our own DB,
    // but we validate anyway to guard against path traversal.
    final docDir = getDocumentsDirectory().path;
    final canonicalPath = File(fullPath).absolute.path;
    if (!canonicalPath.startsWith('$docDir${Platform.pathSeparator}')) {
      developer.log(
        'Image path escapes documents directory: $fullPath',
        name: _logTag,
      );
      return [];
    }

    final file = File(fullPath);
    if (!file.existsSync()) {
      developer.log(
        'Image file not found: $fullPath',
        name: _logTag,
      );
      return [];
    }

    final bytes = await file.readAsBytes();
    return [base64Encode(bytes)];
  }
}

/// Resolved (provider, modelId) pair returned by the per-slot resolver
/// helpers ([SkillInferenceRunner._resolveTranscriptionTarget],
/// [SkillInferenceRunner._resolveImageAnalysisTarget]). Either field
/// may be null when the override is unresolvable and the profile slot
/// is also empty — the caller short-circuits with a "missing
/// provider/model" log in that case.
typedef _InferenceTarget = ({
  AiConfigInferenceProvider? provider,
  String? modelId,
});

/// Identifier for which profile slot a per-invocation override is
/// targeting. The [label] is interpolated into warning logs so a
/// future third slot kind only needs a new enum value, not a new
/// magic-string literal that could typo-drift across the codebase.
enum _OverrideSlotKind {
  transcription('transcription'),
  imageAnalysis('image analysis');

  const _OverrideSlotKind(this.label);

  /// Human-readable form used in developer-log messages.
  final String label;
}

@Riverpod(keepAlive: true)
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
    loggingService: ref.watch(loggingServiceProvider),
    taskSummaryResolver: taskSummaryResolver,
    promptBuilderHelper: PromptBuilderHelper(
      aiInputRepository: ref.watch(aiInputRepositoryProvider),
      journalRepository: ref.watch(journalRepositoryProvider),
      taskSummaryResolver: taskSummaryResolver,
    ),
  );
}
