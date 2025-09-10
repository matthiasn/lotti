import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/gemini_inference_repository.dart';
import 'package:lotti/features/ai/repository/gemini_thinking_config.dart';

class _FakeStreamClient extends http.BaseClient {
  _FakeStreamClient(this._statusCode, this._lines);

  final int _statusCode;
  final List<String> _lines;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final data = _lines.map((l) => utf8.encode('$l\n') as List<int>);
    final stream = Stream<List<int>>.fromIterable(data);
    return http.StreamedResponse(stream, _statusCode, headers: {
      'content-type': 'application/json',
    });
  }
}

class _RoutingFakeClient extends http.BaseClient {
  _RoutingFakeClient({
    required this.streamLines,
    required this.fallbackBody,
  });

  final List<String> streamLines;
  final String fallbackBody;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    if (path.endsWith(':streamGenerateContent')) {
      final data = streamLines.map((l) => utf8.encode('$l\n') as List<int>);
      final stream = Stream<List<int>>.fromIterable(data);
      return http.StreamedResponse(stream, 200, headers: {
        'content-type': 'application/json',
      });
    } else if (path.endsWith(':generateContent')) {
      final bytes = utf8.encode(fallbackBody);
      final stream = Stream<List<int>>.fromIterable([bytes]);
      return http.StreamedResponse(stream, 200, headers: {
        'content-type': 'application/json',
      });
    }
    // Default empty 404
    return http.StreamedResponse(const Stream.empty(), 404);
  }
}

class _RoutingErrorClient extends http.BaseClient {
  _RoutingErrorClient({
    required this.streamLines,
  });

  final List<String> streamLines;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    if (path.endsWith(':streamGenerateContent')) {
      final data = streamLines.map((l) => utf8.encode('$l\n') as List<int>);
      final stream = Stream<List<int>>.fromIterable(data);
      return http.StreamedResponse(stream, 200, headers: {
        'content-type': 'application/json',
      });
    } else if (path.endsWith(':generateContent')) {
      final bytes = utf8.encode('{"error":"boom"}');
      final stream = Stream<List<int>>.fromIterable([bytes]);
      return http.StreamedResponse(stream, 500, headers: {
        'content-type': 'application/json',
      });
    }
    return http.StreamedResponse(const Stream.empty(), 404);
  }
}

class _RoutingCountingClient extends http.BaseClient {
  _RoutingCountingClient({
    required this.streamLines,
    required this.fallbackBody,
  });

  final List<String> streamLines;
  final String fallbackBody;

  int streamCalls = 0;
  int fallbackCalls = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    if (path.endsWith(':streamGenerateContent')) {
      streamCalls++;
      final data = streamLines.map((l) => utf8.encode('$l\n') as List<int>);
      final stream = Stream<List<int>>.fromIterable(data);
      return http.StreamedResponse(stream, 200, headers: {
        'content-type': 'application/json',
      });
    } else if (path.endsWith(':generateContent')) {
      fallbackCalls++;
      final bytes = utf8.encode(fallbackBody);
      final stream = Stream<List<int>>.fromIterable([bytes]);
      return http.StreamedResponse(stream, 200, headers: {
        'content-type': 'application/json',
      });
    }
    return http.StreamedResponse(const Stream.empty(), 404);
  }
}

void main() {
  group('GeminiInferenceRepository streaming', () {
    test('surfaces thinking block then text', () async {
      final line = jsonEncode({
        'candidates': [
          {
            'content': {
              'role': 'model',
              'parts': [
                // Gemini thinking parts include a boolean flag and text
                {'text': 'Consider tasks... ', 'thought': true},
                {'text': 'Check dates.', 'thought': true},
                {'text': 'Here are your tasks.'},
              ],
            }
          }
        ]
      });

      final client = _FakeStreamClient(200, [line]);
      final repo = GeminiInferenceRepository(httpClient: client);

      final provider = AiConfigInferenceProvider(
        id: 'prov',
        baseUrl: 'https://generativelanguage.googleapis.com',
        apiKey: 'test',
        name: 'Gemini',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.gemini,
      );

      final stream = repo.generateText(
        prompt: 'Summarize tasks',
        // Use a non-"flash" model so thinking blocks are surfaced
        model: 'gemini-2.5-pro',
        temperature: 0.7,
        thinkingConfig: const GeminiThinkingConfig(
          thinkingBudget: 1024,
          includeThoughts: true,
        ),
        provider: provider,
      );

      final events = await stream.toList();
      expect(events.length, 2);
      // First is thinking block
      final firstContent = events[0].choices!.first.delta!.content!;
      expect(firstContent.startsWith('<thinking>'), isTrue);
      expect(firstContent.contains('Consider tasks...'), isTrue);
      expect(firstContent.contains('Check dates.'), isTrue);
      // Second is regular text
      final secondContent = events[1].choices!.first.delta!.content!;
      expect(secondContent, 'Here are your tasks.');
    });

    test('maps functionCall to tool call chunk', () async {
      final line = jsonEncode({
        'candidates': [
          {
            'content': {
              'role': 'model',
              'parts': [
                {
                  'functionCall': {
                    'name': 'get_task_summaries',
                    'args': {
                      'start_date': '2024-01-01',
                      'end_date': '2024-01-02'
                    }
                  }
                }
              ],
            }
          }
        ]
      });

      final client = _FakeStreamClient(200, [line]);
      final repo = GeminiInferenceRepository(httpClient: client);

      final provider = AiConfigInferenceProvider(
        id: 'prov',
        baseUrl: 'https://generativelanguage.googleapis.com',
        apiKey: 'test',
        name: 'Gemini',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.gemini,
      );

      final stream = repo.generateText(
        prompt: 'Summarize tasks',
        model: 'gemini-2.5-flash',
        temperature: 0.7,
        thinkingConfig: const GeminiThinkingConfig(
          thinkingBudget: 1024,
        ),
        provider: provider,
      );

      final events = await stream.toList();
      expect(events.length, 1);
      final delta = events.first.choices!.first.delta!;
      expect(delta.toolCalls, isNotNull);
      expect(delta.toolCalls!.length, 1);
      final call = delta.toolCalls!.first;
      expect(call.function!.name, 'get_task_summaries');
      expect(call.function!.arguments, contains('start_date'));
    });

    test('emits unique tool IDs and indices for multiple function calls',
        () async {
      final line = jsonEncode({
        'candidates': [
          {
            'content': {
              'role': 'model',
              'parts': [
                {
                  'functionCall': {
                    'name': 'a',
                    'args': {'x': 1}
                  }
                },
                {
                  'functionCall': {
                    'name': 'b',
                    'args': {'y': 2}
                  }
                }
              ],
            }
          }
        ]
      });

      final client = _FakeStreamClient(200, [line]);
      final repo = GeminiInferenceRepository(httpClient: client);

      final provider = AiConfigInferenceProvider(
        id: 'prov',
        baseUrl: 'https://generativelanguage.googleapis.com',
        apiKey: 'test',
        name: 'Gemini',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.gemini,
      );

      final events = await repo
          .generateText(
            prompt: 'p',
            model: 'gemini-2.5-flash',
            temperature: 0.5,
            thinkingConfig: const GeminiThinkingConfig(thinkingBudget: 64),
            provider: provider,
          )
          .toList();

      // We expect two tool-call events
      expect(events.length, 2);
      final call0 = events[0].choices!.first.delta!.toolCalls!.first;
      final call1 = events[1].choices!.first.delta!.toolCalls!.first;
      expect(call0.id, 'tool_0');
      expect(call0.index, 0);
      expect(call1.id, 'tool_1');
      expect(call1.index, 1);
    });

    test('fallback aggregates multiple tool calls into single response',
        () async {
      // Streaming yields nothing useful -> triggers fallback
      final streamLine = jsonEncode({
        'candidates': [
          {
            'content': {'role': 'model', 'parts': <Object?>[]}
          }
        ]
      });

      final fallback = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'hello'},
                {
                  'functionCall': {
                    'name': 'a',
                    'args': {'x': 1}
                  }
                },
                {
                  'functionCall': {
                    'name': 'b',
                    'args': {'y': 2}
                  }
                }
              ]
            }
          }
        ]
      });

      final client = _RoutingFakeClient(
        streamLines: [streamLine],
        fallbackBody: fallback,
      );
      final repo = GeminiInferenceRepository(httpClient: client);

      final provider = AiConfigInferenceProvider(
        id: 'prov',
        baseUrl: 'https://generativelanguage.googleapis.com',
        apiKey: 'key',
        name: 'Gemini',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.gemini,
      );

      final events = await repo
          .generateText(
            prompt: 'p',
            model: 'gemini-2.0-pro',
            temperature: 0.5,
            thinkingConfig: const GeminiThinkingConfig(thinkingBudget: 64),
            provider: provider,
          )
          .toList();

      // Expect two events: one for content text, one for aggregated tools
      expect(events.length, 2);
      final textDelta = events[0].choices!.first.delta!;
      expect(textDelta.content, 'hello');
      final toolsDelta = events[1].choices!.first.delta!;
      expect(toolsDelta.toolCalls, isNotNull);
      expect(toolsDelta.toolCalls!.length, 2);
      expect(toolsDelta.toolCalls![0].id, 'tool_0');
      expect(toolsDelta.toolCalls![1].id, 'tool_1');
    });

    test('throws for non-2xx streaming status codes', () async {
      final client = _FakeStreamClient(500, ['{"error":"x"}']);
      final repo = GeminiInferenceRepository(httpClient: client);
      final provider = AiConfigInferenceProvider(
        id: 'prov',
        baseUrl: 'https://generativelanguage.googleapis.com',
        apiKey: 'key',
        name: 'Gemini',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.gemini,
      );
      expect(
        () => repo
            .generateText(
              prompt: 'p',
              model: 'gemini-2.0-pro',
              temperature: 0.5,
              thinkingConfig: const GeminiThinkingConfig(thinkingBudget: 64),
              provider: provider,
            )
            .toList(),
        throwsA(isA<Exception>()),
      );
    });

    test(
        'does not emit thinking for flash models even if includeThoughts is true',
        () async {
      final line = jsonEncode({
        'candidates': [
          {
            'content': {
              'role': 'model',
              'parts': [
                {'text': 'internal chain', 'thought': true},
                {'text': 'Visible answer.'},
              ],
            }
          }
        ]
      });

      final client = _FakeStreamClient(200, [line]);
      final repo = GeminiInferenceRepository(httpClient: client);

      final provider = AiConfigInferenceProvider(
        id: 'prov',
        baseUrl: 'https://generativelanguage.googleapis.com',
        apiKey: 'k',
        name: 'Gemini',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.gemini,
      );

      final events = await repo
          .generateText(
            prompt: 'p',
            // flash → hide thoughts
            model: 'gemini-2.5-flash',
            temperature: 0.5,
            thinkingConfig: const GeminiThinkingConfig(
              thinkingBudget: 64,
              includeThoughts: true,
            ),
            provider: provider,
          )
          .toList();

      expect(events.length, 1);
      expect(events[0].choices!.first.delta!.content, 'Visible answer.');
    });

    test('flushes trailing thinking block at end of stream', () async {
      final line = jsonEncode({
        'candidates': [
          {
            'content': {
              'role': 'model',
              'parts': [
                {'text': 'reason...', 'thought': true},
                {'text': 'more...', 'thought': true},
              ],
            }
          }
        ]
      });

      final client = _FakeStreamClient(200, [line]);
      final repo = GeminiInferenceRepository(httpClient: client);
      final provider = AiConfigInferenceProvider(
        id: 'prov',
        baseUrl: 'https://generativelanguage.googleapis.com',
        apiKey: 'k',
        name: 'Gemini',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.gemini,
      );

      final events = await repo
          .generateText(
            prompt: 'p',
            model: 'gemini-2.5-pro',
            temperature: 0.5,
            thinkingConfig: const GeminiThinkingConfig(
              thinkingBudget: 64,
              includeThoughts: true,
            ),
            provider: provider,
          )
          .toList();

      expect(events.length, 1);
      final content = events.first.choices!.first.delta!.content!;
      expect(content.startsWith('<thinking>'), isTrue);
      expect(content, contains('reason...'));
      expect(content, contains('more...'));
    });

    test('handles SSE data: lines and array framing in stream', () async {
      final sse = 'data: ${jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'A'},
                  ]
                }
              }
            ]
          })}';

      // Prepend an opening bracket to test array framing removal
      final client = _FakeStreamClient(200, ['[', sse]);
      final repo = GeminiInferenceRepository(httpClient: client);

      final provider = AiConfigInferenceProvider(
        id: 'prov',
        baseUrl: 'https://generativelanguage.googleapis.com',
        apiKey: 'k',
        name: 'Gemini',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.gemini,
      );

      final events = await repo
          .generateText(
            prompt: 'p',
            model: 'gemini-2.5-pro',
            temperature: 0.5,
            thinkingConfig: const GeminiThinkingConfig(thinkingBudget: 1),
            provider: provider,
          )
          .toList();

      expect(events.length, 1);
      expect(events.first.choices!.first.delta!.content, 'A');
    });

    test('parses JSON object across multiple chunks', () async {
      // Break the JSON across chunks outside of strings to simulate partial frames
      const part1 = '{"candidates":[{"content":{"parts":[';
      const part2 = '{"text":"Hello"}]}}]}';
      final client = _FakeStreamClient(200, const [part1, part2]);
      final repo = GeminiInferenceRepository(httpClient: client);

      final provider = AiConfigInferenceProvider(
        id: 'prov',
        baseUrl: 'https://generativelanguage.googleapis.com',
        apiKey: 'k',
        name: 'Gemini',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.gemini,
      );

      final events = await repo
          .generateText(
            prompt: 'p',
            model: 'gemini-2.5-pro',
            temperature: 0.5,
            thinkingConfig: const GeminiThinkingConfig(thinkingBudget: 1),
            provider: provider,
          )
          .toList();
      expect(events.length, 1);
      expect(events.first.choices!.first.delta!.content, 'Hello');
    });

    test('fallback non-streaming failure yields no events', () async {
      final emptyParts = jsonEncode({
        'candidates': [
          {
            'content': {'parts': <Object?>[]}
          }
        ]
      });
      final client = _RoutingErrorClient(streamLines: [emptyParts]);
      final repo = GeminiInferenceRepository(httpClient: client);
      final provider = AiConfigInferenceProvider(
        id: 'prov',
        baseUrl: 'https://generativelanguage.googleapis.com',
        apiKey: 'k',
        name: 'Gemini',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.gemini,
      );
      final events = await repo
          .generateText(
            prompt: 'p',
            model: 'gemini-2.5-pro',
            temperature: 0.1,
            thinkingConfig: const GeminiThinkingConfig(thinkingBudget: 1),
            provider: provider,
          )
          .toList();
      expect(events, isEmpty);
    });

    test('does not perform fallback when streaming emitted any content',
        () async {
      final streamLine = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'from stream'},
              ]
            }
          }
        ]
      });
      final fallback = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'from fallback'},
              ]
            }
          }
        ]
      });
      final client = _RoutingCountingClient(
        streamLines: [streamLine],
        fallbackBody: fallback,
      );
      final repo = GeminiInferenceRepository(httpClient: client);
      final provider = AiConfigInferenceProvider(
        id: 'prov',
        baseUrl: 'https://generativelanguage.googleapis.com',
        apiKey: 'k',
        name: 'Gemini',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.gemini,
      );
      final events = await repo
          .generateText(
            prompt: 'p',
            model: 'gemini-2.5-pro',
            temperature: 0.2,
            thinkingConfig: const GeminiThinkingConfig(thinkingBudget: 1),
            provider: provider,
          )
          .toList();
      expect(events.length, 1);
      expect(events.first.choices!.first.delta!.content, 'from stream');
      expect(client.streamCalls, 1);
      expect(client.fallbackCalls, 0);
    });
  });
}
