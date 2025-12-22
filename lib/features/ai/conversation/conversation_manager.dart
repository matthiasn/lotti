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

  /// Thought signatures from Gemini 3 models, keyed by tool call ID.
  /// Required for multi-turn function calling to maintain reasoning context.
  final Map<String, String> _thoughtSignatures = {};

  Stream<ConversationEvent> get events => _eventController.stream;
  List<ChatCompletionMessage> get messages => List.unmodifiable(_messages);

  /// Get all thought signatures for building subsequent Gemini requests.
  Map<String, String> get thoughtSignatures =>
      Map.unmodifiable(_thoughtSignatures);

  /// Get signature for a specific tool call ID.
  String? getSignatureForToolCall(String toolCallId) =>
      _thoughtSignatures[toolCallId];

  int get turnCount =>
      _messages.where((m) => m.role == ChatCompletionMessageRole.user).length;

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

    if (!_eventController.isClosed) {
      _eventController.add(ConversationEvent.userMessage(
        message: message,
        turnNumber: turnCount,
      ));
    }
  }

  /// Add an assistant message (from AI response)
  ///
  /// [signatures] contains thought signatures from Gemini 3 models,
  /// keyed by tool call ID. These must be included in subsequent
  /// requests for multi-turn function calling.
  void addAssistantMessage({
    String? content,
    List<ChatCompletionMessageToolCall>? toolCalls,
    Map<String, String>? signatures,
  }) {
    // Store thought signatures for later use
    if (signatures != null) {
      _thoughtSignatures.addAll(signatures);
    }

    _messages.add(ChatCompletionMessage.assistant(
      content: content,
      toolCalls: toolCalls,
    ));

    if (!_eventController.isClosed) {
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

    if (!_eventController.isClosed) {
      _eventController.add(ConversationEvent.toolResponse(
        toolCallId: toolCallId,
        response: response,
      ));
    }
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
    if (!_eventController.isClosed) {
      _eventController.add(ConversationEvent.error(
        message: error,
        turnNumber: turnCount,
      ));
    }
  }

  /// Emit thinking/processing event
  void emitThinking() {
    if (!_eventController.isClosed) {
      _eventController.add(ConversationEvent.thinking(
        turnNumber: turnCount,
      ));
    }
  }

  /// Trim history if it exceeds max size
  void _trimHistoryIfNeeded() {
    if (_messages.length > maxHistorySize) {
      // Ensure maxHistorySize is at least 2 to accommodate system message and at least one other message
      final effectiveMaxSize = maxHistorySize < 2 ? 2 : maxHistorySize;

      // Keep system message if present
      final hasSystem = _messages.isNotEmpty &&
          _messages.first.role == ChatCompletionMessageRole.system;

      // Calculate how many messages to keep
      // We want final count to be effectiveMaxSize, including truncation notice
      // So keep effectiveMaxSize - 1 total messages (including system if present)
      final totalToKeep = effectiveMaxSize - 1; // -1 for truncation notice

      // Calculate how many to keep after system message (if present)
      final messagesToKeepAfterSystem =
          hasSystem ? totalToKeep - 1 : totalToKeep;

      // Ensure we keep at least one message after system
      final keepAfterSystem =
          messagesToKeepAfterSystem < 1 ? 1 : messagesToKeepAfterSystem;

      // Calculate trim range
      final start = hasSystem ? 1 : 0;
      final totalMessages = _messages.length;
      final end = totalMessages - keepAfterSystem;

      // Only trim if there are messages to remove and end > start
      if (end > start && end <= totalMessages) {
        _messages
          ..removeRange(start, end)
          // Add truncation notice
          ..insert(
            start,
            const ChatCompletionMessage.system(
              content: '[Previous messages truncated for context length]',
            ),
          );
      }
    }
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
  complete, // Mark as complete
  wait, // Wait for user input
}
