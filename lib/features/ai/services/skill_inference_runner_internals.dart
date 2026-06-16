part of 'skill_inference_runner.dart';

/// Private helpers for [SkillInferenceRunner]: inference-status updates, the
/// status-tracking wrapper, per-skill [_InferenceTarget] resolution (incl.
/// override handling + Gemini thinking mode), and image-data prep. Kept in a
/// private extension because they use the runner's private deps and are
/// driven by its public run* methods (which stay for the mock interface).
extension _SkillInferenceRunnerInternals on SkillInferenceRunner {
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

  /// Sets the [ImageGenerationErrorController] for an entity (and optionally
  /// its linked task) so the cover-art UI can show the provider's verbatim
  /// failure reason. Passing `null` clears any stale error from a previous
  /// attempt.
  void _setImageGenerationError(
    String? providerReason, {
    required String entityId,
    String? linkedTaskId,
  }) {
    _ref
        .read(imageGenerationErrorControllerProvider(id: entityId).notifier)
        .setError(providerReason);

    if (linkedTaskId != null) {
      _ref
          .read(
            imageGenerationErrorControllerProvider(id: linkedTaskId).notifier,
          )
          .setError(providerReason);
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
    void Function(Object error)? onError,
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
      onError?.call(e);
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
        model: profile.transcriptionModel,
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
        model: profile.imageRecognitionModel,
      ),
    );
  }

  /// Resolves the `(provider, modelId, model)` target used by prompt
  /// generation. The profile fallback is the high-end thinking slot, falling
  /// back to the regular thinking slot through [ResolvedProfile].
  Future<_InferenceTarget> _resolvePromptGenerationTarget({
    required ResolvedProfile profile,
    required String? overrideModelId,
  }) {
    return _resolveOverrideTarget(
      overrideModelId: overrideModelId,
      slotKind: _OverrideSlotKind.promptGeneration,
      fallback: () => (
        provider: profile.effectiveHighEndProvider,
        modelId: profile.effectiveHighEndModelId,
        model: profile.effectiveHighEndModel,
      ),
    );
  }

  /// Shared override-or-fallback resolver used by all per-slot resolvers.
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
      model: modelConfig,
    );
  }

  /// Resolves the effective Gemini thinking mode for [target].
  ///
  /// Returns null unless the target provider is Gemini and the model is a
  /// Gemini 3 variant. Otherwise the per-invocation [override] wins, then
  /// the model row's saved default, then [GeminiThinkingMode.low].
  GeminiThinkingMode? _geminiThinkingModeForTarget(
    _InferenceTarget target,
    GeminiThinkingMode? override,
  ) {
    final provider = target.provider;
    if (provider?.inferenceProviderType != InferenceProviderType.gemini) {
      return null;
    }
    final modelId = target.model?.providerModelId ?? target.modelId;
    if (modelId == null || !GeminiThinkingConfig.isGemini3(modelId)) {
      return null;
    }
    return override ??
        target.model?.geminiThinkingMode ??
        GeminiThinkingMode.low;
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
    final file = File(fullPath);
    if (!file.existsSync()) {
      developer.log(
        'Image file not found: $fullPath',
        name: _logTag,
      );
      return [];
    }

    // Defense-in-depth: fully resolve the file path (following `..` segments
    // and symlinks via resolveSymbolicLinksSync, which requires the file to
    // exist — hence the check above) and confirm it stays within the documents
    // directory. Resolve the documents directory too, so a symlinked root
    // (e.g. macOS /tmp -> /private/tmp) does not produce a false escape. The
    // imageDirectory/imageFile values come from our own DB, but we validate
    // anyway to guard against path traversal.
    final docDir = Directory(
      getDocumentsDirectory().path,
    ).resolveSymbolicLinksSync();
    final canonicalPath = file.resolveSymbolicLinksSync();
    if (!canonicalPath.startsWith('$docDir${Platform.pathSeparator}')) {
      developer.log(
        'Image path escapes documents directory: $fullPath',
        name: _logTag,
      );
      return [];
    }

    final bytes = await file.readAsBytes();
    return [base64Encode(bytes)];
  }
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
String _resolveEntryContent(JournalEntity entity) {
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
