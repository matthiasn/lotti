part of 'skill_inference_runner.dart';

/// Transcription path of [SkillInferenceRunner].
///
/// Implementation body lives here; the class keeps a thin delegator so
/// mocktail mocks of [SkillInferenceRunner] still intercept the public
/// method (extension methods cannot be mocked).
extension SkillTranscriptionRunner on SkillInferenceRunner {
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
  Future<void> runTranscriptionImpl({
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
        final speechDictionary =
            SkillInferenceRunner._formatSpeechDictionaryText(
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
          geminiThinkingMode: effectiveThinkingMode,
          speechDictionaryTerms: speechDictionaryTerms.isNotEmpty
              ? speechDictionaryTerms
              : null,
        );

        // 6. Collect streaming response.
        final buffer = StringBuffer();
        await for (final chunk in responseStream) {
          final content = chunk.choices.firstOrNull?.delta.content;
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

        _loggingService.log(
          LogDomain.ai,
          'Skill-based transcription completed for $audioEntryId '
          '(${response.length} chars)',
          subDomain: 'runTranscription',
        );
      },
    );
  }
}
