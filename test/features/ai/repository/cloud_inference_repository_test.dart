import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

class MockOpenAIClient extends Mock implements OpenAIClient {}

class MockHttpClient extends Mock implements http.Client {}

class MockRef extends Mock implements Ref<Object?> {}

// We need to register fallback values for complex types that will be used with 'any()' matcher
class FakeCreateChatCompletionRequest extends Fake
    implements CreateChatCompletionRequest {}

void main() {
  setUp(() {
    // This needs to be called before each test to register the fallback value
    registerFallbackValue(FakeCreateChatCompletionRequest());
    registerFallbackValue(Uri.parse('http://example.com'));
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
      container = ProviderContainer();
      repository =
          CloudInferenceRepository(MockRef(), httpClient: mockHttpClient);
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
      expect(responses[0].choices[0].delta?.content, 'Valid response');
      expect(responses[1].choices[0].delta?.content, 'Another valid response');
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
      expect(responses[0].choices[0].delta?.content, 'Test');
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
      expect(responses[0].choices[0].delta?.content, 'Test');
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
      expect(responses[0].choices[0].delta?.content, 'Test response');
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
      expect(response.choices.length, 1);
      expect(response.choices[0].delta?.content, transcribedText);
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
        throwsException, // WhisperTranscriptionException wraps the FormatException
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
        throwsException, // WhisperTranscriptionException is thrown instead of TypeError
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
      expect(response.choices[0].delta?.content, transcribedText);
    });

    test('constructor with custom httpClient parameter', () {
      final customHttpClient = MockHttpClient();
      final customRepository = CloudInferenceRepository(
        MockRef(),
        httpClient: customHttpClient,
      );

      expect(customRepository, isA<CloudInferenceRepository>());
      expect(customRepository.ref, isA<Ref>());
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
      expect(response.choices[0].index, equals(0));
      expect(response.choices[0].delta?.content, equals(transcribedText));
      expect(response.choices[0].delta?.role, isNull);
    });
  });
}
