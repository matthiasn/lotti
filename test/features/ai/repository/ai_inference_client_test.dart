import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/model/ai_chat_message.dart';
import 'package:lotti/features/ai/repository/ai_inference_client.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

class _FakeRequest extends Fake implements http.Request {}

http.StreamedResponse _sse(
  List<Map<String, dynamic>> events, {
  int statusCode = 200,
  bool includeDone = true,
}) {
  final lines = events.map((e) => 'data: ${jsonEncode(e)}\n\n').toList();
  if (includeDone) lines.add('data: [DONE]\n\n');
  return http.StreamedResponse(
    Stream.fromIterable([utf8.encode(lines.join())]),
    statusCode,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeRequest());
  });

  group('AiInferenceClient.chatCompletionsStream', () {
    test('sends bearer auth + JSON body and parses content deltas', () async {
      final httpClient = MockHttpClient();
      final captured = <http.Request>[];

      when(() => httpClient.send(any())).thenAnswer((invocation) async {
        captured.add(invocation.positionalArguments.first as http.Request);
        return _sse([
          {
            'id': 'cmpl-1',
            'choices': [
              {
                'index': 0,
                'delta': {'role': 'assistant', 'content': 'Hi'},
              },
            ],
          },
          {
            'id': 'cmpl-1',
            'choices': [
              {
                'index': 0,
                'delta': {'content': '!'},
                'finish_reason': 'stop',
              },
            ],
          },
        ]);
      });

      final client = AiInferenceClient(
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'sk-test',
        httpClient: httpClient,
      );

      final chunks = await client
          .chatCompletionsStream(
            messages: const [AiUserMessage(AiUserTextContent('hi'))],
            model: 'gpt-4o-mini',
            temperature: 0.5,
            maxCompletionTokens: 100,
          )
          .toList();

      expect(chunks, hasLength(2));
      expect(chunks.first.choices.first.delta.content, 'Hi');
      expect(chunks.last.choices.first.finishReason, 'stop');

      expect(captured, hasLength(1));
      final sent = captured.single;
      expect(sent.method, 'POST');
      expect(sent.url.toString(), 'https://api.openai.com/v1/chat/completions');
      expect(sent.headers['Authorization'], 'Bearer sk-test');
      expect(sent.headers['Content-Type'], 'application/json');
      expect(sent.headers['Accept'], 'text/event-stream');
      final body = jsonDecode(sent.body) as Map<String, dynamic>;
      expect(body['model'], 'gpt-4o-mini');
      expect(body['stream'], true);
      expect(body['temperature'], 0.5);
      expect(body['max_completion_tokens'], 100);
      expect(body.containsKey('max_tokens'), isFalse);
      expect(body.containsKey('tools'), isFalse);
      expect(body['messages'], [
        {'role': 'user', 'content': 'hi'},
      ]);
    });

    test('serializes tools and tool_choice when provided', () async {
      final httpClient = MockHttpClient();
      late http.Request sent;

      when(() => httpClient.send(any())).thenAnswer((invocation) async {
        sent = invocation.positionalArguments.first as http.Request;
        return _sse([]);
      });

      final client = AiInferenceClient(
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'k',
        httpClient: httpClient,
      );

      await client
          .chatCompletionsStream(
            messages: const [AiUserMessage(AiUserTextContent('x'))],
            model: 'gpt-4o',
            tools: const [
              AiTool(
                name: 'get_weather',
                description: 'Get weather',
                parameters: {'type': 'object'},
              ),
            ],
            toolChoice: const AiToolChoiceFunction('get_weather'),
          )
          .toList();

      final body = jsonDecode(sent.body) as Map<String, dynamic>;
      expect(body['tools'], [
        {
          'type': 'function',
          'function': {
            'name': 'get_weather',
            'description': 'Get weather',
            'parameters': {'type': 'object'},
          },
        },
      ]);
      expect(body['tool_choice'], {
        'type': 'function',
        'function': {'name': 'get_weather'},
      });
    });

    test(
      'absorbs Anthropic ping events (choices missing) without errors',
      () async {
        final httpClient = MockHttpClient();
        when(() => httpClient.send(any())).thenAnswer(
          (_) async => _sse([
            {'id': 'ping'},
            {
              'id': '1',
              'choices': [
                {
                  'index': 0,
                  'delta': {'content': 'real'},
                },
              ],
            },
          ]),
        );

        final client = AiInferenceClient(
          baseUrl: 'https://example.com',
          apiKey: 'k',
          httpClient: httpClient,
        );

        final chunks = await client
            .chatCompletionsStream(
              messages: const [AiUserMessage(AiUserTextContent('x'))],
              model: 'm',
            )
            .toList();

        expect(chunks, hasLength(1));
        expect(chunks.single.choices.first.delta.content, 'real');
      },
    );

    test('throws AiInferenceException on non-200 with body included', () async {
      final httpClient = MockHttpClient();
      when(() => httpClient.send(any())).thenAnswer(
        (_) async => http.StreamedResponse(
          Stream.fromIterable([utf8.encode('rate limited')]),
          429,
        ),
      );

      final client = AiInferenceClient(
        baseUrl: 'https://example.com',
        apiKey: 'k',
        httpClient: httpClient,
      );

      expect(
        () => client
            .chatCompletionsStream(
              messages: const [AiUserMessage(AiUserTextContent('x'))],
              model: 'm',
            )
            .toList(),
        throwsA(
          isA<AiInferenceException>()
              .having((e) => e.statusCode, 'statusCode', 429)
              .having((e) => e.message, 'message', contains('rate limited')),
        ),
      );
    });

    test('joins baseUrl with a trailing slash correctly', () async {
      final httpClient = MockHttpClient();
      late http.Request sent;
      when(() => httpClient.send(any())).thenAnswer((invocation) async {
        sent = invocation.positionalArguments.first as http.Request;
        return _sse([]);
      });

      final client = AiInferenceClient(
        baseUrl: 'https://example.com/v1/',
        apiKey: 'k',
        httpClient: httpClient,
      );

      await client
          .chatCompletionsStream(
            messages: const [AiUserMessage(AiUserTextContent('x'))],
            model: 'm',
          )
          .toList();

      expect(sent.url.toString(), 'https://example.com/v1/chat/completions');
    });

    test('handles SSE data split across chunk boundaries', () async {
      final httpClient = MockHttpClient();
      // Split one event across two raw chunks
      final part1 = utf8.encode('data: {"id":"1","choices":[{"i');
      final part2 = utf8.encode(
        'ndex":0,"delta":{"content":"x"}}]}\n\ndata: [DONE]\n\n',
      );
      when(() => httpClient.send(any())).thenAnswer(
        (_) async => http.StreamedResponse(
          Stream.fromIterable([part1, part2]),
          200,
        ),
      );

      final client = AiInferenceClient(
        baseUrl: 'https://example.com',
        apiKey: 'k',
        httpClient: httpClient,
      );

      final chunks = await client
          .chatCompletionsStream(
            messages: const [AiUserMessage(AiUserTextContent('x'))],
            model: 'm',
          )
          .toList();

      expect(chunks, hasLength(1));
      expect(chunks.single.choices.first.delta.content, 'x');
    });
  });
}
