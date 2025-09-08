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
      ..body = jsonEncode(body);

    final streamed = await _httpClient.send(req);
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      final bytes = await streamed.stream.toBytes();
      final reason = utf8.decode(bytes);
      throw Exception('Gemini API error ${streamed.statusCode}: $reason');
    }

    final idPrefix = 'gemini-${DateTime.now().millisecondsSinceEpoch}';
    final created = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final thinkingBuffer = StringBuffer();
    var inThinking = false;

    await for (final line in streamed.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (line.trim().isEmpty) continue;
      Map<String, dynamic> obj;
      try {
        obj = jsonDecode(line) as Map<String, dynamic>;
      } catch (_) {
        // Skip malformed lines
        continue;
      }

      // Extract parts from this chunk
      final candidates = obj['candidates'];
      if (candidates is! List || candidates.isEmpty) {
        continue;
      }
      final first = candidates.first;
      final content = first is Map<String, dynamic> ? first['content'] : null;
      if (content is! Map<String, dynamic>) continue;
      final parts = content['parts'];
      if (parts is! List) continue;

      for (final p in parts) {
        if (p is! Map<String, dynamic>) continue;

        // Accumulate thinking parts (if present and requested)
        final thought = p['thought'];
        if (thought is String && thinkingConfig.includeThoughts) {
          inThinking = true;
          thinkingBuffer.write(thought);
          continue;
        }

        // Emit thinking block once we transition to regular text/content
        if (inThinking) {
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
        }

        // Regular text part
        final text = p['text'];
        if (text is String && text.isNotEmpty) {
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
          continue;
        }

        // Function call (tool)
        if (p['functionCall'] is Map<String, dynamic>) {
          final fc = p['functionCall'] as Map<String, dynamic>;
          final name = fc['name']?.toString() ?? '';
          final argsObj = fc['args'];
          String args;
          try {
            args = jsonEncode(argsObj ?? <String, dynamic>{});
          } catch (_) {
            args = argsObj?.toString() ?? '{}';
          }
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
        }
      }
    }

    // Flush any remaining thinking at end of stream
    if (inThinking && thinkingBuffer.isNotEmpty) {
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
    }
  }

  Uri _buildStreamGenerateContentUri({
    required String baseUrl,
    required String model,
    required String apiKey,
  }) {
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final modelPath = model.startsWith('models/') ? model : 'models/$model';
    final url = '$normalizedBase/v1beta/$modelPath:streamGenerateContent';
    return Uri.parse(url)
        .replace(queryParameters: <String, String>{'key': apiKey});
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
