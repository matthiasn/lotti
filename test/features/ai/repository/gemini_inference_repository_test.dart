// ignore_for_file: cascade_invocations

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/gemini_tool_call.dart';
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
      expect(toolsDelta.toolCalls![0].id, 'tool_turn0_0');
      expect(toolsDelta.toolCalls![1].id, 'tool_turn0_1');
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
      expect(call0.id, 'tool_turn0_0');
      expect(call0.index, 0);
      expect(call1.id, 'tool_turn0_1');
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
      expect(toolsDelta.toolCalls![0].id, 'tool_turn0_0');
      expect(toolsDelta.toolCalls![1].id, 'tool_turn0_1');
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

    test('fallback emits usage from non-streaming response', () async {
      // Streaming yields empty parts to trigger fallback
      final streamLine = jsonEncode({
        'candidates': [
          {
            'content': {'parts': <Object?>[]}
          }
        ]
      });

      // Fallback response includes usageMetadata
      final fallback = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'Fallback response'},
              ]
            }
          }
        ],
        'usageMetadata': {
          'promptTokenCount': 50,
          'candidatesTokenCount': 20,
          'thoughtsTokenCount': 10,
        }
      });

      final client = _RoutingFakeClient(
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
            model: 'gemini-2.5-flash',
            temperature: 0.5,
            thinkingConfig: GeminiThinkingConfig.disabled,
            provider: provider,
          )
          .toList();

      // Should have: text event + usage event
      expect(events.length, 2);
      expect(events[0].choices!.first.delta!.content, 'Fallback response');

      final usageEvent = events[1];
      expect(usageEvent.usage, isNotNull);
      expect(usageEvent.usage!.promptTokens, 50);
      expect(usageEvent.usage!.completionTokens, 20);
      expect(usageEvent.usage!.completionTokensDetails?.reasoningTokens, 10);
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

  group('ThoughtSignatureCollector', () {
    test('collects signatures and provides access', () {
      final collector = ThoughtSignatureCollector();

      expect(collector.hasSignatures, isFalse);
      expect(collector.signatures, isEmpty);

      collector.addSignature('tool_0', 'sig-abc123');
      collector.addSignature('tool_1', 'sig-def456');

      expect(collector.hasSignatures, isTrue);
      expect(collector.signatures.length, 2);
      expect(collector.getSignature('tool_0'), 'sig-abc123');
      expect(collector.getSignature('tool_1'), 'sig-def456');
      expect(collector.getSignature('tool_2'), isNull);
    });

    test('clear removes all signatures', () {
      final collector = ThoughtSignatureCollector();
      collector.addSignature('tool_0', 'sig-abc123');
      expect(collector.hasSignatures, isTrue);

      collector.clear();
      expect(collector.hasSignatures, isFalse);
      expect(collector.signatures, isEmpty);
    });

    test('signatures map is unmodifiable', () {
      final collector = ThoughtSignatureCollector();
      collector.addSignature('tool_0', 'sig-abc123');

      expect(
        () => collector.signatures['tool_1'] = 'bad',
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('extractThoughtSignature helper', () {
    test('extracts signature from part level (sibling of functionCall)', () {
      final part = <String, dynamic>{
        'functionCall': {'name': 'test_func', 'args': <String, dynamic>{}},
        'thoughtSignature': 'encrypted-sig-12345',
      };
      expect(extractThoughtSignature(part), 'encrypted-sig-12345');
    });

    test('returns null when no signature present', () {
      final part = <String, dynamic>{
        'functionCall': {'name': 'test_func', 'args': <String, dynamic>{}},
      };
      expect(extractThoughtSignature(part), isNull);
    });

    test('returns null when signature is inside functionCall (wrong location)',
        () {
      // This tests that we correctly look at part level, not inside functionCall
      final part = <String, dynamic>{
        'functionCall': {
          'name': 'test_func',
          'args': <String, dynamic>{},
          'thoughtSignature': 'wrong-location-sig',
        },
      };
      expect(extractThoughtSignature(part), isNull);
    });

    test('handles non-string signature values by converting to string', () {
      final part = <String, dynamic>{
        'functionCall': {'name': 'test_func', 'args': <String, dynamic>{}},
        'thoughtSignature': 12345, // numeric value
      };
      expect(extractThoughtSignature(part), '12345');
    });
  });

  group('Signature capture from streaming', () {
    test('captures thought signatures in collector during streaming', () async {
      // According to Gemini docs, thoughtSignature is a sibling of functionCall
      // at the part level, not inside functionCall. For parallel function calls,
      // only the first call receives a signature.
      final responseWithSignature = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'functionCall': {
                    'name': 'add_checklist_item',
                    'args': {'title': 'Buy milk'},
                  },
                  // thoughtSignature is at part level, sibling of functionCall
                  'thoughtSignature': 'encrypted-sig-12345',
                },
                {
                  'functionCall': {
                    'name': 'add_checklist_item',
                    'args': {'title': 'Buy bread'},
                  },
                  // Second parallel call also gets signature in test
                  // (in practice, only first may have it)
                  'thoughtSignature': 'encrypted-sig-67890',
                }
              ]
            }
          }
        ],
      });

      final client = _FakeStreamClient(200, [responseWithSignature]);
      final repo = GeminiInferenceRepository(httpClient: client);
      final collector = ThoughtSignatureCollector();

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
            model: 'gemini-3-flash',
            temperature: 0.5,
            thinkingConfig: const GeminiThinkingConfig(thinkingBudget: 1),
            provider: provider,
            signatureCollector: collector,
          )
          .toList();

      // Should have 2 tool call events
      expect(events.length, 2);

      // Collector should have both signatures
      expect(collector.hasSignatures, isTrue);
      expect(collector.signatures.length, 2);
      expect(collector.getSignature('tool_turn0_0'), 'encrypted-sig-12345');
      expect(collector.getSignature('tool_turn0_1'), 'encrypted-sig-67890');
    });

    test('handles function calls without signatures', () async {
      final responseNoSignature = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'functionCall': {
                    'name': 'add_checklist_item',
                    'args': {'title': 'Buy milk'},
                    // No thoughtSignature field
                  }
                }
              ]
            }
          }
        ],
      });

      final client = _FakeStreamClient(200, [responseNoSignature]);
      final repo = GeminiInferenceRepository(httpClient: client);
      final collector = ThoughtSignatureCollector();

      final provider = AiConfigInferenceProvider(
        id: 'prov',
        baseUrl: 'https://generativelanguage.googleapis.com',
        apiKey: 'k',
        name: 'Gemini',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.gemini,
      );

      await repo
          .generateText(
            prompt: 'p',
            model: 'gemini-2.5-flash',
            temperature: 0.5,
            thinkingConfig: GeminiThinkingConfig.disabled,
            provider: provider,
            signatureCollector: collector,
          )
          .toList();

      // No signatures should be captured
      expect(collector.hasSignatures, isFalse);
    });

    test('captures signatures from fallback path', () async {
      // Streaming yields empty parts to trigger fallback
      final streamLine = jsonEncode({
        'candidates': [
          {
            'content': {'parts': <Object?>[]}
          }
        ]
      });

      // Fallback has function calls with signatures at part level
      final fallback = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'functionCall': {
                    'name': 'set_task_language',
                    'args': {'languageCode': 'de'},
                  },
                  // thoughtSignature is at part level, sibling of functionCall
                  'thoughtSignature': 'fallback-sig-abc',
                }
              ]
            }
          }
        ],
      });

      final client = _RoutingFakeClient(
        streamLines: [streamLine],
        fallbackBody: fallback,
      );
      final repo = GeminiInferenceRepository(httpClient: client);
      final collector = ThoughtSignatureCollector();

      final provider = AiConfigInferenceProvider(
        id: 'prov',
        baseUrl: 'https://generativelanguage.googleapis.com',
        apiKey: 'k',
        name: 'Gemini',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.gemini,
      );

      await repo
          .generateText(
            prompt: 'p',
            model: 'gemini-3-pro',
            temperature: 0.5,
            thinkingConfig: GeminiThinkingConfig.disabled,
            provider: provider,
            signatureCollector: collector,
          )
          .toList();

      // Signature should be captured from fallback
      expect(collector.hasSignatures, isTrue);
      expect(collector.getSignature('tool_turn0_0'), 'fallback-sig-abc');
    });
  });

  group('generateTextWithMessages (multi-turn)', () {
    test('sends multi-turn request with conversation history', () async {
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
                  {'text': 'Multi-turn response'},
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

      final messages = [
        const ChatCompletionMessage.user(
          content: ChatCompletionUserMessageContent.string('Hello'),
        ),
        const ChatCompletionMessage.assistant(content: 'Hi there!'),
        const ChatCompletionMessage.user(
          content: ChatCompletionUserMessageContent.string('How are you?'),
        ),
      ];

      final events = await repo
          .generateTextWithMessages(
            messages: messages,
            model: 'gemini-2.5-pro',
            temperature: 0.7,
            thinkingConfig: GeminiThinkingConfig.disabled,
            provider: provider,
          )
          .toList();

      expect(events.length, 1);
      expect(events.first.choices!.first.delta!.content, 'Multi-turn response');

      // Verify body contains messages array (multi-turn format)
      expect(capturedBody, isNotNull);
      final body = jsonDecode(capturedBody!) as Map<String, dynamic>;
      expect(body['contents'], isA<List<dynamic>>());
      final contents = body['contents'] as List<dynamic>;
      expect(contents.length, 3); // 3 messages converted
    });

    test('includes thought signatures in multi-turn request', () async {
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
                  {'text': 'Continuing conversation'},
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

      final messages = [
        const ChatCompletionMessage.user(
          content: ChatCompletionUserMessageContent.string('Add items'),
        ),
        const ChatCompletionMessage.assistant(
          toolCalls: [
            ChatCompletionMessageToolCall(
              id: 'call-123',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: 'add_item',
                arguments: '{"title":"Buy milk"}',
              ),
            ),
          ],
        ),
        const ChatCompletionMessage.tool(
          toolCallId: 'call-123',
          content: 'Item added successfully',
        ),
      ];

      await repo.generateTextWithMessages(
        messages: messages,
        model: 'gemini-3-pro',
        temperature: 0.5,
        thinkingConfig: GeminiThinkingConfig.disabled,
        provider: provider,
        thoughtSignatures: {'call-123': 'sig-encrypted-abc'},
      ).toList();

      expect(capturedBody, isNotNull);
      final body = jsonDecode(capturedBody!) as Map<String, dynamic>;
      final contents = body['contents'] as List<dynamic>;

      // Find the model message with function call and verify signature
      final modelMessage = contents.firstWhere(
        (dynamic c) => (c as Map<String, dynamic>)['role'] == 'model',
        orElse: () => <String, dynamic>{},
      ) as Map<String, dynamic>;

      expect(modelMessage, isNotEmpty);
      final parts = modelMessage['parts'] as List<dynamic>;
      expect(parts, isNotEmpty);

      // Check that signature is at part level (sibling of functionCall)
      final functionPart = parts.first as Map<String, dynamic>;
      expect(functionPart['functionCall'], isNotNull);
      expect(functionPart['thoughtSignature'], 'sig-encrypted-abc');
    });

    test('captures signatures from multi-turn response', () async {
      final response = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'functionCall': {
                    'name': 'add_item',
                    'args': {'title': 'New item'},
                  },
                  'thoughtSignature': 'new-sig-xyz',
                }
              ]
            }
          }
        ],
      });

      final client = _FakeStreamClient(200, [response]);
      final repo = GeminiInferenceRepository(httpClient: client);
      final collector = ThoughtSignatureCollector();

      final provider = AiConfigInferenceProvider(
        id: 'prov',
        baseUrl: 'https://generativelanguage.googleapis.com',
        apiKey: 'test-key',
        name: 'Gemini',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.gemini,
      );

      await repo.generateTextWithMessages(
        messages: const [
          ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string('Add item'),
          ),
        ],
        model: 'gemini-3-flash',
        temperature: 0.5,
        thinkingConfig: GeminiThinkingConfig.disabled,
        provider: provider,
        signatureCollector: collector,
      ).toList();

      expect(collector.hasSignatures, isTrue);
      expect(collector.getSignature('tool_turn0_0'), 'new-sig-xyz');
    });

    test('emits thinking block in multi-turn mode', () async {
      final response = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'Let me think about this...', 'thought': true},
                {'text': 'Here is my response'},
              ]
            }
          }
        ],
      });

      final client = _FakeStreamClient(200, [response]);
      final repo = GeminiInferenceRepository(httpClient: client);

      final provider = AiConfigInferenceProvider(
        id: 'prov',
        baseUrl: 'https://generativelanguage.googleapis.com',
        apiKey: 'test-key',
        name: 'Gemini',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.gemini,
      );

      final events = await repo.generateTextWithMessages(
        messages: const [
          ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string('Think hard'),
          ),
        ],
        model: 'gemini-2.5-pro',
        temperature: 0.5,
        thinkingConfig: const GeminiThinkingConfig(
          thinkingBudget: 1024,
          includeThoughts: true,
        ),
        provider: provider,
      ).toList();

      expect(events.length, 2);
      expect(events[0].choices!.first.delta!.content, contains('<think>'));
      expect(
        events[0].choices!.first.delta!.content,
        contains('Let me think about this...'),
      );
      expect(events[1].choices!.first.delta!.content, 'Here is my response');
    });

    test('emits usage in multi-turn response', () async {
      final response = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'Response with usage'},
              ]
            }
          }
        ],
        'usageMetadata': {
          'promptTokenCount': 200,
          'candidatesTokenCount': 100,
          'thoughtsTokenCount': 50,
        }
      });

      final client = _FakeStreamClient(200, [response]);
      final repo = GeminiInferenceRepository(httpClient: client);

      final provider = AiConfigInferenceProvider(
        id: 'prov',
        baseUrl: 'https://generativelanguage.googleapis.com',
        apiKey: 'test-key',
        name: 'Gemini',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.gemini,
      );

      final events = await repo.generateTextWithMessages(
        messages: const [
          ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string('Hello'),
          ),
        ],
        model: 'gemini-2.5-pro',
        temperature: 0.5,
        thinkingConfig: GeminiThinkingConfig.disabled,
        provider: provider,
      ).toList();

      // Content + usage events
      expect(events.length, 2);
      expect(events.last.usage, isNotNull);
      expect(events.last.usage!.promptTokens, 200);
      expect(events.last.usage!.completionTokens, 100);
      expect(events.last.usage!.completionTokensDetails?.reasoningTokens, 50);
    });

    test('throws on non-2xx status in multi-turn mode', () async {
      final client = _FakeStreamClient(500, ['{"error":"internal"}']);
      final repo = GeminiInferenceRepository(httpClient: client);

      final provider = AiConfigInferenceProvider(
        id: 'prov',
        baseUrl: 'https://generativelanguage.googleapis.com',
        apiKey: 'test-key',
        name: 'Gemini',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.gemini,
      );

      expect(
        () => repo.generateTextWithMessages(
          messages: const [
            ChatCompletionMessage.user(
              content: ChatCompletionUserMessageContent.string('Hello'),
            ),
          ],
          model: 'gemini-2.5-pro',
          temperature: 0.5,
          thinkingConfig: GeminiThinkingConfig.disabled,
          provider: provider,
        ).toList(),
        throwsA(isA<Exception>()),
      );
    });

    test('flushes trailing thinking in multi-turn', () async {
      final response = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'Still thinking...', 'thought': true},
              ]
            }
          }
        ],
      });

      final client = _FakeStreamClient(200, [response]);
      final repo = GeminiInferenceRepository(httpClient: client);

      final provider = AiConfigInferenceProvider(
        id: 'prov',
        baseUrl: 'https://generativelanguage.googleapis.com',
        apiKey: 'test-key',
        name: 'Gemini',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.gemini,
      );

      final events = await repo.generateTextWithMessages(
        messages: const [
          ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string('Think'),
          ),
        ],
        model: 'gemini-2.5-pro',
        temperature: 0.5,
        thinkingConfig: const GeminiThinkingConfig(
          thinkingBudget: 1024,
          includeThoughts: true,
        ),
        provider: provider,
      ).toList();

      expect(events.length, 1);
      expect(events.first.choices!.first.delta!.content, contains('<think>'));
      expect(
        events.first.choices!.first.delta!.content,
        contains('Still thinking...'),
      );
    });

    test('handles empty stream in multi-turn (no fallback)', () async {
      final response = jsonEncode({
        'candidates': [
          {
            'content': {'parts': <Object?>[]}
          }
        ],
      });

      final client = _FakeStreamClient(200, [response]);
      final repo = GeminiInferenceRepository(httpClient: client);

      final provider = AiConfigInferenceProvider(
        id: 'prov',
        baseUrl: 'https://generativelanguage.googleapis.com',
        apiKey: 'test-key',
        name: 'Gemini',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.gemini,
      );

      final events = await repo.generateTextWithMessages(
        messages: const [
          ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string('Hi'),
          ),
        ],
        model: 'gemini-2.5-pro',
        temperature: 0.5,
        thinkingConfig: GeminiThinkingConfig.disabled,
        provider: provider,
      ).toList();

      // Multi-turn has no fallback, should just emit nothing
      expect(events, isEmpty);
    });

    test('includes system message in multi-turn request', () async {
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
                  {'text': 'Following system instructions'},
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

      await repo.generateTextWithMessages(
        messages: const [
          ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string('Do something'),
          ),
        ],
        model: 'gemini-2.5-pro',
        temperature: 0.5,
        thinkingConfig: GeminiThinkingConfig.disabled,
        provider: provider,
        systemMessage: 'You are a helpful assistant.',
      ).toList();

      expect(capturedBody, isNotNull);
      final body = jsonDecode(capturedBody!) as Map<String, dynamic>;
      expect(body['systemInstruction'], isNotNull);
      final sysInstruction = body['systemInstruction'] as Map<String, dynamic>;
      final parts = sysInstruction['parts'] as List<dynamic>;
      expect((parts.first as Map<String, dynamic>)['text'],
          'You are a helpful assistant.');
    });
  });

  group('Rate limit with Retry-After header', () {
    test('respects Retry-After header when present', () async {
      var attemptCount = 0;
      final client = _RetryWithHeaderClient(
        statusCodes: [429, 200],
        responses: [
          '{"error": "rate limited"}',
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'role': 'model',
                  'parts': [
                    {'text': 'Success'},
                  ],
                }
              }
            ]
          }),
        ],
        retryAfterSeconds: 1,
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
      expect(events.first.choices!.first.delta!.content, 'Success');
    });
  });

  group('generateImage', () {
    test('successfully generates an image from prompt', () async {
      // Base64 encoded minimal PNG (1x1 transparent pixel)
      const base64Png =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

      final client = _SimpleResponseClient(
        response: jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {
                    'inlineData': {
                      'mimeType': 'image/png',
                      'data': base64Png,
                    },
                  },
                ],
              },
            },
          ],
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

      final result = await repo.generateImage(
        prompt: 'Generate a test image',
        model: 'models/gemini-3-pro-image-preview',
        provider: provider,
      );

      expect(result.mimeType, 'image/png');
      expect(result.bytes, isNotEmpty);
      expect(result.extension, 'png');
    });

    test('handles snake_case response format', () async {
      const base64Png =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

      final client = _SimpleResponseClient(
        response: jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {
                    'inline_data': {
                      'mime_type': 'image/jpeg',
                      'data': base64Png,
                    },
                  },
                ],
              },
            },
          ],
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

      final result = await repo.generateImage(
        prompt: 'Generate a test image',
        model: 'models/gemini-3-pro-image-preview',
        provider: provider,
      );

      expect(result.mimeType, 'image/jpeg');
      expect(result.extension, 'jpg');
    });

    test('throws exception when no candidates', () async {
      final client = _SimpleResponseClient(
        response: jsonEncode({'candidates': <Map<String, dynamic>>[]}),
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

      expect(
        () => repo.generateImage(
          prompt: 'test',
          model: 'models/gemini-3-pro-image-preview',
          provider: provider,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('No candidates'),
          ),
        ),
      );
    });

    test('throws exception when no image data in response', () async {
      final client = _SimpleResponseClient(
        response: jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'No image here'},
                ],
              },
            },
          ],
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

      expect(
        () => repo.generateImage(
          prompt: 'test',
          model: 'models/gemini-3-pro-image-preview',
          provider: provider,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('No image data'),
          ),
        ),
      );
    });

    test('throws exception on HTTP error', () async {
      final client =
          _ErrorClient(statusCode: 400, body: '{"error": "Bad request"}');

      final repo = GeminiInferenceRepository(httpClient: client);
      final provider = AiConfigInferenceProvider(
        id: 'prov',
        baseUrl: 'https://generativelanguage.googleapis.com',
        apiKey: 'test-key',
        name: 'Gemini',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.gemini,
      );

      expect(
        () => repo.generateImage(
          prompt: 'test',
          model: 'models/gemini-3-pro-image-preview',
          provider: provider,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('400'),
          ),
        ),
      );
    });

    test('includes system message when provided', () async {
      const base64Png =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

      http.BaseRequest? capturedRequest;
      final client = _RequestCapturingClient(
        onRequest: (req) => capturedRequest = req,
        response: jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {
                    'inlineData': {
                      'mimeType': 'image/png',
                      'data': base64Png,
                    },
                  },
                ],
              },
            },
          ],
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

      await repo.generateImage(
        prompt: 'Generate a test image',
        model: 'models/gemini-3-pro-image-preview',
        provider: provider,
        systemMessage: 'You are an artist',
      );

      expect(capturedRequest, isNotNull);
      final body = (capturedRequest! as http.Request).body;
      expect(body, contains('You are an artist'));
      expect(body, contains('systemInstruction'));
    });

    test('default MIME type when not specified', () async {
      const base64Png =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

      final client = _SimpleResponseClient(
        response: jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {
                    'inlineData': {
                      'data': base64Png,
                    },
                  },
                ],
              },
            },
          ],
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

      final result = await repo.generateImage(
        prompt: 'test',
        model: 'models/gemini-3-pro-image-preview',
        provider: provider,
      );

      // Defaults to image/png when not specified
      expect(result.mimeType, 'image/png');
    });
  });

  group('GeneratedImage', () {
    test('extension returns correct values', () {
      expect(
        const GeneratedImage(bytes: [], mimeType: 'image/png').extension,
        'png',
      );
      expect(
        const GeneratedImage(bytes: [], mimeType: 'image/jpeg').extension,
        'jpg',
      );
      expect(
        const GeneratedImage(bytes: [], mimeType: 'image/gif').extension,
        'gif',
      );
      expect(
        const GeneratedImage(bytes: [], mimeType: 'image/webp').extension,
        'webp',
      );
      expect(
        const GeneratedImage(bytes: [], mimeType: 'unknown').extension,
        'png',
      );
    });
  });
}

/// Simple response client for non-streaming tests
class _SimpleResponseClient extends http.BaseClient {
  _SimpleResponseClient({required this.response});

  final String response;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bytes = utf8.encode(response);
    final stream = Stream<List<int>>.fromIterable([bytes]);
    return http.StreamedResponse(stream, 200, headers: {
      'content-type': 'application/json',
    });
  }
}

/// Error client for testing error handling
class _ErrorClient extends http.BaseClient {
  _ErrorClient({required this.statusCode, required this.body});

  final int statusCode;
  final String body;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bytes = utf8.encode(body);
    final stream = Stream<List<int>>.fromIterable([bytes]);
    return http.StreamedResponse(stream, statusCode, headers: {
      'content-type': 'application/json',
    });
  }
}

/// Test client with Retry-After header support
class _RetryWithHeaderClient extends http.BaseClient {
  _RetryWithHeaderClient({
    required this.statusCodes,
    required this.responses,
    this.retryAfterSeconds,
    this.onRequest,
  });

  final List<int> statusCodes;
  final List<String> responses;
  final int? retryAfterSeconds;
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

    final headers = <String, String>{'content-type': 'application/json'};
    if (statusCodes[idx] == 429 && retryAfterSeconds != null) {
      headers['retry-after'] = retryAfterSeconds.toString();
    }

    return http.StreamedResponse(
      stream,
      statusCodes[idx],
      headers: headers,
    );
  }
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
