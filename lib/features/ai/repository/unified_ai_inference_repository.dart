import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/supported_language.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/functions/checklist_completion_functions.dart';
import 'package:lotti/features/ai/functions/checklist_tool_selector.dart';
import 'package:lotti/features/ai/functions/label_functions.dart';
import 'package:lotti/features/ai/functions/lotti_checklist_update_handler.dart';
import 'package:lotti/features/ai/functions/lotti_conversation_processor.dart';
import 'package:lotti/features/ai/functions/task_functions.dart';
import 'package:lotti/features/ai/helpers/entity_state_helper.dart';
import 'package:lotti/features/ai/helpers/prompt_builder_helper.dart';
import 'package:lotti/features/ai/helpers/prompt_capability_filter.dart';
import 'package:lotti/features/ai/helpers/smart_task_summary_trigger.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/providers/ollama_inference_repository_provider.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_wrapper.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:lotti/features/ai/services/auto_checklist_service.dart';
import 'package:lotti/features/ai/services/checklist_completion_service.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/utils/checklist_validation.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/services/label_assignment_processor.dart';
import 'package:lotti/features/labels/utils/label_tool_parsing.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/features/tasks/state/checklist_item_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart' show journalDbProvider;
import 'package:lotti/services/dev_log.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'unified_ai_inference_repository.g.dart';

/// Minimum title length for AI suggestion to be applied
const kMinExistingTitleLengthForAiSuggestion = 5;

/// Repository for unified AI inference handling
/// This replaces the specialized controllers and provides a generic way
/// to run any configured AI prompt
class UnifiedAiInferenceRepository {
  UnifiedAiInferenceRepository(this.ref) {
    promptBuilderHelper = PromptBuilderHelper(
      aiInputRepository: ref.read(aiInputRepositoryProvider),
      journalRepository: ref.read(journalRepositoryProvider),
      checklistRepository: ref.read(checklistRepositoryProvider),
      labelsRepository: ref.read(labelsRepositoryProvider),
    );
  }

  final Ref ref;
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

    // TODO(matthiasn): remove after some deprecation period
    final deprecatedConfigs = allPrompts
        .whereType<AiConfigPrompt>()
        .where((p) =>
            // ignore: deprecated_member_use_from_same_package
            p.aiResponseType == AiResponseType.actionItemSuggestions)
        .toList();

    if (deprecatedConfigs.isNotEmpty) {
      final configRepo = ref.read(aiConfigRepositoryProvider);
      await Future.wait(
          deprecatedConfigs.map((c) => configRepo.deleteConfig(c.id)));
      ref.invalidateSelf();
      return []; // Return early to avoid using stale data. The provider will rebuild.
    }

    for (final config in allPrompts) {
      if (config is AiConfigPrompt && !config.archived) {
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
    final platformFilteredPrompts =
        await capabilityFilter.filterPromptsByPlatform(activePrompts);

    return platformFilteredPrompts;
  }

  /// Check if a prompt is active for a given entity type
  Future<bool> _isPromptActiveForEntity(
    AiConfigPrompt prompt,
    JournalEntity entity,
  ) async {
    // First check category restrictions
    final categoryId = entity.meta.categoryId;
    if (categoryId != null) {
      final categoryRepo = ref.read(categoryRepositoryProvider);
      final category = await categoryRepo.getCategoryById(categoryId);

      if (category != null) {
        // If allowedPromptIds is null or empty, no prompts are allowed
        if (category.allowedPromptIds?.isEmpty ?? true) {
          return false;
        }

        // Check if this prompt is in the allowed list
        if (!category.allowedPromptIds!.contains(prompt.id)) {
          return false;
        }
      }
    }

    // Check if prompt requires specific input data types
    final hasTask = prompt.requiredInputData.contains(InputDataType.task);
    final hasImages = prompt.requiredInputData.contains(InputDataType.images);
    final hasAudio =
        prompt.requiredInputData.contains(InputDataType.audioFiles);

    // For prompts that require task context
    if (hasTask) {
      if (entity is Task) {
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

      // Special case: Checklist Updates prompt may be triggered from an
      // audio entry popup even though it only requires task context.
      if (entity is JournalAudio &&
          prompt.aiResponseType == AiResponseType.checklistUpdates) {
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
  Future<void> runInference({
    required String entityId,
    required AiConfigPrompt promptConfig,
    required void Function(String) onProgress,
    required void Function(InferenceStatus) onStatusChange,
    bool useConversationApproach =
        false, // Flag to enable new conversation approach
    String? linkedEntityId,
  }) async {
    await _runInferenceInternal(
      entityId: entityId,
      promptConfig: promptConfig,
      onProgress: onProgress,
      onStatusChange: onStatusChange,
      isRerun: false,
      useConversationApproach: useConversationApproach,
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
    bool useConversationApproach = false,
    JournalEntity? entity, // Optional entity to avoid redundant fetches
    String? linkedEntityId,
  }) async {
    final start = DateTime.now();

    try {
      onStatusChange(InferenceStatus.running);

      // Get the entity if not provided
      entity ??= await ref.read(aiInputRepositoryProvider).getEntity(entityId);
      if (entity == null) {
        throw Exception('Entity not found: $entityId');
      }

      // Get the model configuration
      final model = await ref
          .read(aiConfigRepositoryProvider)
          .getConfigById(promptConfig.defaultModelId) as AiConfigModel?;

      if (model == null) {
        throw Exception('Model not found: ${promptConfig.defaultModelId}');
      }

      // Get the inference provider
      final provider = await ref
              .read(aiConfigRepositoryProvider)
              .getConfigById(model.inferenceProviderId)
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
      final audioBase64 = await _prepareAudio(promptConfig, entity);

      // Run the inference
      final buffer = StringBuffer();
      final isAiStreamingEnabled = await ref
          .read(journalDbProvider)
          .getConfigFlag(enableAiStreamingFlag);

      // Get system message with placeholder substitution
      var systemMessage = await promptBuilderHelper.buildSystemMessageWithData(
        promptConfig: promptConfig,
        entity: entity,
      );

      // Modify system message if task has language preference
      if (entity is Task &&
          entity.data.languageCode != null &&
          promptConfig.aiResponseType == AiResponseType.taskSummary) {
        final language = SupportedLanguage.fromCode(entity.data.languageCode!);
        if (language != null) {
          systemMessage =
              '$systemMessage\n\nIMPORTANT: The task has a language preference set to ${language.name} (${language.code}). Generate the entire summary in this language.';
        }
      }

      // Check if we should use conversation approach for checklist updates
      developer.log(
        'Checking conversation approach: useConversationApproach=$useConversationApproach, '
        'responseType=${promptConfig.aiResponseType}, '
        'supportsFunctionCalling=${model.supportsFunctionCalling}, '
        'provider=${provider.inferenceProviderType}, '
        'model=${model.providerModelId}',
        name: 'UnifiedAiInferenceRepository',
      );

      if (useConversationApproach &&
          promptConfig.aiResponseType == AiResponseType.checklistUpdates &&
          model.supportsFunctionCalling) {
        developer.log(
          'Using conversation approach for checklist updates',
          name: 'UnifiedAiInferenceRepository',
        );

        // Use conversation processor for better batching and error handling
        await _processWithConversation(
          prompt: prompt,
          entity: entity,
          promptConfig: promptConfig,
          model: model,
          provider: provider,
          systemMessage: systemMessage,
          onProgress: onProgress,
          onStatusChange: onStatusChange,
          start: start,
          isRerun: isRerun,
        );
        return; // Exit early, conversation processor handles everything
      }

      final stream = await _runCloudInference(
        prompt: prompt,
        model: model,
        provider: provider,
        images: images,
        audioBase64: audioBase64,
        temperature: 0.6,
        systemMessage: systemMessage,
        entity: entity,
        promptConfig: promptConfig,
      );

      // Process the stream and accumulate tool calls
      final toolCallAccumulator = <String, Map<String, dynamic>>{};
      var toolCallCounter = 0;
      String? pendingProgress;

      await for (final chunk in stream) {
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
          if (delta?.toolCalls != null) {
            developer.log(
              'Tool call details: ${delta!.toolCalls!.map((tc) => 'id=${tc.id}, '
                  'index=${tc.index}, function=${tc.function?.name}, '
                  'hasArgs=${tc.function?.arguments != null}').join('; ')}',
              name: 'UnifiedAiInferenceRepository',
            );
            // Special handling: if we receive multiple tool calls in one chunk all with the same index,
            // they might be complete tool calls rather than chunks
            if (delta.toolCalls!.length > 1 &&
                delta.toolCalls!.every(
                    (tc) => tc.index == 0 && tc.function?.arguments != null)) {
              developer.log(
                'Detected ${delta.toolCalls!.length} complete tool calls in single chunk',
                name: 'UnifiedAiInferenceRepository',
              );

              // Each is a complete tool call
              for (final toolCallChunk in delta.toolCalls!) {
                final toolCallId = 'tool_${toolCallCounter++}';
                toolCallAccumulator[toolCallId] = {
                  'id': toolCallId,
                  'index': toolCallChunk.index ?? 0,
                  'type': toolCallChunk.type?.toString() ?? 'function',
                  'function': <String, dynamic>{
                    'name': toolCallChunk.function?.name ?? '',
                    'arguments': toolCallChunk.function?.arguments ?? '',
                  },
                };
                developer.log(
                  'Added complete tool call $toolCallId: ${toolCallChunk.function?.name}',
                  name: 'UnifiedAiInferenceRepository',
                );
              }
            } else {
              // Normal streaming chunk processing
              for (final toolCallChunk in delta.toolCalls!) {
                // Log the raw chunk data for debugging
                developer.log(
                  'Tool call chunk - id: ${toolCallChunk.id}, index: ${toolCallChunk.index}, '
                  'type: ${toolCallChunk.type}, function: ${toolCallChunk.function?.name}, '
                  'args length: ${toolCallChunk.function?.arguments?.length ?? 0}',
                  name: 'UnifiedAiInferenceRepository',
                );

                // If this chunk has an ID or has function data, it's starting a new tool call
                var toolCallId = toolCallChunk.id;

                // Generate ID if not provided or if it's an empty string
                if (toolCallId == null || toolCallId.isEmpty) {
                  toolCallId = 'tool_${toolCallCounter++}';
                }

                if (toolCallChunk.id != null ||
                    toolCallChunk.function?.name != null) {
                  // This is a new tool call
                  toolCallAccumulator[toolCallId] = {
                    'id': toolCallId,
                    'index': toolCallChunk.index ?? toolCallAccumulator.length,
                    'type': toolCallChunk.type?.toString() ?? 'function',
                    'function': <String, dynamic>{
                      'name': toolCallChunk.function?.name ?? '',
                      'arguments': toolCallChunk.function?.arguments ?? '',
                    },
                  };
                  developer.log(
                    'Started new tool call $toolCallId: ${toolCallChunk.function?.name}',
                    name: 'UnifiedAiInferenceRepository',
                  );
                } else if (toolCallChunk.index != null) {
                  // Try to find by index if no ID
                  final targetKey = toolCallAccumulator.entries
                      .firstWhereOrNull(
                          (e) => e.value['index'] == toolCallChunk.index)
                      ?.key;

                  if (targetKey != null) {
                    final existing = toolCallAccumulator[targetKey]!;
                    final functionData =
                        existing['function'] as Map<String, dynamic>;

                    if (toolCallChunk.function != null) {
                      if (toolCallChunk.function!.name != null) {
                        functionData['name'] = toolCallChunk.function!.name;
                      }
                      if (toolCallChunk.function!.arguments != null) {
                        functionData['arguments'] =
                            ((functionData['arguments'] ?? '') as String) +
                                toolCallChunk.function!.arguments!;
                      }
                    }
                    developer.log(
                      'Continued tool call $targetKey (index ${toolCallChunk.index}) with arguments chunk',
                      name: 'UnifiedAiInferenceRepository',
                    );
                  }
                } else {
                  // This is a continuation of an existing tool call
                  // Find the most recent tool call to append to
                  if (toolCallAccumulator.isNotEmpty) {
                    final lastKey = toolCallAccumulator.keys.last;
                    final existing = toolCallAccumulator[lastKey]!;
                    final functionData =
                        existing['function'] as Map<String, dynamic>;

                    if (toolCallChunk.function != null) {
                      if (toolCallChunk.function!.name != null) {
                        functionData['name'] = toolCallChunk.function!.name;
                      }
                      if (toolCallChunk.function!.arguments != null) {
                        functionData['arguments'] =
                            ((functionData['arguments'] ?? '') as String) +
                                toolCallChunk.function!.arguments!;
                      }
                    }
                    developer.log(
                      'Continued tool call $lastKey with arguments chunk (no index)',
                      name: 'UnifiedAiInferenceRepository',
                    );
                  }
                }
              }
            }
          }
        }
      }

      if (!isAiStreamingEnabled && pendingProgress != null) {
        onProgress(pendingProgress);
      }

      // Process accumulated tool calls
      List<ChatCompletionMessageToolCall>? toolCalls;
      if (toolCallAccumulator.isNotEmpty) {
        developer.log(
          'Processing ${toolCallAccumulator.length} accumulated tool calls',
          name: 'UnifiedAiInferenceRepository',
        );

        // Log all accumulated tool calls for debugging
        toolCallAccumulator.forEach((key, value) {
          final functionData = value['function'] as Map<String, dynamic>?;
          developer.log(
            'Accumulated tool call $key: function=${functionData?['name']}, '
            'args length=${functionData?['arguments']?.toString().length ?? 0}',
            name: 'UnifiedAiInferenceRepository',
          );
        });

        toolCalls = toolCallAccumulator.values.where((data) {
          // Only process tool calls with valid function data
          final functionData = data['function'] as Map<String, dynamic>?;
          final hasValidArgs =
              functionData?['arguments']?.toString().isNotEmpty ?? false;
          if (!hasValidArgs) {
            developer.log(
              'Skipping tool call ${data['id']} - no valid arguments',
              name: 'UnifiedAiInferenceRepository',
            );
          }
          return hasValidArgs;
        }).map((data) {
          final functionData = data['function'] as Map<String, dynamic>;
          developer.log(
            'Creating tool call ${data['id']}: ${functionData['name']} with args: ${functionData['arguments']}',
            name: 'UnifiedAiInferenceRepository',
          );
          return ChatCompletionMessageToolCall(
            id: data['id'] as String,
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: functionData['name'] as String,
              arguments: functionData['arguments'] as String,
            ),
          );
        }).toList();

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
      );

      onStatusChange(InferenceStatus.idle);
    } catch (e, stackTrace) {
      onStatusChange(InferenceStatus.error);

      // Log additional error details
      developer.log(
        'Inference failed',
        name: 'UnifiedAiInferenceRepository',
        error: e,
        stackTrace: stackTrace,
      );

      rethrow;
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

  /// Prepare audio if required
  Future<String?> _prepareAudio(
    AiConfigPrompt promptConfig,
    JournalEntity entity,
  ) async {
    if (!promptConfig.requiredInputData.contains(InputDataType.audioFiles)) {
      return null;
    }

    if (entity is! JournalAudio) return null;

    final fullPath = await AudioUtils.getFullAudioPath(entity);
    final bytes = await File(fullPath).readAsBytes();
    return base64Encode(bytes);
  }

  /// Run cloud inference
  Future<Stream<CreateChatCompletionStreamResponse>> _runCloudInference({
    required String prompt,
    required String systemMessage,
    required AiConfigModel model,
    required AiConfigInferenceProvider provider,
    required List<String> images,
    required String? audioBase64,
    required double temperature,
    required JournalEntity entity,
    required AiConfigPrompt promptConfig,
  }) async {
    final cloudRepo = ref.read(cloudInferenceRepositoryProvider);

    if (audioBase64 != null) {
      // No function calling tools for audio transcription tasks
      // This prevents models from getting confused about their capabilities
      developer.log(
        'Processing audio transcription without function calling tools',
        name: 'UnifiedAiInferenceRepository',
      );

      return cloudRepo.generateWithAudio(
        prompt,
        model: model.providerModelId,
        audioBase64: audioBase64,
        baseUrl: provider.baseUrl,
        apiKey: provider.apiKey,
        provider: provider,
        maxCompletionTokens: model.maxCompletionTokens,
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
      // Determine tools based on response type and entity.
      // We keep the selection centralized via getChecklistToolsForProvider
      // so gating rules (Ollama + GPT‑OSS) stay consistent everywhere.
      List<ChatCompletionTool>? tools;

      // For checklistUpdates response type, always include function tools regardless of entity type
      // This is because checklist updates can be triggered from various contexts
      if (promptConfig.aiResponseType == AiResponseType.checklistUpdates &&
          model.supportsFunctionCalling) {
        const enableLabels = true;
        final checklistTools =
            getChecklistToolsForProvider(provider: provider, model: model);
        tools = [
          ...checklistTools,
          if (enableLabels) ...LabelFunctions.getTools(),
          ...TaskFunctions.getTools(),
        ];
        lottiDevLog(
          name: 'UnifiedAiInferenceRepository',
          message:
              'Including checklist and task tools for checklistUpdates response type. '
              'Checklist tools: ${checklistTools.map((t) => t.function.name).join(', ')} '
              'for provider=${provider.inferenceProviderType} model=${model.providerModelId}',
        );
      }
      // For task summary, no longer include function tools (they're handled separately now)
      else if (promptConfig.aiResponseType == AiResponseType.taskSummary) {
        tools = null;
        developer.log(
          'Task summary processing without function tools (functions handled separately)',
          name: 'UnifiedAiInferenceRepository',
        );
      }
      // Legacy behavior for other cases (should not happen in practice)
      else if (entity is Task && model.supportsFunctionCalling) {
        final checklistTools =
            getChecklistToolsForProvider(provider: provider, model: model);
        tools = [
          ...checklistTools,
          ...TaskFunctions.getTools(),
        ];
        lottiDevLog(
          name: 'UnifiedAiInferenceRepository',
          message:
              'Including checklist completion and task tools for task ${entity.id} with model ${model.providerModelId}. '
              'Checklist tools: ${checklistTools.map((t) => t.function.name).join(', ')}',
        );
      } else {
        developer.log(
          'NOT including tools - entity is Task: ${entity is Task}, supportsFunctionCalling: ${model.supportsFunctionCalling}',
          name: 'UnifiedAiInferenceRepository',
        );
      }

      return cloudRepo.generate(
        prompt,
        model: model.providerModelId,
        temperature: temperature,
        baseUrl: provider.baseUrl,
        apiKey: provider.apiKey,
        systemMessage: systemMessage,
        maxCompletionTokens: model.maxCompletionTokens,
        provider: provider,
        tools: tools,
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
  }) async {
    var thoughts = '';
    var cleanResponse = response;

    // Extract thoughts if present (for reasoning models)
    if (response.contains('</think>')) {
      final parts = response.split('</think>');
      if (parts.length == 2) {
        thoughts = parts[0];
        cleanResponse = parts[1];
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
    final data = AiResponseData(
      model: model.providerModelId,
      temperature: 0.6,
      systemMessage: promptConfig.systemMessage,
      prompt: prompt,
      promptId: promptConfig.id,
      thoughts: thoughts,
      response: cleanResponse,
      type: promptConfig.aiResponseType,
    );

    // Save the AI response entry (except for checklist updates which are function-only)
    AiResponseEntry? aiResponseEntry;
    if (entity is! JournalAudio &&
        entity is! JournalImage &&
        promptConfig.aiResponseType != AiResponseType.checklistUpdates) {
      try {
        aiResponseEntry =
            await ref.read(aiInputRepositoryProvider).createAiResponseEntry(
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
    } else if (promptConfig.aiResponseType == AiResponseType.checklistUpdates) {
      developer.log(
        'Skipping AI response entry creation for checklistUpdates (function-only response)',
        name: 'UnifiedAiInferenceRepository',
      );
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
      case AiResponseType.checklistUpdates:
        // For checklist updates, we only process function calls, no text response
        // The function calls have already been processed at this point
        developer.log(
          'Checklist updates completed (function calls only, no text response to save)',
          name: 'UnifiedAiInferenceRepository',
        );
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
          final amendedText =
              originalText.isEmpty ? response : '$originalText\n\n$response';

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

            // Trigger smart task summary if image is linked to a task
            final linkedTask = await _getTaskForEntity(entity);
            if (linkedTask != null) {
              developer.log(
                'Triggering smart task summary for task ${linkedTask.id} after image analysis',
                name: 'UnifiedAiInferenceRepository',
              );
              await ref
                  .read(smartTaskSummaryTriggerProvider)
                  .triggerTaskSummary(
                    taskId: linkedTask.id,
                    categoryId: linkedTask.meta.categoryId,
                  );
            }
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
            // which respects the user's enableTaskSummary checkbox preference.
            // See lib/features/speech/helpers/automatic_prompt_trigger.dart
          } catch (e) {
            developer.log(
              'Failed to update audio transcription for audio ${entity.id}',
              name: 'UnifiedAiInferenceRepository',
              error: e,
            );
          }
        }
      case AiResponseType.taskSummary:
        if (entity is Task) {
          // Get current task state to avoid overwriting concurrent changes
          final currentTask =
              await EntityStateHelper.getCurrentEntityState<Task>(
            entityId: entity.id,
            aiInputRepo: ref.read(aiInputRepositoryProvider),
            entityTypeName: 'task summary',
          );
          if (currentTask == null) {
            break;
          }

          // Extract title from response (H1 markdown format)
          final titleRegex = RegExp(r'^#\s+(.+)$', multiLine: true);
          final titleMatch = titleRegex.firstMatch(response);

          if (titleMatch != null) {
            final suggestedTitle = titleMatch.group(1)?.trim();
            final currentTitle = currentTask.data.title;

            // Update title if current title is empty or very short (less than 5 characters)
            if (suggestedTitle != null &&
                suggestedTitle.isNotEmpty &&
                currentTitle.length < kMinExistingTitleLengthForAiSuggestion) {
              developer.log(
                'Updating task title from AI suggestion: "$currentTitle" -> "$suggestedTitle" for task ${entity.id}',
                name: 'UnifiedAiInferenceRepository',
              );

              final updated = currentTask.copyWith(
                data: currentTask.data.copyWith(
                  title: suggestedTitle,
                ),
              );

              try {
                await journalRepo.updateJournalEntity(updated);
                developer.log(
                  'Successfully updated task title for task ${entity.id}',
                  name: 'UnifiedAiInferenceRepository',
                );
              } catch (e) {
                developer.log(
                  'Failed to update task title for task ${entity.id}',
                  name: 'UnifiedAiInferenceRepository',
                  error: e,
                );
              }
            } else {
              developer.log(
                'Skipping task title update for task ${entity.id}: suggestedTitle="$suggestedTitle", currentTitle.length=${currentTitle.length}',
                name: 'UnifiedAiInferenceRepository',
              );
            }
          }
        }
      // ignore: deprecated_member_use_from_same_package
      case AiResponseType.actionItemSuggestions:
        developer.log(
          'Processing actionItemSuggestions is no longer supported',
          name: 'UnifiedAiInferenceRepository',
        );
    }
  }

  /// Process various tool calls including checklist operations and language detection
  /// Returns true if language was detected and set
  @visibleForTesting
  Future<bool> processToolCalls({
    required List<ChatCompletionMessageToolCall> toolCalls,
    required Task task,
  }) async {
    var languageWasSet = false;
    var currentTask = task; // Create mutable copy for updates
    developer.log(
      'Starting to process ${toolCalls.length} tool calls for checklist operations',
      name: 'UnifiedAiInferenceRepository',
    );

    // Log all tool calls for debugging
    for (var i = 0; i < toolCalls.length; i++) {
      final tc = toolCalls[i];
      developer.log(
        'Tool call [$i]: name=${tc.function.name}, '
        'args=${tc.function.arguments.length > 200 ? '${tc.function.arguments.substring(0, 200)}...' : tc.function.arguments}',
        name: 'UnifiedAiInferenceRepository',
      );
    }

    final suggestions = <ChecklistCompletionSuggestion>[];

    for (final toolCall in toolCalls) {
      developer.log(
        'Processing tool call: ${toolCall.function.name}',
        name: 'UnifiedAiInferenceRepository',
      );

      if (toolCall.function.name ==
          ChecklistCompletionFunctions.suggestChecklistCompletion) {
        // Handle case where multiple JSON objects might be concatenated
        final argumentsStr = toolCall.function.arguments;

        // Try to split multiple JSON objects if they're concatenated
        // This regex matches JSON objects by looking for balanced braces
        // NOTE: This manual parsing logic may fail if the reason field contains
        // unmatched { or } characters. This is a known limitation but should be
        // rare in practice since AI-generated reasons are typically well-formed.
        final jsonObjects = <String>[];
        var depth = 0;
        var start = -1;

        for (var i = 0; i < argumentsStr.length; i++) {
          if (argumentsStr[i] == '{') {
            if (depth == 0) {
              start = i;
            }
            depth++;
          } else if (argumentsStr[i] == '}') {
            depth--;
            if (depth == 0 && start != -1) {
              jsonObjects.add(argumentsStr.substring(start, i + 1));
              start = -1;
            }
          }
        }

        if (jsonObjects.isEmpty) {
          developer.log(
            'No valid JSON found in arguments: $argumentsStr',
            name: 'UnifiedAiInferenceRepository',
          );
          continue;
        }

        developer.log(
          'Found ${jsonObjects.length} JSON objects in arguments',
          name: 'UnifiedAiInferenceRepository',
        );

        for (final jsonStr in jsonObjects) {
          try {
            developer.log(
              'Parsing individual JSON: $jsonStr',
              name: 'UnifiedAiInferenceRepository',
            );

            final arguments = jsonDecode(jsonStr) as Map<String, dynamic>;
            final suggestion = ChecklistCompletionSuggestion(
              checklistItemId: arguments['checklistItemId'] as String,
              reason: arguments['reason'] as String,
              confidence: ChecklistCompletionConfidence.values.firstWhere(
                (e) => e.name == arguments['confidence'],
                orElse: () => ChecklistCompletionConfidence.low,
              ),
            );
            suggestions.add(suggestion);

            developer.log(
              'Created suggestion for item ${suggestion.checklistItemId} with confidence ${suggestion.confidence.name}',
              name: 'UnifiedAiInferenceRepository',
            );
          } catch (e) {
            developer.log(
              'Error parsing individual checklist completion JSON: $e',
              name: 'UnifiedAiInferenceRepository',
              error: e,
            );
          }
        }
      } else if (toolCall.function.name ==
          ChecklistCompletionFunctions.addMultipleChecklistItems) {
        // Handle add checklist item(s)
        try {
          final arguments =
              jsonDecode(toolCall.function.arguments) as Map<String, dynamic>;

          // Array-of-objects only
          final itemsField = arguments['items'];
          if (itemsField is! List) {
            developer.log(
              'Invalid or missing items for add_multiple_checklist_items',
              name: 'UnifiedAiInferenceRepository',
            );
            continue;
          }

          final sanitized = ChecklistValidation.validateItems(itemsField);

          if (!ChecklistValidation.isValidBatchSize(sanitized.length)) {
            developer.log(
              ChecklistValidation.getBatchSizeErrorMessage(sanitized.length),
              name: 'UnifiedAiInferenceRepository',
            );
            continue;
          }

          developer.log(
            'Processing ${sanitized.length} checklist items (array-of-objects)',
            name: 'UnifiedAiInferenceRepository',
          );

          // Process each item
          for (final item in sanitized) {
            developer.log(
              'Adding checklist item: ${item.title} (isChecked=${item.isChecked})',
              name: 'UnifiedAiInferenceRepository',
            );

            // Check if task has existing checklists
            final checklistIds = currentTask.data.checklistIds ?? [];

            if (checklistIds.isEmpty) {
              // Create a new "to-do" checklist with the item
              developer.log(
                'No existing checklists found, creating new "to-do" checklist',
                name: 'UnifiedAiInferenceRepository',
              );

              final result = await autoChecklistService.autoCreateChecklist(
                taskId: currentTask.id,
                suggestions: [
                  ChecklistItemData(
                    title: item.title,
                    isChecked: item.isChecked,
                    linkedChecklists: [],
                  ),
                ],
                title: 'TODOs',
              );

              if (result.success) {
                developer.log(
                  'Created new checklist ${result.checklistId} with item',
                  name: 'UnifiedAiInferenceRepository',
                );

                // Refresh the task to get the updated checklistIds
                final journalDb = getIt<JournalDb>();
                final updatedEntity =
                    await journalDb.journalEntityById(currentTask.id);
                if (updatedEntity is Task) {
                  currentTask = updatedEntity;
                  developer.log(
                    'Refreshed task, now has ${currentTask.data.checklistIds?.length ?? 0} checklists',
                    name: 'UnifiedAiInferenceRepository',
                  );
                } else {
                  // The task should exist since we just created a checklist for it.
                  // If not, it was likely deleted concurrently. Stop processing to avoid further errors.
                  developer.log(
                    'Failed to refresh task ${currentTask.id} after creating checklist. It might have been deleted concurrently.',
                    name: 'UnifiedAiInferenceRepository',
                    level: 1000, // SEVERE
                  );
                  break;
                }
              } else {
                developer.log(
                  'Failed to create checklist: ${result.error}',
                  name: 'UnifiedAiInferenceRepository',
                );
              }
            } else {
              // Add item to the first existing checklist using atomic operation
              final checklistId = checklistIds.first;
              developer.log(
                'Adding item to existing checklist: $checklistId',
                name: 'UnifiedAiInferenceRepository',
              );

              final checklistRepository = ref.read(checklistRepositoryProvider);
              final newItem = await checklistRepository.addItemToChecklist(
                checklistId: checklistId,
                title: item.title,
                isChecked: item.isChecked,
                categoryId: currentTask.meta.categoryId,
              );

              if (newItem != null) {
                developer.log(
                  'Successfully added item ${newItem.id} to checklist',
                  name: 'UnifiedAiInferenceRepository',
                );
              }
            }
          }

          // Force refresh of checklists UI
          ref.invalidate(checklistItemControllerProvider);
        } catch (e) {
          developer.log(
            'Error processing add checklist item(s): $e',
            name: 'UnifiedAiInferenceRepository',
            error: e,
          );
        }
      } else if (toolCall.function.name ==
          ChecklistCompletionFunctions.updateChecklistItems) {
        try {
          final updateHandler = LottiChecklistUpdateHandler(
            task: currentTask,
            checklistRepository: ref.read(checklistRepositoryProvider),
            onTaskUpdated: (Task updatedTask) {
              currentTask = updatedTask;
            },
          );

          final result = updateHandler.processFunctionCall(toolCall);

          if (!result.success) {
            developer.log(
              'Invalid update_checklist_items call: ${result.error}',
              name: 'UnifiedAiInferenceRepository',
            );
            continue;
          }

          final count = await updateHandler.executeUpdates(result);

          developer.log(
            'Updated $count checklist items, '
            'skipped ${updateHandler.skippedItems.length}',
            name: 'UnifiedAiInferenceRepository',
          );

          ref.invalidate(checklistItemControllerProvider);
        } catch (e, stackTrace) {
          developer.log(
            'Error processing update_checklist_items: $e',
            name: 'UnifiedAiInferenceRepository',
            error: e,
            stackTrace: stackTrace,
          );
        }
      } else if (toolCall.function.name == TaskFunctions.setTaskLanguage) {
        // Handle set task language
        try {
          final result = SetTaskLanguageResult.fromJson(
            jsonDecode(toolCall.function.arguments) as Map<String, dynamic>,
          );
          final languageCode = result.languageCode;
          final confidence = result.confidence.name;
          final reason = result.reason;

          developer.log(
            'Setting task language to: $languageCode (confidence: $confidence, reason: $reason)',
            name: 'UnifiedAiInferenceRepository',
          );

          // Re-fetch the task to get the latest state and avoid race conditions
          final journalRepo = ref.read(journalRepositoryProvider);
          final freshEntity =
              await journalRepo.getJournalEntityById(currentTask.id);

          if (freshEntity is! Task) {
            developer.log(
              'Task ${currentTask.id} not found or is not a Task anymore, skipping language update',
              name: 'UnifiedAiInferenceRepository',
            );
            continue;
          }

          final freshTask = freshEntity;

          // Only set language if task doesn't already have one
          if (freshTask.data.languageCode == null) {
            final updated = freshTask.copyWith(
              data: freshTask.data.copyWith(
                languageCode: languageCode,
              ),
            );

            try {
              await journalRepo.updateJournalEntity(updated);
              developer.log(
                'Successfully set task language to $languageCode for task ${currentTask.id}',
                name: 'UnifiedAiInferenceRepository',
              );
              languageWasSet = true;
            } catch (e) {
              developer.log(
                'Failed to update task language for task ${currentTask.id}',
                name: 'UnifiedAiInferenceRepository',
                error: e,
              );
            }
          } else {
            developer.log(
              'Task ${currentTask.id} already has language set to ${freshTask.data.languageCode}, not overwriting',
              name: 'UnifiedAiInferenceRepository',
            );
          }
        } catch (e) {
          developer.log(
            'Error processing set task language: $e',
            name: 'UnifiedAiInferenceRepository',
            error: e,
          );
        }
      } else if (toolCall.function.name == LabelFunctions.assignTaskLabels) {
        // Handle assign task labels (add-only)
        try {
          final parsed = parseLabelCallArgs(toolCall.function.arguments);
          final requested =
              LinkedHashSet<String>.from(parsed.selectedIds).toList();

          // Phase 3: filter suppressed IDs for this task (hard filter)
          final suppressedSet =
              currentTask.data.aiSuppressedLabelIds ?? const <String>{};
          final proposed =
              requested.where((id) => !suppressedSet.contains(id)).toList();

          final processor = LabelAssignmentProcessor(
            repository: ref.read(labelsRepositoryProvider),
          );

          // Short-circuit if everything was suppressed
          if (proposed.isEmpty && requested.isNotEmpty) {
            final skipped = requested
                .where(suppressedSet.contains)
                .map((id) => {'id': id, 'reason': 'suppressed'})
                .toList();
            final noop = LabelAssignmentResult(
              assigned: const [],
              invalid: const [],
              skipped: skipped,
            );
            try {
              final response = noop.toStructuredJson(requested);
              developer.log(
                'assign_task_labels suppressed-only: $response',
                name: 'UnifiedAiInferenceRepository',
              );
            } catch (_) {
              // best-effort logging
            }
            continue;
          }
          final result = await processor.processAssignment(
            taskId: currentTask.id,
            proposedIds: proposed,
            existingIds: currentTask.meta.labelIds ?? const <String>[],
            categoryId: currentTask.meta.categoryId,
            droppedLow: parsed.droppedLow,
            legacyUsed: parsed.legacyUsed,
            confidenceBreakdown: parsed.confidenceBreakdown,
            totalCandidates: parsed.totalCandidates,
          );
          // Log structured result for debugging
          try {
            developer.log(
              'assign_task_labels result: ${result.toStructuredJson(requested)}',
              name: 'UnifiedAiInferenceRepository',
            );
          } catch (_) {
            // best-effort logging
          }
        } catch (e) {
          developer.log(
            'Error processing assign_task_labels: $e',
            name: 'UnifiedAiInferenceRepository',
            error: e,
          );
        }
      } else {
        developer.log(
          'Skipping unknown tool call: ${toolCall.function.name}',
          name: 'UnifiedAiInferenceRepository',
        );
      }
    }

    if (suggestions.isNotEmpty) {
      developer.log(
        'About to store ${suggestions.length} suggestions:',
        name: 'UnifiedAiInferenceRepository',
      );

      for (final suggestion in suggestions) {
        developer.log(
          '  - Item ${suggestion.checklistItemId}: ${suggestion.reason} (${suggestion.confidence.name})',
          name: 'UnifiedAiInferenceRepository',
        );
      }

      // Store suggestions in the service
      ref
          .read(checklistCompletionServiceProvider.notifier)
          .addSuggestions(suggestions);

      // Auto-check items with high confidence
      final checklistRepository = ref.read(checklistRepositoryProvider);
      final journalRepository = ref.read(journalRepositoryProvider);

      for (final suggestion in suggestions) {
        if (suggestion.confidence == ChecklistCompletionConfidence.high) {
          developer.log(
            'Auto-checking item ${suggestion.checklistItemId} due to high confidence',
            name: 'UnifiedAiInferenceRepository',
          );

          try {
            // Get the current checklist item
            final checklistItem = await journalRepository
                .getJournalEntityById(suggestion.checklistItemId);

            if (checklistItem is ChecklistItem) {
              if (!checklistItem.data.isChecked) {
                // Update the item to be checked
                await checklistRepository.updateChecklistItem(
                  checklistItemId: suggestion.checklistItemId,
                  data: checklistItem.data.copyWith(isChecked: true),
                  taskId: currentTask.id,
                );

                developer.log(
                  'Successfully auto-checked item ${suggestion.checklistItemId}',
                  name: 'UnifiedAiInferenceRepository',
                );
              } else {
                developer.log(
                  'Skipping auto-check for item ${suggestion.checklistItemId} - already checked',
                  name: 'UnifiedAiInferenceRepository',
                );
              }
            }
          } catch (e) {
            developer.log(
              'Error auto-checking item ${suggestion.checklistItemId}: $e',
              name: 'UnifiedAiInferenceRepository',
              error: e,
            );
          }
        }
      }

      // Force refresh of all checklist items in this task
      // This will cause the UI to re-check for suggestions
      ref.invalidate(checklistItemControllerProvider);

      developer.log(
        'Processed ${suggestions.length} checklist completion suggestions for task ${currentTask.id}',
        name: 'UnifiedAiInferenceRepository',
      );
    } else {
      developer.log(
        'No suggestions to process after parsing tool calls',
        name: 'UnifiedAiInferenceRepository',
      );
    }

    return languageWasSet;
  }

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

  /// Process checklist updates using conversation approach for better batching
  Future<void> _processWithConversation({
    required String prompt,
    required JournalEntity entity,
    required AiConfigPrompt promptConfig,
    required AiConfigModel model,
    required AiConfigInferenceProvider provider,
    required String systemMessage,
    required void Function(String) onProgress,
    required void Function(InferenceStatus) onStatusChange,
    required DateTime start,
    required bool isRerun,
  }) async {
    developer.log(
      'Starting conversation-based processing for ${entity.runtimeType}',
      name: 'UnifiedAiInferenceRepository',
    );

    // Get the task for this entity
    final task = await _getTaskForEntity(entity);
    if (task == null) {
      developer.log(
        'No task found for entity ${entity.id}, falling back to regular processing',
        name: 'UnifiedAiInferenceRepository',
      );
      // Fall back to regular processing
      await _runInferenceInternal(
        entityId: entity.id,
        promptConfig: promptConfig,
        onProgress: onProgress,
        onStatusChange: onStatusChange,
        isRerun: isRerun,
        entity: entity,
      );
      return;
    }

    try {
      // Create conversation processor
      final processor = LottiConversationProcessor(ref: ref);

      // Get the appropriate inference repository based on provider type
      InferenceRepositoryInterface inferenceRepo;

      if (provider.inferenceProviderType == InferenceProviderType.ollama) {
        developer.log(
          'Using OllamaInferenceRepository for conversation approach',
          name: 'UnifiedAiInferenceRepository',
        );
        inferenceRepo = ref.read(ollamaInferenceRepositoryProvider);
      } else {
        developer.log(
          'Using CloudInferenceWrapper for ${provider.inferenceProviderType} provider',
          name: 'UnifiedAiInferenceRepository',
        );
        final cloudRepo = ref.read(cloudInferenceRepositoryProvider);
        inferenceRepo = CloudInferenceWrapper(cloudRepository: cloudRepo);
      }

      // Define tools for checklist updates
      const enableLabels = true;
      final checklistTools =
          getChecklistToolsForProvider(provider: provider, model: model);
      final tools = [
        ...checklistTools,
        if (enableLabels) ...LabelFunctions.getTools(),
        ...TaskFunctions.getTools(),
      ];

      lottiDevLog(
        name: 'UnifiedAiInferenceRepository',
        message:
            'Conversation tool set. Checklist tools: ${checklistTools.map((t) => t.function.name).join(', ')} '
            'for provider=${provider.inferenceProviderType} model=${model.providerModelId}',
      );

      // Process with conversation
      final result = await processor.processPromptWithConversation(
        prompt: prompt,
        entity: entity,
        task: task,
        model: model,
        provider: provider,
        promptConfig: promptConfig,
        systemMessage: systemMessage,
        tools: tools,
        inferenceRepo: inferenceRepo,
      );

      // Update progress with final result
      onProgress(result.responseText);

      // Handle the result
      developer.log(
        'Conversation processing completed: ${result.totalCreated} items created, '
        'duration: ${result.duration.inMilliseconds}ms, errors: ${result.hadErrors}',
        name: 'UnifiedAiInferenceRepository',
      );

      // Update status to idle or error
      if (result.hadErrors) {
        onStatusChange(InferenceStatus.error);
      } else {
        onStatusChange(InferenceStatus.idle);
      }

      // Log the response but don't create visible entry for checklist updates
      developer.log(
        'Checklist updates completed via conversation: ${result.totalCreated} items',
        name: 'UnifiedAiInferenceRepository',
      );

      // Force refresh of checklists UI
      ref.invalidate(checklistItemControllerProvider);
    } catch (e) {
      developer.log(
        'Error in conversation processing: $e',
        name: 'UnifiedAiInferenceRepository',
        error: e,
      );
      onStatusChange(InferenceStatus.error);
      onProgress('Error: $e');
    }
  }
}

@riverpod
UnifiedAiInferenceRepository unifiedAiInferenceRepository(Ref ref) {
  return UnifiedAiInferenceRepository(ref);
}
