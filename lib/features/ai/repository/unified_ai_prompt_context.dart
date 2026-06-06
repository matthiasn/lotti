part of 'unified_ai_inference_repository.dart';

/// Prompt-context filtering: which prompts are active for a given
/// entity/category context.
extension UnifiedAiPromptContext on UnifiedAiInferenceRepository {
  /// Get all active prompts that match the current context
  Future<List<AiConfigPrompt>> getActivePromptsForContext({
    required JournalEntity entity,
  }) async {
    final allPrompts = await ref
        .read(aiConfigRepositoryProvider)
        .getConfigsByType(AiConfigType.prompt);

    final activePrompts = <AiConfigPrompt>[];

    // Check all prompts in parallel for better performance
    final activeChecks = <Future<bool>>[];
    final validPrompts = <AiConfigPrompt>[];

    for (final config in allPrompts) {
      if (config is AiConfigPrompt &&
          !config.archived &&
          !config.aiResponseType.isLegacyType) {
        validPrompts.add(config);
        activeChecks.add(_isPromptActiveForEntity(config, entity));
      }
    }

    // Wait for all checks to complete
    final results = await Future.wait(activeChecks);

    // Add active prompts to the result
    for (var i = 0; i < results.length; i++) {
      if (results[i]) {
        activePrompts.add(validPrompts[i]);
      }
    }

    // Filter prompts by platform capability (remove local-only models on mobile)
    final capabilityFilter = ref.read(promptCapabilityFilterProvider);
    final platformFilteredPrompts = await capabilityFilter
        .filterPromptsByPlatform(activePrompts);

    return platformFilteredPrompts;
  }

  /// Check if a prompt is active for a given entity type
  Future<bool> _isPromptActiveForEntity(
    AiConfigPrompt prompt,
    JournalEntity entity,
  ) async {
    // Check if prompt requires specific input data types
    final hasTask = prompt.requiredInputData.contains(InputDataType.task);
    final hasImages = prompt.requiredInputData.contains(InputDataType.images);
    final hasAudio = prompt.requiredInputData.contains(
      InputDataType.audioFiles,
    );

    // For prompts that require task context
    if (hasTask) {
      if (entity is Task) {
        // Prompt generation types require an audio entry as input (for the
        // transcript) so they should not appear on task-level menus.
        if (prompt.aiResponseType.isPromptGenerationType) {
          return false;
        }
        // Direct task entity - always valid as long as additional modality
        // requirements are satisfied.
        return !hasImages && !hasAudio;
      } else if (entity is JournalImage && hasImages) {
        // Image with task requirement - check if linked to task
        final linkedEntities = await ref
            .read(journalRepositoryProvider)
            .getLinkedToEntities(linkedTo: entity.id);
        return linkedEntities.any((e) => e is Task);
      } else if (entity is JournalAudio && hasAudio) {
        // Audio with task requirement - check if linked to task
        final linkedEntities = await ref
            .read(journalRepositoryProvider)
            .getLinkedToEntities(linkedTo: entity.id);
        return linkedEntities.any((e) => e is Task);
      }

      // Special case: Prompt generation types may be triggered from an audio
      // entry popup even though they only require task context (not audio file
      // upload) — they use the {{audioTranscript}} placeholder.
      if (entity is JournalAudio &&
          prompt.aiResponseType.isPromptGenerationType) {
        final linkedEntities = await ref
            .read(journalRepositoryProvider)
            .getLinkedToEntities(linkedTo: entity.id);
        return linkedEntities.any((e) => e is Task);
      }

      return false;
    }

    // For prompts without task requirement
    if (hasImages && entity is! JournalImage) return false;
    if (hasAudio && entity is! JournalAudio) return false;

    return true;
  }

  /// Run inference with a given prompt configuration
}
