import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/model/ai_config.dart';
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
  static const int kMaxRawChunkLogs = 3; // max raw chunk previews
  static const int kMaxRawLineLogs = 10; // max raw line previews
  static const int kRawPreviewLen = 200; // chars per preview

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

    final req = http.Request('POST', uri)
      ..headers['Content-Type'] = 'application/json'
      ..headers['Accept'] =
          'application/x-ndjson, application/json, text/event-stream'
      ..body = jsonEncode(body);

    final streamed = await _httpClient.send(req);
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
      throw Exception('Gemini API error ${streamed.statusCode}: $reason');
    }

    final idPrefix = 'gemini-${DateTime.now().millisecondsSinceEpoch}';
    final created = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final thinkingBuffer = StringBuffer();
    var inThinking = false;
    var answerStarted = false;

    // Robust NDJSON/SSE parser: accumulate chunks and parse per line.
    final buffer = StringBuffer();
    const linesProcessed = 0;
    const malformedLines = 0;
    var emittedAny = false;
    var rawChunkLogs = 0;
    const rawPreviewLen = 200;
    var toolCallIndex = 0; // ensure unique IDs/indices across tool calls
    await for (final chunk in streamed.stream.transform(utf8.decoder)) {
      if (kVerboseStreamLogging && rawChunkLogs < 3) {
        final preview = chunk.length > rawPreviewLen
            ? chunk.substring(0, rawPreviewLen)
            : chunk;
        developer.log(
            'raw chunk (${chunk.length} chars): ${preview.replaceAll('\n', r'\n')}',
            name: 'GeminiInferenceRepository');
        rawChunkLogs++;
      }
      buffer.write(chunk);
      var text = buffer.toString();
      // Convert possible SSE/NDJSON/JSON-array stream into complete JSON
      // objects by scanning brace depth. Strip leading array wrappers, commas,
      // and SSE data: lines.
      text = GeminiUtils.stripLeadingFraming(text);
      var progressed = true;
      while (progressed) {
        progressed = false;
        final start = text.indexOf('{');
        if (start == -1) break;
        var depth = 0;
        var inStr = false;
        var esc = false;
        var end = -1;
        for (var i = start; i < text.length; i++) {
          final ch = text[i];
          if (inStr) {
            if (esc) {
              esc = false;
            } else if (ch == r'\') {
              esc = true;
            } else if (ch == '"') {
              inStr = false;
            }
            continue;
          }
          if (ch == '"') {
            inStr = true;
            continue;
          }
          if (ch == '{') depth++;
          if (ch == '}') {
            depth--;
            if (depth == 0) {
              end = i;
              break;
            }
          }
        }
        if (end == -1) break; // need more data

        final objStr = text.substring(start, end + 1);
        Map<String, dynamic> obj;
        try {
          obj = jsonDecode(objStr) as Map<String, dynamic>;
        } catch (_) {
          text = text.substring(end + 1);
          text = GeminiUtils.stripLeadingFraming(text);
          progressed = true;
          continue;
        }

        // consume processed portion and strip
        text = text.substring(end + 1);
        text = GeminiUtils.stripLeadingFraming(text);

        // Extract parts from this chunk
        final candidates = obj['candidates'];
        if (candidates is! List || candidates.isEmpty) {
          if (kVerboseStreamLogging) {
            final keys = obj.keys.join(',');
            developer.log('no candidates; obj keys=[$keys]',
                name: 'GeminiInferenceRepository');
          }
          progressed = true;
          continue;
        }
        final first = candidates.first;
        final content = first is Map<String, dynamic> ? first['content'] : null;
        if (content is! Map<String, dynamic>) {
          if (kVerboseStreamLogging) {
            developer.log('candidate.content missing or not a map',
                name: 'GeminiInferenceRepository');
          }
          progressed = true;
          continue;
        }
        final parts = content['parts'];
        if (parts is! List) {
          if (kVerboseStreamLogging) {
            developer.log('content.parts missing or not a list',
                name: 'GeminiInferenceRepository');
          }
          progressed = true;
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
                thinkingBuffer.write(t);
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
          progressed = true;
        }
      }
      // preserve any remainder (partial JSON line) in buffer
      buffer
        ..clear()
        ..write(text);
    }

    // Flush any remaining thinking at end of stream
    if (inThinking && thinkingBuffer.isNotEmpty) {
      emittedAny = true;
      yield CreateChatCompletionStreamResponse(
        id: 'gemini-${DateTime.now().millisecondsSinceEpoch}',
        created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
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
      developer.log(
        'Gemini stream finished. lines=$linesProcessed malformed=$malformedLines',
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
      final fallbackResp = await _httpClient.post(
        nonStreamingUri,
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      );
      if (fallbackResp.statusCode >= 200 && fallbackResp.statusCode < 300) {
        final decoded = jsonDecode(fallbackResp.body) as Map<String, dynamic>;
        // Emit thinking + text + tools in a compact form
        final candidates = decoded['candidates'];
        if (candidates is List && candidates.isNotEmpty) {
          final first = candidates.first;
          final content =
              first is Map<String, dynamic> ? first['content'] : null;
          if (content is Map<String, dynamic>) {
            final parts = content['parts'];
            if (parts is List) {
              final tb = StringBuffer();
              final cb = StringBuffer();
              final toolChunks = <ChatCompletionStreamMessageToolCallChunk>[];
              var toolIndex = 0;
              for (final p in parts) {
                if (p is! Map<String, dynamic>) continue;
                final isThought = p['thought'] == true;
                final text = p['text'];
                if (isThought && thinkingConfig.includeThoughts) {
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
              if (tb.isNotEmpty) {
                yield CreateChatCompletionStreamResponse(
                  id: 'gemini-${DateTime.now().millisecondsSinceEpoch}',
                  created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                  model: model,
                  choices: [
                    ChatCompletionStreamResponseChoice(
                      index: 0,
                      delta: ChatCompletionStreamResponseDelta(
                        content: '<thinking>\n$tb\n</thinking>\n',
                      ),
                    ),
                  ],
                );
              }
              if (cb.isNotEmpty) {
                yield CreateChatCompletionStreamResponse(
                  id: 'gemini-${DateTime.now().millisecondsSinceEpoch}',
                  created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                  model: model,
                  choices: [
                    ChatCompletionStreamResponseChoice(
                      index: 0,
                      delta: ChatCompletionStreamResponseDelta(
                        content: cb.toString(),
                      ),
                    ),
                  ],
                );
              }
              if (toolChunks.isNotEmpty) {
                yield CreateChatCompletionStreamResponse(
                  id: 'gemini-${DateTime.now().millisecondsSinceEpoch}',
                  created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                  model: model,
                  choices: [
                    ChatCompletionStreamResponseChoice(
                      index: 0,
                      delta: ChatCompletionStreamResponseDelta(
                        toolCalls: toolChunks,
                      ),
                    ),
                  ],
                );
              }
            }
          }
        }
      } else {
        if (kVerboseStreamLogging) {
          developer.log(
            'Fallback non-stream failed: ${fallbackResp.statusCode} ${fallbackResp.body}',
            name: 'GeminiInferenceRepository',
          );
        }
      }
    }
  }
}

// no non-stream adapter
