import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/ai/helpers/entity_state_helper.dart';
import 'package:lotti/features/ai/helpers/prompt_builder_helper.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/repository/ai_prompt_resolver.dart';
import 'package:lotti/features/ai/repository/ai_tool_call_processor.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/task_summary_resolver.dart';
import 'package:lotti/features/ai/repository/tool_call_accumulator.dart';
import 'package:lotti/features/ai/services/auto_checklist_service.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart' show journalDbProvider;
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

export 'package:lotti/features/ai/repository/ai_tool_call_processor.dart'
    show extractJsonObjects;

part 'unified_ai_inference_repository.g.dart';

/// Result of audio preparation containing base64 data and format
class PreparedAudio {
  const PreparedAudio({
    required this.base64,
    required this.format,
  });

  final String base64;
  final ChatCompletionMessageInputAudioFormat format;
}

/// Repository for unified AI inference handling
/// This replaces the specialized controllers and provides a generic way
/// to run any configured AI prompt
class UnifiedAiInferenceRepository {
  UnifiedAiInferenceRepository(this.ref, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    final resolver = TaskSummaryResolver(
      getIt.isRegistered<AgentDatabase>()
          ? AgentRepository(getIt<AgentDatabase>())
          : null,
    );
    promptBuilderHelper = PromptBuilderHelper(
      aiInputRepository: ref.read(aiInputRepositoryProvider),
      journalRepository: ref.read(journalRepositoryProvider),
      taskSummaryResolver: resolver,
    );
  }

  final Ref ref;

  /// Clock function for timestamps — injectable for testing.
  final DateTime Function() _clock;

  late final AiToolCallProcessor _toolCallProcessor = AiToolCallProcessor(
    ref: ref,
    clock: _clock,
    autoChecklistServiceResolver: () => autoChecklistService,
  );

  late final AiPromptResolver _promptResolver = AiPromptResolver(ref: ref);

  late final PromptBuilderHelper promptBuilderHelper;
  AutoChecklistService? _autoChecklistService;

  AutoChecklistService get autoChecklistService {
    return _autoChecklistService ??= AutoChecklistService(
      checklistRepository: ref.read(checklistRepositoryProvider),
    );
  }

  // For testing purposes only
  // ignore: avoid_setters_without_getters
  set autoChecklistServiceForTesting(AutoChecklistService service) {
    _autoChecklistService = service;
  }

  Future<void> runInference({
    required String entityId,
    required AiConfigPrompt promptConfig,
    required void Function(String) onProgress,
    required void Function(InferenceStatus) onStatusChange,
    String? linkedEntityId,
  }) async {
    // Guard: legacy response types should not be executed
    if (promptConfig.aiResponseType.isLegacyType) {
      developer.log(
        'Skipping inference for legacy response type '
        '${promptConfig.aiResponseType.name} (prompt ${promptConfig.id})',
        name: 'UnifiedAiInferenceRepository',
      );
      return;
    }

    await _runInferenceInternal(
      entityId: entityId,
      promptConfig: promptConfig,
      onProgress: onProgress,
      onStatusChange: onStatusChange,
      isRerun: false,
      linkedEntityId: linkedEntityId,
    );
  }

  /// Internal inference method with rerun flag to prevent recursive auto-creation
  Future<void> _runInferenceInternal({
    required String entityId,
    required AiConfigPrompt promptConfig,
    required void Function(String) onProgress,
    required void Function(InferenceStatus) onStatusChange,
    required bool isRerun,
    JournalEntity? entity, // Optional entity to avoid redundant fetches
    String? linkedEntityId,
  }) async {
    // Keep the provider alive during the entire inference operation
    // This prevents disposal when the user navigates away
    final keepAliveLink = ref.keepAlive();

    final start = DateTime.now();

    try {
      onStatusChange(InferenceStatus.running);

      // Capture all needed repositories upfront before any async gaps
      // This ensures we have valid references throughout the operation
      final aiInputRepo = ref.read(aiInputRepositoryProvider);
      final aiConfigRepo = ref.read(aiConfigRepositoryProvider);

      // Get the entity if not provided
      entity ??= await aiInputRepo.getEntity(entityId);
      if (entity == null) {
        throw Exception('Entity not found: $entityId');
      }

      // Get the model configuration
      final model =
          await aiConfigRepo.getConfigById(promptConfig.defaultModelId)
              as AiConfigModel?;

      if (model == null) {
        throw Exception('Model not found: ${promptConfig.defaultModelId}');
      }

      // Get the inference provider
      final provider =
          await aiConfigRepo.getConfigById(model.inferenceProviderId)
              as AiConfigInferenceProvider?;

      if (provider == null) {
        throw Exception('Provider not found: ${model.inferenceProviderId}');
      }

      // Build the prompt with the entity data
      final prompt = await promptBuilderHelper.buildPromptWithData(
        promptConfig: promptConfig,
        entity: entity,
        linkedEntityId: linkedEntityId,
      );

      if (prompt == null) {
        throw Exception('Failed to build prompt');
      }

      // Prepare any additional data (images, audio)
      final images = await _prepareImages(promptConfig, entity);
      final preparedAudio = await _prepareAudio(promptConfig, entity, provider);

      // Run the inference
      final buffer = StringBuffer();
      final isAiStreamingEnabled = await ref
          .read(journalDbProvider)
          .getConfigFlag(enableAiStreamingFlag);

      // Get system message with placeholder substitution
      final systemMessage = await promptBuilderHelper
          .buildSystemMessageWithData(
            promptConfig: promptConfig,
            entity: entity,
          );

      // Start timing the inference
      final stopwatch = Stopwatch()..start();

      // OpenAI reasoning models with reasoning_effort set only accept temperature=1.0.
      // Other models (including non-reasoning OpenAI models like GPT-4/GPT-4o)
      // support custom temperature values.
      final useReasoningEffort =
          model.isReasoningModel && promptConfig.useReasoning;
      final temperature = useReasoningEffort ? 1.0 : 0.6;

      final stream = await _runCloudInference(
        prompt: prompt,
        model: model,
        provider: provider,
        images: images,
        preparedAudio: preparedAudio,
        temperature: temperature,
        systemMessage: systemMessage,
        entity: entity,
        promptConfig: promptConfig,
        isAiStreamingEnabled: isAiStreamingEnabled,
      );

      // Process the stream and accumulate tool calls
      final toolCallAccumulator = ToolCallAccumulator();
      String? pendingProgress;
      CompletionUsage? usage;

      await for (final chunk in stream) {
        // Capture usage metadata from the final chunk
        if (chunk.usage != null) {
          usage = chunk.usage;
        }

        final text = _extractTextFromChunk(chunk);
        buffer.write(text);
        final latest = buffer.toString();
        if (isAiStreamingEnabled) {
          onProgress(latest);
        } else {
          pendingProgress = latest;
        }

        // Accumulate tool calls from chunks
        if (chunk.choices?.isNotEmpty ?? false) {
          final delta = chunk.choices?.first.delta;
          developer.log(
            'Stream chunk received: hasContent=${text.isNotEmpty}, '
            'hasToolCalls=${delta?.toolCalls != null}, '
            'toolCallCount=${delta?.toolCalls?.length ?? 0}',
            name: 'UnifiedAiInferenceRepository',
          );
          toolCallAccumulator.processChunk(delta);
        }
      }

      // Stop timing after stream processing
      stopwatch.stop();
      final durationMs = stopwatch.elapsedMilliseconds;

      if (!isAiStreamingEnabled && pendingProgress != null) {
        onProgress(pendingProgress);
      }

      // Process accumulated tool calls
      List<ChatCompletionMessageToolCall>? toolCalls;
      if (toolCallAccumulator.hasToolCalls) {
        developer.log(
          'Processing ${toolCallAccumulator.count} accumulated tool calls',
          name: 'UnifiedAiInferenceRepository',
        );
        toolCalls = toolCallAccumulator.toToolCalls();
        developer.log(
          'Created ${toolCalls.length} tool calls from accumulator',
          name: 'UnifiedAiInferenceRepository',
        );
      } else {
        developer.log(
          'No tool calls accumulated from stream',
          name: 'UnifiedAiInferenceRepository',
        );
      }

      // Process the complete response
      await _processCompleteResponse(
        response: buffer.toString(),
        promptConfig: promptConfig,
        model: model,
        prompt: prompt,
        provider: provider,
        entity: entity,
        start: start,
        isRerun: isRerun,
        onProgress: onProgress,
        onStatusChange: onStatusChange,
        toolCalls: toolCalls,
        usage: usage,
        durationMs: durationMs,
        temperature: temperature,
        effectiveSystemMessage: systemMessage,
      );

      onStatusChange(InferenceStatus.idle);
    } catch (e, stackTrace) {
      // NOTE: Do NOT call onStatusChange(error) here!
      // The controller sets state.error THEN sets status, ensuring the widget
      // can read the error object when it rebuilds on status change.

      // Log additional error details
      developer.log(
        'Inference failed',
        name: 'UnifiedAiInferenceRepository',
        error: e,
        stackTrace: stackTrace,
      );

      rethrow;
    } finally {
      // Release the keepAlive link now that the operation is complete
      // This allows the provider to be disposed if no longer needed
      keepAliveLink.close();
    }
  }

  /// Prepare images if required
  Future<List<String>> _prepareImages(
    AiConfigPrompt promptConfig,
    JournalEntity entity,
  ) async {
    if (!promptConfig.requiredInputData.contains(InputDataType.images)) {
      return [];
    }

    if (entity is! JournalImage) return [];

    final fullPath = getFullImagePath(entity);
    final bytes = await File(fullPath).readAsBytes();
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

  /// Run cloud inference
  Future<Stream<CreateChatCompletionStreamResponse>> _runCloudInference({
    required String prompt,
    required String systemMessage,
    required AiConfigModel model,
    required AiConfigInferenceProvider provider,
    required List<String> images,
    required PreparedAudio? preparedAudio,
    required double? temperature,
    required JournalEntity entity,
    required AiConfigPrompt promptConfig,
    required bool isAiStreamingEnabled,
  }) async {
    final cloudRepo = ref.read(cloudInferenceRepositoryProvider);

    if (preparedAudio != null) {
      // No function calling tools for audio transcription tasks
      // This prevents models from getting confused about their capabilities
      developer.log(
        'Processing audio transcription without function calling tools',
        name: 'UnifiedAiInferenceRepository',
      );

      // Extract speech dictionary terms for context biasing
      // (used by Mistral's transcription endpoint as context_bias)
      final speechDictionaryTerms = await promptBuilderHelper
          .getSpeechDictionaryTerms(entity);

      final speechTerms = speechDictionaryTerms.isNotEmpty
          ? speechDictionaryTerms
          : null;
      return cloudRepo.generateWithAudio(
        prompt,
        model: model.providerModelId,
        audioBase64: preparedAudio.base64,
        baseUrl: provider.baseUrl,
        apiKey: provider.apiKey,
        provider: provider,
        maxCompletionTokens: model.maxCompletionTokens,
        stream: isAiStreamingEnabled,
        audioFormat: preparedAudio.format,
        speechDictionaryTerms: speechTerms,
        geminiThinkingMode:
            provider.inferenceProviderType == InferenceProviderType.gemini
            ? model.geminiThinkingMode
            : null,
      );
    } else if (images.isNotEmpty) {
      // No function calling tools for image analysis tasks
      // This prevents models from getting confused about their capabilities
      developer.log(
        'Processing image analysis without function calling tools',
        name: 'UnifiedAiInferenceRepository',
      );

      return cloudRepo.generateWithImages(
        prompt,
        model: model.providerModelId,
        temperature: temperature,
        images: images,
        baseUrl: provider.baseUrl,
        apiKey: provider.apiKey,
        provider: provider,
        maxCompletionTokens: model.maxCompletionTokens,
        geminiThinkingMode:
            provider.inferenceProviderType == InferenceProviderType.gemini
            ? model.geminiThinkingMode
            : null,
      );
    } else {
      // No tools attached — checklist updates and task summaries are
      // handled by the agent system. Other response types (image analysis,
      // audio transcription, prompt generation) don't use function calling.
      const List<ChatCompletionTool>? _ = null;

      return cloudRepo.generate(
        prompt,
        model: model.providerModelId,
        temperature: temperature,
        baseUrl: provider.baseUrl,
        apiKey: provider.apiKey,
        systemMessage: systemMessage,
        maxCompletionTokens: model.maxCompletionTokens,
        provider: provider,
        geminiThinkingMode: model.geminiThinkingMode,
      );
    }
  }

  /// Extract text from stream chunk
  String _extractTextFromChunk(CreateChatCompletionStreamResponse chunk) {
    try {
      // Handle potential null values in Anthropic's response
      final choices = chunk.choices;
      if (choices?.isEmpty ?? true) {
        return '';
      }
      return choices?.firstOrNull?.delta?.content ?? '';
    } catch (e) {
      // Log error but continue processing stream
      developer.log(
        'Error extracting text from chunk',
        name: 'UnifiedAiInferenceRepository',
        error: e,
      );
      return '';
    }
  }

  // ===========================================================================
  // Completed-response handling: persisting results and post-processing.
  // ===========================================================================

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
        // Coding prompts attach to the parent task (like cover art) rather
        // than the triggering audio/image entry. This makes each generated
        // prompt part of the task context, so later prompts can build on
        // earlier ones. Reuses the parent task already resolved for tool
        // calls above; falls back to the source entity when no parent task
        // can be resolved (e.g. an unlinked entry).
        var linkedId = entity.id;
        if (promptConfig.aiResponseType == AiResponseType.promptGeneration &&
            taskForToolCalls != null) {
          linkedId = taskForToolCalls.id;
        }
        aiResponseEntry = await ref
            .read(aiInputRepositoryProvider)
            .createAiResponseEntry(
              data: data,
              start: start,
              linkedId: linkedId,
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

  // ===========================================================================
  // Prompt-context filtering: which prompts are active for a given
  // entity/category context.
  // ===========================================================================

  Future<List<AiConfigPrompt>> getActivePromptsForContext({
    required JournalEntity entity,
  }) => _promptResolver.getActivePromptsForContext(entity: entity);

  // ===========================================================================
  // Tool-call dispatch: executes function calls emitted by the model.
  // ===========================================================================

  /// Process various tool calls including checklist operations and language
  /// detection. Returns true if language was detected and set.
  @visibleForTesting
  Future<bool> processToolCalls({
    required List<ChatCompletionMessageToolCall> toolCalls,
    required Task task,
  }) => _toolCallProcessor.process(toolCalls: toolCalls, task: task);

  /// Helper method to get the associated task for a given entity
  Future<Task?> _getTaskForEntity(JournalEntity entity) async {
    if (entity is Task) {
      return entity;
    }
    if (entity is JournalAudio || entity is JournalImage) {
      final linkedEntities = await ref
          .read(journalRepositoryProvider)
          .getLinkedToEntities(linkedTo: entity.id);
      return linkedEntities.firstWhereOrNull((e) => e is Task) as Task?;
    }
    return null;
  }
}

@riverpod
UnifiedAiInferenceRepository unifiedAiInferenceRepository(Ref ref) {
  return UnifiedAiInferenceRepository(ref);
}
