part of 'skill_inference_runner.dart';

/// The bodies of the audio-summary and prompt-generation runs; the public methods on SkillInferenceRunner forward here.
extension _SkillTextRuns on SkillInferenceRunner {
  Future<void> _runAudioSummary({
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
    final target = await _resolveAudioSummaryTarget(
      profile: profile,
      overrideModelId: overrideModelId,
    );
    // Like prompt generation, the fallback here is the profile's *required*
    // thinking slot, so the resolved target always carries a provider and a
    // model id — unlike the optional transcription / image slots, which is
    // why those paths null-check and this one does not.
    final provider = target.provider!;
    final modelId = target.modelId!;
    final effectiveThinkingMode = _geminiThinkingModeForTarget(
      target,
      geminiThinkingMode,
    );

    // The thinking slot is constrained to tool-capable models by the profile
    // form, so this is an assertion rather than a fallback: it only fires for
    // a profile seeded programmatically (bypassing the picker) or a model row
    // whose user-editable capability flag is wrong. Skipping is the honest
    // outcome — firing a pinned tool call at a model that cannot call tools
    // burns the call and returns nothing usable.
    if (target.model != null && !target.model!.supportsFunctionCalling) {
      _loggingService.log(
        LogDomain.ai,
        'Skipping audio summary for $audioEntryId: resolved model $modelId '
        'is not marked as supporting function calling',
        subDomain: 'runAudioSummary',
      );
      return;
    }

    await _withStatusTracking(
      entityId: audioEntryId,
      responseType: skill.skillType.toResponseType,
      subDomain: 'runAudioSummary',
      linkedTaskId: linkedTaskId,
      body: () async {
        // 1. Fetch the audio entity.
        final entity = await _aiInputRepository.getEntity(audioEntryId);
        if (entity is! JournalAudio) {
          throw StateError('Entity $audioEntryId is not a JournalAudio');
        }

        // 2. Resolve the text to summarize — an edit wins over the raw
        // transcript, same precedence every other consumer uses.
        final entryContent = _resolveEntryContent(entity);
        if (entryContent.length < _audioSummaryMinChars) {
          _loggingService.log(
            LogDomain.ai,
            'Skipping audio summary for $audioEntryId: transcript is '
            '${entryContent.length} chars, under the '
            '$_audioSummaryMinChars minimum',
            subDomain: 'runAudioSummary',
          );
          return;
        }

        // 3. Build task context. This is the snapshot the summary is framed
        // by; it is deliberately read now rather than referenced later.
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

        // 5. Call inference with the summary tool pinned.
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
        // Each attempt gets its OWN collector. `InferenceImpactCollector` is a
        // single mutable slot, so sharing one across the retry would let the
        // second call's impact overwrite the first's and silently drop a real
        // provider charge from the ledger.
        Future<
          ({
            String content,
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
              tools: [entrySummaryTool],
              toolChoice: entrySummaryToolChoiceFor(modelId),
              geminiThinkingMode: effectiveThinkingMode,
              impactCollector: collector,
            ),
          );
          return (
            content: result.content,
            toolCalls: result.toolCalls,
            usage: result.usage,
            impact: collector.impact,
          );
        }

        // 6. Decode the tool call. One forced retry covers the common
        // failure — a model that narrates instead of calling, or emits a
        // one-liner over the length cap — without turning a persistently
        // misbehaving model into an unbounded retry loop.
        //
        // Spend from BOTH attempts is billed, and it is billed even when the
        // retry also fails: the provider ran the calls either way, so throwing
        // before the ledger write would make a model that never produces a
        // usable summary look free — exactly the model whose cost the user
        // most needs to see.
        var attempt = await callModel(promptResult.userMessage);
        var usage = attempt.usage;
        var impact = attempt.impact;
        EntrySummary? summary;
        EntrySummaryToolException? failure;

        try {
          summary = parseEntrySummaryToolCall(attempt.toolCalls);
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
            'Call the $entrySummaryToolName tool with all three arguments '
            'and respond with nothing else.',
          );
          usage = SkillInferenceRunner._mergeUsage(usage, attempt.usage);
          impact = SkillInferenceRunner._mergeImpact(impact, attempt.impact);
          try {
            summary = parseEntrySummaryToolCall(attempt.toolCalls);
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
          responseText: summary?.summary ?? '',
        );

        if (summary == null) {
          throw failure!;
        }

        // 7. Re-read the source before persisting so a recording deleted
        // mid-run cannot leave a detached summary behind.
        final currentAudio =
            await EntityStateHelper.getCurrentEntityState<JournalAudio>(
              entityId: audioEntryId,
              aiInputRepo: _aiInputRepository,
              entityTypeName: 'audio summary',
            );
        if (currentAudio == null) {
          throw StateError('Audio entity $audioEntryId disappeared mid-run');
        }

        // 8. Persist as an AiResponseEntry linked to the AUDIO entry, never
        // to the task: the summary is about this recording, and the collapsed
        // card resolves it by walking the recording's linked responses.
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
  }

  Future<void> _runPromptGeneration({
    required String entryId,
    required AutomationResult automationResult,
    String? linkedTaskId,
    List<ProcessedReferenceImage>? referenceImages,
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

        // 3. Build task context (parallel for independent calls). The
        // category brief rides along so the coding prompt is framed by the
        // same knowledge a task-agent wake is, and a coding prompt also gets
        // the task's pull requests, refreshed from GitHub for it.
        final (
          String? taskContext,
          String? linkedTasks,
          String? categoryKnowledge,
          String? pullRequests,
        ) = linkedTaskId != null
            ? await (
                _aiInputRepository.buildTaskDetailsJson(id: linkedTaskId),
                _aiInputRepository.buildLinkedTasksJson(linkedTaskId),
                _aiInputRepository.buildCategoryKnowledge(linkedTaskId),
                SkillInferenceRunner._carriesPullRequests(skill)
                    ? _pullRequestContext(linkedTaskId)
                    : Future<String?>.value(),
              ).wait
            : (null, null, null, null);

        // 4. Build prompts via SkillPromptBuilder.
        const promptBuilder = SkillPromptBuilder();
        final promptResult = promptBuilder.build(
          skill: skill,
          entryContent: entryContent,
          taskContext: taskContext,
          linkedTasks: linkedTasks,
          categoryKnowledge: categoryKnowledge,
          pullRequests: pullRequests,
        );

        // 5. Call inference, using the existing multimodal request path only
        // when the user selected task images. Empty selection is deliberately
        // identical to the historical text-only request.
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
        final requestedImageCount = referenceImages?.length ?? 0;
        final resolvedModel = target.model;
        final selectedImages =
            resolvedModel != null &&
                supportsChatImageInput(
                  model: resolvedModel,
                  provider: target.provider,
                )
            ? referenceImages ?? const []
            : const <ProcessedReferenceImage>[];
        if (requestedImageCount > 0 && selectedImages.isEmpty) {
          _loggingService.log(
            LogDomain.ai,
            resolvedModel == null
                ? 'Dropping $requestedImageCount selected image(s) for '
                      '$entryId: model metadata is unavailable for $modelId'
                : 'Dropping $requestedImageCount selected image(s) for '
                      '$entryId: resolved model $modelId does not accept '
                      'chat images',
            subDomain: 'runPromptGeneration',
          );
        }
        final responseStream = selectedImages.isEmpty
            ? _cloudRepository.generate(
                promptResult.userMessage,
                model: modelId,
                temperature: null,
                baseUrl: provider.baseUrl,
                apiKey: provider.apiKey,
                provider: provider,
                systemMessage: promptResult.systemMessage,
                geminiThinkingMode: effectiveThinkingMode,
                impactCollector: impactCollector,
              )
            : _cloudRepository.generateWithImages(
                promptResult.userMessage,
                model: modelId,
                temperature: null,
                baseUrl: provider.baseUrl,
                apiKey: provider.apiKey,
                provider: provider,
                systemMessage: promptResult.systemMessage,
                images: selectedImages
                    .map((image) => image.base64Data)
                    .toList(growable: false),
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
}
