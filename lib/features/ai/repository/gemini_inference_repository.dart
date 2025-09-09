import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/gemini_thinking_config.dart';
import 'package:openai_dart/openai_dart.dart';

/// Minimal Gemini repository using REST to support thinking configuration and
/// tool declarations. Returns OpenAI-compatible stream chunks to integrate
/// with the existing pipeline.
class GeminiInferenceRepository {
  GeminiInferenceRepository({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  // Toggle for verbose streaming logs useful during debugging. Disabled by
  // default to avoid console noise in production.
  static const bool kVerboseStreamLogging = true;
  static const int kMaxRawChunkLogs = 3; // max raw chunk previews
  static const int kMaxRawLineLogs = 10; // max raw line previews
  static const int kRawPreviewLen = 200; // chars per preview

  bool _isFlashModel(String modelId) {
    final m = modelId.toLowerCase();
    return m.contains('flash');
  }

  /// Generate text via Gemini streaming API with thinking and function-calling support.
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
    final uri = _buildStreamGenerateContentUri(
      baseUrl: provider.baseUrl,
      model: model,
      apiKey: provider.apiKey,
    );

    final body = _buildRequestBody(
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
    var linesProcessed = 0;
    var malformedLines = 0;
    var emittedAny = false;
    var rawChunkLogs = 0;
    const rawPreviewLen = 200;
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
      String stripLeading(String src) {
        var s = src.trimLeft();
        while (s.startsWith('data:')) {
          final nl = s.indexOf('\n');
          if (nl == -1) return s; // wait for more
          s = s.substring(nl + 1).trimLeft();
        }
        while (s.isNotEmpty && (s[0] == '[' || s[0] == ']' || s[0] == ',')) {
          s = s.substring(1).trimLeft();
        }
        return s;
      }

      text = stripLeading(text);
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
          text = stripLeading(text);
          progressed = true;
          continue;
        }

        // consume processed portion and strip
        text = text.substring(end + 1);
        text = stripLeading(text);

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
          final hideThought = !answerStarted &&
              thinkingConfig.includeThoughts &&
              !_isFlashModel(model);
          if (isThought && hideThought) {
            final t = p['text'];
            if (t is String && t.isNotEmpty) {
              inThinking = true;
              thinkingBuffer.write(t);
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
                        index: 0,
                        id: 'tool_0',
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

    // Fallback: If the streaming API produced no deltas, perform a
    // non-streaming call and emit a single content/tool chunk so the UI
    // doesn't show an empty bubble.
    if (!emittedAny || !answerStarted) {
      final nonStreamingUri = _buildGenerateContentUri(
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
              ChatCompletionStreamMessageToolCallChunk? toolChunk;
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
                  toolChunk = ChatCompletionStreamMessageToolCallChunk(
                    index: 0,
                    id: 'tool_0',
                    function: ChatCompletionStreamMessageFunctionCall(
                      name: name,
                      arguments: args,
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
              if (toolChunk != null) {
                yield CreateChatCompletionStreamResponse(
                  id: 'gemini-${DateTime.now().millisecondsSinceEpoch}',
                  created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                  model: model,
                  choices: [
                    ChatCompletionStreamResponseChoice(
                      index: 0,
                      delta: ChatCompletionStreamResponseDelta(
                        toolCalls: [toolChunk],
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

  Uri _buildStreamGenerateContentUri({
    required String baseUrl,
    required String model,
    required String apiKey,
  }) {
    // Many configs reuse an OpenAI-compatible baseUrl that includes path
    // segments like '/openai/v1beta'. For Gemini native endpoints we always
    // construct the URL from the root authority to avoid duplicated segments.
    final parsed = Uri.parse(baseUrl);
    final root = Uri(
      scheme: parsed.scheme.isNotEmpty ? parsed.scheme : 'https',
      host: parsed.host,
      port: parsed.hasPort ? parsed.port : null,
    );

    final trimmed = model.trim().endsWith('/')
        ? model.trim().substring(0, model.trim().length - 1)
        : model.trim();
    final modelPath =
        trimmed.startsWith('models/') ? trimmed : 'models/$trimmed';
    // Build '/v1beta/models/{id}:streamGenerateContent?key=...'
    final path = '/v1beta/$modelPath:streamGenerateContent';
    return root.replace(
      path: path,
      queryParameters: <String, String>{'key': apiKey},
    );
  }

  Uri _buildGenerateContentUri({
    required String baseUrl,
    required String model,
    required String apiKey,
  }) {
    final parsed = Uri.parse(baseUrl);
    final root = Uri(
      scheme: parsed.scheme.isNotEmpty ? parsed.scheme : 'https',
      host: parsed.host,
      port: parsed.hasPort ? parsed.port : null,
    );
    final trimmed = model.trim().endsWith('/')
        ? model.trim().substring(0, model.trim().length - 1)
        : model.trim();
    final modelPath =
        trimmed.startsWith('models/') ? trimmed : 'models/$trimmed';
    final path = '/v1beta/$modelPath:generateContent';
    return root.replace(
      path: path,
      queryParameters: <String, String>{'key': apiKey},
    );
  }

  Map<String, dynamic> _buildRequestBody({
    required String prompt,
    required double temperature,
    required GeminiThinkingConfig thinkingConfig,
    String? systemMessage,
    int? maxTokens,
    List<ChatCompletionTool>? tools,
  }) {
    final contents = <Map<String, dynamic>>[
      {
        'role': 'user',
        'parts': [
          {'text': prompt},
        ],
      },
    ];

    final generationConfig = <String, dynamic>{
      'temperature': temperature,
      if (maxTokens != null) 'maxOutputTokens': maxTokens,
      'thinkingConfig': thinkingConfig.toJson(),
    };

    final request = <String, dynamic>{
      'contents': contents,
      'generationConfig': generationConfig,
      if (tools != null && tools.isNotEmpty)
        'tools': [
          {
            'functionDeclarations': tools
                .map((t) => {
                      'name': t.function.name,
                      if (t.function.description != null)
                        'description': t.function.description,
                      if (t.function.parameters != null)
                        'parameters': t.function.parameters,
                    })
                .toList(),
          }
        ],
    };

    if (systemMessage != null && systemMessage.trim().isNotEmpty) {
      request['systemInstruction'] = {
        'role': 'system',
        'parts': [
          {'text': systemMessage},
        ],
      };
    }

    return request;
  }

  // (unused helpers removed)
}

// no non-stream adapter
