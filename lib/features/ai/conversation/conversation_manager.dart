import 'dart:async';

import 'package:lotti/features/ai/model/ai_chat_message.dart';

/// Manages AI conversations with context preservation and multi-turn support.
///
/// Features:
/// - Maintains conversation history
/// - Supports function calling
/// - Handles multi-turn interactions
/// - Provides event stream for UI updates
class ConversationManager {
  ConversationManager({
    required this.conversationId,
    this.maxTurns = 20,
    this.maxHistorySize = 100,
  });

  static const _truncationNotice =
      '[Previous messages truncated for context length]';

  final String conversationId;
  final int maxTurns;
  final int maxHistorySize;

  final List<AiChatMessage> _messages = [];
  final _eventController = StreamController<ConversationEvent>.broadcast();

  /// Thought signatures from Gemini 3 models, keyed by tool call ID.
  /// Required for multi-turn function calling to maintain reasoning context.
  final Map<String, String> _thoughtSignatures = {};

  Stream<ConversationEvent> get events => _eventController.stream;
  List<AiChatMessage> get messages => List.unmodifiable(_messages);

  /// Get all thought signatures for building subsequent Gemini requests.
  Map<String, String> get thoughtSignatures =>
      Map.unmodifiable(_thoughtSignatures);

  int get turnCount => _messages.whereType<AiUserMessage>().length;

  /// Initialize conversation with optional system message.
  void initialize({String? systemMessage}) {
    _messages.clear();
    _thoughtSignatures.clear();

    if (systemMessage != null) {
      _messages.add(AiSystemMessage(systemMessage));
    }

    _eventController.add(
      ConversationEvent.initialized(
        conversationId: conversationId,
        systemMessage: systemMessage,
      ),
    );
  }

  /// Add a user message to the conversation.
  void addUserMessage(String message) {
    _messages.add(AiUserMessage(AiUserTextContent(message)));

    _trimHistoryIfNeeded();

    if (!_eventController.isClosed) {
      _eventController.add(
        ConversationEvent.userMessage(
          message: message,
          turnNumber: turnCount,
        ),
      );
    }
  }

  /// Add an assistant message (from AI response).
  ///
  /// [signatures] contains thought signatures from Gemini 3 models,
  /// keyed by tool call ID. These must be included in subsequent
  /// requests for multi-turn function calling.
  void addAssistantMessage({
    String? content,
    List<AiToolCall>? toolCalls,
    Map<String, String>? signatures,
  }) {
    if (signatures != null) {
      _thoughtSignatures.addAll(signatures);
    }

    _messages.add(
      AiAssistantMessage(content: content, toolCalls: toolCalls),
    );

    if (!_eventController.isClosed) {
      if (toolCalls?.isNotEmpty ?? false) {
        _eventController.add(
          ConversationEvent.toolCalls(
            calls: toolCalls!,
            turnNumber: turnCount,
          ),
        );
      } else if (content != null) {
        _eventController.add(
          ConversationEvent.assistantMessage(
            message: content,
            turnNumber: turnCount,
          ),
        );
      }
    }
  }

  /// Add tool response.
  void addToolResponse({
    required String toolCallId,
    required String response,
  }) {
    _messages.add(
      AiToolResultMessage(toolCallId: toolCallId, content: response),
    );

    if (!_eventController.isClosed) {
      _eventController.add(
        ConversationEvent.toolResponse(
          toolCallId: toolCallId,
          response: response,
        ),
      );
    }
  }

  /// Check if we can continue the conversation.
  bool canContinue() {
    return turnCount < maxTurns;
  }

  /// Get messages formatted for API request.
  List<AiChatMessage> getMessagesForRequest() {
    return List.from(_messages);
  }

  /// Emit an error event.
  void emitError(String error) {
    if (!_eventController.isClosed) {
      _eventController.add(
        ConversationEvent.error(
          message: error,
          turnNumber: turnCount,
        ),
      );
    }
  }

  /// Emit thinking/processing event.
  void emitThinking() {
    if (!_eventController.isClosed) {
      _eventController.add(
        ConversationEvent.thinking(turnNumber: turnCount),
      );
    }
  }

  /// Trim history if it exceeds max size.
  void _trimHistoryIfNeeded() {
    if (_messages.length <= maxHistorySize) return;

    final hasInitialSystem =
        _messages.isNotEmpty &&
        _messages.first is AiSystemMessage &&
        !_isTruncationNotice(_messages.first);
    final minimumRetainedSize = hasInitialSystem ? 3 : 2;
    final effectiveMaxSize = maxHistorySize < minimumRetainedSize
        ? minimumRetainedSize
        : maxHistorySize;
    final keepTailCount = effectiveMaxSize - (hasInitialSystem ? 2 : 1);
    final bodyStart = hasInitialSystem ? 1 : 0;
    final bodyMessages = _messages
        .skip(bodyStart)
        .where((message) => !_isTruncationNotice(message))
        .toList();
    final tailStart = bodyMessages.length > keepTailCount
        ? bodyMessages.length - keepTailCount
        : 0;
    final hadTruncationNotice = _messages.any(_isTruncationNotice);

    if (tailStart == 0 && !hadTruncationNotice) return;

    final retainedTail = bodyMessages.skip(tailStart);
    final retainedMessages = [
      if (hasInitialSystem) _messages.first,
      const AiSystemMessage(_truncationNotice),
      ...retainedTail,
    ];

    _messages
      ..clear()
      ..addAll(retainedMessages);
  }

  bool _isTruncationNotice(AiChatMessage message) {
    return message is AiSystemMessage && message.content == _truncationNotice;
  }

  void dispose() {
    _eventController.close();
  }
}

/// Events emitted during conversation.
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

  factory ConversationEvent.thinking({required int turnNumber}) = ThinkingEvent;

  factory ConversationEvent.assistantMessage({
    required String message,
    required int turnNumber,
  }) = AssistantMessageEvent;

  factory ConversationEvent.toolCalls({
    required List<AiToolCall> calls,
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
  const ThinkingEvent({required this.turnNumber});

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
  const ToolCallsEvent({required this.calls, required this.turnNumber});

  final List<AiToolCall> calls;
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

/// Strategy for handling conversations.
abstract class ConversationStrategy {
  /// Process tool calls and determine next action.
  Future<ConversationAction> processToolCalls({
    required List<AiToolCall> toolCalls,
    required ConversationManager manager,
  });

  /// Determine if conversation should continue.
  bool shouldContinue(ConversationManager manager);

  /// Generate continuation prompt.
  String? getContinuationPrompt(ConversationManager manager);
}

/// Action to take after processing.
enum ConversationAction {
  continueConversation,
  complete,
  wait,
}
