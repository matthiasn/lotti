part of 'unified_ai_inference_repository.dart';

/// Private helpers of [UnifiedAiInferenceRepository] that hold no state of their own; kept beside the class as an extension so the library stays readable.
extension _UnifiedAiInferenceRepositoryInternals
    on UnifiedAiInferenceRepository {
  Future<void> _failOutputAttribution(
    AiAttributionSession session,
    Object error,
  ) => getIt<AiInteractionCapture>().completeSession(
    session: session,
    outputs: const [],
    status: AiWorkStatus.failed,
    errorCode: error.runtimeType.toString(),
  );

  AiWorkType _workType(AiResponseType type) => switch (type) {
    AiResponseType.promptGeneration => AiWorkType.codingPrompt,
    AiResponseType.imageGeneration => AiWorkType.imageGeneration,
    AiResponseType.imageAnalysis => AiWorkType.imageAnalysis,
    AiResponseType.audioTranscription => AiWorkType.audioTranscription,
    _ => AiWorkType.textGeneration,
  };

  AiInteractionKind _interactionKind(AiResponseType type) => switch (type) {
    AiResponseType.imageGeneration => AiInteractionKind.imageGeneration,
    AiResponseType.imageAnalysis => AiInteractionKind.imageAnalysis,
    AiResponseType.audioTranscription => AiInteractionKind.audioTranscription,
    _ => AiInteractionKind.textGeneration,
  };

  AiArtifactReference _outputReference({
    required AiResponseType responseType,
    required String entityId,
    required String outputId,
  }) => responseType == AiResponseType.audioTranscription
      ? AiArtifactReference(
          type: AiArtifactType.journalAudio,
          id: entityId,
          subId: outputId,
        )
      : AiArtifactReference(
          type: AiArtifactType.journalAiResponse,
          id: outputId,
        );
}

/// Image and audio preparation for an inference request.
extension _UnifiedAiInputPreparation on UnifiedAiInferenceRepository {
  /// Prepare images if required
  Future<List<String>> _prepareImages(
    AiConfigPrompt promptConfig,
    JournalEntity entity,
  ) async {
    if (!promptConfig.requiredInputData.contains(InputDataType.images)) {
      return [];
    }

    if (entity is! JournalImage) return [];

    final fullPath = getCanonicalImagePath(entity);
    final file = File(fullPath);
    final documentsPath = Directory(
      getDocumentsDirectory().path,
    ).resolveSymbolicLinksSync();
    final resolvedPath = file.resolveSymbolicLinksSync();
    if (!p.isWithin(documentsPath, resolvedPath)) {
      throw StateError('Image path escapes documents directory: $fullPath');
    }
    final bytes = await file.readAsBytes();
    final base64String = base64Encode(bytes);

    return [base64String];
  }

  /// Prepare audio if required.
  ///
  /// All providers now accept M4A natively — no format conversion needed.
  Future<PreparedAudio?> _prepareAudio(
    AiConfigPrompt promptConfig,
    JournalEntity entity,
    AiConfigInferenceProvider provider,
  ) async {
    // Skip audio preparation entirely for prompt generation types - they use
    // transcript text via {{audioTranscript}} placeholder, not audio files
    if (promptConfig.aiResponseType.isPromptGenerationType) {
      return null;
    }

    if (!promptConfig.requiredInputData.contains(InputDataType.audioFiles)) {
      return null;
    }

    if (entity is! JournalAudio) return null;

    final fullPath = await AudioUtils.getFullAudioPath(entity);
    final file = File(fullPath);
    final bytes = await file.readAsBytes();

    // All providers accept M4A bytes labeled as mp3
    return PreparedAudio(
      base64: base64Encode(bytes),
      format: ChatCompletionMessageInputAudioFormat.mp3,
    );
  }
}
