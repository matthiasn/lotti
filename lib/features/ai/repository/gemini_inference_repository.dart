import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/gemini_tool_call.dart';
import 'package:lotti/features/ai/repository/gemini_stream_parser.dart';
import 'package:lotti/features/ai/repository/gemini_thinking_config.dart';
import 'package:lotti/features/ai/repository/gemini_utils.dart';
import 'package:lotti/features/ai/util/image_processing_utils.dart';
import 'package:openai_dart/openai_dart.dart';

part 'gemini_inference_payloads.dart';

part 'gemini_multiturn_inference.dart';
part 'gemini_chunk_factories.dart';
part 'gemini_image_generation.dart';

/// Gemini inference over raw HTTP with OpenAI-compatible streaming output.
///
/// What this repository does:
/// - Calls Gemini's `:streamGenerateContent` REST endpoint directly using
///   the base URL and API key from the selected `AiConfigInferenceProvider`.
/// - Translates Gemini responses (including thinking parts and function
///   calls) into OpenAI-compatible `CreateChatCompletionStreamResponse` deltas
///   so the rest of the app can consume a uniform format.
/// - Implements robust, allocation-friendly parsing of mixed streaming
///   formats (NDJSON, SSE `data:` lines, and JSON array framing) without
///   relying on line boundaries.
/// - Handles "thinking" parts: all Gemini 2.5+ models (including Flash)
///   support thinking. When `includeThoughts=true`, emits a single
///   consolidated `<think>` block before visible content.
/// - Emits OpenAI-style tool-call chunks for Gemini `functionCall` parts and
///   ensures unique, stable IDs (`tool_#`) and indices for accumulation.
/// - Captures thought signatures from Gemini 3 function calls for potential
///   multi-turn conversation support.
/// - Parses `usageMetadata` from responses and emits usage statistics
///   (prompt tokens, completion tokens, thought tokens) in the final chunk.
/// - Provides a non-streaming fallback (`:generateContent`) that runs only
///   if the streaming path produced no events; the fallback compacts all
///   thinking, visible text, and tool calls into at most three deltas
///   (thinking, text, tools) to avoid empty responses.
///
/// The adapter is intentionally small and self-contained and uses
/// [GeminiUtils] for URI and request body construction and for minimal
/// framing cleanup.
class GeminiInferenceRepository {
  GeminiInferenceRepository({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  // -------------------------------------------------------------------------
  // Configuration constants
  // -------------------------------------------------------------------------

  /// Maximum characters to show in debug log previews and error messages.
  static const int kPreviewLength = 200;

  /// Safety cap on total characters emitted during streaming (1 million).
  ///
  /// This prevents runaway responses from consuming excessive memory or
  /// causing UI performance issues. When reached, the stream terminates
  /// early with a log message. This is a safety mechanism, not a typical
  /// limit—most responses are far smaller.
  static const int kMaxStreamingChars = 1000000;

  /// Timeout for establishing the initial streaming connection.
  /// This covers the HTTP handshake, not the full response duration.
  static const Duration kInitialRequestTimeout = Duration(seconds: 30);

  /// Timeout for non-streaming (fallback) requests.
  /// Longer than streaming since we wait for the complete response.
  static const Duration kNonStreamingTimeout = Duration(seconds: 60);

  /// Maximum retry attempts for rate-limited (429) or temporarily
  /// unavailable (503) responses.
  static const int kMaxRetries = 3;

  /// Base delay for exponential backoff on retries.
  /// Actual delay doubles with each attempt: 500ms, 1s, 2s.
  static const Duration kRetryBaseDelay = Duration(milliseconds: 500);

  /// Generates text via Gemini's streaming API with thinking and function-calling support.
  ///
  /// Parameters:
  /// - `prompt`: user content to send to the model.
  /// - `model`: Gemini model ID (e.g. `gemini-2.5-pro` or `gemini-2.5-flash`).
  /// - `temperature`: sampling temperature forwarded to Gemini.
  /// - `thinkingConfig`: budget and policy controlling whether thinking is surfaced.
  /// - `provider`: contains base URL and API key.
  /// - `systemMessage`: optional system instruction.
  /// - `maxCompletionTokens`: model-specific token cap.
  /// - `tools`: OpenAI-style function tools mapped to Gemini function declarations.
  /// - `toolChoice`: Optional OpenAI-style tool-selection override mapped to
  ///   Gemini's native function-calling config.
  /// - `signatureCollector`: optional collector for capturing thought signatures
  ///   from Gemini 3 function calls (for multi-turn conversations).
  ///
  /// Returns a stream of OpenAI-compatible deltas. The stream may emit:
  /// 1) a single `<think>` block (when `includeThoughts=true`),
  /// 2) visible text chunks,
  /// 3) tool-call chunks with unique IDs/indices for accumulation, and
  /// 4) a final chunk with usage statistics (tokens consumed).
  ///
  /// If the streaming call completes without emitting anything, a
  /// non-streaming fallback is invoked to avoid an empty response bubble.
  Stream<CreateChatCompletionStreamResponse> generateText({
    required String prompt,
    required String model,
    required double temperature,
    required GeminiThinkingConfig thinkingConfig,
    required AiConfigInferenceProvider provider,
    String? systemMessage,
    int? maxCompletionTokens,
    List<ChatCompletionTool>? tools,
    ChatCompletionToolChoiceOption? toolChoice,
    ThoughtSignatureCollector? signatureCollector,
  }) async* {
    final uri = GeminiUtils.buildStreamGenerateContentUri(
      baseUrl: provider.baseUrl,
      model: model,
      apiKey: provider.apiKey,
    );

    final body = GeminiUtils.buildRequestBody(
      prompt: prompt,
      temperature: temperature,
      thinkingConfig: thinkingConfig,
      systemMessage: systemMessage,
      modelId: model,
      maxTokens: maxCompletionTokens,
      tools: tools,
      toolChoice: toolChoice,
    );

    developer.log(
      'Gemini streamGenerateContent request to: $uri',
      name: 'GeminiInferenceRepository',
    );

    http.Request buildStreamRequest() {
      return http.Request('POST', uri)
        ..headers['Content-Type'] = 'application/json'
        ..headers['Accept'] =
            'application/x-ndjson, application/json, text/event-stream'
        ..body = jsonEncode(body);
    }

    final streamed = await _sendStreamWithRateLimitBackoff(
      buildRequest: buildStreamRequest,
      context:
          'Gemini streamGenerateContent (model=$model, baseUrl=${provider.baseUrl})',
    );
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      final bytes = await streamed.stream.toBytes();
      final reason = utf8.decode(bytes);
      throw Exception(
        'Gemini streaming error ${streamed.statusCode} for model "$model" at ${provider.baseUrl}: $reason. '
        'If rate-limited (429), wait and retry.',
      );
    }

    final now = DateTime.now();
    final idPrefix = 'gemini-${now.millisecondsSinceEpoch}';
    final created = now.millisecondsSinceEpoch ~/ 1000;

    final thinkingBuffer = StringBuffer();
    var inThinking = false;
    var answerStarted = false;

    // Robust NDJSON/SSE parser (extracted utility)
    final parser = GeminiStreamParser();
    var emittedAny = false;
    var thinkingChars = 0;
    var visibleChars = 0;
    var totalCharsEmitted = 0;
    var toolCallIndex = 0; // ensure unique IDs/indices across tool calls
    // Track usage metadata from Gemini response
    int? promptTokens;
    int? candidatesTokens;
    int? thoughtsTokens;
    int? cachedTokens;
    await for (final chunk in streamed.stream.transform(utf8.decoder)) {
      // Use extracted incremental parser to decode mixed-framing chunks
      {
        final objs = parser.addChunk(chunk);
        for (final obj in objs) {
          // Parse usageMetadata if present (Gemini includes this at root level)
          final usage = obj['usageMetadata'];
          if (usage is Map<String, dynamic>) {
            promptTokens = usage['promptTokenCount'] as int? ?? promptTokens;
            candidatesTokens =
                usage['candidatesTokenCount'] as int? ?? candidatesTokens;
            thoughtsTokens =
                usage['thoughtsTokenCount'] as int? ?? thoughtsTokens;
            cachedTokens =
                usage['cachedContentTokenCount'] as int? ?? cachedTokens;
          }

          final candidates = obj['candidates'];
          if (candidates is! List || candidates.isEmpty) {
            continue;
          }
          final first = candidates.first;
          final content = first is Map<String, dynamic>
              ? first['content']
              : null;
          if (content is! Map<String, dynamic>) {
            continue;
          }
          final parts = content['parts'];
          if (parts is! List) {
            continue;
          }

          for (final p in parts) {
            if (p is! Map<String, dynamic>) continue;

            // Accumulate thinking parts (if present and requested).
            // Gemini marks thoughts with a boolean `thought: true` and the
            // actual text in `text`.
            final isThought = p['thought'] == true;
            if (isThought) {
              // Include thoughts when requested and only before the visible
              // answer has started. Gemini 2.5+ Flash supports thinking.
              if (!answerStarted && thinkingConfig.includeThoughts) {
                final t = p['text'];
                if (t is String && t.isNotEmpty) {
                  inThinking = true;
                  // Enforce cap during accumulation
                  final remaining =
                      kMaxStreamingChars -
                      (thinkingBuffer.length + visibleChars);
                  if (remaining > 0) {
                    final toAdd = t.length > remaining ? remaining : t.length;
                    thinkingBuffer.write(t.substring(0, toAdd));
                    thinkingChars += toAdd;
                  }
                }
              }
              continue;
            }

            // Emit thinking block once we transition to regular text/content
            if (inThinking) {
              emittedAny = true;
              yield _createThinkingChunk(
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
              visibleChars += text.length;
              totalCharsEmitted = visibleChars + thinkingChars;
              yield _createTextChunk(
                id: idPrefix,
                created: created,
                model: model,
                text: text,
              );
              if (totalCharsEmitted >= kMaxStreamingChars) {
                developer.log(
                  'Max streaming char cap reached ($kMaxStreamingChars). Terminating stream early.',
                  name: 'GeminiInferenceRepository',
                );
                return; // end generator and cancel stream
              }
              continue;
            }

            // Function call (tool) - see extractThoughtSignature() for signature handling
            if (p['functionCall'] is Map<String, dynamic>) {
              final fc = p['functionCall'] as Map<String, dynamic>;
              final name = fc['name']?.toString() ?? '';
              final args = jsonEncode(fc['args'] ?? {});

              emittedAny = true;
              final currentIndex = toolCallIndex++;
              // Single-turn is always turn 0
              final toolCallId = 'tool_turn0_$currentIndex';

              _captureSignatureIfPresent(
                part: p,
                toolCallId: toolCallId,
                functionName: name,
                toolCallIndex: currentIndex,
                signatureCollector: signatureCollector,
              );

              yield _createToolCallChunk(
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
        continue; // next network chunk
      }
    }

    // Flush any remaining thinking at end of stream
    if (inThinking && thinkingBuffer.isNotEmpty) {
      emittedAny = true;
      yield _createThinkingChunk(
        id: idPrefix,
        created: created,
        model: model,
        thinking: thinkingBuffer.toString(),
      );
    }

    // Emit final response with usage metadata if available
    if (promptTokens != null || candidatesTokens != null) {
      yield _createUsageChunk(
        id: idPrefix,
        created: created,
        model: model,
        promptTokens: promptTokens,
        completionTokens: candidatesTokens,
        thoughtsTokens: thoughtsTokens,
      );
    }

    // Fallback: If the streaming API produced no deltas at all, perform a
    // non-streaming call and emit chunks so the UI doesn't show an empty
    // bubble. If we already emitted anything (thinking/text/tool), skip
    // fallback to avoid duplicate output.
    if (!emittedAny) {
      final nonStreamingUri = GeminiUtils.buildGenerateContentUri(
        baseUrl: provider.baseUrl,
        model: model,
        apiKey: provider.apiKey,
      );
      final fallbackResp = await _httpClient
          .post(
            nonStreamingUri,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(kNonStreamingTimeout);
      if (fallbackResp.statusCode >= 200 && fallbackResp.statusCode < 300) {
        final decoded = jsonDecode(fallbackResp.body) as Map<String, dynamic>;
        final payload = _processGeminiPayload(
          decoded,
          includeThoughts: thinkingConfig.includeThoughts,
        );

        // Add captured signatures to collector
        if (signatureCollector != null && payload.signatures.isNotEmpty) {
          for (final entry in payload.signatures.entries) {
            signatureCollector.addSignature(entry.key, entry.value);
          }
        }

        if (payload.thinking.isNotEmpty) {
          yield _createThinkingChunk(
            id: idPrefix,
            created: created,
            model: model,
            thinking: payload.thinking,
          );
        }
        if (payload.visible.isNotEmpty) {
          yield _createTextChunk(
            id: idPrefix,
            created: created,
            model: model,
            text: payload.visible,
          );
        }
        if (payload.toolChunks.isNotEmpty) {
          yield CreateChatCompletionStreamResponse(
            id: idPrefix,
            created: created,
            model: model,
            choices: [
              ChatCompletionStreamResponseChoice(
                index: 0,
                delta: ChatCompletionStreamResponseDelta(
                  toolCalls: payload.toolChunks,
                ),
              ),
            ],
          );
        }
        // Emit usage for fallback response
        if (payload.usage != null) {
          yield CreateChatCompletionStreamResponse(
            id: idPrefix,
            created: created,
            model: model,
            choices: const [],
            usage: payload.usage,
          );
        }
      } else {
        developer.log(
          'Gemini non-stream fallback failed: HTTP ${fallbackResp.statusCode} for model "$model" at ${provider.baseUrl}. '
          'Body preview: ${fallbackResp.body.substring(0, fallbackResp.body.length > kPreviewLength ? kPreviewLength : fallbackResp.body.length)}. '
          'If this is a transient error or rate limit, please try again.',
          name: 'GeminiInferenceRepository',
        );
      }
    }
  }

  /// Send a HTTP streamed request with exponential backoff for rate limiting
  /// (429/503) and an initial handshake timeout. Builds a fresh request per attempt.
  Future<http.StreamedResponse> _sendStreamWithRateLimitBackoff({
    required http.Request Function() buildRequest,
    required String context,
    int maxRetries = kMaxRetries,
    Duration baseDelay = kRetryBaseDelay,
  }) async {
    var attempt = 0;
    while (true) {
      attempt++;
      try {
        final req = buildRequest();
        final resp = await _httpClient
            .send(req)
            .timeout(kInitialRequestTimeout);
        if (resp.statusCode == 429 || resp.statusCode == 503) {
          if (attempt > maxRetries) return resp; // let caller inspect body
          // Honor Retry-After header if present (seconds)
          final retryAfter = resp.headers['retry-after'];
          Duration delay;
          if (retryAfter != null) {
            final secs = int.tryParse(retryAfter.trim());
            delay = secs != null
                ? Duration(seconds: secs)
                : baseDelay * (1 << (attempt - 1));
          } else {
            delay = baseDelay * (1 << (attempt - 1));
          }
          developer.log(
            'Rate limited (${resp.statusCode}) during $context; retrying in ${delay.inMilliseconds}ms (attempt $attempt/$maxRetries)...',
            name: 'GeminiInferenceRepository',
          );
          await Future<void>.delayed(delay);
          continue;
        }
        return resp;
      } on TimeoutException {
        if (attempt > maxRetries) rethrow;
        final delay = baseDelay * (1 << (attempt - 1));
        developer.log(
          'Timeout during $context; retrying in ${delay.inMilliseconds}ms (attempt $attempt/$maxRetries)...',
          name: 'GeminiInferenceRepository',
        );
        await Future<void>.delayed(delay);
      }
    }
  }

  /// Processes a decoded Gemini response (non-streaming) into compact outputs.
  ///
  /// This is used by the fallback path when streaming produces no events.
  /// Extracts thinking, visible text, tool calls, and usage metadata from
  /// a complete Gemini response payload.
  ///
  /// [turnIndex] is used for generating unique tool call IDs across turns.
  static _ProcessedPayload _processGeminiPayload(
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

    return _ProcessedPayload(
      thinking: tb.toString(),
      visible: cb.toString(),
      toolChunks: toolChunks,
      signatures: signatures,
      usage: usage,
    );
  }

  /// Multi-turn streaming over an explicit message history. Thin delegator
  /// to [GeminiMultiTurnInference.generateTextWithMessagesImpl] so the
  /// method remains a mockable class member.
  Stream<CreateChatCompletionStreamResponse> generateTextWithMessages({
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
  }) => generateTextWithMessagesImpl(
    messages: messages,
    model: model,
    temperature: temperature,
    thinkingConfig: thinkingConfig,
    provider: provider,
    thoughtSignatures: thoughtSignatures,
    systemMessage: systemMessage,
    maxCompletionTokens: maxCompletionTokens,
    tools: tools,
    toolChoice: toolChoice,
    signatureCollector: signatureCollector,
    turnIndex: turnIndex,
  );

  /// Image generation. Thin delegator to
  /// [GeminiImageGeneration.generateImageImpl] so the method remains a
  /// mockable class member.
  Future<GeneratedImage> generateImage({
    required String prompt,
    required String model,
    required AiConfigInferenceProvider provider,
    String? systemMessage,
    List<ProcessedReferenceImage>? referenceImages,
  }) => generateImageImpl(
    prompt: prompt,
    model: model,
    provider: provider,
    systemMessage: systemMessage,
    referenceImages: referenceImages,
  );
}

// ---------------------------------------------------------------------------
// Internal data structures
// ---------------------------------------------------------------------------
