import 'dart:async';

import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/functions/function_handler.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ollama_inference_repository.dart';
import 'package:openai_dart/openai_dart.dart';

/// Extensible batch processor using conversation-based approach
/// 
/// This processor can handle multiple function types through the FunctionHandler system
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
    required List<FunctionHandler> handlers,
    String? systemMessage,
    double temperature = 0.1,
    int maxTurns = 15,
  }) async* {
    // Create conversation
    final conversationId = conversationRepo.createConversation(
      systemMessage: systemMessage,
      maxTurns: maxTurns,
    );
    
    final manager = conversationRepo.getConversation(conversationId)!;
    
    // Track all results
    final allResults = <FunctionCallResult>[];
    
    // Listen to conversation events
    final subscription = manager.events.listen((event) {
      // We'll yield events based on conversation events
    });
    
    try {
      // Yield initial analyzing event
      yield BatchProcessingEvent.analyzing();
      
      // Create batch strategy with handlers
      final strategy = ExtensibleBatchStrategy(
        handlers: handlers,
        onItemProcessed: (result) {
          allResults.add(result);
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
}

/// Extensible batch strategy that works with multiple function handlers
class ExtensibleBatchStrategy extends ConversationStrategy {
  ExtensibleBatchStrategy({
    required this.handlers,
    required this.onItemProcessed,
  });
  
  final List<FunctionHandler> handlers;
  final void Function(FunctionCallResult) onItemProcessed;
  final _eventController = StreamController<BatchProcessingEvent>.broadcast();
  
  Stream<BatchProcessingEvent> get events => _eventController.stream;
  
  int _totalSuccessful = 0;
  int _roundNumber = 0;
  bool _hasStarted = false;
  final Map<String, List<FunctionCallResult>> _failedByHandler = {};
  final Map<String, bool> _hasRetriedByHandler = {};
  
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
    final roundResults = <FunctionCallResult>[];
    
    for (final call in toolCalls) {
      // Find the appropriate handler
      final handler = handlers.firstWhere(
        (h) => h.functionName == call.function.name,
        orElse: () => throw Exception('No handler for function: ${call.function.name}'),
      );
      
      // Process the call
      final result = handler.processFunctionCall(call);
      
      if (result.success) {
        // Check for duplicates
        if (!handler.isDuplicate(result)) {
          roundResults.add(result);
          onItemProcessed(result);
          _totalSuccessful++;
          
          // Add success response
          manager.addToolResponse(
            toolCallId: result.data['toolCallId'] as String,
            response: handler.createToolResponse(result),
          );
        } else {
          // Skip duplicate
          final desc = handler.getDescription(result) ?? 'item';
          manager.addToolResponse(
            toolCallId: result.data['toolCallId'] as String,
            response: 'Skipped: $desc (already exists)',
          );
        }
      } else {
        // Handle failure
        roundResults.add(result);
        
        // Track failed items by handler
        _failedByHandler.putIfAbsent(handler.functionName, () => []).add(result);
        
        manager.addToolResponse(
          toolCallId: result.data['toolCallId'] as String,
          response: handler.createToolResponse(result),
        );
      }
    }
    
    // Emit event for this round
    if (roundResults.isNotEmpty) {
      _eventController.add(BatchProcessingEvent.itemsProcessed(
        results: roundResults,
        totalSuccessful: _totalSuccessful,
      ));
    }
    
    // Decide whether to continue
    final shouldContinue = _shouldContinueBasedOnContext(manager);
    
    if (!shouldContinue) {
      // Emit completion
      _eventController.add(BatchProcessingEvent.batchCompleted(
        totalSuccessful: _totalSuccessful,
        totalFailed: _failedByHandler.values.expand((list) => list).length,
      ));
      return ConversationAction.complete;
    }
    
    return ConversationAction.continueConversation;
  }
  
  @override
  bool shouldContinue(ConversationManager manager) {
    return true; // Let processToolCalls decide
  }
  
  @override
  String? getContinuationPrompt(ConversationManager manager) {
    // Check if we have any failed items to retry
    final hasUnretriedFailures = _failedByHandler.entries
        .any((entry) => entry.value.isNotEmpty && !(_hasRetriedByHandler[entry.key] ?? false));
    
    if (hasUnretriedFailures) {
      // Build retry prompts for each handler with failures
      final retryPrompts = <String>[];
      
      for (final entry in _failedByHandler.entries) {
        if (entry.value.isEmpty || (_hasRetriedByHandler[entry.key] ?? false)) {
          continue;
        }
        
        final handlerName = entry.key;
        final failures = entry.value;
        final handler = handlers.firstWhere((h) => h.functionName == handlerName);
        
        // Get successful items for this handler
        final successfulDescriptions = _getSuccessfulDescriptions(manager, handlerName);
        
        // Get retry prompt from handler
        final retryPrompt = handler.getRetryPrompt(
          failedItems: failures,
          successfulDescriptions: successfulDescriptions,
        );
        
        retryPrompts.add(retryPrompt);
        _hasRetriedByHandler[handlerName] = true;
      }
      
      // Clear failed items after creating retry prompts
      _failedByHandler.clear();
      
      return retryPrompts.join('\n\n');
    }
    
    // No failures, check if we should continue
    if (_totalSuccessful == 0) {
      return 'Please use the provided functions to process the request.';
    }
    
    return '''
Great! I've successfully processed $_totalSuccessful item(s) so far.

Are there more items to process? If yes, please continue.
If all items have been processed, just say "done" or "complete".''';
  }
  
  List<String> _getSuccessfulDescriptions(ConversationManager manager, String functionName) {
    final descriptions = <String>[];
    final handler = handlers.firstWhere((h) => h.functionName == functionName);
    
    // Look through tool responses in conversation history
    for (final message in manager.messages) {
      if (message.role == ChatCompletionMessageRole.tool && 
          message.content != null) {
        // Parse successful items from this handler's responses
        final content = message.content!;
        if (content.startsWith('Created: ') || content.startsWith('Created event: ')) {
          // This is a bit hacky - in a real implementation we might want to
          // track successful results more explicitly
          final description = content.substring(content.indexOf(':') + 1).trim();
          descriptions.add(description);
        }
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
    
    // Continue if we have retries pending
    final hasUnretriedFailures = _failedByHandler.entries
        .any((entry) => entry.value.isNotEmpty && !(_hasRetriedByHandler[entry.key] ?? false));
    
    return hasUnretriedFailures || _roundNumber < 3; // Give at least 3 rounds
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
  factory BatchProcessingEvent.itemsProcessed({
    required List<FunctionCallResult> results,
    required int totalSuccessful,
  }) = ItemsProcessedEvent;
  factory BatchProcessingEvent.batchCompleted({
    required int totalSuccessful,
    required int totalFailed,
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

class ItemsProcessedEvent extends BatchProcessingEvent {
  const ItemsProcessedEvent({
    required this.results,
    required this.totalSuccessful,
  });
  final List<FunctionCallResult> results;
  final int totalSuccessful;
}

class BatchCompletedEvent extends BatchProcessingEvent {
  const BatchCompletedEvent({
    required this.totalSuccessful,
    required this.totalFailed,
  });
  final int totalSuccessful;
  final int totalFailed;
}

class ErrorEvent extends BatchProcessingEvent {
  const ErrorEvent({required this.message});
  final String message;
}