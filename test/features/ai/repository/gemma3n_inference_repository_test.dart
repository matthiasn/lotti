import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/repository/gemma3n_inference_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockHttpClient extends Mock implements http.Client {}

class MockStreamedResponse extends Mock implements http.StreamedResponse {}

class FakeRequest extends Fake implements http.Request {}

void main() {
  late Gemma3nInferenceRepository repository;
  late MockHttpClient mockHttpClient;

  setUpAll(() {
    registerFallbackValue(FakeRequest());
    registerFallbackValue(Uri.parse('http://localhost:8080'));
  });

  setUp(() {
    mockHttpClient = MockHttpClient();
    repository = Gemma3nInferenceRepository(httpClient: mockHttpClient);
  });

  group('Gemma3nInferenceRepository', () {
    group('transcribeAudio', () {
      const model = 'google/gemma-3n-E2B-it';
      const baseUrl = 'http://localhost:8080';
      const audioBase64 = 'base64_audio_data';
      const prompt = 'Test context';

      test('should transcribe audio successfully', () async {
        // Arrange
        const expectedText = 'Transcribed text';
        final responseBody = {
          'id': 'test-123',
          'choices': [
            {
              'message': {
                'content': expectedText,
              },
            },
          ],
          'created': 1234567890,
        };

        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => http.Response(
              jsonEncode(responseBody),
              200,
            ));

        // Act
        final stream = repository.transcribeAudio(
          model: model,
          audioBase64: audioBase64,
          baseUrl: baseUrl,
          prompt: prompt,
        );

        final result = await stream.first;

        // Assert
        expect(result.choices?.first.delta?.content, equals(expectedText));
        expect(result.id, equals('test-123'));

        // Verify the request
        final captured = verify(() => mockHttpClient.post(
              captureAny(),
              headers: captureAny(named: 'headers'),
              body: captureAny(named: 'body'),
            )).captured;

        final uri = captured[0] as Uri;
        expect(uri.toString(), equals('$baseUrl/v1/chat/completions'));

        final headers = captured[1] as Map<String, String>;
        expect(headers['Content-Type'], contains('application/json'));

        final requestBody =
            jsonDecode(captured[2] as String) as Map<String, dynamic>;
        expect(requestBody['model'], equals('gemma-3n-E2B-it')); // Normalized
        expect(requestBody['audio'], equals(audioBase64));
        expect(requestBody['temperature'], equals(0.1));
        expect(requestBody['max_tokens'], equals(2000));

        final messages = requestBody['messages'] as List<dynamic>;
        expect(messages.length, equals(1));
        expect((messages[0] as Map<String, dynamic>)['role'], equals('user'));
        expect((messages[0] as Map<String, dynamic>)['content'],
            contains('Context: $prompt'));
      });

      test('should transcribe audio without prompt', () async {
        // Arrange
        const expectedText = 'Transcribed text';
        final responseBody = {
          'id': 'test-123',
          'choices': [
            {
              'message': {
                'content': expectedText,
              },
            },
          ],
        };

        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => http.Response(
              jsonEncode(responseBody),
              200,
            ));

        // Act
        final stream = repository.transcribeAudio(
          model: model,
          audioBase64: audioBase64,
          baseUrl: baseUrl,
        );

        final result = await stream.first;

        // Assert
        expect(result.choices?.first.delta?.content, equals(expectedText));

        final captured = verify(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: captureAny(named: 'body'),
            )).captured;

        final requestBody =
            jsonDecode(captured.first as String) as Map<String, dynamic>;
        final messages = requestBody['messages'] as List<dynamic>;
        expect((messages[0] as Map<String, dynamic>)['content'],
            equals('Transcribe this audio'));
      });

      test('should use custom max completion tokens', () async {
        // Arrange
        final responseBody = {
          'choices': [
            {
              'message': {
                'content': 'Text',
              },
            },
          ],
        };

        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => http.Response(
              jsonEncode(responseBody),
              200,
            ));

        // Act
        final stream = repository.transcribeAudio(
          model: model,
          audioBase64: audioBase64,
          baseUrl: baseUrl,
          maxCompletionTokens: 5000,
        );

        await stream.first;

        // Assert
        final captured = verify(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: captureAny(named: 'body'),
            )).captured;

        final requestBody =
            jsonDecode(captured.first as String) as Map<String, dynamic>;
        expect(requestBody['max_tokens'], equals(5000));
      });

      test('should throw ArgumentError for empty model', () {
        expect(
          () => repository.transcribeAudio(
            model: '',
            audioBase64: audioBase64,
            baseUrl: baseUrl,
          ),
          throwsA(isA<ArgumentError>().having(
              (e) => e.message, 'message', 'Model name cannot be empty')),
        );
      });

      test('should throw ArgumentError for empty baseUrl', () {
        expect(
          () => repository.transcribeAudio(
            model: model,
            audioBase64: audioBase64,
            baseUrl: '',
          ),
          throwsA(isA<ArgumentError>()
              .having((e) => e.message, 'message', 'Base URL cannot be empty')),
        );
      });

      test('should handle HTTP error responses', () async {
        // Arrange
        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => http.Response(
              'Server error',
              500,
            ));

        // Act & Assert
        final stream = repository.transcribeAudio(
          model: model,
          audioBase64: audioBase64,
          baseUrl: baseUrl,
        );

        expect(
          stream.first,
          throwsA(isA<Gemma3nInferenceException>()
              .having((e) => e.message, 'message', contains('HTTP 500'))
              .having((e) => e.statusCode, 'statusCode', 500)),
        );
      });

      test('should throw ModelNotAvailableException when model is missing',
          () async {
        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => http.Response(
              'Model not found',
              404,
            ));

        final stream = repository.transcribeAudio(
          model: model,
          audioBase64: audioBase64,
          baseUrl: baseUrl,
        );

        expect(
          stream.first,
          throwsA(isA<ModelNotAvailableException>()
              .having((e) => e.modelName, 'modelName', 'gemma-3n-E2B-it')
              .having((e) => e.statusCode, 'statusCode', 404)),
        );
      });

      test('should handle timeout', () async {
        // Arrange
        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(seconds: 2));
          return http.Response('', 200);
        });

        // Act & Assert
        final stream = repository.transcribeAudio(
          model: model,
          audioBase64: audioBase64,
          baseUrl: baseUrl,
          timeout: const Duration(milliseconds: 100),
        );

        expect(
          stream.first,
          throwsA(isA<Gemma3nInferenceException>()
              .having((e) => e.message, 'message', contains('timed out'))
              .having((e) => e.statusCode, 'statusCode', 408)),
        );
      });

      test('should handle invalid JSON response', () async {
        // Arrange
        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => http.Response(
              'Invalid JSON',
              200,
            ));

        // Act & Assert
        final stream = repository.transcribeAudio(
          model: model,
          audioBase64: audioBase64,
          baseUrl: baseUrl,
        );

        expect(
          stream.first,
          throwsA(isA<Gemma3nInferenceException>().having((e) => e.message,
              'message', contains('Invalid response format'))),
        );
      });

      test('should handle missing choices in response', () async {
        // Arrange
        final responseBody = {
          'id': 'test-123',
          // Missing 'choices'
        };

        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => http.Response(
              jsonEncode(responseBody),
              200,
            ));

        // Act & Assert
        final stream = repository.transcribeAudio(
          model: model,
          audioBase64: audioBase64,
          baseUrl: baseUrl,
        );

        expect(
          stream.first,
          throwsA(isA<Gemma3nInferenceException>().having(
              (e) => e.message,
              'message',
              contains('Invalid response from transcription service'))),
        );
      });

      test('should handle empty choices array', () async {
        // Arrange
        final responseBody = {
          'id': 'test-123',
          'choices': <dynamic>[],
        };

        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => http.Response(
              jsonEncode(responseBody),
              200,
            ));

        // Act & Assert
        final stream = repository.transcribeAudio(
          model: model,
          audioBase64: audioBase64,
          baseUrl: baseUrl,
        );

        expect(
          stream.first,
          throwsA(isA<Gemma3nInferenceException>().having(
              (e) => e.message,
              'message',
              contains('Invalid response from transcription service'))),
        );
      });

      test('should handle missing message content', () async {
        // Arrange
        final responseBody = {
          'id': 'test-123',
          'choices': [
            <String, dynamic>{
              'message': <String, dynamic>{
                // Missing 'content'
              },
            },
          ],
        };

        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => http.Response(
              jsonEncode(responseBody),
              200,
            ));

        // Act & Assert
        final stream = repository.transcribeAudio(
          model: model,
          audioBase64: audioBase64,
          baseUrl: baseUrl,
        );

        expect(
          stream.first,
          throwsA(isA<Gemma3nInferenceException>().having(
              (e) => e.message,
              'message',
              contains('Invalid response from transcription service'))),
        );
      });
    });

    group('generateText', () {
      const model = 'google/gemma-3n-E2B-it';
      const baseUrl = 'http://localhost:8080';
      const prompt = 'Test prompt';

      test('should generate text with streaming successfully', () async {
        // Arrange
        final mockStreamedResponse = MockStreamedResponse();
        final streamController = StreamController<List<int>>();

        // Simulate SSE stream chunks
        final chunks = [
          'data: {"id":"test-1","choices":[{"delta":{"content":"Hello"}}],"created":1234567890}\n',
          'data: {"id":"test-2","choices":[{"delta":{"content":" world"}}]}\n',
          'data: [DONE]\n',
        ];

        when(() => mockStreamedResponse.statusCode).thenReturn(200);
        when(() => mockStreamedResponse.stream)
            .thenAnswer((_) => http.ByteStream(streamController.stream));

        when(() => mockHttpClient.send(any())).thenAnswer((_) async {
          // Add chunks to stream asynchronously
          unawaited(Future.microtask(() async {
            for (final chunk in chunks) {
              streamController.add(utf8.encode(chunk));
            }
            await streamController.close();
          }));
          return mockStreamedResponse;
        });

        // Act
        final stream = repository.generateText(
          prompt: prompt,
          model: model,
          baseUrl: baseUrl,
        );

        final results = await stream.toList();

        // Assert
        expect(results.length, equals(2));
        expect(results[0].choices?.first.delta?.content, equals('Hello'));
        expect(results[1].choices?.first.delta?.content, equals(' world'));

        // Verify request
        final captured =
            verify(() => mockHttpClient.send(captureAny())).captured;
        final request = captured.first as http.Request;

        expect(request.method, equals('POST'));
        expect(request.url.toString(), equals('$baseUrl/v1/chat/completions'));
        expect(request.headers['Content-Type'], contains('application/json'));

        final requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        expect(requestBody['model'], equals('gemma-3n-E2B-it')); // Normalized
        expect(requestBody['stream'], isTrue);
        expect(requestBody['temperature'], equals(0.7));

        final messages = requestBody['messages'] as List<dynamic>;
        expect(messages.length, equals(1));
        expect((messages[0] as Map<String, dynamic>)['role'], equals('user'));
        expect(
            (messages[0] as Map<String, dynamic>)['content'], equals(prompt));
      });

      test('should generate text with system message', () async {
        // Arrange
        final mockStreamedResponse = MockStreamedResponse();
        final streamController = StreamController<List<int>>();

        when(() => mockStreamedResponse.statusCode).thenReturn(200);
        when(() => mockStreamedResponse.stream)
            .thenAnswer((_) => http.ByteStream(streamController.stream));

        when(() => mockHttpClient.send(any())).thenAnswer((_) async {
          unawaited(Future.microtask(() async {
            streamController.add(utf8.encode('data: [DONE]\n'));
            await streamController.close();
          }));
          return mockStreamedResponse;
        });

        // Act
        final stream = repository.generateText(
          prompt: prompt,
          model: model,
          baseUrl: baseUrl,
          systemMessage: 'System context',
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
            equals('System context'));
        expect((messages[1] as Map<String, dynamic>)['role'], equals('user'));
        expect(
            (messages[1] as Map<String, dynamic>)['content'], equals(prompt));
      });

      test('should use custom temperature and max tokens', () async {
        // Arrange
        final mockStreamedResponse = MockStreamedResponse();
        final streamController = StreamController<List<int>>();

        when(() => mockStreamedResponse.statusCode).thenReturn(200);
        when(() => mockStreamedResponse.stream)
            .thenAnswer((_) => http.ByteStream(streamController.stream));

        when(() => mockHttpClient.send(any())).thenAnswer((_) async {
          unawaited(Future.microtask(() async {
            streamController.add(utf8.encode('data: [DONE]\n'));
            await streamController.close();
          }));
          return mockStreamedResponse;
        });

        // Act
        final stream = repository.generateText(
          prompt: prompt,
          model: model,
          baseUrl: baseUrl,
          temperature: 1.5,
          maxCompletionTokens: 4000,
        );

        await stream.toList();

        // Assert
        final captured =
            verify(() => mockHttpClient.send(captureAny())).captured;
        final request = captured.first as http.Request;

        final requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        expect(requestBody['temperature'], equals(1.5));
        expect(requestBody['max_tokens'], equals(4000));
      });

      test('should throw ArgumentError for empty model', () {
        expect(
          () => repository
              .generateText(
                prompt: prompt,
                model: '',
                baseUrl: baseUrl,
              )
              .toList(),
          throwsA(isA<ArgumentError>().having(
              (e) => e.message, 'message', 'Model name cannot be empty')),
        );
      });

      test('should throw ArgumentError for empty baseUrl', () {
        expect(
          () => repository
              .generateText(
                prompt: prompt,
                model: model,
                baseUrl: '',
              )
              .toList(),
          throwsA(isA<ArgumentError>()
              .having((e) => e.message, 'message', 'Base URL cannot be empty')),
        );
      });

      test('should handle HTTP error responses', () async {
        // Arrange
        final mockStreamedResponse = MockStreamedResponse();
        final streamController = StreamController<List<int>>();

        when(() => mockStreamedResponse.statusCode).thenReturn(500);
        when(() => mockStreamedResponse.stream)
            .thenAnswer((_) => http.ByteStream(streamController.stream));

        when(() => mockHttpClient.send(any())).thenAnswer((_) async {
          unawaited(Future.microtask(() async {
            streamController.add(utf8.encode('Server error'));
            await streamController.close();
          }));
          return mockStreamedResponse;
        });

        // Act & Assert
        final stream = repository.generateText(
          prompt: prompt,
          model: model,
          baseUrl: baseUrl,
        );

        expect(
          stream.toList(),
          throwsA(isA<Gemma3nInferenceException>()
              .having((e) => e.message, 'message', contains('HTTP 500'))
              .having((e) => e.statusCode, 'statusCode', 500)),
        );
      });

      test(
          'should throw ModelNotAvailableException when streaming model missing',
          () async {
        final mockStreamedResponse = MockStreamedResponse();

        when(() => mockStreamedResponse.statusCode).thenReturn(404);
        when(() => mockStreamedResponse.stream).thenAnswer(
          (_) => http.ByteStream(
            Stream<List<int>>.fromIterable(
              [utf8.encode('Model missing')],
            ),
          ),
        );

        when(() => mockHttpClient.send(any())).thenAnswer((_) async {
          return mockStreamedResponse;
        });

        final stream = repository.generateText(
          prompt: prompt,
          model: model,
          baseUrl: baseUrl,
        );

        await expectLater(
          stream.toList(),
          throwsA(isA<ModelNotAvailableException>()
              .having((e) => e.modelName, 'modelName', 'gemma-3n-E2B-it')
              .having((e) => e.statusCode, 'statusCode', 404)),
        );
      });

      test('should handle timeout', () async {
        // Arrange
        when(() => mockHttpClient.send(any())).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(seconds: 2));
          final mockStreamedResponse = MockStreamedResponse();
          return mockStreamedResponse;
        });

        // Act & Assert
        final stream = repository.generateText(
          prompt: prompt,
          model: model,
          baseUrl: baseUrl,
          timeout: const Duration(milliseconds: 100),
        );

        expect(
          stream.toList(),
          throwsA(isA<Gemma3nInferenceException>()
              .having((e) => e.message, 'message', contains('timed out'))
              .having((e) => e.statusCode, 'statusCode', 408)),
        );
      });

      test('should handle malformed SSE chunks gracefully', () async {
        // Arrange
        final mockStreamedResponse = MockStreamedResponse();
        final streamController = StreamController<List<int>>();

        final chunks = [
          'data: {"id":"test-1","choices":[{"delta":{"content":"Valid"}}]}\n',
          'data: {invalid json}\n', // Malformed JSON
          'data: {"id":"test-2","choices":[{"delta":{"content":" chunk"}}]}\n',
          'data: [DONE]\n',
        ];

        when(() => mockStreamedResponse.statusCode).thenReturn(200);
        when(() => mockStreamedResponse.stream)
            .thenAnswer((_) => http.ByteStream(streamController.stream));

        when(() => mockHttpClient.send(any())).thenAnswer((_) async {
          unawaited(Future.microtask(() async {
            for (final chunk in chunks) {
              streamController.add(utf8.encode(chunk));
            }
            await streamController.close();
          }));
          return mockStreamedResponse;
        });

        // Act
        final stream = repository.generateText(
          prompt: prompt,
          model: model,
          baseUrl: baseUrl,
        );

        final results = await stream.toList();

        // Assert - should skip malformed chunk
        expect(results.length, equals(2));
        expect(results[0].choices?.first.delta?.content, equals('Valid'));
        expect(results[1].choices?.first.delta?.content, equals(' chunk'));
      });

      test('should handle chunks without content gracefully', () async {
        // Arrange
        final mockStreamedResponse = MockStreamedResponse();
        final streamController = StreamController<List<int>>();

        final chunks = [
          'data: {"id":"test-1","choices":[{"delta":{"content":"Hello"}}]}\n',
          'data: {"id":"test-2","choices":[{"delta":{}}]}\n', // No content
          'data: {"id":"test-3","choices":[]}\n', // Empty choices
          'data: {"id":"test-4"}\n', // No choices
          'data: [DONE]\n',
        ];

        when(() => mockStreamedResponse.statusCode).thenReturn(200);
        when(() => mockStreamedResponse.stream)
            .thenAnswer((_) => http.ByteStream(streamController.stream));

        when(() => mockHttpClient.send(any())).thenAnswer((_) async {
          unawaited(Future.microtask(() async {
            for (final chunk in chunks) {
              streamController.add(utf8.encode(chunk));
            }
            await streamController.close();
          }));
          return mockStreamedResponse;
        });

        // Act
        final stream = repository.generateText(
          prompt: prompt,
          model: model,
          baseUrl: baseUrl,
        );

        final results = await stream.toList();

        // Assert - should only have valid content chunk
        expect(results.length, equals(1));
        expect(results[0].choices?.first.delta?.content, equals('Hello'));
      });
    });

    group('Gemma3nInferenceException', () {
      test('should format toString correctly', () {
        final exception = Gemma3nInferenceException(
          'Test error',
          statusCode: 404,
          originalError: Exception('Original'),
        );

        expect(exception.toString(),
            equals('Gemma3nInferenceException: Test error'));
        expect(exception.message, equals('Test error'));
        expect(exception.statusCode, equals(404));
        expect(exception.originalError, isA<Exception>());
      });
    });
  });
}
