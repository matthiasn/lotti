import 'dart:async';

import 'package:openai_dart/openai_dart.dart';

/// Manages AI conversations with context preservation and multi-turn support
/// 
/// Features:
/// - Maintains conversation history
/// - Supports function calling
/// - Handles multi-turn interactions
/// - Provides event stream for UI updates
/// - Flexible for various use cases
class ConversationManager {
  ConversationManager({
    required this.conversationId,
    this.maxTurns = 20,
    this.maxHistorySize = 100,
  });

  final String conversationId;
  final int maxTurns;
  final int maxHistorySize;

  final List<ChatCompletionMessage> _messages = [];
  final _eventController = StreamController<ConversationEvent>.broadcast();
  
  Stream<ConversationEvent> get events => _eventController.stream;
  List<ChatCompletionMessage> get messages => List.unmodifiable(_messages);
  int get turnCount => _messages.where((m) => m.role == ChatCompletionMessageRole.user).length;
  
  /// Initialize conversation with optional system message
  void initialize({String? systemMessage}) {
    _messages.clear();
    
    if (systemMessage != null) {
      _messages.add(ChatCompletionMessage.system(content: systemMessage));
    }
    
    _eventController.add(ConversationEvent.initialized(
      conversationId: conversationId,
      systemMessage: systemMessage,
    ));
  }
  
  /// Add a user message to the conversation
  void addUserMessage(String message) {
    _messages.add(ChatCompletionMessage.user(
      content: ChatCompletionUserMessageContent.string(message),
    ));
    
    _trimHistoryIfNeeded();
    
    _eventController.add(ConversationEvent.userMessage(
      message: message,
      turnNumber: turnCount,
    ));
  }
  
  /// Add an assistant message (from AI response)
  void addAssistantMessage({
    String? content,
    List<ChatCompletionMessageToolCall>? toolCalls,
  }) {
    _messages.add(ChatCompletionMessage.assistant(
      content: content,
      toolCalls: toolCalls,
    ));
    
    if (toolCalls?.isNotEmpty ?? false) {
      _eventController.add(ConversationEvent.toolCalls(
        calls: toolCalls!,
        turnNumber: turnCount,
      ));
    } else if (content != null) {
      _eventController.add(ConversationEvent.assistantMessage(
        message: content,
        turnNumber: turnCount,
      ));
    }
  }
  
  /// Add tool response
  void addToolResponse({
    required String toolCallId,
    required String response,
  }) {
    _messages.add(ChatCompletionMessage.tool(
      toolCallId: toolCallId,
      content: response,
    ));
    
    _eventController.add(ConversationEvent.toolResponse(
      toolCallId: toolCallId,
      response: response,
    ));
  }
  
  /// Check if we can continue the conversation
  bool canContinue() {
    return turnCount < maxTurns;
  }
  
  /// Get messages formatted for API request
  List<ChatCompletionMessage> getMessagesForRequest() {
    return List.from(_messages);
  }
  
  /// Emit an error event
  void emitError(String error) {
    _eventController.add(ConversationEvent.error(
      message: error,
      turnNumber: turnCount,
    ));
  }
  
  /// Emit thinking/processing event
  void emitThinking() {
    _eventController.add(ConversationEvent.thinking(
      turnNumber: turnCount,
    ));
  }
  
  /// Trim history if it exceeds max size
  void _trimHistoryIfNeeded() {
    if (_messages.length > maxHistorySize) {
      // Keep system message if present
      final hasSystem = _messages.isNotEmpty && 
                       _messages.first.role == ChatCompletionMessageRole.system;
      
      final trimCount = _messages.length - maxHistorySize + 10; // Leave some buffer
      
      _messages.removeRange(
        hasSystem ? 1 : 0,
        trimCount,
      );
      
      // Add truncation notice
      _messages.insert(
        hasSystem ? 1 : 0,
        ChatCompletionMessage.system(
          content: '[Previous messages truncated for context length]',
        ),
      );
    }
  }
  
  /// Export conversation as string
  String exportAsString() {
    final buffer = StringBuffer();
    
    for (final message in _messages) {
      final role = message.role.name.toUpperCase();
      final content = message.content ?? '(function calls)';
      buffer.writeln('$role: $content');
    }
    
    return buffer.toString();
  }
  
  void dispose() {
    _eventController.close();
  }
}

/// Events emitted during conversation
sealed class ConversationEvent {
  const ConversationEvent();
  
  factory ConversationEvent.initialized({
    required String conversationId,
    String? systemMessage,
  }) = ConversationInitializedEvent;
  
  factory ConversationEvent.userMessage({
    required String message,
    required int turnNumber,
  }) = UserMessageEvent;
  
  factory ConversationEvent.thinking({
    required int turnNumber,
  }) = ThinkingEvent;
  
  factory ConversationEvent.assistantMessage({
    required String message,
    required int turnNumber,
  }) = AssistantMessageEvent;
  
  factory ConversationEvent.toolCalls({
    required List<ChatCompletionMessageToolCall> calls,
    required int turnNumber,
  }) = ToolCallsEvent;
  
  factory ConversationEvent.toolResponse({
    required String toolCallId,
    required String response,
  }) = ToolResponseEvent;
  
  factory ConversationEvent.error({
    required String message,
    required int turnNumber,
  }) = ConversationErrorEvent;
}

class ConversationInitializedEvent extends ConversationEvent {
  const ConversationInitializedEvent({
    required this.conversationId,
    this.systemMessage,
  });
  
  final String conversationId;
  final String? systemMessage;
}

class UserMessageEvent extends ConversationEvent {
  const UserMessageEvent({
    required this.message,
    required this.turnNumber,
  });
  
  final String message;
  final int turnNumber;
}

class ThinkingEvent extends ConversationEvent {
  const ThinkingEvent({
    required this.turnNumber,
  });
  
  final int turnNumber;
}

class AssistantMessageEvent extends ConversationEvent {
  const AssistantMessageEvent({
    required this.message,
    required this.turnNumber,
  });
  
  final String message;
  final int turnNumber;
}

class ToolCallsEvent extends ConversationEvent {
  const ToolCallsEvent({
    required this.calls,
    required this.turnNumber,
  });
  
  final List<ChatCompletionMessageToolCall> calls;
  final int turnNumber;
}

class ToolResponseEvent extends ConversationEvent {
  const ToolResponseEvent({
    required this.toolCallId,
    required this.response,
  });
  
  final String toolCallId;
  final String response;
}

class ConversationErrorEvent extends ConversationEvent {
  const ConversationErrorEvent({
    required this.message,
    required this.turnNumber,
  });
  
  final String message;
  final int turnNumber;
}

/// Strategy for handling conversations
abstract class ConversationStrategy {
  /// Process tool calls and determine next action
  Future<ConversationAction> processToolCalls({
    required List<ChatCompletionMessageToolCall> toolCalls,
    required ConversationManager manager,
  });
  
  /// Determine if conversation should continue
  bool shouldContinue(ConversationManager manager);
  
  /// Generate continuation prompt
  String? getContinuationPrompt(ConversationManager manager);
}

/// Action to take after processing
enum ConversationAction {
  continueConversation, // Continue conversation
  complete,             // Mark as complete
  wait,                 // Wait for user input
}

/// Batch processing strategy for checklist items
class BatchChecklistStrategy extends ConversationStrategy {
  BatchChecklistStrategy({
    required this.targetItemCount,
    this.itemDescriptions = const [],
  });
  
  final int targetItemCount;
  final List<String> itemDescriptions;
  final List<String> _createdItems = [];
  
  List<String> get createdItems => List.unmodifiable(_createdItems);
  
  @override
  Future<ConversationAction> processToolCalls({
    required List<ChatCompletionMessageToolCall> toolCalls,
    required ConversationManager manager,
  }) async {
    // Process each tool call
    for (final call in toolCalls) {
      if (call.function.name == 'createChecklistItem') {
        // Extract item description from arguments
        // Note: In production, parse JSON properly
        _createdItems.add(call.function.arguments);
        
        // Add tool response
        manager.addToolResponse(
          toolCallId: call.id,
          response: 'Created checklist item',
        );
      }
    }
    
    return shouldContinue(manager) 
      ? ConversationAction.continueConversation 
      : ConversationAction.complete;
  }
  
  @override
  bool shouldContinue(ConversationManager manager) {
    return _createdItems.length < targetItemCount && manager.canContinue();
  }
  
  @override
  String? getContinuationPrompt(ConversationManager manager) {
    if (!shouldContinue(manager)) return null;
    
    final remaining = targetItemCount - _createdItems.length;
    return '''
Excellent! I've created ${_createdItems.length} checklist item(s).

There are $remaining more items to create. Please continue creating the remaining items.''';
  }
}
