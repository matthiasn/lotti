import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/gemini_tool_call.dart';
import 'package:lotti/features/ai/repository/gemini_stream_parser.dart';
import 'package:lotti/features/ai/repository/gemini_thinking_config.dart';
import 'package:lotti/features/ai/repository/gemini_utils.dart';
import 'package:openai_dart/openai_dart.dart';

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

  /// Toggle for verbose streaming logs useful during debugging.
  /// Set to `true` to enable detailed logging of raw chunks, parsed objects,
  /// and processing metrics. Disabled by default to avoid console noise.
  static const bool kVerboseStreamLogging = false;

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
      maxTokens: maxCompletionTokens,
      tools: tools,
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
    if (kVerboseStreamLogging) {
      developer.log(
        'Gemini streaming status: ${streamed.statusCode}',
        name: 'GeminiInferenceRepository',
      );
      developer.log(
        'Response headers: ${streamed.headers}',
        name: 'GeminiInferenceRepository',
      );
    }
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
    var rawChunkLogs = 0;
    // Metrics
    final requestStart = DateTime.now();
    var chunkProcessingMicros = 0;
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
      if (kVerboseStreamLogging && rawChunkLogs < 3) {
        final preview = chunk.length > kPreviewLength
            ? chunk.substring(0, kPreviewLength)
            : chunk;
        developer.log(
            'raw chunk (${chunk.length} chars): ${preview.replaceAll('\n', r'\n')}',
            name: 'GeminiInferenceRepository');
        rawChunkLogs++;
      }
      final sw = Stopwatch()..start();
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
            if (kVerboseStreamLogging) {
              final keys = obj.keys.join(',');
              developer.log('no candidates; obj keys=[$keys]',
                  name: 'GeminiInferenceRepository');
            }
            continue;
          }
          final first = candidates.first;
          final content =
              first is Map<String, dynamic> ? first['content'] : null;
          if (content is! Map<String, dynamic>) {
            if (kVerboseStreamLogging) {
              developer.log('candidate.content missing or not a map',
                  name: 'GeminiInferenceRepository');
            }
            continue;
          }
          final parts = content['parts'];
          if (parts is! List) {
            if (kVerboseStreamLogging) {
              developer.log('content.parts missing or not a list',
                  name: 'GeminiInferenceRepository');
            }
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
                  final remaining = kMaxStreamingChars -
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
              if (kVerboseStreamLogging) {
                developer.log(
                  'Flushed thinking block',
                  name: 'GeminiInferenceRepository',
                );
              }
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
              if (kVerboseStreamLogging) {
                developer.log(
                  'Text delta (${text.length} chars)',
                  name: 'GeminiInferenceRepository',
                );
              }
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
              if (kVerboseStreamLogging) {
                developer.log(
                  'Tool call: $name',
                  name: 'GeminiInferenceRepository',
                );
              }
            }
          }
        }
        sw.stop();
        chunkProcessingMicros += sw.elapsedMicroseconds;
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
      if (kVerboseStreamLogging) {
        developer.log(
          'Flushed trailing thinking block',
          name: 'GeminiInferenceRepository',
        );
      }
    }

    if (kVerboseStreamLogging) {
      final totalLatency = DateTime.now().difference(requestStart);
      final denom = visibleChars + thinkingChars;
      final thinkingRatio = denom > 0 ? (thinkingChars / denom) : 0.0;
      developer.log(
        'Gemini stream finished. latency=${totalLatency.inMilliseconds}ms, processing=$chunkProcessingMicrosµs, '
        'visibleChars=$visibleChars, thinkingChars=$thinkingChars, thinkingRatio=${thinkingRatio.toStringAsFixed(3)}',
        name: 'GeminiInferenceRepository',
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
        final resp =
            await _httpClient.send(req).timeout(kInitialRequestTimeout);
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

  /// Generates text with full conversation history for multi-turn interactions.
  ///
  /// This method supports:
  /// - Full conversation history with user, assistant, and tool messages
  /// - Thought signatures in function calls (required for Gemini 3 multi-turn)
  /// - Thinking configuration
  /// - Function tool declarations
  ///
  /// Parameters:
  /// - [messages]: Full conversation history as OpenAI-style messages
  /// - [model]: Gemini model ID
  /// - [temperature]: Sampling temperature
  /// - [thinkingConfig]: Thinking budget and policy
  /// - [provider]: Contains base URL and API key
  /// - [thoughtSignatures]: Map of tool call IDs to signatures (for replay)
  /// - [systemMessage]: Optional system instruction
  /// - [maxCompletionTokens]: Optional output token limit
  /// - [tools]: Optional function declarations
  /// - [signatureCollector]: Optional collector for capturing new signatures
  /// Multi-turn variant that accepts full conversation history.
  ///
  /// [turnIndex] provides the current turn number for generating unique
  /// tool call IDs that don't collide across conversation turns. This prevents
  /// signature/name lookup errors when replaying multi-turn function calls.
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
      maxTokens: maxCompletionTokens,
      tools: tools,
    );

    developer.log(
      'Gemini multi-turn streamGenerateContent request to: $uri with ${messages.length} messages',
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
          'Gemini multi-turn streamGenerateContent (model=$model, baseUrl=${provider.baseUrl})',
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
          thoughtsTokens =
              usage['thoughtsTokenCount'] as int? ?? thoughtsTokens;
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
            yield _createTextChunk(
              id: idPrefix,
              created: created,
              model: model,
              text: text,
            );
            continue;
          }

          // Function call (tool) - see extractThoughtSignature() for signature handling
          if (p['functionCall'] is Map<String, dynamic>) {
            final fc = p['functionCall'] as Map<String, dynamic>;
            final name = fc['name']?.toString() ?? '';
            final args = jsonEncode(fc['args'] ?? {});

            emittedAny = true;
            final currentIndex = toolCallIndex++;
            // Use turn-prefixed ID to ensure uniqueness across conversation turns
            final turn = turnIndex ?? 0;
            final toolCallId = 'tool_turn${turn}_$currentIndex';

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
    }

    // Flush any remaining thinking
    if (inThinking && thinkingBuffer.isNotEmpty) {
      emittedAny = true;
      yield _createThinkingChunk(
        id: idPrefix,
        created: created,
        model: model,
        thinking: thinkingBuffer.toString(),
      );
    }

    // Emit usage metadata
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

    // Fallback if no content was emitted
    if (!emittedAny) {
      developer.log(
        'Gemini multi-turn stream produced no output, no fallback available for multi-turn mode',
        name: 'GeminiInferenceRepository',
      );
    }
  }

  // -------------------------------------------------------------------------
  // Image generation
  // -------------------------------------------------------------------------

  /// Generates an image using Gemini's image generation capabilities.
  ///
  /// This method uses the Gemini image generation API (Nano Banana Pro) to
  /// generate images from text prompts. The model must support image output
  /// (outputModalities includes Modality.image).
  ///
  /// Parameters:
  /// - [prompt]: The text prompt describing the image to generate.
  /// - [model]: The Gemini model ID (e.g., 'models/gemini-3-pro-image-preview').
  /// - [provider]: Contains base URL and API key.
  /// - [systemMessage]: Optional system instruction for guiding generation.
  ///
  /// Returns a [GeneratedImage] containing the image bytes and MIME type,
  /// or throws an exception if generation fails.
  Future<GeneratedImage> generateImage({
    required String prompt,
    required String model,
    required AiConfigInferenceProvider provider,
    String? systemMessage,
  }) async {
    final uri = GeminiUtils.buildGenerateContentUri(
      baseUrl: provider.baseUrl,
      model: model,
      apiKey: provider.apiKey,
    );

    final body = GeminiUtils.buildImageGenerationRequestBody(
      prompt: prompt,
      systemMessage: systemMessage,
    );

    developer.log(
      'Gemini generateImage request to: $uri',
      name: 'GeminiInferenceRepository',
    );

    final response = await _httpClient
        .post(
          uri,
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 120));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Gemini image generation error ${response.statusCode} for model "$model": ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return _extractImageFromResponse(decoded);
  }

  /// Extracts image data from a Gemini image generation response.
  ///
  /// The response contains candidates with parts that include inline_data
  /// containing the base64-encoded image and its MIME type.
  GeneratedImage _extractImageFromResponse(Map<String, dynamic> response) {
    final candidates = response['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw Exception('No candidates in image generation response');
    }

    final first = candidates.first;
    final content = first is Map<String, dynamic> ? first['content'] : null;
    if (content is! Map<String, dynamic>) {
      throw Exception('No content in image generation response');
    }

    final parts = content['parts'];
    if (parts is! List || parts.isEmpty) {
      throw Exception('No parts in image generation response');
    }

    // Look for inline_data containing the generated image
    for (final part in parts) {
      if (part is! Map<String, dynamic>) continue;

      final inlineData = part['inlineData'] ?? part['inline_data'];
      if (inlineData is Map<String, dynamic>) {
        final mimeType = inlineData['mimeType'] as String? ??
            inlineData['mime_type'] as String? ??
            'image/png';
        final data = inlineData['data'] as String?;

        if (data != null && data.isNotEmpty) {
          final bytes = base64Decode(data);
          return GeneratedImage(
            bytes: bytes,
            mimeType: mimeType,
          );
        }
      }
    }

    throw Exception('No image data found in response');
  }

  // -------------------------------------------------------------------------
  // Private payload processing
  // -------------------------------------------------------------------------

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
}

// ---------------------------------------------------------------------------
// Helper methods for creating OpenAI-compatible response chunks
// ---------------------------------------------------------------------------

/// Creates a response chunk containing a thinking block.
CreateChatCompletionStreamResponse _createThinkingChunk({
  required String id,
  required int created,
  required String model,
  required String thinking,
}) {
  return CreateChatCompletionStreamResponse(
    id: id,
    created: created,
    model: model,
    choices: [
      ChatCompletionStreamResponseChoice(
        index: 0,
        delta: ChatCompletionStreamResponseDelta(
          content: '<think>\n$thinking\n</think>\n',
        ),
      ),
    ],
  );
}

/// Creates a response chunk containing visible text content.
CreateChatCompletionStreamResponse _createTextChunk({
  required String id,
  required int created,
  required String model,
  required String text,
}) {
  return CreateChatCompletionStreamResponse(
    id: id,
    created: created,
    model: model,
    choices: [
      ChatCompletionStreamResponseChoice(
        index: 0,
        delta: ChatCompletionStreamResponseDelta(content: text),
      ),
    ],
  );
}

/// Creates a response chunk containing a tool call.
CreateChatCompletionStreamResponse _createToolCallChunk({
  required String id,
  required int created,
  required String model,
  required int index,
  required String toolCallId,
  required String name,
  required String arguments,
}) {
  return CreateChatCompletionStreamResponse(
    id: id,
    created: created,
    model: model,
    choices: [
      ChatCompletionStreamResponseChoice(
        index: 0,
        delta: ChatCompletionStreamResponseDelta(
          toolCalls: [
            ChatCompletionStreamMessageToolCallChunk(
              index: index,
              id: toolCallId,
              function: ChatCompletionStreamMessageFunctionCall(
                name: name,
                arguments: arguments,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

/// Creates a response chunk containing usage statistics.
CreateChatCompletionStreamResponse _createUsageChunk({
  required String id,
  required int created,
  required String model,
  int? promptTokens,
  int? completionTokens,
  int? thoughtsTokens,
}) {
  return CreateChatCompletionStreamResponse(
    id: id,
    created: created,
    model: model,
    choices: const [],
    usage: CompletionUsage(
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      totalTokens: (promptTokens ?? 0) + (completionTokens ?? 0),
      completionTokensDetails: thoughtsTokens != null
          ? CompletionTokensDetails(reasoningTokens: thoughtsTokens)
          : null,
    ),
  );
}

/// Captures a thought signature from a Gemini response part if present.
///
/// Logs when a signature is captured or when the first function call lacks one.
/// Uses [extractThoughtSignature] to extract the signature from the part.
void _captureSignatureIfPresent({
  required Map<String, dynamic> part,
  required String toolCallId,
  required String functionName,
  required int toolCallIndex,
  ThoughtSignatureCollector? signatureCollector,
}) {
  final thoughtSignature = extractThoughtSignature(part);
  if (thoughtSignature != null) {
    signatureCollector?.addSignature(toolCallId, thoughtSignature);
    developer.log(
      'Captured thought signature for $functionName ($toolCallId), '
      'length=${thoughtSignature.length}',
      name: 'GeminiInferenceRepository',
    );
  } else if (toolCallIndex == 0) {
    // First function call without signature - unexpected for Gemini 3
    // but may be normal for Gemini 2.x or non-thinking mode
    developer.log(
      'First function call $functionName has no thought signature',
      name: 'GeminiInferenceRepository',
    );
  }
}

// ---------------------------------------------------------------------------
// Internal data structures
// ---------------------------------------------------------------------------

/// Internal helper result for consolidated (non-streaming) Gemini payloads.
class _ProcessedPayload {
  _ProcessedPayload({
    required this.thinking,
    required this.visible,
    required this.toolChunks,
    required this.signatures,
    this.usage,
  });

  final String thinking;
  final String visible;
  final List<ChatCompletionStreamMessageToolCallChunk> toolChunks;
  final CompletionUsage? usage;

  /// Thought signatures captured from function calls, keyed by tool call ID.
  final Map<String, String> signatures;
}

/// Extracts a thought signature from a Gemini response part.
///
/// Gemini 3 models include `thoughtSignature` as a **sibling** to `functionCall`
/// at the part level (not nested inside `functionCall`). For example:
/// ```json
/// {
///   "functionCall": { "name": "...", "args": {...} },
///   "thoughtSignature": "<encrypted-signature>"
/// }
/// ```
///
/// For parallel function calls, only the first call receives a signature.
/// These signatures must be included in subsequent multi-turn requests to
/// maintain reasoning context; without them, Gemini 3 returns 400 errors.
///
/// Returns null if no signature is present (normal for Gemini 2.x or non-thinking mode).
String? extractThoughtSignature(Map<String, dynamic> part) {
  return part['thoughtSignature']?.toString();
}

// ---------------------------------------------------------------------------
// Image generation data structures
// ---------------------------------------------------------------------------

/// Represents a generated image from the Gemini image generation API.
///
/// Contains the raw image bytes and MIME type (typically 'image/png').
/// This is used as the return type for [GeminiInferenceRepository.generateImage].
class GeneratedImage {
  const GeneratedImage({
    required this.bytes,
    required this.mimeType,
  });

  /// The raw image data bytes.
  final List<int> bytes;

  /// The MIME type of the image (e.g., 'image/png', 'image/jpeg').
  final String mimeType;

  /// Returns the file extension for this image's MIME type.
  String get extension {
    switch (mimeType) {
      case 'image/jpeg':
        return 'jpg';
      case 'image/gif':
        return 'gif';
      case 'image/webp':
        return 'webp';
      case 'image/png':
      default:
        return 'png';
    }
  }
}
