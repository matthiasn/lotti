import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/ai/helpers/entity_state_helper.dart';
import 'package:lotti/features/ai/helpers/prompt_builder_helper.dart';
import 'package:lotti/features/ai/helpers/skill_prompt_builder.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/task_summary_resolver.dart';
import 'package:lotti/features/ai/services/profile_automation_service.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/get_it.dart';
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
    required Ref ref,
    required CloudInferenceRepository cloudRepository,
    required AiInputRepository aiInputRepository,
    required JournalRepository journalRepository,
    required LoggingService loggingService,
    required PromptBuilderHelper promptBuilderHelper,
    required TaskSummaryResolver taskSummaryResolver,
  }) : _ref = ref,
       _cloudRepository = cloudRepository,
       _aiInputRepository = aiInputRepository,
       _journalRepository = journalRepository,
       _loggingService = loggingService,
       _promptBuilderHelper = promptBuilderHelper,
       _taskSummaryResolver = taskSummaryResolver;

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

  /// Run skill-based transcription on an audio entry.
  Future<void> runTranscription({
    required String audioEntryId,
    required AutomationResult automationResult,
    String? linkedTaskId,
  }) async {
    final skill = automationResult.skill;
    final profile = automationResult.resolvedProfile;
    if (skill == null || profile == null) {
      throw StateError(
        'AutomationResult missing skill or profile for $audioEntryId: '
        'skill=${skill != null}, profile=${profile != null}',
      );
    }
    final provider = profile.transcriptionProvider;
    final modelId = profile.transcriptionModelId;
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
  Future<void> runImageAnalysis({
    required String imageEntryId,
    required AutomationResult automationResult,
    String? linkedTaskId,
  }) async {
    final skill = automationResult.skill;
    final profile = automationResult.resolvedProfile;
    if (skill == null || profile == null) {
      throw StateError(
        'AutomationResult missing skill or profile for $imageEntryId: '
        'skill=${skill != null}, profile=${profile != null}',
      );
    }
    final provider = profile.imageRecognitionProvider;
    final modelId = profile.imageRecognitionModelId;
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

  /// Run skill-based prompt generation on an audio entry.
  ///
  /// Uses the profile's high-end thinking model (falling back to the regular
  /// thinking model) to transform an audio transcript + task context into a
  /// detailed coding prompt. The result is saved as an [AiResponseEntry]
  /// linked to the audio entity.
  Future<void> runPromptGeneration({
    required String audioEntryId,
    required AutomationResult automationResult,
    String? linkedTaskId,
  }) async {
    final skill = automationResult.skill;
    final profile = automationResult.resolvedProfile;
    if (skill == null || profile == null) {
      throw StateError(
        'AutomationResult missing skill or profile for $audioEntryId: '
        'skill=${skill != null}, profile=${profile != null}',
      );
    }
    final provider = profile.effectiveHighEndProvider;
    final modelId = profile.effectiveHighEndModelId;

    await _withStatusTracking(
      entityId: audioEntryId,
      responseType: skill.skillType.toResponseType,
      subDomain: 'runPromptGeneration',
      linkedTaskId: linkedTaskId,
      body: () async {
        // 1. Fetch the audio entity.
        final entity = await _aiInputRepository.getEntity(audioEntryId);
        if (entity is! JournalAudio) {
          throw StateError('Entity $audioEntryId is not a JournalAudio');
        }

        // 2. Extract the audio transcript.
        final audioTranscript = _resolveAudioTranscript(entity);

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
          audioTranscript: audioTranscript,
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
            'Empty prompt generation response for $audioEntryId',
          );
        }

        // 7. Save result as AiResponseEntry.
        final data = AiResponseData(
          model: modelId,
          systemMessage: promptResult.systemMessage,
          prompt: promptResult.userMessage,
          thoughts: '',
          response: response,
          type: AiResponseType.promptGeneration,
        );

        await _aiInputRepository.createAiResponseEntry(
          data: data,
          start: start,
          linkedId: audioEntryId,
          categoryId: entity.meta.categoryId,
        );

        _loggingService.captureEvent(
          'Skill-based prompt generation completed for $audioEntryId '
          '(${response.length} chars)',
          domain: _logTag,
          subDomain: 'runPromptGeneration',
        );
      },
    );
  }

  /// Resolves the audio transcript from a [JournalAudio] entity.
  ///
  /// Prioritises user-edited text over the original transcript, matching the
  /// behaviour of the legacy prompt builder.
  static String _resolveAudioTranscript(JournalAudio entity) {
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
