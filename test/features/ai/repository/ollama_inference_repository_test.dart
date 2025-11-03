import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ollama_inference_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

class MockHttpClient extends Mock implements http.Client {}

class MockStreamedResponse extends Mock implements http.StreamedResponse {}

class FakeRequest extends Fake implements http.Request {}

void main() {
  late OllamaInferenceRepository repository;
  late MockHttpClient mockHttpClient;

  setUpAll(() {
    registerFallbackValue(FakeRequest());
    registerFallbackValue(Uri.parse('http://localhost:11434'));
    // Use zero retry delay across this file to avoid real-time backoffs
    OllamaInferenceRepository.retryBaseDelay = Duration.zero;
  });

  tearDownAll(() {
    // Restore default for other suites
    OllamaInferenceRepository.retryBaseDelay = const Duration(seconds: 2);
  });

  setUp(() {
    mockHttpClient = MockHttpClient();
    repository = OllamaInferenceRepository(httpClient: mockHttpClient);
  });

  group('OllamaInferenceRepository', () {
    group('generateText', () {
      final provider = AiConfigInferenceProvider(
        id: 'ollama-provider',
        name: 'Ollama',
        baseUrl: 'http://localhost:11434',
        apiKey: '',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.ollama,
      );

      test('should use /api/chat endpoint even when no tools provided',
          () async {
        // Arrange
        const prompt = 'Test prompt';
        const model = 'llama2';
        const temperature = 0.7;
        const systemMessage = 'System message';

        final mockResponse = MockStreamedResponse();
        when(() => mockResponse.statusCode).thenReturn(200);
        when(() => mockResponse.stream).thenAnswer((_) => http.ByteStream(
              Stream.value(
                utf8.encode(
                    '{"message":{"content":"Test response"},"done":true}\n'),
              ),
            ));

        when(() => mockHttpClient.send(any()))
            .thenAnswer((_) async => mockResponse);

        // Act
        final stream = repository.generateText(
          prompt: prompt,
          model: model,
          temperature: temperature,
          systemMessage: systemMessage,
          provider: provider,
        );

        final result = await stream.first;

        // Assert
        expect(result.choices?.first.delta?.content, equals('Test response'));

        // Verify the correct endpoint was called
        final captured =
            verify(() => mockHttpClient.send(captureAny())).captured;
        final request = captured[0] as http.Request;
        expect(request.url.toString(), contains('/api/chat'));
      });

      test('should use /api/chat endpoint when tools are provided', () async {
        // Arrange
        const prompt = 'Test prompt';
        const model = 'qwen3:8b';
        const temperature = 0.7;

        final tools = [
          const ChatCompletionTool(
            type: ChatCompletionToolType.function,
            function: FunctionObject(
              name: 'test_function',
              description: 'Test function',
            ),
          ),
        ];

        final mockResponse = MockStreamedResponse();
        when(() => mockResponse.statusCode).thenReturn(200);
        when(() => mockResponse.stream).thenAnswer((_) => http.ByteStream(
              Stream.value(
                utf8.encode(
                    '{"message":{"content":"Test response"},"done":true}\n'),
              ),
            ));

        when(() => mockHttpClient.send(any()))
            .thenAnswer((_) async => mockResponse);

        // Act
        final stream = repository.generateText(
          prompt: prompt,
          model: model,
          temperature: temperature,
          systemMessage: null,
          provider: provider,
          tools: tools,
        );

        final results = await stream.toList();

        // Assert
        expect(results, isNotEmpty);
        expect(results.first.choices?.first.delta?.content,
            equals('Test response'));

        // Verify the correct endpoint was called
        final captured =
            verify(() => mockHttpClient.send(captureAny())).captured;
        final request = captured[0] as http.Request;
        expect(request.url.toString(), contains('/api/chat'));
      });

      test('should handle tool calls in chat response', () async {
        // Arrange
        const prompt = 'Test prompt';
        const model = 'qwen3:8b';
        const temperature = 0.7;

        final tools = [
          const ChatCompletionTool(
            type: ChatCompletionToolType.function,
            function: FunctionObject(
              name: 'get_weather',
              description: 'Get weather information',
            ),
          ),
        ];

        final mockResponse = MockStreamedResponse();
        when(() => mockResponse.statusCode).thenReturn(200);
        when(() => mockResponse.stream).thenAnswer((_) => http.ByteStream(
              Stream.value(
                utf8.encode('${jsonEncode({
                      'message': {
                        'tool_calls': [
                          {
                            'id': 'call_123',
                            'function': {
                              'name': 'get_weather',
                              'arguments': {'city': 'Tokyo'},
                            },
                          },
                        ],
                      },
                      'done': false,
                    })}\n${jsonEncode({'done': true})}\n'),
              ),
            ));

        when(() => mockHttpClient.send(any()))
            .thenAnswer((_) async => mockResponse);

        // Act
        final stream = repository.generateText(
          prompt: prompt,
          model: model,
          temperature: temperature,
          systemMessage: null,
          provider: provider,
          tools: tools,
        );

        final results = await stream.toList();

        // Assert
        expect(results, isNotEmpty);
        final toolCallsResponse = results.first;
        expect(toolCallsResponse.choices?.first.delta?.toolCalls, isNotNull);
      });

      test('should retry on timeout', () async {
        // Arrange
        const prompt = 'Test prompt';
        const model = 'llama2';
        const temperature = 0.7;

        var attempts = 0;
        when(() => mockHttpClient.send(any())).thenAnswer((_) async {
          attempts++;
          if (attempts < 3) {
            throw TimeoutException('Request timeout');
          }
          final mockResponse = MockStreamedResponse();
          when(() => mockResponse.statusCode).thenReturn(200);
          when(() => mockResponse.stream).thenAnswer((_) => http.ByteStream(
                Stream.value(
                  utf8.encode(
                      '{"message":{"content":"Success after retry"},"done":true}\n'),
                ),
              ));
          return mockResponse;
        });

        // Act
        final stream = repository.generateText(
          prompt: prompt,
          model: model,
          temperature: temperature,
          systemMessage: null,
          provider: provider,
        );

        final result = await stream.first;

        // Assert
        expect(result.choices?.first.delta?.content,
            equals('Success after retry'));
        expect(attempts, equals(3));
      });

      test(
          'should throw ModelNotInstalledException for 404 with model not found',
          () async {
        // Arrange
        const prompt = 'Test prompt';
        const model = 'nonexistent-model';
        const temperature = 0.7;

        final mockResponse = MockStreamedResponse();
        when(() => mockResponse.statusCode).thenReturn(404);
        when(() => mockResponse.stream).thenAnswer((_) => http.ByteStream(
              Stream.value(
                utf8.encode('model "nonexistent-model" not found\n'),
              ),
            ));

        when(() => mockHttpClient.send(any()))
            .thenAnswer((_) async => mockResponse);

        // Act & Assert
        expect(
          () => repository
              .generateText(
                prompt: prompt,
                model: model,
                temperature: temperature,
                systemMessage: null,
                provider: provider,
              )
              .first,
          throwsA(isA<ModelNotInstalledException>()),
        );
      });

      test('should validate request parameters', () {
        // Test empty prompt
        expect(
          () => repository.generateText(
            prompt: '',
            model: 'llama2',
            temperature: 0.7,
            systemMessage: null,
            provider: provider,
          ),
          throwsException,
        );

        // Test empty model
        expect(
          () => repository.generateText(
            prompt: 'Test',
            model: '',
            temperature: 0.7,
            systemMessage: null,
            provider: provider,
          ),
          throwsException,
        );

        // Test invalid temperature
        expect(
          () => repository.generateText(
            prompt: 'Test',
            model: 'llama2',
            temperature: -1,
            systemMessage: null,
            provider: provider,
          ),
          throwsException,
        );
      });
    });

    group('generateWithImages', () {
      final provider = AiConfigInferenceProvider(
        id: 'ollama-provider',
        name: 'Ollama',
        baseUrl: 'http://localhost:11434',
        apiKey: '',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.ollama,
      );

      test('should generate response with images', () async {
        // Arrange
        const prompt = 'Describe this image';
        const model = 'llava';
        const temperature = 0.7;
        final images = ['base64encodedimage'];

        // Mock warmUpModel
        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => http.Response(
              '{"response": "Hello"}',
              200,
            ));

        // Mock generateWithImages stream response
        final mockResponse = MockStreamedResponse();
        when(() => mockResponse.statusCode).thenReturn(200);
        when(() => mockResponse.stream).thenAnswer((_) => http.ByteStream(
              Stream.value(
                utf8.encode(
                    '{"message":{"content":"This is an image description"},"done":true}\n'),
              ),
            ));

        when(() => mockHttpClient.send(any()))
            .thenAnswer((_) async => mockResponse);

        // Act
        final stream = repository.generateWithImages(
          prompt: prompt,
          model: model,
          temperature: temperature,
          images: images,
          provider: provider,
        );

        final result = await stream.first;

        // Assert
        expect(result.choices?.first.delta?.content,
            equals('This is an image description'));

        // Verify warmUpModel was called
        verify(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).called(1);

        // Verify streaming request was made for generateWithImages
        final captured =
            verify(() => mockHttpClient.send(captureAny())).captured;
        expect(captured.length, 1);

        final request = captured[0] as http.Request;
        expect(request.url.toString(), contains('/api/chat'));

        final requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        expect(requestBody['messages'], isA<List<dynamic>>());
        final messages = requestBody['messages'] as List<dynamic>;
        expect(messages.length, 1);
        expect((messages[0] as Map<String, dynamic>)['images'], equals(images));
      });

      test('should throw exception for empty images list', () {
        expect(
          () => repository.generateWithImages(
            prompt: 'Test',
            model: 'llava',
            temperature: 0.7,
            images: [],
            provider: provider,
          ),
          throwsException,
        );
      });
    });

    group('isModelInstalled', () {
      test('should return true when model is installed', () async {
        // Arrange
        const modelName = 'llama2';
        const baseUrl = 'http://localhost:11434';

        when(() => mockHttpClient.get(any()))
            .thenAnswer((_) async => http.Response(
                  jsonEncode({
                    'models': [
                      {'name': 'llama2', 'size': 1000000},
                      {'name': 'codellama', 'size': 2000000},
                    ],
                  }),
                  200,
                ));

        // Act
        final result = await repository.isModelInstalled(modelName, baseUrl);

        // Assert
        expect(result, isTrue);
      });

      test('should return false when model is not installed', () async {
        // Arrange
        const modelName = 'nonexistent';
        const baseUrl = 'http://localhost:11434';

        when(() => mockHttpClient.get(any()))
            .thenAnswer((_) async => http.Response(
                  jsonEncode({
                    'models': [
                      {'name': 'llama2', 'size': 1000000},
                    ],
                  }),
                  200,
                ));

        // Act
        final result = await repository.isModelInstalled(modelName, baseUrl);

        // Assert
        expect(result, isFalse);
      });

      test('should return false on error', () async {
        // Arrange
        const modelName = 'llama2';
        const baseUrl = 'http://localhost:11434';

        when(() => mockHttpClient.get(any()))
            .thenThrow(Exception('Network error'));

        // Act
        final result = await repository.isModelInstalled(modelName, baseUrl);

        // Assert
        expect(result, isFalse);
      });
    });

    group('getModelInfo', () {
      test('should return model info when found', () async {
        // Arrange
        const modelName = 'llama2';
        const baseUrl = 'http://localhost:11434';

        when(() => mockHttpClient.get(any()))
            .thenAnswer((_) async => http.Response(
                  jsonEncode({
                    'models': [
                      {
                        'name': 'llama2',
                        'size': 4000000000,
                        'details': {
                          'parameter_size': '7B',
                          'quantization_level': 'Q4_K_M',
                        },
                      },
                    ],
                  }),
                  200,
                ));

        // Act
        final result = await repository.getModelInfo(modelName, baseUrl);

        // Assert
        expect(result, isNotNull);
        expect(result!.name, equals('llama2'));
        expect(result.parameterSize, equals('7B'));
        expect(result.quantizationLevel, equals('Q4_K_M'));
        expect(result.humanReadableSize, equals('3.7 GB'));
      });

      test('should return null when model not found', () async {
        // Arrange
        const modelName = 'nonexistent';
        const baseUrl = 'http://localhost:11434';

        when(() => mockHttpClient.get(any()))
            .thenAnswer((_) async => http.Response(
                  jsonEncode({'models': <Map<String, dynamic>>[]}),
                  200,
                ));

        // Act
        final result = await repository.getModelInfo(modelName, baseUrl);

        // Assert
        expect(result, isNull);
      });
    });

    group('installModel', () {
      test('should stream installation progress', () async {
        // Arrange
        const modelName = 'llama2';
        const baseUrl = 'http://localhost:11434';

        final mockResponse = MockStreamedResponse();
        when(() => mockResponse.statusCode).thenReturn(200);
        when(() => mockResponse.stream)
            .thenAnswer((_) => http.ByteStream(Stream.fromIterable([
                  '{"status":"pulling manifest","total":0,"completed":0}\n',
                  '{"status":"downloading","total":1000,"completed":500}\n',
                  '{"status":"downloading","total":1000,"completed":1000}\n',
                  '{"status":"success","total":1000,"completed":1000}\n',
                ].map((s) => utf8.encode(s)))));

        when(() => mockHttpClient.send(any()))
            .thenAnswer((_) async => mockResponse);

        // Act
        final progressStream = repository.installModel(modelName, baseUrl);
        final progressList = await progressStream.toList();

        // Assert
        expect(progressList.length, equals(4));
        expect(progressList[0].status, equals('pulling manifest'));
        expect(progressList[1].progress, equals(0.5));
        expect(progressList[2].progress, equals(1.0));
        expect(progressList[3].status, equals('success'));
      });

      test('should handle installation errors', () async {
        // Arrange
        const modelName = 'nonexistent';
        const baseUrl = 'http://localhost:11434';

        final mockResponse = MockStreamedResponse();
        when(() => mockResponse.statusCode).thenReturn(200);
        when(() => mockResponse.stream).thenAnswer((_) => http.ByteStream(
              Stream.value(
                utf8.encode('{"error":"model not found"}\n'),
              ),
            ));

        when(() => mockHttpClient.send(any()))
            .thenAnswer((_) async => mockResponse);

        // Act & Assert
        expect(
          repository.installModel(modelName, baseUrl).toList(),
          throwsException,
        );
      });
    });

    group('warmUpModel', () {
      test('should send warm-up request successfully', () async {
        // Arrange
        const modelName = 'llama2';
        const baseUrl = 'http://localhost:11434';

        when(() => mockHttpClient.post(
                  any(),
                  headers: any(named: 'headers'),
                  body: any(named: 'body'),
                ))
            .thenAnswer(
                (_) async => http.Response('{"response":"Hello"}', 200));

        // Act
        await repository.warmUpModel(modelName, baseUrl);

        // Assert
        verify(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).called(1);
      });

      test('should not throw on warm-up failure', () async {
        // Arrange
        const modelName = 'llama2';
        const baseUrl = 'http://localhost:11434';

        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenThrow(Exception('Network error'));

        // Act & Assert (should not throw)
        await repository.warmUpModel(modelName, baseUrl);
      });
    });

    group('OllamaModelInfo', () {
      test('should format human-readable sizes correctly', () {
        expect(
          const OllamaModelInfo(
            name: 'test',
            size: 500,
            parameterSize: '1B',
            quantizationLevel: 'Q4',
          ).humanReadableSize,
          equals('500 B'),
        );

        expect(
          const OllamaModelInfo(
            name: 'test',
            size: 2048,
            parameterSize: '1B',
            quantizationLevel: 'Q4',
          ).humanReadableSize,
          equals('2.0 KB'),
        );

        expect(
          const OllamaModelInfo(
            name: 'test',
            size: 5242880,
            parameterSize: '1B',
            quantizationLevel: 'Q4',
          ).humanReadableSize,
          equals('5.0 MB'),
        );

        expect(
          const OllamaModelInfo(
            name: 'test',
            size: 4294967296,
            parameterSize: '1B',
            quantizationLevel: 'Q4',
          ).humanReadableSize,
          equals('4.0 GB'),
        );
      });
    });

    group('OllamaPullProgress', () {
      test('should format progress correctly', () {
        const progress = OllamaPullProgress(
          status: 'downloading',
          total: 1048576,
          completed: 524288,
          progress: 0.5,
        );

        expect(progress.progressPercentage, equals('50.0%'));
        expect(progress.downloadProgress,
            equals('downloading: 0.5 MB / 1.0 MB (50.0%)'));
      });

      test('should handle zero total', () {
        const progress = OllamaPullProgress(
          status: 'preparing',
          total: 0,
          completed: 0,
          progress: 0,
        );

        expect(progress.downloadProgress, equals('preparing'));
      });
    });
  });

  group('Content Extraction from ChatCompletionUserMessageContent', () {
    late OllamaInferenceRepository repository;
    late MockHttpClient mockHttpClient;

    setUp(() {
      mockHttpClient = MockHttpClient();
      repository = OllamaInferenceRepository(httpClient: mockHttpClient);
    });

    test('should extract text from list of content parts', () async {
      final messages = [
        const ChatCompletionMessage.user(
          content: ChatCompletionUserMessageContent.parts([
            ChatCompletionMessageContentPart.text(text: 'Hello'),
            ChatCompletionMessageContentPart.text(text: ' world'),
          ]),
        ),
      ];

      final mockResponse = MockStreamedResponse();
      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.stream).thenAnswer((_) => http.ByteStream(
          Stream.value(utf8.encode('{"response": "test", "done": true}'))));

      when(() => mockHttpClient.send(any()))
          .thenAnswer((_) async => mockResponse);

      final provider = AiConfigInferenceProvider(
        id: 'test-provider',
        name: 'Test',
        baseUrl: 'http://localhost:11434',
        apiKey: '',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.ollama,
      );

      final stream = repository.generateTextWithMessages(
        messages: messages,
        model: 'test-model',
        temperature: 0.7,
        provider: provider,
      );

      await stream.toList();

      final captured = verify(() => mockHttpClient.send(captureAny())).captured;
      final request = captured.first as http.Request;
      final body = request.body;
      final jsonBody = jsonDecode(body) as Map<String, dynamic>;

      final jsonMessages = jsonBody['messages'] as List<dynamic>;
      final firstMessage = jsonMessages[0] as Map<String, dynamic>;
      expect(firstMessage['content'], 'Hello world');
    });

    test('should handle string content directly', () async {
      final messages = [
        const ChatCompletionMessage.user(
          content:
              ChatCompletionUserMessageContent.string('Direct string content'),
        ),
      ];

      final mockResponse = MockStreamedResponse();
      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.stream).thenAnswer((_) => http.ByteStream(
          Stream.value(utf8.encode('{"response": "test", "done": true}'))));

      when(() => mockHttpClient.send(any()))
          .thenAnswer((_) async => mockResponse);

      final provider = AiConfigInferenceProvider(
        id: 'test-provider',
        name: 'Test',
        baseUrl: 'http://localhost:11434',
        apiKey: '',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.ollama,
      );

      final stream = repository.generateTextWithMessages(
        messages: messages,
        model: 'test-model',
        temperature: 0.7,
        provider: provider,
      );

      await stream.toList();

      final captured = verify(() => mockHttpClient.send(captureAny())).captured;
      final request = captured.first as http.Request;
      final body = request.body;
      final jsonBody = jsonDecode(body) as Map<String, dynamic>;

      final jsonMessages = jsonBody['messages'] as List<dynamic>;
      final firstMessage = jsonMessages[0] as Map<String, dynamic>;
      expect(firstMessage['content'], 'Direct string content');
    });

    test('should skip thinking content in chat completion', () async {
      final messages = [
        const ChatCompletionMessage.user(
          content: ChatCompletionUserMessageContent.string('Test'),
        ),
      ];

      final chunks = [
        '{"message": {"thinking": "Internal thoughts..."}}',
        '{"message": {"content": "Actual response"}}',
        '{"done": true}',
      ];

      final mockResponse = MockStreamedResponse();
      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.stream).thenAnswer((_) => http.ByteStream(
          Stream.fromIterable(chunks.map((c) => utf8.encode('$c\n')))));

      when(() => mockHttpClient.send(any()))
          .thenAnswer((_) async => mockResponse);

      final provider = AiConfigInferenceProvider(
        id: 'test-provider',
        name: 'Test',
        baseUrl: 'http://localhost:11434',
        apiKey: '',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.ollama,
      );

      final stream = repository.generateTextWithMessages(
        messages: messages,
        model: 'test-model',
        temperature: 0.7,
        provider: provider,
      );

      final events = await stream.toList();

      // Should have received content but not thinking
      expect(
          events.any((CreateChatCompletionStreamResponse e) =>
              e.choices?.first.delta?.content?.contains('Actual response') ??
              false),
          true);
      expect(
          events.any((CreateChatCompletionStreamResponse e) =>
              e.choices?.first.delta?.content?.contains('Internal thoughts') ??
              false),
          false);
    });

    test('should handle tool messages correctly', () async {
      final messages = [
        const ChatCompletionMessage.tool(
          toolCallId: 'tool-123',
          content: 'Tool execution result',
        ),
      ];

      final mockResponse = MockStreamedResponse();
      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.stream).thenAnswer((_) => http.ByteStream(
          Stream.value(utf8.encode('{"response": "test", "done": true}'))));

      when(() => mockHttpClient.send(any()))
          .thenAnswer((_) async => mockResponse);

      final provider = AiConfigInferenceProvider(
        id: 'test-provider',
        name: 'Test',
        baseUrl: 'http://localhost:11434',
        apiKey: '',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.ollama,
      );

      final stream = repository.generateTextWithMessages(
        messages: messages,
        model: 'test-model',
        temperature: 0.7,
        provider: provider,
      );

      await stream.toList();

      final captured = verify(() => mockHttpClient.send(captureAny())).captured;
      final request = captured.first as http.Request;
      final body = request.body;
      final jsonBody = jsonDecode(body) as Map<String, dynamic>;

      final jsonMessages = jsonBody['messages'] as List<dynamic>;
      final firstMessage = jsonMessages[0] as Map<String, dynamic>;
      expect(firstMessage['role'], 'tool');
      expect(firstMessage['content'], 'Tool execution result');
    });

    test('should handle messages with null content', () async {
      final messages = [
        const ChatCompletionMessage.assistant(
          toolCalls: [
            ChatCompletionMessageToolCall(
              id: 'tool-1',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: 'test_function',
                arguments: '{}',
              ),
            ),
          ],
        ),
      ];

      final mockResponse = MockStreamedResponse();
      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.stream).thenAnswer((_) => http.ByteStream(
          Stream.value(utf8.encode('{"response": "test", "done": true}'))));

      when(() => mockHttpClient.send(any()))
          .thenAnswer((_) async => mockResponse);

      final provider = AiConfigInferenceProvider(
        id: 'test-provider',
        name: 'Test',
        baseUrl: 'http://localhost:11434',
        apiKey: '',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.ollama,
      );

      final stream = repository.generateTextWithMessages(
        messages: messages,
        model: 'test-model',
        temperature: 0.7,
        provider: provider,
      );

      await stream.toList();

      final captured = verify(() => mockHttpClient.send(captureAny())).captured;
      final request = captured.first as http.Request;
      final body = request.body;
      final jsonBody = jsonDecode(body) as Map<String, dynamic>;

      final jsonMessages = jsonBody['messages'] as List<dynamic>;
      final firstMessage = jsonMessages[0] as Map<String, dynamic>;
      expect(firstMessage['content'], '');
    });

    test('should handle content that cannot be JSON encoded', () async {
      // Create a message with standard content
      final messages = [
        const ChatCompletionMessage.user(
          content: ChatCompletionUserMessageContent.string('test content'),
        ),
      ];

      final mockResponse = MockStreamedResponse();
      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.stream).thenAnswer((_) => http.ByteStream(
          Stream.value(utf8.encode('{"response": "test", "done": true}'))));

      when(() => mockHttpClient.send(any()))
          .thenAnswer((_) async => mockResponse);

      final provider = AiConfigInferenceProvider(
        id: 'test-provider',
        name: 'Test',
        baseUrl: 'http://localhost:11434',
        apiKey: '',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.ollama,
      );

      final stream = repository.generateTextWithMessages(
        messages: messages,
        model: 'test-model',
        temperature: 0.7,
        provider: provider,
      );

      await stream.toList();

      final captured = verify(() => mockHttpClient.send(captureAny())).captured;
      final request = captured.first as http.Request;
      final body = request.body;
      final jsonBody = jsonDecode(body) as Map<String, dynamic>;

      final jsonMessages = jsonBody['messages'] as List<dynamic>;
      final firstMessage = jsonMessages[0] as Map<String, dynamic>;
      // Should have the standard content
      expect(firstMessage['content'], 'test content');
    });

    test('should include maxCompletionTokens in options', () async {
      final messages = [
        const ChatCompletionMessage.user(
          content: ChatCompletionUserMessageContent.string('Test'),
        ),
      ];

      final mockResponse = MockStreamedResponse();
      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.stream).thenAnswer((_) => http.ByteStream(
          Stream.value(utf8.encode('{"response": "test", "done": true}'))));

      when(() => mockHttpClient.send(any()))
          .thenAnswer((_) async => mockResponse);

      final provider = AiConfigInferenceProvider(
        id: 'test-provider',
        name: 'Test',
        baseUrl: 'http://localhost:11434',
        apiKey: '',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.ollama,
      );

      final stream = repository.generateTextWithMessages(
        messages: messages,
        model: 'test-model',
        temperature: 0.7,
        provider: provider,
        maxCompletionTokens: 500,
      );

      await stream.toList();

      final captured = verify(() => mockHttpClient.send(captureAny())).captured;
      final request = captured.first as http.Request;
      final body = request.body;
      final jsonBody = jsonDecode(body) as Map<String, dynamic>;

      final options = jsonBody['options'] as Map<String, dynamic>;
      expect(options['num_predict'], 500);
    });

    test('should handle empty text parts in content', () async {
      final messages = [
        const ChatCompletionMessage.user(
          content: ChatCompletionUserMessageContent.parts([
            ChatCompletionMessageContentPart.text(text: ''),
            ChatCompletionMessageContentPart.text(
                text: '  '), // Only whitespace
            ChatCompletionMessageContentPart.text(text: 'Valid text'),
          ]),
        ),
      ];

      final mockResponse = MockStreamedResponse();
      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.stream).thenAnswer((_) => http.ByteStream(
          Stream.value(utf8.encode('{"response": "test", "done": true}'))));

      when(() => mockHttpClient.send(any()))
          .thenAnswer((_) async => mockResponse);

      final provider = AiConfigInferenceProvider(
        id: 'test-provider',
        name: 'Test',
        baseUrl: 'http://localhost:11434',
        apiKey: '',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.ollama,
      );

      final stream = repository.generateTextWithMessages(
        messages: messages,
        model: 'test-model',
        temperature: 0.7,
        provider: provider,
      );

      await stream.toList();

      final captured = verify(() => mockHttpClient.send(captureAny())).captured;
      final request = captured.first as http.Request;
      final body = request.body;
      final jsonBody = jsonDecode(body) as Map<String, dynamic>;

      final jsonMessages = jsonBody['messages'] as List<dynamic>;
      final firstMessage = jsonMessages[0] as Map<String, dynamic>;
      // Should only contain the valid text
      expect(firstMessage['content'], 'Valid text');
    });
  });

  group('Additional Error handling and retries', () {
    late OllamaInferenceRepository repository;
    late MockHttpClient mockHttpClient;

    setUp(() {
      mockHttpClient = MockHttpClient();
      repository = OllamaInferenceRepository(httpClient: mockHttpClient);
    });

    test('should handle malformed JSON in stream', () async {
      final messages = [
        const ChatCompletionMessage.user(
          content: ChatCompletionUserMessageContent.string('Test'),
        ),
      ];

      final mockResponse = MockStreamedResponse();
      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.stream).thenAnswer((_) => http.ByteStream(
          Stream.value(utf8.encode('invalid json\n{"done": true}'))));

      when(() => mockHttpClient.send(any()))
          .thenAnswer((_) async => mockResponse);

      final provider = AiConfigInferenceProvider(
        id: 'test-provider',
        name: 'Test',
        baseUrl: 'http://localhost:11434',
        apiKey: '',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.ollama,
      );

      final stream = repository.generateTextWithMessages(
        messages: messages,
        model: 'test-model',
        temperature: 0.7,
        provider: provider,
      );

      // Should handle the error gracefully and continue
      final responses = await stream.toList();
      expect(responses, isEmpty);
    });

    test('should retry on SocketException', () async {
      var attemptCount = 0;
      final mockResponse = MockStreamedResponse();
      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.stream).thenAnswer((_) => http.ByteStream(
          Stream.value(utf8.encode('{"response": "test", "done": true}'))));

      when(() => mockHttpClient.send(any())).thenAnswer((_) async {
        attemptCount++;
        if (attemptCount < 2) {
          throw const SocketException('Connection failed');
        }
        return mockResponse;
      });

      final provider = AiConfigInferenceProvider(
        id: 'test-provider',
        name: 'Test',
        baseUrl: 'http://localhost:11434',
        apiKey: '',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.ollama,
      );

      final stream = repository.generateText(
        prompt: 'Test prompt',
        model: 'test-model',
        temperature: 0.7,
        systemMessage: null,
        provider: provider,
      );

      await stream.toList();

      // Should have retried
      expect(attemptCount, 2);
    });

    test('should throw after max retries on SocketException', () async {
      when(() => mockHttpClient.send(any())).thenThrow(
        const SocketException('Connection failed'),
      );

      final provider = AiConfigInferenceProvider(
        id: 'test-provider',
        name: 'Test',
        baseUrl: 'http://localhost:11434',
        apiKey: '',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.ollama,
      );

      final stream = repository.generateText(
        prompt: 'Test prompt',
        model: 'test-model',
        temperature: 0.7,
        systemMessage: null,
        provider: provider,
      );

      expect(
        stream.toList(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Network error'),
          ),
        ),
      );
    });

    test('should rethrow non-retryable exceptions immediately', () async {
      when(() => mockHttpClient.send(any())).thenThrow(
        Exception('Some other error'),
      );

      final provider = AiConfigInferenceProvider(
        id: 'test-provider',
        name: 'Test',
        baseUrl: 'http://localhost:11434',
        apiKey: '',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.ollama,
      );

      final stream = repository.generateText(
        prompt: 'Test prompt',
        model: 'test-model',
        temperature: 0.7,
        systemMessage: null,
        provider: provider,
      );

      await expectLater(
        stream.toList(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Some other error'),
          ),
        ),
      );

      // Should not retry
      verify(() => mockHttpClient.send(any())).called(1);
    });

    test('should detect model not found in error message', () async {
      final mockResponse = MockStreamedResponse();
      // Model not found should return 404
      when(() => mockResponse.statusCode).thenReturn(404);
      when(() =>
          mockResponse
              .stream).thenAnswer((_) => http.ByteStream(Stream.value(utf8.encode(
          '{"error": "model \'missing-model\' not found, try pulling it first"}'))));

      when(() => mockHttpClient.send(any()))
          .thenAnswer((_) async => mockResponse);

      final provider = AiConfigInferenceProvider(
        id: 'test-provider',
        name: 'Test',
        baseUrl: 'http://localhost:11434',
        apiKey: '',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.ollama,
      );

      final stream = repository.generateText(
        prompt: 'Test prompt',
        model: 'missing-model',
        temperature: 0.7,
        systemMessage: null,
        provider: provider,
      );

      await expectLater(
        stream.toList(),
        throwsA(isA<ModelNotInstalledException>()),
      );
    });
  });

  group('Additional Tool call handling', () {
    late OllamaInferenceRepository repository;
    late MockHttpClient mockHttpClient;

    setUp(() {
      mockHttpClient = MockHttpClient();
      repository = OllamaInferenceRepository(httpClient: mockHttpClient);
    });

    test('should handle tool calls with existing ID in stream', () async {
      final messages = [
        const ChatCompletionMessage.user(
          content: ChatCompletionUserMessageContent.string('Test'),
        ),
      ];

      final mockResponse = MockStreamedResponse();
      when(() => mockResponse.statusCode).thenReturn(200);

      // Stream that sends tool call in multiple chunks
      final streamController = StreamController<List<int>>();
      when(() => mockResponse.stream)
          .thenAnswer((_) => http.ByteStream(streamController.stream));

      when(() => mockHttpClient.send(any()))
          .thenAnswer((_) async => mockResponse);

      final provider = AiConfigInferenceProvider(
        id: 'test-provider',
        name: 'Test',
        baseUrl: 'http://localhost:11434',
        apiKey: '',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.ollama,
      );

      final stream = repository.generateTextWithMessages(
        messages: messages,
        model: 'test-model',
        temperature: 0.7,
        provider: provider,
        tools: [
          const ChatCompletionTool(
            type: ChatCompletionToolType.function,
            function: FunctionObject(
              name: 'test_function',
              description: 'Test function',
            ),
          ),
        ],
      );

      final futureList = stream.toList();

      // Send tool call response
      streamController
        ..add(utf8.encode('${jsonEncode({
              'message': {
                'tool_calls': [
                  {
                    'id': 'tool-1',
                    'function': {
                      'name': 'test_function',
                      'arguments': '{"partial": true}',
                    },
                  },
                ],
              },
              'done': false,
            })}\n'))

        // Send completion
        ..add(utf8.encode('${jsonEncode({
              'done': true,
            })}\n'));

      await streamController.close();

      final responses = await futureList;
      expect(responses.length, 1);
      expect(responses.first.choices?.first.delta?.toolCalls, isNotNull);
      expect(responses.first.choices?.first.delta?.toolCalls?.length, 1);
    });

    test('should handle tool calls with pre-encoded arguments', () async {
      final messages = [
        const ChatCompletionMessage.user(
          content: ChatCompletionUserMessageContent.string('Test'),
        ),
      ];

      final mockResponse = MockStreamedResponse();
      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.stream).thenAnswer(
          (_) => http.ByteStream(Stream.value(utf8.encode(jsonEncode({
                'message': {
                  'tool_calls': [
                    {
                      'id': 'tool-1',
                      'function': {
                        'name': 'test_function',
                        'arguments':
                            '{"already": "encoded"}', // Already a string
                      },
                    },
                  ],
                },
                'done': true,
              })))));

      when(() => mockHttpClient.send(any()))
          .thenAnswer((_) async => mockResponse);

      final provider = AiConfigInferenceProvider(
        id: 'test-provider',
        name: 'Test',
        baseUrl: 'http://localhost:11434',
        apiKey: '',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.ollama,
      );

      final stream = repository.generateTextWithMessages(
        messages: messages,
        model: 'test-model',
        temperature: 0.7,
        provider: provider,
        tools: [
          const ChatCompletionTool(
            type: ChatCompletionToolType.function,
            function: FunctionObject(
              name: 'test_function',
              description: 'Test function',
            ),
          ),
        ],
      );

      final responses = await stream.toList();
      expect(responses.length, 1);
      final toolCall = responses.first.choices?.first.delta?.toolCalls?.first;
      expect(toolCall?.function?.arguments, '{"already": "encoded"}');
    });

    test('should generate tool call ID if missing', () async {
      final messages = [
        const ChatCompletionMessage.user(
          content: ChatCompletionUserMessageContent.string('Test'),
        ),
      ];

      final mockResponse = MockStreamedResponse();
      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.stream).thenAnswer(
          (_) => http.ByteStream(Stream.value(utf8.encode(jsonEncode({
                'message': {
                  'tool_calls': [
                    {
                      // No ID provided
                      'function': {
                        'name': 'test_function',
                        'arguments': {'test': 'args'},
                      },
                    },
                  ],
                },
                'done': true,
              })))));

      when(() => mockHttpClient.send(any()))
          .thenAnswer((_) async => mockResponse);

      final provider = AiConfigInferenceProvider(
        id: 'test-provider',
        name: 'Test',
        baseUrl: 'http://localhost:11434',
        apiKey: '',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.ollama,
      );

      final stream = repository.generateTextWithMessages(
        messages: messages,
        model: 'test-model',
        temperature: 0.7,
        provider: provider,
        tools: [
          const ChatCompletionTool(
            type: ChatCompletionToolType.function,
            function: FunctionObject(
              name: 'test_function',
              description: 'Test function',
            ),
          ),
        ],
      );

      final responses = await stream.toList();
      expect(responses.length, 1);
      final toolCall = responses.first.choices?.first.delta?.toolCalls?.first;
      expect(toolCall?.id, startsWith('tool-'));
    });
  });
}

// Test helper classes
