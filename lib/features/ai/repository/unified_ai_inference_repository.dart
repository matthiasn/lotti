import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/functions/checklist_completion_functions.dart';
import 'package:lotti/features/ai/helpers/entity_state_helper.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/ai_input.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/services/auto_checklist_service.dart';
import 'package:lotti/features/ai/services/checklist_completion_service.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/features/tasks/state/checklist_item_controller.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'unified_ai_inference_repository.g.dart';

/// Minimum title length for AI suggestion to be applied
const kMinExistingTitleLengthForAiSuggestion = 5;

/// Regular expression to remove problematic characters from checklist item titles
/// Only removes leading/trailing dashes and asterisks which are often markdown artifacts
final _invalidChecklistItemTitleChars = RegExp(r'^[-*\s]+|[-*\s]+$');

/// Repository for unified AI inference handling
/// This replaces the specialized controllers and provides a generic way
/// to run any configured AI prompt
class UnifiedAiInferenceRepository {
  UnifiedAiInferenceRepository(this.ref);

  final Ref ref;
  AutoChecklistService? _autoChecklistService;

  // Track tasks that are currently auto-creating checklists to prevent duplicates
  final Set<String> _autoCreatingTasks = {};

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

    return activePrompts;
  }

  /// Check if a prompt is active for a given entity type
  Future<bool> _isPromptActiveForEntity(
    AiConfigPrompt prompt,
    JournalEntity entity,
  ) async {
    // Check if prompt requires specific input data types
    final hasTask = prompt.requiredInputData.contains(InputDataType.task);
    final hasImages = prompt.requiredInputData.contains(InputDataType.images);
    final hasAudio =
        prompt.requiredInputData.contains(InputDataType.audioFiles);

    // For prompts that require task context
    if (hasTask) {
      if (entity is Task) {
        // Direct task entity - always valid
        return hasImages == false && hasAudio == false;
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
  }) async {
    await _runInferenceInternal(
      entityId: entityId,
      promptConfig: promptConfig,
      onProgress: onProgress,
      onStatusChange: onStatusChange,
      isRerun: false,
    );
  }

  /// Internal inference method with rerun flag to prevent recursive auto-creation
  Future<void> _runInferenceInternal({
    required String entityId,
    required AiConfigPrompt promptConfig,
    required void Function(String) onProgress,
    required void Function(InferenceStatus) onStatusChange,
    required bool isRerun,
  }) async {
    final start = DateTime.now();

    try {
      onStatusChange(InferenceStatus.running);

      // Get the entity
      final entity =
          await ref.read(aiInputRepositoryProvider).getEntity(entityId);
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
      final prompt = await _buildPromptWithData(
        promptConfig: promptConfig,
        entity: entity,
      );

      if (prompt == null) {
        throw Exception('Failed to build prompt');
      }

      // Prepare any additional data (images, audio)
      final images = await _prepareImages(promptConfig, entity);
      final audioBase64 = await _prepareAudio(promptConfig, entity);

      // Run the inference
      final buffer = StringBuffer();
      final stream = await _runCloudInference(
        prompt: prompt,
        model: model,
        provider: provider,
        images: images,
        audioBase64: audioBase64,
        temperature: 0.6,
        systemMessage: promptConfig.systemMessage,
        entity: entity,
      );

      // Process the stream and accumulate tool calls
      final toolCallAccumulator = <String, Map<String, dynamic>>{};
      var toolCallCounter = 0;

      await for (final chunk in stream) {
        final text = _extractTextFromChunk(chunk);
        buffer.write(text);
        onProgress(buffer.toString());

        // Accumulate tool calls from chunks
        if (chunk.choices.isNotEmpty) {
          final delta = chunk.choices.first.delta;
          if (delta?.toolCalls != null) {
            developer.log(
              'Received tool call chunk with ${delta!.toolCalls!.length} tool calls',
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

  /// Build prompt with entity data
  Future<String?> _buildPromptWithData({
    required AiConfigPrompt promptConfig,
    required JournalEntity entity,
  }) async {
    final aiInputRepo = ref.read(aiInputRepositoryProvider);
    var prompt = promptConfig.userMessage;

    // Check if prompt contains {{task}} placeholder
    if (prompt.contains('{{task}}')) {
      // Handle different entity types that might need task context
      if (entity is JournalImage || entity is JournalAudio) {
        // For images and audio, check if they are linked to a task
        final journalRepo = ref.read(journalRepositoryProvider);
        final linkedFromEntities = await journalRepo.getLinkedToEntities(
          linkedTo: entity.id,
        );

        // Find if any linked entity is a task
        final linkedTask = linkedFromEntities.firstWhereOrNull(
          (entity) => entity is Task,
        ) as Task?;

        if (linkedTask != null) {
          // Get task context and replace {{task}} placeholder
          final taskJson =
              await aiInputRepo.buildTaskDetailsJson(id: linkedTask.id);
          if (taskJson != null) {
            prompt = prompt.replaceAll('{{task}}', taskJson);
          }
        }
        // If no linked task, leave the prompt as is (with {{task}} placeholder)
        // The AI will handle it gracefully
      } else if (entity is Task) {
        // For task entities, directly replace the placeholder
        final taskJson = await aiInputRepo.buildTaskDetailsJson(id: entity.id);
        if (taskJson != null) {
          prompt = prompt.replaceAll('{{task}}', taskJson);
        }
      }
    } else if (promptConfig.requiredInputData.contains(InputDataType.task) &&
        entity is Task) {
      // For prompts that require task data but don't use {{task}} placeholder
      // (legacy support for summaries, action items)
      final jsonString = await aiInputRepo.buildTaskDetailsJson(id: entity.id);
      prompt = '${promptConfig.userMessage} \n $jsonString';
    }

    return prompt;
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
  }) async {
    final cloudRepo = ref.read(cloudInferenceRepositoryProvider);

    if (audioBase64 != null) {
      // Include checklist completion tools if processing audio linked to a task with function calling support
      List<ChatCompletionTool>? tools;

      // Check if this is audio linked to a task
      Task? linkedTask;
      if (entity is JournalAudio && model.supportsFunctionCalling) {
        linkedTask = await _getTaskForEntity(entity);

        if (linkedTask != null) {
          tools = ChecklistCompletionFunctions.getTools();
          developer.log(
            'Including checklist completion tools for audio transcription linked to task ${linkedTask.id}',
            name: 'UnifiedAiInferenceRepository',
          );
        }
      } else if (entity is Task && model.supportsFunctionCalling) {
        tools = ChecklistCompletionFunctions.getTools();
        developer.log(
          'Including checklist completion tools for audio transcription of task ${entity.id}',
          name: 'UnifiedAiInferenceRepository',
        );
      }

      return cloudRepo.generateWithAudio(
        prompt,
        model: model.providerModelId,
        audioBase64: audioBase64,
        baseUrl: provider.baseUrl,
        apiKey: provider.apiKey,
        provider: provider,
        maxCompletionTokens: model.maxCompletionTokens,
        tools: tools,
      );
    } else if (images.isNotEmpty) {
      // Include checklist completion tools if processing image linked to a task with function calling support
      List<ChatCompletionTool>? tools;

      // Check if this is image linked to a task
      Task? linkedTask;
      if (entity is JournalImage && model.supportsFunctionCalling) {
        linkedTask = await _getTaskForEntity(entity);

        if (linkedTask != null) {
          tools = ChecklistCompletionFunctions.getTools();
          developer.log(
            'Including checklist completion tools for image analysis linked to task ${linkedTask.id}',
            name: 'UnifiedAiInferenceRepository',
          );
        }
      } else if (entity is Task && model.supportsFunctionCalling) {
        tools = ChecklistCompletionFunctions.getTools();
        developer.log(
          'Including checklist completion tools for image analysis of task ${entity.id}',
          name: 'UnifiedAiInferenceRepository',
        );
      }

      return cloudRepo.generateWithImages(
        prompt,
        model: model.providerModelId,
        temperature: temperature,
        images: images,
        baseUrl: provider.baseUrl,
        apiKey: provider.apiKey,
        provider: provider,
        maxCompletionTokens: model.maxCompletionTokens,
        tools: tools,
      );
    } else {
      // Include checklist completion tools if processing a task with function calling support
      List<ChatCompletionTool>? tools;
      if (entity is Task && model.supportsFunctionCalling) {
        tools = ChecklistCompletionFunctions.getTools();
        developer.log(
          'Including checklist completion tools for task ${entity.id} with model ${model.providerModelId}',
          name: 'UnifiedAiInferenceRepository',
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
        tools: tools,
      );
    }
  }

  /// Extract text from stream chunk
  String _extractTextFromChunk(CreateChatCompletionStreamResponse chunk) {
    try {
      // Handle potential null values in Anthropic's response
      final choices = chunk.choices;
      if (choices.isEmpty) {
        return '';
      }
      return choices.firstOrNull?.delta?.content ?? '';
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

    // Parse action items if this is an action item suggestions prompt
    List<AiActionItem>? suggestedActionItems;
    if (promptConfig.aiResponseType == AiResponseType.actionItemSuggestions) {
      try {
        final exp = RegExp(r'\[(.|\n)*\]', multiLine: true);
        final match = exp.firstMatch(cleanResponse)?.group(0) ?? '[]';
        final actionItemsJson = '{"items": $match}';
        final decoded = jsonDecode(actionItemsJson) as Map<String, dynamic>;
        suggestedActionItems = AiInputActionItemsList.fromJson(decoded).items;
      } catch (e) {
        // Failed to parse action items, continue without them
      }
    }

    // Process tool calls for checklist completions
    final taskForToolCalls = await _getTaskForEntity(entity);

    if (toolCalls != null && toolCalls.isNotEmpty && taskForToolCalls != null) {
      developer.log(
        'Processing ${toolCalls.length} tool calls for task ${taskForToolCalls.id} (from ${entity.runtimeType})',
        name: 'UnifiedAiInferenceRepository',
      );
      await _processChecklistToolCalls(
        toolCalls: toolCalls,
        task: taskForToolCalls,
      );
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
      suggestedActionItems: suggestedActionItems,
      type: promptConfig.aiResponseType,
    );

    // Save the AI response entry
    AiResponseEntry? aiResponseEntry;
    if (entity is! JournalAudio && entity is! JournalImage) {
      try {
        aiResponseEntry =
            await ref.read(aiInputRepositoryProvider).createAiResponseEntry(
                  data: data,
                  start: start,
                  linkedId: entity.id,
                  categoryId: entity is Task ? entity.categoryId : null,
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
      'About to call _handlePostProcessing. entity: ${entity.runtimeType}, suggestedActionItems: ${suggestedActionItems?.length ?? 0}, promptConfig.aiResponseType: ${promptConfig.aiResponseType}',
      name: 'UnifiedAiInferenceRepository',
    );

    await _handlePostProcessing(
      entity: entity,
      promptConfig: promptConfig,
      response: cleanResponse,
      model: model,
      provider: provider,
      start: start,
      suggestedActionItems: suggestedActionItems,
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
    List<AiActionItem>? suggestedActionItems,
    AiResponseEntry? aiResponseEntry,
  }) async {
    final journalRepo = ref.read(journalRepositoryProvider);

    switch (promptConfig.aiResponseType) {
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
      case AiResponseType.actionItemSuggestions:
        developer.log(
          'Processing actionItemSuggestions. entity is Task: ${entity is Task}, suggestedActionItems: ${suggestedActionItems?.length ?? 0} items, aiResponseEntry: ${aiResponseEntry?.id ?? "null"}',
          name: 'UnifiedAiInferenceRepository',
        );
        if (entity is Task &&
            suggestedActionItems != null &&
            suggestedActionItems.isNotEmpty &&
            !isRerun) {
          // Get current task state to avoid using stale data
          final currentTask =
              await EntityStateHelper.getCurrentEntityState<Task>(
            entityId: entity.id,
            aiInputRepo: ref.read(aiInputRepositoryProvider),
            entityTypeName: 'action item suggestions',
          );
          if (currentTask == null) {
            return;
          }
          // Don't auto-create on re-runs
          await _handleActionItemSuggestions(
              currentTask, suggestedActionItems, aiResponseEntry, promptConfig);
        } else {
          developer.log(
            'Skipping _handleActionItemSuggestions - conditions not met',
            name: 'UnifiedAiInferenceRepository',
          );
        }
    }
  }

  /// Handle action item suggestions post-processing
  Future<void> _handleActionItemSuggestions(
    Task task,
    List<AiActionItem> suggestedActionItems,
    AiResponseEntry? aiResponseEntry,
    AiConfigPrompt promptConfig,
  ) async {
    try {
      developer.log(
        '_handleActionItemSuggestions called for task ${task.id} with ${suggestedActionItems.length} suggestions. aiResponseEntry: ${aiResponseEntry?.id ?? "null"}',
        name: 'UnifiedAiInferenceRepository',
      );

      // Check if this task is already being processed to prevent concurrent auto-creation
      if (_autoCreatingTasks.contains(task.id)) {
        developer.log(
          'Task ${task.id} is already being processed for auto-checklist creation, skipping',
          name: 'UnifiedAiInferenceRepository',
        );
        return;
      }

      // Check if auto-creation should happen
      final shouldAutoCreate =
          await autoChecklistService.shouldAutoCreate(taskId: task.id);

      developer.log(
        'shouldAutoCreate result: $shouldAutoCreate',
        name: 'UnifiedAiInferenceRepository',
      );

      if (shouldAutoCreate) {
        // Mark this task as being processed and ensure it's cleaned up
        _autoCreatingTasks.add(task.id);
        try {
          // Convert AI action items to checklist items
          final checklistItems = suggestedActionItems.map((item) {
            final title = item.title
                .replaceAll(_invalidChecklistItemTitleChars, '')
                .trim();
            return ChecklistItemData(
              title: title,
              isChecked: item.completed,
              linkedChecklists: [],
            );
          }).toList();

          // Auto-create checklist with all suggestions
          // Pass shouldAutoCreate as true since we already checked it above
          final result = await autoChecklistService.autoCreateChecklist(
            taskId: task.id,
            suggestions: checklistItems,
            shouldAutoCreate: true,
          );

          if (result.success) {
            developer.log(
              'Auto-created checklist with ${checklistItems.length} items, re-running AI suggestions prompt',
              name: 'UnifiedAiInferenceRepository',
            );

            // Re-run the same AI suggestions prompt to get updated suggestions
            // that account for the newly created checklist
            await _rerunActionItemSuggestions(task, promptConfig);
          } else {
            developer.log(
              'Failed to auto-create checklist: ${result.error}',
              name: 'UnifiedAiInferenceRepository',
              error: result.error,
            );
          }
        } finally {
          // Always remove task from processing set, even if errors occur
          _autoCreatingTasks.remove(task.id);
        }
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error in action item suggestions post-processing',
        name: 'UnifiedAiInferenceRepository',
        error: e,
        stackTrace: stackTrace,
      );
      // Don't rethrow - this is post-processing, main inference should not fail
    }
  }

  /// Re-run the same action item suggestions prompt after auto-checklist creation
  /// This generates new suggestions that account for the existing checklist
  Future<void> _rerunActionItemSuggestions(
      Task task, AiConfigPrompt originalPrompt) async {
    try {
      developer.log(
        'Re-running action item suggestions for task ${task.id} with original prompt ${originalPrompt.id}',
        name: 'UnifiedAiInferenceRepository',
      );

      // Re-run the inference with the exact same prompt that was used originally
      // This will generate new suggestions based on current task state (with checklist)
      await _runInferenceInternal(
        entityId: task.id,
        promptConfig: originalPrompt,
        onProgress: (_) {}, // Silent re-run, no progress updates
        onStatusChange: (_) {}, // Silent re-run, no status updates
        isRerun: true, // Prevent auto-checklist creation on re-run
      );

      developer.log(
        'Successfully re-ran action item suggestions prompt',
        name: 'UnifiedAiInferenceRepository',
      );
    } catch (e) {
      developer.log(
        'Failed to re-run action item suggestions: $e',
        name: 'UnifiedAiInferenceRepository',
        error: e,
      );
    }
  }

  /// Process tool calls for checklist operations (completion suggestions and item additions)
  Future<void> _processChecklistToolCalls({
    required List<ChatCompletionMessageToolCall> toolCalls,
    required Task task,
  }) async {
    developer.log(
      'Starting to process ${toolCalls.length} tool calls for checklist operations',
      name: 'UnifiedAiInferenceRepository',
    );

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
          ChecklistCompletionFunctions.addChecklistItem) {
        // Handle add checklist item
        try {
          final arguments =
              jsonDecode(toolCall.function.arguments) as Map<String, dynamic>;
          final actionItemDescription =
              arguments['actionItemDescription'] as String;

          developer.log(
            'Adding checklist item: $actionItemDescription',
            name: 'UnifiedAiInferenceRepository',
          );

          // Check if task has existing checklists
          final checklistIds = task.data.checklistIds ?? [];

          if (checklistIds.isEmpty) {
            // Create a new "to-do" checklist with the item
            developer.log(
              'No existing checklists found, creating new "to-do" checklist',
              name: 'UnifiedAiInferenceRepository',
            );

            final result = await autoChecklistService.autoCreateChecklist(
              taskId: task.id,
              suggestions: [
                ChecklistItemData(
                  title: actionItemDescription,
                  isChecked: false,
                  linkedChecklists: [],
                ),
              ],
              title: 'to-do',
            );

            if (result.success) {
              developer.log(
                'Created new checklist ${result.checklistId} with item',
                name: 'UnifiedAiInferenceRepository',
              );
            } else {
              developer.log(
                'Failed to create checklist: ${result.error}',
                name: 'UnifiedAiInferenceRepository',
              );
            }
          } else {
            // Add item to the first existing checklist
            final checklistId = checklistIds.first;
            developer.log(
              'Adding item to existing checklist: $checklistId',
              name: 'UnifiedAiInferenceRepository',
            );

            final checklistRepository = ref.read(checklistRepositoryProvider);
            final newItem = await checklistRepository.createChecklistItem(
              checklistId: checklistId,
              title: actionItemDescription,
              isChecked: false,
              categoryId: task.meta.categoryId,
            );

            if (newItem != null) {
              // Update the checklist to include the new item
              final checklist = await ref
                  .read(journalRepositoryProvider)
                  .getJournalEntityById(checklistId);

              if (checklist is Checklist) {
                await checklistRepository.updateChecklist(
                  checklistId: checklistId,
                  data: checklist.data.copyWith(
                    linkedChecklistItems: [
                      ...checklist.data.linkedChecklistItems,
                      newItem.id,
                    ],
                  ),
                );

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
            'Error processing add checklist item: $e',
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

      // Force refresh of all checklist items in this task
      // This will cause the UI to re-check for suggestions
      ref.invalidate(checklistItemControllerProvider);

      developer.log(
        'Processed ${suggestions.length} checklist completion suggestions for task ${task.id}',
        name: 'UnifiedAiInferenceRepository',
      );
    } else {
      developer.log(
        'No suggestions to process after parsing tool calls',
        name: 'UnifiedAiInferenceRepository',
      );
    }
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
}

@riverpod
UnifiedAiInferenceRepository unifiedAiInferenceRepository(Ref ref) {
  return UnifiedAiInferenceRepository(ref);
}
