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
import 'package:lotti/features/ai/repository/transcription_exception.dart';
import 'package:lotti/features/ai/services/profile_automation_service.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/image_generation_error_controller.dart';
import 'package:lotti/features/ai/state/inference_error_controller.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/util/image_processing_utils.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_event.dart';
import 'package:lotti/features/ai_consumption/service/ai_attribution_identity_resolver.dart';
import 'package:lotti/features/ai_consumption/service/ai_attribution_service.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/image_import.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:meta/meta.dart';
import 'package:openai_dart/openai_dart.dart';

part 'skill_inference_runner_internals.dart';

const _logTag = 'SkillInferenceRunner';

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

  /// The wired task-summary resolver — observable seam for the provider
  /// factory tests (AgentDatabase registered vs not).
  @visibleForTesting
  TaskSummaryResolver get debugTaskSummaryResolver => _taskSummaryResolver;

  /// Test seam for [_resolveEntryContent] — pure content resolution.
  @visibleForTesting
  static String debugResolveEntryContent(JournalEntity entity) =>
      _resolveEntryContent(entity);

  /// Test seam for [_formatSpeechDictionaryText] — pure prompt fragment.
  @visibleForTesting
  static String debugFormatSpeechDictionaryText(List<String> terms) =>
      _formatSpeechDictionaryText(terms);

  /// Test seam for [_prepareImageData] — image read + path-containment guard.
  @visibleForTesting
  Future<List<String>> debugPrepareImageData(JournalImage image) =>
      _prepareImageData(image);

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
  Future<void> runTranscription({
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
          geminiThinkingMode: effectiveThinkingMode,
          impactCollector: impactCollector,
        );

        // 6. Collect streaming response.
        final collected = await _collectStream(responseStream);

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

        final response = collected.content.trim();
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

        // 5. Call inference with text-only (no audio/image upload).
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
        final responseStream = _cloudRepository.generate(
          promptResult.userMessage,
          model: modelId,
          temperature: null,
          baseUrl: provider.baseUrl,
          apiKey: provider.apiKey,
          provider: provider,
          systemMessage: promptResult.systemMessage,
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

  /// Drains a chat-completion stream, concatenating content deltas and
  /// capturing the last reported [CompletionUsage] (providers emit usage on
  /// the final chunk). Shared by the transcription, image-analysis, and
  /// prompt-generation paths so the accumulation logic lives in one place.
  Future<({String content, CompletionUsage? usage})> _collectStream(
    Stream<CreateChatCompletionStreamResponse> stream,
  ) async {
    final buffer = StringBuffer();
    CompletionUsage? usage;
    await for (final chunk in stream) {
      if (chunk.usage != null) usage = chunk.usage;
      final content = chunk.choices?.firstOrNull?.delta?.content;
      if (content != null) {
        buffer.write(content);
      }
    }
    return (content: buffer.toString(), usage: usage);
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
  imageGeneration('image generation');

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
