// ignore_for_file: avoid_redundant_argument_values

import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/repository/voxtral_inference_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../test_utils/retry_fake_time.dart';

class MockHttpClient extends Mock implements http.Client {}

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
