import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/functions/function_handler.dart';
import 'package:lotti/features/ai/functions/lotti_batch_checklist_handler.dart';
import 'package:lotti/features/ai/functions/lotti_checklist_handler.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ollama_inference_repository.dart';
import 'package:lotti/features/ai/services/auto_checklist_service.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:openai_dart/openai_dart.dart';

/// Processes AI function calls using conversation approach for better batching and error handling
class LottiConversationProcessor {
  LottiConversationProcessor({
    required this.ref,
  });

  final Ref ref;

  /// Process entire prompt using conversation approach (for checklistUpdates)
  Future<ConversationResult> processPromptWithConversation({
    required String prompt,
    required JournalEntity entity,
    required Task task,
    required AiConfigModel model,
    required AiConfigInferenceProvider provider,
    required AiConfigPrompt promptConfig,
    required String? systemMessage,
    required List<ChatCompletionTool> tools,
    required OllamaInferenceRepository ollamaRepo,
    AutoChecklistService? autoChecklistService,
  }) async {
    developer.log(
      'Processing prompt with conversation for task ${task.id}',
      name: 'LottiConversationProcessor',
    );

    // Create handlers
    final effectiveAutoChecklistService = autoChecklistService ??
        AutoChecklistService(
          checklistRepository: ref.read(checklistRepositoryProvider),
        );
    final checklistRepository = ref.read(checklistRepositoryProvider);

    // Track current task state
    var currentTask = task;

    final checklistHandler = LottiChecklistItemHandler(
      task: currentTask,
      autoChecklistService: effectiveAutoChecklistService,
      checklistRepository: checklistRepository,
      onTaskUpdated: (Task updatedTask) {
        // Update task reference for subsequent operations
        currentTask = updatedTask;
      },
    );

    final batchChecklistHandler = LottiBatchChecklistHandler(
      task: currentTask,
      autoChecklistService: effectiveAutoChecklistService,
      checklistRepository: checklistRepository,
      onTaskUpdated: (Task updatedTask) {
        // Update task reference for subsequent operations
        currentTask = updatedTask;
        checklistHandler.task = updatedTask;
      },
    );

    // Create conversation repository
    final conversationRepo = ref.read(conversationRepositoryProvider.notifier);

    // Create conversation with appropriate system message
    final conversationId = conversationRepo.createConversation(
      systemMessage: systemMessage ?? _defaultSystemMessage,
      maxTurns: 10,
    );

    final manager = conversationRepo.getConversation(conversationId)!;

    // Track results
    final startTime = DateTime.now();
    var responseText = '';
    var hasErrors = false;

    try {
      // Create strategy that will handle all the batching logic
      final strategy = LottiChecklistStrategy(
        checklistHandler: checklistHandler,
        batchChecklistHandler: batchChecklistHandler,
        ref: ref,
      );

      // Send the initial prompt - this will trigger the entire conversation flow
      await conversationRepo.sendMessage(
        conversationId: conversationId,
        message: prompt,
        model: model.providerModelId,
        provider: provider,
        ollamaRepo: ollamaRepo,
        tools: tools,
        temperature: 0.1,
        strategy: strategy,
      );

      // Collect results from strategy
      hasErrors = strategy.hadErrors;
      responseText = strategy.getResponseSummary();

      // Combine items from both handlers for logging
      final totalItems = checklistHandler.successfulItems.length +
          batchChecklistHandler.successfulItems.length;

      developer.log(
        'Conversation completed: $totalItems items created '
        '(checklist: ${checklistHandler.successfulItems.length}, '
        'batch: ${batchChecklistHandler.successfulItems.length}), '
        'errors: $hasErrors',
        name: 'LottiConversationProcessor',
      );

      // Store messages before cleanup
      final messages = List<ChatCompletionMessage>.from(manager.messages);

      // Use only checklistHandler items since batch items are copied there
      final allItems = checklistHandler.successfulItems;

      return ConversationResult(
        totalCreated: allItems.length,
        items: allItems,
        hadErrors: hasErrors,
        responseText: responseText,
        duration: DateTime.now().difference(startTime),
        messages: messages,
      );
    } catch (e) {
      developer.log(
        'Error in conversation processing',
        name: 'LottiConversationProcessor',
        error: e,
      );
      hasErrors = true;
      responseText = 'Error processing request: $e';

      // Use only checklistHandler items since batch items are copied there
      final allItems = checklistHandler.successfulItems;

      return ConversationResult(
        totalCreated: allItems.length,
        items: allItems,
        hadErrors: true,
        responseText: responseText,
        duration: DateTime.now().difference(startTime),
        messages: [],
      );
    } finally {
      conversationRepo.deleteConversation(conversationId);
    }
  }

  static const _defaultSystemMessage = '''
You are a helpful assistant that creates checklist items based on the user's request.

Your primary task is to create checklist items from the user's request. You have two options:

1. Use add_multiple_checklist_items for efficiency when you have multiple items:
   - This is the PREFERRED method when you have 2 or more items
   - Format: {"items": "item1, item2, item3"}
   - Example: {"items": "cheese, tomatoes, pepperoni"}

2. Use add_checklist_item for single items:
   - Format: {"actionItemDescription": "item description"}
   - Use this only when adding a single item

Guidelines:
- If you detect a language, call set_task_language first, then create items
- Do not use suggest_checklist_completion
- When the user provides a list, use add_multiple_checklist_items for efficiency

Example: If user says "Pizza shopping: cheese, pepperoni, dough", use:
add_multiple_checklist_items with {"items": "cheese, pepperoni, dough"}''';

  /// Process already-received function calls with conversation approach
  /// Used when we already have tool calls from an initial response
  Future<ProcessingResult> processFunctionCalls({
    required List<ChatCompletionMessageToolCall> initialToolCalls,
    required Task task,
    required AiConfigModel model,
    required AiConfigInferenceProvider provider,
    required String originalPrompt,
    required OllamaInferenceRepository ollamaRepo,
    AutoChecklistService? autoChecklistService,
  }) async {
    developer.log(
      'Processing ${initialToolCalls.length} function calls for task ${task.id}',
      name: 'LottiConversationProcessor',
    );

    // Create handlers
    final effectiveAutoChecklistService = autoChecklistService ??
        AutoChecklistService(
          checklistRepository: ref.read(checklistRepositoryProvider),
        );

    // Create a mutable copy of task to avoid reassigning the parameter
    var currentTask = task;

    final checklistHandler = LottiChecklistItemHandler(
      task: currentTask,
      autoChecklistService: effectiveAutoChecklistService,
      checklistRepository: ref.read(checklistRepositoryProvider),
      onTaskUpdated: (updatedTask) {
        // Update task reference for subsequent operations
        currentTask = updatedTask;
      },
    );

    final handlers = <FunctionHandler>[checklistHandler];

    // Create conversation repository if needed
    final conversationRepo = ref.read(conversationRepositoryProvider.notifier);

    // System message for conversation
    const systemMessage = '''
You are a helpful assistant that creates checklist items for task management.
When asked to create multiple items, create them efficiently.
Always use the provided function to create items.
IMPORTANT: The correct format is {"actionItemDescription": "item description"}.
''';

    // Create conversation
    final conversationId = conversationRepo.createConversation(
      systemMessage: systemMessage,
      maxTurns: 10,
    );

    final manager = conversationRepo.getConversation(conversationId)!;

    // Track results
    final allResults = <FunctionCallResult>[];
    var hasErrors = false;
    var totalProcessed = 0;

    try {
      // First, process the initial tool calls
      developer.log(
        'Processing initial tool calls',
        name: 'LottiConversationProcessor',
      );

      for (final toolCall in initialToolCalls) {
        final handler = handlers.firstWhere(
          (h) => h.functionName == toolCall.function.name,
          orElse: () =>
              throw Exception('No handler for ${toolCall.function.name}'),
        );

        final result = handler.processFunctionCall(toolCall);
        allResults.add(result);

        if (result.success && !handler.isDuplicate(result)) {
          // Actually create the item
          final created = await checklistHandler.createItem(result);
          if (created) {
            totalProcessed++;
            developer.log(
              'Created item: ${handler.getDescription(result)}',
              name: 'LottiConversationProcessor',
            );
          }
        } else if (!result.success) {
          hasErrors = true;
          developer.log(
            'Failed to process: ${result.error}',
            name: 'LottiConversationProcessor',
          );
        }

        // Add tool response to conversation
        manager.addToolResponse(
          toolCallId: toolCall.id,
          response: handler.createToolResponse(result),
        );
      }

      // If we had errors, try to recover with conversation
      if (hasErrors) {
        developer.log(
          'Attempting to recover from errors using conversation',
          name: 'LottiConversationProcessor',
        );

        // Get failed items
        final failedResults = allResults.where((r) => !r.success).toList();

        if (failedResults.isNotEmpty) {
          // Create retry prompt
          final retryPrompt = checklistHandler.getRetryPrompt(
            failedItems: failedResults,
            successfulDescriptions: checklistHandler.successfulItems,
          );

          // Send retry request
          await conversationRepo.sendMessage(
            conversationId: conversationId,
            message: retryPrompt,
            model: model.providerModelId,
            provider: provider,
            ollamaRepo: ollamaRepo,
            tools: [
              const ChatCompletionTool(
                type: ChatCompletionToolType.function,
                function: FunctionObject(
                  name: 'add_checklist_item',
                  description: 'Create a checklist item',
                  parameters: {
                    'type': 'object',
                    'required': ['actionItemDescription'],
                    'properties': {
                      'actionItemDescription': {
                        'type': 'string',
                        'description': 'The item description',
                      },
                    },
                  },
                ),
              ),
            ],
            temperature: 0.1,
            strategy: _RetryStrategy(
              checklistHandler: checklistHandler,
              onSuccess: () {
                totalProcessed++;
              },
            ),
          );
        }
      }

      // Check if we need to continue the original prompt
      // (e.g., if the model only created some items and we need more)
      if (totalProcessed > 0) {
        developer.log(
          'Continuing conversation to complete remaining items',
          name: 'LottiConversationProcessor',
        );

        final continuationPrompt = '''
Great! Created ${checklistHandler.successfulItems.length} items so far: ${checklistHandler.successfulItems.join(', ')}

Please continue creating any remaining items from the original request.''';

        await conversationRepo.sendMessage(
          conversationId: conversationId,
          message: continuationPrompt,
          model: model.providerModelId,
          provider: provider,
          ollamaRepo: ollamaRepo,
          tools: [
            const ChatCompletionTool(
              type: ChatCompletionToolType.function,
              function: FunctionObject(
                name: 'add_checklist_item',
                description: 'Create a checklist item',
                parameters: {
                  'type': 'object',
                  'required': ['actionItemDescription'],
                  'properties': {
                    'actionItemDescription': {
                      'type': 'string',
                      'description': 'The item description',
                    },
                  },
                },
              ),
            ),
          ],
          temperature: 0.1,
          strategy: _ContinuationStrategy(
            checklistHandler: checklistHandler,
            onSuccess: () {
              totalProcessed++;
            },
            maxItems: 10, // Reasonable limit
          ),
        );
      }
    } catch (e) {
      developer.log(
        'Error in conversation processing',
        name: 'LottiConversationProcessor',
        error: e,
      );
    } finally {
      conversationRepo.deleteConversation(conversationId);
    }

    return ProcessingResult(
      totalCreated: checklistHandler.successfulItems.length,
      items: checklistHandler.successfulItems,
      hadErrors: hasErrors,
    );
  }
}

/// Result of processing function calls
class ProcessingResult {
  const ProcessingResult({
    required this.totalCreated,
    required this.items,
    required this.hadErrors,
  });

  final int totalCreated;
  final List<String> items;
  final bool hadErrors;
}

/// Strategy for retrying failed items
class _RetryStrategy extends ConversationStrategy {
  _RetryStrategy({
    required this.checklistHandler,
    required this.onSuccess,
  });

  final LottiChecklistItemHandler checklistHandler;
  final VoidCallback onSuccess;

  @override
  Future<ConversationAction> processToolCalls({
    required List<ChatCompletionMessageToolCall> toolCalls,
    required ConversationManager manager,
  }) async {
    for (final call in toolCalls) {
      if (call.function.name == checklistHandler.functionName) {
        final result = checklistHandler.processFunctionCall(call);

        if (result.success && !checklistHandler.isDuplicate(result)) {
          final created = await checklistHandler.createItem(result);
          if (created) {
            onSuccess();
          }
        }

        manager.addToolResponse(
          toolCallId: call.id,
          response: checklistHandler.createToolResponse(result),
        );
      }
    }

    return ConversationAction.complete;
  }

  @override
  bool shouldContinue(ConversationManager manager) => false;

  @override
  String? getContinuationPrompt(ConversationManager manager) => null;
}

/// Strategy for continuing with more items
class _ContinuationStrategy extends ConversationStrategy {
  _ContinuationStrategy({
    required this.checklistHandler,
    required this.onSuccess,
    required this.maxItems,
  });

  final LottiChecklistItemHandler checklistHandler;
  final VoidCallback onSuccess;
  final int maxItems;

  int _rounds = 0;

  @override
  Future<ConversationAction> processToolCalls({
    required List<ChatCompletionMessageToolCall> toolCalls,
    required ConversationManager manager,
  }) async {
    _rounds++;

    for (final call in toolCalls) {
      if (call.function.name == checklistHandler.functionName) {
        final result = checklistHandler.processFunctionCall(call);

        if (result.success && !checklistHandler.isDuplicate(result)) {
          final created = await checklistHandler.createItem(result);
          if (created) {
            onSuccess();
          }
        }

        manager.addToolResponse(
          toolCallId: call.id,
          response: checklistHandler.createToolResponse(result),
        );
      }
    }

    // Continue if we haven't reached max items and haven't tried too many times
    if (checklistHandler.successfulItems.length < maxItems && _rounds < 5) {
      return ConversationAction.continueConversation;
    }

    return ConversationAction.complete;
  }

  @override
  bool shouldContinue(ConversationManager manager) {
    return checklistHandler.successfulItems.length < maxItems && _rounds < 5;
  }

  @override
  String? getContinuationPrompt(ConversationManager manager) {
    if (!shouldContinue(manager)) return null;

    return 'Please continue creating any remaining items from the original request.';
  }
}

/// Result of conversation-based processing
class ConversationResult {
  const ConversationResult({
    required this.totalCreated,
    required this.items,
    required this.hadErrors,
    required this.responseText,
    required this.duration,
    required this.messages,
  });

  final int totalCreated;
  final List<String> items;
  final bool hadErrors;
  final String responseText;
  final Duration duration;
  final List<ChatCompletionMessage> messages;
}

/// Strategy for handling checklist creation in Lotti
class LottiChecklistStrategy extends ConversationStrategy {
  LottiChecklistStrategy({
    required this.checklistHandler,
    required this.batchChecklistHandler,
    required this.ref,
  });

  final LottiChecklistItemHandler checklistHandler;
  final LottiBatchChecklistHandler batchChecklistHandler;
  final Ref ref;

  int _rounds = 0;
  bool _hadErrors = false;
  final List<FunctionCallResult> _failedResults = [];

  bool get hadErrors => _hadErrors;

  String getResponseSummary() {
    // Combine items from both handlers
    final allItems = <String>{}
      ..addAll(checklistHandler.successfulItems)
      ..addAll(batchChecklistHandler.successfulItems);

    if (allItems.isEmpty) {
      return 'No checklist items were created.';
    }

    final itemCount = allItems.length;
    final itemWord = itemCount == 1 ? 'item' : 'items';

    return 'Created $itemCount checklist $itemWord:\n${allItems.map((item) => '• $item').join('\n')}';
  }

  @override
  Future<ConversationAction> processToolCalls({
    required List<ChatCompletionMessageToolCall> toolCalls,
    required ConversationManager manager,
  }) async {
    _rounds++;

    developer.log(
      'LottiChecklistStrategy: Processing ${toolCalls.length} tool calls in round $_rounds',
      name: 'LottiConversationProcessor',
    );

    for (final call in toolCalls) {
      developer.log(
        'Processing tool call: ${call.function.name} with args: ${call.function.arguments}',
        name: 'LottiConversationProcessor',
      );

      if (call.function.name == checklistHandler.functionName) {
        final result = checklistHandler.processFunctionCall(call);

        developer.log(
          'Tool call result: success=${result.success}, description=${checklistHandler.getDescription(result)}',
          name: 'LottiConversationProcessor',
        );

        if (result.success && !checklistHandler.isDuplicate(result)) {
          final created = await checklistHandler.createItem(result);
          developer.log(
            'Item creation result: $created for "${checklistHandler.getDescription(result)}"',
            name: 'LottiConversationProcessor',
          );
          if (!created) {
            _hadErrors = true;
          }
        } else if (!result.success) {
          _hadErrors = true;
          _failedResults.add(result);
        }

        manager.addToolResponse(
          toolCallId: call.id,
          response: checklistHandler.createToolResponse(result),
        );
      } else if (call.function.name == batchChecklistHandler.functionName) {
        final result = batchChecklistHandler.processFunctionCall(call);

        developer.log(
          'Batch tool call result: success=${result.success}, items=${batchChecklistHandler.getDescription(result)}',
          name: 'LottiConversationProcessor',
        );

        if (result.success) {
          // Pass existing descriptions to prevent duplicates
          final existingDescriptions = checklistHandler.successfulItems
              .map((item) => item.toLowerCase().trim())
              .toSet();
          final createdCount = await batchChecklistHandler.createBatchItems(
            result,
            existingDescriptions: existingDescriptions,
          );
          developer.log(
            'Batch creation result: created $createdCount items',
            name: 'LottiConversationProcessor',
          );
          // Only flag as error if we tried to create items but failed
          // (not if all items were duplicates)
          final items = result.data['items'] as List<String>?;
          if (createdCount == 0 && items != null && items.isNotEmpty) {
            // Check if all items were duplicates
            final allDuplicates = items.every((item) =>
                existingDescriptions.contains(item.toLowerCase().trim()));
            if (!allDuplicates) {
              // Some items should have been created but weren't
              _hadErrors = true;
            }
          }
          // Copy successful items to the single item handler for consistency
          checklistHandler
              .addSuccessfulItems(batchChecklistHandler.successfulItems);
        } else {
          _hadErrors = true;
          _failedResults.add(result);
        }

        manager.addToolResponse(
          toolCallId: call.id,
          response: batchChecklistHandler.createToolResponse(result),
        );
      } else if (call.function.name == 'set_task_language') {
        // Handle language setting properly
        try {
          final args =
              jsonDecode(call.function.arguments) as Map<String, dynamic>;
          final languageCode = args['languageCode'] as String?;
          final confidence = args['confidence'] as String?;
          final reason = args['reason'] as String?;

          developer.log(
            'Processing set_task_language: $languageCode (confidence: $confidence, reason: $reason)',
            name: 'LottiConversationProcessor',
          );

          if (languageCode != null &&
              checklistHandler.task.data.languageCode == null) {
            // Update the task with the detected language
            final updatedTask = checklistHandler.task.copyWith(
              data: checklistHandler.task.data.copyWith(
                languageCode: languageCode,
              ),
            );

            try {
              final journalRepo = ref.read(journalRepositoryProvider);
              await journalRepo.updateJournalEntity(updatedTask);

              // Update the handler's task reference
              checklistHandler.task = updatedTask;
              checklistHandler.onTaskUpdated?.call(updatedTask);

              developer.log(
                'Successfully set task language to $languageCode',
                name: 'LottiConversationProcessor',
              );

              manager.addToolResponse(
                toolCallId: call.id,
                response:
                    "Language set to $languageCode. Good! Now please create the checklist items from the user's request.",
              );
            } catch (e) {
              developer.log(
                'Failed to update task language',
                name: 'LottiConversationProcessor',
                error: e,
              );
              manager.addToolResponse(
                toolCallId: call.id,
                response:
                    'Failed to set language, but continuing with checklist items.',
              );
            }
          } else if (checklistHandler.task.data.languageCode != null) {
            developer.log(
              'Task already has language: ${checklistHandler.task.data.languageCode}',
              name: 'LottiConversationProcessor',
            );
            manager.addToolResponse(
              toolCallId: call.id,
              response: 'Language already set. Creating checklist items.',
            );
          } else {
            manager.addToolResponse(
              toolCallId: call.id,
              response: 'Invalid language data. Creating checklist items.',
            );
          }
        } catch (e) {
          developer.log(
            'Error processing set_task_language: $e',
            name: 'LottiConversationProcessor',
            error: e,
          );
          manager.addToolResponse(
            toolCallId: call.id,
            response:
                'Error setting language, but continuing with checklist items.',
          );
        }
      } else if (call.function.name == 'suggest_checklist_completion') {
        // Handle but redirect to creating items
        developer.log(
          'Redirecting suggest_checklist_completion to item creation: ${call.function.arguments}',
          name: 'LottiConversationProcessor',
        );

        // Try to extract the suggested items for a more descriptive response
        String detailedResponse;
        try {
          final args =
              jsonDecode(call.function.arguments) as Map<String, dynamic>;
          final suggestions = args['suggestions'] as List<dynamic>?;
          if (suggestions != null && suggestions.isNotEmpty) {
            final itemDescriptions = suggestions
                .map((s) => s is Map<String, dynamic>
                    ? s['title'] ?? s['description']
                    : s.toString())
                .where(
                    (desc) => desc != null && desc.toString().trim().isNotEmpty)
                .take(5) // Limit to first 5 for brevity
                .join(', ');

            detailedResponse = suggestions.length > 5
                ? 'Found ${suggestions.length} suggested items ($itemDescriptions, ...). Please use add_checklist_item or add_multiple_checklist_items to create these items.'
                : 'Found ${suggestions.length} suggested items: $itemDescriptions. Please use add_checklist_item or add_multiple_checklist_items to create these items.';
          } else {
            detailedResponse =
                'No items to suggest. Please use add_checklist_item if you want to create new items.';
          }
        } catch (e) {
          // If we can't parse the arguments, use a generic response
          detailedResponse =
              'Please use add_checklist_item or add_multiple_checklist_items to create the suggested items.';
        }

        manager.addToolResponse(
          toolCallId: call.id,
          response: detailedResponse,
        );
      } else {
        developer.log(
          'Unknown tool call: ${call.function.name}',
          name: 'LottiConversationProcessor',
        );
        manager.addToolResponse(
          toolCallId: call.id,
          response:
              'Unknown function. Please use add_checklist_item to create checklist items.',
        );
      }
    }

    // Continue if we haven't tried too many times and haven't created any items yet
    // OR if we've created at least one item and haven't exceeded our round limit
    final totalSuccessfulItems = checklistHandler.successfulItems.length +
        batchChecklistHandler.successfulItems.length;
    final shouldContinue =
        _rounds < 10 && (_rounds == 1 || totalSuccessfulItems > 0);

    developer.log(
      'Deciding whether to continue: checklistItems=${checklistHandler.successfulItems.length}, '
      'batchItems=${batchChecklistHandler.successfulItems.length}, '
      'totalItems=$totalSuccessfulItems, rounds=$_rounds, shouldContinue=$shouldContinue',
      name: 'LottiConversationProcessor',
    );

    if (shouldContinue) {
      return ConversationAction.continueConversation;
    }

    return ConversationAction.complete;
  }

  @override
  bool shouldContinue(ConversationManager manager) {
    final totalSuccessfulItems = checklistHandler.successfulItems.length +
        batchChecklistHandler.successfulItems.length;
    return _rounds < 10 && (_rounds == 1 || totalSuccessfulItems > 0);
  }

  @override
  String? getContinuationPrompt(ConversationManager manager) {
    if (!shouldContinue(manager)) return null;

    // Check if we have failed items to retry
    if (_failedResults.isNotEmpty && _rounds <= 2) {
      final retryPrompt = checklistHandler.getRetryPrompt(
        failedItems: _failedResults,
        successfulDescriptions: checklistHandler.successfulItems,
      );
      _failedResults.clear(); // Clear for next round
      return retryPrompt;
    }

    // Combine successful items from both handlers
    final allSuccessfulItems = <String>[
      ...checklistHandler.successfulItems,
      ...batchChecklistHandler.successfulItems,
    ];

    // If no items created yet, provide explicit instructions
    if (allSuccessfulItems.isEmpty) {
      return '''
You haven't created any checklist items yet. Please review the user's original request and use the add_checklist_item function to create each item.

Remember to use the format: {"actionItemDescription": "item description"}

For example, if the user asked for a pizza shopping list with cheese, pepperoni, and dough, you would call add_checklist_item three times:
1. {"actionItemDescription": "cheese"}
2. {"actionItemDescription": "pepperoni"}
3. {"actionItemDescription": "dough"}

Please create the checklist items now.''';
    }

    return '''
Great! You've created ${allSuccessfulItems.length} checklist item(s) so far: ${allSuccessfulItems.join(', ')}.

The user's original request mentioned multiple items. Please continue using the add_checklist_item function to create each of the remaining items.

Remember: Create one item per function call. Continue until all items from the user's request have been added.''';
  }
}
