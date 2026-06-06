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
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'skill_image_analysis_runner.dart';
part 'skill_image_generation_runner.dart';
part 'skill_prompt_generation_runner.dart';
part 'skill_transcription_runner.dart';

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
  final DomainLogger _loggingService;
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
      _loggingService.error(
        LogDomain.ai,
        e,
        stackTrace: stack,
        subDomain: subDomain,
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

  /// Run skill-based transcription; see [SkillTranscriptionRunner].
  Future<void> runTranscription({
    required String audioEntryId,
    required AutomationResult automationResult,
    String? linkedTaskId,
    String? overrideModelId,
  }) => runTranscriptionImpl(
    audioEntryId: audioEntryId,
    automationResult: automationResult,
    linkedTaskId: linkedTaskId,
    overrideModelId: overrideModelId,
  );

  /// Run skill-based image analysis; see [SkillImageAnalysisRunner].
  Future<void> runImageAnalysis({
    required String imageEntryId,
    required AutomationResult automationResult,
    String? linkedTaskId,
    String? overrideModelId,
  }) => runImageAnalysisImpl(
    imageEntryId: imageEntryId,
    automationResult: automationResult,
    linkedTaskId: linkedTaskId,
    overrideModelId: overrideModelId,
  );

  /// Run skill-based prompt generation; see [SkillPromptGenerationRunner].
  Future<void> runPromptGeneration({
    required String entryId,
    required AutomationResult automationResult,
    String? linkedTaskId,
  }) => runPromptGenerationImpl(
    entryId: entryId,
    automationResult: automationResult,
    linkedTaskId: linkedTaskId,
  );

  /// Run skill-based image generation; see [SkillImageGenerationRunner].
  Future<void> runImageGeneration({
    required String entryId,
    required AutomationResult automationResult,
    required String linkedTaskId,
    List<ProcessedReferenceImage>? referenceImages,
  }) => runImageGenerationImpl(
    entryId: entryId,
    automationResult: automationResult,
    linkedTaskId: linkedTaskId,
    referenceImages: referenceImages,
  );
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
    loggingService: getIt<DomainLogger>(),
    taskSummaryResolver: taskSummaryResolver,
    promptBuilderHelper: PromptBuilderHelper(
      aiInputRepository: ref.watch(aiInputRepositoryProvider),
      journalRepository: ref.watch(journalRepositoryProvider),
      taskSummaryResolver: taskSummaryResolver,
    ),
  );
}
