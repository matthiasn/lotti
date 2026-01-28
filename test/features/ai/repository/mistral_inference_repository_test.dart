// ignore_for_file: avoid_redundant_argument_values

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/repository/mistral_inference_repository.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

class MockHttpClient extends Mock implements http.Client {}

class MockLoggingService extends Mock implements LoggingService {}

class FakeRequest extends Fake implements http.Request {}

class FakeBaseRequest extends Fake implements http.BaseRequest {}

/// Creates a mock SSE stream response for testing
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

/// Creates a mock SSE event for a chunk with content
Map<String, dynamic> createSseChunkEvent({
  String? content,
  String? id,
  String? finishReason,
  int? created,
  String model = 'magistral-medium-2509',
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
          if (content != null) 'content': content,
          if (role != null) 'role': role,
          if (toolCalls != null) 'tool_calls': toolCalls,
        },
        'finish_reason': finishReason,
      }
    ],
    if (usage != null) 'usage': usage,
  };
}

/// Creates a final SSE event with finish_reason but no content
Map<String, dynamic> createSseFinalEvent({
  String? id,
  int? created,
  String model = 'magistral-medium-2509',
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
      }
    ],
  };
}

void main() {
  late MistralInferenceRepository repository;
  late MockHttpClient mockHttpClient;

  setUpAll(() {
    registerFallbackValue(FakeRequest());
    registerFallbackValue(FakeBaseRequest());
    registerFallbackValue(Uri.parse('https://api.mistral.ai/v1'));
  });

  setUp(() {
    mockHttpClient = MockHttpClient();
    repository = MistralInferenceRepository(httpClient: mockHttpClient);
  });

  group('MistralInferenceRepository', () {
    group('generateText', () {
      const model = 'magistral-medium-2509';
      const baseUrl = 'https://api.mistral.ai/v1';
      const apiKey = 'test-api-key';
      const prompt = 'Hello, how are you?';

      test('should generate text with streaming', () async {
        // Arrange
        const chunk1 = 'Hello!';
        const chunk2 = ' I am doing great.';
        final events = [
          createSseChunkEvent(content: chunk1, role: 'assistant'),
          createSseChunkEvent(content: chunk2),
          createSseFinalEvent(),
        ];

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: events),
        );

        // Act
        final stream = repository.generateText(
          prompt: prompt,
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        final results = await stream.toList();

        // Assert
        expect(results.length, equals(3));
        expect(results[0].choices?.first.delta?.content, equals(chunk1));
        expect(results[0].choices?.first.delta?.role,
            equals(ChatCompletionMessageRole.assistant));
        expect(results[1].choices?.first.delta?.content, equals(chunk2));

        // Verify the request
        final captured =
            verify(() => mockHttpClient.send(captureAny())).captured;
        final request = captured.first as http.Request;
        expect(request.url.toString(), equals('$baseUrl/chat/completions'));
        expect(request.headers['Content-Type'], equals('application/json'));
        expect(request.headers['Accept'], equals('text/event-stream'));
        expect(request.headers['Authorization'], equals('Bearer $apiKey'));

        final requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        expect(requestBody['model'], equals(model));
        expect(requestBody['stream'], isTrue);

        final messages = requestBody['messages'] as List<dynamic>;
        expect(messages.length, equals(1));
        expect((messages[0] as Map<String, dynamic>)['role'], equals('user'));
        expect(
            (messages[0] as Map<String, dynamic>)['content'], equals(prompt));
      });

      test('should include system message when provided', () async {
        // Arrange
        final events = [
          createSseChunkEvent(content: 'Response'),
          createSseFinalEvent(),
        ];

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: events),
        );

        // Act
        final stream = repository.generateText(
          prompt: prompt,
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
          systemMessage: 'You are a helpful assistant.',
        );

        await stream.toList();

        // Assert
        final captured =
            verify(() => mockHttpClient.send(captureAny())).captured;
        final request = captured.first as http.Request;
        final requestBody = jsonDecode(request.body) as Map<String, dynamic>;

        final messages = requestBody['messages'] as List<dynamic>;
        expect(messages.length, equals(2));
        expect((messages[0] as Map<String, dynamic>)['role'], equals('system'));
        expect((messages[0] as Map<String, dynamic>)['content'],
            equals('You are a helpful assistant.'));
        expect((messages[1] as Map<String, dynamic>)['role'], equals('user'));
        expect(
            (messages[1] as Map<String, dynamic>)['content'], equals(prompt));
      });

      test('should include temperature when provided', () async {
        // Arrange
        final events = [
          createSseChunkEvent(content: 'Response'),
          createSseFinalEvent(),
        ];

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: events),
        );

        // Act
        final stream = repository.generateText(
          prompt: prompt,
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
          temperature: 0.7,
        );

        await stream.toList();

        // Assert
        final captured =
            verify(() => mockHttpClient.send(captureAny())).captured;
        final request = captured.first as http.Request;
        final requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        expect(requestBody['temperature'], equals(0.7));
      });

      test('should include maxCompletionTokens when provided', () async {
        // Arrange
        final events = [
          createSseChunkEvent(content: 'Response'),
          createSseFinalEvent(),
        ];

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: events),
        );

        // Act
        final stream = repository.generateText(
          prompt: prompt,
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
          maxCompletionTokens: 1000,
        );

        await stream.toList();

        // Assert
        final captured =
            verify(() => mockHttpClient.send(captureAny())).captured;
        final request = captured.first as http.Request;
        final requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        expect(requestBody['max_tokens'], equals(1000));
      });

      test('should include tools when provided', () async {
        // Arrange
        final events = [
          createSseChunkEvent(
            toolCalls: [
              {
                'id': 'call_123',
                'index': 0,
                'function': {
                  'name': 'get_weather',
                  'arguments': '{"location": "Paris"}',
                },
              }
            ],
          ),
          createSseFinalEvent(),
        ];

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: events),
        );

        final tools = [
          const ChatCompletionTool(
            type: ChatCompletionToolType.function,
            function: FunctionObject(
              name: 'get_weather',
              description: 'Get the weather for a location',
              parameters: {
                'type': 'object',
                'properties': {
                  'location': {'type': 'string'},
                },
                'required': ['location'],
              },
            ),
          ),
        ];

        // Act
        final stream = repository.generateText(
          prompt: prompt,
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
          tools: tools,
        );

        final results = await stream.toList();

        // Assert - verify tool calls are parsed
        expect(results.length, equals(2));
        expect(results[0].choices?.first.delta?.toolCalls, isNotNull);
        expect(results[0].choices?.first.delta?.toolCalls?.length, equals(1));
        expect(results[0].choices?.first.delta?.toolCalls?.first.id,
            equals('call_123'));
        expect(results[0].choices?.first.delta?.toolCalls?.first.function?.name,
            equals('get_weather'));

        // Verify request body includes tools
        final captured =
            verify(() => mockHttpClient.send(captureAny())).captured;
        final request = captured.first as http.Request;
        final requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        expect(requestBody['tools'], isNotNull);
        expect(requestBody['tool_choice'], equals('auto'));
      });

      test('should handle HTTP error responses', () async {
        // Arrange
        final stream =
            Stream.fromIterable([utf8.encode('{"error": "Invalid API key"}')]);
        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => http.StreamedResponse(stream, 401),
        );

        // Act & Assert
        final responseStream = repository.generateText(
          prompt: prompt,
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        expect(
          responseStream.toList(),
          throwsA(isA<MistralInferenceException>()
              .having((e) => e.message, 'message', contains('HTTP 401'))
              .having((e) => e.statusCode, 'statusCode', 401)),
        );
      });

      test('should handle 404 error', () async {
        // Arrange
        final stream = Stream.fromIterable(
            [utf8.encode('{"message": "no Route matched with those values"}')]);
        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => http.StreamedResponse(stream, 404),
        );

        // Act & Assert
        final responseStream = repository.generateText(
          prompt: prompt,
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        expect(
          responseStream.toList(),
          throwsA(isA<MistralInferenceException>()
              .having((e) => e.statusCode, 'statusCode', 404)),
        );
      });
    });

    group('generateTextWithMessages', () {
      const model = 'magistral-medium-2509';
      const baseUrl = 'https://api.mistral.ai/v1';
      const apiKey = 'test-api-key';

      test('should convert system messages correctly', () async {
        // Arrange
        final events = [
          createSseChunkEvent(content: 'Response'),
          createSseFinalEvent(),
        ];

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: events),
        );

        final messages = [
          const ChatCompletionMessage.system(
              content: 'You are a helpful assistant.'),
          const ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string('Hello'),
          ),
        ];

        // Act
        final stream = repository.generateTextWithMessages(
          messages: messages,
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        await stream.toList();

        // Assert
        final captured =
            verify(() => mockHttpClient.send(captureAny())).captured;
        final request = captured.first as http.Request;
        final requestBody = jsonDecode(request.body) as Map<String, dynamic>;

        final reqMessages = requestBody['messages'] as List<dynamic>;
        expect(reqMessages.length, equals(2));
        expect((reqMessages[0] as Map)['role'], equals('system'));
        expect((reqMessages[0] as Map)['content'],
            equals('You are a helpful assistant.'));
        expect((reqMessages[1] as Map)['role'], equals('user'));
        expect((reqMessages[1] as Map)['content'], equals('Hello'));
      });

      test('should convert assistant messages with tool calls', () async {
        // Arrange
        final events = [
          createSseChunkEvent(content: 'Response'),
          createSseFinalEvent(),
        ];

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: events),
        );

        final messages = [
          const ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string('What is 2+2?'),
          ),
          const ChatCompletionMessage.assistant(
            content: 'Let me calculate that.',
            toolCalls: [
              ChatCompletionMessageToolCall(
                id: 'call_123',
                type: ChatCompletionMessageToolCallType.function,
                function: ChatCompletionMessageFunctionCall(
                  name: 'calculate',
                  arguments: '{"expression": "2+2"}',
                ),
              ),
            ],
          ),
        ];

        // Act
        final stream = repository.generateTextWithMessages(
          messages: messages,
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        await stream.toList();

        // Assert
        final captured =
            verify(() => mockHttpClient.send(captureAny())).captured;
        final request = captured.first as http.Request;
        final requestBody = jsonDecode(request.body) as Map<String, dynamic>;

        final reqMessages = requestBody['messages'] as List<dynamic>;
        expect(reqMessages.length, equals(2));

        final assistantMsg = reqMessages[1] as Map<String, dynamic>;
        expect(assistantMsg['role'], equals('assistant'));
        expect(assistantMsg['content'], equals('Let me calculate that.'));
        expect(assistantMsg['tool_calls'], isNotNull);
        expect((assistantMsg['tool_calls'] as List).length, equals(1));

        final toolCall =
            (assistantMsg['tool_calls'] as List).first as Map<String, dynamic>;
        expect(toolCall['id'], equals('call_123'));
        final function = toolCall['function'] as Map<String, dynamic>;
        expect(function['name'], equals('calculate'));
      });

      test('should convert tool messages correctly', () async {
        // Arrange
        final events = [
          createSseChunkEvent(content: 'The answer is 4'),
          createSseFinalEvent(),
        ];

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: events),
        );

        final messages = [
          const ChatCompletionMessage.tool(
            toolCallId: 'call_123',
            content: '4',
          ),
        ];

        // Act
        final stream = repository.generateTextWithMessages(
          messages: messages,
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        await stream.toList();

        // Assert
        final captured =
            verify(() => mockHttpClient.send(captureAny())).captured;
        final request = captured.first as http.Request;
        final requestBody = jsonDecode(request.body) as Map<String, dynamic>;

        final reqMessages = requestBody['messages'] as List<dynamic>;
        expect(reqMessages.length, equals(1));

        final toolMsg = reqMessages[0] as Map<String, dynamic>;
        expect(toolMsg['role'], equals('tool'));
        expect(toolMsg['tool_call_id'], equals('call_123'));
        expect(toolMsg['content'], equals('4'));
      });
    });

    group('content extraction', () {
      const model = 'magistral-medium-2509';
      const baseUrl = 'https://api.mistral.ai/v1';
      const apiKey = 'test-api-key';

      test('should handle content as string', () async {
        // Arrange
        final events = [
          createSseChunkEvent(content: 'Hello world'),
          createSseFinalEvent(),
        ];

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: events),
        );

        // Act
        final stream = repository.generateText(
          prompt: 'Hi',
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        final results = await stream.toList();

        // Assert
        expect(results[0].choices?.first.delta?.content, equals('Hello world'));
      });

      test('should handle content as array of text parts', () async {
        // Arrange - content as array (Mistral's format for some responses)
        final event = {
          'id': 'chatcmpl-test',
          'object': 'chat.completion.chunk',
          'created': 1234567890,
          'model': model,
          'choices': [
            {
              'index': 0,
              'delta': {
                'content': [
                  {'type': 'text', 'text': 'Hello '},
                  {'type': 'text', 'text': 'world'},
                ],
              },
              'finish_reason': null,
            }
          ],
        };

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: [event]),
        );

        // Act
        final stream = repository.generateText(
          prompt: 'Hi',
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        final results = await stream.toList();

        // Assert - should concatenate text parts
        expect(results[0].choices?.first.delta?.content, equals('Hello world'));
      });

      test('should handle content as array of strings', () async {
        // Arrange
        final event = {
          'id': 'chatcmpl-test',
          'object': 'chat.completion.chunk',
          'created': 1234567890,
          'model': model,
          'choices': [
            {
              'index': 0,
              'delta': {
                'content': ['Hello ', 'world'],
              },
              'finish_reason': null,
            }
          ],
        };

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: [event]),
        );

        // Act
        final stream = repository.generateText(
          prompt: 'Hi',
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        final results = await stream.toList();

        // Assert
        expect(results[0].choices?.first.delta?.content, equals('Hello world'));
      });

      test('should handle null content', () async {
        // Arrange
        final event = {
          'id': 'chatcmpl-test',
          'object': 'chat.completion.chunk',
          'created': 1234567890,
          'model': model,
          'choices': [
            {
              'index': 0,
              'delta': {
                'role': 'assistant',
              },
              'finish_reason': null,
            }
          ],
        };

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: [event]),
        );

        // Act
        final stream = repository.generateText(
          prompt: 'Hi',
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        final results = await stream.toList();

        // Assert
        expect(results[0].choices?.first.delta?.content, isNull);
        expect(results[0].choices?.first.delta?.role,
            equals(ChatCompletionMessageRole.assistant));
      });

      test('should handle empty array content', () async {
        // Arrange
        final event = {
          'id': 'chatcmpl-test',
          'object': 'chat.completion.chunk',
          'created': 1234567890,
          'model': model,
          'choices': [
            {
              'index': 0,
              'delta': {
                'content': <dynamic>[],
              },
              'finish_reason': null,
            }
          ],
        };

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: [event]),
        );

        // Act
        final stream = repository.generateText(
          prompt: 'Hi',
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        final results = await stream.toList();

        // Assert
        expect(results[0].choices?.first.delta?.content, isNull);
      });
    });

    group('SSE stream buffering', () {
      const model = 'magistral-medium-2509';
      const baseUrl = 'https://api.mistral.ai/v1';
      const apiKey = 'test-api-key';

      test('should handle fragmented SSE chunks', () async {
        // Arrange - simulate fragmented network chunks
        final event1 = createSseChunkEvent(content: 'First chunk');
        final event2 = createSseChunkEvent(content: 'Second chunk');

        // Split the SSE data into fragments that cut JSON in the middle
        final fullSse =
            'data: ${jsonEncode(event1)}\n\ndata: ${jsonEncode(event2)}\n\ndata: [DONE]\n\n';

        // Fragment at an arbitrary position
        final fragment1 = fullSse.substring(0, 50);
        final fragment2 = fullSse.substring(50);

        final stream = Stream.fromIterable([
          utf8.encode(fragment1),
          utf8.encode(fragment2),
        ]);

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => http.StreamedResponse(stream, 200),
        );

        // Act
        final responseStream = repository.generateText(
          prompt: 'Hi',
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        final results = await responseStream.toList();

        // Assert - should properly buffer and parse both events
        expect(results.length, equals(2));
        expect(results[0].choices?.first.delta?.content, equals('First chunk'));
        expect(
            results[1].choices?.first.delta?.content, equals('Second chunk'));
      });

      test('should handle multiple events in single chunk', () async {
        // Arrange
        final event1 = createSseChunkEvent(content: 'Chunk 1');
        final event2 = createSseChunkEvent(content: 'Chunk 2');
        final event3 = createSseChunkEvent(content: 'Chunk 3');

        final allInOne =
            'data: ${jsonEncode(event1)}\n\ndata: ${jsonEncode(event2)}\n\ndata: ${jsonEncode(event3)}\n\ndata: [DONE]\n\n';

        final stream = Stream.fromIterable([utf8.encode(allInOne)]);

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => http.StreamedResponse(stream, 200),
        );

        // Act
        final responseStream = repository.generateText(
          prompt: 'Hi',
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        final results = await responseStream.toList();

        // Assert
        expect(results.length, equals(3));
        expect(results[0].choices?.first.delta?.content, equals('Chunk 1'));
        expect(results[1].choices?.first.delta?.content, equals('Chunk 2'));
        expect(results[2].choices?.first.delta?.content, equals('Chunk 3'));
      });

      test('should handle malformed SSE data gracefully', () async {
        // Arrange - mix valid and invalid SSE events
        const sseData = '''
data: {"id": "test", "choices": [{"delta": {"content": "Valid chunk"}, "index": 0}], "object": "chat.completion.chunk", "created": 1234}

data: invalid json here

data: {"id": "test", "choices": [{"delta": {"content": "Another valid"}, "index": 0}], "object": "chat.completion.chunk", "created": 1234}

data: [DONE]

''';

        final stream = Stream.fromIterable([utf8.encode(sseData)]);
        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => http.StreamedResponse(stream, 200),
        );

        // Act
        final responseStream = repository.generateText(
          prompt: 'Hi',
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        final results = await responseStream.toList();

        // Assert - should skip invalid JSON and continue
        expect(results.length, equals(2));
        expect(results[0].choices?.first.delta?.content, equals('Valid chunk'));
        expect(
            results[1].choices?.first.delta?.content, equals('Another valid'));
      });

      test('should handle empty stream', () async {
        // Arrange
        const sseData = 'data: [DONE]\n\n';
        final stream = Stream.fromIterable([utf8.encode(sseData)]);

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => http.StreamedResponse(stream, 200),
        );

        // Act
        final responseStream = repository.generateText(
          prompt: 'Hi',
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        final results = await responseStream.toList();

        // Assert
        expect(results, isEmpty);
      });
    });

    group('URL construction', () {
      const model = 'magistral-medium-2509';
      const apiKey = 'test-api-key';

      test('should construct URL correctly without trailing slash', () async {
        // Arrange
        final events = [createSseChunkEvent(content: 'Test')];
        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: events),
        );

        // Act
        final stream = repository.generateText(
          prompt: 'Hi',
          model: model,
          baseUrl: 'https://api.mistral.ai/v1',
          apiKey: apiKey,
        );

        await stream.toList();

        // Assert
        final captured =
            verify(() => mockHttpClient.send(captureAny())).captured;
        final request = captured.first as http.Request;
        expect(request.url.toString(),
            equals('https://api.mistral.ai/v1/chat/completions'));
      });

      test('should construct URL correctly with trailing slash', () async {
        // Arrange
        final events = [createSseChunkEvent(content: 'Test')];
        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: events),
        );

        // Act
        final stream = repository.generateText(
          prompt: 'Hi',
          model: model,
          baseUrl: 'https://api.mistral.ai/v1/',
          apiKey: apiKey,
        );

        await stream.toList();

        // Assert
        final captured =
            verify(() => mockHttpClient.send(captureAny())).captured;
        final request = captured.first as http.Request;
        expect(request.url.toString(),
            equals('https://api.mistral.ai/v1/chat/completions'));
      });
    });

    group('tool call parsing', () {
      const model = 'magistral-medium-2509';
      const baseUrl = 'https://api.mistral.ai/v1';
      const apiKey = 'test-api-key';

      test('should parse single tool call', () async {
        // Arrange
        final event = {
          'id': 'chatcmpl-test',
          'object': 'chat.completion.chunk',
          'created': 1234567890,
          'model': model,
          'choices': [
            {
              'index': 0,
              'delta': {
                'tool_calls': [
                  {
                    'id': 'call_abc123',
                    'index': 0,
                    'function': {
                      'name': 'get_weather',
                      'arguments': '{"location": "Paris"}',
                    },
                  }
                ],
              },
              'finish_reason': null,
            }
          ],
        };

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: [event]),
        );

        // Act
        final stream = repository.generateText(
          prompt: 'What is the weather?',
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        final results = await stream.toList();

        // Assert
        expect(results.length, equals(1));
        final toolCalls = results[0].choices?.first.delta?.toolCalls;
        expect(toolCalls, isNotNull);
        expect(toolCalls?.length, equals(1));
        expect(toolCalls?.first.id, equals('call_abc123'));
        expect(toolCalls?.first.index, equals(0));
        expect(toolCalls?.first.function?.name, equals('get_weather'));
        expect(toolCalls?.first.function?.arguments,
            equals('{"location": "Paris"}'));
      });

      test('should parse multiple tool calls', () async {
        // Arrange
        final event = {
          'id': 'chatcmpl-test',
          'object': 'chat.completion.chunk',
          'created': 1234567890,
          'model': model,
          'choices': [
            {
              'index': 0,
              'delta': {
                'tool_calls': [
                  {
                    'id': 'call_1',
                    'index': 0,
                    'function': {'name': 'tool_a', 'arguments': '{}'},
                  },
                  {
                    'id': 'call_2',
                    'index': 1,
                    'function': {'name': 'tool_b', 'arguments': '{}'},
                  },
                ],
              },
              'finish_reason': null,
            }
          ],
        };

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: [event]),
        );

        // Act
        final stream = repository.generateText(
          prompt: 'Use both tools',
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        final results = await stream.toList();

        // Assert
        final toolCalls = results[0].choices?.first.delta?.toolCalls;
        expect(toolCalls?.length, equals(2));
        expect(toolCalls?[0].function?.name, equals('tool_a'));
        expect(toolCalls?[1].function?.name, equals('tool_b'));
      });

      test('should handle null tool_calls', () async {
        // Arrange
        final event = createSseChunkEvent(content: 'Just text, no tools');

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: [event]),
        );

        // Act
        final stream = repository.generateText(
          prompt: 'Hi',
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        final results = await stream.toList();

        // Assert
        expect(results[0].choices?.first.delta?.toolCalls, isNull);
      });
    });

    group('usage parsing', () {
      const model = 'magistral-medium-2509';
      const baseUrl = 'https://api.mistral.ai/v1';
      const apiKey = 'test-api-key';

      test('should parse usage from response', () async {
        // Arrange
        final event = createSseChunkEvent(
          content: 'Hello',
          usage: {
            'prompt_tokens': 10,
            'completion_tokens': 5,
            'total_tokens': 15,
          },
        );

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: [event]),
        );

        // Act
        final stream = repository.generateText(
          prompt: 'Hi',
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        final results = await stream.toList();

        // Assert
        expect(results[0].usage, isNotNull);
        expect(results[0].usage?.promptTokens, equals(10));
        expect(results[0].usage?.completionTokens, equals(5));
        expect(results[0].usage?.totalTokens, equals(15));
      });
    });

    group('finish reason parsing', () {
      const model = 'magistral-medium-2509';
      const baseUrl = 'https://api.mistral.ai/v1';
      const apiKey = 'test-api-key';

      test('should parse stop finish reason', () async {
        // Arrange
        final event =
            createSseChunkEvent(content: 'Done', finishReason: 'stop');

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: [event]),
        );

        // Act
        final stream = repository.generateText(
          prompt: 'Hi',
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        final results = await stream.toList();

        // Assert
        expect(results[0].choices?.first.finishReason,
            equals(ChatCompletionFinishReason.stop));
      });

      test('should parse tool_calls finish reason', () async {
        // Arrange
        final event =
            createSseChunkEvent(content: null, finishReason: 'tool_calls');

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: [event]),
        );

        // Act
        final stream = repository.generateText(
          prompt: 'Hi',
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        final results = await stream.toList();

        // Assert
        expect(results[0].choices?.first.finishReason,
            equals(ChatCompletionFinishReason.toolCalls));
      });

      test('should fallback to stop for unknown finish reason', () async {
        // Arrange
        final event = {
          'id': 'chatcmpl-test',
          'object': 'chat.completion.chunk',
          'created': 1234567890,
          'model': model,
          'choices': [
            {
              'index': 0,
              'delta': {'content': 'test'},
              'finish_reason': 'unknown_reason',
            }
          ],
        };

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: [event]),
        );

        // Act
        final stream = repository.generateText(
          prompt: 'Hi',
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        final results = await stream.toList();

        // Assert - should fallback to stop
        expect(results[0].choices?.first.finishReason,
            equals(ChatCompletionFinishReason.stop));
      });
    });

    group('edge cases', () {
      const model = 'magistral-medium-2509';
      const baseUrl = 'https://api.mistral.ai/v1';
      const apiKey = 'test-api-key';

      test('should handle null choices', () async {
        // Arrange
        final event = {
          'id': 'chatcmpl-test',
          'object': 'chat.completion.chunk',
          'created': 1234567890,
          'model': model,
          'choices': null,
        };

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: [event]),
        );

        // Act
        final stream = repository.generateText(
          prompt: 'Hi',
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        final results = await stream.toList();

        // Assert - should skip event with null choices
        expect(results, isEmpty);
      });

      test('should handle empty choices array', () async {
        // Arrange
        final event = {
          'id': 'chatcmpl-test',
          'object': 'chat.completion.chunk',
          'created': 1234567890,
          'model': model,
          'choices': <dynamic>[],
        };

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: [event]),
        );

        // Act
        final stream = repository.generateText(
          prompt: 'Hi',
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        final results = await stream.toList();

        // Assert - should skip event with empty choices
        expect(results, isEmpty);
      });

      test('should handle null delta', () async {
        // Arrange
        final event = {
          'id': 'chatcmpl-test',
          'object': 'chat.completion.chunk',
          'created': 1234567890,
          'model': model,
          'choices': [
            {
              'index': 0,
              'delta': null,
              'finish_reason': null,
            }
          ],
        };

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: [event]),
        );

        // Act
        final stream = repository.generateText(
          prompt: 'Hi',
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        final results = await stream.toList();

        // Assert - should skip choice with null delta
        expect(results, isEmpty);
      });

      test('should generate fallback id when missing', () async {
        // Arrange
        final event = {
          'object': 'chat.completion.chunk',
          'created': 1234567890,
          'model': model,
          'choices': [
            {
              'index': 0,
              'delta': {'content': 'test'},
              'finish_reason': null,
            }
          ],
        };

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: [event]),
        );

        // Act
        final stream = repository.generateText(
          prompt: 'Hi',
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        final results = await stream.toList();

        // Assert - should generate fallback id
        expect(results[0].id, startsWith('mistral-'));
      });

      test('should generate fallback created when missing', () async {
        // Arrange
        final event = {
          'id': 'chatcmpl-test',
          'object': 'chat.completion.chunk',
          'model': model,
          'choices': [
            {
              'index': 0,
              'delta': {'content': 'test'},
              'finish_reason': null,
            }
          ],
        };

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: [event]),
        );

        // Act
        final stream = repository.generateText(
          prompt: 'Hi',
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        final results = await stream.toList();

        // Assert - should have a valid created timestamp
        expect(results[0].created, isPositive);
      });
    });

    group('MistralInferenceException', () {
      test('should format toString correctly', () {
        final exception = MistralInferenceException(
          'Test error',
          statusCode: 404,
          originalError: Exception('Original'),
        );

        expect(exception.toString(),
            equals('MistralInferenceException: Test error'));
        expect(exception.message, equals('Test error'));
        expect(exception.statusCode, equals(404));
        expect(exception.originalError, isA<Exception>());
      });

      test('should work without optional parameters', () {
        final exception = MistralInferenceException('Simple error');

        expect(exception.message, equals('Simple error'));
        expect(exception.statusCode, isNull);
        expect(exception.originalError, isNull);
      });
    });

    group('exception logging with LoggingService', () {
      const model = 'magistral-medium-2509';
      const baseUrl = 'https://api.mistral.ai/v1';
      const apiKey = 'test-api-key';
      late MockLoggingService mockLoggingService;

      setUp(() {
        mockLoggingService = MockLoggingService();
        if (GetIt.instance.isRegistered<LoggingService>()) {
          GetIt.instance.unregister<LoggingService>();
        }
        GetIt.instance.registerSingleton<LoggingService>(mockLoggingService);
      });

      tearDown(() {
        if (GetIt.instance.isRegistered<LoggingService>()) {
          GetIt.instance.unregister<LoggingService>();
        }
      });

      test('should log exception on unexpected error', () async {
        // Arrange
        when(
          () => mockLoggingService.captureException(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String?>(named: 'subDomain'),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          ),
        ).thenReturn(null);

        when(() => mockHttpClient.send(any()))
            .thenThrow(StateError('Unexpected error'));

        // Act & Assert
        final responseStream = repository.generateText(
          prompt: 'Hi',
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        expect(
          responseStream.toList(),
          throwsA(isA<MistralInferenceException>()
              .having((e) => e.message, 'message', contains('Unexpected'))),
        );

        // Wait for exception to be logged
        await Future<void>.delayed(Duration.zero);

        verify(
          () => mockLoggingService.captureException(
            any<Object>(that: isA<StateError>()),
            domain: 'MISTRAL',
            subDomain: 'unexpected',
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          ),
        ).called(1);
      });
    });
  });
}
