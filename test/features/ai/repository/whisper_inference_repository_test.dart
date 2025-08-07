import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/repository/whisper_inference_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockHttpClient extends Mock implements http.Client {}

class FakeUri extends Fake implements Uri {}

void main() {
  late WhisperInferenceRepository repository;
  late MockHttpClient mockHttpClient;

  setUpAll(() {
    registerFallbackValue(FakeUri());
  });

  setUp(() {
    mockHttpClient = MockHttpClient();
    repository = WhisperInferenceRepository(httpClient: mockHttpClient);
  });

  tearDown(() {
    mockHttpClient.close();
  });

  group('WhisperInferenceRepository', () {
    const baseUrl = 'http://localhost:8084';
    const model = 'whisper-1';
    const prompt = 'Test prompt';
    const audioBase64 = 'base64-encoded-audio-data';

    group('transcribeAudio', () {
      test('successfully transcribes audio', () async {
        // Arrange
        const transcribedText = 'This is the transcribed text from audio.';

        when(() => mockHttpClient.post(
              Uri.parse('$baseUrl/v1/audio/transcriptions'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'model': model,
                'audio': audioBase64,
              }),
            )).thenAnswer((_) async => http.Response(
              jsonEncode({'text': transcribedText}),
              200,
            ));

        // Act
        final stream = repository.transcribeAudio(
          model: model,
          audioBase64: audioBase64,
          baseUrl: baseUrl,
          prompt: prompt,
        );

        final response = await stream.first;

        // Assert
        expect(stream.isBroadcast, isTrue);
        expect(response.choices, hasLength(1));
        expect(response.choices?[0].delta?.content, equals(transcribedText));
        expect(response.id, startsWith('whisper-'));
        expect(response.object, equals('chat.completion.chunk'));
        expect(response.created, isA<int>());

        // Verify HTTP call
        verify(() => mockHttpClient.post(
              Uri.parse('$baseUrl/v1/audio/transcriptions'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'model': model,
                'audio': audioBase64,
              }),
            )).called(1);
      });

      test('handles empty audio data gracefully', () async {
        // Arrange
        const emptyAudioBase64 = '';
        const transcribedText = ''; // Empty transcription for empty audio

        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => http.Response(
              jsonEncode({'text': transcribedText}),
              200,
            ));

        // Act
        final stream = repository.transcribeAudio(
          prompt: prompt,
          model: model,
          audioBase64: emptyAudioBase64,
          baseUrl: baseUrl,
        );

        final response = await stream.first;

        // Assert
        expect(response.choices?[0].delta?.content, equals(transcribedText));
      });

      test('throws WhisperTranscriptionException on HTTP error', () async {
        // Arrange
        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => http.Response(
              'Internal Server Error',
              500,
            ));

        // Act
        final stream = repository.transcribeAudio(
          model: model,
          audioBase64: audioBase64,
          baseUrl: baseUrl,
          prompt: prompt,
        );

        // Assert
        await expectLater(
          stream.first,
          throwsA(
            isA<WhisperTranscriptionException>()
                .having((e) => e.message, 'message',
                    contains('Failed to transcribe audio (HTTP 500)'))
                .having((e) => e.statusCode, 'statusCode', 500),
          ),
        );
      });

      test('throws WhisperTranscriptionException on invalid JSON response',
          () async {
        // Arrange
        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => http.Response(
              'Not valid JSON',
              200,
            ));

        // Act
        final stream = repository.transcribeAudio(
          model: model,
          audioBase64: audioBase64,
          baseUrl: baseUrl,
          prompt: prompt,
        );

        // Assert
        await expectLater(
          stream.first,
          throwsA(
            isA<WhisperTranscriptionException>()
                .having((e) => e.message, 'message',
                    contains('Invalid response format'))
                .having((e) => e.originalError, 'originalError',
                    isA<FormatException>()),
          ),
        );
      });

      test('throws WhisperTranscriptionException when text field is missing',
          () async {
        // Arrange
        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => http.Response(
              jsonEncode({'result': 'some value'}), // Missing 'text' field
              200,
            ));

        // Act
        final stream = repository.transcribeAudio(
          model: model,
          audioBase64: audioBase64,
          baseUrl: baseUrl,
          prompt: prompt,
        );

        // Assert
        await expectLater(
          stream.first,
          throwsA(
            isA<WhisperTranscriptionException>().having(
                (e) => e.message, 'message', contains('missing text field')),
          ),
        );
      });

      test('throws ArgumentError for empty model', () {
        // Act & Assert
        expect(
          () => repository.transcribeAudio(
            prompt: prompt,
            model: '',
            audioBase64: audioBase64,
            baseUrl: baseUrl,
          ),
          throwsA(isA<ArgumentError>().having((e) => e.message, 'message',
              contains('Model name cannot be empty'))),
        );
      });

      test('throws ArgumentError for empty baseUrl', () {
        // Act & Assert
        expect(
          () => repository.transcribeAudio(
            prompt: prompt,
            model: model,
            audioBase64: audioBase64,
            baseUrl: '',
          ),
          throwsA(isA<ArgumentError>().having((e) => e.message, 'message',
              contains('Base URL cannot be empty'))),
        );
      });

      test('accepts maxCompletionTokens parameter', () async {
        // Arrange
        const transcribedText = 'Transcribed text';
        const maxCompletionTokens = 1000;

        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => http.Response(
              jsonEncode({'text': transcribedText}),
              200,
            ));

        // Act
        final stream = repository.transcribeAudio(
          model: model,
          audioBase64: audioBase64,
          baseUrl: baseUrl,
          prompt: prompt,
          maxCompletionTokens: maxCompletionTokens,
        );

        final response = await stream.first;

        // Assert
        expect(response.choices?[0].delta?.content, equals(transcribedText));
        // maxCompletionTokens is accepted but not used by Whisper
      });

      test('handles network errors gracefully', () async {
        // Arrange
        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenThrow(Exception('Network error'));

        // Act
        final stream = repository.transcribeAudio(
          model: model,
          audioBase64: audioBase64,
          baseUrl: baseUrl,
          prompt: prompt,
        );

        // Assert
        await expectLater(
          stream.first,
          throwsA(
            isA<WhisperTranscriptionException>()
                .having((e) => e.message, 'message',
                    contains('Failed to transcribe audio'))
                .having(
                    (e) => e.originalError, 'originalError', isA<Exception>()),
          ),
        );
      });

      test('creates unique IDs for each transcription', () async {
        // Arrange
        const transcribedText = 'Test transcription';

        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((_) async {
          // Add a small delay to simulate network latency
          await Future<void>.delayed(const Duration(milliseconds: 1));
          return http.Response(
            jsonEncode({'text': transcribedText}),
            200,
          );
        });

        // Act
        final stream1 = repository.transcribeAudio(
          prompt: prompt,
          model: model,
          audioBase64: audioBase64,
          baseUrl: baseUrl,
        );

        // Wait a bit before starting second request to ensure different timestamp
        await Future<void>.delayed(const Duration(milliseconds: 2));

        final stream2 = repository.transcribeAudio(
          prompt: prompt,
          model: model,
          audioBase64: audioBase64,
          baseUrl: baseUrl,
        );

        final response1 = await stream1.first;
        final response2 = await stream2.first;

        // Assert
        expect(response1.id, isNot(equals(response2.id)));
        expect(response1.id, startsWith('whisper-'));
        expect(response2.id, startsWith('whisper-'));
      });

      test('preserves transcription with special characters', () async {
        // Arrange
        const transcribedText =
            'Special chars: @#\$%^&*()_+ "quotes" \'apostrophe\' \n newline';

        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => http.Response(
              jsonEncode({'text': transcribedText}),
              200,
            ));

        // Act
        final stream = repository.transcribeAudio(
          model: model,
          audioBase64: audioBase64,
          baseUrl: baseUrl,
          prompt: prompt,
        );

        final response = await stream.first;

        // Assert
        expect(response.choices?[0].delta?.content, equals(transcribedText));
      });

      test('handles very long transcriptions', () async {
        // Arrange
        final longText = 'A' * 10000; // 10,000 character transcription

        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => http.Response(
              jsonEncode({'text': longText}),
              200,
            ));

        // Act
        final stream = repository.transcribeAudio(
          model: model,
          audioBase64: audioBase64,
          baseUrl: baseUrl,
          prompt: prompt,
        );

        final response = await stream.first;

        // Assert
        expect(response.choices?[0].delta?.content, equals(longText));
        expect(response.choices?[0].delta?.content?.length, equals(10000));
      });

      test('sends correct request body to server', () async {
        // Arrange
        const transcribedText = 'Test';

        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => http.Response(
              jsonEncode({'text': transcribedText}),
              200,
            ));

        // Act
        await repository
            .transcribeAudio(
              prompt: prompt,
              model: model,
              audioBase64: audioBase64,
              baseUrl: baseUrl,
            )
            .first;

        // Assert
        final captured = verify(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: captureAny(named: 'body'),
            )).captured;

        final requestBody =
            jsonDecode(captured[0] as String) as Map<String, dynamic>;
        expect(requestBody['model'], equals(model));
        expect(requestBody['audio'], equals(audioBase64));
      });

      test('handles HTTP 400 Bad Request', () async {
        // Arrange
        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => http.Response(
              'Bad Request: Invalid audio format',
              400,
            ));

        // Act
        final stream = repository.transcribeAudio(
          model: model,
          audioBase64: audioBase64,
          baseUrl: baseUrl,
          prompt: prompt,
        );

        // Assert
        await expectLater(
          stream.first,
          throwsA(
            isA<WhisperTranscriptionException>()
                .having((e) => e.statusCode, 'statusCode', 400),
          ),
        );
      });

      test('handles HTTP 401 Unauthorized', () async {
        // Arrange
        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => http.Response(
              'Unauthorized',
              401,
            ));

        // Act
        final stream = repository.transcribeAudio(
          model: model,
          audioBase64: audioBase64,
          baseUrl: baseUrl,
          prompt: prompt,
        );

        // Assert
        await expectLater(
          stream.first,
          throwsA(
            isA<WhisperTranscriptionException>()
                .having((e) => e.statusCode, 'statusCode', 401),
          ),
        );
      });

      test('handles HTTP 429 Too Many Requests', () async {
        // Arrange
        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => http.Response(
              'Too Many Requests',
              429,
            ));

        // Act
        final stream = repository.transcribeAudio(
          model: model,
          audioBase64: audioBase64,
          baseUrl: baseUrl,
          prompt: prompt,
        );

        // Assert
        await expectLater(
          stream.first,
          throwsA(
            isA<WhisperTranscriptionException>()
                .having((e) => e.statusCode, 'statusCode', 429),
          ),
        );
      });
    });

    group('WhisperTranscriptionException', () {
      test('toString returns message', () {
        const message = 'Test error message';
        final exception = WhisperTranscriptionException(message);

        expect(exception.toString(), equals(message));
      });

      test('preserves status code', () {
        final exception = WhisperTranscriptionException(
          'Error',
          statusCode: 404,
        );

        expect(exception.statusCode, equals(404));
      });

      test('preserves original error', () {
        final originalError = Exception('Original');
        final exception = WhisperTranscriptionException(
          'Wrapped error',
          originalError: originalError,
        );

        expect(exception.originalError, equals(originalError));
      });
    });
  });
}
