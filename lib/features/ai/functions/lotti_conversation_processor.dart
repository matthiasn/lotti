import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/functions/function_handler.dart';
import 'package:lotti/features/ai/functions/lotti_batch_checklist_handler.dart';
import 'package:lotti/features/ai/functions/lotti_checklist_handler.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:lotti/features/ai/services/auto_checklist_service.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/services/label_assignment_processor.dart';
import 'package:lotti/features/labels/utils/label_tool_parsing.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
// ignore: unused_import
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/consts.dart';
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
    required InferenceRepositoryInterface inferenceRepo,
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
    if (systemMessage == null || systemMessage.isEmpty) {
      developer.log(
        'No system message provided for conversation processor',
        name: 'LottiConversationProcessor',
        level: 900, // WARNING level
      );
      throw ArgumentError(
          'System message is required for conversation processing');
    }

    final conversationId = conversationRepo.createConversation(
      systemMessage: systemMessage,
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
        provider: provider,
      );

      // Send the initial prompt - this will trigger the entire conversation flow
      await conversationRepo.sendMessage(
        conversationId: conversationId,
        message: prompt,
        model: model.providerModelId,
        provider: provider,
        inferenceRepo: inferenceRepo,
        tools: tools,
        temperature: 0.1,
        strategy: strategy,
      );

      // Collect results from strategy
      hasErrors = strategy.hadErrors;
      responseText = strategy.getResponseSummary();

      // Merge items from both handlers for robustness
      final mergedItems = <String>{
        ...checklistHandler.successfulItems,
        ...batchChecklistHandler.successfulItems,
      }.toList();
      final totalItems = mergedItems.length;

      developer.log(
        'Conversation completed: $totalItems items created '
        '(checklist: ${checklistHandler.successfulItems.length}, '
        'batch: ${batchChecklistHandler.successfulItems.length}), '
        'errors: $hasErrors',
        name: 'LottiConversationProcessor',
      );

      // Store messages before cleanup
      final messages = List<ChatCompletionMessage>.from(manager.messages);

      // Merge items from both handlers
      final allItems = <String>{
        ...checklistHandler.successfulItems,
        ...batchChecklistHandler.successfulItems,
      }.toList();

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
    required this.provider,
  });

  final LottiChecklistItemHandler checklistHandler;
  final LottiBatchChecklistHandler batchChecklistHandler;
  final Ref ref;
  final AiConfigInferenceProvider provider;

  int _rounds = 0;
  bool _hadErrors = false;
  final List<FunctionCallResult> _failedResults = [];

  bool get hadErrors => _hadErrors;

  String getResponseSummary() {
    // Merge items from both handlers
    final allItems = <String>{
      ...checklistHandler.successfulItems,
      ...batchChecklistHandler.successfulItems,
    }.toList();

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
          final createdCount =
              await batchChecklistHandler.createBatchItems(result);
          developer.log(
            'Batch creation result: created $createdCount items',
            name: 'LottiConversationProcessor',
          );
          // Only flag as error if we tried to create items but failed
          // (not if all items were duplicates)
          final items = result.data['items'] as List<dynamic>?;
          if (createdCount == 0 && items != null && items.isNotEmpty) {
            _hadErrors = true;
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
              batchChecklistHandler.task = updatedTask;
              checklistHandler.onTaskUpdated?.call(updatedTask);

              developer.log(
                'Successfully set task language to $languageCode',
                name: 'LottiConversationProcessor',
              );

              manager.addToolResponse(
                toolCallId: call.id,
                response:
                    'Language set to $languageCode. Task language updated successfully.',
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
                    'Failed to set language. Continuing without language update.',
              );
            }
          } else if (checklistHandler.task.data.languageCode != null) {
            developer.log(
              'Task already has language: ${checklistHandler.task.data.languageCode}',
              name: 'LottiConversationProcessor',
            );
            manager.addToolResponse(
              toolCallId: call.id,
              response:
                  'Language already set to ${checklistHandler.task.data.languageCode}.',
            );
          } else {
            manager.addToolResponse(
              toolCallId: call.id,
              response: 'Invalid language data received.',
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
            response: 'Error processing language detection.',
          );
        }
      } else if (call.function.name == 'assign_task_labels') {
        // Assign labels to task (add-only) with rate limiting (handled upstream if needed)
        try {
          final db = getIt<JournalDb>();
          final processor = LabelAssignmentProcessor(
            repository: ref.read(labelsRepositoryProvider),
          );

          final parsed = parseLabelCallArgs(call.function.arguments);
          final selected =
              LinkedHashSet<String>.from(parsed.selectedIds).toList();
          // Phase 3: filter out suppressed IDs for this task (hard filter)
          final suppressedSet =
              checklistHandler.task.data.aiSuppressedLabelIds ??
                  const <String>{};
          final proposed =
              selected.where((id) => !suppressedSet.contains(id)).toList();
          // Shadow mode: do not persist if enabled (safe default false)
          var shadow = false;
          try {
            final dynamic fut = db.getConfigFlag(aiLabelAssignmentShadowFlag);
            if (fut is Future<bool>) {
              shadow = await fut;
            }
          } catch (_) {
            shadow = false;
          }
          // Short-circuit if everything was suppressed
          if (proposed.isEmpty && selected.isNotEmpty) {
            final skipped = selected
                .where(suppressedSet.contains)
                .map((id) => {'id': id, 'reason': 'suppressed'})
                .toList();
            final noop = LabelAssignmentResult(
              assigned: const [],
              invalid: const [],
              skipped: skipped,
            );
            final response = noop.toStructuredJson(selected);
            manager.addToolResponse(
              toolCallId: call.id,
              response: response,
            );
            continue;
          }

          final result = await processor.processAssignment(
            taskId: checklistHandler.task.id,
            proposedIds: proposed,
            existingIds:
                checklistHandler.task.meta.labelIds ?? const <String>[],
            shadowMode: shadow,
            categoryId: checklistHandler.task.meta.categoryId,
            // Phase 2 metrics forwarded for telemetry
            droppedLow: parsed.droppedLow,
            legacyUsed: parsed.legacyUsed,
            confidenceBreakdown: parsed.confidenceBreakdown,
            totalCandidates: parsed.totalCandidates,
          );

          // Structured tool response for the model
          final response = result.toStructuredJson(proposed);
          manager.addToolResponse(
            toolCallId: call.id,
            response: response,
          );
        } catch (e) {
          developer.log(
            'Error processing assign_task_labels: $e',
            name: 'LottiConversationProcessor',
            error: e,
          );
          // Return a structured error response instead of a generic string
          try {
            final requested = LinkedHashSet<String>.from(
              parseLabelCallArgs(call.function.arguments).selectedIds,
            ).toList();
            final errorResponse = jsonEncode({
              'function': 'assign_task_labels',
              'request': {'labelIds': requested},
              'error': 'Error processing label assignment: $e',
            });
            manager.addToolResponse(
              toolCallId: call.id,
              response: errorResponse,
            );
          } catch (_) {
            manager.addToolResponse(
              toolCallId: call.id,
              response: 'Error processing label assignment',
            );
          }
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
                ? 'Found ${suggestions.length} suggested items ($itemDescriptions, ...). Please use add_multiple_checklist_items (array of objects) to create these items.'
                : 'Found ${suggestions.length} suggested items: $itemDescriptions. Please use add_multiple_checklist_items (array of objects) to create these items.';
          } else {
            detailedResponse =
                'No items to suggest. To create new items, call add_multiple_checklist_items with {"items": [{"title": "..."}]}.';
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
              'Unknown function. Please use add_multiple_checklist_items with the required array-of-objects format.',
        );
      }
    }

    // For cloud providers (like Gemini), we don't need multi-round conversations
    // as they typically return complete responses in the first round
    final isCloudProvider =
        provider.inferenceProviderType != InferenceProviderType.ollama;

    // Continue logic depends on provider type
    final totalSuccessfulItems = checklistHandler.successfulItems.length;
    final shouldContinue = !isCloudProvider && // Only continue for Ollama
        _rounds < 10 &&
        (_rounds == 1 || totalSuccessfulItems > 0);

    developer.log(
      'Deciding whether to continue: provider=${provider.inferenceProviderType}, '
      'isCloudProvider=$isCloudProvider, checklistItems=${checklistHandler.successfulItems.length}, '
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
    // Only continue for Ollama providers
    if (provider.inferenceProviderType != InferenceProviderType.ollama) {
      return false;
    }

    final totalSuccessfulItems = checklistHandler.successfulItems.length;
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

    // Merge items from both handlers
    final allSuccessfulItems = <String>{
      ...checklistHandler.successfulItems,
      ...batchChecklistHandler.successfulItems,
    }.toList();

    // If no items created yet, provide explicit instructions
    if (allSuccessfulItems.isEmpty) {
      return '''
You haven't created any checklist items yet. Please review the user's original request.

IMPORTANT: When you have multiple items to add (2 or more), you MUST use add_multiple_checklist_items in a SINGLE call.

Required format (array of objects):
{"items": [{"title": "item1"}, {"title": "item2"}, {"title": "item3", "isChecked": true}]}

Example: If the user asked for a pizza shopping list with cheese, pepperoni, and dough, use ONE call:
add_multiple_checklist_items with {"items": [{"title": "cheese"}, {"title": "pepperoni"}, {"title": "dough"}]}

Please create the checklist items now using the required function and format.''';
    }

    return '''
Great! You've created ${allSuccessfulItems.length} checklist item(s) so far: ${allSuccessfulItems.join(', ')}.

If there are more items to add from the user's original request:
- Use add_multiple_checklist_items with {"items": [{"title": "item1"}, {"title": "item2"}, {"title": "item3"}]}
- When an item is explicitly mentioned as already done, set {"isChecked": true} for that item

Continue until all items from the user's request have been added.''';
  }
}
