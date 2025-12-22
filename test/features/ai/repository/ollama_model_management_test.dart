import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/providers/gemini_inference_repository_provider.dart';
import 'package:lotti/features/ai/providers/ollama_inference_repository_provider.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/gemini_inference_repository.dart';
import 'package:lotti/features/ai/repository/ollama_inference_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../test_utils/retry_fake_time.dart';

class MockHttpClient extends Mock implements http.Client {}

class MockRef extends Mock implements Ref<Object?> {}

// Add this fake for mocktail
class FakeBaseRequest extends Fake implements http.BaseRequest {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeBaseRequest());
    registerFallbackValue(Uri.parse('http://example.com'));
  });

  group('Ollama Model Management', () {
    late MockHttpClient mockHttpClient;
    late ProviderContainer container;
    late CloudInferenceRepository repository;
    late AiConfigInferenceProvider ollamaProvider;

    const baseUrl = 'http://localhost:11434';
    const modelName = 'gemma3:4b';
    const testImage = 'base64-encoded-image-data';

    setUp(() {
      mockHttpClient = MockHttpClient();
      container = ProviderContainer();

      // Create and configure the mock ref
      final mockRef = MockRef();

      // Create a real OllamaInferenceRepository with the mocked HTTP client
      // This allows the tests to verify HTTP calls as originally intended
      final ollamaRepo = OllamaInferenceRepository(httpClient: mockHttpClient);

      // Configure the mock ref to return the OllamaInferenceRepository with mocked HTTP
      when(() => mockRef.read(ollamaInferenceRepositoryProvider))
          .thenReturn(ollamaRepo);
      // Also provide a real GeminiInferenceRepository to satisfy constructor deps
      final geminiRepo = GeminiInferenceRepository(httpClient: mockHttpClient);
      when(() => mockRef.read(geminiInferenceRepositoryProvider))
          .thenReturn(geminiRepo);

      repository =
          CloudInferenceRepository(mockRef, httpClient: mockHttpClient);
      ollamaProvider = AiConfig.inferenceProvider(
        id: 'ollama-provider',
        name: 'Ollama Provider',
        baseUrl: baseUrl,
        apiKey: '',
        // Ollama doesn't use API keys
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.ollama,
      ) as AiConfigInferenceProvider;
    });

    tearDown(() async {
      mockHttpClient.close();
      container.dispose();
    });

    group('installModel', () {
      test('emits progress updates during installation', () async {
        // Arrange
        final streamedResponse = MockInstallProgressResponse();
        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => streamedResponse,
        );

        // Act & Assert
        final progressStream = repository.installModel(modelName, baseUrl);
        final progressList = await progressStream.toList();

        expect(progressList, hasLength(3));
        expect(progressList[0].status, 'pulling manifest');
        expect(progressList[0].progress, 0.0);
        expect(progressList[1].status, 'downloading');
        expect(progressList[1].progress, 0.5);
        expect(progressList[2].status, 'success');
        expect(progressList[2].progress, 1.0);

        // Verify request was made correctly
        final captured =
            verify(() => mockHttpClient.send(captureAny())).captured;
        final request = captured.first as http.Request;
        expect(request.url.toString(), '$baseUrl/api/pull');
        expect(request.method, 'POST');
        expect(request.headers['Content-Type'], startsWith('application/json'));
        expect(jsonDecode(request.body), {'name': modelName});
      });

      test('throws exception when installation fails', () async {
        // Arrange
        final mockResponse = MockStreamedResponse();
        when(() => mockResponse.statusCode).thenReturn(500);
        when(() => mockResponse.stream).thenAnswer((_) => http.ByteStream(
              Stream.value(utf8.encode('{"error": "installation failed"}\n')),
            ));

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => mockResponse,
        );

        // Act & Assert
        expect(
          () => repository.installModel(modelName, baseUrl).toList(),
          throwsA(isA<Exception>()),
        );
      });

      test('handles error responses in stream', () async {
        // Arrange
        final streamedResponse = MockStreamedResponseWithError();
        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => streamedResponse,
        );

        // Act & Assert
        expect(
          () => repository.installModel(modelName, baseUrl).toList(),
          throwsA(isA<Exception>()),
        );
      });

      test('skips malformed JSON lines', () async {
        // Arrange
        final streamedResponse = MockInstallProgressResponse();
        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => streamedResponse,
        );

        // Act & Assert
        final progressStream = repository.installModel(modelName, baseUrl);
        final progressList = await progressStream.toList();

        expect(progressList, hasLength(3)); // Only valid JSON lines
        expect(progressList[0].status, 'pulling manifest');
        expect(progressList[2].status, 'success');
      });
    });

    group('_generateWithOllama', () {
      test('generates response with images successfully', () async {
        // Arrange
        const prompt = 'Analyze this image';
        const images = [testImage];
        const temperature = 0.7;

        // Set up repository with mock HTTP client
        final testMockRef = MockRef();
        final testOllamaRepo =
            OllamaInferenceRepository(httpClient: mockHttpClient);

        when(() => testMockRef.read(ollamaInferenceRepositoryProvider))
            .thenReturn(testOllamaRepo);
        // Provide Gemini repo as well for this specialized ref
        when(() => testMockRef.read(geminiInferenceRepositoryProvider))
            .thenReturn(GeminiInferenceRepository(httpClient: mockHttpClient));

        repository =
            CloudInferenceRepository(testMockRef, httpClient: mockHttpClient);
        ollamaProvider = AiConfig.inferenceProvider(
          id: 'ollama-provider',
          name: 'Ollama Provider',
          baseUrl: baseUrl,
          apiKey: '',
          createdAt: DateTime.now(),
          inferenceProviderType: InferenceProviderType.ollama,
        ) as AiConfigInferenceProvider;

        // Mock both warmUpModel call and generate call
        // The OllamaInferenceRepository will make both calls
        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((invocation) async {
          // This is warmUpModel (still uses post for now)
          return http.Response(
            '{"response": "Hello", "created_at": "2024-01-01T00:00:00Z"}',
            httpStatusOk,
          );
        });

        // Mock streaming response for generateWithImages
        final mockResponse = MockStreamedResponse();
        when(() => mockResponse.statusCode).thenReturn(200);
        when(() => mockResponse.stream).thenAnswer((_) => http.ByteStream(
              Stream.value(
                utf8.encode(
                    '{"message":{"content":"Analyze this image"},"done":true}\n'),
              ),
            ));

        when(() => mockHttpClient.send(any()))
            .thenAnswer((_) async => mockResponse);

        // Act
        final stream = repository.generateWithImages(
          prompt,
          model: modelName,
          temperature: temperature,
          baseUrl: baseUrl,
          apiKey: '',
          images: images,
          provider: ollamaProvider,
        );

        // Assert
        final response = await stream.first;
        expect(response.choices, hasLength(1));
        expect(response.choices?.first.delta?.content, 'Analyze this image');

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

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['model'], modelName);
        expect(body['messages'], isA<List<dynamic>>());
        final messages = body['messages'] as List<dynamic>;
        expect(messages.length, 1);
        final message = messages[0] as Map<String, dynamic>;
        expect(message['role'], 'user');
        expect(message['content'], prompt);
        expect(message['images'], images);
        expect(body['stream'], true);
        expect((body['options'] as Map<String, dynamic>)['temperature'],
            temperature);
      });

      test('throws ModelNotInstalledException when model not found', () async {
        // Arrange
        const prompt = 'Analyze this image';
        const images = [testImage];

        // Mock warm-up call
        when(() => mockHttpClient.post(any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'))).thenAnswer(
          (_) async => http.Response('{"response": "Hello"}', httpStatusOk),
        );

        // Mock generate call with model not found error
        final mockResponse = MockStreamedResponse();
        when(() => mockResponse.statusCode).thenReturn(404);
        when(() => mockResponse.stream).thenAnswer((_) => http.ByteStream(
              Stream.value(
                utf8.encode('{"error": "model not found"}\n'),
              ),
            ));

        when(() => mockHttpClient.send(any()))
            .thenAnswer((_) async => mockResponse);

        // Act & Assert
        final stream = repository.generateWithImages(
          prompt,
          model: modelName,
          temperature: 0.7,
          baseUrl: baseUrl,
          apiKey: '',
          images: images,
          provider: ollamaProvider,
        );

        expect(
          () => stream.first,
          throwsA(isA<ModelNotInstalledException>()),
        );
      });

      test('validates input parameters', () async {
        // Arrange
        const images = [testImage];

        // Act & Assert
        expect(
          () => repository.generateWithImages(
            '', // Empty prompt
            model: modelName,
            temperature: 0.7,
            baseUrl: baseUrl,
            apiKey: '',
            images: images,
            provider: ollamaProvider,
          ),
          throwsA(isA<Exception>()),
        );

        expect(
          () => repository.generateWithImages(
            'Test prompt',
            model: '',
            // Empty model
            temperature: 0.7,
            baseUrl: baseUrl,
            apiKey: '',
            images: images,
            provider: ollamaProvider,
          ),
          throwsA(isA<Exception>()),
        );

        expect(
          () => repository.generateWithImages(
            'Test prompt',
            model: modelName,
            temperature: 0.7,
            baseUrl: baseUrl,
            apiKey: '',
            images: [],
            // Empty images
            provider: ollamaProvider,
          ),
          throwsA(isA<Exception>()),
        );

        expect(
          () => repository.generateWithImages(
            'Test prompt',
            model: modelName,
            temperature: -1,
            // Invalid temperature
            baseUrl: baseUrl,
            apiKey: '',
            images: images,
            provider: ollamaProvider,
          ),
          throwsA(isA<Exception>()),
        );

        expect(
          () => repository.generateWithImages(
            'Test prompt',
            model: modelName,
            temperature: 3,
            // Invalid temperature
            baseUrl: baseUrl,
            apiKey: '',
            images: images,
            provider: ollamaProvider,
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('handles timeout for image analysis', () {
        // Ensure retryBaseDelay is always restored even if the test fails
        final prevDelay = OllamaInferenceRepository.retryBaseDelay;
        addTearDown(() => OllamaInferenceRepository.retryBaseDelay = prevDelay);
        fakeAsync((async) {
          // Arrange
          const prompt = 'Analyze this image';
          const images = [testImage];
          const temperature = 0.7;

          // Mock warm-up call (returns quickly)
          when(() => mockHttpClient.post(any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'))).thenAnswer(
            (_) async => http.Response('{"response": "Hello"}', httpStatusOk),
          );

          // Simulate the HTTP send exceeding the image-analysis timeout on each retry.
          when(() => mockHttpClient.send(any())).thenAnswer((_) async {
            await Future<void>.delayed(
              const Duration(seconds: ollamaImageAnalysisTimeoutSeconds + 1),
            );
            return MockStreamedResponse(); // never reached before timeout
          });

          // Remove backoff to keep time math simple under fake clock
          OllamaInferenceRepository.retryBaseDelay = Duration.zero;

          final received = <dynamic>[];
          final errors = <Object>[];
          final done = Completer<void>();

          repository
              .generateWithImages(
            prompt,
            model: modelName,
            temperature: temperature,
            baseUrl: baseUrl,
            apiKey: '',
            images: images,
            provider: ollamaProvider,
          )
              .listen(
            received.add,
            onError: (Object e, StackTrace st) {
              errors.add(e);
              if (!done.isCompleted) done.complete();
            },
            onDone: () {
              if (!done.isCompleted) done.complete();
            },
          );

          // Advance fake time following the retry/backoff plan deterministically
          final plan = buildRetryBackoffPlan(
            maxRetries: 3,
            timeout: const Duration(seconds: ollamaImageAnalysisTimeoutSeconds),
            baseDelay: OllamaInferenceRepository.retryBaseDelay,
            epsilon: const Duration(seconds: 1),
          );
          async.elapseRetryPlan(plan);

          // Assert the timeout path deterministically
          expect(done.isCompleted, isTrue);
          expect(received, isEmpty);
          expect(errors, isNotEmpty);
          expect(errors.first.toString(), contains('timed out'));
        });
      });
    });

    group('_generateTextWithOllama', () {
      test('generates text response successfully', () async {
        // Arrange
        const prompt = 'Generate a summary';
        const expectedResponse = 'This is a test response';

        final mockResponse = MockStreamedResponse();
        when(() => mockResponse.statusCode).thenReturn(200);
        when(() => mockResponse.stream).thenAnswer((_) => http.ByteStream(
              Stream.value(
                utf8.encode(
                    '{"message":{"content":"$expectedResponse"},"done":true}\n'),
              ),
            ));

        when(() => mockHttpClient.send(any()))
            .thenAnswer((_) async => mockResponse);

        // Act
        final stream = repository.generate(
          prompt,
          model: modelName,
          temperature: 0.7,
          baseUrl: baseUrl,
          apiKey: '',
          provider: ollamaProvider,
        );

        // Assert
        final response = await stream.first;
        expect(response.choices?.first.delta?.content, expectedResponse);
      });

      test('throws ModelNotInstalledException when model not found', () async {
        // Arrange
        const prompt = 'Generate a summary';

        // Mock generate call with model not found error
        final mockResponse = MockStreamedResponse();
        when(() => mockResponse.statusCode).thenReturn(404);
        when(() => mockResponse.stream).thenAnswer((_) => http.ByteStream(
              Stream.value(
                utf8.encode('{"error": "model not found"}\n'),
              ),
            ));

        when(() => mockHttpClient.send(any()))
            .thenAnswer((_) async => mockResponse);

        // Act & Assert
        final stream = repository.generate(
          prompt,
          model: modelName,
          temperature: 0.7,
          baseUrl: baseUrl,
          apiKey: '',
          provider: ollamaProvider,
        );

        expect(
          () => stream.first,
          throwsA(isA<ModelNotInstalledException>()),
        );
      });

      test('sends correct request body', () async {
        // Arrange
        const prompt = 'Generate a summary';
        const temperature = 0.7;
        const maxCompletionTokens = 1000;

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
        final stream = repository.generate(
          prompt,
          model: modelName,
          temperature: temperature,
          baseUrl: baseUrl,
          apiKey: '',
          maxCompletionTokens: maxCompletionTokens,
          provider: ollamaProvider,
        );

        // Consume the stream to trigger the HTTP call
        await stream.first;

        // Assert
        final captured =
            verify(() => mockHttpClient.send(captureAny())).captured;
        final request = captured[0] as http.Request;

        expect(request.url.toString(), contains('/api/chat'));

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['model'], modelName);
        expect(body['messages'], isA<List<dynamic>>());
        final messages = body['messages'] as List<dynamic>;
        expect(messages.length, 1);
        final message = messages[0] as Map<String, dynamic>;
        expect(message['role'], 'user');
        expect(message['content'], prompt);
        expect(body['stream'], true);
        expect((body['options'] as Map<String, dynamic>)['temperature'],
            temperature);
        expect((body['options'] as Map<String, dynamic>)['num_predict'],
            maxCompletionTokens);
      });

      test('includes system message in messages when provided', () async {
        // Arrange
        const prompt = 'Generate a summary';
        const systemMessage = 'You are a helpful assistant.';

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
        final stream = repository.generate(
          prompt,
          model: modelName,
          temperature: 0.7,
          baseUrl: baseUrl,
          apiKey: '',
          systemMessage: systemMessage,
          provider: ollamaProvider,
        );

        // Consume the stream to trigger the HTTP call
        await stream.first;

        // Assert
        final captured =
            verify(() => mockHttpClient.send(captureAny())).captured;
        final request = captured[0] as http.Request;

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['messages'], isA<List<dynamic>>());
        final messages = body['messages'] as List<dynamic>;
        expect(messages.length, 2);
        final systemMsg = messages[0] as Map<String, dynamic>;
        final userMsg = messages[1] as Map<String, dynamic>;
        expect(systemMsg['role'], 'system');
        expect(systemMsg['content'], systemMessage);
        expect(userMsg['role'], 'user');
        expect(userMsg['content'], prompt);
      });
    });

    group('OllamaPullProgress', () {
      test('has correct status and progress', () {
        const progress = OllamaPullProgress(
          status: 'downloading',
          progress: 0.5,
        );

        expect(progress.status, 'downloading');
        expect(progress.progress, 0.5);
      });
    });

    group('ModelNotInstalledException', () {
      test('toString returns correct message', () {
        const exception = ModelNotInstalledException('test-model');
        expect(exception.toString(),
            'Model "test-model" is not installed. Please install it first.');
      });
    });
  });
}

// Simple mock for general use
class MockStreamedResponse extends Mock implements http.StreamedResponse {}

// Special mock with hardcoded stream for installation progress tests
class MockInstallProgressResponse extends Mock
    implements http.StreamedResponse {
  MockInstallProgressResponse({this.statusCode = httpStatusOk});

  @override
  final int statusCode;

  @override
  http.ByteStream get stream => http.ByteStream(Stream.fromIterable([
        utf8.encode(
            '{"status": "pulling manifest", "total": 1000000, "completed": 0}\n'),
        utf8.encode(
            '{"status": "downloading", "total": 1000000, "completed": 500000}\n'),
        utf8.encode(
            '{"status": "success", "total": 1000000, "completed": 1000000}\n'),
      ]));
}

class MockStreamedResponseWithError extends Mock
    implements http.StreamedResponse {
  @override
  final int statusCode = httpStatusOk;

  @override
  http.ByteStream get stream => http.ByteStream(Stream.fromIterable([
        utf8.encode('{"error": "Model not found"}\n'),
      ]));
}
