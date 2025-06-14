import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

class MockOpenAIClient extends Mock implements OpenAIClient {}

// We need to register fallback values for complex types that will be used with 'any()' matcher
class FakeCreateChatCompletionRequest extends Fake
    implements CreateChatCompletionRequest {}

void main() {
  setUp(() {
    // This needs to be called before each test to register the fallback value
    registerFallbackValue(FakeCreateChatCompletionRequest());
  });

  group('CloudInferenceRepository', () {
    late MockOpenAIClient mockClient;
    late ProviderContainer container;
    late CloudInferenceRepository repository;

    const baseUrl = 'https://api.openai.com/v1';
    const apiKey = 'test-api-key';
    const model = 'gpt-4';
    const temperature = 0.7;
    const prompt = 'Hello, AI!';

    setUp(() {
      mockClient = MockOpenAIClient();
      container = ProviderContainer();
      repository = container.read(cloudInferenceRepositoryProvider);
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
        maxCompletionTokens: maxCompletionTokens,
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
  });
}
