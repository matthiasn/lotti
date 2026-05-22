import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/model/ai_chat_message.dart';
import 'package:lotti/features/ai/model/ai_chat_message_json.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';

/// HTTP client for OpenAI-compatible `/chat/completions` endpoints.
///
/// Replaces the previous `openai_dart` dependency for providers that speak
/// the standard OpenAI wire protocol — OpenAI itself, OpenRouter, Nebius,
/// Anthropic-via-OpenRouter, generic OpenAI-compatible servers. Mistral and
/// Ollama keep their dedicated repositories because of provider-specific
/// quirks (array content, alternate streaming format).
///
/// Anthropic-via-OpenRouter ping messages (events without a `choices` field)
/// are absorbed naturally by [aiStreamChunkFromJson] returning `null`, so no
/// special filter is needed downstream.
class AiInferenceClient {
  AiInferenceClient({
    required this.baseUrl,
    required this.apiKey,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final String apiKey;
  final http.Client _httpClient;

  /// POST `/chat/completions` with `stream: true` and yield each parsed event.
  Stream<AiStreamChunk> chatCompletionsStream({
    required List<AiChatMessage> messages,
    required String model,
    double? temperature,
    int? maxTokens,
    int? maxCompletionTokens,
    List<AiTool>? tools,
    AiToolChoice? toolChoice,
    AiReasoningEffort? reasoningEffort,
  }) async* {
    final body = <String, dynamic>{
      'model': model,
      'messages': messages.map((m) => m.toJson()).toList(),
      'stream': true,
      'temperature': ?temperature,
      'max_tokens': ?maxTokens,
      'max_completion_tokens': ?maxCompletionTokens,
      if (tools != null && tools.isNotEmpty)
        'tools': tools.map((t) => t.toJson()).toList(),
      'tool_choice': ?toolChoice?.toJson(),
      'reasoning_effort': ?reasoningEffort?.wire,
    };

    final uri = _resolve('chat/completions');
    final request = http.Request('POST', uri)
      ..headers['Content-Type'] = 'application/json'
      ..headers['Accept'] = 'text/event-stream'
      ..headers['Authorization'] = 'Bearer $apiKey'
      ..body = jsonEncode(body);

    final streamed = await _httpClient.send(request);
    if (streamed.statusCode != 200) {
      final responseBody = await streamed.stream.bytesToString();
      throw AiInferenceException(
        'HTTP ${streamed.statusCode}: $responseBody',
        statusCode: streamed.statusCode,
      );
    }

    var parseErrors = 0;
    const maxParseErrors = 5;
    var buffer = StringBuffer();

    await for (final chunk in streamed.stream.transform(utf8.decoder)) {
      buffer.write(chunk);
      final raw = buffer.toString();
      final lines = raw.split('\n');
      buffer = StringBuffer();
      if (!raw.endsWith('\n')) {
        buffer.write(lines.removeLast());
      }

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || !trimmed.startsWith('data: ')) continue;
        final data = trimmed.substring(6).trim();
        if (data == '[DONE]') return;

        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          final parsed = aiStreamChunkFromJson(json);
          if (parsed != null) yield parsed;
        } on FormatException catch (e, stack) {
          parseErrors++;
          developer.log(
            'Failed to parse SSE chunk '
            '($parseErrors/$maxParseErrors): $data',
            name: 'AiInferenceClient',
            error: e,
          );
          if (parseErrors >= maxParseErrors) {
            _captureException(
              e,
              subDomain: 'parse_threshold_exceeded',
              stack: stack,
            );
            throw AiInferenceException(
              'Too many parse errors during streaming',
              originalError: e,
            );
          }
        }
      }
    }
  }

  Uri _resolve(String path) {
    final base = Uri.parse(baseUrl);
    return base.replace(
      path: '${base.path}${base.path.endsWith('/') ? '' : '/'}$path',
    );
  }

  void _captureException(
    Object error, {
    required String subDomain,
    StackTrace? stack,
  }) {
    if (getIt.isRegistered<LoggingService>()) {
      getIt<LoggingService>().captureException(
        error,
        domain: 'AiInferenceClient',
        subDomain: subDomain,
        stackTrace: stack,
      );
    }
  }

  void close() => _httpClient.close();
}

class AiInferenceException implements Exception {
  AiInferenceException(this.message, {this.statusCode, this.originalError});

  final String message;
  final int? statusCode;
  final Object? originalError;

  @override
  String toString() => 'AiInferenceException: $message';
}
