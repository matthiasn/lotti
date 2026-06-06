import 'dart:convert';

import 'package:http/http.dart' as http;

/// Shared SSE fixtures for the streaming inference repository tests
/// (Mistral, Voxtral, …).

/// Creates a mock SSE streamed response from a list of event payloads.
http.StreamedResponse createSseStreamedResponse({
  required List<Map<String, dynamic>> events,
  int statusCode = 200,
  bool includeDone = true,
}) {
  final sseLines = <String>[];

  for (final event in events) {
    sseLines.add('data: ${jsonEncode(event)}\n\n');
  }
  if (includeDone) {
    sseLines.add('data: [DONE]\n\n');
  }

  final stream = Stream.fromIterable([utf8.encode(sseLines.join())]);
  return http.StreamedResponse(stream, statusCode);
}

/// Creates a mock SSE event for a chunk with content.
Map<String, dynamic> createSseChunkEvent({
  String? content,
  String? id,
  String? finishReason,
  int? created,
  String model = 'test-model',
  String? role,
  List<Map<String, dynamic>>? toolCalls,
  Map<String, dynamic>? usage,
}) {
  return {
    'id': id ?? 'chatcmpl-test',
    'object': 'chat.completion.chunk',
    'created': created ?? 1234567890,
    'model': model,
    'choices': [
      {
        'index': 0,
        'delta': {
          'content': ?content,
          'role': ?role,
          'tool_calls': ?toolCalls,
        },
        'finish_reason': finishReason,
      },
    ],
    'usage': ?usage,
  };
}

/// Creates a final SSE event with finish_reason but no content.
Map<String, dynamic> createSseFinalEvent({
  String? id,
  int? created,
  String model = 'test-model',
}) {
  return {
    'id': id ?? 'chatcmpl-test',
    'object': 'chat.completion.chunk',
    'created': created ?? 1234567890,
    'model': model,
    'choices': [
      {
        'index': 0,
        'delta': <String, dynamic>{},
        'finish_reason': 'stop',
      },
    ],
  };
}
