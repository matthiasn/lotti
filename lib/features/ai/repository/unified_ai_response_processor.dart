part of 'unified_ai_inference_repository.dart';

/// Completed-response handling: persisting results and post-processing.
extension UnifiedAiResponseProcessor on UnifiedAiInferenceRepository {
  /// Process complete response and create appropriate entry
  Future<void> _processCompleteResponse({
    required String response,
    required AiConfigPrompt promptConfig,
    required AiConfigModel model,
    required AiConfigInferenceProvider provider,
    required String prompt,
    required JournalEntity entity,
    required DateTime start,
    required bool isRerun,
    required void Function(String) onProgress,
    required void Function(InferenceStatus) onStatusChange,
    List<ChatCompletionMessageToolCall>? toolCalls,
    CompletionUsage? usage,
    int? durationMs,
    double? temperature,
    String? effectiveSystemMessage,
  }) async {
    var thoughts = '';
    var cleanResponse = response;

    // Extract thoughts if present (for reasoning models like Gemini and OpenAI Thinking)
    if (response.contains('</think>')) {
      final parts = response.split('</think>');
      if (parts.length == 2) {
        thoughts = parts[0].replaceFirst('<think>', '').trim();
        cleanResponse = parts[1].trim();
      }
    }

    // Process tool calls for checklist completions
    final taskForToolCalls = await _getTaskForEntity(entity);

    if (toolCalls != null && toolCalls.isNotEmpty && taskForToolCalls != null) {
      developer.log(
        'Processing ${toolCalls.length} tool calls for task ${taskForToolCalls.id} (from ${entity.runtimeType})',
        name: 'UnifiedAiInferenceRepository',
      );
      final languageWasSet = await processToolCalls(
        toolCalls: toolCalls,
        task: taskForToolCalls,
      );

      // If language was set and response is empty, we need to re-run
      if (languageWasSet && response.trim().isEmpty && !isRerun) {
        developer.log(
          'Language was detected and set, but response is empty. Triggering automatic re-run for task ${taskForToolCalls.id}',
          name: 'UnifiedAiInferenceRepository',
        );
        // Re-run the inference with the same prompt to generate the summary in the detected language
        await _runInferenceInternal(
          entityId: entity.id,
          promptConfig: promptConfig,
          onProgress: onProgress,
          onStatusChange: onStatusChange,
          isRerun: true,
          entity: entity, // Pass the entity to avoid redundant fetch
        );
        return; // Exit early to avoid duplicate processing
      }
    } else {
      developer.log(
        'No tool calls to process - toolCalls: ${toolCalls?.length ?? 0}, taskForToolCalls: ${taskForToolCalls?.id ?? 'null'}, entity: ${entity.runtimeType}',
        name: 'UnifiedAiInferenceRepository',
      );
    }

    // Create AI response data
    // Note: temperature is computed earlier based on model.isReasoningModel
    final data = AiResponseData(
      model: model.providerModelId,
      temperature: temperature,
      systemMessage: effectiveSystemMessage ?? promptConfig.systemMessage,
      prompt: prompt,
      promptId: promptConfig.id,
      thoughts: thoughts,
      response: cleanResponse,
      type: promptConfig.aiResponseType,
      inputTokens: usage?.promptTokens,
      outputTokens: usage?.completionTokens,
      thoughtsTokens: usage?.completionTokensDetails?.reasoningTokens,
      durationMs: durationMs,
    );

    // Save the AI response entry
    // Also save for prompt generation types even when triggered from audio entries
    AiResponseEntry? aiResponseEntry;
    final shouldSaveEntry =
        promptConfig.aiResponseType.isPromptGenerationType ||
        (entity is! JournalAudio && entity is! JournalImage);

    if (shouldSaveEntry) {
      try {
        aiResponseEntry = await ref
            .read(aiInputRepositoryProvider)
            .createAiResponseEntry(
              data: data,
              start: start,
              linkedId: entity.id,
              categoryId: entity.meta.categoryId,
            );
        developer.log(
          'createAiResponseEntry result: ${aiResponseEntry?.id ?? "null"}',
          name: 'UnifiedAiInferenceRepository',
        );
      } catch (e) {
        developer.log(
          'createAiResponseEntry failed: $e',
          name: 'UnifiedAiInferenceRepository',
          error: e,
        );
      }
    }

    // Handle special post-processing
    developer.log(
      'About to call _handlePostProcessing. entity: ${entity.runtimeType}, promptConfig.aiResponseType: ${promptConfig.aiResponseType}',
      name: 'UnifiedAiInferenceRepository',
    );

    await _handlePostProcessing(
      entity: entity,
      promptConfig: promptConfig,
      response: cleanResponse,
      model: model,
      provider: provider,
      start: start,
      aiResponseEntry: aiResponseEntry,
      isRerun: isRerun,
    );
  }

  /// Handle any special post-processing based on response type
  Future<void> _handlePostProcessing({
    required JournalEntity entity,
    required AiConfigPrompt promptConfig,
    required AiConfigModel model,
    required AiConfigInferenceProvider provider,
    required String response,
    required DateTime start,
    required bool isRerun,
    AiResponseEntry? aiResponseEntry,
  }) async {
    final journalRepo = ref.read(journalRepositoryProvider);

    switch (promptConfig.aiResponseType) {
      // ignore: deprecated_member_use_from_same_package
      case AiResponseType.checklistUpdates:
      // ignore: deprecated_member_use_from_same_package
      case AiResponseType.taskSummary:
        // These response types are now handled by the agent system;
        // the enum values are kept for DB backwards-compatibility.
        break;
      case AiResponseType.imageAnalysis:
        if (entity is JournalImage) {
          // Get current image state to avoid overwriting concurrent changes
          final currentImage =
              await EntityStateHelper.getCurrentEntityState<JournalImage>(
                entityId: entity.id,
                aiInputRepo: ref.read(aiInputRepositoryProvider),
                entityTypeName: 'image analysis',
              );
          if (currentImage == null) {
            break;
          }

          final originalText = currentImage.entryText?.markdown ?? '';
          final amendedText = originalText.isEmpty
              ? response
              : '$originalText\n\n$response';

          try {
            // Add text to image by appending to existing content using current state
            final updated = currentImage.copyWith(
              entryText: EntryText(
                plainText: amendedText,
                markdown: amendedText,
              ),
            );
            await journalRepo.updateJournalEntity(updated);
            developer.log(
              'Successfully updated image analysis for image ${entity.id}',
              name: 'UnifiedAiInferenceRepository',
            );
          } catch (e) {
            developer.log(
              'Failed to update image analysis for image ${entity.id}',
              name: 'UnifiedAiInferenceRepository',
              error: e,
            );
          }
        }
      case AiResponseType.audioTranscription:
        if (entity is JournalAudio) {
          // Get current audio state to avoid overwriting concurrent changes
          final currentAudio =
              await EntityStateHelper.getCurrentEntityState<JournalAudio>(
                entityId: entity.id,
                aiInputRepo: ref.read(aiInputRepositoryProvider),
                entityTypeName: 'audio transcription',
              );
          if (currentAudio == null) {
            break;
          }

          final transcript = AudioTranscript(
            created: DateTime.now(),
            library: provider.name,
            model: model.providerModelId,
            detectedLanguage: '-',
            transcript: response.trim(),
            processingTime: DateTime.now().difference(start),
          );

          final completeResponse = response.trim();

          // Add transcript to audio data and update entry text using current state
          final existingTranscripts = currentAudio.data.transcripts ?? [];

          try {
            final updated = currentAudio.copyWith(
              data: currentAudio.data.copyWith(
                transcripts: [...existingTranscripts, transcript],
              ),
              entryText: EntryText(
                plainText: completeResponse,
                markdown: completeResponse,
              ),
            );
            await journalRepo.updateJournalEntity(updated);
            developer.log(
              'Successfully updated audio transcription for audio ${entity.id}',
              name: 'UnifiedAiInferenceRepository',
            );

            // Note: Task summary for audio is handled by AutomaticPromptTrigger
            // using category defaults.
            // See lib/features/speech/helpers/automatic_prompt_trigger.dart
          } catch (e) {
            developer.log(
              'Failed to update audio transcription for audio ${entity.id}',
              name: 'UnifiedAiInferenceRepository',
              error: e,
            );
          }
        }
      case AiResponseType.promptGeneration:
        // Prompt generation has no special post-processing - the response
        // is saved as an AiResponseEntry which is handled by the caller
        developer.log(
          'Prompt generation completed for entity ${entity.id}',
          name: 'UnifiedAiInferenceRepository',
        );
      case AiResponseType.imagePromptGeneration:
        // Image prompt generation has no special post-processing - the response
        // is saved as an AiResponseEntry which is handled by the caller
        developer.log(
          'Image prompt generation completed for entity ${entity.id}',
          name: 'UnifiedAiInferenceRepository',
        );
      case AiResponseType.imageGeneration:
        // Image generation is now handled via skills (SkillInferenceRunner).
        // This case should not be reached in normal flow.
        developer.log(
          'Image generation type received in response processing - no-op',
          name: 'UnifiedAiInferenceRepository',
        );
    }
  }
}
