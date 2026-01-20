// ignore_for_file: avoid_redundant_argument_values

import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/repository/voxtral_inference_repository.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../test_utils/retry_fake_time.dart';

class MockHttpClient extends Mock implements http.Client {}

class MockLoggingService extends Mock implements LoggingService {}

class FakeRequest extends Fake implements http.Request {}

class FakeBaseRequest extends Fake implements http.BaseRequest {}

/// Creates a mock SSE stream response for testing
http.StreamedResponse createSseStreamedResponse({
  required List<Map<String, dynamic>> events,
  int statusCode = 200,
}) {
  final sseLines = <String>[];

  for (final event in events) {
    sseLines.add('data: ${jsonEncode(event)}\n\n');
  }
  sseLines.add('data: [DONE]\n\n');

  final stream = Stream.fromIterable([utf8.encode(sseLines.join())]);
  return http.StreamedResponse(stream, statusCode);
}

/// Creates a mock SSE event for a chunk with content
Map<String, dynamic> createSseChunkEvent({
  required String content,
  String? id,
  String? finishReason,
  int? created,
  String model = 'voxtral-mini',
}) {
  return {
    'id': id ?? 'chatcmpl-test',
    'object': 'chat.completion.chunk',
    'created': created ?? 1234567890,
    'model': model,
    'choices': [
      {
        'index': 0,
        'delta': {'content': content},
        'finish_reason': finishReason,
      }
    ],
  };
}

/// Creates a final SSE event with finish_reason but no content
Map<String, dynamic> createSseFinalEvent({
  String? id,
  int? created,
  String model = 'voxtral-mini',
}) {
  return {
    'id': id ?? 'chatcmpl-test',
    'object': 'chat.completion.chunk',
    'created': created ?? 1234567890,
    'model': model,
    'choices': [
      {
        'index': 0,
        'delta': <String, dynamic>{},
        'finish_reason': 'stop',
      }
    ],
  };
}

void main() {
  late VoxtralInferenceRepository repository;
  late MockHttpClient mockHttpClient;

  setUpAll(() {
    registerFallbackValue(FakeRequest());
    registerFallbackValue(FakeBaseRequest());
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

      test('should transcribe audio with streaming', () async {
        // Arrange - simulate multiple chunks being streamed
        const chunk1 = 'This is the first chunk.';
        const chunk2 = ' This is the second chunk.';
        final events = [
          createSseChunkEvent(content: chunk1),
          createSseChunkEvent(content: chunk2),
          createSseFinalEvent(),
        ];

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: events),
        );

        // Act
        final stream = repository.transcribeAudio(
          model: model,
          audioBase64: audioBase64,
          baseUrl: baseUrl,
          prompt: prompt,
        );

        final results = await stream.toList();

        // Assert - should receive 2 chunks with content
        expect(results.length, equals(2));
        expect(results[0].choices?.first.delta?.content, equals(chunk1));
        expect(results[1].choices?.first.delta?.content, equals(chunk2));

        // Verify the request
        final captured =
            verify(() => mockHttpClient.send(captureAny())).captured;
        final request = captured.first as http.Request;
        expect(request.url.toString(), equals('$baseUrl/v1/chat/completions'));
        expect(request.headers['Content-Type'], contains('application/json'));
        expect(request.headers['Accept'], contains('text/event-stream'));

        final requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        expect(requestBody['model'], equals(model));
        expect(requestBody['audio'], equals(audioBase64));
        expect(requestBody['stream'], isTrue); // Streaming enabled
        expect(requestBody['temperature'], equals(0.0)); // Deterministic
        expect(requestBody['max_tokens'], equals(4096)); // Default for Voxtral

        final messages = requestBody['messages'] as List<dynamic>;
        expect(messages.length, equals(1));
        expect((messages[0] as Map<String, dynamic>)['role'], equals('user'));
        expect(
            (messages[0] as Map<String, dynamic>)['content'], equals(prompt));
      });

      test('should transcribe single chunk audio', () async {
        // Arrange - single chunk
        const transcribedText = 'Transcribed text from single segment.';
        final events = [
          createSseChunkEvent(content: transcribedText),
          createSseFinalEvent(),
        ];

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: events),
        );

        // Act
        final stream = repository.transcribeAudio(
          model: model,
          audioBase64: audioBase64,
          baseUrl: baseUrl,
          prompt: prompt,
        );

        final results = await stream.toList();

        // Assert
        expect(results.length, equals(1));
        expect(
            results[0].choices?.first.delta?.content, equals(transcribedText));
        expect(results[0].id, equals('chatcmpl-test'));
      });

      test('should transcribe audio without prompt', () async {
        // Arrange
        const expectedText = 'Transcribed text';
        final events = [
          createSseChunkEvent(content: expectedText),
          createSseFinalEvent(),
        ];

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: events),
        );

        // Act
        final stream = repository.transcribeAudio(
          model: model,
          audioBase64: audioBase64,
          baseUrl: baseUrl,
        );

        final results = await stream.toList();

        // Assert
        expect(results.length, equals(1));
        expect(results[0].choices?.first.delta?.content, equals(expectedText));

        final captured =
            verify(() => mockHttpClient.send(captureAny())).captured;
        final request = captured.first as http.Request;
        final requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        final messages = requestBody['messages'] as List<dynamic>;
        expect((messages[0] as Map<String, dynamic>)['content'],
            equals('Transcribe this audio.'));
      });

      test('should use custom max completion tokens', () async {
        // Arrange
        final events = [
          createSseChunkEvent(content: 'Text'),
          createSseFinalEvent(),
        ];

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: events),
        );

        // Act
        final stream = repository.transcribeAudio(
          model: model,
          audioBase64: audioBase64,
          baseUrl: baseUrl,
          maxCompletionTokens: 8000,
        );

        await stream.toList();

        // Assert
        final captured =
            verify(() => mockHttpClient.send(captureAny())).captured;
        final request = captured.first as http.Request;
        final requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        expect(requestBody['max_tokens'], equals(8000));
      });

      test('should include language hint when provided', () async {
        // Arrange
        final events = [
          createSseChunkEvent(content: 'Text'),
          createSseFinalEvent(),
        ];

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: events),
        );

        // Act
        final stream = repository.transcribeAudio(
          model: model,
          audioBase64: audioBase64,
          baseUrl: baseUrl,
          language: 'de',
        );

        await stream.toList();

        // Assert
        final captured =
            verify(() => mockHttpClient.send(captureAny())).captured;
        final request = captured.first as http.Request;
        final requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        expect(requestBody['language'], equals('de'));
      });

      test('should not include language hint for auto', () async {
        // Arrange
        final events = [
          createSseChunkEvent(content: 'Text'),
          createSseFinalEvent(),
        ];

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: events),
        );

        // Act
        final stream = repository.transcribeAudio(
          model: model,
          audioBase64: audioBase64,
          baseUrl: baseUrl,
          language: 'auto',
        );

        await stream.toList();

        // Assert
        final captured =
            verify(() => mockHttpClient.send(captureAny())).captured;
        final request = captured.first as http.Request;
        final requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        expect(requestBody.containsKey('language'), isFalse);
      });

      test('should throw ArgumentError for empty model', () {
        expect(
          () => repository
              .transcribeAudio(
                model: '',
                audioBase64: audioBase64,
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
              .transcribeAudio(
                model: model,
                audioBase64: audioBase64,
                baseUrl: '',
              )
              .toList(),
          throwsA(isA<ArgumentError>()
              .having((e) => e.message, 'message', 'Base URL cannot be empty')),
        );
      });

      test('should throw ArgumentError for empty audioBase64', () {
        expect(
          () => repository
              .transcribeAudio(
                model: model,
                audioBase64: '',
                baseUrl: baseUrl,
              )
              .toList(),
          throwsA(isA<ArgumentError>().having(
              (e) => e.message, 'message', 'Audio payload cannot be empty')),
        );
      });

      test('should handle HTTP error responses', () async {
        // Arrange
        final stream = Stream.fromIterable([utf8.encode('Server error')]);
        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => http.StreamedResponse(stream, 500),
        );

        // Act & Assert
        final transcriptionStream = repository.transcribeAudio(
          model: model,
          audioBase64: audioBase64,
          baseUrl: baseUrl,
        );

        expect(
          transcriptionStream.toList(),
          throwsA(isA<VoxtralInferenceException>()
              .having((e) => e.message, 'message', contains('HTTP 500'))
              .having((e) => e.statusCode, 'statusCode', 500)),
        );
      });

      test(
          'should throw VoxtralModelNotAvailableException when model is missing',
          () async {
        final stream = Stream.fromIterable([utf8.encode('Model not found')]);
        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => http.StreamedResponse(stream, 404),
        );

        final transcriptionStream = repository.transcribeAudio(
          model: model,
          audioBase64: audioBase64,
          baseUrl: baseUrl,
        );

        expect(
          transcriptionStream.toList(),
          throwsA(isA<VoxtralModelNotAvailableException>()
              .having((e) => e.modelName, 'modelName', model)
              .having((e) => e.statusCode, 'statusCode', 404)),
        );
      });

      test('should handle timeout', () {
        fakeAsync((FakeAsync async) {
          // Arrange
          when(() => mockHttpClient.send(any())).thenAnswer((_) async {
            await Future<void>.delayed(const Duration(seconds: 2));
            return createSseStreamedResponse(events: []);
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

          stream.toList().then((_) {
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

      test('should handle malformed SSE data gracefully', () async {
        // Arrange - mix valid and invalid SSE events
        const sseData = '''
data: {"id": "test", "choices": [{"delta": {"content": "Valid chunk"}, "index": 0, "finish_reason": null}], "object": "chat.completion.chunk", "created": 1234}

data: invalid json here

data: {"id": "test", "choices": [{"delta": {}, "index": 0, "finish_reason": "stop"}], "object": "chat.completion.chunk", "created": 1234}

data: [DONE]

''';

        final stream = Stream.fromIterable([utf8.encode(sseData)]);
        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => http.StreamedResponse(stream, 200),
        );

        // Act
        final transcriptionStream = repository.transcribeAudio(
          model: model,
          audioBase64: audioBase64,
          baseUrl: baseUrl,
        );

        final results = await transcriptionStream.toList();

        // Assert - should still get the valid chunk
        expect(results.length, equals(1));
        expect(results[0].choices?.first.delta?.content, equals('Valid chunk'));
      });

      test('should handle empty stream gracefully', () async {
        // Arrange - only [DONE] marker, no content
        const sseData = 'data: [DONE]\n\n';

        final stream = Stream.fromIterable([utf8.encode(sseData)]);
        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => http.StreamedResponse(stream, 200),
        );

        // Act
        final transcriptionStream = repository.transcribeAudio(
          model: model,
          audioBase64: audioBase64,
          baseUrl: baseUrl,
        );

        final results = await transcriptionStream.toList();

        // Assert - empty result for empty stream
        expect(results, isEmpty);
      });

      test('should handle multiple chunks with proper ordering', () async {
        // Arrange - 5 sequential chunks
        final events = [
          createSseChunkEvent(content: 'Chunk 1. '),
          createSseChunkEvent(content: 'Chunk 2. '),
          createSseChunkEvent(content: 'Chunk 3. '),
          createSseChunkEvent(content: 'Chunk 4. '),
          createSseChunkEvent(content: 'Chunk 5.'),
          createSseFinalEvent(),
        ];

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: events),
        );

        // Act
        final stream = repository.transcribeAudio(
          model: model,
          audioBase64: audioBase64,
          baseUrl: baseUrl,
        );

        final results = await stream.toList();

        // Assert - all chunks in order
        expect(results.length, equals(5));
        expect(results[0].choices?.first.delta?.content, equals('Chunk 1. '));
        expect(results[1].choices?.first.delta?.content, equals('Chunk 2. '));
        expect(results[2].choices?.first.delta?.content, equals('Chunk 3. '));
        expect(results[3].choices?.first.delta?.content, equals('Chunk 4. '));
        expect(results[4].choices?.first.delta?.content, equals('Chunk 5.'));
      });

      group('non-streaming mode', () {
        test('should transcribe audio without streaming', () async {
          // Arrange - non-streaming response
          final responseBody = {
            'id': 'chatcmpl-test',
            'object': 'chat.completion',
            'created': 1234567890,
            'choices': [
              {
                'index': 0,
                'message': {
                  'role': 'assistant',
                  'content': 'Transcribed text.'
                },
                'finish_reason': 'stop',
              }
            ],
          };

          when(() => mockHttpClient.post(
                any(),
                headers: any(named: 'headers'),
                body: any(named: 'body'),
              )).thenAnswer(
            (_) async => http.Response(jsonEncode(responseBody), 200),
          );

          // Act
          final stream = repository.transcribeAudio(
            model: model,
            audioBase64: audioBase64,
            baseUrl: baseUrl,
            prompt: prompt,
            stream: false,
          );

          final results = await stream.toList();

          // Assert
          expect(results.length, equals(1));
          expect(results[0].choices?.first.delta?.content,
              equals('Transcribed text.'));
          expect(results[0].id, equals('chatcmpl-test'));

          // Verify request body has stream: false
          final captured = verify(() => mockHttpClient.post(
                captureAny(),
                headers: any(named: 'headers'),
                body: captureAny(named: 'body'),
              )).captured;
          final requestBody =
              jsonDecode(captured[1] as String) as Map<String, dynamic>;
          expect(requestBody['stream'], isFalse);
        });

        test('should handle 404 error in non-streaming mode', () async {
          when(() => mockHttpClient.post(
                any(),
                headers: any(named: 'headers'),
                body: any(named: 'body'),
              )).thenAnswer(
            (_) async => http.Response('Model not found', 404),
          );

          final stream = repository.transcribeAudio(
            model: model,
            audioBase64: audioBase64,
            baseUrl: baseUrl,
            stream: false,
          );

          expect(
            stream.toList(),
            throwsA(isA<VoxtralModelNotAvailableException>()
                .having((e) => e.statusCode, 'statusCode', 404)),
          );
        });

        test('should handle HTTP error in non-streaming mode', () async {
          when(() => mockHttpClient.post(
                any(),
                headers: any(named: 'headers'),
                body: any(named: 'body'),
              )).thenAnswer(
            (_) async => http.Response('Server error', 500),
          );

          final stream = repository.transcribeAudio(
            model: model,
            audioBase64: audioBase64,
            baseUrl: baseUrl,
            stream: false,
          );

          expect(
            stream.toList(),
            throwsA(isA<VoxtralInferenceException>()
                .having((e) => e.statusCode, 'statusCode', 500)),
          );
        });

        test('should handle empty choices in non-streaming mode', () async {
          final responseBody = {
            'id': 'test',
            'object': 'chat.completion',
            'created': 1234567890,
            'choices': <dynamic>[],
          };

          when(() => mockHttpClient.post(
                any(),
                headers: any(named: 'headers'),
                body: any(named: 'body'),
              )).thenAnswer(
            (_) async => http.Response(jsonEncode(responseBody), 200),
          );

          final stream = repository.transcribeAudio(
            model: model,
            audioBase64: audioBase64,
            baseUrl: baseUrl,
            stream: false,
          );

          final results = await stream.toList();
          expect(results, isEmpty);
        });

        test('should use fallback id when missing in non-streaming mode',
            () async {
          final responseBody = {
            'object': 'chat.completion',
            'choices': [
              {
                'index': 0,
                'message': {'role': 'assistant', 'content': 'Text'},
                'finish_reason': 'stop',
              }
            ],
          };

          when(() => mockHttpClient.post(
                any(),
                headers: any(named: 'headers'),
                body: any(named: 'body'),
              )).thenAnswer(
            (_) async => http.Response(jsonEncode(responseBody), 200),
          );

          final stream = repository.transcribeAudio(
            model: model,
            audioBase64: audioBase64,
            baseUrl: baseUrl,
            stream: false,
          );

          final results = await stream.toList();
          expect(results.length, equals(1));
          expect(results[0].id, startsWith('voxtral-'));
        });

        test('should handle timeout in non-streaming mode', () {
          fakeAsync((FakeAsync async) {
            when(() => mockHttpClient.post(
                  any(),
                  headers: any(named: 'headers'),
                  body: any(named: 'body'),
                )).thenAnswer((_) async {
              await Future<void>.delayed(const Duration(seconds: 2));
              return http.Response('{}', 200);
            });

            Object? error;
            var completed = false;
            final stream = repository.transcribeAudio(
              model: model,
              audioBase64: audioBase64,
              baseUrl: baseUrl,
              stream: false,
              timeout: const Duration(milliseconds: 100),
            );

            stream.toList().then((_) {
              completed = true;
            }, onError: (Object e) {
              error = e;
              completed = true;
            });

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

    group('exception logging with LoggingService', () {
      const model = 'mistralai/Voxtral-Mini-3B-2507';
      const baseUrl = 'http://localhost:11344';
      const audioBase64 = 'base64_audio_data';
      late MockLoggingService mockLoggingService;

      setUp(() {
        mockLoggingService = MockLoggingService();
        // Register LoggingService in GetIt
        if (GetIt.instance.isRegistered<LoggingService>()) {
          GetIt.instance.unregister<LoggingService>();
        }
        GetIt.instance.registerSingleton<LoggingService>(mockLoggingService);
      });

      tearDown(() {
        if (GetIt.instance.isRegistered<LoggingService>()) {
          GetIt.instance.unregister<LoggingService>();
        }
      });

      test('should log exception when model is not available', () async {
        // Arrange
        when(
          () => mockLoggingService.captureException(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String?>(named: 'subDomain'),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          ),
        ).thenReturn(null);

        final stream = Stream.fromIterable([utf8.encode('Not found')]);
        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => http.StreamedResponse(stream, 404),
        );

        // Act & Assert
        final transcriptionStream = repository.transcribeAudio(
          model: model,
          audioBase64: audioBase64,
          baseUrl: baseUrl,
        );

        expect(
          transcriptionStream.toList(),
          throwsA(isA<VoxtralModelNotAvailableException>()),
        );

        // Wait for the stream to be consumed and exception logged
        await Future<void>.delayed(Duration.zero);

        verify(
          () => mockLoggingService.captureException(
            any<Object>(that: isA<VoxtralModelNotAvailableException>()),
            domain: 'VOXTRAL',
            subDomain: 'model_not_available',
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          ),
        ).called(1);
      });

      test('should log exception on HTTP error', () async {
        // Arrange
        when(
          () => mockLoggingService.captureException(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String?>(named: 'subDomain'),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          ),
        ).thenReturn(null);

        final stream = Stream.fromIterable([utf8.encode('Server error')]);
        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => http.StreamedResponse(stream, 500),
        );

        // Act & Assert
        final transcriptionStream = repository.transcribeAudio(
          model: model,
          audioBase64: audioBase64,
          baseUrl: baseUrl,
        );

        expect(
          transcriptionStream.toList(),
          throwsA(isA<VoxtralInferenceException>()),
        );

        // Wait for the stream to be consumed and exception logged
        await Future<void>.delayed(Duration.zero);

        verify(
          () => mockLoggingService.captureException(
            any<Object>(that: isA<VoxtralInferenceException>()),
            domain: 'VOXTRAL',
            subDomain: 'http_error',
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          ),
        ).called(1);
      });

      test('should log exception on unexpected error', () async {
        // Arrange
        when(
          () => mockLoggingService.captureException(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String?>(named: 'subDomain'),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          ),
        ).thenReturn(null);

        // Throw a StateError to trigger the generic catch block
        when(() => mockHttpClient.send(any()))
            .thenThrow(StateError('Unexpected error'));

        // Act & Assert
        final transcriptionStream = repository.transcribeAudio(
          model: model,
          audioBase64: audioBase64,
          baseUrl: baseUrl,
        );

        expect(
          transcriptionStream.toList(),
          throwsA(isA<VoxtralInferenceException>()
              .having((e) => e.message, 'message', contains('Unexpected'))),
        );

        // Wait for exception to be logged
        await Future<void>.delayed(Duration.zero);

        verify(
          () => mockLoggingService.captureException(
            any<Object>(that: isA<StateError>()),
            domain: 'VOXTRAL',
            subDomain: 'unexpected',
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          ),
        ).called(1);
      });
    });

    group('edge cases', () {
      const model = 'mistralai/Voxtral-Mini-3B-2507';
      const baseUrl = 'http://localhost:11344';
      const audioBase64 = 'base64_audio_data';

      test('should use fallback id and created when missing from response',
          () async {
        // Arrange - response without id and created
        const sseData = '''
data: {"choices": [{"delta": {"content": "Transcribed text"}, "index": 0, "finish_reason": null}], "object": "chat.completion.chunk"}

data: [DONE]

''';

        final stream = Stream.fromIterable([utf8.encode(sseData)]);
        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => http.StreamedResponse(stream, 200),
        );

        // Act
        final transcriptionStream = repository.transcribeAudio(
          model: model,
          audioBase64: audioBase64,
          baseUrl: baseUrl,
        );

        final results = await transcriptionStream.toList();

        // Assert - should generate fallback id starting with 'voxtral-'
        expect(results.length, equals(1));
        expect(results[0].id, startsWith('voxtral-'));
        expect(results[0].created, isPositive);
      });

      test('should handle unknown finish_reason with orElse fallback',
          () async {
        // Arrange - response with unknown finish_reason
        final events = [
          {
            'id': 'test-id',
            'object': 'chat.completion.chunk',
            'created': 1234567890,
            'choices': [
              {
                'index': 0,
                'delta': {'content': 'Text'},
                'finish_reason': 'unknown_reason', // Not a valid enum value
              }
            ],
          },
        ];

        final sseData =
            '${events.map((e) => 'data: ${jsonEncode(e)}\n\n').join()}data: [DONE]\n\n';

        final stream = Stream.fromIterable([utf8.encode(sseData)]);
        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => http.StreamedResponse(stream, 200),
        );

        // Act
        final transcriptionStream = repository.transcribeAudio(
          model: model,
          audioBase64: audioBase64,
          baseUrl: baseUrl,
        );

        final results = await transcriptionStream.toList();

        // Assert - should fallback to 'stop' for unknown finish reason
        expect(results.length, equals(1));
        expect(results[0].choices?.first.finishReason,
            equals(ChatCompletionFinishReason.stop));
      });

      test('should handle stop signal with empty content', () async {
        // Arrange - content chunk followed by stop with empty content
        const sseData = '''
data: {"id": "test", "choices": [{"delta": {"content": "Some text"}, "index": 0, "finish_reason": null}], "object": "chat.completion.chunk", "created": 1234}

data: {"id": "test", "choices": [{"delta": {"content": ""}, "index": 0, "finish_reason": "stop"}], "object": "chat.completion.chunk", "created": 1234}

data: [DONE]

''';

        final stream = Stream.fromIterable([utf8.encode(sseData)]);
        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => http.StreamedResponse(stream, 200),
        );

        // Act
        final transcriptionStream = repository.transcribeAudio(
          model: model,
          audioBase64: audioBase64,
          baseUrl: baseUrl,
        );

        final results = await transcriptionStream.toList();

        // Assert - should only yield the chunk with content, not the empty stop chunk
        expect(results.length, equals(1));
        expect(results[0].choices?.first.delta?.content, equals('Some text'));
      });

      test('should not include language hint for empty string', () async {
        // Arrange
        final events = [
          createSseChunkEvent(content: 'Text'),
          createSseFinalEvent(),
        ];

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: events),
        );

        // Act
        final stream = repository.transcribeAudio(
          model: model,
          audioBase64: audioBase64,
          baseUrl: baseUrl,
          language: '', // Empty string should not be included
        );

        await stream.toList();

        // Assert
        final captured =
            verify(() => mockHttpClient.send(captureAny())).captured;
        final request = captured.first as http.Request;
        final requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        expect(requestBody.containsKey('language'), isFalse);
      });

      test('should handle timeout with 1 minute message', () {
        fakeAsync((FakeAsync async) {
          // Arrange
          when(() => mockHttpClient.send(any())).thenAnswer((_) async {
            await Future<void>.delayed(const Duration(minutes: 2));
            return createSseStreamedResponse(events: []);
          });

          // Act under fake time with exactly 1 minute timeout
          Object? error;
          var completed = false;
          final stream = repository.transcribeAudio(
            model: model,
            audioBase64: audioBase64,
            baseUrl: baseUrl,
            timeout: const Duration(minutes: 1), // Exactly 1 minute
          );

          stream.toList().then((_) {
            completed = true;
          }, onError: (Object e) {
            error = e;
            completed = true;
          });

          // Drive time to trigger timeout
          final plan = buildRetryBackoffPlan(
            maxRetries: 1,
            timeout: const Duration(minutes: 1),
            baseDelay: Duration.zero,
            epsilon: const Duration(seconds: 1),
          );
          async.elapseRetryPlan(plan);

          expect(completed, isTrue);
          final err = error;
          expect(err, isA<VoxtralInferenceException>());
          if (err is VoxtralInferenceException) {
            // Should use singular "1 minute" not "1 minutes"
            expect(err.message, contains('1 minute'));
            expect(err.message, isNot(contains('1 minutes')));
          }
        });
      });

      test('should handle chunks with null choices', () async {
        // Arrange - response with null choices
        const sseData = '''
data: {"id": "test", "choices": null, "object": "chat.completion.chunk", "created": 1234}

data: {"id": "test", "choices": [{"delta": {"content": "Valid"}, "index": 0, "finish_reason": null}], "object": "chat.completion.chunk", "created": 1234}

data: [DONE]

''';

        final stream = Stream.fromIterable([utf8.encode(sseData)]);
        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => http.StreamedResponse(stream, 200),
        );

        // Act
        final transcriptionStream = repository.transcribeAudio(
          model: model,
          audioBase64: audioBase64,
          baseUrl: baseUrl,
        );

        final results = await transcriptionStream.toList();

        // Assert - should skip null choices and only yield valid chunk
        expect(results.length, equals(1));
        expect(results[0].choices?.first.delta?.content, equals('Valid'));
      });

      test('should handle chunks with empty choices array', () async {
        // Arrange - response with empty choices array
        const sseData = '''
data: {"id": "test", "choices": [], "object": "chat.completion.chunk", "created": 1234}

data: {"id": "test", "choices": [{"delta": {"content": "Valid"}, "index": 0, "finish_reason": null}], "object": "chat.completion.chunk", "created": 1234}

data: [DONE]

''';

        final stream = Stream.fromIterable([utf8.encode(sseData)]);
        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => http.StreamedResponse(stream, 200),
        );

        // Act
        final transcriptionStream = repository.transcribeAudio(
          model: model,
          audioBase64: audioBase64,
          baseUrl: baseUrl,
        );

        final results = await transcriptionStream.toList();

        // Assert - should skip empty choices and only yield valid chunk
        expect(results.length, equals(1));
        expect(results[0].choices?.first.delta?.content, equals('Valid'));
      });

      test('should handle chunks with null delta', () async {
        // Arrange - response with null delta
        const sseData = '''
data: {"id": "test", "choices": [{"delta": null, "index": 0, "finish_reason": null}], "object": "chat.completion.chunk", "created": 1234}

data: {"id": "test", "choices": [{"delta": {"content": "Valid"}, "index": 0, "finish_reason": null}], "object": "chat.completion.chunk", "created": 1234}

data: [DONE]

''';

        final stream = Stream.fromIterable([utf8.encode(sseData)]);
        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => http.StreamedResponse(stream, 200),
        );

        // Act
        final transcriptionStream = repository.transcribeAudio(
          model: model,
          audioBase64: audioBase64,
          baseUrl: baseUrl,
        );

        final results = await transcriptionStream.toList();

        // Assert - should skip null delta and only yield valid chunk
        expect(results.length, equals(1));
        expect(results[0].choices?.first.delta?.content, equals('Valid'));
      });

      test('should handle chunks with null content in delta', () async {
        // Arrange - response with null content
        const sseData = '''
data: {"id": "test", "choices": [{"delta": {"content": null}, "index": 0, "finish_reason": null}], "object": "chat.completion.chunk", "created": 1234}

data: {"id": "test", "choices": [{"delta": {"content": "Valid"}, "index": 0, "finish_reason": null}], "object": "chat.completion.chunk", "created": 1234}

data: [DONE]

''';

        final stream = Stream.fromIterable([utf8.encode(sseData)]);
        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => http.StreamedResponse(stream, 200),
        );

        // Act
        final transcriptionStream = repository.transcribeAudio(
          model: model,
          audioBase64: audioBase64,
          baseUrl: baseUrl,
        );

        final results = await transcriptionStream.toList();

        // Assert - should skip null content and only yield valid chunk
        expect(results.length, equals(1));
        expect(results[0].choices?.first.delta?.content, equals('Valid'));
      });
    });

    group('downloadModel edge cases', () {
      test('should wrap network exception in VoxtralInferenceException',
          () async {
        // Arrange - throw a non-VoxtralInferenceException
        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenThrow(Exception('Network timeout'));

        // Act & Assert
        expect(
          () => repository.downloadModel(),
          throwsA(isA<VoxtralInferenceException>()
              .having((e) => e.message, 'message', contains('Network timeout'))
              .having((e) => e.originalError, 'originalError', isA<Exception>())
              .having((e) => e.statusCode, 'statusCode', isNull)),
        );
      });
    });

    group('checkHealth edge cases', () {
      test('should handle missing optional fields in health response',
          () async {
        // Arrange - response with only status field
        final responseBody = {
          'status': 'healthy',
        };

        when(() => mockHttpClient.get(any())).thenAnswer(
          (_) async => http.Response(jsonEncode(responseBody), 200),
        );

        // Act
        final result = await repository.checkHealth();

        // Assert - should use default values for missing fields
        expect(result.isHealthy, isTrue);
        expect(result.modelAvailable, isFalse); // Default
        expect(result.modelLoaded, isFalse); // Default
        expect(result.device, equals('unknown')); // Default
        expect(result.maxAudioMinutes, equals(30)); // Default
      });

      test('should handle non-healthy status', () async {
        // Arrange - response with unhealthy status
        final responseBody = {
          'status': 'unhealthy',
          'model_available': true,
          'model_loaded': false,
          'device': 'cpu',
          'max_audio_minutes': 15.0,
        };

        when(() => mockHttpClient.get(any())).thenAnswer(
          (_) async => http.Response(jsonEncode(responseBody), 200),
        );

        // Act
        final result = await repository.checkHealth();

        // Assert - isHealthy should be false for non-'healthy' status
        expect(result.isHealthy, isFalse);
        expect(result.modelAvailable, isTrue);
        expect(result.modelLoaded, isFalse);
        expect(result.device, equals('cpu'));
        expect(result.maxAudioMinutes, equals(15.0));
      });
    });
  });
}
