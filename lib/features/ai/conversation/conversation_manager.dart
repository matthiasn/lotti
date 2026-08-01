import 'package:openai_dart/openai_dart.dart';

/// Manages AI conversations with context preservation and multi-turn support
///
/// Features:
/// - Maintains conversation history
/// - Supports function calling
/// - Handles multi-turn interactions
/// - Flexible for various use cases
class ConversationManager {
  ConversationManager({
    this.maxTurns = 20,
    this.maxHistorySize = 100,
  });

  static const _truncationNotice =
      '[Previous messages truncated for context length]';

  final int maxTurns;
  final int maxHistorySize;

  final List<ChatCompletionMessage> _messages = [];
  String? _lastError;

  /// Thought signatures from Gemini 3 models, keyed by tool call ID.
  /// Required for multi-turn function calling to maintain reasoning context.
  final Map<String, String> _thoughtSignatures = {};

  List<ChatCompletionMessage> get messages => List.unmodifiable(_messages);

  /// Most recent inference error emitted for this conversation, if any.
  String? get lastError => _lastError;

  /// Clears the previous request's error before a new request begins.
  void clearLastError() => _lastError = null;

  /// Get all thought signatures for building subsequent Gemini requests.
  Map<String, String> get thoughtSignatures =>
      Map.unmodifiable(_thoughtSignatures);

  int get turnCount =>
      _messages.where((m) => m.role == ChatCompletionMessageRole.user).length;

  /// Initialize conversation with optional system message
  void initialize({String? systemMessage}) {
    _messages.clear();
    _thoughtSignatures.clear(); // Clear signatures from previous conversation
    _lastError = null;

    if (systemMessage != null) {
      _messages.add(ChatCompletionMessage.system(content: systemMessage));
    }
  }

  /// Add a user message to the conversation
  void addUserMessage(String message) {
    _messages.add(
      ChatCompletionMessage.user(
        content: ChatCompletionUserMessageContent.string(message),
      ),
    );

    _trimHistoryIfNeeded();
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

    _messages.add(
      ChatCompletionMessage.assistant(
        content: content,
        toolCalls: toolCalls,
      ),
    );
  }

  /// Add tool response
  void addToolResponse({
    required String toolCallId,
    required String response,
  }) {
    _messages.add(
      ChatCompletionMessage.tool(
        toolCallId: toolCallId,
        content: response,
      ),
    );
  }

  /// Check if we can continue the conversation
  bool canContinue() {
    return turnCount < maxTurns;
  }

  /// Get messages formatted for API request
  List<ChatCompletionMessage> getMessagesForRequest() {
    return _messages
        .map((message) {
          final normalized = message.mapOrNull(
            assistant: (assistant) {
              if (assistant.content == null) {
                return assistant.copyWith(content: '');
              }
              return null;
            },
          );
          return normalized ?? message;
        })
        .toList(growable: false);
  }

  /// Store the most recent inference error for this conversation.
  set lastError(String error) => _lastError = error;

  /// Trim history if it exceeds max size
  void _trimHistoryIfNeeded() {
    if (_messages.length <= maxHistorySize) return;

    final hasInitialSystem =
        _messages.isNotEmpty &&
        _messages.first.role == ChatCompletionMessageRole.system &&
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

    final retainedTail = bodyMessages.skip(tailStart).toList();
    // The retained tail must not begin with an orphan `tool` message whose
    // assistant tool_use parent was dropped by the trim above — strict
    // providers reject a tool result that has no preceding tool call. Drop
    // any such leading orphans so the tail starts on an assistant/user
    // boundary. Trimming only ever runs from [addUserMessage], so the
    // just-added user turn always survives at the tail end and this strip
    // cannot empty the tail today; the guard below future-proofs against a
    // caller that trims after a tool/assistant append.
    while (retainedTail.isNotEmpty &&
        retainedTail.first.role == ChatCompletionMessageRole.tool) {
      retainedTail.removeAt(0);
    }
    if (retainedTail.isEmpty) return;
    final retainedMessages = [
      if (hasInitialSystem) _messages.first,
      const ChatCompletionMessage.system(content: _truncationNotice),
      ...retainedTail,
    ];

    _messages
      ..clear()
      ..addAll(retainedMessages);
  }

  bool _isTruncationNotice(ChatCompletionMessage message) {
    return message.role == ChatCompletionMessageRole.system &&
        message.content == _truncationNotice;
  }
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
