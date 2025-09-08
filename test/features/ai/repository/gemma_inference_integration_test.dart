import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/gemma_inference_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockHttpClient extends Mock implements http.Client {}

class MockStreamedResponse extends Mock implements http.StreamedResponse {}

class FakeUri extends Fake implements Uri {}

class FakeRequest extends Fake implements http.Request {}

void main() {
  group('GemmaInferenceRepository Integration Tests', () {
    late GemmaInferenceRepository repository;
    late MockHttpClient mockHttpClient;

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

    group('Service Health Check Integration', () {
      test('detects when Gemma service is running', () async {
        // Arrange - Mock successful models endpoint response
        when(() => mockHttpClient.get(
              Uri.parse('$baseUrl/v1/models'),
            )).thenAnswer((_) async => http.Response(
              jsonEncode({
                'data': [
                  {
                    'id': 'google/gemma-2b-it',
                    'object': 'model',
                    'created': 1234567890,
                  },
                  {
                    'id': 'google/gemma-3n-E2B-it',
                    'object': 'model',
                    'created': 1234567890,
                  }
                ]
              }),
              200,
            ));

        // Act
        final isAvailable = await repository.isModelAvailable(baseUrl);

        // Assert
        expect(isAvailable, isTrue);
        verify(() => mockHttpClient.get(Uri.parse('$baseUrl/v1/models')))
            .called(1);
      });

      test('detects when Gemma service is not running', () async {
        // Arrange - Mock connection refused
        when(() => mockHttpClient.get(any()))
            .thenThrow(const SocketException('Connection refused'));

        // Act
        final isAvailable = await repository.isModelAvailable(baseUrl);

        // Assert
        expect(isAvailable, isFalse);
      });

      test('detects when service is running but no models loaded', () async {
        // Arrange - Empty models list
        when(() => mockHttpClient.get(
              Uri.parse('$baseUrl/v1/models'),
            )).thenAnswer((_) async => http.Response(
              jsonEncode({'data': <dynamic>[]}),
              200,
            ));

        // Act
        final isAvailable = await repository.isModelAvailable(baseUrl);

        // Assert
        expect(isAvailable, isFalse);
      });
    });

    group('Model Name Aliasing Integration', () {
      test('handles model name aliasing from Flutter to service', () async {
        // Arrange - Test that service handles both model name formats
        final streamController = StreamController<List<int>>.broadcast();
        final mockResponse = MockStreamedResponse();

        when(() => mockResponse.statusCode).thenReturn(200);
        when(() => mockResponse.stream)
            .thenAnswer((_) => http.ByteStream(streamController.stream));

        when(() => mockHttpClient.send(any())).thenAnswer((_) async {
          Timer.run(() {
            streamController
              ..add(
                  utf8.encode('data: {"text": "Transcribed successfully"}\n'))
              ..add(utf8.encode('data: [DONE]\n'))
              ..close();
          });
          return mockResponse;
        });

        // Act - Use the Flutter model name (as configured in known_models.dart)
        const flutterModelName = 'google/gemma-2b-it';
        final stream = repository.transcribeAudio(
          audioBase64: audioBase64,
          model: flutterModelName,
          temperature: temperature,
          provider: testProvider,
        );

        final response = await stream.first.timeout(const Duration(seconds: 5));

        // Assert
        expect(response.choices?[0].delta?.content,
            equals('Transcribed successfully'));

        // Verify the request was made with the correct model name
        final capturedRequest = verify(() => mockHttpClient.send(captureAny()))
            .captured
            .first as http.Request;
        final requestBody =
            jsonDecode(capturedRequest.body) as Map<String, dynamic>;
        expect(requestBody['model'], equals(flutterModelName));
      });

      test('handles alternative model names correctly', () async {
        // Arrange
        final streamController = StreamController<List<int>>.broadcast();
        final mockResponse = MockStreamedResponse();

        when(() => mockResponse.statusCode).thenReturn(200);
        when(() => mockResponse.stream)
            .thenAnswer((_) => http.ByteStream(streamController.stream));

        when(() => mockHttpClient.send(any())).thenAnswer((_) async {
          Timer.run(() {
            streamController
              ..add(
                  utf8.encode('data: {"text": "Alternative model response"}\n'))
              ..add(utf8.encode('data: [DONE]\n'))
              ..close();
          });
          return mockResponse;
        });

        // Act - Test with different model variant
        const alternativeModel = 'google/gemma-3n-E2B-it';
        final stream = repository.transcribeAudio(
          audioBase64: audioBase64,
          model: alternativeModel,
          temperature: temperature,
          provider: testProvider,
        );

        final response = await stream.first.timeout(const Duration(seconds: 5));

        // Assert
        expect(response.choices?[0].delta?.content,
            equals('Alternative model response'));
      });
    });

    group('Audio Transcription Integration Flow', () {
      test('completes full transcription workflow with context', () async {
        // Arrange - Mock complete transcription flow
        final streamController = StreamController<List<int>>.broadcast();
        final mockResponse = MockStreamedResponse();

        when(() => mockResponse.statusCode).thenReturn(200);
        when(() => mockResponse.stream)
            .thenAnswer((_) => http.ByteStream(streamController.stream));

        when(() => mockHttpClient.send(any())).thenAnswer((_) async {
          Timer.run(() async {
            // Simulate chunked streaming response with small delays
            streamController.add(
                utf8.encode('data: {"text": "This is the first part "}\n'));
            await Future<void>.delayed(const Duration(milliseconds: 5));
            streamController.add(
                utf8.encode('data: {"text": "of the transcribed audio "}\n'));
            await Future<void>.delayed(const Duration(milliseconds: 5));
            streamController.add(utf8
                .encode('data: {"text": "with context about the meeting."}\n'));
            await Future<void>.delayed(const Duration(milliseconds: 5));
            streamController.add(utf8.encode('data: [DONE]\n'));
            await streamController.close();
          });
          return mockResponse;
        });

        // Act
        const contextPrompt = 'This is a meeting about project planning';
        const language = 'en';
        final stream = repository.transcribeAudio(
          audioBase64: audioBase64,
          model: model,
          temperature: temperature,
          provider: testProvider,
          contextPrompt: contextPrompt,
          language: language,
        );

        final responses =
            await stream.take(3).toList().timeout(const Duration(seconds: 5));

        // Assert
        expect(responses, hasLength(3)); // Three text chunks
        expect(responses[0].choices?[0].delta?.content,
            equals('This is the first part '));
        expect(responses[1].choices?[0].delta?.content,
            equals('of the transcribed audio '));
        expect(responses[2].choices?[0].delta?.content,
            equals('with context about the meeting.'));

        // Verify request includes context parameters
        final capturedRequest = verify(() => mockHttpClient.send(captureAny()))
            .captured
            .first as http.Request;
        final requestBody =
            jsonDecode(capturedRequest.body) as Map<String, dynamic>;
        expect(requestBody['prompt'], equals(contextPrompt));
        expect(requestBody['language'], equals(language));
        expect(requestBody['stream'], isTrue);
        expect(requestBody['response_format'], equals('json'));
      });

      test('handles service errors gracefully during transcription', () async {
        // Arrange - Mock service error scenarios
        final streamController = StreamController<List<int>>.broadcast();
        final mockResponse = MockStreamedResponse();

        when(() => mockResponse.statusCode).thenReturn(500);
        when(() => mockResponse.stream)
            .thenAnswer((_) => http.ByteStream(streamController.stream));

        when(() => mockHttpClient.send(any())).thenAnswer((_) async {
          Timer.run(() {
            streamController
              ..add(utf8.encode('{"error": "Model failed to load"}'))
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
          throwsA(
            predicate((e) =>
                e is Exception &&
                e
                    .toString()
                    .contains('Gemma transcription failed with status 500')),
          ),
        );
      });

      test('handles model not installed scenario', () async {
        // Arrange - Mock model not installed response
        final streamController = StreamController<List<int>>.broadcast();
        final mockResponse = MockStreamedResponse();

        when(() => mockResponse.statusCode).thenReturn(404);
        when(() => mockResponse.stream)
            .thenAnswer((_) => http.ByteStream(streamController.stream));

        when(() => mockHttpClient.send(any())).thenAnswer((_) async {
          Timer.run(() {
            streamController
              ..add(utf8.encode('Model google/gemma-2b-it is not downloaded'))
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
          throwsA(isA<ModelNotInstalledException>()
              .having((e) => e.modelName, 'model name', model)),
        );
      });
    });

    group('Model Management Integration', () {
      test('installs model with progress tracking', () async {
        // Arrange - Mock model installation progress
        final streamController = StreamController<List<int>>.broadcast();
        final mockResponse = MockStreamedResponse();

        when(() => mockResponse.statusCode).thenReturn(200);
        when(() => mockResponse.stream)
            .thenAnswer((_) => http.ByteStream(streamController.stream));

        when(() => mockHttpClient.send(any())).thenAnswer((_) async {
          Timer.run(() async {
            streamController.add(utf8.encode(
                'data: {"status": "downloading", "total": 10000000, "completed": 1000000, "progress": 0.1}\n'));
            await Future<void>.delayed(const Duration(milliseconds: 10));
            streamController.add(utf8.encode(
                'data: {"status": "downloading", "total": 10000000, "completed": 5000000, "progress": 0.5}\n'));
            await Future<void>.delayed(const Duration(milliseconds: 10));
            streamController.add(utf8.encode(
                'data: {"status": "extracting", "total": 10000000, "completed": 8000000, "progress": 0.8}\n'));
            await Future<void>.delayed(const Duration(milliseconds: 10));
            streamController.add(utf8.encode(
                'data: {"status": "complete", "total": 10000000, "completed": 10000000, "progress": 1.0}\n'));
            await Future<void>.delayed(const Duration(milliseconds: 10));
            streamController.add(utf8.encode('data: [DONE]\n'));
            await streamController.close();
          });
          return mockResponse;
        });

        // Act
        final progressStream = repository.installModel(model, baseUrl);
        final progressList = await progressStream
            .take(4)
            .toList()
            .timeout(const Duration(seconds: 5));

        // Assert
        expect(progressList, hasLength(4));
        expect(progressList[0].status, equals('downloading'));
        expect(progressList[0].progress, equals(0.1));
        expect(progressList[1].progress, equals(0.5));
        expect(progressList[2].status, equals('extracting'));
        expect(progressList[3].status, equals('complete'));
        expect(progressList[3].progress, equals(1.0));

        // Verify installation request
        final capturedRequest = verify(() => mockHttpClient.send(captureAny()))
            .captured
            .first as http.Request;
        expect(capturedRequest.url.path, equals('/v1/models/pull'));
        final requestBody =
            jsonDecode(capturedRequest.body) as Map<String, dynamic>;
        expect(requestBody['model_name'], equals(model));
        expect(requestBody['stream'], isTrue);
      });

      test('warms up model successfully', () async {
        // Arrange
        when(() => mockHttpClient.post(
                  Uri.parse('$baseUrl/v1/models/load'),
                  headers: {'Content-Type': 'application/json'},
                ))
            .thenAnswer(
                (_) async => http.Response('{"status": "loaded"}', 200));

        // Act & Assert - Should complete without throwing
        await repository.warmUpModel(baseUrl);

        verify(() => mockHttpClient.post(
              Uri.parse('$baseUrl/v1/models/load'),
              headers: {'Content-Type': 'application/json'},
            )).called(1);
      });
    });

    group('Chat API Integration', () {
      test('generates text with streaming chat completion', () async {
        // Arrange
        final streamController = StreamController<List<int>>.broadcast();
        final mockResponse = MockStreamedResponse();

        when(() => mockResponse.statusCode).thenReturn(200);
        when(() => mockResponse.stream)
            .thenAnswer((_) => http.ByteStream(streamController.stream));

        when(() => mockHttpClient.send(any())).thenAnswer((_) async {
          Timer.run(() async {
            streamController.add(utf8.encode(
                'data: {"choices": [{"delta": {"content": "Hello! "}}]}\n'));
            await Future<void>.delayed(const Duration(milliseconds: 5));
            streamController.add(utf8.encode(
                'data: {"choices": [{"delta": {"content": "How can I "}}]}\n'));
            await Future<void>.delayed(const Duration(milliseconds: 5));
            streamController.add(utf8.encode(
                'data: {"choices": [{"delta": {"content": "help you today?"}}]}\n'));
            await Future<void>.delayed(const Duration(milliseconds: 5));
            streamController.add(utf8.encode('data: [DONE]\n'));
            await streamController.close();
          });
          return mockResponse;
        });

        // Act
        const prompt = 'Hello, how are you?';
        const systemMessage = 'You are a helpful assistant';
        final stream = repository.generateText(
          prompt: prompt,
          model: model,
          temperature: temperature,
          systemMessage: systemMessage,
          provider: testProvider,
        );

        final responses =
            await stream.take(3).toList().timeout(const Duration(seconds: 5));

        // Assert
        expect(responses, hasLength(3));
        expect(responses[0].choices?[0].delta?.content, equals('Hello! '));
        expect(responses[1].choices?[0].delta?.content, equals('How can I '));
        expect(
            responses[2].choices?[0].delta?.content, equals('help you today?'));

        // Verify chat request structure
        final capturedRequest = verify(() => mockHttpClient.send(captureAny()))
            .captured
            .first as http.Request;
        expect(capturedRequest.url.path, equals('/v1/chat/completions'));
        final requestBody =
            jsonDecode(capturedRequest.body) as Map<String, Object?>;
        final messages = (requestBody['messages'] as List<dynamic>?)!;
        expect(messages, hasLength(2));
        expect((messages[0] as Map<String, dynamic>)['role'], equals('system'));
        expect((messages[1] as Map<String, dynamic>)['role'], equals('user'));
      });
    });

    group('Error Recovery Integration', () {
      test('handles network timeout gracefully', () async {
        // Arrange
        when(() => mockHttpClient.send(any())).thenThrow(
            TimeoutException('Request timeout', const Duration(seconds: 300)));

        // Act & Assert
        final stream = repository.transcribeAudio(
          audioBase64: audioBase64,
          model: model,
          temperature: temperature,
          provider: testProvider,
        );

        await expectLater(
          stream.first,
          throwsA(
            predicate((e) =>
                e is Exception &&
                e.toString().contains('Gemma transcription error')),
          ),
        );
      });

      test('handles malformed streaming response', () async {
        // Arrange - Mock malformed JSON response
        final streamController = StreamController<List<int>>.broadcast();
        final mockResponse = MockStreamedResponse();

        when(() => mockResponse.statusCode).thenReturn(200);
        when(() => mockResponse.stream)
            .thenAnswer((_) => http.ByteStream(streamController.stream));

        when(() => mockHttpClient.send(any())).thenAnswer((_) async {
          Timer.run(() {
            // Mix valid and invalid JSON chunks
            streamController
              ..add(utf8.encode('data: {"text": "Valid response"}\n'))
              ..add(utf8.encode('data: {invalid json}\n'))
              ..add(utf8.encode('data: {"text": "Another valid response"}\n'))
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

        final responses =
            await stream.take(2).toList().timeout(const Duration(seconds: 5));

        // Assert - Should only process valid chunks, skip malformed ones
        expect(responses, hasLength(2));
        expect(
            responses[0].choices?[0].delta?.content, equals('Valid response'));
        expect(responses[1].choices?[0].delta?.content,
            equals('Another valid response'));
      });
    });
  });
}
