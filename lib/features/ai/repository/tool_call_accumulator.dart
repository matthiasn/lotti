import 'dart:developer' as developer;

import 'package:lotti/features/ai/model/ai_chat_message.dart';

/// Accumulates tool-call chunks from streaming responses into complete
/// [AiToolCall]s.
///
/// Streaming providers split a single tool call across many delta chunks —
/// often only the `arguments` field is sent after the initial chunk that
/// carries `id` and `name`. This class tracks partial state keyed by tool-call
/// id (with synthetic ids when the provider doesn't supply one) and stitches
/// the deltas back into complete calls.
class ToolCallAccumulator {
  final _toolCalls = <String, _AccumulatedToolCall>{};
  var _counter = 0;

  /// Process a streaming delta's tool-call chunks and update internal state.
  void processChunk(AiStreamDelta? delta) {
    if (delta?.toolCalls == null) return;
    final toolCalls = delta!.toolCalls!;

    developer.log(
      'Tool call details: ${toolCalls.map((tc) => 'id=${tc.id}, '
          'index=${tc.index}, function=${tc.name}, '
          'hasArgs=${tc.arguments != null}').join('; ')}',
      name: 'ToolCallAccumulator',
    );

    // If multiple chunks arrive in one delta all marked index=0 and all with
    // arguments, treat them as complete tool calls rather than fragments.
    if (toolCalls.length > 1 &&
        toolCalls.every((tc) => tc.index == 0 && tc.arguments != null)) {
      developer.log(
        'Detected ${toolCalls.length} complete tool calls in single chunk',
        name: 'ToolCallAccumulator',
      );
      toolCalls.forEach(_addCompleteToolCall);
    } else {
      toolCalls.forEach(_processToolCallChunk);
    }
  }

  void _addCompleteToolCall(AiToolCallChunk chunk) {
    final explicitId = chunk.id;
    final hasExplicitId = explicitId != null && explicitId.isNotEmpty;
    final toolCallId = hasExplicitId ? explicitId : _nextSyntheticToolCallId();
    _toolCalls[toolCallId] = _AccumulatedToolCall(
      index: chunk.index ?? 0,
      functionName: chunk.name ?? '',
      functionArguments: chunk.arguments ?? '',
    );
    developer.log(
      'Added complete tool call $toolCallId: ${chunk.name}',
      name: 'ToolCallAccumulator',
    );
  }

  void _processToolCallChunk(AiToolCallChunk chunk) {
    developer.log(
      'Tool call chunk - id: ${chunk.id}, index: ${chunk.index}, '
      'function: ${chunk.name}, '
      'args length: ${chunk.arguments?.length ?? 0}',
      name: 'ToolCallAccumulator',
    );

    final explicitId = chunk.id;
    final hasExplicitId = explicitId != null && explicitId.isNotEmpty;

    if (hasExplicitId && _toolCalls.containsKey(explicitId)) {
      _appendToToolCall(explicitId, chunk);
    } else if (hasExplicitId || chunk.name != null) {
      final toolCallId = hasExplicitId
          ? explicitId
          : _nextSyntheticToolCallId();
      _startNewToolCall(toolCallId, chunk);
    } else if (chunk.index != null) {
      _continueByIndex(chunk);
    } else {
      _continueLastToolCall(chunk);
    }
  }

  void _startNewToolCall(String toolCallId, AiToolCallChunk chunk) {
    _toolCalls[toolCallId] = _AccumulatedToolCall(
      index: chunk.index ?? _toolCalls.length,
      functionName: chunk.name ?? '',
      functionArguments: chunk.arguments ?? '',
    );
    developer.log(
      'Started new tool call $toolCallId: ${chunk.name}',
      name: 'ToolCallAccumulator',
    );
  }

  void _continueByIndex(AiToolCallChunk chunk) {
    final targetEntry = _toolCalls.entries
        .where((e) => e.value.index == chunk.index)
        .firstOrNull;
    if (targetEntry != null) {
      _appendToToolCall(targetEntry.key, chunk);
      developer.log(
        'Continued tool call ${targetEntry.key} '
        '(index ${chunk.index}) with arguments chunk',
        name: 'ToolCallAccumulator',
      );
    }
  }

  void _continueLastToolCall(AiToolCallChunk chunk) {
    if (_toolCalls.isNotEmpty) {
      final lastKey = _toolCalls.keys.last;
      _appendToToolCall(lastKey, chunk);
      developer.log(
        'Continued tool call $lastKey with arguments chunk (no index)',
        name: 'ToolCallAccumulator',
      );
    }
  }

  void _appendToToolCall(String key, AiToolCallChunk chunk) {
    final existing = _toolCalls[key]!;
    _toolCalls[key] = existing.copyWith(
      functionName: chunk.name ?? existing.functionName,
      functionArguments: chunk.arguments != null
          ? existing.functionArguments + chunk.arguments!
          : null,
    );
  }

  /// Convert accumulated chunks to a list of [AiToolCall]. Skips entries that
  /// never received any arguments (treated as malformed).
  List<AiToolCall> toToolCalls() {
    final validToolCalls = <AiToolCall>[];
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
        'Creating tool call ${entry.key}: ${toolCall.functionName} '
        'with args: ${toolCall.functionArguments}',
        name: 'ToolCallAccumulator',
      );
      validToolCalls.add(
        AiToolCall(
          id: entry.key,
          name: toolCall.functionName,
          arguments: toolCall.functionArguments,
        ),
      );
    }
    developer.log(
      'Created ${validToolCalls.length} tool calls from accumulator',
      name: 'ToolCallAccumulator',
    );
    return validToolCalls;
  }

  bool get hasToolCalls => _toolCalls.isNotEmpty;
  int get count => _toolCalls.length;

  String _nextSyntheticToolCallId() {
    String id;
    do {
      id = 'tool_${_counter++}';
    } while (_toolCalls.containsKey(id));
    return id;
  }
}

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
