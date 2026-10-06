part of 'skill_inference_runner.dart';

/// The bodies of the image-analysis and image-generation runs; the public methods on SkillInferenceRunner forward here.
extension _SkillMediaRuns on SkillInferenceRunner {
  Future<void> _runImageAnalysis({
    required String imageEntryId,
    required AutomationResult automationResult,
    String? linkedTaskId,
    String? overrideModelId,
    GeminiThinkingMode? geminiThinkingMode,
  }) async {
    final skill = automationResult.skill;
    final profile = automationResult.resolvedProfile;
    if (skill == null || profile == null) {
      throw StateError(
        'AutomationResult missing skill or profile for $imageEntryId: '
        'skill=${skill != null}, profile=${profile != null}',
      );
    }
    final target = await _resolveImageAnalysisTarget(
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
      _loggingService.log(
        LogDomain.ai,
        'Profile missing image recognition provider/model for $imageEntryId',
        subDomain: _logTag,
        level: InsightLevel.warn,
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
        //
        // Tiers are requested only when the resolved vision model can call
        // tools AND the provider's image path actually forwards them. Plenty
        // of capable vision models cannot, and this skill has shipped on a
        // free-text contract for a long time — so tool support upgrades the
        // output rather than gating it, and anything without it keeps
        // producing exactly what it produces today.
        //
        // The second half matters as much as the first: `generateWithImages`
        // fans out to provider-specific backends, and Ollama's carries no
        // tool parameters at all. Asking there would put "call
        // publish_entry_summary and respond with nothing else" in front of a
        // model that was handed no such tool.
        final useTieredSummary =
            (target.model?.supportsFunctionCalling ?? false) &&
            imagePathSupportsTools(provider: provider, model: modelId);
        const promptBuilder = SkillPromptBuilder();
        final promptResult = promptBuilder.build(
          skill: skill,
          taskContext: taskContext,
          linkedTasks: linkedTasks,
          currentTaskSummary: currentTaskSummary,
          requestTieredSummary: useTieredSummary,
        );

        // 4. Prepare image data.
        final images = await _prepareImageData(entity);
        if (images.isEmpty) {
          throw StateError('No image data available for $imageEntryId');
        }

        // 5. Call inference with separate system/user messages.
        final start = DateTime.now();
        final responseId = uuid.v4();
        final attribution = await _beginAttribution(
          workType: AiWorkType.imageAnalysis,
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
        final responseStream = _cloudRepository.generateWithImages(
          promptResult.userMessage,
          baseUrl: provider.baseUrl,
          apiKey: provider.apiKey,
          model: modelId,
          temperature: null,
          images: images,
          provider: provider,
          systemMessage: promptResult.systemMessage,
          tools: useTieredSummary ? [entrySummaryTool] : null,
          toolChoice: useTieredSummary
              ? entrySummaryToolChoiceFor(modelId)
              : null,
          geminiThinkingMode: effectiveThinkingMode,
          impactCollector: impactCollector,
        );

        // 6. Collect streaming response.
        final collected = await _collectStream(responseStream);

        // Decode the tiers when we asked for them. Unlike the audio summary,
        // invalid shorter tiers must not discard the full analysis. Recover
        // the tool's summary on its own before falling back to streamed prose.
        // Audio summaries still require all three tiers and retry on failure.
        EntrySummary? tiers;
        String? recoveredSummary;
        if (useTieredSummary) {
          try {
            tiers = parseEntrySummaryToolCall(collected.toolCalls);
          } on EntrySummaryToolException catch (e) {
            _loggingService.log(
              LogDomain.ai,
              'Image analysis tiers unavailable for $imageEntryId '
              '(${e.reason}) — trying analysis without tiers',
              subDomain: 'runImageAnalysis',
            );
            try {
              recoveredSummary = parseEntrySummaryToolBody(collected.toolCalls);
            } on EntrySummaryToolException {
              // Malformed/missing tool content cannot supply an analysis;
              // streamed prose remains usable, if the model supplied any.
            }
          }
        }

        // Prefer the tool's valid summary, with or without shorter tiers, then
        // streamed prose. Resolve the body BEFORE
        // the consumption record, because that record hashes the response for
        // provenance: a tool call leaves `collected.content` empty, so hashing
        // it would stamp every tiered analysis with the digest of an empty
        // string and break the link to the `AiResponseEntry` it describes.
        final response =
            tiers?.summary ?? recoveredSummary ?? collected.content.trim();
        if (response.isEmpty) {
          throw StateError(
            'Empty image analysis response for $imageEntryId',
          );
        }

        final attributionEnvelope = await _recordAttributedConsumption(
          attribution: attribution,
          entryId: imageEntryId,
          taskId: linkedTaskId,
          categoryId: entity.meta.categoryId,
          skillId: skill.id,
          provider: provider,
          modelId: modelId,
          responseType: skill.skillType.toResponseType,
          usage: collected.usage,
          impact: impactCollector.impact,
          start: start,
          interactionKind: AiInteractionKind.imageAnalysis,
          requestText:
              '${promptResult.systemMessage}\n${promptResult.userMessage}',
          responseText: response,
        );

        // 7. Re-read before persisting either projection so a source deleted
        // mid-run cannot leave a detached analysis behind.
        final currentImage =
            await EntityStateHelper.getCurrentEntityState<JournalImage>(
              entityId: imageEntryId,
              aiInputRepo: _aiInputRepository,
              entityTypeName: 'image analysis',
              domainLogger: _loggingService,
            );
        if (currentImage == null) {
          throw StateError('Image entity $imageEntryId disappeared mid-run');
        }

        // Attributed clients save analysis as its own authoritative output.
        // The compatibility path below remains the only write when the new
        // service is not registered (older tests/partial composition roots).
        if (attribution != null) {
          final aiResponse = await _aiInputRepository.createAiResponseEntry(
            id: responseId,
            data: AiResponseData(
              model: modelId,
              systemMessage: promptResult.systemMessage,
              prompt: promptResult.userMessage,
              thoughts: '',
              response: response,
              oneLiner: tiers?.oneLiner,
              tldr: tiers?.tldr,
              skillId: skill.id,
              type: skill.skillType.toResponseType,
              aiAttribution: attributionEnvelope,
            ),
            start: start,
            linkedId: imageEntryId,
            categoryId: entity.meta.categoryId,
          );
          if (aiResponse == null) {
            throw StateError(
              'Failed to persist image analysis for $imageEntryId',
            );
          }
          await _finalizeAttribution(attributionEnvelope);

          // The analysis entry is linked FROM the image, so its creation only
          // notifies the image and response ids — notification propagation is
          // one hop, and the parent tasks never hear about it. Emit the same
          // child-changed pairs `updateDbEntity` produces when the image
          // itself is edited — for EVERY parent task of the image, not just
          // the resolved [linkedTaskId]: an image can be linked from several
          // tasks, and each parent's agent needs its normal subscription wake
          // (120 s coalescing, automatic-updates opt-in / stale-marking) to
          // pick up the new analysis. Non-task parents are skipped — only
          // task contexts render image analyses, so waking their agents
          // would burn inference on invisible content. [linkedTaskId] is
          // unioned in because task resolution may have matched an outgoing
          // image→task link the incoming-parents query does not cover. The
          // legacy branch below needs no equivalent: its image update
          // propagates on its own.
          await _notifyParentTasksOfNestedResponse(
            sourceEntryId: imageEntryId,
            linkedTaskId: linkedTaskId,
            subDomain: 'runImageAnalysis',
            imageAnalysis: true,
          );
        } else {
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
        }

        _loggingService.log(
          LogDomain.ai,
          'Skill-based image analysis completed for $imageEntryId '
          '(${response.length} chars)',
          subDomain: 'runImageAnalysis',
        );
      },
    );
  }

  Future<void> _runImageGeneration({
    required String entryId,
    required AutomationResult automationResult,
    required String linkedTaskId,
    List<ProcessedReferenceImage>? referenceImages,
    String? overrideModelId,
  }) async {
    // Derive the response type from the skill when present so future skill
    // variants (or test stubs) drive the status controller correctly.
    // Falls back to `imageGeneration` only when the automation result is
    // misconfigured — that path immediately throws inside `_withStatusTracking`.
    final responseType =
        automationResult.skill?.skillType.toResponseType ??
        AiResponseType.imageGeneration;

    // Clear any error from a previous attempt so the UI starts this run fresh.
    _setImageGenerationError(
      null,
      entityId: entryId,
      linkedTaskId: linkedTaskId,
    );

    await _withStatusTracking(
      entityId: entryId,
      responseType: responseType,
      subDomain: 'runImageGeneration',
      linkedTaskId: linkedTaskId,
      onError: (error) {
        // Surface the provider's verbatim reason to the UI when we have one
        // (e.g. a Gemini `finishReason`); other failures (network, internal)
        // carry no provider reason and fall back to a generic message.
        final providerReason = error is ImageGenerationException
            ? error.providerReason
            : null;
        _setImageGenerationError(
          providerReason,
          entityId: entryId,
          linkedTaskId: linkedTaskId,
        );
      },
      body: () async {
        // 0. Validate automation result — inside status tracking so the UI
        // transitions to running before any early throw/return (prevents the
        // progress view from spinning forever on misconfigured profiles).
        final skill = automationResult.skill;
        final profile = automationResult.resolvedProfile;
        if (skill == null || profile == null) {
          throw StateError(
            'AutomationResult missing skill or profile for $entryId: '
            'skill=${skill != null}, profile=${profile != null}',
          );
        }
        // Honour the per-invocation model override (chosen in the
        // provider→model picker) when it resolves, otherwise fall back to the
        // profile's image-generation slot.
        final target = await _resolveImageGenerationTarget(
          profile: profile,
          overrideModelId: overrideModelId,
        );
        final provider = target.provider;
        final modelId = target.modelId;
        if (provider == null || modelId == null) {
          throw StateError(
            'Profile missing image generation provider/model for '
            '$entryId',
          );
        }

        // 1. Fetch the source entity (transcript or typed description).
        final entity = await _aiInputRepository.getEntity(entryId);
        if (entity == null) {
          throw StateError('Entity $entryId not found for image generation');
        }
        if (entity is! JournalAudio && entity is! JournalEntry) {
          throw StateError(
            'Entity $entryId is not a JournalAudio or JournalEntry '
            '(got ${entity.runtimeType}); image generation requires a '
            'text-bearing entry',
          );
        }

        // 2. Extract the entry content (user's description).
        final entryContent = _resolveEntryContent(entity);

        // 3. Build task context and summary in parallel.
        final (taskContext, linkedTasks) = await (
          _aiInputRepository.buildTaskDetailsJson(id: linkedTaskId),
          _aiInputRepository.buildLinkedTasksJson(linkedTaskId),
        ).wait;
        final currentTaskSummary = await _buildCurrentTaskSummary(
          entity,
          linkedTaskId,
        );

        // 4. Build prompts via SkillPromptBuilder.
        const promptBuilder = SkillPromptBuilder();
        final promptResult = promptBuilder.build(
          skill: skill,
          entryContent: entryContent,
          taskContext: taskContext,
          linkedTasks: linkedTasks,
          currentTaskSummary: currentTaskSummary,
        );

        // 5. Generate image via the cloud inference repository.
        _loggingService.log(
          LogDomain.ai,
          'Generating cover art for task $linkedTaskId '
          '(${referenceImages?.length ?? 0} reference images)',
          subDomain: _logTag,
        );

        final start = DateTime.now();
        final imageId = uuid.v1();
        final attribution = await _beginAttribution(
          workType: AiWorkType.imageGeneration,
          source: entity,
          output: AiArtifactReference(
            type: AiArtifactType.journalImage,
            id: imageId,
          ),
          skill: skill,
          automationResult: automationResult,
          taskId: linkedTaskId,
        );
        final impactCollector = InferenceImpactCollector();
        final generatedImage = await _cloudRepository.generateImage(
          prompt: promptResult.userMessage,
          model: modelId,
          provider: provider,
          systemMessage: promptResult.systemMessage,
          referenceImages: referenceImages,
          impactCollector: impactCollector,
        );

        // 6. Verify linked task still exists and get its category.
        final taskEntity = await _journalRepository.getJournalEntityById(
          linkedTaskId,
        );

        // Image generation is a single request (no token stream), so tokens
        // are null; impact comes from the collector for Melious. Record
        // before the task-existence check below: the billed call already
        // happened, so a task deleted mid-flight must not erase its
        // cost/impact record.
        final attributionEnvelope = await _recordAttributedConsumption(
          attribution: attribution,
          entryId: entryId,
          taskId: linkedTaskId,
          categoryId: taskEntity is Task ? taskEntity.meta.categoryId : null,
          skillId: skill.id,
          provider: provider,
          modelId: modelId,
          responseType: skill.skillType.toResponseType,
          usage: null,
          impact: impactCollector.impact,
          start: start,
          interactionKind: AiInteractionKind.imageGeneration,
          requestText:
              '${promptResult.systemMessage}\n${promptResult.userMessage}',
          responseText: generatedImage.mimeType,
        );

        if (taskEntity is! Task) {
          throw StateError(
            'Linked task $linkedTaskId not found before cover art save',
          );
        }

        // 7. Import the generated image as a JournalImage linked to the task.
        final extension =
            generatedImage.mimeType.split('/').lastOrNull ?? 'png';
        final importedImageId = await importGeneratedImageBytes(
          data: Uint8List.fromList(generatedImage.bytes),
          fileExtension: extension,
          linkedId: linkedTaskId,
          categoryId: taskEntity.meta.categoryId,
          imageId: imageId,
          aiAttribution: attributionEnvelope,
        );

        if (importedImageId == null) {
          throw StateError(
            'Failed to import generated image for task $linkedTaskId',
          );
        }
        await _finalizeAttribution(attributionEnvelope);

        // 8. Set the image as cover art on the task.
        //
        // Uses `importedImageId` (the JournalImage entity's real id), NOT
        // `imageId` (the pre-generated id passed into `ImageData.imageId`
        // for attribution purposes). `createImageEntry` derives the actual
        // entity id from a uuidV5 hash of the encoded `ImageData` — it does
        // NOT reuse `imageData.imageId` as the entity id — so the two
        // values are different. Setting `coverArtId` to `imageId` silently
        // pointed the task at an id nothing was ever stored under: the
        // cover art generated successfully but never rendered anywhere.
        final didUpdate = await getIt<PersistenceLogic>().updateTask(
          journalEntityId: linkedTaskId,
          change: (stored) => stored.copyWith(coverArtId: importedImageId),
        );
        if (didUpdate == null) {
          throw StateError(
            'Linked task $linkedTaskId disappeared before cover art update',
          );
        }

        _loggingService.log(
          LogDomain.ai,
          'Skill-based image generation completed for task $linkedTaskId '
          '(imageId: $importedImageId)',
          subDomain: 'runImageGeneration',
        );

        // 9. Trigger automatic image analysis on the newly created cover art,
        // treating it exactly like a manual photo drop.
        unawaited(
          _ref
              .read(automaticImageAnalysisTriggerProvider)
              .triggerAutomaticImageAnalysis(
                imageEntryId: importedImageId,
                linkedTaskId: linkedTaskId,
              ),
        );
      },
    );
  }
}
