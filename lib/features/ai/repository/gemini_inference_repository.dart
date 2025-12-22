import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/model/ai_config.dart';
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
/// - Handles "thinking" parts based on feature flags and model type:
///   - Non-flash models: optionally surface a single consolidated
///     `<thinking>` block before visible content when `includeThoughts=true`.
///   - Flash models: thoughts are always hidden and never emitted.
/// - Emits OpenAI-style tool-call chunks for Gemini `functionCall` parts and
///   ensures unique, stable IDs (`tool_#`) and indices for accumulation.
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

  // Toggle for verbose streaming logs useful during debugging. Disabled by
  // default to avoid console noise in production.
  static const bool kVerboseStreamLogging = false;
  // Preview length for debug logging and error previews
  static const int kPreviewLength = 200;

  // Centralized caps and timeouts
  static const int kMaxStreamingChars = 1000000; // 1M safety cap
  static const Duration kInitialRequestTimeout = Duration(seconds: 30);
  static const Duration kNonStreamingTimeout = Duration(seconds: 60);
  static const int kMaxRetries = 3;
  static const Duration kRetryBaseDelay = Duration(milliseconds: 500);

  bool _isFlashModel(String modelId) => GeminiUtils.isFlashModel(modelId);

  /// Generates text via Gemini's streaming API with thinking and function-calling support.
  ///
  /// Parameters:
  /// - `prompt`: user content to send to the model.
  /// - `model`: Gemini model ID (e.g. `gemini-2.5-pro` or `gemini-2.5-flash`).
  /// - `temperature`: sampling temperature forwarded to Gemini.
  /// - `thinkingConfig`: budget and policy controlling whether thinking is
  ///   surfaced for non-flash models.
  /// - `provider`: contains base URL and API key.
  /// - `systemMessage`: optional system instruction.
  /// - `maxCompletionTokens`: model-specific token cap.
  /// - `tools`: OpenAI-style function tools mapped to Gemini function declarations.
  ///
  /// Returns a stream of OpenAI-compatible deltas. The stream may emit up to
  /// three logical segments:
  /// 1) a single `<thinking>` block (when enabled on non-flash models),
  /// 2) visible text chunks, and
  /// 3) tool-call chunks with unique IDs/indices for accumulation.
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
              // Include thoughts only for non-flash models when requested and
              // only before the visible answer has started. Otherwise, drop
              // thought parts entirely (do not surface as regular text).
              if (!answerStarted &&
                  thinkingConfig.includeThoughts &&
                  !_isFlashModel(model)) {
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
              yield CreateChatCompletionStreamResponse(
                id: idPrefix,
                created: created,
                model: model,
                choices: [
                  ChatCompletionStreamResponseChoice(
                    index: 0,
                    delta: ChatCompletionStreamResponseDelta(
                      content: '<thinking>\n$thinkingBuffer\n</thinking>\n',
                    ),
                  ),
                ],
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
              yield CreateChatCompletionStreamResponse(
                id: idPrefix,
                created: created,
                model: model,
                choices: [
                  ChatCompletionStreamResponseChoice(
                    index: 0,
                    delta: ChatCompletionStreamResponseDelta(content: text),
                  ),
                ],
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

            // Function call (tool)
            if (p['functionCall'] is Map<String, dynamic>) {
              final fc = p['functionCall'] as Map<String, dynamic>;
              final name = fc['name']?.toString() ?? '';
              final args = jsonEncode(fc['args'] ?? {});
              emittedAny = true;
              final currentIndex = toolCallIndex++;
              yield CreateChatCompletionStreamResponse(
                id: idPrefix,
                created: created,
                model: model,
                choices: [
                  ChatCompletionStreamResponseChoice(
                    index: 0,
                    delta: ChatCompletionStreamResponseDelta(
                      toolCalls: [
                        ChatCompletionStreamMessageToolCallChunk(
                          index: currentIndex,
                          id: 'tool_$currentIndex',
                          function: ChatCompletionStreamMessageFunctionCall(
                            name: name,
                            arguments: args,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
      yield CreateChatCompletionStreamResponse(
        id: idPrefix,
        created: created,
        model: model,
        choices: [
          ChatCompletionStreamResponseChoice(
            index: 0,
            delta: ChatCompletionStreamResponseDelta(
              content: '<thinking>\n$thinkingBuffer\n</thinking>\n',
            ),
          ),
        ],
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
          includeThoughts:
              thinkingConfig.includeThoughts && !_isFlashModel(model),
        );
        if (payload.thinking.isNotEmpty) {
          yield CreateChatCompletionStreamResponse(
            id: idPrefix,
            created: created,
            model: model,
            choices: [
              ChatCompletionStreamResponseChoice(
                index: 0,
                delta: ChatCompletionStreamResponseDelta(
                  content: '<thinking>\n${payload.thinking}\n</thinking>\n',
                ),
              ),
            ],
          );
        }
        if (payload.visible.isNotEmpty) {
          yield CreateChatCompletionStreamResponse(
            id: idPrefix,
            created: created,
            model: model,
            choices: [
              ChatCompletionStreamResponseChoice(
                index: 0,
                delta: ChatCompletionStreamResponseDelta(
                  content: payload.visible,
                ),
              ),
            ],
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
}

/// Internal helper result for consolidated (non-streaming) Gemini payloads.
class _ProcessedPayload {
  _ProcessedPayload({
    required this.thinking,
    required this.visible,
    required this.toolChunks,
  });

  final String thinking;
  final String visible;
  final List<ChatCompletionStreamMessageToolCallChunk> toolChunks;
}

/// Processes a decoded Gemini response (non-streaming) into compact outputs.
_ProcessedPayload _processGeminiPayload(
  Map<String, dynamic> decoded, {
  required bool includeThoughts,
}) {
  final tb = StringBuffer();
  final cb = StringBuffer();
  final toolChunks = <ChatCompletionStreamMessageToolCallChunk>[];
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
            toolChunks.add(
              ChatCompletionStreamMessageToolCallChunk(
                index: idx,
                id: 'tool_$idx',
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
  return _ProcessedPayload(
    thinking: tb.toString(),
    visible: cb.toString(),
    toolChunks: toolChunks,
  );
}

// no non-stream adapter
