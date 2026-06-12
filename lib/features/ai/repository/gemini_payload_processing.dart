import 'dart:convert';

import 'package:lotti/features/ai/repository/gemini_inference_payloads.dart';
import 'package:openai_dart/openai_dart.dart';

/// Extracts thinking, visible text, tool calls, and usage metadata from
/// a complete Gemini response payload.
///
/// [turnIndex] is used for generating unique tool call IDs across turns.
ProcessedGeminiPayload processGeminiPayload(
  Map<String, dynamic> decoded, {
  required bool includeThoughts,
  int turnIndex = 0,
}) {
  final tb = StringBuffer();
  final cb = StringBuffer();
  final toolChunks = <ChatCompletionStreamMessageToolCallChunk>[];
  final signatures = <String, String>{};
  var toolIndex = 0;

  final candidates = decoded['candidates'];
  if (candidates is List && candidates.isNotEmpty) {
    final first = candidates.first;
    final content = first is Map<String, dynamic> ? first['content'] : null;
    if (content is Map<String, dynamic>) {
      final parts = content['parts'];
      if (parts is List) {
        for (final p in parts) {
          if (p is! Map<String, dynamic>) continue;
          final isThought = p['thought'] == true;
          final text = p['text'];
          if (isThought && includeThoughts) {
            if (text is String && text.isNotEmpty) tb.write(text);
          } else if (text is String && text.isNotEmpty) {
            cb.write(text);
          }
          final fc = p['functionCall'];
          if (fc is Map<String, dynamic>) {
            final name = fc['name']?.toString() ?? '';
            final args = jsonEncode(fc['args'] ?? {});
            final idx = toolIndex++;
            // Use turn-prefixed ID for uniqueness across conversation turns
            final toolCallId = 'tool_turn${turnIndex}_$idx';

            // Capture thought signature using shared helper
            final signature = extractThoughtSignature(p);
            if (signature != null) {
              signatures[toolCallId] = signature;
            }

            toolChunks.add(
              ChatCompletionStreamMessageToolCallChunk(
                index: idx,
                id: toolCallId,
                function: ChatCompletionStreamMessageFunctionCall(
                  name: name,
                  arguments: args,
                ),
              ),
            );
          }
        }
      }
    }
  }

  // Parse usage metadata
  CompletionUsage? usage;
  final usageMetadata = decoded['usageMetadata'];
  if (usageMetadata is Map<String, dynamic>) {
    final promptTokens = usageMetadata['promptTokenCount'] as int?;
    final candidatesTokens = usageMetadata['candidatesTokenCount'] as int?;
    final thoughtsTokens = usageMetadata['thoughtsTokenCount'] as int?;

    if (promptTokens != null || candidatesTokens != null) {
      usage = CompletionUsage(
        promptTokens: promptTokens,
        completionTokens: candidatesTokens,
        totalTokens: (promptTokens ?? 0) + (candidatesTokens ?? 0),
        completionTokensDetails: thoughtsTokens != null
            ? CompletionTokensDetails(reasoningTokens: thoughtsTokens)
            : null,
      );
    }
  }

  return ProcessedGeminiPayload(
    thinking: tb.toString(),
    visible: cb.toString(),
    toolChunks: toolChunks,
    signatures: signatures,
    usage: usage,
  );
}
