part of 'skill_inference_runner.dart';

/// Prompt-generation path of [SkillInferenceRunner].
///
/// Implementation body lives here; the class keeps a thin delegator so
/// mocktail mocks of [SkillInferenceRunner] still intercept the public
/// method (extension methods cannot be mocked).
extension SkillPromptGenerationRunner on SkillInferenceRunner {
  /// Run skill-based prompt generation on a [JournalAudio] or [JournalEntry].
  ///
  /// Uses the profile's high-end thinking model (falling back to the regular
  /// thinking model) to transform the entry's content (audio transcript or
  /// typed text) plus task context into a detailed prompt. The result is
  /// saved as an [AiResponseEntry] linked to the source entry.
  Future<void> runPromptGenerationImpl({
    required String entryId,
    required AutomationResult automationResult,
    String? linkedTaskId,
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
        final entryContent = SkillInferenceRunner._resolveEntryContent(entity);

        // 3. Build task context (parallel for independent calls).
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

        // 5. Call inference with text-only (no audio/image upload).
        final start = DateTime.now();
        final responseStream = _cloudRepository.generate(
          promptResult.userMessage,
          model: modelId,
          temperature: null,
          baseUrl: provider.baseUrl,
          apiKey: provider.apiKey,
          provider: provider,
          systemMessage: promptResult.systemMessage,
          geminiThinkingMode: effectiveThinkingMode,
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
        );

        await _aiInputRepository.createAiResponseEntry(
          data: data,
          start: start,
          linkedId: entryId,
          categoryId: entity.meta.categoryId,
        );

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
