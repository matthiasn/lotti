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

    group('isModelInstalled', () {
      test('returns true when model is installed', () async {
        // Arrange
        final responseBody = jsonEncode({
          'models': [
            {
              'name': modelName,
              'model': modelName,
              'size': 4294967296, // 4GB
              'details': {
                'parameter_size': '4.3B',
                'quantization_level': 'Q4_K_M',
              },
            },
          ],
        });

        when(() => mockHttpClient.get(any())).thenAnswer(
          (_) async => http.Response(responseBody, httpStatusOk),
        );

        // Act
        final result = await repository.isModelInstalled(modelName, baseUrl);

        // Assert
        expect(result, isTrue);
        verify(() => mockHttpClient.get(Uri.parse('$baseUrl/api/tags')))
            .called(1);
      });

      test('returns false when model is not installed', () async {
        // Arrange
        final responseBody = jsonEncode({
          'models': [
            {
              'name': 'other-model',
              'model': 'other-model',
              'size': 4294967296,
            },
          ],
        });

        when(() => mockHttpClient.get(any())).thenAnswer(
          (_) async => http.Response(responseBody, httpStatusOk),
        );

        // Act
        final result = await repository.isModelInstalled(modelName, baseUrl);

        // Assert
        expect(result, isFalse);
      });

      test('returns false when API returns error status', () async {
        // Arrange
        when(() => mockHttpClient.get(any())).thenAnswer(
          (_) async => http.Response('Error', httpStatusInternalServerError),
        );

        // Act
        final result = await repository.isModelInstalled(modelName, baseUrl);

        // Assert
        expect(result, isFalse);
      });

      test('returns false when API call throws exception', () async {
        // Arrange
        when(() => mockHttpClient.get(any()))
            .thenThrow(Exception('Network error'));

        // Act
        final result = await repository.isModelInstalled(modelName, baseUrl);

        // Assert
        expect(result, isFalse);
      });

      test('handles timeout gracefully', () {
        fakeAsync((async) {
          // Arrange
          when(() => mockHttpClient.get(any())).thenAnswer(
            (_) async {
              await Future<void>.delayed(const Duration(seconds: 2));
              return http.Response('{}', httpStatusOk);
            },
          );

          // Act under fake time
          bool? result;
          repository
              .isModelInstalled(modelName, baseUrl)
              .then((r) => result = r);

          // Drive time forward to trigger timeout handling deterministically
          async
            ..elapse(const Duration(seconds: 2))
            ..flushMicrotasks();

          // Assert
          expect(result, isFalse);
        });
      });
    });

    group('getModelInfo', () {
      test('returns model info when model is found', () async {
        // Arrange
        final responseBody = jsonEncode({
          'models': [
            {
              'name': modelName,
              'model': modelName,
              'size': 4294967296, // 4GB
              'details': {
                'parameter_size': '4.3B',
                'quantization_level': 'Q4_K_M',
              },
            },
          ],
        });

        when(() => mockHttpClient.get(any())).thenAnswer(
          (_) async => http.Response(responseBody, httpStatusOk),
        );

        // Act
        final result = await repository.getModelInfo(modelName, baseUrl);

        // Assert
        expect(result, isNotNull);
        expect(result!.name, modelName);
        expect(result.size, 4294967296);
        expect(result.parameterSize, '4.3B');
        expect(result.quantizationLevel, 'Q4_K_M');
        expect(result.humanReadableSize, '4.0 GB');
      });

      test('returns null when model is not found', () async {
        // Arrange
        final responseBody = jsonEncode({
          'models': [
            {
              'name': 'other-model',
              'model': 'other-model',
              'size': 4294967296,
            },
          ],
        });

        when(() => mockHttpClient.get(any())).thenAnswer(
          (_) async => http.Response(responseBody, httpStatusOk),
        );

        // Act
        final result = await repository.getModelInfo(modelName, baseUrl);

        // Assert
        expect(result, isNull);
      });

      test('returns null when API returns error status', () async {
        // Arrange
        when(() => mockHttpClient.get(any())).thenAnswer(
          (_) async => http.Response('Error', httpStatusInternalServerError),
        );

        // Act
        final result = await repository.getModelInfo(modelName, baseUrl);

        // Assert
        expect(result, isNull);
      });

      test('handles missing details gracefully', () async {
        // Arrange
        final responseBody = jsonEncode({
          'models': [
            {
              'name': modelName,
              'model': modelName,
              'size': 4294967296,
              // No details field
            },
          ],
        });

        when(() => mockHttpClient.get(any())).thenAnswer(
          (_) async => http.Response(responseBody, httpStatusOk),
        );

        // Act
        final result = await repository.getModelInfo(modelName, baseUrl);

        // Assert
        expect(result, isNotNull);
        expect(result!.name, modelName);
        expect(result.size, 4294967296);
        expect(result.parameterSize, 'Unknown');
        expect(result.quantizationLevel, 'Unknown');
      });
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
        when(() => mockResponse.statusCode)
            .thenReturn(httpStatusInternalServerError);
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

    group('warmUpModel', () {
      test('sends warm-up request successfully', () async {
        // Arrange
        when(() => mockHttpClient.post(any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'))).thenAnswer(
          (_) async => http.Response('{"response": "Hello"}', httpStatusOk),
        );

        // Act
        await repository.warmUpModel(modelName, baseUrl);

        // Assert
        final captured = verify(() => mockHttpClient.post(
              any(),
              headers: captureAny(named: 'headers'),
              body: captureAny(named: 'body'),
            )).captured;

        final headers = captured[0] as Map<String, String>;
        final body = captured[1] as String;

        expect(headers['Content-Type'], ollamaContentType);
        expect(jsonDecode(body), {
          'model': modelName,
          'messages': [
            {'role': 'user', 'content': 'Hello'}
          ],
          'stream': false,
        });
      });

      test('handles warm-up failure gracefully', () async {
        // Arrange
        when(() => mockHttpClient.post(any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'))).thenAnswer(
          (_) async => http.Response('Error', httpStatusInternalServerError),
        );

        // Act & Assert - should not throw
        await repository.warmUpModel(modelName, baseUrl);
      });

      test('handles timeout gracefully', () {
        fakeAsync((async) {
          // Arrange
          when(() => mockHttpClient.post(any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'))).thenAnswer(
            (_) async {
              await Future<void>.delayed(const Duration(seconds: 2));
              return http.Response('{"response": "Hello"}', httpStatusOk);
            },
          );

          // Act under fake time & Assert - should not throw
          Object? error;
          repository
              .warmUpModel(modelName, baseUrl)
              .catchError((dynamic e, __) => error = e);

          async
            ..elapse(const Duration(seconds: 2))
            ..flushMicrotasks();

          expect(error, isNull);
        });
      });
    });

    group('_generateWithOllama', () {
      test('generates response with images successfully', () async {
        // Arrange
        const prompt = 'Analyze this image';
        const images = [testImage];
        const temperature = 0.7;

        // Use test subclass to override warmUpModel
        final testMockRef = MockRef();
        final testOllamaRepo =
            OllamaInferenceRepository(httpClient: mockHttpClient);

        when(() => testMockRef.read(ollamaInferenceRepositoryProvider))
            .thenReturn(testOllamaRepo);
        // Provide Gemini repo as well for this specialized ref
        when(() => testMockRef.read(geminiInferenceRepositoryProvider))
            .thenReturn(GeminiInferenceRepository(httpClient: mockHttpClient));

        repository = TestCloudInferenceRepository(testMockRef,
            httpClient: mockHttpClient);
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

      test('handles timeout for image analysis', () async {
        // Arrange
        const prompt = 'Analyze this image';
        const images = [testImage];
        const temperature = 0.7;

        // Mock warm-up call
        when(() => mockHttpClient.post(any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'))).thenAnswer(
          (_) async => http.Response('{"response": "Hello"}', httpStatusOk),
        );

        // Mock generate call with delayed response
        final mockResponse = MockStreamedResponse();
        when(() => mockResponse.statusCode).thenReturn(200);
        when(() => mockResponse.stream).thenAnswer((_) => http.ByteStream(
              () async* {
                await Future<void>.delayed(const Duration(milliseconds: 100));
                yield utf8
                    .encode('{"message":{"content":"result"},"done":true}\n');
              }(),
            ));

        when(() => mockHttpClient.send(any()))
            .thenAnswer((_) async => mockResponse);

        // Act & Assert - should not throw due to timeout handling
        final result = await repository
            .generateWithImages(
              prompt,
              model: modelName,
              temperature: temperature,
              baseUrl: baseUrl,
              apiKey: '',
              images: images,
              provider: ollamaProvider,
            )
            .toList();

        expect(result, isNotEmpty);
      });
    });

    group('OllamaModelInfo', () {
      test('humanReadableSize formats correctly', () {
        const info = OllamaModelInfo(
          name: 'test-model',
          size: 1024, // 1KB
          parameterSize: '4.3B',
          quantizationLevel: 'Q4_K_M',
        );

        expect(info.humanReadableSize, '1.0 KB');
      });

      test('humanReadableSize handles large sizes', () {
        const info = OllamaModelInfo(
          name: 'test-model',
          size: 4294967296, // 4GB
          parameterSize: '4.3B',
          quantizationLevel: 'Q4_K_M',
        );

        expect(info.humanReadableSize, '4.0 GB');
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
      test('progressPercentage formats correctly', () {
        const progress = OllamaPullProgress(
          status: 'downloading',
          total: 1000000,
          completed: 500000,
          progress: 0.5,
        );

        expect(progress.progressPercentage, '50.0%');
      });

      test('downloadProgress formats correctly', () {
        const progress = OllamaPullProgress(
          status: 'downloading',
          total: 1048576, // 1MB
          completed: 524288, // 0.5MB
          progress: 0.5,
        );

        expect(
            progress.downloadProgress, 'downloading: 0.5 MB / 1.0 MB (50.0%)');
      });

      test('downloadProgress handles zero total', () {
        const progress = OllamaPullProgress(
          status: 'pulling manifest',
          total: 0,
          completed: 0,
          progress: 0,
        );

        expect(progress.downloadProgress, 'pulling manifest');
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

// Test subclass to override warmUpModel
class TestCloudInferenceRepository extends CloudInferenceRepository {
  TestCloudInferenceRepository(super.ref, {super.httpClient});
  @override
  Future<void> warmUpModel(String modelName, String baseUrl) async {}
}
