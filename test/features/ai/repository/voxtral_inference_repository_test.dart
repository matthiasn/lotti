// ignore_for_file: avoid_redundant_argument_values

import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/repository/voxtral_inference_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../test_utils/retry_fake_time.dart';

class MockHttpClient extends Mock implements http.Client {}

class FakeRequest extends Fake implements http.Request {}

void main() {
  late VoxtralInferenceRepository repository;
  late MockHttpClient mockHttpClient;

  setUpAll(() {
    registerFallbackValue(FakeRequest());
    registerFallbackValue(Uri.parse('http://localhost:11344'));
  });

  setUp(() {
    mockHttpClient = MockHttpClient();
    repository = VoxtralInferenceRepository(httpClient: mockHttpClient);
  });

  group('VoxtralInferenceRepository', () {
    group('transcribeAudio', () {
      const model = 'mistralai/Voxtral-Mini-3B-2507';
      const baseUrl = 'http://localhost:11344';
      const audioBase64 = 'base64_audio_data';
      const prompt = 'Test context';

      test('should transcribe audio successfully', () async {
        // Arrange
        const expectedText = 'Transcribed text';
        final responseBody = {
          'id': 'voxtral-123',
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
        expect(result.id, equals('voxtral-123'));

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
        expect(requestBody['model'], equals(model));
        expect(requestBody['audio'], equals(audioBase64));
        expect(requestBody['temperature'], equals(0.0)); // Deterministic
        expect(requestBody['max_tokens'], equals(4096)); // Default for Voxtral

        final messages = requestBody['messages'] as List<dynamic>;
        expect(messages.length, equals(1));
        expect((messages[0] as Map<String, dynamic>)['role'], equals('user'));
        expect(
            (messages[0] as Map<String, dynamic>)['content'], equals(prompt));
      });

      test('should transcribe audio without prompt', () async {
        // Arrange
        const expectedText = 'Transcribed text';
        final responseBody = {
          'id': 'voxtral-123',
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
            equals('Transcribe this audio.'));
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
          maxCompletionTokens: 8000,
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
        expect(requestBody['max_tokens'], equals(8000));
      });

      test('should include language hint when provided', () async {
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
          language: 'de',
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
        expect(requestBody['language'], equals('de'));
      });

      test('should not include language hint for auto', () async {
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
          language: 'auto',
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
        expect(requestBody.containsKey('language'), isFalse);
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
          throwsA(isA<VoxtralInferenceException>()
              .having((e) => e.message, 'message', contains('HTTP 500'))
              .having((e) => e.statusCode, 'statusCode', 500)),
        );
      });

      test(
          'should throw VoxtralModelNotAvailableException when model is missing',
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
          throwsA(isA<VoxtralModelNotAvailableException>()
              .having((e) => e.modelName, 'modelName', model)
              .having((e) => e.statusCode, 'statusCode', 404)),
        );
      });

      test('should handle timeout', () {
        fakeAsync((FakeAsync async) {
          // Arrange
          when(() => mockHttpClient.post(
                any(),
                headers: any(named: 'headers'),
                body: any(named: 'body'),
              )).thenAnswer((_) async {
            await Future<void>.delayed(const Duration(seconds: 2));
            return http.Response('', 200);
          });

          // Act under fake time
          Object? error;
          var completed = false;
          final stream = repository.transcribeAudio(
            model: model,
            audioBase64: audioBase64,
            baseUrl: baseUrl,
            timeout: const Duration(milliseconds: 100),
          );

          stream.first.then((_) {
            completed = true;
          }, onError: (Object e) {
            error = e;
            completed = true;
          });

          // Drive time to trigger timeout deterministically via helper
          final plan = buildRetryBackoffPlan(
            maxRetries: 1,
            timeout: const Duration(milliseconds: 100),
            baseDelay: Duration.zero,
            epsilon: const Duration(milliseconds: 1),
          );
          async.elapseRetryPlan(plan);

          expect(completed, isTrue);
          final err = error;
          expect(err, isA<VoxtralInferenceException>());
          if (err is VoxtralInferenceException) {
            expect(err.statusCode, 408);
          }
        });
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
          throwsA(isA<VoxtralInferenceException>().having((e) => e.message,
              'message', contains('Invalid response format'))),
        );
      });

      test('should handle missing choices in response', () async {
        // Arrange
        final responseBody = {
          'id': 'voxtral-123',
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
          throwsA(isA<VoxtralInferenceException>().having(
              (e) => e.message,
              'message',
              contains('Invalid response from transcription service'))),
        );
      });

      test('should handle empty choices array', () async {
        // Arrange
        final responseBody = {
          'id': 'voxtral-123',
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
          throwsA(isA<VoxtralInferenceException>().having(
              (e) => e.message,
              'message',
              contains('Invalid response from transcription service'))),
        );
      });

      test('should handle missing message content', () async {
        // Arrange
        final responseBody = {
          'id': 'voxtral-123',
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
          throwsA(isA<VoxtralInferenceException>().having(
              (e) => e.message,
              'message',
              contains('Invalid response from transcription service'))),
        );
      });
    });

    group('checkHealth', () {
      test('should return healthy status when server responds', () async {
        // Arrange
        final responseBody = {
          'status': 'healthy',
          'model_available': true,
          'model_loaded': true,
          'device': 'mps',
          'max_audio_minutes': 30.0,
        };

        when(() => mockHttpClient.get(any())).thenAnswer(
          (_) async => http.Response(jsonEncode(responseBody), 200),
        );

        // Act
        final result = await repository.checkHealth();

        // Assert
        expect(result.isHealthy, isTrue);
        expect(result.modelAvailable, isTrue);
        expect(result.modelLoaded, isTrue);
        expect(result.device, equals('mps'));
        expect(result.maxAudioMinutes, equals(30.0));
      });

      test('should return unhealthy status on server error', () async {
        // Arrange
        when(() => mockHttpClient.get(any())).thenAnswer(
          (_) async => http.Response('Server error', 500),
        );

        // Act
        final result = await repository.checkHealth();

        // Assert
        expect(result.isHealthy, isFalse);
      });

      test('should return unhealthy status on network error', () async {
        // Arrange
        when(() => mockHttpClient.get(any()))
            .thenThrow(Exception('Network error'));

        // Act
        final result = await repository.checkHealth();

        // Assert
        expect(result.isHealthy, isFalse);
      });
    });

    group('downloadModel', () {
      test('should download model successfully', () async {
        // Arrange
        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => http.Response(
              jsonEncode({'status': 'success'}),
              200,
            ));

        // Act & Assert - should not throw
        await repository.downloadModel();

        // Verify the request
        final captured = verify(() => mockHttpClient.post(
              captureAny(),
              headers: any(named: 'headers'),
              body: captureAny(named: 'body'),
            )).captured;

        final uri = captured[0] as Uri;
        expect(uri.path, contains('v1/models/pull'));

        final requestBody =
            jsonDecode(captured[1] as String) as Map<String, dynamic>;
        expect(requestBody['model_name'],
            equals('mistralai/Voxtral-Mini-3B-2507'));
        expect(requestBody['stream'], isFalse);
      });

      test('should throw on download failure', () async {
        // Arrange
        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => http.Response(
              'Download failed',
              500,
            ));

        // Act & Assert
        expect(
          () => repository.downloadModel(),
          throwsA(isA<VoxtralInferenceException>()
              .having((e) => e.statusCode, 'statusCode', 500)),
        );
      });
    });

    group('VoxtralInferenceException', () {
      test('should format toString correctly', () {
        final exception = VoxtralInferenceException(
          'Test error',
          statusCode: 404,
          originalError: Exception('Original'),
        );

        expect(exception.toString(),
            equals('VoxtralInferenceException: Test error'));
        expect(exception.message, equals('Test error'));
        expect(exception.statusCode, equals(404));
        expect(exception.originalError, isA<Exception>());
      });
    });

    group('VoxtralModelNotAvailableException', () {
      test('should format toString correctly', () {
        final exception = VoxtralModelNotAvailableException(
          'Model not available',
          modelName: 'voxtral-mini',
          statusCode: 404,
        );

        expect(exception.toString(),
            equals('VoxtralModelNotAvailableException: Model not available'));
        expect(exception.modelName, equals('voxtral-mini'));
        expect(exception.statusCode, equals(404));
      });
    });

    group('VoxtralHealthStatus', () {
      test('should have default values', () {
        final status = VoxtralHealthStatus(isHealthy: true);

        expect(status.isHealthy, isTrue);
        expect(status.modelAvailable, isFalse);
        expect(status.modelLoaded, isFalse);
        expect(status.device, equals('unknown'));
        expect(status.maxAudioMinutes, equals(30));
      });
    });
  });
}
