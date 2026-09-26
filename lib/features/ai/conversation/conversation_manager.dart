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
  int _turnCount = 0;
  String? _lastError;

  /// Thought signatures from Gemini 3 models, keyed by tool call ID.
  /// Required for multi-turn function calling to maintain reasoning context.
  final Map<String, String> _thoughtSignatures = {};

  List<ChatCompletionMessage> get messages => List.unmodifiable(_messages);

  /// Most recent inference error recorded for this conversation, if any.
  // Used by test/evaluation tooling, which `dcm check-unused-code lib` does not
  // include in its usage graph.
  // ignore: unused-code
  String? get lastError => _lastError;

  /// Clears the previous request's error before a new request begins.
  void clearLastError() => _lastError = null;

  /// Get all thought signatures for building subsequent Gemini requests.
  Map<String, String> get thoughtSignatures =>
      Map.unmodifiable(_thoughtSignatures);

  /// The number of user turns added since [initialize], continuation prompts
  /// included.
  ///
  /// It counts turns ever added, not the user messages the history still
  /// holds: trimming drops old user messages, and a count of what is left
  /// stops growing once a round's tool calls fill the history, so
  /// [canContinue] would never refuse and the loop would never end. The turn
  /// also scopes synthesized tool-call ids (`tool_turn<turn>_<n>`), which
  /// must never repeat, so it must never go back.
  int get turnCount => _turnCount;

  /// Initialize conversation with optional system message
  void initialize({String? systemMessage}) {
    _messages.clear();
    _thoughtSignatures.clear(); // Clear signatures from previous conversation
    _turnCount = 0;
    _lastError = null;

    if (systemMessage != null) {
      _messages.add(ChatCompletionMessage.system(content: systemMessage));
    }
  }

  /// Adds a user turn to the conversation, counts it in [turnCount], and
  /// trims the history if it has grown past [maxHistorySize].
  void addUserMessage(String message) {
    _messages.add(
      ChatCompletionMessage.user(
        content: ChatCompletionUserMessageContent.string(message),
      ),
    );
    _turnCount++;

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

  /// Answers every tool call of the latest assistant message that has no
  /// tool response yet with [response].
  ///
  /// A strategy that throws part-way through a batch, or a loop that ends
  /// without a strategy to run the calls, leaves calls unanswered; strict
  /// providers reject every later request whose history holds one, so the
  /// next message on this conversation would fail too.
  void answerPendingToolCalls(String response) {
    final assistantIndex = _messages.lastIndexWhere(
      (message) => message.role == ChatCompletionMessageRole.assistant,
    );
    if (assistantIndex < 0) return;
    final toolCalls = _messages[assistantIndex].mapOrNull(
      assistant: (assistant) => assistant.toolCalls,
    );
    if (toolCalls == null || toolCalls.isEmpty) return;

    final answered = {
      for (final message in _messages.skip(assistantIndex + 1))
        ?message.mapOrNull(tool: (tool) => tool.toolCallId),
    };
    for (final toolCall in toolCalls) {
      if (!answered.contains(toolCall.id)) {
        addToolResponse(toolCallId: toolCall.id, response: response);
      }
    }
  }

  /// Whether another turn fits under [maxTurns].
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
    // The retained tail must open on a user turn. A cut through a tool round
    // leaves either tool results whose assistant tool call was dropped, which
    // strict providers reject, or an assistant turn with nothing before it,
    // and Gemini requires a function call turn to follow a user turn or a
    // function response. Trimming only ever runs from [addUserMessage], so
    // the just-added user turn always survives at the tail end and this strip
    // cannot empty the tail today; the guard below future-proofs against a
    // caller that trims after a tool/assistant append.
    while (retainedTail.isNotEmpty &&
        retainedTail.first.role != ChatCompletionMessageRole.user) {
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

  /// The tools to advertise for the turn about to be sent, or null to keep
  /// whatever the caller passed to `sendMessage`.
  ///
  /// `sendMessage` otherwise fixes one tool list for the whole conversation, so
  /// a wake advertises every tool on every turn no matter what it is doing. A
  /// strategy that overrides this can open with a small, relevant set and widen
  /// as the conversation earns it, which costs no extra round trip because the
  /// turns already exist.
  ///
  /// Returning null is the default and leaves behaviour exactly as before, so
  /// strategies that do not care are unaffected.
  List<ChatCompletionTool>? toolsForTurn({
    required int turnIndex,
    required ConversationManager manager,
  }) => null;
}

/// Action to take after processing
enum ConversationAction {
  continueConversation, // Continue conversation
  complete, // Mark as complete
  wait, // Wait for user input
}
