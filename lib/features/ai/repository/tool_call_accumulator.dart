import 'package:openai_dart/openai_dart.dart';

/// Accumulates tool call chunks from streaming responses into complete tool calls.
///
/// This class handles the complexity of assembling tool calls that are streamed
/// in multiple chunks, tracking them by ID or index, and producing the final
/// list of complete tool calls.
///
/// It does not log: it runs once per streamed chunk. A caller logs the
/// outcome instead — [count] accumulated against [toToolCalls] kept.
class ToolCallAccumulator {
  final _toolCalls = <String, _AccumulatedToolCall>{};
  var _counter = 0;

  /// Process a chunk from the streaming response and accumulate any tool calls.
  void processChunk(ChatCompletionStreamResponseDelta? delta) {
    final toolCalls = delta?.toolCalls;
    if (toolCalls == null) return;

    // Special handling: if we receive multiple tool calls in one chunk all with
    // the same index, they might be complete tool calls rather than chunks
    if (toolCalls.length > 1 &&
        toolCalls.every(
          (tc) => tc.index == 0 && tc.function?.arguments != null,
        )) {
      toolCalls.forEach(_addCompleteToolCall);
    } else {
      // Normal streaming chunk processing
      toolCalls.forEach(_processToolCallChunk);
    }
  }

  /// Add a complete tool call (not chunked).
  void _addCompleteToolCall(
    ChatCompletionStreamMessageToolCallChunk toolCallChunk,
  ) {
    final explicitId = toolCallChunk.id;
    final hasExplicitId = explicitId != null && explicitId.isNotEmpty;
    final toolCallId = hasExplicitId ? explicitId : _nextSyntheticToolCallId();
    _toolCalls[toolCallId] = _AccumulatedToolCall(
      index: toolCallChunk.index ?? 0,
      functionName: toolCallChunk.function?.name ?? '',
      functionArguments: toolCallChunk.function?.arguments ?? '',
    );
  }

  /// Process a single tool call chunk, either starting a new tool call or
  /// continuing an existing one.
  void _processToolCallChunk(
    ChatCompletionStreamMessageToolCallChunk toolCallChunk,
  ) {
    final explicitId = toolCallChunk.id;
    final hasExplicitId = explicitId != null && explicitId.isNotEmpty;

    if (hasExplicitId && _toolCalls.containsKey(explicitId)) {
      // Continuation chunk that repeats the same explicit ID — append rather
      // than overwriting the accumulated state.
      _appendToToolCall(explicitId, toolCallChunk);
    } else if (hasExplicitId || toolCallChunk.function?.name != null) {
      // This is a new tool call
      final toolCallId = hasExplicitId
          ? explicitId
          : _nextSyntheticToolCallId();
      _startNewToolCall(toolCallId, toolCallChunk);
    } else if (toolCallChunk.index != null) {
      // Try to find by index if no ID
      _continueByIndex(toolCallChunk);
    } else {
      // This is a continuation of an existing tool call
      _continueLastToolCall(toolCallChunk);
    }
  }

  /// Start a new tool call entry.
  void _startNewToolCall(
    String toolCallId,
    ChatCompletionStreamMessageToolCallChunk chunk,
  ) {
    _toolCalls[toolCallId] = _AccumulatedToolCall(
      index: chunk.index ?? _toolCalls.length,
      functionName: chunk.function?.name ?? '',
      functionArguments: chunk.function?.arguments ?? '',
    );
  }

  /// Continue a tool call by finding it by index.
  void _continueByIndex(ChatCompletionStreamMessageToolCallChunk chunk) {
    final targetEntry = _toolCalls.entries
        .where((e) => e.value.index == chunk.index)
        .firstOrNull;

    if (targetEntry != null) {
      _appendToToolCall(targetEntry.key, chunk);
    }
  }

  /// Continue the most recent tool call.
  void _continueLastToolCall(ChatCompletionStreamMessageToolCallChunk chunk) {
    if (_toolCalls.isNotEmpty) {
      final lastKey = _toolCalls.keys.last;
      _appendToToolCall(lastKey, chunk);
    }
  }

  /// Append chunk data to an existing tool call.
  void _appendToToolCall(
    String key,
    ChatCompletionStreamMessageToolCallChunk chunk,
  ) {
    final existing = _toolCalls[key]!;

    if (chunk.function != null) {
      _toolCalls[key] = existing.copyWith(
        functionName: chunk.function!.name,
        functionArguments: chunk.function!.arguments != null
            ? existing.functionArguments + chunk.function!.arguments!
            : null,
      );
    }
  }

  /// Convert accumulated tool calls to a list of [ChatCompletionMessageToolCall].
  ///
  /// Only includes tool calls with valid (non-empty) arguments; the
  /// difference to [count] is how many were skipped.
  List<ChatCompletionMessageToolCall> toToolCalls() {
    final validToolCalls = <ChatCompletionMessageToolCall>[];

    for (final entry in _toolCalls.entries) {
      final toolCall = entry.value;

      if (toolCall.functionArguments.isEmpty) {
        continue;
      }

      validToolCalls.add(
        ChatCompletionMessageToolCall(
          id: entry.key,
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: toolCall.functionName,
            arguments: toolCall.functionArguments,
          ),
        ),
      );
    }

    return validToolCalls;
  }

  /// Check if any tool calls have been accumulated.
  bool get hasToolCalls => _toolCalls.isNotEmpty;

  /// Get the number of accumulated tool calls.
  int get count => _toolCalls.length;

  String _nextSyntheticToolCallId() {
    String id;
    do {
      id = 'tool_${_counter++}';
    } while (_toolCalls.containsKey(id));
    return id;
  }
}

/// Internal data class representing an accumulated tool call.
class _AccumulatedToolCall {
  const _AccumulatedToolCall({
    required this.index,
    required this.functionName,
    required this.functionArguments,
  });

  final int index;
  final String functionName;
  final String functionArguments;

  _AccumulatedToolCall copyWith({
    String? functionName,
    String? functionArguments,
  }) {
    return _AccumulatedToolCall(
      index: index,
      functionName: functionName ?? this.functionName,
      functionArguments: functionArguments ?? this.functionArguments,
    );
  }
}
