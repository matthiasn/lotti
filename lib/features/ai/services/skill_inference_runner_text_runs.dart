part of 'skill_inference_runner.dart';

/// The body of the prompt-generation run; the public method on SkillInferenceRunner forwards here.
extension _SkillTextRuns on SkillInferenceRunner {
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
