import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/gemini_inference_repository.dart';
import 'package:lotti/features/ai/repository/gemini_thinking_config.dart';
import 'package:openai_dart/openai_dart.dart';

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
      expect(firstContent.startsWith('<think>'), isTrue);
      expect(firstContent.contains('Consider tasks...'), isTrue);
      expect(firstContent.contains('Check dates.'), isTrue);
      // Second is regular text
      final secondContent = events[1].choices!.first.delta!.content!;
      expect(secondContent, 'Here are your tasks.');
    });

    test('skips malformed JSON object and continues with next valid one',
        () async {
      // Malformed object with unquoted keys should be dropped; subsequent valid
      // object should still be parsed and emitted.
      const malformed = '{a:b}';
      final valid = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'OK'},
              ]
            }
          }
        ]
      });

      final client = _FakeStreamClient(200, [malformed, valid]);
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
      expect(events.first.choices!.first.delta!.content, 'OK');
    });

    test('fallback emits thinking, then text, then aggregated tools', () async {
      // Streaming yields empty parts to trigger fallback
      final streamLine = jsonEncode({
        'candidates': [
          {
            'content': {'role': 'model', 'parts': <Object?>[]}
          }
        ]
      });

      // Fallback contains thinking + visible text + two tool calls
      final fallback = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'Reason A', 'thought': true},
                {'text': 'Visible'},
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
            model: 'gemini-2.5-pro',
            temperature: 0.5,
            thinkingConfig: const GeminiThinkingConfig(
              thinkingBudget: 64,
              includeThoughts: true,
            ),
            provider: provider,
          )
          .toList();

      // Expect three events: thinking, text, then aggregated tools
      expect(events.length, 3);
      final thinkDelta = events[0].choices!.first.delta!;
      expect(thinkDelta.content, isNotNull);
      // includes <thinking> wrapper
      expect(thinkDelta.content!.contains('Reason A'), isTrue);

      final textDelta = events[1].choices!.first.delta!;
      expect(textDelta.content, 'Visible');

      final toolsDelta = events[2].choices!.first.delta!;
      expect(toolsDelta.toolCalls, isNotNull);
      expect(toolsDelta.toolCalls!.length, 2);
      expect(toolsDelta.toolCalls![0].id, 'tool_0');
      expect(toolsDelta.toolCalls![1].id, 'tool_1');
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

    test('emits thinking for flash models when includeThoughts is true',
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
            // Gemini 2.5+ Flash supports thinking
            model: 'gemini-2.5-flash',
            temperature: 0.5,
            thinkingConfig: const GeminiThinkingConfig(
              thinkingBudget: 64,
              includeThoughts: true,
            ),
            provider: provider,
          )
          .toList();

      // Expect thinking block + visible answer
      expect(events.length, 2);
      expect(
        events[0].choices!.first.delta!.content,
        '<think>\ninternal chain\n</think>\n',
      );
      expect(events[1].choices!.first.delta!.content, 'Visible answer.');
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
      expect(content.startsWith('<think>'), isTrue);
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

    test('parses usageMetadata and emits in final chunk', () async {
      final responseWithUsage = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'Hello world'},
              ]
            }
          }
        ],
        'usageMetadata': {
          'promptTokenCount': 100,
          'candidatesTokenCount': 50,
          'thoughtsTokenCount': 25,
          'cachedContentTokenCount': 10,
        }
      });

      final client = _FakeStreamClient(200, [responseWithUsage]);
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

      // Should have content event + usage event
      expect(events.length, 2);

      // First event is content
      expect(events[0].choices!.first.delta!.content, 'Hello world');

      // Last event contains usage
      final usageEvent = events.last;
      expect(usageEvent.usage, isNotNull);
      expect(usageEvent.usage!.promptTokens, 100);
      expect(usageEvent.usage!.completionTokens, 50);
      expect(usageEvent.usage!.completionTokensDetails?.reasoningTokens, 25);
    });

    test('accumulates usageMetadata across multiple chunks', () async {
      // First chunk has partial usage
      final chunk1 = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'Hello'},
              ]
            }
          }
        ],
        'usageMetadata': {
          'promptTokenCount': 100,
        }
      });

      // Second chunk has more usage data
      final chunk2 = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': ' world'},
              ]
            }
          }
        ],
        'usageMetadata': {
          'promptTokenCount': 100,
          'candidatesTokenCount': 50,
          'thoughtsTokenCount': 25,
        }
      });

      final client = _FakeStreamClient(200, [chunk1, chunk2]);
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

      // Should have 2 content events + 1 usage event
      expect(events.length, 3);

      // Last event contains accumulated usage
      final usageEvent = events.last;
      expect(usageEvent.usage, isNotNull);
      expect(usageEvent.usage!.promptTokens, 100);
      expect(usageEvent.usage!.completionTokens, 50);
      expect(usageEvent.usage!.completionTokensDetails?.reasoningTokens, 25);
    });

    test('emits no usage event when usageMetadata is absent', () async {
      final responseNoUsage = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'No usage data'},
              ]
            }
          }
        ],
      });

      final client = _FakeStreamClient(200, [responseNoUsage]);
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

      // Should only have content event, no usage event
      expect(events.length, 1);
      expect(events.first.choices!.first.delta!.content, 'No usage data');
      expect(events.first.usage, isNull);
    });

    test('parses function call with thoughtSignature', () async {
      final responseWithFunctionCall = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'functionCall': {
                    'name': 'test_function',
                    'args': {'arg1': 'value1'},
                    'thoughtSignature': 'sig-abc123-encrypted',
                  }
                }
              ]
            }
          }
        ],
      });

      final client = _FakeStreamClient(200, [responseWithFunctionCall]);
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
            model: 'gemini-3-flash-preview',
            temperature: 0.5,
            thinkingConfig: const GeminiThinkingConfig(thinkingBudget: 1),
            provider: provider,
          )
          .toList();

      expect(events.length, 1);
      final toolCalls = events.first.choices!.first.delta!.toolCalls;
      expect(toolCalls, isNotNull);
      expect(toolCalls!.length, 1);
      expect(toolCalls.first.function!.name, 'test_function');
      expect(toolCalls.first.function!.arguments, '{"arg1":"value1"}');
      // Note: thoughtSignature is logged but not exposed in OpenAI-compat types
    });

    test('handles multiple function calls in single response', () async {
      final responseWithMultipleFunctionCalls = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'functionCall': {
                    'name': 'function_one',
                    'args': {'a': 1},
                  }
                },
                {
                  'functionCall': {
                    'name': 'function_two',
                    'args': {'b': 2},
                  }
                },
              ]
            }
          }
        ],
      });

      final client =
          _FakeStreamClient(200, [responseWithMultipleFunctionCalls]);
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
            model: 'gemini-3-pro-preview',
            temperature: 0.5,
            thinkingConfig: const GeminiThinkingConfig(thinkingBudget: 1),
            provider: provider,
          )
          .toList();

      expect(events.length, 2);

      // First function call
      final firstToolCalls = events[0].choices!.first.delta!.toolCalls;
      expect(firstToolCalls, isNotNull);
      expect(firstToolCalls!.first.function!.name, 'function_one');

      // Second function call
      final secondToolCalls = events[1].choices!.first.delta!.toolCalls;
      expect(secondToolCalls, isNotNull);
      expect(secondToolCalls!.first.function!.name, 'function_two');
    });
  });

  group('Rate limit backoff', () {
    test('retries on 429 and succeeds on subsequent attempt', () async {
      var attemptCount = 0;
      final client = _RetryTestClient(
        statusCodes: [429, 200],
        responses: [
          '{"error": "rate limited"}',
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'role': 'model',
                  'parts': [
                    {'text': 'Success after retry'},
                  ],
                }
              }
            ]
          }),
        ],
        onRequest: () => attemptCount++,
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
            prompt: 'test',
            model: 'gemini-2.5-pro',
            temperature: 0.5,
            thinkingConfig: GeminiThinkingConfig.disabled,
            provider: provider,
          )
          .toList();

      expect(attemptCount, 2);
      expect(events.length, 1);
      expect(events.first.choices!.first.delta!.content, 'Success after retry');
    });

    test('retries on 503 service unavailable', () async {
      var attemptCount = 0;
      final client = _RetryTestClient(
        statusCodes: [503, 200],
        responses: [
          '{"error": "service unavailable"}',
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'role': 'model',
                  'parts': [
                    {'text': 'Back online'},
                  ],
                }
              }
            ]
          }),
        ],
        onRequest: () => attemptCount++,
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
            prompt: 'test',
            model: 'gemini-2.5-pro',
            temperature: 0.5,
            thinkingConfig: GeminiThinkingConfig.disabled,
            provider: provider,
          )
          .toList();

      expect(attemptCount, 2);
      expect(events.first.choices!.first.delta!.content, 'Back online');
    });

    test('gives up after max retries and throws', () async {
      var attemptCount = 0;
      final client = _RetryTestClient(
        statusCodes: [429, 429, 429, 429], // Always 429
        responses: List.filled(4, '{"error": "still rate limited"}'),
        onRequest: () => attemptCount++,
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

      await expectLater(
        repo
            .generateText(
              prompt: 'test',
              model: 'gemini-2.5-pro',
              temperature: 0.5,
              thinkingConfig: GeminiThinkingConfig.disabled,
              provider: provider,
            )
            .toList(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('429'),
        )),
      );

      // Default max retries is 3, so 4 attempts total (1 initial + 3 retries)
      expect(attemptCount, 4);
    });
  });

  group('Request headers and body verification', () {
    test('sends correct Content-Type and Accept headers', () async {
      http.BaseRequest? capturedRequest;
      final client = _RequestCapturingClient(
        onRequest: (req) => capturedRequest = req,
        response: jsonEncode({
          'candidates': [
            {
              'content': {
                'role': 'model',
                'parts': [
                  {'text': 'Hello'},
                ],
              }
            }
          ]
        }),
      );

      final repo = GeminiInferenceRepository(httpClient: client);
      final provider = AiConfigInferenceProvider(
        id: 'prov',
        baseUrl: 'https://generativelanguage.googleapis.com',
        apiKey: 'test-key',
        name: 'Gemini',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.gemini,
      );

      await repo
          .generateText(
            prompt: 'Hello',
            model: 'gemini-2.5-pro',
            temperature: 0.7,
            thinkingConfig: GeminiThinkingConfig.standard,
            provider: provider,
          )
          .toList();

      expect(capturedRequest, isNotNull);
      expect(capturedRequest!.headers['Content-Type'], 'application/json');
      expect(
        capturedRequest!.headers['Accept'],
        'application/x-ndjson, application/json, text/event-stream',
      );
    });

    test('sends correct request body structure', () async {
      String? capturedBody;
      final client = _RequestCapturingClient(
        onRequest: (req) {
          if (req is http.Request) {
            capturedBody = req.body;
          }
        },
        response: jsonEncode({
          'candidates': [
            {
              'content': {
                'role': 'model',
                'parts': [
                  {'text': 'Response'},
                ],
              }
            }
          ]
        }),
      );

      final repo = GeminiInferenceRepository(httpClient: client);
      final provider = AiConfigInferenceProvider(
        id: 'prov',
        baseUrl: 'https://generativelanguage.googleapis.com',
        apiKey: 'test-key',
        name: 'Gemini',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.gemini,
      );

      await repo
          .generateText(
            prompt: 'Test prompt',
            model: 'gemini-2.5-pro',
            temperature: 0.8,
            thinkingConfig: const GeminiThinkingConfig(
              thinkingBudget: 4096,
              includeThoughts: true,
            ),
            provider: provider,
            systemMessage: 'You are helpful.',
            maxCompletionTokens: 1000,
          )
          .toList();

      expect(capturedBody, isNotNull);
      final body = jsonDecode(capturedBody!) as Map<String, dynamic>;

      // Verify contents array
      expect(body['contents'], isA<List<dynamic>>());
      final contents = body['contents'] as List<dynamic>;
      expect(contents.length, 1);
      final firstContent = contents[0] as Map<String, dynamic>;
      final firstPart =
          (firstContent['parts'] as List<dynamic>)[0] as Map<String, dynamic>;
      expect(firstPart['text'], 'Test prompt');

      // Verify generation config
      expect(body['generationConfig'], isA<Map<String, dynamic>>());
      final genConfig = body['generationConfig'] as Map<String, dynamic>;
      expect(genConfig['temperature'], 0.8);
      expect(genConfig['maxOutputTokens'], 1000);

      // Verify thinking config
      expect(genConfig['thinkingConfig'], isA<Map<String, dynamic>>());
      final thinkingConfig =
          genConfig['thinkingConfig'] as Map<String, dynamic>;
      expect(thinkingConfig['thinkingBudget'], 4096);
      expect(thinkingConfig['includeThoughts'], true);

      // Verify system instruction
      expect(body['systemInstruction'], isA<Map<String, dynamic>>());
      final sysInstruction = body['systemInstruction'] as Map<String, dynamic>;
      final sysParts = sysInstruction['parts'] as List<dynamic>;
      final sysFirstPart = sysParts[0] as Map<String, dynamic>;
      expect(sysFirstPart['text'], 'You are helpful.');
    });

    test('includes API key in URL query parameter', () async {
      http.BaseRequest? capturedRequest;
      final client = _RequestCapturingClient(
        onRequest: (req) => capturedRequest = req,
        response: jsonEncode({
          'candidates': [
            {
              'content': {
                'role': 'model',
                'parts': [
                  {'text': 'Hi'},
                ],
              }
            }
          ]
        }),
      );

      final repo = GeminiInferenceRepository(httpClient: client);
      final provider = AiConfigInferenceProvider(
        id: 'prov',
        baseUrl: 'https://generativelanguage.googleapis.com',
        apiKey: 'my-secret-api-key',
        name: 'Gemini',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.gemini,
      );

      await repo
          .generateText(
            prompt: 'Hi',
            model: 'gemini-2.5-flash',
            temperature: 0.5,
            thinkingConfig: GeminiThinkingConfig.disabled,
            provider: provider,
          )
          .toList();

      expect(capturedRequest, isNotNull);
      expect(
        capturedRequest!.url.queryParameters['key'],
        'my-secret-api-key',
      );
    });

    test('constructs correct streaming endpoint URL', () async {
      http.BaseRequest? capturedRequest;
      final client = _RequestCapturingClient(
        onRequest: (req) => capturedRequest = req,
        response: jsonEncode({
          'candidates': [
            {
              'content': {
                'role': 'model',
                'parts': [
                  {'text': 'OK'},
                ],
              }
            }
          ]
        }),
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

      await repo
          .generateText(
            prompt: 'Test',
            model: 'gemini-2.5-flash',
            temperature: 0.5,
            thinkingConfig: GeminiThinkingConfig.disabled,
            provider: provider,
          )
          .toList();

      expect(capturedRequest, isNotNull);
      expect(
        capturedRequest!.url.path,
        '/v1beta/models/gemini-2.5-flash:streamGenerateContent',
      );
    });

    test('includes tools in request body when provided', () async {
      String? capturedBody;
      final client = _RequestCapturingClient(
        onRequest: (req) {
          if (req is http.Request) {
            capturedBody = req.body;
          }
        },
        response: jsonEncode({
          'candidates': [
            {
              'content': {
                'role': 'model',
                'parts': [
                  {'text': 'Using tool'},
                ],
              }
            }
          ]
        }),
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

      await repo.generateText(
        prompt: 'Call a function',
        model: 'gemini-2.5-pro',
        temperature: 0.5,
        thinkingConfig: GeminiThinkingConfig.disabled,
        provider: provider,
        tools: [
          const ChatCompletionTool(
            type: ChatCompletionToolType.function,
            function: FunctionObject(
              name: 'get_weather',
              description: 'Get weather for a location',
              parameters: {
                'type': 'object',
                'properties': {
                  'location': {'type': 'string'},
                },
                'required': ['location'],
              },
            ),
          ),
        ],
      ).toList();

      expect(capturedBody, isNotNull);
      final body = jsonDecode(capturedBody!) as Map<String, dynamic>;

      expect(body['tools'], isA<List<dynamic>>());
      final tools = body['tools'] as List<dynamic>;
      expect(tools.length, 1);

      final tool = tools[0] as Map<String, dynamic>;
      expect(tool['functionDeclarations'], isA<List<dynamic>>());
      final funcDecls = tool['functionDeclarations'] as List<dynamic>;
      expect(funcDecls.length, 1);
      final firstFuncDecl = funcDecls[0] as Map<String, dynamic>;
      expect(firstFuncDecl['name'], 'get_weather');
      expect(firstFuncDecl['description'], 'Get weather for a location');
    });
  });

  group('Character cap enforcement', () {
    test('truncates thinking content at character cap', () async {
      // Create a response with very long thinking content
      final longThinking = 'x' * 50000; // 50k chars
      final line = jsonEncode({
        'candidates': [
          {
            'content': {
              'role': 'model',
              'parts': [
                {'text': longThinking, 'thought': true},
                {'text': 'Short answer'},
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
            prompt: 'Test',
            model: 'gemini-2.5-pro',
            temperature: 0.5,
            thinkingConfig: const GeminiThinkingConfig(
              thinkingBudget: 8192,
              includeThoughts: true,
            ),
            provider: provider,
          )
          .toList();

      // Should have thinking block + answer
      expect(events.length, 2);

      // Thinking should be captured (may be truncated at very high limits)
      final thinkingContent = events[0].choices!.first.delta!.content!;
      expect(thinkingContent.startsWith('<think>'), isTrue);
      expect(thinkingContent.endsWith('</think>\n'), isTrue);

      // Answer should be present
      expect(events[1].choices!.first.delta!.content, 'Short answer');
    });
  });
}

/// Test client that allows controlling retry behavior
class _RetryTestClient extends http.BaseClient {
  _RetryTestClient({
    required this.statusCodes,
    required this.responses,
    this.onRequest,
  });

  final List<int> statusCodes;
  final List<String> responses;
  final void Function()? onRequest;
  int _callCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    onRequest?.call();
    final idx =
        _callCount < statusCodes.length ? _callCount : statusCodes.length - 1;
    _callCount++;

    final body = responses[idx < responses.length ? idx : responses.length - 1];
    final bytes = utf8.encode(body);
    final stream = Stream<List<int>>.fromIterable([bytes]);

    return http.StreamedResponse(
      stream,
      statusCodes[idx],
      headers: {'content-type': 'application/json'},
    );
  }
}

/// Test client that captures request details for verification
class _RequestCapturingClient extends http.BaseClient {
  _RequestCapturingClient({
    required this.onRequest,
    required this.response,
  });

  final void Function(http.BaseRequest) onRequest;
  final String response;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    onRequest(request);
    final bytes = utf8.encode(response);
    final stream = Stream<List<int>>.fromIterable([bytes]);
    return http.StreamedResponse(stream, 200, headers: {
      'content-type': 'application/json',
    });
  }
}
