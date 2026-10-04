part of 'skill_inference_runner.dart';

/// Transcription for [SkillInferenceRunner]: transcribe-and-summarize, saving the transcript, and the follow-up audio summary. A private extension because they use the runner's private deps and are driven by runTranscription.
extension _SkillInferenceRunnerTranscription on SkillInferenceRunner {
  /// The body of [runTranscription] behind its single-flight registry:
  /// transcribes, saves the transcript, and then runs the automated audio
  /// summary. Returns the failure the status tracking reported, or null once
  /// the transcript is saved; the summary follows only a saved transcript.
  Future<Object?> _transcribeAndSummarize({
    required String audioEntryId,
    required AutomationResult automationResult,
    required AiConfigSkill skill,
    required ResolvedProfile profile,
    required AiConfigInferenceProvider provider,
    required String modelId,
    required GeminiThinkingMode? effectiveThinkingMode,
    required String? linkedTaskId,
    required List<String> knownTerms,
  }) async {
    Object? failure;
    await _withStatusTracking(
      entityId: audioEntryId,
      responseType: skill.skillType.toResponseType,
      subDomain: 'runTranscription',
      linkedTaskId: linkedTaskId,
      onError: (error) => failure = error,
      body: () async {
        // 1. Fetch the audio entity.
        final entity = await _aiInputRepository.getEntity(audioEntryId);
        if (entity is! JournalAudio) {
          throw StateError('Entity $audioEntryId is not a JournalAudio');
        }

        // 2. Build context for prompts (fetch terms once, reuse for both
        // prompt text and provider-level context biasing).
        final speechDictionaryTerms = mergeSpeechTerms(
          knownTerms,
          await _promptBuilderHelper.getSpeechDictionaryTerms(entity),
        );
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
        final collected = await _collectStream(responseStream)
            .onError<TranscriptionException>((error, stackTrace) async {
              if (error.completedSegments > 0) {
                try {
                  final failedAttribution = await _recordAttributedConsumption(
                    attribution: attribution,
                    entryId: audioEntryId,
                    taskId: linkedTaskId,
                    categoryId: entity.meta.categoryId,
                    skillId: skill.id,
                    provider: provider,
                    modelId: modelId,
                    responseType: skill.skillType.toResponseType,
                    usage: error.partialUsage,
                    impact: error.partialImpact,
                    start: start,
                    interactionKind: AiInteractionKind.audioTranscription,
                    requestText:
                        '${promptResult.systemMessage}\n${promptResult.userMessage}',
                    responseText: '',
                    status: AiWorkStatus.failed,
                    errorCode: 'transcription_incomplete',
                    errorSummary:
                        'Transcription failed after completed audio segments.',
                  );
                  await _finalizeAttribution(failedAttribution);
                } catch (accountingError, accountingStackTrace) {
                  _loggingService.error(
                    LogDomain.ai,
                    accountingError,
                    stackTrace: accountingStackTrace,
                    subDomain: 'runTranscription.accounting',
                  );
                }
              }
              Error.throwWithStackTrace(error, stackTrace);
            });

        final response = collected.content.trim();

        // With names to expect, the transcript is corrected against them:
        // first by sound and spelling (against the names and the category
        // dictionary), then by the profile's thinking model against the
        // names alone, for what those rules cannot reach. The model's call is part of this
        // transcription's spend.
        var text = response;
        AiConsumptionEvent? nameCorrectionEvent;
        if (knownTerms.isNotEmpty && response.isNotEmpty) {
          text = correctTranscriptTerms(response, speechDictionaryTerms).text;
          final corrected = await _correctNamesWithThinkingModel(
            profile: profile,
            transcript: text,
            // Only the names the caller expects: a category dictionary
            // holds ordinary vocabulary, which is no name to swap in.
            terms: knownTerms,
            entity: entity,
            taskId: linkedTaskId,
            skillId: skill.id,
          );
          if (corrected != null) {
            text = corrected.text;
            nameCorrectionEvent = corrected.event;
          }
        }

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
          additionalEvents: [?nameCorrectionEvent],
        );

        if (response.isEmpty) {
          throw StateError('Empty transcription response for $audioEntryId');
        }

        // 7. Save result — append the AudioTranscript and set entryText.
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

        await _saveTranscript(
          audioEntryId: audioEntryId,
          textAtStart: entity.entryText,
          transcript: transcript,
          text: text,
        );
        // The transcript is saved, so the run succeeded: a bookkeeping
        // failure from here on must not fail it, or the summary and the
        // caller's agent wake would be skipped for a transcript that exists.
        // The envelope is saved on the transcript itself, where peers project
        // it from; only this device's ledger row is missing, and logged.
        try {
          await _finalizeAttribution(attributionEnvelope);
        } catch (accountingError, accountingStackTrace) {
          _loggingService.error(
            LogDomain.ai,
            accountingError,
            stackTrace: accountingStackTrace,
            subDomain: 'runTranscription.accounting',
          );
        }

        _loggingService.log(
          LogDomain.ai,
          'Skill-based transcription completed for $audioEntryId '
          '(${response.length} chars)',
          subDomain: 'runTranscription',
        );
      },
    );

    // A failed run has no new transcript to summarize: a summary now would
    // pay to restate whatever the recording held before.
    if (failure != null) return failure;

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
    return null;
  }

  /// Appends [transcript] to the recording's history and sets its text to
  /// [text], re-reading the recording first so a change made during the
  /// inference is kept.
  ///
  /// Two rules decide what the write carries:
  /// - **An edit made during the run wins.** When the recording's text is no
  ///   longer [textAtStart] — the user, or a synced peer, changed it while the
  ///   model was listening — that text is kept and the transcript only joins
  ///   the history. A re-transcription of text edited *before* the run still
  ///   replaces it, as the user asked.
  /// - **The write applies only to the row it was built on.** It is guarded
  ///   on the re-read's version (`onlyIfUnchanged`), so an edit stored after
  ///   the re-read — synced, or typed here — refuses it instead of being
  ///   overwritten, and the next attempt is built on that edit.
  /// - **A write that does not land is retried, then fails the run.**
  ///   `updateJournalEntity` returns false when the write was refused — a
  ///   version was stored since the re-read — or when it threw and logged. A
  ///   fresh re-read carries the change, so the next attempt normally lands.
  ///   After [_transcriptSaveAttempts] this throws, so the run reports an
  ///   error instead of claiming a transcript nobody can find.
  /// - **A transcript is saved once.** A write can commit and still report
  ///   false, when a step after the commit throws. Every re-read therefore
  ///   first looks for the transcript's id: once it is there the transcript
  ///   is saved, and it is neither appended again nor reported lost.
  Future<void> _saveTranscript({
    required String audioEntryId,
    required EntryText? textAtStart,
    required AudioTranscript transcript,
    required String text,
  }) async {
    for (var attempt = 1; ; attempt++) {
      final currentAudio =
          await EntityStateHelper.getCurrentEntityState<JournalAudio>(
            entityId: audioEntryId,
            aiInputRepo: _aiInputRepository,
            entityTypeName: 'audio transcription',
          );
      if (currentAudio == null) {
        throw StateError('Audio entity $audioEntryId disappeared mid-run');
      }
      final existingTranscripts = currentAudio.data.transcripts ?? [];
      if (existingTranscripts.any((saved) => saved.id == transcript.id)) {
        return;
      }
      if (attempt > _transcriptSaveAttempts) {
        throw StateError(
          'Transcript for $audioEntryId was not saved after '
          '$_transcriptSaveAttempts attempts',
        );
      }

      final editedDuringRun = currentAudio.entryText != textAtStart;
      final updated = currentAudio.copyWith(
        data: currentAudio.data.copyWith(
          transcripts: [...existingTranscripts, transcript],
        ),
        entryText: editedDuringRun
            ? currentAudio.entryText
            : EntryText(plainText: text, markdown: text),
      );
      if (await _journalRepository.updateJournalEntity(
        updated,
        onlyIfUnchanged: true,
      )) {
        return;
      }
      _loggingService.log(
        LogDomain.ai,
        'Transcript write for $audioEntryId did not land '
        '(attempt $attempt); re-reading',
        subDomain: 'runTranscription',
      );
    }
  }

  /// Runs the profile's automated audio-summary skill, if it has one.
  ///
  /// Hangs off the end of [runTranscription] rather than off each of its
  /// callers (automatic recording trigger, synced-audio dispatcher, manual
  /// picker and Retry, relationship and goal check-ins) so every route that
  /// produces a transcript gets the same follow-up exactly once. It runs only
  /// after the transcript was saved.
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
}
