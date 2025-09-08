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

  /// Generate text from a plain prompt with optional system instruction and tools.
  ///
  /// This uses the non-streaming `generateContent` endpoint internally and
  /// adapts the result into a simple two-event stream: one for content (if any)
  /// and one for tool calls (if present).
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
    final uri = _buildGenerateContentUri(
      baseUrl: provider.baseUrl,
      model: model,
      apiKey: provider.apiKey,
    );

    final body = _buildRequestBody(
      prompt: prompt,
      systemMessage: systemMessage,
      temperature: temperature,
      maxTokens: maxCompletionTokens,
      thinkingConfig: thinkingConfig,
      tools: tools,
    );

    developer.log(
      'Gemini generateContent request to: $uri',
      name: 'GeminiInferenceRepository',
    );

    final resp = await _httpClient.post(
      uri,
      headers: const {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(
          'Gemini API error ${resp.statusCode}: ${resp.body.isNotEmpty ? resp.body : resp.reasonPhrase}');
    }

    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;

    final contentText = _extractText(decoded);
    final toolCalls = _extractToolCalls(decoded);

    // Emit content chunk if present
    if (contentText.isNotEmpty) {
      yield CreateChatCompletionStreamResponse(
        id: 'gemini-${DateTime.now().millisecondsSinceEpoch}',
        created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        model: model,
        choices: [
          ChatCompletionStreamResponseChoice(
            index: 0,
            delta: ChatCompletionStreamResponseDelta(content: contentText),
          ),
        ],
      );
    }

    // Emit tool call chunk if present
    if (toolCalls.isNotEmpty) {
      yield CreateChatCompletionStreamResponse(
        id: 'gemini-${DateTime.now().millisecondsSinceEpoch}',
        created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        model: model,
        choices: [
          ChatCompletionStreamResponseChoice(
            index: 0,
            delta: ChatCompletionStreamResponseDelta(toolCalls: toolCalls),
          ),
        ],
      );
    }
  }

  Uri _buildGenerateContentUri({
    required String baseUrl,
    required String model,
    required String apiKey,
  }) {
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final modelPath = model.startsWith('models/') ? model : 'models/$model';
    final url = '$normalizedBase/v1beta/$modelPath:generateContent';
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

  String _extractText(Map<String, dynamic> response) {
    final list = response['candidates']
        as List<dynamic>?; // safe cast from dynamic
    if (list == null || list.isEmpty) return '';
    final first = list.first;
    final content = first is Map<String, dynamic> ? first['content'] : null;
    if (content is! Map<String, dynamic>) return '';
    final parts = content['parts'];
    if (parts is! List) return '';

    final buffer = StringBuffer();
    for (final p in parts) {
      if (p is Map<String, dynamic> && p['text'] is String) {
        buffer.write(p['text'] as String);
      }
    }
    return buffer.toString();
  }

  List<ChatCompletionStreamMessageToolCallChunk> _extractToolCalls(
    Map<String, dynamic> response,
  ) {
    final result = <ChatCompletionStreamMessageToolCallChunk>[];
    final list = response['candidates']
        as List<dynamic>?; // safe cast from dynamic
    if (list == null || list.isEmpty) return result;
    final first = list.first;
    final content = first is Map<String, dynamic> ? first['content'] : null;
    if (content is! Map<String, dynamic>) return result;
    final parts = content['parts'];
    if (parts is! List) return result;

    var idx = 0;
    for (final p in parts) {
      if (p is Map<String, dynamic> &&
          p['functionCall'] is Map<String, dynamic>) {
        final fc = p['functionCall'] as Map<String, dynamic>;
        final name = fc['name']?.toString() ?? '';
        final argsObj = fc['args'];
        String args;
        try {
          args = jsonEncode(argsObj ?? <String, dynamic>{});
        } catch (_) {
          args = argsObj?.toString() ?? '{}';
        }
        result.add(
          ChatCompletionStreamMessageToolCallChunk(
            index: idx,
            id: 'tool_$idx',
            function: ChatCompletionStreamMessageFunctionCall(
              name: name,
              arguments: args,
            ),
          ),
        );
        idx++;
      }
    }
    return result;
  }
}
