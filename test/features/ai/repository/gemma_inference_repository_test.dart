import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/gemma_inference_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

class MockHttpClient extends Mock implements http.Client {}

class MockStreamedResponse extends Mock implements http.StreamedResponse {}

class FakeUri extends Fake implements Uri {}

class FakeRequest extends Fake implements http.Request {}

void main() {
  late GemmaInferenceRepository repository;
  late MockHttpClient mockHttpClient;

  setUpAll(() {
    registerFallbackValue(FakeUri());
    registerFallbackValue(FakeRequest());
  });

  setUp(() {
    mockHttpClient = MockHttpClient();
    repository = GemmaInferenceRepository(httpClient: mockHttpClient);
  });

  tearDown(() {
    mockHttpClient.close();
  });

  group('GemmaInferenceRepository', () {
    const baseUrl = 'http://localhost:11343';
    const model = 'google/gemma-2b-it';
    const audioBase64 = 'base64-encoded-audio-data';
    const temperature = 0.7;

    final testProvider = AiConfigInferenceProvider(
      id: 'test-gemma',
      name: 'Test Gemma',
      baseUrl: baseUrl,
      apiKey: '',
      inferenceProviderType: InferenceProviderType.gemma,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    group('transcribeAudio', () {
      test('successfully transcribes audio with streaming response', () async {
        // Arrange
        const transcribedText = 'This is the transcribed text from audio.';
        final streamController = StreamController<List<int>>.broadcast();
        final mockResponse = MockStreamedResponse();

        when(() => mockResponse.statusCode).thenReturn(200);
        when(() => mockResponse.stream)
            .thenAnswer((_) => http.ByteStream(streamController.stream));

        when(() => mockHttpClient.send(any())).thenAnswer((_) async {
          // Add data and close immediately to prevent hanging
          Timer.run(() {
            streamController
              ..add(utf8.encode('data: {"text": "$transcribedText"}\n'))
              ..add(utf8.encode('data: [DONE]\n'))
              ..close();
          });
          return mockResponse;
        });

        // Act
        final stream = repository.transcribeAudio(
          audioBase64: audioBase64,
          model: model,
          temperature: temperature,
          provider: testProvider,
        );

        final response = await stream.first.timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw TimeoutException('Test timeout'),
        );

        // Assert
        expect(response.choices, hasLength(1));
        expect(response.choices?[0].delta?.content, equals(transcribedText));
        expect(response.id, startsWith('gemma-'));
        expect(response.object, equals('chat.completion.chunk'));
        expect(response.created, isA<int>());
      });

      test('handles context prompt parameter', () async {
        // Arrange
        const contextPrompt = 'This is about a meeting discussion';
        final streamController = StreamController<List<int>>.broadcast();
        final mockResponse = MockStreamedResponse();

        when(() => mockResponse.statusCode).thenReturn(200);
        when(() => mockResponse.stream)
            .thenAnswer((_) => http.ByteStream(streamController.stream));

        when(() => mockHttpClient.send(any())).thenAnswer((_) async {
          Timer.run(() {
            streamController
              ..add(utf8.encode('data: {"text": "Meeting transcription"}\n'))
              ..add(utf8.encode('data: [DONE]\n'))
              ..close();
          });
          return mockResponse;
        });

        // Act
        final stream = repository.transcribeAudio(
          audioBase64: audioBase64,
          model: model,
          temperature: temperature,
          provider: testProvider,
          contextPrompt: contextPrompt,
          language: 'en',
        );

        await stream.first.timeout(const Duration(seconds: 5));

        // Assert
        final capturedRequest = verify(() => mockHttpClient.send(captureAny()))
            .captured
            .first as http.Request;
        final requestBody =
            jsonDecode(capturedRequest.body) as Map<String, dynamic>;
        expect(requestBody['prompt'], equals(contextPrompt));
        expect(requestBody['language'], equals('en'));
      });

      test('throws ModelNotInstalledException on 404 with model not downloaded',
          () async {
        // Arrange
        final streamController = StreamController<List<int>>.broadcast();
        final mockResponse = MockStreamedResponse();

        when(() => mockResponse.statusCode).thenReturn(404);
        when(() => mockResponse.stream)
            .thenAnswer((_) => http.ByteStream(streamController.stream));

        when(() => mockHttpClient.send(any())).thenAnswer((_) async {
          Timer.run(() {
            streamController
              ..add(utf8.encode('Model not downloaded'))
              ..close();
          });
          return mockResponse;
        });

        // Act & Assert
        final stream = repository.transcribeAudio(
          audioBase64: audioBase64,
          model: model,
          temperature: temperature,
          provider: testProvider,
        );

        await expectLater(
          stream.first.timeout(const Duration(seconds: 5)),
          throwsA(isA<ModelNotInstalledException>()),
        );
      });

      test('throws exception on HTTP error', () async {
        // Arrange
        final streamController = StreamController<List<int>>.broadcast();
        final mockResponse = MockStreamedResponse();

        when(() => mockResponse.statusCode).thenReturn(500);
        when(() => mockResponse.stream)
            .thenAnswer((_) => http.ByteStream(streamController.stream));

        when(() => mockHttpClient.send(any())).thenAnswer((_) async {
          Timer.run(() {
            streamController
              ..add(utf8.encode('Internal server error'))
              ..close();
          });
          return mockResponse;
        });

        // Act & Assert
        final stream = repository.transcribeAudio(
          audioBase64: audioBase64,
          model: model,
          temperature: temperature,
          provider: testProvider,
        );

        await expectLater(
          stream.first.timeout(const Duration(seconds: 5)),
          throwsA(isA<Exception>()),
        );
      });

      test('handles timeout correctly', () async {
        // Arrange
        when(() => mockHttpClient.send(any())).thenThrow(
          TimeoutException('Request timed out', const Duration(seconds: 300)),
        );

        // Act & Assert
        final stream = repository.transcribeAudio(
          audioBase64: audioBase64,
          model: model,
          temperature: temperature,
          provider: testProvider,
        );

        await expectLater(
          stream.first,
          throwsA(isA<Exception>()),
        );
      });
    });

    group('generateText', () {
      test('successfully generates text with chat API', () async {
        // Arrange
        const prompt = 'Hello, how are you?';
        const responseText = 'I am doing well, thank you!';
        final streamController = StreamController<List<int>>.broadcast();
        final mockResponse = MockStreamedResponse();

        when(() => mockResponse.statusCode).thenReturn(200);
        when(() => mockResponse.stream)
            .thenAnswer((_) => http.ByteStream(streamController.stream));

        when(() => mockHttpClient.send(any())).thenAnswer((_) async {
          Timer.run(() {
            streamController
              ..add(utf8.encode(
                  'data: {"choices": [{"delta": {"content": "$responseText"}}]}\n'))
              ..add(utf8.encode('data: [DONE]\n'))
              ..close();
          });
          return mockResponse;
        });

        // Act
        final stream = repository.generateText(
          prompt: prompt,
          model: model,
          temperature: temperature,
          systemMessage: null,
          provider: testProvider,
        );

        final response = await stream.first.timeout(const Duration(seconds: 5));

        // Assert
        expect(response.choices, hasLength(1));
        expect(response.choices?[0].delta?.content, equals(responseText));

        // Verify HTTP call was made to chat endpoint
        final capturedRequest = verify(() => mockHttpClient.send(captureAny()))
            .captured
            .first as http.Request;
        expect(capturedRequest.url.path, equals('/v1/chat/completions'));

        final requestBody =
            jsonDecode(capturedRequest.body) as Map<String, Object?>;
        expect(requestBody['model'], equals(model));
        expect(requestBody['stream'], isTrue);
        final messages = (requestBody['messages'] as List<dynamic>?)!;
        expect(messages, hasLength(1));
        expect((messages[0] as Map<String, dynamic>)['content'], equals(prompt));
      });

      test('includes system message when provided', () async {
        // Arrange
        const prompt = 'Hello';
        const systemMessage = 'You are a helpful assistant';
        final streamController = StreamController<List<int>>.broadcast();
        final mockResponse = MockStreamedResponse();

        when(() => mockResponse.statusCode).thenReturn(200);
        when(() => mockResponse.stream)
            .thenAnswer((_) => http.ByteStream(streamController.stream));

        when(() => mockHttpClient.send(any())).thenAnswer((_) async {
          Timer.run(() {
            streamController
              ..add(utf8.encode(
                  'data: {"choices": [{"delta": {"content": "Hello!"}}]}\n'))
              ..add(utf8.encode('data: [DONE]\n'))
              ..close();
          });
          return mockResponse;
        });

        // Act
        final stream = repository.generateText(
          prompt: prompt,
          model: model,
          temperature: temperature,
          systemMessage: systemMessage,
          provider: testProvider,
        );

        await stream.first.timeout(const Duration(seconds: 5));

        // Assert
        final capturedRequest = verify(() => mockHttpClient.send(captureAny()))
            .captured
            .first as http.Request;
        final requestBody =
            jsonDecode(capturedRequest.body) as Map<String, Object?>;
        final messages = (requestBody['messages'] as List<dynamic>?)!;
        expect(messages, hasLength(2));
        expect((messages[0] as Map<String, dynamic>)['role'], equals('system'));
        expect((messages[0] as Map<String, dynamic>)['content'], equals(systemMessage));
        expect((messages[1] as Map<String, dynamic>)['role'], equals('user'));
        expect((messages[1] as Map<String, dynamic>)['content'], equals(prompt));
      });
    });

    group('generateTextWithMessages', () {
      test('converts messages to Gemma format correctly', () async {
        // Arrange
        final messages = <ChatCompletionMessage>[
          const ChatCompletionMessage.system(content: 'You are helpful'),
          const ChatCompletionMessage.user(
              content: ChatCompletionUserMessageContent.string('Hello')),
        ];
        final streamController = StreamController<List<int>>.broadcast();
        final mockResponse = MockStreamedResponse();

        when(() => mockResponse.statusCode).thenReturn(200);
        when(() => mockResponse.stream)
            .thenAnswer((_) => http.ByteStream(streamController.stream));

        when(() => mockHttpClient.send(any())).thenAnswer((_) async {
          Timer.run(() {
            streamController
              ..add(utf8.encode(
                  'data: {"choices": [{"delta": {"content": "Hi there!"}}]}\n'))
              ..add(utf8.encode('data: [DONE]\n'))
              ..close();
          });
          return mockResponse;
        });

        // Act
        final stream = repository.generateTextWithMessages(
          messages: messages,
          model: model,
          temperature: temperature,
          provider: testProvider,
        );

        await stream.first.timeout(const Duration(seconds: 5));

        // Assert
        final capturedRequest = verify(() => mockHttpClient.send(captureAny()))
            .captured
            .first as http.Request;
        final requestBody =
            jsonDecode(capturedRequest.body) as Map<String, Object?>;
        final capturedMessages = (requestBody['messages'] as List<dynamic>?)!;
        expect(capturedMessages, hasLength(2));
        expect((capturedMessages[0] as Map<String, dynamic>)['role'], equals('system'));
        expect((capturedMessages[1] as Map<String, dynamic>)['role'], equals('user'));
      });
    });

    group('Model Management', () {
      test('isModelAvailable returns true when models exist', () async {
        // Arrange
        when(() => mockHttpClient.get(
              Uri.parse('$baseUrl/v1/models'),
            )).thenAnswer((_) async => http.Response(
              jsonEncode({
                'data': [
                  {'id': model, 'object': 'model'},
                ]
              }),
              200,
            ));

        // Act
        final result = await repository.isModelAvailable(baseUrl);

        // Assert
        expect(result, isTrue);
      });

      test('isModelAvailable returns false on error', () async {
        // Arrange
        when(() => mockHttpClient.get(any()))
            .thenThrow(Exception('Network error'));

        // Act
        final result = await repository.isModelAvailable(baseUrl);

        // Assert
        expect(result, isFalse);
      });

      test('installModel streams progress correctly', () async {
        // Arrange
        final streamController = StreamController<List<int>>.broadcast();
        final mockResponse = MockStreamedResponse();

        when(() => mockResponse.statusCode).thenReturn(200);
        when(() => mockResponse.stream)
            .thenAnswer((_) => http.ByteStream(streamController.stream));

        when(() => mockHttpClient.send(any())).thenAnswer((_) async {
          Timer.run(() async {
            streamController.add(utf8.encode(
                'data: {"status": "downloading", "total": 1000, "completed": 500, "progress": 0.5}\n'));
            await Future<void>.delayed(const Duration(milliseconds: 50));
            streamController.add(utf8.encode(
                'data: {"status": "complete", "total": 1000, "completed": 1000, "progress": 1}\n'));
            await Future<void>.delayed(const Duration(milliseconds: 50));  
            streamController.add(utf8.encode('data: [DONE]\n'));
            await Future<void>.delayed(const Duration(milliseconds: 10));
            await streamController.close();
          });
          return mockResponse;
        });

        // Act
        final progressStream = repository.installModel(model, baseUrl);
        final progressList = await progressStream
            .toList()
            .timeout(const Duration(seconds: 2));

        // Assert - we should get at least one progress event
        expect(progressList, isNotEmpty);
        expect(progressList[0].status, equals('downloading'));
        expect(progressList[0].progress, equals(0.5));
        
        // The test demonstrates that the installModel method can parse and emit 
        // streaming progress events from the mock server response
      });

      test('warmUpModel completes without error', () async {
        // Arrange
        when(() => mockHttpClient.post(
              Uri.parse('$baseUrl/v1/models/load'),
              headers: {'Content-Type': 'application/json'},
            )).thenAnswer((_) async => http.Response('', 200));

        // Act & Assert - Should not throw
        await repository.warmUpModel(baseUrl);

        verify(() => mockHttpClient.post(
              Uri.parse('$baseUrl/v1/models/load'),
              headers: {'Content-Type': 'application/json'},
            )).called(1);
      });

      test('warmUpModel handles timeout gracefully', () async {
        // Arrange
        when(() => mockHttpClient.post(any(), headers: any(named: 'headers')))
            .thenThrow(TimeoutException(
                'Warm-up timed out', const Duration(seconds: 60)));

        // Act & Assert - Should not throw, just log warning
        await repository.warmUpModel(baseUrl);
      });
    });

    group('GemmaPullProgress', () {
      test('calculates progress percentage correctly', () {
        // Arrange
        const progress = GemmaPullProgress(
          status: 'downloading',
          total: 1000,
          completed: 750,
          progress: 0.75,
        );

        // Assert
        expect(progress.progressPercentage, equals('75.0%'));
      });

      test('formats download progress correctly', () {
        // Arrange
        const progress = GemmaPullProgress(
          status: 'downloading',
          total: 1048576, // 1MB in bytes
          completed: 524288, // 0.5MB in bytes
          progress: 0.5,
        );

        // Assert
        expect(progress.downloadProgress, contains('downloading'));
        expect(progress.downloadProgress, contains('0.5 MB / 1.0 MB'));
        expect(progress.downloadProgress, contains('50.0%'));
      });

      test('handles zero total correctly', () {
        // Arrange
        const progress = GemmaPullProgress(
          status: 'initializing',
          total: 0,
          completed: 0,
          progress: 0,
        );

        // Assert
        expect(progress.downloadProgress, equals('initializing'));
      });
    });

    group('ModelNotInstalledException', () {
      test('formats error message correctly', () {
        // Arrange
        const exception = ModelNotInstalledException('google/gemma-2b-it');

        // Assert
        expect(
            exception.toString(),
            equals(
                'Gemma model "google/gemma-2b-it" is not downloaded. Please install it first.'));
      });
    });
  });
}
