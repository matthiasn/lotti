part of 'skill_inference_runner.dart';

/// The text a recording had when its transcription started: what the
/// transcript's text replaces, unless the recording was edited since.
typedef _HeldText = ({EntryText? textAtStart});

/// The summary of a recording, and the composite step that corrects its
/// transcript against the speech dictionary in the same call. A private
/// extension because it uses the runner's private deps.
extension _SkillInferenceRunnerRecording on SkillInferenceRunner {
  /// The summary that follows a transcription, or null when none does.
  ///
  /// - **A task must be resolved.** The summary is framed by the task it
  ///   belongs to; goal and person check-ins and standalone voice notes
  ///   transcribe as before and get no summary.
  /// - **Speech recognized in the task's context on a speech-to-text
  ///   engine** chains the summary however it was started — from the AI
  ///   menu or by the category's automation. On such an engine that skill
  ///   *is* the composite step: the engine cannot read the task or the
  ///   dictionary, so the correction against them is part of what was asked
  ///   for. An automated run uses the profile's automated audio summary when
  ///   it has one, and otherwise the built-in summary, attributed to the
  ///   automation that started it.
  /// - **Any other automated transcription** — the plain skill, or a
  ///   multimodal model that read the task and the dictionary in its own
  ///   prompt — chains the profile's automated audio summary only, as it
  ///   always has: only `ProfileAutomationService` sets a `skillAssignment`,
  ///   and only after the category's consent check. Started by hand, it
  ///   chains nothing.
  AutomationResult? _audioSummaryFollowUp({
    required AutomationResult automationResult,
    required AiConfigSkill transcriptionSkill,
    required String? linkedTaskId,
    required bool speechToText,
  }) {
    final profile = automationResult.resolvedProfile;
    if (linkedTaskId == null || profile == null) return null;
    // A summary needs a post-processing model that can call its tool. The
    // direct speech-to-text fallback, run without an inference profile, puts
    // its transcription model in the thinking slot it falls back to; no
    // summary is scheduled then, and the transcript is written at once
    // instead of held for a call that `_summarizeRecording` would skip.
    if (profile.effectiveAudioPostProcessingModel case final model?
        when !model.supportsFunctionCalling) {
      return null;
    }

    final automatedRun = automationResult.skillAssignment;
    final automatedSummary = automatedRun == null
        ? null
        : profile.skillAssignments
              .where((a) => a.automate)
              .map((a) => (assignment: a, skill: findBuiltInSkill(a.skillId)))
              .where((pair) => pair.skill?.skillType == SkillType.audioSummary)
              .firstOrNull;
    if (automatedSummary != null) {
      return AutomationResult(
        handled: true,
        skill: automatedSummary.skill,
        skillAssignment: automatedSummary.assignment,
        resolvedProfile: profile,
      );
    }

    if (!speechToText ||
        transcriptionSkill.contextPolicy != ContextPolicy.fullTask) {
      return null;
    }
    final summary = findBuiltInSkill(skillAudioSummaryId);
    if (summary == null) return null;
    return AutomationResult(
      handled: true,
      skill: summary,
      skillAssignment: automatedRun,
      resolvedProfile: profile,
    );
  }

  /// Runs [followUp] after a saved transcription. Failures never propagate:
  /// the transcript is persisted and is the valuable artifact, and a summary
  /// failure surfacing here would mark the transcription as failed and invite
  /// a retry that re-transcribes audio that transcribed fine.
  Future<void> _runFollowUpSummary({
    required String audioEntryId,
    required AutomationResult followUp,
    required String linkedTaskId,
    required _HeldText? heldText,
  }) async {
    try {
      await _runAudioSummary(
        audioEntryId: audioEntryId,
        automationResult: followUp,
        linkedTaskId: linkedTaskId,
        heldText: heldText,
      );
    } catch (error, stackTrace) {
      // Unreachable today — the run reports through its status tracking and
      // writes held text in a `finally` — and kept because this is the seam
      // that protects a persisted transcript from a future change to that.
      _loggingService.error(
        LogDomain.ai,
        error,
        stackTrace: stackTrace,
        subDomain: 'maybeRunAudioSummary',
      );
    }
  }

  /// Summarizes a recording in its task's context: a one-liner, a TLDR and a
  /// full summary, saved as an [AiResponseEntry] linked from the recording.
  ///
  /// The prompt is bounded by the recording, not the task: it carries this
  /// recording's text, the task's title and language, the task's current
  /// report, and the speech dictionary terms that reach the recording —
  /// never the task's log, the other recordings' transcripts or the linked
  /// tasks, which grow without limit.
  ///
  /// The same call reports where the transcript misheard a dictionary term
  /// ([recordingSummaryTool]). With [heldText] — a transcription by a
  /// speech-to-text engine whose text was held back for this step, or a
  /// recording whose text is still empty — the corrections are applied to
  /// the transcript, learned as misheard spellings, and the result becomes
  /// the recording's text unless it was edited since; if the summary fails or
  /// is skipped, the raw transcript does. Without it the corrections are
  /// ignored: the text came from a model that read the dictionary itself.
  /// [fillEmptyText] treats a recording that has a transcript but no text
  /// yet as held — the state a composite step that never finished leaves.
  Future<void> _runAudioSummary({
    required String audioEntryId,
    required AutomationResult automationResult,
    String? linkedTaskId,
    String? overrideModelId,
    GeminiThinkingMode? geminiThinkingMode,
    _HeldText? heldText,
    bool fillEmptyText = false,
  }) async {
    final skill = automationResult.skill;
    final profile = automationResult.resolvedProfile;
    if (skill == null || profile == null) {
      throw StateError(
        'AutomationResult missing skill or profile for $audioEntryId: '
        'skill=${skill != null}, profile=${profile != null}',
      );
    }
    var held = heldText;
    if (held == null && fillEmptyText) {
      final entity = await _aiInputRepository.getEntity(audioEntryId);
      if (entity is JournalAudio && _textAwaitsTranscript(entity)) {
        held = (textAtStart: entity.entryText);
      }
    }
    String? correctedText;
    try {
      correctedText = await _summarizeRecording(
        audioEntryId: audioEntryId,
        automationResult: automationResult,
        skill: skill,
        profile: profile,
        linkedTaskId: linkedTaskId,
        overrideModelId: overrideModelId,
        geminiThinkingMode: geminiThinkingMode,
        correct: held != null,
      );
    } finally {
      if (held != null) {
        await _writeTranscriptText(
          audioEntryId: audioEntryId,
          textAtStart: held.textAtStart,
          correctedText: correctedText,
        );
      }
    }
  }

  /// The model call and its persistence; returns the corrected transcript
  /// when [correct] and the call reported corrections, else null.
  Future<String?> _summarizeRecording({
    required String audioEntryId,
    required AutomationResult automationResult,
    required AiConfigSkill skill,
    required ResolvedProfile profile,
    required String? linkedTaskId,
    required String? overrideModelId,
    required GeminiThinkingMode? geminiThinkingMode,
    required bool correct,
  }) async {
    final target = await _resolveAudioSummaryTarget(
      profile: profile,
      overrideModelId: overrideModelId,
    );
    final provider = target.provider;
    final modelId = target.modelId;
    // Only a post-processing model the profile names but this device cannot
    // resolve leaves the target empty — the thinking slot it otherwise falls
    // back to is required. Fail where the user sees it, through the status
    // tracking, instead of quietly running on the model they chose another
    // one over; a held transcript is still written, uncorrected.
    if (provider == null || modelId == null) {
      await _withStatusTracking(
        entityId: audioEntryId,
        responseType: skill.skillType.toResponseType,
        subDomain: 'runAudioSummary',
        linkedTaskId: linkedTaskId,
        body: () async =>
            throw StateError('Audio post-processing model unavailable'),
      );
      return null;
    }
    final effectiveThinkingMode = _geminiThinkingModeForTarget(
      target,
      geminiThinkingMode,
    );

    // The profile form constrains both slots this can resolve to — audio
    // post-processing and thinking — to tool-capable models, so this is an
    // assertion rather than a fallback: it only fires for a profile seeded
    // programmatically or a model row whose capability flag is wrong. Firing a pinned tool call at a model that cannot call tools
    // burns the call and returns nothing usable.
    if (target.model != null && !target.model!.supportsFunctionCalling) {
      _loggingService.log(
        LogDomain.ai,
        'Skipping audio summary for $audioEntryId: resolved model $modelId '
        'is not marked as supporting function calling',
        subDomain: 'runAudioSummary',
      );
      return null;
    }

    String? correctedText;
    await _withStatusTracking(
      entityId: audioEntryId,
      responseType: skill.skillType.toResponseType,
      subDomain: 'runAudioSummary',
      linkedTaskId: linkedTaskId,
      body: () async {
        final entity = await _aiInputRepository.getEntity(audioEntryId);
        if (entity is! JournalAudio) {
          throw StateError('Entity $audioEntryId is not a JournalAudio');
        }

        // An edit wins over the raw transcript, the precedence every other
        // consumer uses — except for a held transcript: its text is still the
        // one the recording had before (empty, or the text a
        // re-transcription replaces), and the correction is of the newest
        // transcript.
        final entryContent = correct
            ? _latestTranscriptText(entity) ?? _resolveEntryContent(entity)
            : _resolveEntryContent(entity);
        final entries = await _promptBuilderHelper.getSpeechDictionaryEntries(
          entity,
        );
        // A note too short to summarize is still worth correcting.
        final worthIt =
            entryContent.length >= _audioSummaryMinChars ||
            (correct && entries.isNotEmpty);
        if (!worthIt) {
          _loggingService.log(
            LogDomain.ai,
            'Skipping audio summary for $audioEntryId: transcript is '
            '${entryContent.length} chars, under the '
            '$_audioSummaryMinChars minimum',
            subDomain: 'runAudioSummary',
          );
          return;
        }

        final (String? taskHeader, String? taskReport) = linkedTaskId != null
            ? await (
                _taskHeaderJson(linkedTaskId),
                _taskSummaryResolver.resolve(linkedTaskId, fullReport: true),
              ).wait
            : (null, null);

        const promptBuilder = SkillPromptBuilder();
        final promptResult = promptBuilder.build(
          skill: skill,
          entryContent: entryContent,
          taskContext: taskHeader,
          currentTaskSummary: taskReport,
          transcriptCorrection: recordingCorrectionPrompt(entries),
        );

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
        // Each attempt gets its OWN collector: a single mutable slot shared
        // across the retry would let the second call's impact overwrite the
        // first's and silently drop a real provider charge from the ledger.
        Future<
          ({
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
              tools: [recordingSummaryTool],
              toolChoice: recordingSummaryToolChoiceFor(modelId),
              geminiThinkingMode: effectiveThinkingMode,
              impactCollector: collector,
            ),
          );
          return (
            toolCalls: result.toolCalls,
            usage: result.usage,
            impact: collector.impact,
          );
        }

        // One forced retry covers the common failure — a model that narrates
        // instead of calling, or leaves a tier out — without turning a
        // misbehaving model into an unbounded loop. Spend from both attempts
        // is billed, even when the retry fails too.
        var attempt = await callModel(promptResult.userMessage);
        var usage = attempt.usage;
        var impact = attempt.impact;
        RecordingSummary? result;
        EntrySummaryToolException? failure;
        try {
          result = parseRecordingSummaryToolCall(attempt.toolCalls);
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
            'Call the $recordingSummaryToolName tool with all of its '
            'arguments and respond with nothing else.',
          );
          usage = SkillInferenceRunner._mergeUsage(usage, attempt.usage);
          impact = SkillInferenceRunner._mergeImpact(impact, attempt.impact);
          try {
            result = parseRecordingSummaryToolCall(attempt.toolCalls);
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
          responseText: result?.summary.summary ?? '',
        );

        if (result == null) {
          throw failure!;
        }
        final summary = result.summary;

        if (correct) {
          final corrected = applyRecordingCorrections(
            entryContent,
            result.corrections,
            entries,
          );
          if (corrected.applied.isNotEmpty) {
            correctedText = corrected.text;
            await _learnMisheardForms(corrected.applied);
          }
          _loggingService.log(
            LogDomain.ai,
            'Transcript correction for $audioEntryId: '
            '${corrected.applied.length} of ${result.corrections.length} '
            'applied',
            subDomain: 'runAudioSummary',
          );
        }

        // Re-read the source before persisting so a recording deleted
        // mid-run cannot leave a detached summary behind.
        final currentAudio =
            await EntityStateHelper.getCurrentEntityState<JournalAudio>(
              entityId: audioEntryId,
              aiInputRepo: _aiInputRepository,
              entityTypeName: 'audio summary',
              domainLogger: _loggingService,
            );
        if (currentAudio == null) {
          throw StateError('Audio entity $audioEntryId disappeared mid-run');
        }

        // Linked to the AUDIO entry, never to the task: the summary is about
        // this recording, and the collapsed card resolves it by walking the
        // recording's linked responses.
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
    return correctedText;
  }

  /// The task as the summary needs it: its title and the language the
  /// summary is written in. Null when [taskId] is not a task.
  Future<String?> _taskHeaderJson(String taskId) async {
    final task = await _aiInputRepository.getEntity(taskId);
    if (task is! Task) return null;
    return const JsonEncoder.withIndent('    ').convert({
      'title': task.data.title,
      'languageCode': task.data.languageCode,
    });
  }

  /// Records each applied correction as a misheard spelling of its term. A
  /// failure is logged and never fails the summary: the corrected text is
  /// what matters, and the next correction can teach the same spelling.
  Future<void> _learnMisheardForms(List<TermCorrection> applied) async {
    try {
      await _ref
          .read(speechDictionaryRepositoryProvider)
          .learnMisheardForms(applied);
    } catch (error, stackTrace) {
      _loggingService.error(
        LogDomain.ai,
        error,
        stackTrace: stackTrace,
        subDomain: 'runAudioSummary.learnMisheardForms',
      );
    }
  }

  /// Sets the recording's text to [correctedText], or to its latest
  /// transcript when there is none — the text a held transcription leaves
  /// for this moment — unless the text is no longer [textAtStart]: an edit
  /// made since, here or on another device, wins.
  ///
  /// The write is guarded on the re-read's version, like the transcript's
  /// own ([_saveTranscript]), and a refused write is re-read and retried. A
  /// write that never lands is logged, not thrown: the transcript is saved,
  /// and the next summary of a recording without text fills it.
  Future<void> _writeTranscriptText({
    required String audioEntryId,
    required EntryText? textAtStart,
    required String? correctedText,
  }) async {
    try {
      for (var attempt = 1; ; attempt++) {
        final current =
            await EntityStateHelper.getCurrentEntityState<JournalAudio>(
              entityId: audioEntryId,
              aiInputRepo: _aiInputRepository,
              entityTypeName: 'audio transcript text',
              domainLogger: _loggingService,
            );
        if (current == null || current.entryText != textAtStart) return;
        final text = correctedText ?? _latestTranscriptText(current);
        if (text == null) return;
        final written = await _journalRepository.updateJournalEntity(
          current.copyWith(
            entryText: EntryText(plainText: text, markdown: text),
          ),
          onlyIfUnchanged: true,
        );
        if (written) return;
        if (attempt >= _transcriptSaveAttempts) {
          throw StateError(
            'Transcript text for $audioEntryId was not saved after '
            '$_transcriptSaveAttempts attempts',
          );
        }
      }
    } catch (error, stackTrace) {
      _loggingService.error(
        LogDomain.ai,
        error,
        stackTrace: stackTrace,
        subDomain: 'runTranscription.writeText',
      );
    }
  }
}

/// The text of [audio]'s newest transcript, or null when it has none.
String? _latestTranscriptText(JournalAudio audio) {
  final transcripts = audio.data.transcripts;
  if (transcripts == null || transcripts.isEmpty) return null;
  final text = transcripts
      .reduce((a, b) => b.created.isAfter(a.created) ? b : a)
      .transcript
      .trim();
  return text.isEmpty ? null : text;
}

/// Whether a recording's text is still waiting for its transcript: it has a
/// transcript but no text, as a held transcription leaves it until its
/// summary step writes one.
bool _textAwaitsTranscript(JournalAudio audio) =>
    (audio.entryText?.plainText.trim().isEmpty ?? true) &&
    _latestTranscriptText(audio) != null;
