import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/gemini_multiturn_inference.dart';
import 'package:lotti/features/ai/repository/gemini_stream_sender.dart';
import 'package:lotti/features/ai/repository/gemini_thinking_config.dart';
import 'package:openai_dart/openai_dart.dart';

AiConfigInferenceProvider _provider() => AiConfigInferenceProvider(
  id: 'prov',
  baseUrl: 'https://generativelanguage.googleapis.com',
  apiKey: 'key',
  name: 'Gemini',
  createdAt: DateTime(2024),
  inferenceProviderType: InferenceProviderType.gemini,
);

/// Streams scripted NDJSON lines for `:streamGenerateContent` and records the
/// request path/body so we can assert the function routed through the sender.
class _RecordingStreamClient extends http.BaseClient {
  _RecordingStreamClient(this._lines, {this.statusCode = 200});

  final List<String> _lines;
  final int statusCode;
  String? path;
  String? body;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    path = request.url.path;
    if (request is http.Request) body = request.body;
    final data = _lines.map((l) => utf8.encode('$l\n') as List<int>);
    return http.StreamedResponse(
      Stream<List<int>>.fromIterable(data),
      statusCode,
      headers: const {'content-type': 'application/json'},
    );
  }
}

List<ChatCompletionMessage> _messages() => [
  const ChatCompletionMessage.user(
    content: ChatCompletionUserMessageContent.string('hi'),
  ),
];

void main() {
  group('generateGeminiTextWithMessages', () {
    test(
      'routes through the sender to the streaming endpoint and emits text',
      () async {
        final client = _RecordingStreamClient([
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'Hello back'},
                  ],
                },
              },
            ],
          }),
        ]);
        final sender = GeminiStreamSender(httpClient: client);

        final events = await generateGeminiTextWithMessages(
          sender: sender,
          messages: _messages(),
          model: 'gemini-2.5-pro',
          temperature: 0.5,
          thinkingConfig: GeminiThinkingConfig.disabled,
          provider: _provider(),
        ).toList();

        expect(client.path, endsWith(':streamGenerateContent'));
        expect(
          events.map((e) => e.choices?.first.delta?.content).join(),
          'Hello back',
        );
      },
    );

    test('emits a usage chunk when usageMetadata is present', () async {
      final client = _RecordingStreamClient([
        jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'ok'},
                ],
              },
            },
          ],
          'usageMetadata': {
            'promptTokenCount': 11,
            'candidatesTokenCount': 7,
          },
        }),
      ]);
      final sender = GeminiStreamSender(httpClient: client);

      final events = await generateGeminiTextWithMessages(
        sender: sender,
        messages: _messages(),
        model: 'gemini-2.5-pro',
        temperature: 0,
        thinkingConfig: GeminiThinkingConfig.disabled,
        provider: _provider(),
      ).toList();

      final usage = events.firstWhere((e) => e.usage != null).usage!;
      expect(usage.promptTokens, 11);
      expect(usage.completionTokens, 7);
    });

    test('uses turnIndex to build turn-prefixed tool call IDs', () async {
      final client = _RecordingStreamClient([
        jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {
                    'functionCall': {
                      'name': 'do_thing',
                      'args': {'x': 1},
                    },
                  },
                ],
              },
            },
          ],
        }),
      ]);
      final sender = GeminiStreamSender(httpClient: client);

      final events = await generateGeminiTextWithMessages(
        sender: sender,
        messages: _messages(),
        model: 'gemini-3-pro',
        temperature: 0,
        thinkingConfig: GeminiThinkingConfig.disabled,
        provider: _provider(),
        turnIndex: 2,
      ).toList();

      final toolCall = events
          .expand(
            (e) => e.choices ?? const <ChatCompletionStreamResponseChoice>[],
          )
          .map((c) => c.delta?.toolCalls)
          .whereType<List<ChatCompletionStreamMessageToolCallChunk>>()
          .expand((t) => t)
          .first;
      expect(toolCall.id, 'tool_turn2_0');
      expect(toolCall.function?.name, 'do_thing');
    });

    test('throws on a non-2xx streaming status', () async {
      final client = _RecordingStreamClient(
        [
          jsonEncode({'error': 'nope'}),
        ],
        statusCode: 500,
      );
      final sender = GeminiStreamSender(httpClient: client);

      await expectLater(
        generateGeminiTextWithMessages(
          sender: sender,
          messages: _messages(),
          model: 'gemini-2.5-pro',
          temperature: 0,
          thinkingConfig: GeminiThinkingConfig.disabled,
          provider: _provider(),
        ).toList(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('500'),
          ),
        ),
      );
    });

    test(
      'includes the system message in the request body when provided',
      () async {
        final client = _RecordingStreamClient([
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'ok'},
                  ],
                },
              },
            ],
          }),
        ]);
        final sender = GeminiStreamSender(httpClient: client);

        await generateGeminiTextWithMessages(
          sender: sender,
          messages: _messages(),
          model: 'gemini-2.5-pro',
          temperature: 0,
          thinkingConfig: GeminiThinkingConfig.disabled,
          provider: _provider(),
          systemMessage: 'you are concise',
        ).toList();

        expect(client.body, contains('you are concise'));
      },
    );
  });
}
