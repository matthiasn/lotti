import 'dart:async';
import 'dart:convert';

import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ollama_inference_repository.dart';
import 'package:openai_dart/openai_dart.dart';

/// Batch processor using conversation-based approach
/// 
/// This processor leverages the conversation system to handle batch operations
/// flexibly - supporting both models that can process multiple items at once
/// and those that need conversation continuation.
class ConversationBatchProcessor {
  ConversationBatchProcessor({
    required this.conversationRepo,
    required this.ollamaRepo,
  });
  
  final ConversationRepository conversationRepo;
  final OllamaInferenceRepository ollamaRepo;
  
  /// Process a batch request using conversation
  Stream<BatchProcessingEvent> processBatch({
    required String prompt,
    required String model,
    required AiConfigInferenceProvider provider,
    required List<ChatCompletionTool> tools,
    String? systemMessage,
    double temperature = 0.1,
  }) async* {
    // Create conversation
    final conversationId = conversationRepo.createConversation(
      systemMessage: systemMessage ?? _defaultSystemMessage,
      maxTurns: 15, // Reasonable limit for batch processing
    );
    
    final manager = conversationRepo.getConversation(conversationId)!;
    
    // Track created items
    final createdItems = <FunctionCallResult>[];
    
    // Listen to conversation events
    final subscription = manager.events.listen((event) {
      // We'll yield events based on conversation events
    });
    
    try {
      // Yield initial analyzing event
      yield BatchProcessingEvent.analyzing();
      
      // Create batch strategy
      final strategy = FlexibleBatchStrategy(
        onItemCreated: (item) {
          createdItems.add(item);
        },
      );
      
      // Send initial message
      await conversationRepo.sendMessage(
        conversationId: conversationId,
        message: prompt,
        model: model,
        provider: provider,
        ollamaRepo: ollamaRepo,
        tools: tools,
        temperature: temperature,
        strategy: strategy,
      );
      
      // Process events from strategy
      await for (final event in strategy.events) {
        yield event;
        
        if (event is BatchCompletedEvent) {
          break;
        }
      }
      
    } catch (e) {
      yield BatchProcessingEvent.error(message: e.toString());
    } finally {
      await subscription.cancel();
      conversationRepo.deleteConversation(conversationId);
    }
  }
  
  static const _defaultSystemMessage = '''
You are a helpful assistant that creates checklist items.
When asked to create multiple items, you can:
1. Create all items at once if your model supports it
2. Create items one at a time if needed

Always use the provided function to create items.
Be concise and efficient.
''';
}

/// Flexible batch strategy that handles both single and multi-item responses
class FlexibleBatchStrategy extends ConversationStrategy {
  FlexibleBatchStrategy({
    required this.onItemCreated,
  });
  
  final void Function(FunctionCallResult) onItemCreated;
  final _eventController = StreamController<BatchProcessingEvent>.broadcast();
  
  Stream<BatchProcessingEvent> get events => _eventController.stream;
  
  int _totalItemsCreated = 0;
  int _roundNumber = 0;
  bool _hasStarted = false;
  final List<FunctionCallResult> _failedItems = [];
  bool _hasRetriedErrors = false;
  final Set<String> _createdItemDescriptions = {}; // Track unique items
  
  @override
  Future<ConversationAction> processToolCalls({
    required List<ChatCompletionMessageToolCall> toolCalls,
    required ConversationManager manager,
  }) async {
    _roundNumber++;
    
    if (!_hasStarted) {
      _hasStarted = true;
      _eventController.add(BatchProcessingEvent.startingBatch(
        totalItems: -1, // Unknown total
      ));
    }
    
    // Process all tool calls in this round
    final roundItems = <FunctionCallResult>[];
    
    for (final call in toolCalls) {
      if (call.function.name == 'createChecklistItem' || 
          call.function.name == 'addChecklistItem') {
        try {
          final args = jsonDecode(call.function.arguments) as Map<String, dynamic>;
          final description = args['actionItemDescription'] as String?;
          
          if (description != null) {
            // Check for duplicates
            final isDuplicate = _createdItemDescriptions.contains(description.toLowerCase());
            
            if (!isDuplicate) {
              _createdItemDescriptions.add(description.toLowerCase());
              
              final result = FunctionCallResult(
                success: true,
                functionName: call.function.name,
                arguments: call.function.arguments,
                originalItem: description,
              );
              
              roundItems.add(result);
              onItemCreated(result);
              _totalItemsCreated++;
              
              // Add tool response
              manager.addToolResponse(
                toolCallId: call.id,
                response: 'Created: $description',
              );
            } else {
              // Skip duplicate
              manager.addToolResponse(
                toolCallId: call.id,
                response: 'Skipped: $description (already exists)',
              );
            }
          }
        } catch (e) {
          // Try to extract what the model was trying to create
          String attemptedItem = '';
          String errorDetails = '';
          
          try {
            // Try to parse even if malformed
            final rawArgs = jsonDecode(call.function.arguments) as Map<String, dynamic>;
            // Look for any string value that might be the item
            for (final entry in rawArgs.entries) {
              if (entry.value is String && entry.value.toString().isNotEmpty) {
                attemptedItem = entry.value.toString();
                errorDetails = 'Found "${entry.key}" instead of "actionItemDescription"';
                break;
              }
            }
          } catch (_) {
            errorDetails = 'Invalid JSON format';
          }
          
          // Handle parse error
          final result = FunctionCallResult(
            success: false,
            functionName: call.function.name,
            arguments: call.function.arguments,
            originalItem: attemptedItem,
            error: errorDetails.isNotEmpty ? errorDetails : e.toString(),
          );
          
          roundItems.add(result);
          _failedItems.add(result);
          
          manager.addToolResponse(
            toolCallId: call.id,
            response: 'Error: Unable to create item. $errorDetails',
          );
        }
      }
    }
    
    // Emit event for this round
    if (roundItems.isNotEmpty) {
      _eventController.add(BatchProcessingEvent.itemsCreated(
        items: roundItems,
        totalSoFar: _totalItemsCreated,
      ));
    }
    
    // Decide whether to continue
    final shouldContinue = _shouldContinueBasedOnContext(manager);
    
    if (!shouldContinue) {
      // Emit completion
      _eventController.add(BatchProcessingEvent.batchCompleted(
        results: [], // Results are tracked externally
      ));
      return ConversationAction.complete;
    }
    
    return ConversationAction.continueConversation;
  }
  
  @override
  bool shouldContinue(ConversationManager manager) {
    // Let processToolCalls decide
    return true;
  }
  
  @override
  String? getContinuationPrompt(ConversationManager manager) {
    // Check if we have failed items to retry
    if (_failedItems.isNotEmpty && !_hasRetriedErrors) {
      _hasRetriedErrors = true;
      
      final errorSummary = _failedItems.map((item) {
        final attempted = item.originalItem.isNotEmpty 
            ? 'for "${item.originalItem}"' 
            : '';
        return '- ${item.error} $attempted';
      }).join('\n');
      
      final retryItems = _failedItems
          .where((item) => item.originalItem.isNotEmpty)
          .map((item) => item.originalItem)
          .toList();
      
      _failedItems.clear(); // Clear for next round
      
      if (retryItems.isNotEmpty) {
        // Get list of successfully created items from conversation history
        final successfulDescriptions = _getSuccessfulItemDescriptions(manager);
        
        return '''
I noticed ${_failedItems.length == 1 ? 'an error' : 'errors'} in your function call${_failedItems.length > 1 ? 's' : ''}:
$errorSummary

You already successfully created these items: ${successfulDescriptions.join(', ')}

Please create ONLY the failed item${retryItems.length > 1 ? 's' : ''}: ${retryItems.join(', ')}

Use the correct format:
{"actionItemDescription": "item description"}

Do NOT recreate the items that were already successful.''';
      }
    }
    
    if (_totalItemsCreated == 0) {
      return 'Please use the createChecklistItem function to create the checklist items.';
    }
    
    return '''
Great! I've successfully created $_totalItemsCreated item(s) so far.

Are there more items to create? If yes, please continue creating them.
If all items have been created, just say "done" or "complete".''';
  }
  
  List<String> _getSuccessfulItemDescriptions(ConversationManager manager) {
    final descriptions = <String>[];
    
    // Look through tool responses in conversation history
    for (final message in manager.messages) {
      if (message.role == ChatCompletionMessageRole.tool && 
          message.content?.startsWith('Created: ') == true) {
        final description = message.content!.substring('Created: '.length);
        descriptions.add(description);
      }
    }
    
    return descriptions;
  }
  
  bool _shouldContinueBasedOnContext(ConversationManager manager) {
    // Check if we've had too many rounds without progress
    if (_roundNumber > 10) {
      return false;
    }
    
    // Check last assistant message for completion indicators
    final messages = manager.messages;
    if (messages.isNotEmpty) {
      final lastAssistant = messages
          .where((m) => m.role == ChatCompletionMessageRole.assistant)
          .lastOrNull;
      
      if (lastAssistant != null && lastAssistant.content != null) {
        final content = lastAssistant.content.toString().toLowerCase();
        if (content.contains('done') ||
            content.contains('complete') ||
            content.contains('all items') ||
            content.contains('that\'s all') ||
            content.contains('finished')) {
          return false;
        }
      }
    }
    
    // Continue if we're still making progress
    return true;
  }
  
  void dispose() {
    _eventController.close();
  }
}

/// Events for batch processing
sealed class BatchProcessingEvent {
  const BatchProcessingEvent();
  
  factory BatchProcessingEvent.analyzing() = AnalyzingEvent;
  factory BatchProcessingEvent.startingBatch({required int totalItems}) = StartingBatchEvent;
  factory BatchProcessingEvent.itemsCreated({
    required List<FunctionCallResult> items,
    required int totalSoFar,
  }) = ItemsCreatedEvent;
  factory BatchProcessingEvent.batchCompleted({
    required List<FunctionCallResult> results,
  }) = BatchCompletedEvent;
  factory BatchProcessingEvent.error({required String message}) = ErrorEvent;
}

class AnalyzingEvent extends BatchProcessingEvent {
  const AnalyzingEvent();
}

class StartingBatchEvent extends BatchProcessingEvent {
  const StartingBatchEvent({required this.totalItems});
  final int totalItems; // -1 if unknown
}

class ItemsCreatedEvent extends BatchProcessingEvent {
  const ItemsCreatedEvent({
    required this.items,
    required this.totalSoFar,
  });
  final List<FunctionCallResult> items;
  final int totalSoFar;
}

class BatchCompletedEvent extends BatchProcessingEvent {
  const BatchCompletedEvent({required this.results});
  final List<FunctionCallResult> results;
}

class ErrorEvent extends BatchProcessingEvent {
  const ErrorEvent({required this.message});
  final String message;
}

/// Result of a function call
class FunctionCallResult {
  const FunctionCallResult({
    required this.success,
    required this.functionName,
    required this.arguments,
    required this.originalItem,
    this.error,
  });
  
  final bool success;
  final String functionName;
  final String arguments;
  final String originalItem;
  final String? error;
  
  Map<String, dynamic> get parsedArguments {
    try {
      return jsonDecode(arguments) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}
