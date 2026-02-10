import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/providers/gemini_inference_repository_provider.dart';
import 'package:lotti/features/ai/providers/gemini_thinking_providers.dart';
import 'package:lotti/features/ai/providers/ollama_inference_repository_provider.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/gemini_inference_repository.dart'
    show GeminiInferenceRepository, GeneratedImage;
import 'package:lotti/features/ai/repository/gemini_thinking_config.dart';
import 'package:lotti/features/ai/repository/ollama_inference_repository.dart';
import 'package:lotti/features/ai/repository/transcription_exception.dart';
import 'package:lotti/features/ai/util/image_processing_utils.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../test_utils.dart';

class MockOpenAIClient extends Mock implements OpenAIClient {}

class MockHttpClient extends Mock implements http.Client {}

class MockOllamaInferenceRepository extends Mock
    implements OllamaInferenceRepository {}

class MockGeminiInferenceRepository extends Mock
    implements GeminiInferenceRepository {}

// We need to register fallback values for complex types that will be used with 'any()' matcher
class FakeCreateChatCompletionRequest extends Fake
    implements CreateChatCompletionRequest {}

class FakeRequest extends Fake implements http.Request {}

class FakeBaseRequest extends Fake implements http.BaseRequest {}

class FakeGeminiThinkingConfig extends Fake implements GeminiThinkingConfig {}

class FakeAiConfigInferenceProvider extends Fake
    implements AiConfigInferenceProvider {}

void main() {
  setUpAll(() {
    // Register fallback values for mocktail
    registerFallbackValue(FakeCreateChatCompletionRequest());
    registerFallbackValue(Uri.parse('http://example.com'));
    registerFallbackValue(FakeRequest());
    registerFallbackValue(FakeBaseRequest());
    registerFallbackValue(FakeGeminiThinkingConfig());
    registerFallbackValue(FakeAiConfigInferenceProvider());
    registerFallbackValue(<ChatCompletionTool>[]);
  });

  group('CloudInferenceRepository', () {
    late MockOpenAIClient mockClient;
    late MockHttpClient mockHttpClient;
    late ProviderContainer container;
    late CloudInferenceRepository repository;
    late AiConfigInferenceProvider testProvider;

    const baseUrl = 'https://api.openai.com/v1';
    const apiKey = 'test-api-key';
    const model = 'gpt-4';
    const temperature = 0.7;
    const prompt = 'Hello, AI!';

    setUp(() {
      mockClient = MockOpenAIClient();
      mockHttpClient = MockHttpClient();
      final mockOllamaRepo = MockOllamaInferenceRepository();
      final mockGeminiRepo = MockGeminiInferenceRepository();

      container = ProviderContainer(
        overrides: [
          ollamaInferenceRepositoryProvider.overrideWithValue(mockOllamaRepo),
          geminiInferenceRepositoryProvider.overrideWithValue(mockGeminiRepo),
        ],
      );

      final ref = container.read(testRefProvider);
      repository = CloudInferenceRepository(ref, httpClient: mockHttpClient);
      testProvider = AiConfig.inferenceProvider(
        id: 'test-provider-id',
        name: 'Test Provider',
        baseUrl: baseUrl,
        apiKey: apiKey,
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.genericOpenAi,
      ) as AiConfigInferenceProvider;
    });

    tearDown(() async {
      mockHttpClient.close();
      container.dispose();
    });

    test(
        'generate calls OpenAIClient.createChatCompletionStream with correct parameters',
        () {
      // Arrange
      when(
        () => mockClient.createChatCompletionStream(
          request: any(named: 'request'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable([
          CreateChatCompletionStreamResponse(
            id: 'response-id',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(
                  content: 'Test response',
                ),
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        ]),
      );

      // Act
      repository.generate(
        prompt,
        model: model,
        temperature: temperature,
        baseUrl: baseUrl,
        apiKey: apiKey,
        overrideClient: mockClient,
      );

      // Capture call for verification
      final captured = verify(
        () => mockClient.createChatCompletionStream(
          request: captureAny(named: 'request'),
        ),
      ).captured;

      final request = captured.first as CreateChatCompletionRequest;
      expect(request.model.toString(), contains(model));
      expect(request.temperature, temperature);
      expect(request.messages.length, 1);
      expect(request.messages.first.role, ChatCompletionMessageRole.user);
      expect(request.stream, isTrue);

      // For simple string prompts, check that the content contains the prompt
      expect(request.toString(), contains(prompt));
    });

    test('generate returns stream from OpenAIClient.createChatCompletionStream',
        () async {
      // Arrange
      final expectedResponses = [
        CreateChatCompletionStreamResponse(
          id: 'response-id-1',
          choices: [
            const ChatCompletionStreamResponseChoice(
              delta: ChatCompletionStreamResponseDelta(
                content: 'Hello',
              ),
              index: 0,
            ),
          ],
          object: 'chat.completion.chunk',
          created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        ),
        CreateChatCompletionStreamResponse(
          id: 'response-id-2',
          choices: [
            const ChatCompletionStreamResponseChoice(
              delta: ChatCompletionStreamResponseDelta(
                content: ' World!',
              ),
              index: 0,
            ),
          ],
          object: 'chat.completion.chunk',
          created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        ),
      ];

      when(
        () => mockClient.createChatCompletionStream(
          request: any(named: 'request'),
        ),
      ).thenAnswer((_) => Stream.fromIterable(expectedResponses));

      // Act
      final stream = repository.generate(
        prompt,
        model: model,
        temperature: temperature,
        baseUrl: baseUrl,
        apiKey: apiKey,
        overrideClient: mockClient,
      );

      // Assert
      expect(stream, emitsInOrder(expectedResponses));
    });

    test('generateWithImages calls OpenAIClient with correct image parameters',
        () {
      // Arrange
      final images = ['image1-base64', 'image2-base64'];

      when(
        () => mockClient.createChatCompletionStream(
          request: any(named: 'request'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable([
          CreateChatCompletionStreamResponse(
            id: 'response-id',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(
                  content: 'Test image response',
                ),
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        ]),
      );

      // Act
      repository.generateWithImages(
        prompt,
        model: model,
        temperature: temperature,
        baseUrl: baseUrl,
        apiKey: apiKey,
        images: images,
        overrideClient: mockClient,
      );

      // Capture call for verification
      final captured = verify(
        () => mockClient.createChatCompletionStream(
          request: captureAny(named: 'request'),
        ),
      ).captured;

      final request = captured.first as CreateChatCompletionRequest;
      expect(request.model.toString(), contains(model));
      expect(request.temperature, temperature);
      expect(request.messages.length, 1);
      expect(request.messages.first.role, ChatCompletionMessageRole.user);
      expect(request.stream, isTrue);

      // Verify that request contains the images
      final requestString = request.toString();
      expect(requestString.contains(prompt), isTrue);
      for (final image in images) {
        expect(requestString.contains(image), isTrue);
      }
    });

    test('generateWithAudio calls OpenAIClient with correct audio parameters',
        () {
      // Arrange
      const audioBase64 = 'audio-base64-string';

      when(
        () => mockClient.createChatCompletionStream(
          request: any(named: 'request'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable([
          CreateChatCompletionStreamResponse(
            id: 'response-id',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(
                  content: 'Test audio response',
                ),
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        ]),
      );

      // Act
      repository.generateWithAudio(
        prompt,
        model: model,
        baseUrl: baseUrl,
        apiKey: apiKey,
        audioBase64: audioBase64,
        provider: testProvider,
        overrideClient: mockClient,
      );

      // Capture call  for verification
      final captured = verify(
        () => mockClient.createChatCompletionStream(
          request: captureAny(named: 'request'),
        ),
      ).captured;

      final request = captured.first as CreateChatCompletionRequest;
      expect(request.model.toString(), contains(model));
      expect(request.messages.length, 1);
      expect(request.messages.first.role, ChatCompletionMessageRole.user);
      expect(request.stream, isTrue);

      // Verify audio content parameters by checking the string representation
      final requestString = request.toString();
      expect(requestString.contains(prompt), isTrue);
      expect(requestString.contains(audioBase64), isTrue);
      // Default audioFormat is mp3
      expect(requestString.contains('mp3'), isTrue);
    });

    test('generate with maxCompletionTokens sets maxTokens parameter correctly',
        () {
      // Arrange
      const maxCompletionTokens = 2000;

      when(
        () => mockClient.createChatCompletionStream(
          request: any(named: 'request'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable([
          CreateChatCompletionStreamResponse(
            id: 'response-id',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(
                  content: 'Test response',
                ),
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        ]),
      );

      // Act
      repository.generate(
        prompt,
        model: model,
        temperature: temperature,
        baseUrl: baseUrl,
        apiKey: apiKey,
        maxCompletionTokens: maxCompletionTokens,
        overrideClient: mockClient,
      );

      // Capture call for verification
      final captured = verify(
        () => mockClient.createChatCompletionStream(
          request: captureAny(named: 'request'),
        ),
      ).captured;

      final request = captured.first as CreateChatCompletionRequest;
      expect(request.maxCompletionTokens, equals(maxCompletionTokens));
    });

    test(
        'generateWithImages with maxCompletionTokens sets maxTokens parameter correctly',
        () {
      // Arrange
      const maxCompletionTokens = 3000;
      const images = ['base64ImageData'];

      when(
        () => mockClient.createChatCompletionStream(
          request: any(named: 'request'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable([
          CreateChatCompletionStreamResponse(
            id: 'response-id',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(
                  content: 'Test response',
                ),
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        ]),
      );

      // Act
      repository.generateWithImages(
        prompt,
        model: model,
        temperature: temperature,
        images: images,
        baseUrl: baseUrl,
        apiKey: apiKey,
        maxCompletionTokens: maxCompletionTokens,
        overrideClient: mockClient,
      );

      // Capture call for verification
      final captured = verify(
        () => mockClient.createChatCompletionStream(
          request: captureAny(named: 'request'),
        ),
      ).captured;

      final request = captured.first as CreateChatCompletionRequest;
      // Note: generateWithImages uses maxTokens instead of maxCompletionTokens
      expect(request.maxTokens, equals(maxCompletionTokens));
    });

    test(
        'generateWithAudio with maxCompletionTokens sets maxCompletionTokens parameter correctly',
        () {
      // Arrange
      const maxCompletionTokens = 4000;
      const audioBase64 = 'base64AudioData';

      when(
        () => mockClient.createChatCompletionStream(
          request: any(named: 'request'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable([
          CreateChatCompletionStreamResponse(
            id: 'response-id',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(
                  content: 'Test response',
                ),
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        ]),
      );

      // Act
      repository.generateWithAudio(
        prompt,
        model: model,
        audioBase64: audioBase64,
        baseUrl: baseUrl,
        apiKey: apiKey,
        provider: testProvider,
        maxCompletionTokens: maxCompletionTokens,
        overrideClient: mockClient,
      );

      // Capture call for verification
      final captured = verify(
        () => mockClient.createChatCompletionStream(
          request: captureAny(named: 'request'),
        ),
      ).captured;

      final request = captured.first as CreateChatCompletionRequest;
      expect(request.maxCompletionTokens, equals(maxCompletionTokens));
    });

    test('cloudInferenceRepository provider creates instance correctly', () {
      final repository = container.read(cloudInferenceRepositoryProvider);
      expect(repository, isA<CloudInferenceRepository>());
    });

    test('generate with systemMessage includes system message in request', () {
      // Arrange
      const systemMessage = 'You are a helpful assistant.';

      when(
        () => mockClient.createChatCompletionStream(
          request: any(named: 'request'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable([
          CreateChatCompletionStreamResponse(
            id: 'response-id',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(
                  content: 'Test response',
                ),
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        ]),
      );

      // Act
      repository.generate(
        prompt,
        model: model,
        temperature: temperature,
        baseUrl: baseUrl,
        apiKey: apiKey,
        systemMessage: systemMessage,
        overrideClient: mockClient,
      );

      // Capture call for verification
      final captured = verify(
        () => mockClient.createChatCompletionStream(
          request: captureAny(named: 'request'),
        ),
      ).captured;

      final request = captured.first as CreateChatCompletionRequest;
      expect(request.messages.length, 2); // System message + user message
      expect(request.messages.first.role, ChatCompletionMessageRole.system);
      expect(request.messages.last.role, ChatCompletionMessageRole.user);
      expect(request.toString(), contains(systemMessage));
    });

    test('generate returns broadcast stream', () async {
      // Arrange
      when(
        () => mockClient.createChatCompletionStream(
          request: any(named: 'request'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable([
          CreateChatCompletionStreamResponse(
            id: 'response-id',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(
                  content: 'Test',
                ),
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        ]),
      );

      // Act
      final stream = repository.generate(
        prompt,
        model: model,
        temperature: temperature,
        baseUrl: baseUrl,
        apiKey: apiKey,
        overrideClient: mockClient,
      );

      // Assert - broadcast streams can be listened to multiple times
      expect(stream.isBroadcast, isTrue);
      // Just verify it's a broadcast stream, don't test multiple listens
      // as the mock stream is exhausted after first listen
    });

    test('generateWithImages returns broadcast stream', () async {
      // Arrange
      const images = ['image1'];

      when(
        () => mockClient.createChatCompletionStream(
          request: any(named: 'request'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable([
          CreateChatCompletionStreamResponse(
            id: 'response-id',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(
                  content: 'Test',
                ),
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        ]),
      );

      // Act
      final stream = repository.generateWithImages(
        prompt,
        model: model,
        temperature: temperature,
        baseUrl: baseUrl,
        apiKey: apiKey,
        images: images,
        overrideClient: mockClient,
      );

      // Assert
      expect(stream.isBroadcast, isTrue);
    });

    test('generateWithAudio returns broadcast stream', () async {
      // Arrange
      const audioBase64 = 'audio-data';

      when(
        () => mockClient.createChatCompletionStream(
          request: any(named: 'request'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable([
          CreateChatCompletionStreamResponse(
            id: 'response-id',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(
                  content: 'Test',
                ),
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        ]),
      );

      // Act
      final stream = repository.generateWithAudio(
        prompt,
        model: model,
        baseUrl: baseUrl,
        apiKey: apiKey,
        audioBase64: audioBase64,
        provider: testProvider,
        overrideClient: mockClient,
      );

      // Assert
      expect(stream.isBroadcast, isTrue);
    });

    test('_filterAnthropicPings filters out Anthropic ping errors', () async {
      // Arrange - Create a stream that will emit an Anthropic ping error
      final errorStream = Stream<CreateChatCompletionStreamResponse>.multi(
        (controller) {
          controller
            ..add(
              CreateChatCompletionStreamResponse(
                id: 'response-1',
                choices: [
                  const ChatCompletionStreamResponseChoice(
                    delta: ChatCompletionStreamResponseDelta(
                      content: 'Valid response',
                    ),
                    index: 0,
                  ),
                ],
                object: 'chat.completion.chunk',
                created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              ),
            )
            // Add an error that matches the Anthropic ping pattern
            ..addError(
              "type 'Null' is not a subtype of type 'List<dynamic>' in type cast (choices)",
            )
            ..add(
              CreateChatCompletionStreamResponse(
                id: 'response-2',
                choices: [
                  const ChatCompletionStreamResponseChoice(
                    delta: ChatCompletionStreamResponseDelta(
                      content: 'Another valid response',
                    ),
                    index: 0,
                  ),
                ],
                object: 'chat.completion.chunk',
                created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              ),
            )
            ..close();
        },
      );

      when(
        () => mockClient.createChatCompletionStream(
          request: any(named: 'request'),
        ),
      ).thenAnswer((_) => errorStream);

      // Act
      final stream = repository.generate(
        prompt,
        model: model,
        temperature: temperature,
        baseUrl: baseUrl,
        apiKey: apiKey,
        overrideClient: mockClient,
      );

      // Assert - Should only get the valid responses, not the error
      final responses = await stream.toList();
      expect(responses.length, 2);
      expect(responses[0].choices?[0].delta?.content, 'Valid response');
      expect(responses[1].choices?[0].delta?.content, 'Another valid response');
    });

    test('_filterAnthropicPings propagates non-Anthropic errors', () async {
      // Arrange - Create a stream with a different kind of error
      final errorStream = Stream<CreateChatCompletionStreamResponse>.multi(
        (controller) {
          controller
            ..add(
              CreateChatCompletionStreamResponse(
                id: 'response-1',
                choices: [
                  const ChatCompletionStreamResponseChoice(
                    delta: ChatCompletionStreamResponseDelta(
                      content: 'Valid response',
                    ),
                    index: 0,
                  ),
                ],
                object: 'chat.completion.chunk',
                created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              ),
            )
            // Add a different error
            ..addError('Network error: Connection refused')
            ..close();
        },
      );

      when(
        () => mockClient.createChatCompletionStream(
          request: any(named: 'request'),
        ),
      ).thenAnswer((_) => errorStream);

      // Act
      final stream = repository.generate(
        prompt,
        model: model,
        temperature: temperature,
        baseUrl: baseUrl,
        apiKey: apiKey,
        overrideClient: mockClient,
      );

      // Assert - Should propagate the error
      expect(
        stream.toList(),
        throwsA(equals('Network error: Connection refused')),
      );
    });

    test(
        'generateWithAudio uses standard OpenAI format for non-FastWhisper provider',
        () async {
      // Use a non-FastWhisper provider
      const audioBase64 = 'audio-base64-data';

      when(
        () => mockClient.createChatCompletionStream(
          request: any(named: 'request'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable([
          CreateChatCompletionStreamResponse(
            id: 'response-id',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(
                  content: 'Test response',
                ),
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        ]),
      );

      // Non-FastWhisper provider should use standard OpenAI path
      repository.generateWithAudio(
        prompt,
        model: model,
        baseUrl: baseUrl,
        apiKey: apiKey,
        audioBase64: audioBase64,
        provider: testProvider, // This is genericOpenAi type
        overrideClient: mockClient,
      );

      // Verify standard OpenAI client was used
      verify(
        () => mockClient.createChatCompletionStream(
          request: any(named: 'request'),
        ),
      ).called(1);
    });

    test('generate without overrideClient creates new OpenAIClient', () {
      // Act - Don't provide overrideClient, so it creates its own
      final stream = repository.generate(
        prompt,
        model: model,
        temperature: temperature,
        baseUrl: baseUrl,
        apiKey: apiKey,
      );

      // Just verify the stream is created (it will fail to connect, but that tests the path)
      expect(stream, isA<Stream<CreateChatCompletionStreamResponse>>());
      expect(stream.isBroadcast, isTrue);
    });

    test('generateWithImages without overrideClient creates new OpenAIClient',
        () {
      // Act - Don't provide overrideClient, so it creates its own
      final stream = repository.generateWithImages(
        prompt,
        model: model,
        temperature: temperature,
        baseUrl: baseUrl,
        apiKey: apiKey,
        images: const ['base64image'],
      );

      // Just verify the stream is created (it will fail to connect, but that tests the path)
      expect(stream, isA<Stream<CreateChatCompletionStreamResponse>>());
      expect(stream.isBroadcast, isTrue);
    });

    test('generateWithAudio without overrideClient creates new OpenAIClient',
        () {
      // Act - Don't provide overrideClient for non-FastWhisper provider
      final stream = repository.generateWithAudio(
        prompt,
        model: model,
        baseUrl: baseUrl,
        apiKey: apiKey,
        audioBase64: 'audio-data',
        provider: testProvider, // genericOpenAi type
      );

      // Just verify the stream is created (it will fail to connect, but that tests the path)
      expect(stream, isA<Stream<CreateChatCompletionStreamResponse>>());
      expect(stream.isBroadcast, isTrue);
    });

    test('generateWithImages does not use _filterAnthropicPings', () async {
      // Arrange
      const images = ['image1'];

      when(
        () => mockClient.createChatCompletionStream(
          request: any(named: 'request'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable([
          CreateChatCompletionStreamResponse(
            id: 'response-id',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(
                  content: 'Test',
                ),
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        ]),
      );

      // Act
      final stream = repository.generateWithImages(
        prompt,
        model: model,
        temperature: temperature,
        baseUrl: baseUrl,
        apiKey: apiKey,
        images: images,
        overrideClient: mockClient,
      );

      // Assert - Should get the response directly without filtering
      final responses = await stream.toList();
      expect(responses.length, 1);
      expect(responses[0].choices?[0].delta?.content, 'Test');
    });

    test(
        'generateWithAudio for non-FastWhisper does not use _filterAnthropicPings',
        () async {
      // Arrange
      const audioBase64 = 'audio-data';

      when(
        () => mockClient.createChatCompletionStream(
          request: any(named: 'request'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable([
          CreateChatCompletionStreamResponse(
            id: 'response-id',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(
                  content: 'Test',
                ),
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        ]),
      );

      // Act
      final stream = repository.generateWithAudio(
        prompt,
        model: model,
        baseUrl: baseUrl,
        apiKey: apiKey,
        audioBase64: audioBase64,
        provider: testProvider, // genericOpenAi type
        overrideClient: mockClient,
      );

      // Assert - Should get the response directly without filtering
      final responses = await stream.toList();
      expect(responses.length, 1);
      expect(responses[0].choices?[0].delta?.content, 'Test');
    });

    test('constructor initializes repository with ref', () {
      expect(repository.ref, isNotNull);
    });

    test('_filterAnthropicPings handles stream close correctly', () async {
      // Arrange - Create a stream that closes normally
      final normalStream =
          Stream<CreateChatCompletionStreamResponse>.fromIterable([
        CreateChatCompletionStreamResponse(
          id: 'response-id',
          choices: [
            const ChatCompletionStreamResponseChoice(
              delta: ChatCompletionStreamResponseDelta(
                content: 'Test response',
              ),
              index: 0,
            ),
          ],
          object: 'chat.completion.chunk',
          created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        ),
      ]);

      when(
        () => mockClient.createChatCompletionStream(
          request: any(named: 'request'),
        ),
      ).thenAnswer((_) => normalStream);

      // Act
      final stream = repository.generate(
        prompt,
        model: model,
        temperature: temperature,
        baseUrl: baseUrl,
        apiKey: apiKey,
        overrideClient: mockClient,
      );

      // Assert - Should complete normally
      final responses = await stream.toList();
      expect(responses.length, 1);
      expect(responses[0].choices?[0].delta?.content, 'Test response');
    });

    test('generateWithAudio handles Whisper provider type successfully',
        () async {
      // Create a Whisper provider
      final whisperProvider = AiConfig.inferenceProvider(
        id: 'whisper-id',
        name: 'OpenAI Whisper',
        baseUrl: 'http://localhost:8084',
        apiKey: '',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.whisper,
      ) as AiConfigInferenceProvider;

      const audioBase64 = 'audio-base64-data';
      const transcribedText = 'This is the OpenAI Whisper transcription.';

      // Mock successful HTTP response from the Python server
      when(() => mockHttpClient.post(
            Uri.parse('${whisperProvider.baseUrl}/v1/audio/transcriptions'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': model,
              'audio': audioBase64,
            }),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({'text': transcribedText}),
            200,
          ));

      final stream = repository.generateWithAudio(
        prompt,
        model: model,
        baseUrl: whisperProvider.baseUrl,
        apiKey: whisperProvider.apiKey,
        audioBase64: audioBase64,
        provider: whisperProvider,
      );

      expect(stream.isBroadcast, isTrue);

      final response = await stream.first;
      expect(response.choices?.length, 1);
      expect(response.choices?[0].delta?.content, transcribedText);
      expect(response.id, startsWith('whisper-'));
      expect(response.object, 'chat.completion.chunk');

      // Verify the HTTP call was made with correct parameters
      verify(() => mockHttpClient.post(
            Uri.parse('${whisperProvider.baseUrl}/v1/audio/transcriptions'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': model,
              'audio': audioBase64,
            }),
          )).called(1);
    });

    test('generateWithAudio handles Whisper provider HTTP error', () async {
      // Create a Whisper provider
      final whisperProvider = AiConfig.inferenceProvider(
        id: 'whisper-id',
        name: 'OpenAI Whisper',
        baseUrl: 'http://localhost:8084',
        apiKey: '',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.whisper,
      ) as AiConfigInferenceProvider;

      const audioBase64 = 'audio-base64-data';

      // Mock HTTP error response from the Python server
      when(() => mockHttpClient.post(
            Uri.parse('${whisperProvider.baseUrl}/v1/audio/transcriptions'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': model,
              'audio': audioBase64,
            }),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({'error': 'Audio transcription failed'}),
            500,
          ));

      final stream = repository.generateWithAudio(
        prompt,
        model: model,
        baseUrl: whisperProvider.baseUrl,
        apiKey: whisperProvider.apiKey,
        audioBase64: audioBase64,
        provider: whisperProvider,
      );

      // Should throw an exception for HTTP error
      expect(
        stream.first,
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to transcribe audio'),
        )),
      );
    });

    test('generateWithAudio handles Whisper provider invalid JSON response',
        () async {
      // Create a Whisper provider
      final whisperProvider = AiConfig.inferenceProvider(
        id: 'whisper-id',
        name: 'OpenAI Whisper',
        baseUrl: 'http://localhost:8084',
        apiKey: '',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.whisper,
      ) as AiConfigInferenceProvider;

      const audioBase64 = 'audio-base64-data';

      // Mock invalid JSON response from the Python server
      when(() => mockHttpClient.post(
            Uri.parse('${whisperProvider.baseUrl}/v1/audio/transcriptions'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': model,
              'audio': audioBase64,
            }),
          )).thenAnswer((_) async => http.Response(
            'Invalid JSON response',
            200,
          ));

      final stream = repository.generateWithAudio(
        prompt,
        model: model,
        baseUrl: whisperProvider.baseUrl,
        apiKey: whisperProvider.apiKey,
        audioBase64: audioBase64,
        provider: whisperProvider,
      );

      // Should throw an exception for invalid JSON
      expect(
        stream.first,
        throwsA(isA<
            TranscriptionException>()), // TranscriptionException wraps the FormatException
      );
    });

    test('generateWithAudio handles Whisper provider missing text field',
        () async {
      // Create a Whisper provider
      final whisperProvider = AiConfig.inferenceProvider(
        id: 'whisper-id',
        name: 'OpenAI Whisper',
        baseUrl: 'http://localhost:8084',
        apiKey: '',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.whisper,
      ) as AiConfigInferenceProvider;

      const audioBase64 = 'audio-base64-data';

      // Mock response without 'text' field
      when(() => mockHttpClient.post(
            Uri.parse('${whisperProvider.baseUrl}/v1/audio/transcriptions'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': model,
              'audio': audioBase64,
            }),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({'error': 'No text field'}),
            200,
          ));

      final stream = repository.generateWithAudio(
        prompt,
        model: model,
        baseUrl: whisperProvider.baseUrl,
        apiKey: whisperProvider.apiKey,
        audioBase64: audioBase64,
        provider: whisperProvider,
      );

      // Should throw an exception for missing text field
      expect(
        stream.first,
        throwsA(isA<
            TranscriptionException>()), // TranscriptionException is thrown instead of TypeError
      );
    });

    test('generateWithAudio uses maxCompletionTokens parameter for Whisper',
        () async {
      // Create a Whisper provider
      final whisperProvider = AiConfig.inferenceProvider(
        id: 'whisper-id',
        name: 'OpenAI Whisper',
        baseUrl: 'http://localhost:8084',
        apiKey: '',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.whisper,
      ) as AiConfigInferenceProvider;

      const audioBase64 = 'audio-base64-data';
      const transcribedText = 'This is the transcription.';
      const maxCompletionTokens = 1000;

      // Mock successful HTTP response
      when(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({'text': transcribedText}),
            200,
          ));

      await repository
          .generateWithAudio(
            prompt,
            model: model,
            baseUrl: whisperProvider.baseUrl,
            apiKey: whisperProvider.apiKey,
            audioBase64: audioBase64,
            provider: whisperProvider,
            maxCompletionTokens: maxCompletionTokens,
          )
          .first;

      // Verify maxCompletionTokens parameter is accepted (Whisper doesn't use it but should accept it)
      verify(() => mockHttpClient.post(
            Uri.parse('${whisperProvider.baseUrl}/v1/audio/transcriptions'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': model,
              'audio': audioBase64,
            }),
          )).called(1);
    });

    test('generateWithAudio with empty audio data for Whisper', () async {
      // Create a Whisper provider
      final whisperProvider = AiConfig.inferenceProvider(
        id: 'whisper-id',
        name: 'OpenAI Whisper',
        baseUrl: 'http://localhost:8084',
        apiKey: '',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.whisper,
      ) as AiConfigInferenceProvider;

      const audioBase64 = '';
      const transcribedText = '';

      // Mock response for empty audio
      when(() => mockHttpClient.post(
            Uri.parse('${whisperProvider.baseUrl}/v1/audio/transcriptions'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': model,
              'audio': audioBase64,
            }),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({'text': transcribedText}),
            200,
          ));

      final stream = repository.generateWithAudio(
        prompt,
        model: model,
        baseUrl: whisperProvider.baseUrl,
        apiKey: whisperProvider.apiKey,
        audioBase64: audioBase64,
        provider: whisperProvider,
      );

      final response = await stream.first;
      expect(response.choices?[0].delta?.content, transcribedText);
    });

    test('constructor with custom httpClient parameter', () {
      final customHttpClient = MockHttpClient();

      // Create a container with required provider overrides
      final mockOllamaRepo = MockOllamaInferenceRepository();
      final mockGeminiRepo = MockGeminiInferenceRepository();

      final testContainer = ProviderContainer(
        overrides: [
          ollamaInferenceRepositoryProvider.overrideWithValue(mockOllamaRepo),
          geminiInferenceRepositoryProvider.overrideWithValue(mockGeminiRepo),
        ],
      );

      final ref = testContainer.read(testRefProvider);

      final customRepository = CloudInferenceRepository(
        ref,
        httpClient: customHttpClient,
      );

      expect(customRepository, isA<CloudInferenceRepository>());
      expect(customRepository.ref, isA<Ref>());
      testContainer.dispose();
    });

    test('generateWithAudio creates proper response structure for Whisper',
        () async {
      // Create a Whisper provider
      final whisperProvider = AiConfig.inferenceProvider(
        id: 'whisper-id',
        name: 'OpenAI Whisper',
        baseUrl: 'http://localhost:8084',
        apiKey: '',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.whisper,
      ) as AiConfigInferenceProvider;

      const audioBase64 = 'audio-base64-data';
      const transcribedText = 'Test transcription';

      when(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({'text': transcribedText}),
            200,
          ));

      final stream = repository.generateWithAudio(
        prompt,
        model: model,
        baseUrl: whisperProvider.baseUrl,
        apiKey: whisperProvider.apiKey,
        audioBase64: audioBase64,
        provider: whisperProvider,
      );

      final response = await stream.first;

      // Verify response structure
      expect(response.id, startsWith('whisper-'));
      expect(response.object, equals('chat.completion.chunk'));
      expect(response.created, isA<int>());
      expect(response.choices, hasLength(1));
      expect(response.choices?[0].index, equals(0));
      expect(response.choices?[0].delta?.content, equals(transcribedText));
      expect(response.choices?[0].delta?.role, isNull);
    });

    test('generate sets verbosity to null for Gemini compatibility', () async {
      // Arrange
      when(
        () => mockClient.createChatCompletionStream(
          request: any(named: 'request'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable([
          CreateChatCompletionStreamResponse(
            id: 'response-id',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(
                  content: 'Test response',
                ),
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        ]),
      );

      // Act
      await repository
          .generate(
            prompt,
            model: model,
            temperature: temperature,
            baseUrl: baseUrl,
            apiKey: apiKey,
            overrideClient: mockClient,
          )
          .toList();

      // Assert
      final captured = verify(
        () => mockClient.createChatCompletionStream(
          request: captureAny(named: 'request'),
        ),
      ).captured;

      final request = captured.first as CreateChatCompletionRequest;
      expect(request.verbosity, isNull);
    });

    test('generateWithImages sets verbosity to null for Gemini compatibility',
        () async {
      // Arrange
      const images = ['base64-image-data'];

      when(
        () => mockClient.createChatCompletionStream(
          request: any(named: 'request'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable([
          CreateChatCompletionStreamResponse(
            id: 'response-id',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(
                  content: 'Test response',
                ),
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        ]),
      );

      // Act
      await repository
          .generateWithImages(
            prompt,
            model: model,
            temperature: temperature,
            baseUrl: baseUrl,
            apiKey: apiKey,
            images: images,
            overrideClient: mockClient,
          )
          .toList();

      // Assert
      final captured = verify(
        () => mockClient.createChatCompletionStream(
          request: captureAny(named: 'request'),
        ),
      ).captured;

      final request = captured.first as CreateChatCompletionRequest;
      expect(request.verbosity, isNull);
    });

    test('generateWithAudio sets verbosity to null for Gemini compatibility',
        () async {
      // Arrange
      const audioBase64 = 'base64-audio-data';

      when(
        () => mockClient.createChatCompletionStream(
          request: any(named: 'request'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable([
          CreateChatCompletionStreamResponse(
            id: 'response-id',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(
                  content: 'Test response',
                ),
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        ]),
      );

      // Act
      await repository
          .generateWithAudio(
            prompt,
            model: model,
            audioBase64: audioBase64,
            baseUrl: baseUrl,
            apiKey: apiKey,
            provider: testProvider,
            overrideClient: mockClient,
          )
          .toList();

      // Assert
      final captured = verify(
        () => mockClient.createChatCompletionStream(
          request: captureAny(named: 'request'),
        ),
      ).captured;

      final request = captured.first as CreateChatCompletionRequest;
      expect(request.verbosity, isNull);
    });

    test('generate with empty tools list does not set toolChoice', () async {
      // Arrange
      final emptyTools = <ChatCompletionTool>[];

      when(
        () => mockClient.createChatCompletionStream(
          request: any(named: 'request'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable([
          CreateChatCompletionStreamResponse(
            id: 'response-id',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(
                  content: 'Test response',
                ),
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        ]),
      );

      // Act
      await repository
          .generate(
            prompt,
            model: model,
            temperature: temperature,
            baseUrl: baseUrl,
            apiKey: apiKey,
            overrideClient: mockClient,
            tools: emptyTools,
          )
          .toList();

      // Assert
      final captured = verify(
        () => mockClient.createChatCompletionStream(
          request: captureAny(named: 'request'),
        ),
      ).captured;

      final request = captured.first as CreateChatCompletionRequest;
      expect(request.toolChoice, isNull);
      expect(request.tools, isEmpty);
    });

    test('generate with non-empty tools list sets toolChoice', () async {
      // Arrange
      final tools = [
        const ChatCompletionTool(
          type: ChatCompletionToolType.function,
          function: FunctionObject(
            name: 'test_function',
            description: 'A test function',
          ),
        ),
      ];

      when(
        () => mockClient.createChatCompletionStream(
          request: any(named: 'request'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable([
          CreateChatCompletionStreamResponse(
            id: 'response-id',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(
                  content: 'Test response',
                ),
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        ]),
      );

      // Act
      await repository
          .generate(
            prompt,
            model: model,
            temperature: temperature,
            baseUrl: baseUrl,
            apiKey: apiKey,
            overrideClient: mockClient,
            tools: tools,
          )
          .toList();

      // Assert
      final captured = verify(
        () => mockClient.createChatCompletionStream(
          request: captureAny(named: 'request'),
        ),
      ).captured;

      final request = captured.first as CreateChatCompletionRequest;
      expect(request.toolChoice, isNotNull);
      expect(request.tools, hasLength(1));
    });
  });

  group('CloudInferenceRepository - Gemini Provider', () {
    late MockHttpClient mockHttpClient;
    late ProviderContainer container;
    late MockGeminiInferenceRepository mockGeminiRepo;
    late CloudInferenceRepository repository;

    setUp(() {
      mockHttpClient = MockHttpClient();
      mockGeminiRepo = MockGeminiInferenceRepository();

      container = ProviderContainer(
        overrides: [
          geminiInferenceRepositoryProvider.overrideWithValue(mockGeminiRepo),
          ollamaInferenceRepositoryProvider
              .overrideWithValue(MockOllamaInferenceRepository()),
          // Mock the thoughts toggle provider - default to true for testing
          geminiIncludeThoughtsProvider.overrideWithValue(true),
        ],
      );

      final ref = container.read(testRefProvider);
      repository = CloudInferenceRepository(ref, httpClient: mockHttpClient);
    });

    tearDown(() {
      mockHttpClient.close();
      container.dispose();
    });

    AiConfigInferenceProvider createGeminiProvider() {
      return AiConfigInferenceProvider(
        id: 'gemini-provider',
        name: 'Gemini',
        baseUrl: 'https://generativelanguage.googleapis.com',
        apiKey: 'test-api-key',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.gemini,
      );
    }

    test('routes to GeminiInferenceRepository when provider type is gemini',
        () async {
      final provider = createGeminiProvider();
      const model = 'gemini-2.5-pro';

      when(
        () => mockGeminiRepo.generateText(
          prompt: any(named: 'prompt'),
          model: any(named: 'model'),
          temperature: any(named: 'temperature'),
          thinkingConfig: any(named: 'thinkingConfig'),
          provider: any(named: 'provider'),
          systemMessage: any(named: 'systemMessage'),
          maxCompletionTokens: any(named: 'maxCompletionTokens'),
          tools: any(named: 'tools'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable([
          CreateChatCompletionStreamResponse(
            id: 'test-id',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            model: model,
            choices: [
              const ChatCompletionStreamResponseChoice(
                index: 0,
                delta: ChatCompletionStreamResponseDelta(content: 'Hello'),
              ),
            ],
          ),
        ]),
      );

      final result = await repository
          .generate(
            'Test prompt',
            model: model,
            temperature: 0.7,
            baseUrl: provider.baseUrl,
            apiKey: provider.apiKey,
            provider: provider,
          )
          .toList();

      expect(result, hasLength(1));
      expect(result.first.choices!.first.delta!.content, 'Hello');

      verify(
        () => mockGeminiRepo.generateText(
          prompt: 'Test prompt',
          model: model,
          temperature: 0.7,
          thinkingConfig: any(named: 'thinkingConfig'),
          provider: provider,
        ),
      ).called(1);
    });

    test('enables includeThoughts for thinking-capable models (Pro)', () async {
      final provider = createGeminiProvider();
      const model = 'gemini-2.5-pro';
      GeminiThinkingConfig? capturedConfig;

      when(
        () => mockGeminiRepo.generateText(
          prompt: any(named: 'prompt'),
          model: any(named: 'model'),
          temperature: any(named: 'temperature'),
          thinkingConfig: any(named: 'thinkingConfig'),
          provider: any(named: 'provider'),
          systemMessage: any(named: 'systemMessage'),
          maxCompletionTokens: any(named: 'maxCompletionTokens'),
          tools: any(named: 'tools'),
        ),
      ).thenAnswer((invocation) {
        capturedConfig =
            invocation.namedArguments[#thinkingConfig] as GeminiThinkingConfig;
        return const Stream.empty();
      });

      await repository
          .generate(
            'Test',
            model: model,
            temperature: 0.5,
            baseUrl: provider.baseUrl,
            apiKey: provider.apiKey,
            provider: provider,
          )
          .toList();

      expect(capturedConfig, isNotNull);
      // gemini-2.5-pro has auto config (budget = -1), so includeThoughts should be true
      expect(capturedConfig!.includeThoughts, isTrue);
      expect(capturedConfig!.thinkingBudget, -1);
    });

    test('enables includeThoughts for Flash models with thinking support',
        () async {
      final provider = createGeminiProvider();
      const model = 'gemini-2.5-flash';
      GeminiThinkingConfig? capturedConfig;

      when(
        () => mockGeminiRepo.generateText(
          prompt: any(named: 'prompt'),
          model: any(named: 'model'),
          temperature: any(named: 'temperature'),
          thinkingConfig: any(named: 'thinkingConfig'),
          provider: any(named: 'provider'),
          systemMessage: any(named: 'systemMessage'),
          maxCompletionTokens: any(named: 'maxCompletionTokens'),
          tools: any(named: 'tools'),
        ),
      ).thenAnswer((invocation) {
        capturedConfig =
            invocation.namedArguments[#thinkingConfig] as GeminiThinkingConfig;
        return const Stream.empty();
      });

      await repository
          .generate(
            'Test',
            model: model,
            temperature: 0.5,
            baseUrl: provider.baseUrl,
            apiKey: provider.apiKey,
            provider: provider,
          )
          .toList();

      expect(capturedConfig, isNotNull);
      // gemini-2.5-flash has standard config (budget = 8192), so includeThoughts should be true
      expect(capturedConfig!.includeThoughts, isTrue);
      expect(capturedConfig!.thinkingBudget, 8192);
    });

    test('disables includeThoughts for models without thinking support',
        () async {
      final provider = createGeminiProvider();
      const model = 'gemini-2.0-flash';
      GeminiThinkingConfig? capturedConfig;

      when(
        () => mockGeminiRepo.generateText(
          prompt: any(named: 'prompt'),
          model: any(named: 'model'),
          temperature: any(named: 'temperature'),
          thinkingConfig: any(named: 'thinkingConfig'),
          provider: any(named: 'provider'),
          systemMessage: any(named: 'systemMessage'),
          maxCompletionTokens: any(named: 'maxCompletionTokens'),
          tools: any(named: 'tools'),
        ),
      ).thenAnswer((invocation) {
        capturedConfig =
            invocation.namedArguments[#thinkingConfig] as GeminiThinkingConfig;
        return const Stream.empty();
      });

      await repository
          .generate(
            'Test',
            model: model,
            temperature: 0.5,
            baseUrl: provider.baseUrl,
            apiKey: provider.apiKey,
            provider: provider,
          )
          .toList();

      expect(capturedConfig, isNotNull);
      // gemini-2.0-flash has disabled config (budget = 0), so includeThoughts should be false
      expect(capturedConfig!.includeThoughts, isFalse);
      expect(capturedConfig!.thinkingBudget, 0);
    });

    test('passes system message to Gemini repository', () async {
      final provider = createGeminiProvider();
      const model = 'gemini-2.5-pro';
      const systemMessage = 'You are a helpful assistant.';

      when(
        () => mockGeminiRepo.generateText(
          prompt: any(named: 'prompt'),
          model: any(named: 'model'),
          temperature: any(named: 'temperature'),
          thinkingConfig: any(named: 'thinkingConfig'),
          provider: any(named: 'provider'),
          systemMessage: any(named: 'systemMessage'),
          maxCompletionTokens: any(named: 'maxCompletionTokens'),
          tools: any(named: 'tools'),
        ),
      ).thenAnswer((_) => const Stream.empty());

      await repository
          .generate(
            'Test',
            model: model,
            temperature: 0.5,
            baseUrl: provider.baseUrl,
            apiKey: provider.apiKey,
            provider: provider,
            systemMessage: systemMessage,
          )
          .toList();

      verify(
        () => mockGeminiRepo.generateText(
          prompt: 'Test',
          model: model,
          temperature: 0.5,
          thinkingConfig: any(named: 'thinkingConfig'),
          provider: provider,
          systemMessage: systemMessage,
        ),
      ).called(1);
    });

    test('passes maxCompletionTokens to Gemini repository', () async {
      final provider = createGeminiProvider();
      const model = 'gemini-2.5-pro';
      const maxTokens = 4096;

      when(
        () => mockGeminiRepo.generateText(
          prompt: any(named: 'prompt'),
          model: any(named: 'model'),
          temperature: any(named: 'temperature'),
          thinkingConfig: any(named: 'thinkingConfig'),
          provider: any(named: 'provider'),
          systemMessage: any(named: 'systemMessage'),
          maxCompletionTokens: any(named: 'maxCompletionTokens'),
          tools: any(named: 'tools'),
        ),
      ).thenAnswer((_) => const Stream.empty());

      await repository
          .generate(
            'Test',
            model: model,
            temperature: 0.5,
            baseUrl: provider.baseUrl,
            apiKey: provider.apiKey,
            provider: provider,
            maxCompletionTokens: maxTokens,
          )
          .toList();

      verify(
        () => mockGeminiRepo.generateText(
          prompt: 'Test',
          model: model,
          temperature: 0.5,
          thinkingConfig: any(named: 'thinkingConfig'),
          provider: provider,
          maxCompletionTokens: maxTokens,
        ),
      ).called(1);
    });

    test('passes tools to Gemini repository', () async {
      final provider = createGeminiProvider();
      const model = 'gemini-2.5-pro';
      final tools = [
        const ChatCompletionTool(
          type: ChatCompletionToolType.function,
          function: FunctionObject(
            name: 'test_function',
            description: 'A test function',
            parameters: <String, dynamic>{
              'type': 'object',
              'properties': <String, dynamic>{}
            },
          ),
        ),
      ];

      when(
        () => mockGeminiRepo.generateText(
          prompt: any(named: 'prompt'),
          model: any(named: 'model'),
          temperature: any(named: 'temperature'),
          thinkingConfig: any(named: 'thinkingConfig'),
          provider: any(named: 'provider'),
          systemMessage: any(named: 'systemMessage'),
          maxCompletionTokens: any(named: 'maxCompletionTokens'),
          tools: any(named: 'tools'),
        ),
      ).thenAnswer((_) => const Stream.empty());

      await repository
          .generate(
            'Test',
            model: model,
            temperature: 0.5,
            baseUrl: provider.baseUrl,
            apiKey: provider.apiKey,
            provider: provider,
            tools: tools,
          )
          .toList();

      verify(
        () => mockGeminiRepo.generateText(
          prompt: 'Test',
          model: model,
          temperature: 0.5,
          thinkingConfig: any(named: 'thinkingConfig'),
          provider: provider,
          tools: tools,
        ),
      ).called(1);
    });

    test('uses models/ prefix correctly for model ID', () async {
      final provider = createGeminiProvider();
      const model = 'models/gemini-2.5-flash';
      GeminiThinkingConfig? capturedConfig;

      when(
        () => mockGeminiRepo.generateText(
          prompt: any(named: 'prompt'),
          model: any(named: 'model'),
          temperature: any(named: 'temperature'),
          thinkingConfig: any(named: 'thinkingConfig'),
          provider: any(named: 'provider'),
          systemMessage: any(named: 'systemMessage'),
          maxCompletionTokens: any(named: 'maxCompletionTokens'),
          tools: any(named: 'tools'),
        ),
      ).thenAnswer((invocation) {
        capturedConfig =
            invocation.namedArguments[#thinkingConfig] as GeminiThinkingConfig;
        return const Stream.empty();
      });

      await repository
          .generate(
            'Test',
            model: model,
            temperature: 0.5,
            baseUrl: provider.baseUrl,
            apiKey: provider.apiKey,
            provider: provider,
          )
          .toList();

      // models/gemini-2.5-flash should get standard config
      expect(capturedConfig!.thinkingBudget, 8192);
      expect(capturedConfig!.includeThoughts, isTrue);
    });

    test('generateWithMessages routes to Gemini repository for multi-turn',
        () async {
      final provider = createGeminiProvider();
      const model = 'gemini-2.5-pro';

      when(
        () => mockGeminiRepo.generateTextWithMessages(
          messages: any(named: 'messages'),
          model: any(named: 'model'),
          temperature: any(named: 'temperature'),
          thinkingConfig: any(named: 'thinkingConfig'),
          provider: any(named: 'provider'),
          thoughtSignatures: any(named: 'thoughtSignatures'),
          systemMessage: any(named: 'systemMessage'),
          maxCompletionTokens: any(named: 'maxCompletionTokens'),
          tools: any(named: 'tools'),
          signatureCollector: any(named: 'signatureCollector'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable([
          CreateChatCompletionStreamResponse(
            id: 'test-id',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            model: model,
            choices: [
              const ChatCompletionStreamResponseChoice(
                index: 0,
                delta: ChatCompletionStreamResponseDelta(content: 'Response'),
              ),
            ],
          ),
        ]),
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

      final result = await repository
          .generateWithMessages(
            messages: messages,
            model: model,
            temperature: 0.7,
            provider: provider,
          )
          .toList();

      expect(result, hasLength(1));
      expect(result.first.choices!.first.delta!.content, 'Response');

      verify(
        () => mockGeminiRepo.generateTextWithMessages(
          messages: messages,
          model: model,
          temperature: 0.7,
          thinkingConfig: any(named: 'thinkingConfig'),
          provider: provider,
        ),
      ).called(1);
    });

    test('generateWithMessages passes thought signatures to Gemini', () async {
      final provider = createGeminiProvider();
      const model = 'gemini-3-pro';
      final signatures = {'call-123': 'sig-abc'};

      when(
        () => mockGeminiRepo.generateTextWithMessages(
          messages: any(named: 'messages'),
          model: any(named: 'model'),
          temperature: any(named: 'temperature'),
          thinkingConfig: any(named: 'thinkingConfig'),
          provider: any(named: 'provider'),
          thoughtSignatures: any(named: 'thoughtSignatures'),
          systemMessage: any(named: 'systemMessage'),
          maxCompletionTokens: any(named: 'maxCompletionTokens'),
          tools: any(named: 'tools'),
          signatureCollector: any(named: 'signatureCollector'),
        ),
      ).thenAnswer((_) => const Stream.empty());

      await repository.generateWithMessages(
        messages: const [
          ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string('Continue'),
          ),
        ],
        model: model,
        temperature: 0.5,
        provider: provider,
        thoughtSignatures: signatures,
      ).toList();

      verify(
        () => mockGeminiRepo.generateTextWithMessages(
          messages: any(named: 'messages'),
          model: model,
          temperature: 0.5,
          thinkingConfig: any(named: 'thinkingConfig'),
          provider: provider,
          thoughtSignatures: signatures,
        ),
      ).called(1);
    });

    test('generateWithMessages disables thoughts for non-thinking models',
        () async {
      // gemini-2.0-flash has thinkingBudget=0, so includeThoughts should be false
      final provider = createGeminiProvider();
      const model = 'gemini-2.0-flash'; // Non-thinking model
      GeminiThinkingConfig? capturedConfig;

      when(
        () => mockGeminiRepo.generateTextWithMessages(
          messages: any(named: 'messages'),
          model: any(named: 'model'),
          temperature: any(named: 'temperature'),
          thinkingConfig: any(named: 'thinkingConfig'),
          provider: any(named: 'provider'),
          thoughtSignatures: any(named: 'thoughtSignatures'),
          systemMessage: any(named: 'systemMessage'),
          maxCompletionTokens: any(named: 'maxCompletionTokens'),
          tools: any(named: 'tools'),
          signatureCollector: any(named: 'signatureCollector'),
        ),
      ).thenAnswer((invocation) {
        capturedConfig =
            invocation.namedArguments[#thinkingConfig] as GeminiThinkingConfig;
        return const Stream.empty();
      });

      await repository.generateWithMessages(
        messages: const [
          ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string('Test'),
          ),
        ],
        model: model,
        temperature: 0.5,
        provider: provider,
      ).toList();

      // Non-thinking model (thinkingBudget=0) should have includeThoughts=false
      expect(capturedConfig!.includeThoughts, isFalse);
    });

    test(
        'generateWithMessages always captures thoughts for thinking-capable models',
        () async {
      // The toggle no longer affects thought capture - thoughts are always
      // captured for thinking-capable models so they appear in the Thoughts tab.
      // The toggle only controls inline display in chat.
      final provider = createGeminiProvider();
      const model = 'gemini-2.5-pro'; // Thinking-capable model
      GeminiThinkingConfig? capturedConfig;

      when(
        () => mockGeminiRepo.generateTextWithMessages(
          messages: any(named: 'messages'),
          model: any(named: 'model'),
          temperature: any(named: 'temperature'),
          thinkingConfig: any(named: 'thinkingConfig'),
          provider: any(named: 'provider'),
          thoughtSignatures: any(named: 'thoughtSignatures'),
          systemMessage: any(named: 'systemMessage'),
          maxCompletionTokens: any(named: 'maxCompletionTokens'),
          tools: any(named: 'tools'),
          signatureCollector: any(named: 'signatureCollector'),
        ),
      ).thenAnswer((invocation) {
        capturedConfig =
            invocation.namedArguments[#thinkingConfig] as GeminiThinkingConfig;
        return const Stream.empty();
      });

      await repository.generateWithMessages(
        messages: const [
          ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string('Test'),
          ),
        ],
        model: model,
        temperature: 0.5,
        provider: provider,
      ).toList();

      // Thoughts are always captured for thinking-capable models
      expect(capturedConfig!.includeThoughts, isTrue);
    });
  });

  group('CloudInferenceRepository - generateImage', () {
    late MockHttpClient mockHttpClient;
    late ProviderContainer container;
    late MockGeminiInferenceRepository mockGeminiRepo;
    late CloudInferenceRepository repository;

    setUp(() {
      mockHttpClient = MockHttpClient();
      mockGeminiRepo = MockGeminiInferenceRepository();

      container = ProviderContainer(
        overrides: [
          geminiInferenceRepositoryProvider.overrideWithValue(mockGeminiRepo),
          ollamaInferenceRepositoryProvider
              .overrideWithValue(MockOllamaInferenceRepository()),
        ],
      );

      final ref = container.read(testRefProvider);
      repository = CloudInferenceRepository(ref, httpClient: mockHttpClient);
    });

    tearDown(() {
      mockHttpClient.close();
      container.dispose();
    });

    AiConfigInferenceProvider createGeminiProvider() {
      return AiConfigInferenceProvider(
        id: 'gemini-provider',
        name: 'Gemini',
        baseUrl: 'https://generativelanguage.googleapis.com',
        apiKey: 'test-api-key',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.gemini,
      );
    }

    test('routes to GeminiInferenceRepository for Gemini provider', () async {
      final provider = createGeminiProvider();
      const model = 'models/gemini-3-pro-image-preview';
      const prompt = 'Generate a beautiful sunset';
      const systemMessage = 'You are an image generator';

      when(
        () => mockGeminiRepo.generateImage(
          prompt: any(named: 'prompt'),
          model: any(named: 'model'),
          provider: any(named: 'provider'),
          systemMessage: any(named: 'systemMessage'),
        ),
      ).thenAnswer(
        (_) async => const GeneratedImage(
          bytes: [1, 2, 3, 4, 5],
          mimeType: 'image/png',
        ),
      );

      final result = await repository.generateImage(
        prompt: prompt,
        model: model,
        provider: provider,
        systemMessage: systemMessage,
      );

      expect(result.bytes, [1, 2, 3, 4, 5]);
      expect(result.mimeType, 'image/png');

      verify(
        () => mockGeminiRepo.generateImage(
          prompt: prompt,
          model: model,
          provider: provider,
          systemMessage: systemMessage,
        ),
      ).called(1);
    });

    test('throws UnsupportedError for non-Gemini provider', () async {
      final ollamaProvider = AiConfigInferenceProvider(
        id: 'ollama-provider',
        name: 'Ollama',
        baseUrl: 'http://localhost:11434',
        apiKey: '',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.ollama,
      );

      expect(
        () => repository.generateImage(
          prompt: 'Generate an image',
          model: 'llama2',
          provider: ollamaProvider,
        ),
        throwsA(isA<UnsupportedError>().having(
          (e) => e.message,
          'message',
          contains('only supported for Gemini providers'),
        )),
      );
    });

    test('works without optional systemMessage', () async {
      final provider = createGeminiProvider();
      const model = 'models/gemini-3-pro-image-preview';

      when(
        () => mockGeminiRepo.generateImage(
          prompt: any(named: 'prompt'),
          model: any(named: 'model'),
          provider: any(named: 'provider'),
          systemMessage: any(named: 'systemMessage'),
        ),
      ).thenAnswer(
        (_) async => const GeneratedImage(
          bytes: [10, 20, 30],
          mimeType: 'image/jpeg',
        ),
      );

      final result = await repository.generateImage(
        prompt: 'A cat playing piano',
        model: model,
        provider: provider,
      );

      expect(result.bytes, [10, 20, 30]);
      expect(result.mimeType, 'image/jpeg');

      verify(
        () => mockGeminiRepo.generateImage(
          prompt: 'A cat playing piano',
          model: model,
          provider: provider,
        ),
      ).called(1);
    });

    test('propagates exceptions from GeminiInferenceRepository', () async {
      final provider = createGeminiProvider();
      const model = 'models/gemini-3-pro-image-preview';

      when(
        () => mockGeminiRepo.generateImage(
          prompt: any(named: 'prompt'),
          model: any(named: 'model'),
          provider: any(named: 'provider'),
          systemMessage: any(named: 'systemMessage'),
        ),
      ).thenThrow(Exception('Image generation failed'));

      expect(
        () => repository.generateImage(
          prompt: 'Generate an image',
          model: model,
          provider: provider,
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Image generation failed'),
        )),
      );
    });

    test('passes reference images to GeminiInferenceRepository', () async {
      final provider = createGeminiProvider();
      const model = 'models/gemini-3-pro-image-preview';
      const prompt = 'Generate a similar image';

      final referenceImages = [
        const ProcessedReferenceImage(
          base64Data: 'base64data1',
          mimeType: 'image/jpeg',
          originalId: 'ref-1',
        ),
        const ProcessedReferenceImage(
          base64Data: 'base64data2',
          mimeType: 'image/png',
          originalId: 'ref-2',
        ),
      ];

      when(
        () => mockGeminiRepo.generateImage(
          prompt: any(named: 'prompt'),
          model: any(named: 'model'),
          provider: any(named: 'provider'),
          systemMessage: any(named: 'systemMessage'),
          referenceImages: any(named: 'referenceImages'),
        ),
      ).thenAnswer(
        (_) async => const GeneratedImage(
          bytes: [1, 2, 3],
          mimeType: 'image/png',
        ),
      );

      final result = await repository.generateImage(
        prompt: prompt,
        model: model,
        provider: provider,
        referenceImages: referenceImages,
      );

      expect(result.bytes, [1, 2, 3]);

      verify(
        () => mockGeminiRepo.generateImage(
          prompt: prompt,
          model: model,
          provider: provider,
          referenceImages: referenceImages,
        ),
      ).called(1);
    });

    test('works with empty reference images list', () async {
      final provider = createGeminiProvider();
      const model = 'models/gemini-3-pro-image-preview';
      const prompt = 'Generate an image';

      when(
        () => mockGeminiRepo.generateImage(
          prompt: any(named: 'prompt'),
          model: any(named: 'model'),
          provider: any(named: 'provider'),
          systemMessage: any(named: 'systemMessage'),
          referenceImages: any(named: 'referenceImages'),
        ),
      ).thenAnswer(
        (_) async => const GeneratedImage(
          bytes: [5, 6, 7],
          mimeType: 'image/jpeg',
        ),
      );

      final result = await repository.generateImage(
        prompt: prompt,
        model: model,
        provider: provider,
        referenceImages: [],
      );

      expect(result.bytes, [5, 6, 7]);

      verify(
        () => mockGeminiRepo.generateImage(
          prompt: prompt,
          model: model,
          provider: provider,
          referenceImages: [],
        ),
      ).called(1);
    });

    test('throws UnsupportedError for OpenAI provider with reference images',
        () async {
      final openAiProvider = AiConfigInferenceProvider(
        id: 'openai-provider',
        name: 'OpenAI',
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'test-api-key',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.openAi,
      );

      final referenceImages = [
        const ProcessedReferenceImage(
          base64Data: 'data',
          mimeType: 'image/png',
          originalId: 'ref-1',
        ),
      ];

      expect(
        () => repository.generateImage(
          prompt: 'Generate an image',
          model: 'dall-e-3',
          provider: openAiProvider,
          referenceImages: referenceImages,
        ),
        throwsA(isA<UnsupportedError>().having(
          (e) => e.message,
          'message',
          contains('only supported for Gemini providers'),
        )),
      );
    });
  });

  group('CloudInferenceRepository - generateWithMessages for other providers',
      () {
    late ProviderContainer container;
    late CloudInferenceRepository repository;
    late MockOllamaInferenceRepository mockOllamaRepo;
    late MockGeminiInferenceRepository mockGeminiRepo;

    setUp(() {
      mockOllamaRepo = MockOllamaInferenceRepository();
      mockGeminiRepo = MockGeminiInferenceRepository();

      container = ProviderContainer(
        overrides: [
          geminiInferenceRepositoryProvider.overrideWithValue(mockGeminiRepo),
          ollamaInferenceRepositoryProvider.overrideWithValue(mockOllamaRepo),
          geminiIncludeThoughtsProvider.overrideWithValue(true),
        ],
      );

      final ref = container.read(testRefProvider);
      repository = CloudInferenceRepository(ref);
    });

    tearDown(() {
      container.dispose();
    });

    test('routes to Ollama repository for Ollama provider', () async {
      final provider = AiConfigInferenceProvider(
        id: 'ollama-provider',
        name: 'Ollama',
        baseUrl: 'http://localhost:11434',
        apiKey: '',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.ollama,
      );
      const model = 'llama2';

      when(
        () => mockOllamaRepo.generateTextWithMessages(
          messages: any(named: 'messages'),
          model: any(named: 'model'),
          temperature: any(named: 'temperature'),
          provider: any(named: 'provider'),
          maxCompletionTokens: any(named: 'maxCompletionTokens'),
          tools: any(named: 'tools'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable([
          CreateChatCompletionStreamResponse(
            id: 'test-id',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            model: model,
            choices: [
              const ChatCompletionStreamResponseChoice(
                index: 0,
                delta: ChatCompletionStreamResponseDelta(content: 'Ollama'),
              ),
            ],
          ),
        ]),
      );

      final messages = [
        const ChatCompletionMessage.user(
          content: ChatCompletionUserMessageContent.string('Hello'),
        ),
      ];

      final result = await repository
          .generateWithMessages(
            messages: messages,
            model: model,
            temperature: 0.7,
            provider: provider,
          )
          .toList();

      expect(result, hasLength(1));
      expect(result.first.choices!.first.delta!.content, 'Ollama');

      verify(
        () => mockOllamaRepo.generateTextWithMessages(
          messages: messages,
          model: model,
          temperature: 0.7,
          provider: provider,
        ),
      ).called(1);
    });
  });

  // Note: OpenAI Transcription API test removed - the _transcribeWithOpenAiApi
  // method uses http.MultipartRequest directly which can't be easily mocked.
  // The functionality is tested via integration/manual testing.

  group('CloudInferenceRepository - Nullable Temperature', () {
    late MockOpenAIClient mockClient;
    late ProviderContainer container;
    late CloudInferenceRepository repository;

    setUp(() {
      mockClient = MockOpenAIClient();
      final mockOllamaRepo = MockOllamaInferenceRepository();
      final mockGeminiRepo = MockGeminiInferenceRepository();

      container = ProviderContainer(
        overrides: [
          ollamaInferenceRepositoryProvider.overrideWithValue(mockOllamaRepo),
          geminiInferenceRepositoryProvider.overrideWithValue(mockGeminiRepo),
        ],
      );

      final ref = container.read(testRefProvider);
      repository = CloudInferenceRepository(ref);
    });

    tearDown(() {
      container.dispose();
    });

    test('generate accepts null temperature parameter', () {
      when(
        () => mockClient.createChatCompletionStream(
          request: any(named: 'request'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable([
          CreateChatCompletionStreamResponse(
            id: 'response-id',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(
                  content: 'Test response',
                ),
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        ]),
      );

      // Act - pass null temperature (for reasoning models)
      repository.generate(
        'Hello',
        model: 'o3',
        temperature: null, // OpenAI reasoning models don't support temperature
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'test-key',
        overrideClient: mockClient,
      );

      final captured = verify(
        () => mockClient.createChatCompletionStream(
          request: captureAny(named: 'request'),
        ),
      ).captured;

      final request = captured.first as CreateChatCompletionRequest;
      expect(request.temperature, isNull);
    });

    test('generateWithImages accepts null temperature parameter', () {
      when(
        () => mockClient.createChatCompletionStream(
          request: any(named: 'request'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable([
          CreateChatCompletionStreamResponse(
            id: 'response-id',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(
                  content: 'Test response',
                ),
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        ]),
      );

      // Act - pass null temperature
      repository.generateWithImages(
        'Describe this image',
        model: 'o3',
        temperature: null,
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'test-key',
        images: ['base64image'],
        overrideClient: mockClient,
      );

      final captured = verify(
        () => mockClient.createChatCompletionStream(
          request: captureAny(named: 'request'),
        ),
      ).captured;

      final request = captured.first as CreateChatCompletionRequest;
      expect(request.temperature, isNull);
    });

    test('generateWithMessages accepts null temperature parameter', () {
      final provider = AiConfigInferenceProvider(
        id: 'test-provider',
        name: 'Test',
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'test-key',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.genericOpenAi,
      );

      when(
        () => mockClient.createChatCompletionStream(
          request: any(named: 'request'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable([
          CreateChatCompletionStreamResponse(
            id: 'response-id',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(
                  content: 'Test response',
                ),
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        ]),
      );

      // Act - pass null temperature
      // Note: generateWithMessages doesn't have overrideClient, so we test
      // that null temperature is accepted by the method signature
      final stream = repository.generateWithMessages(
        messages: const [
          ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string('Hello'),
          ),
        ],
        model: 'gpt-5-nano',
        temperature: null,
        provider: provider,
      );

      // Verify stream is created (actual API call would fail without mock,
      // but this tests the null temperature parameter is accepted)
      expect(stream, isA<Stream<CreateChatCompletionStreamResponse>>());
    });
  });

  group('CloudInferenceRepository - Temperature handling by provider', () {
    late ProviderContainer container;
    late CloudInferenceRepository repository;
    late MockHttpClient mockHttpClient;

    setUp(() {
      mockHttpClient = MockHttpClient();
      final mockOllamaRepo = MockOllamaInferenceRepository();
      final mockGeminiRepo = MockGeminiInferenceRepository();

      container = ProviderContainer(
        overrides: [
          ollamaInferenceRepositoryProvider.overrideWithValue(mockOllamaRepo),
          geminiInferenceRepositoryProvider.overrideWithValue(mockGeminiRepo),
        ],
      );

      final ref = container.read(testRefProvider);
      repository = CloudInferenceRepository(ref, httpClient: mockHttpClient);
    });

    tearDown(() {
      mockHttpClient.close();
      container.dispose();
    });

    test('generateWithMessages accepts temperature for OpenAI provider', () {
      final openAiProvider = AiConfigInferenceProvider(
        id: 'openai-provider',
        name: 'OpenAI',
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'test-key',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.openAi,
      );

      // Temperature handling for OpenAI is done at the caller level
      // (conversation_repository or unified_ai_inference_repository)
      final stream = repository.generateWithMessages(
        messages: const [
          ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string('Hello'),
          ),
        ],
        model: 'gpt-5.2',
        temperature: 1, // OpenAI GPT-5 only accepts 1.0
        provider: openAiProvider,
      );

      expect(stream, isA<Stream<CreateChatCompletionStreamResponse>>());
      expect(stream.isBroadcast, isTrue);
    });

    test('generateWithMessages accepts temperature for genericOpenAi provider',
        () {
      final genericProvider = AiConfigInferenceProvider(
        id: 'generic-provider',
        name: 'Generic OpenAI Compatible',
        baseUrl: 'https://example.com/v1',
        apiKey: 'test-key',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.genericOpenAi,
      );

      final stream = repository.generateWithMessages(
        messages: const [
          ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string('Hello'),
          ),
        ],
        model: 'custom-model',
        temperature: 0.7,
        provider: genericProvider,
      );

      expect(stream, isA<Stream<CreateChatCompletionStreamResponse>>());
      expect(stream.isBroadcast, isTrue);
    });

    test('generateWithMessages accepts temperature for Anthropic provider', () {
      final anthropicProvider = AiConfigInferenceProvider(
        id: 'anthropic-provider',
        name: 'Anthropic',
        baseUrl: 'https://api.anthropic.com/v1',
        apiKey: 'test-key',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.anthropic,
      );

      final stream = repository.generateWithMessages(
        messages: const [
          ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string('Hello'),
          ),
        ],
        model: 'claude-opus-4',
        temperature: 0.5,
        provider: anthropicProvider,
      );

      expect(stream, isA<Stream<CreateChatCompletionStreamResponse>>());
      expect(stream.isBroadcast, isTrue);
    });

    group('generateWithAudio with OpenAI transcription models', () {
      test('routes gpt-4o-mini-transcribe to OpenAI transcription endpoint',
          () async {
        // Arrange
        final openAiProvider = AiConfigInferenceProvider(
          id: 'openai-provider',
          name: 'OpenAI',
          baseUrl: 'https://api.openai.com/v1',
          apiKey: 'test-key',
          createdAt: DateTime(2024),
          inferenceProviderType: InferenceProviderType.openAi,
        );

        // Mock successful transcription response
        when(() => mockHttpClient.send(any())).thenAnswer((_) async {
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode({'text': 'Transcribed text'}))),
            200,
          );
        });

        final stream = repository.generateWithAudio(
          'Transcribe this audio',
          model: 'gpt-4o-mini-transcribe',
          audioBase64: 'dGVzdC1hdWRpby1kYXRh',
          baseUrl: 'https://api.openai.com/v1',
          apiKey: 'test-key',
          provider: openAiProvider,
        );

        final response = await stream.first;

        // Assert - verify it went through OpenAI transcription endpoint
        expect(
            response.choices?.first.delta?.content, equals('Transcribed text'));

        // Verify the request was sent to the transcription endpoint
        final captured =
            verify(() => mockHttpClient.send(captureAny())).captured;
        expect(captured, hasLength(1));
        final request = captured.first as http.MultipartRequest;
        expect(request.url.toString(),
            equals('https://api.openai.com/v1/audio/transcriptions'));
        expect(request.fields['model'], equals('gpt-4o-mini-transcribe'));
      });

      test('routes gpt-4o-transcribe to OpenAI transcription endpoint',
          () async {
        // Arrange
        final openAiProvider = AiConfigInferenceProvider(
          id: 'openai-provider',
          name: 'OpenAI',
          baseUrl: 'https://api.openai.com/v1',
          apiKey: 'test-key',
          createdAt: DateTime(2024),
          inferenceProviderType: InferenceProviderType.openAi,
        );

        when(() => mockHttpClient.send(any())).thenAnswer((_) async {
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode({'text': 'Transcribed text'}))),
            200,
          );
        });

        final stream = repository.generateWithAudio(
          'Transcribe this audio',
          model: 'gpt-4o-transcribe',
          audioBase64: 'dGVzdC1hdWRpby1kYXRh',
          baseUrl: 'https://api.openai.com/v1',
          apiKey: 'test-key',
          provider: openAiProvider,
        );

        final response = await stream.first;
        expect(
            response.choices?.first.delta?.content, equals('Transcribed text'));

        final captured =
            verify(() => mockHttpClient.send(captureAny())).captured;
        final request = captured.first as http.MultipartRequest;
        expect(request.fields['model'], equals('gpt-4o-transcribe'));
      });

      test('routes gpt-4o-transcribe-diarize to OpenAI transcription endpoint',
          () async {
        final openAiProvider = AiConfigInferenceProvider(
          id: 'openai-provider',
          name: 'OpenAI',
          baseUrl: 'https://api.openai.com/v1',
          apiKey: 'test-key',
          createdAt: DateTime(2024),
          inferenceProviderType: InferenceProviderType.openAi,
        );

        when(() => mockHttpClient.send(any())).thenAnswer((_) async {
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode({'text': 'Speaker 1: Hello'}))),
            200,
          );
        });

        final stream = repository.generateWithAudio(
          'Transcribe with diarization',
          model: 'gpt-4o-transcribe-diarize',
          audioBase64: 'dGVzdC1hdWRpby1kYXRh',
          baseUrl: 'https://api.openai.com/v1',
          apiKey: 'test-key',
          provider: openAiProvider,
        );

        final response = await stream.first;
        expect(
            response.choices?.first.delta?.content, equals('Speaker 1: Hello'));

        final captured =
            verify(() => mockHttpClient.send(captureAny())).captured;
        final request = captured.first as http.MultipartRequest;
        expect(request.fields['model'], equals('gpt-4o-transcribe-diarize'));
      });

      test(
          'routes snapshot alias gpt-4o-mini-transcribe-2025-01-15 to OpenAI transcription endpoint',
          () async {
        final openAiProvider = AiConfigInferenceProvider(
          id: 'openai-provider',
          name: 'OpenAI',
          baseUrl: 'https://api.openai.com/v1',
          apiKey: 'test-key',
          createdAt: DateTime(2024),
          inferenceProviderType: InferenceProviderType.openAi,
        );

        when(() => mockHttpClient.send(any())).thenAnswer((_) async {
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode({'text': 'Transcribed'}))),
            200,
          );
        });

        final stream = repository.generateWithAudio(
          'Transcribe',
          model: 'gpt-4o-mini-transcribe-2025-01-15',
          audioBase64: 'dGVzdC1hdWRpby1kYXRh',
          baseUrl: 'https://api.openai.com/v1',
          apiKey: 'test-key',
          provider: openAiProvider,
        );

        final response = await stream.first;
        expect(response.choices?.first.delta?.content, equals('Transcribed'));

        final captured =
            verify(() => mockHttpClient.send(captureAny())).captured;
        final request = captured.first as http.MultipartRequest;
        expect(request.fields['model'],
            equals('gpt-4o-mini-transcribe-2025-01-15'));
      });

      test(
          'does not route non-OpenAI provider to OpenAI transcription endpoint',
          () async {
        // Arrange - use genericOpenAi provider with same model name
        final genericProvider = AiConfigInferenceProvider(
          id: 'generic-provider',
          name: 'Generic',
          baseUrl: 'https://example.com/v1',
          apiKey: 'test-key',
          createdAt: DateTime(2024),
          inferenceProviderType: InferenceProviderType.genericOpenAi,
        );

        // This should NOT go to OpenAI transcription endpoint
        // because the provider type is genericOpenAi, not openAi
        final stream = repository.generateWithAudio(
          'Transcribe',
          model: 'gpt-4o-mini-transcribe',
          audioBase64: 'dGVzdC1hdWRpby1kYXRh',
          baseUrl: 'https://example.com/v1',
          apiKey: 'test-key',
          provider: genericProvider,
        );

        // The stream should be created (even though it won't work in practice)
        // It should NOT have sent to OpenAI's transcription endpoint
        expect(stream, isA<Stream<CreateChatCompletionStreamResponse>>());
      });
    });

    group('generateWithAudio with Mistral transcription models', () {
      test('routes voxtral-mini-latest to Mistral transcription endpoint',
          () async {
        final mistralProvider = AiConfigInferenceProvider(
          id: 'mistral-provider',
          name: 'Mistral',
          baseUrl: 'https://api.mistral.ai/v1',
          apiKey: 'test-key',
          createdAt: DateTime(2024),
          inferenceProviderType: InferenceProviderType.mistral,
        );

        when(() => mockHttpClient.send(any())).thenAnswer((_) async {
          return http.StreamedResponse(
            Stream.value(
              utf8.encode(jsonEncode({'text': 'Mistral transcribed text'})),
            ),
            200,
          );
        });

        final stream = repository.generateWithAudio(
          'Transcribe this audio',
          model: 'voxtral-mini-latest',
          audioBase64: 'dGVzdC1hdWRpby1kYXRh',
          baseUrl: 'https://api.mistral.ai/v1',
          apiKey: 'test-key',
          provider: mistralProvider,
        );

        final response = await stream.first;

        expect(response.choices?.first.delta?.content,
            equals('Mistral transcribed text'));

        final captured =
            verify(() => mockHttpClient.send(captureAny())).captured;
        expect(captured, hasLength(1));
        final request = captured.first as http.MultipartRequest;
        expect(
          request.url.toString(),
          equals('https://api.mistral.ai/v1/audio/transcriptions'),
        );
        expect(request.fields['model'], equals('voxtral-mini-latest'));
      });

      test('routes voxtral-small-2507 to Mistral transcription endpoint',
          () async {
        final mistralProvider = AiConfigInferenceProvider(
          id: 'mistral-provider',
          name: 'Mistral',
          baseUrl: 'https://api.mistral.ai/v1',
          apiKey: 'test-key',
          createdAt: DateTime(2024),
          inferenceProviderType: InferenceProviderType.mistral,
        );

        when(() => mockHttpClient.send(any())).thenAnswer((_) async {
          return http.StreamedResponse(
            Stream.value(
              utf8.encode(jsonEncode({'text': 'Legacy model transcription'})),
            ),
            200,
          );
        });

        final stream = repository.generateWithAudio(
          'Transcribe',
          model: 'voxtral-small-2507',
          audioBase64: 'dGVzdC1hdWRpby1kYXRh',
          baseUrl: 'https://api.mistral.ai/v1',
          apiKey: 'test-key',
          provider: mistralProvider,
        );

        final response = await stream.first;
        expect(response.choices?.first.delta?.content,
            equals('Legacy model transcription'));
      });

      test(
          'does not route non-Mistral provider to Mistral transcription endpoint',
          () {
        final genericProvider = AiConfigInferenceProvider(
          id: 'generic-provider',
          name: 'Generic',
          baseUrl: 'https://example.com/v1',
          apiKey: 'test-key',
          createdAt: DateTime(2024),
          inferenceProviderType: InferenceProviderType.genericOpenAi,
        );

        final stream = repository.generateWithAudio(
          'Transcribe',
          model: 'voxtral-mini-latest',
          audioBase64: 'dGVzdC1hdWRpby1kYXRh',
          baseUrl: 'https://example.com/v1',
          apiKey: 'test-key',
          provider: genericProvider,
        );

        // Should NOT route to Mistral transcription
        expect(stream, isA<Stream<CreateChatCompletionStreamResponse>>());
      });

      test('does not route non-voxtral Mistral model to transcription endpoint',
          () {
        final mistralProvider = AiConfigInferenceProvider(
          id: 'mistral-provider',
          name: 'Mistral',
          baseUrl: 'https://api.mistral.ai/v1',
          apiKey: 'test-key',
          createdAt: DateTime(2024),
          inferenceProviderType: InferenceProviderType.mistral,
        );

        final stream = repository.generateWithAudio(
          'Test',
          model: 'mistral-large',
          audioBase64: 'dGVzdC1hdWRpby1kYXRh',
          baseUrl: 'https://api.mistral.ai/v1',
          apiKey: 'test-key',
          provider: mistralProvider,
        );

        // Non-voxtral model should use chat completions fallback
        expect(stream, isA<Stream<CreateChatCompletionStreamResponse>>());
      });
    });
  });

  group('CloudInferenceRepository - generateWithAudio audioFormat parameter',
      () {
    late MockOpenAIClient mockClient;
    late MockHttpClient mockHttpClient;
    late ProviderContainer container;
    late CloudInferenceRepository repository;

    setUp(() {
      mockClient = MockOpenAIClient();
      mockHttpClient = MockHttpClient();
      final mockOllamaRepo = MockOllamaInferenceRepository();
      final mockGeminiRepo = MockGeminiInferenceRepository();

      container = ProviderContainer(
        overrides: [
          ollamaInferenceRepositoryProvider.overrideWithValue(mockOllamaRepo),
          geminiInferenceRepositoryProvider.overrideWithValue(mockGeminiRepo),
        ],
      );

      final ref = container.read(testRefProvider);
      repository = CloudInferenceRepository(ref, httpClient: mockHttpClient);
    });

    tearDown(() async {
      mockHttpClient.close();
      container.dispose();
    });

    test('OpenAI provider uses passed wav audioFormat for chat completions',
        () {
      // Arrange - non-transcription model uses chat completions path
      final openAiProvider = AiConfigInferenceProvider(
        id: 'openai-provider',
        name: 'OpenAI',
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'test-key',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.openAi,
      );

      when(
        () => mockClient.createChatCompletionStream(
          request: any(named: 'request'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable([
          CreateChatCompletionStreamResponse(
            id: 'response-id',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(
                  content: 'Test response',
                ),
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        ]),
      );

      // Act - use non-transcription model with wav format
      repository.generateWithAudio(
        'Test prompt',
        model: 'gpt-4o-audio-preview', // Not a transcription model
        audioBase64: 'test-audio-base64',
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'test-key',
        provider: openAiProvider,
        overrideClient: mockClient,
        audioFormat: ChatCompletionMessageInputAudioFormat.wav,
      );

      // Assert
      final captured = verify(
        () => mockClient.createChatCompletionStream(
          request: captureAny(named: 'request'),
        ),
      ).captured;

      final request = captured.first as CreateChatCompletionRequest;
      final requestString = request.toString();
      // Check for format: wav in the audio input configuration
      expect(requestString,
          contains('format: ChatCompletionMessageInputAudioFormat.wav'));
    });

    test('OpenAI provider uses passed mp3 audioFormat for chat completions',
        () {
      // Arrange
      final openAiProvider = AiConfigInferenceProvider(
        id: 'openai-provider',
        name: 'OpenAI',
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'test-key',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.openAi,
      );

      when(
        () => mockClient.createChatCompletionStream(
          request: any(named: 'request'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable([
          CreateChatCompletionStreamResponse(
            id: 'response-id',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(
                  content: 'Test response',
                ),
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        ]),
      );

      // Act - use non-transcription model with mp3 format (default)
      repository.generateWithAudio(
        'Test prompt',
        model: 'gpt-4o-audio-preview',
        audioBase64: 'test-audio-base64',
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'test-key',
        provider: openAiProvider,
        overrideClient: mockClient,
      );

      // Assert
      final captured = verify(
        () => mockClient.createChatCompletionStream(
          request: captureAny(named: 'request'),
        ),
      ).captured;

      final request = captured.first as CreateChatCompletionRequest;
      final requestString = request.toString();
      // Check for format: mp3 in the audio input configuration
      expect(requestString,
          contains('format: ChatCompletionMessageInputAudioFormat.mp3'));
    });

    test('Mistral provider uses passed audioFormat for chat completions', () {
      // Arrange
      final mistralProvider = AiConfigInferenceProvider(
        id: 'mistral-provider',
        name: 'Mistral',
        baseUrl: 'https://api.mistral.ai/v1',
        apiKey: 'test-key',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.mistral,
      );

      when(
        () => mockClient.createChatCompletionStream(
          request: any(named: 'request'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable([
          CreateChatCompletionStreamResponse(
            id: 'response-id',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(
                  content: 'Test response',
                ),
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        ]),
      );

      // Act - use wav format for Mistral
      repository.generateWithAudio(
        'Test prompt',
        model: 'mistral-large',
        audioBase64: 'test-audio-base64',
        baseUrl: 'https://api.mistral.ai/v1',
        apiKey: 'test-key',
        provider: mistralProvider,
        overrideClient: mockClient,
        audioFormat: ChatCompletionMessageInputAudioFormat.wav,
      );

      // Assert
      final captured = verify(
        () => mockClient.createChatCompletionStream(
          request: captureAny(named: 'request'),
        ),
      ).captured;

      final request = captured.first as CreateChatCompletionRequest;
      final requestString = request.toString();
      // Check for format: wav in the audio input configuration
      expect(requestString,
          contains('format: ChatCompletionMessageInputAudioFormat.wav'));
    });

    test('generic provider uses passed audioFormat parameter', () {
      // Arrange
      final genericProvider = AiConfigInferenceProvider(
        id: 'generic-provider',
        name: 'Generic',
        baseUrl: 'https://api.example.com/v1',
        apiKey: 'test-key',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.genericOpenAi,
      );

      when(
        () => mockClient.createChatCompletionStream(
          request: any(named: 'request'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable([
          CreateChatCompletionStreamResponse(
            id: 'response-id',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(
                  content: 'Test response',
                ),
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        ]),
      );

      // Act - explicitly pass wav audioFormat
      repository.generateWithAudio(
        'Test prompt',
        model: 'some-model',
        audioBase64: 'test-audio-base64',
        baseUrl: 'https://api.example.com/v1',
        apiKey: 'test-key',
        provider: genericProvider,
        overrideClient: mockClient,
        audioFormat: ChatCompletionMessageInputAudioFormat.wav,
      );

      // Assert - should use the passed audioFormat (wav)
      final captured = verify(
        () => mockClient.createChatCompletionStream(
          request: captureAny(named: 'request'),
        ),
      ).captured;

      final request = captured.first as CreateChatCompletionRequest;
      final requestString = request.toString();
      expect(requestString,
          contains('format: ChatCompletionMessageInputAudioFormat.wav'));
    });
  });
}
