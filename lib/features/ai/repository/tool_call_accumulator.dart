import 'dart:developer' as developer;

import 'package:openai_dart/openai_dart.dart';

/// Accumulates tool call chunks from streaming responses into complete tool calls.
///
/// This class handles the complexity of assembling tool calls that are streamed
/// in multiple chunks, tracking them by ID or index, and producing the final
/// list of complete tool calls.
class ToolCallAccumulator {
  final _toolCalls = <String, _AccumulatedToolCall>{};
  var _counter = 0;

  /// Process a chunk from the streaming response and accumulate any tool calls.
  void processChunk(ChatCompletionStreamResponseDelta? delta) {
    if (delta?.toolCalls == null) return;

    developer.log(
      'Tool call details: ${delta!.toolCalls!.map((tc) => 'id=${tc.id}, '
          'index=${tc.index}, function=${tc.function?.name}, '
          'hasArgs=${tc.function?.arguments != null}').join('; ')}',
      name: 'ToolCallAccumulator',
    );

    // Special handling: if we receive multiple tool calls in one chunk all with
    // the same index, they might be complete tool calls rather than chunks
    if (delta.toolCalls!.length > 1 &&
        delta.toolCalls!
            .every((tc) => tc.index == 0 && tc.function?.arguments != null)) {
      developer.log(
        'Detected ${delta.toolCalls!.length} complete tool calls in single chunk',
        name: 'ToolCallAccumulator',
      );

      delta.toolCalls!.forEach(_addCompleteToolCall);
    } else {
      // Normal streaming chunk processing
      delta.toolCalls!.forEach(_processToolCallChunk);
    }
  }

  /// Add a complete tool call (not chunked).
  void _addCompleteToolCall(
      ChatCompletionStreamMessageToolCallChunk toolCallChunk) {
    final toolCallId = 'tool_${_counter++}';
    _toolCalls[toolCallId] = _AccumulatedToolCall(
      id: toolCallId,
      index: toolCallChunk.index ?? 0,
      type: toolCallChunk.type?.toString() ?? 'function',
      functionName: toolCallChunk.function?.name ?? '',
      functionArguments: toolCallChunk.function?.arguments ?? '',
    );
    developer.log(
      'Added complete tool call $toolCallId: ${toolCallChunk.function?.name}',
      name: 'ToolCallAccumulator',
    );
  }

  /// Process a single tool call chunk, either starting a new tool call or
  /// continuing an existing one.
  void _processToolCallChunk(
      ChatCompletionStreamMessageToolCallChunk toolCallChunk) {
    developer.log(
      'Tool call chunk - id: ${toolCallChunk.id}, index: ${toolCallChunk.index}, '
      'type: ${toolCallChunk.type}, function: ${toolCallChunk.function?.name}, '
      'args length: ${toolCallChunk.function?.arguments?.length ?? 0}',
      name: 'ToolCallAccumulator',
    );

    // If this chunk has an ID or has function data, it's starting a new tool call
    var toolCallId = toolCallChunk.id;

    // Generate ID if not provided or if it's an empty string
    if (toolCallId == null || toolCallId.isEmpty) {
      toolCallId = 'tool_${_counter++}';
    }

    if (toolCallChunk.id != null || toolCallChunk.function?.name != null) {
      // This is a new tool call
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
      String toolCallId, ChatCompletionStreamMessageToolCallChunk chunk) {
    _toolCalls[toolCallId] = _AccumulatedToolCall(
      id: toolCallId,
      index: chunk.index ?? _toolCalls.length,
      type: chunk.type?.toString() ?? 'function',
      functionName: chunk.function?.name ?? '',
      functionArguments: chunk.function?.arguments ?? '',
    );
    developer.log(
      'Started new tool call $toolCallId: ${chunk.function?.name}',
      name: 'ToolCallAccumulator',
    );
  }

  /// Continue a tool call by finding it by index.
  void _continueByIndex(ChatCompletionStreamMessageToolCallChunk chunk) {
    final targetEntry = _toolCalls.entries
        .where((e) => e.value.index == chunk.index)
        .firstOrNull;

    if (targetEntry != null) {
      _appendToToolCall(targetEntry.key, chunk);
      developer.log(
        'Continued tool call ${targetEntry.key} (index ${chunk.index}) with arguments chunk',
        name: 'ToolCallAccumulator',
      );
    }
  }

  /// Continue the most recent tool call.
  void _continueLastToolCall(ChatCompletionStreamMessageToolCallChunk chunk) {
    if (_toolCalls.isNotEmpty) {
      final lastKey = _toolCalls.keys.last;
      _appendToToolCall(lastKey, chunk);
      developer.log(
        'Continued tool call $lastKey with arguments chunk (no index)',
        name: 'ToolCallAccumulator',
      );
    }
  }

  /// Append chunk data to an existing tool call.
  void _appendToToolCall(
      String key, ChatCompletionStreamMessageToolCallChunk chunk) {
    final existing = _toolCalls[key]!;

    if (chunk.function != null) {
      _toolCalls[key] = existing.copyWith(
        functionName: chunk.function!.name ?? existing.functionName,
        functionArguments: chunk.function!.arguments != null
            ? existing.functionArguments + chunk.function!.arguments!
            : null,
      );
    }
  }

  /// Convert accumulated tool calls to a list of [ChatCompletionMessageToolCall].
  ///
  /// Only includes tool calls with valid (non-empty) arguments.
  List<ChatCompletionMessageToolCall> toToolCalls() {
    final validToolCalls = <ChatCompletionMessageToolCall>[];

    for (final entry in _toolCalls.entries) {
      final toolCall = entry.value;

      if (toolCall.functionArguments.isEmpty) {
        developer.log(
          'Skipping tool call ${entry.key} - no valid arguments',
          name: 'ToolCallAccumulator',
        );
        continue;
      }

      developer.log(
        'Creating tool call ${entry.key}: ${toolCall.functionName} with args: ${toolCall.functionArguments}',
        name: 'ToolCallAccumulator',
      );

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

    developer.log(
      'Created ${validToolCalls.length} tool calls from accumulator',
      name: 'ToolCallAccumulator',
    );

    return validToolCalls;
  }

  /// Check if any tool calls have been accumulated.
  bool get hasToolCalls => _toolCalls.isNotEmpty;

  /// Get the number of accumulated tool calls.
  int get count => _toolCalls.length;
}

/// Internal data class representing an accumulated tool call.
class _AccumulatedToolCall {
  const _AccumulatedToolCall({
    required this.id,
    required this.index,
    required this.type,
    required this.functionName,
    required this.functionArguments,
  });

  final String id;
  final int index;
  final String type;
  final String functionName;
  final String functionArguments;

  _AccumulatedToolCall copyWith({
    String? functionName,
    String? functionArguments,
  }) {
    return _AccumulatedToolCall(
      id: id,
      index: index,
      type: type,
      functionName: functionName ?? this.functionName,
      functionArguments: functionArguments ?? this.functionArguments,
    );
  }
}
