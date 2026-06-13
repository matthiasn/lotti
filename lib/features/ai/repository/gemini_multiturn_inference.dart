import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/gemini_tool_call.dart';
import 'package:lotti/features/ai/repository/gemini_chunk_factories.dart';
import 'package:lotti/features/ai/repository/gemini_stream_parser.dart';
import 'package:lotti/features/ai/repository/gemini_stream_sender.dart';
import 'package:lotti/features/ai/repository/gemini_thinking_config.dart';
import 'package:lotti/features/ai/repository/gemini_utils.dart';
import 'package:openai_dart/openai_dart.dart';

/// Generates text with full conversation history for multi-turn interactions.
///
/// This supports:
/// - Full conversation history with user, assistant, and tool messages
/// - Thought signatures in function calls (required for Gemini 3 multi-turn)
/// - Thinking configuration
/// - Function tool declarations
///
/// Parameters:
/// - [sender]: HTTP stream sender with rate-limit backoff.
/// - [messages]: Full conversation history as OpenAI-style messages
/// - [model]: Gemini model ID
/// - [temperature]: Sampling temperature
/// - [thinkingConfig]: Thinking budget and policy
/// - [provider]: Contains base URL and API key
/// - [thoughtSignatures]: Map of tool call IDs to signatures (for replay)
/// - [systemMessage]: Optional system instruction
/// - [maxCompletionTokens]: Optional output token limit
/// - [tools]: Optional function declarations
/// - [toolChoice]: Optional tool-selection override
/// - [signatureCollector]: Optional collector for capturing new signatures
/// - [turnIndex]: Current turn number for generating unique tool call IDs that
///   don't collide across conversation turns. This prevents signature/name
///   lookup errors when replaying multi-turn function calls.
Stream<CreateChatCompletionStreamResponse> generateGeminiTextWithMessages({
  required GeminiStreamSender sender,
  required List<ChatCompletionMessage> messages,
  required String model,
  required double temperature,
  required GeminiThinkingConfig thinkingConfig,
  required AiConfigInferenceProvider provider,
  Map<String, String>? thoughtSignatures,
  String? systemMessage,
  int? maxCompletionTokens,
  List<ChatCompletionTool>? tools,
  ChatCompletionToolChoiceOption? toolChoice,
  ThoughtSignatureCollector? signatureCollector,
  int? turnIndex,
}) async* {
  final uri = GeminiUtils.buildStreamGenerateContentUri(
    baseUrl: provider.baseUrl,
    model: model,
    apiKey: provider.apiKey,
  );

  final body = GeminiUtils.buildMultiTurnRequestBody(
    messages: messages,
    temperature: temperature,
    thinkingConfig: thinkingConfig,
    thoughtSignatures: thoughtSignatures,
    systemMessage: systemMessage,
    modelId: model,
    maxTokens: maxCompletionTokens,
    tools: tools,
    toolChoice: toolChoice,
  );

  developer.log(
    'Gemini multi-turn streamGenerateContent request to: $uri with '
    '${messages.length} messages',
    name: 'GeminiInferenceRepository',
  );

  http.Request buildStreamRequest() {
    return http.Request('POST', uri)
      ..headers['Content-Type'] = 'application/json'
      ..headers['Accept'] =
          'application/x-ndjson, application/json, text/event-stream'
      ..body = jsonEncode(body);
  }

  final streamed = await sender.send(
    buildRequest: buildStreamRequest,
    context:
        'Gemini multi-turn streamGenerateContent (model=$model, '
        'baseUrl=${provider.baseUrl})',
  );

  if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
    final bytes = await streamed.stream.toBytes();
    final reason = utf8.decode(bytes);
    throw Exception(
      'Gemini streaming error ${streamed.statusCode} for model "$model" at '
      '${provider.baseUrl}: $reason. '
      'If rate-limited (429), wait and retry.',
    );
  }

  final now = DateTime.now();
  final idPrefix = 'gemini-${now.millisecondsSinceEpoch}';
  final created = now.millisecondsSinceEpoch ~/ 1000;

  final thinkingBuffer = StringBuffer();
  var inThinking = false;
  var answerStarted = false;

  final parser = GeminiStreamParser();
  var emittedAny = false;
  var toolCallIndex = 0;

  // Track usage metadata
  int? promptTokens;
  int? candidatesTokens;
  int? thoughtsTokens;

  await for (final chunk in streamed.stream.transform(utf8.decoder)) {
    final objs = parser.addChunk(chunk);
    for (final obj in objs) {
      // Parse usageMetadata if present
      final usage = obj['usageMetadata'];
      if (usage is Map<String, dynamic>) {
        promptTokens = usage['promptTokenCount'] as int? ?? promptTokens;
        candidatesTokens =
            usage['candidatesTokenCount'] as int? ?? candidatesTokens;
        thoughtsTokens = usage['thoughtsTokenCount'] as int? ?? thoughtsTokens;
      }

      final candidates = obj['candidates'];
      if (candidates is! List || candidates.isEmpty) continue;

      final first = candidates.first;
      final content = first is Map<String, dynamic> ? first['content'] : null;
      if (content is! Map<String, dynamic>) continue;

      final parts = content['parts'];
      if (parts is! List) continue;

      for (final p in parts) {
        if (p is! Map<String, dynamic>) continue;

        // Handle thinking parts
        final isThought = p['thought'] == true;
        if (isThought) {
          if (!answerStarted && thinkingConfig.includeThoughts) {
            final t = p['text'];
            if (t is String && t.isNotEmpty) {
              inThinking = true;
              thinkingBuffer.write(t);
            }
          }
          continue;
        }

        // Emit thinking block when transitioning to regular content
        if (inThinking) {
          emittedAny = true;
          yield createThinkingChunk(
            id: idPrefix,
            created: created,
            model: model,
            thinking: thinkingBuffer.toString(),
          );
          thinkingBuffer.clear();
          inThinking = false;
        }

        // Regular text part
        final text = p['text'];
        if (text is String && text.isNotEmpty) {
          answerStarted = true;
          emittedAny = true;
          yield createTextChunk(
            id: idPrefix,
            created: created,
            model: model,
            text: text,
          );
          continue;
        }

        // Function call (tool) - see extractThoughtSignature() for signature
        // handling
        if (p['functionCall'] is Map<String, dynamic>) {
          final fc = p['functionCall'] as Map<String, dynamic>;
          final name = fc['name']?.toString() ?? '';
          final args = jsonEncode(fc['args'] ?? {});

          emittedAny = true;
          final currentIndex = toolCallIndex++;
          // Use turn-prefixed ID to ensure uniqueness across conversation turns
          final turn = turnIndex ?? 0;
          final toolCallId = 'tool_turn${turn}_$currentIndex';

          captureSignatureIfPresent(
            part: p,
            toolCallId: toolCallId,
            functionName: name,
            toolCallIndex: currentIndex,
            signatureCollector: signatureCollector,
          );

          yield createToolCallChunk(
            id: idPrefix,
            created: created,
            model: model,
            index: currentIndex,
            toolCallId: toolCallId,
            name: name,
            arguments: args,
          );
        }
      }
    }
  }

  // Flush any remaining thinking
  if (inThinking && thinkingBuffer.isNotEmpty) {
    emittedAny = true;
    yield createThinkingChunk(
      id: idPrefix,
      created: created,
      model: model,
      thinking: thinkingBuffer.toString(),
    );
  }

  // Emit usage metadata
  if (promptTokens != null || candidatesTokens != null) {
    yield createUsageChunk(
      id: idPrefix,
      created: created,
      model: model,
      promptTokens: promptTokens,
      completionTokens: candidatesTokens,
      thoughtsTokens: thoughtsTokens,
    );
  }

  // Fallback if no content was emitted
  if (!emittedAny) {
    developer.log(
      'Gemini multi-turn stream produced no output, no fallback available for '
      'multi-turn mode',
      name: 'GeminiInferenceRepository',
    );
  }
}
