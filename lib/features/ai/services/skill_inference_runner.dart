import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

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
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'skill_inference_runner.g.dart';

const _logTag = 'SkillInferenceRunner';

/// Service that invokes inference using skill-built prompts and
/// profile-resolved models, bypassing the legacy prompt system entirely.
class SkillInferenceRunner {
  const SkillInferenceRunner({
    required CloudInferenceRepository cloudRepository,
    required AiInputRepository aiInputRepository,
    required JournalRepository journalRepository,
    required LoggingService loggingService,
    required PromptBuilderHelper promptBuilderHelper,
  }) : _cloudRepository = cloudRepository,
       _aiInputRepository = aiInputRepository,
       _journalRepository = journalRepository,
       _loggingService = loggingService,
       _promptBuilderHelper = promptBuilderHelper;

  final CloudInferenceRepository _cloudRepository;
  final AiInputRepository _aiInputRepository;
  final JournalRepository _journalRepository;
  final LoggingService _loggingService;
  final PromptBuilderHelper _promptBuilderHelper;

  /// Run skill-based transcription on an audio entry.
  Future<void> runTranscription({
    required String audioEntryId,
    required AutomationResult automationResult,
    String? linkedTaskId,
  }) async {
    try {
      final skill = automationResult.skill;
      final profile = automationResult.resolvedProfile;
      if (skill == null || profile == null) {
        developer.log(
          'AutomationResult missing skill or profile for $audioEntryId',
          name: _logTag,
        );
        return;
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

      // 1. Fetch the audio entity.
      final entity = await _aiInputRepository.getEntity(audioEntryId);
      if (entity is! JournalAudio) {
        developer.log(
          'Entity $audioEntryId is not a JournalAudio',
          name: _logTag,
        );
        return;
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

      // 7. Collect streaming response.
      final buffer = StringBuffer();
      await for (final chunk in responseStream) {
        final content = chunk.choices?.firstOrNull?.delta?.content;
        if (content != null) {
          buffer.write(content);
        }
      }

      final response = buffer.toString().trim();
      if (response.isEmpty) {
        developer.log(
          'Empty transcription response for $audioEntryId',
          name: _logTag,
        );
        return;
      }

      // 8. Save result — create AudioTranscript + update entryText.
      final currentAudio =
          await EntityStateHelper.getCurrentEntityState<JournalAudio>(
            entityId: audioEntryId,
            aiInputRepo: _aiInputRepository,
            entityTypeName: 'audio transcription',
          );
      if (currentAudio == null) return;

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
    } catch (e, stack) {
      _loggingService.captureException(
        e,
        domain: _logTag,
        subDomain: 'runTranscription',
        stackTrace: stack,
      );
    }
  }

  /// Run skill-based image analysis on an image entry.
  Future<void> runImageAnalysis({
    required String imageEntryId,
    required AutomationResult automationResult,
    String? linkedTaskId,
  }) async {
    try {
      final skill = automationResult.skill;
      final profile = automationResult.resolvedProfile;
      if (skill == null || profile == null) {
        developer.log(
          'AutomationResult missing skill or profile for $imageEntryId',
          name: _logTag,
        );
        return;
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
      // 1. Fetch the image entity.
      final entity = await _aiInputRepository.getEntity(imageEntryId);
      if (entity is! JournalImage) {
        developer.log(
          'Entity $imageEntryId is not a JournalImage',
          name: _logTag,
        );
        return;
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
        developer.log(
          'No image data available for $imageEntryId',
          name: _logTag,
        );
        return;
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
        developer.log(
          'Empty image analysis response for $imageEntryId',
          name: _logTag,
        );
        return;
      }

      // 7. Save result — append to entryText.
      final currentImage =
          await EntityStateHelper.getCurrentEntityState<JournalImage>(
            entityId: imageEntryId,
            aiInputRepo: _aiInputRepository,
            entityTypeName: 'image analysis',
          );
      if (currentImage == null) return;

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
    } catch (e, stack) {
      _loggingService.captureException(
        e,
        domain: _logTag,
        subDomain: 'runImageAnalysis',
        stackTrace: stack,
      );
    }
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

    final linkedEntities = await _journalRepository.getLinkedToEntities(
      linkedTo: taskId,
    );

    final summaries =
        linkedEntities
            .whereType<AiResponseEntry>()
            // ignore: deprecated_member_use_from_same_package
            .where((e) => e.data.type == AiResponseType.taskSummary)
            .toList()
          ..sort((a, b) => b.meta.dateFrom.compareTo(a.meta.dateFrom));

    if (summaries.isEmpty) return null;
    return summaries.first.data.response;
  }

  Future<List<String>> _prepareImageData(JournalImage image) async {
    final imageDirectory = image.data.imageDirectory;
    final imageFile = image.data.imageFile;
    final docDir = getDocumentsDirectory();
    final fullPath = '${docDir.path}$imageDirectory$imageFile';

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
  return SkillInferenceRunner(
    cloudRepository: ref.watch(cloudInferenceRepositoryProvider),
    aiInputRepository: ref.watch(aiInputRepositoryProvider),
    journalRepository: ref.watch(journalRepositoryProvider),
    loggingService: ref.watch(loggingServiceProvider),
    promptBuilderHelper: PromptBuilderHelper(
      aiInputRepository: ref.watch(aiInputRepositoryProvider),
      journalRepository: ref.watch(journalRepositoryProvider),
      taskSummaryResolver: TaskSummaryResolver(
        getIt.isRegistered<AgentDatabase>()
            ? AgentRepository(getIt<AgentDatabase>())
            : null,
      ),
    ),
  );
}
