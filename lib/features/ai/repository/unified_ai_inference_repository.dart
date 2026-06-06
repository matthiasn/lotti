import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/ai/functions/checklist_completion_functions.dart';
import 'package:lotti/features/ai/functions/label_functions.dart';
import 'package:lotti/features/ai/functions/lotti_checklist_update_handler.dart';
import 'package:lotti/features/ai/functions/task_functions.dart';
import 'package:lotti/features/ai/helpers/entity_state_helper.dart';
import 'package:lotti/features/ai/helpers/prompt_builder_helper.dart';
import 'package:lotti/features/ai/helpers/prompt_capability_filter.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/task_summary_resolver.dart';
import 'package:lotti/features/ai/repository/tool_call_accumulator.dart';
import 'package:lotti/features/ai/services/auto_checklist_service.dart';
import 'package:lotti/features/ai/services/checklist_completion_service.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/utils/checklist_validation.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/services/label_assignment_processor.dart';
import 'package:lotti/features/labels/utils/label_tool_parsing.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/features/tasks/state/checklist_item_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart' show journalDbProvider;
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'unified_ai_prompt_context.dart';
part 'unified_ai_response_processor.dart';
part 'unified_ai_tool_call_processor.dart';

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
        speechDictionaryTerms: speechDictionaryTerms.isNotEmpty
            ? speechDictionaryTerms
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

  /// Active-prompt filtering for an entity context. Thin delegator to
  /// [UnifiedAiPromptContext.getActivePromptsForContextImpl] so the method
  /// remains a mockable class member.
  Future<List<AiConfigPrompt>> getActivePromptsForContext({
    required JournalEntity entity,
  }) => getActivePromptsForContextImpl(entity: entity);

  /// Tool-call dispatch. Thin delegator to
  /// [UnifiedAiToolCallProcessor.processToolCallsImpl] (mockable class
  /// member). Returns true if a language was detected and set.
  @visibleForTesting
  Future<bool> processToolCalls({
    required List<ChatCompletionMessageToolCall> toolCalls,
    required Task task,
  }) => processToolCallsImpl(toolCalls: toolCalls, task: task);
}

@riverpod
UnifiedAiInferenceRepository unifiedAiInferenceRepository(Ref ref) {
  return UnifiedAiInferenceRepository(ref);
}

/// Extracts top-level JSON object substrings from [input] by brace-depth
/// scanning.
///
/// AI providers sometimes concatenate several JSON objects into one tool-call
/// argument string; this splits them back apart. Text outside braces is
/// ignored. Braces inside JSON string literals (including escaped quotes)
/// are ignored so a reason like `"The user selected {Item}"` does not skew
/// the depth count.
List<String> extractJsonObjects(String input) {
  final jsonObjects = <String>[];
  var depth = 0;
  var start = -1;
  var inString = false;
  var escaped = false;

  for (var i = 0; i < input.length; i++) {
    final char = input[i];

    if (escaped) {
      escaped = false;
      continue;
    }
    if (inString) {
      if (char == r'\') {
        escaped = true;
      } else if (char == '"') {
        inString = false;
      }
      continue;
    }
    // Only treat quotes as string delimiters inside an object — stray
    // quotes in the surrounding prose must not flip the string state.
    if (char == '"' && depth > 0) {
      inString = true;
    } else if (char == '{') {
      if (depth == 0) {
        start = i;
      }
      depth++;
    } else if (char == '}') {
      if (depth > 0) {
        depth--;
        if (depth == 0 && start != -1) {
          jsonObjects.add(input.substring(start, i + 1));
          start = -1;
        }
      }
    }
  }

  return jsonObjects;
}
