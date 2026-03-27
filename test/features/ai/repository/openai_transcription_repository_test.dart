import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lotti/features/ai/repository/openai_transcription_repository.dart';
import 'package:lotti/features/ai/repository/transcription_exception.dart';

void main() {
  group('OpenAiTranscriptionRepository', () {
    group('isOpenAiTranscriptionModel', () {
      test('returns true for gpt-4o-transcribe', () {
        expect(
          OpenAiTranscriptionRepository.isOpenAiTranscriptionModel(
            'gpt-4o-transcribe',
          ),
          isTrue,
        );
      });

      test('returns true for gpt-4o-mini-transcribe', () {
        expect(
          OpenAiTranscriptionRepository.isOpenAiTranscriptionModel(
            'gpt-4o-mini-transcribe',
          ),
          isTrue,
        );
      });

      test('returns true for gpt-4o-transcribe-diarize', () {
        expect(
          OpenAiTranscriptionRepository.isOpenAiTranscriptionModel(
            'gpt-4o-transcribe-diarize',
          ),
          isTrue,
        );
      });

      test(
        'returns true for versioned variant gpt-4o-transcribe-2025-01-15',
        () {
          expect(
            OpenAiTranscriptionRepository.isOpenAiTranscriptionModel(
              'gpt-4o-transcribe-2025-01-15',
            ),
            isTrue,
          );
        },
      );

      test('returns false for gpt-4o', () {
        expect(
          OpenAiTranscriptionRepository.isOpenAiTranscriptionModel('gpt-4o'),
          isFalse,
        );
      });

      test('returns false for gpt-4o-mini', () {
        expect(
          OpenAiTranscriptionRepository.isOpenAiTranscriptionModel(
            'gpt-4o-mini',
          ),
          isFalse,
        );
      });

      test('returns false for empty string', () {
        expect(
          OpenAiTranscriptionRepository.isOpenAiTranscriptionModel(''),
          isFalse,
        );
      });
    });

    group('transcribeAudio', () {
      const testModel = 'gpt-4o-transcribe';
      const testApiKey = 'test-api-key';
      final testAudioBase64 = base64Encode([1, 2, 3]);

      test('throws ArgumentError for empty model', () {
        final repo = OpenAiTranscriptionRepository();

        expect(
          () => repo.transcribeAudio(
            model: '',
            audioBase64: testAudioBase64,
            apiKey: testApiKey,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError for empty audioBase64', () {
        final repo = OpenAiTranscriptionRepository();

        expect(
          () => repo.transcribeAudio(
            model: testModel,
            audioBase64: '',
            apiKey: testApiKey,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError for empty apiKey', () {
        final repo = OpenAiTranscriptionRepository();

        expect(
          () => repo.transcribeAudio(
            model: testModel,
            audioBase64: testAudioBase64,
            apiKey: '',
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test(
        'sends correct multipart request and returns transcription',
        () async {
          final mockClient = MockClient((request) async {
            expect(request.method, equals('POST'));
            expect(
              request.url.toString(),
              equals('https://api.openai.com/v1/audio/transcriptions'),
            );
            expect(
              request.headers['Authorization'],
              equals('Bearer $testApiKey'),
            );

            return http.Response(
              jsonEncode({'text': 'Hello, world!'}),
              200,
            );
          });

          final repo = OpenAiTranscriptionRepository(httpClient: mockClient);

          final responses = await repo
              .transcribeAudio(
                model: testModel,
                audioBase64: testAudioBase64,
                apiKey: testApiKey,
              )
              .toList();

          expect(responses, hasLength(1));
          expect(
            responses.first.choices?.first.delta?.content,
            'Hello, world!',
          );
          expect(responses.first.id, startsWith('openai-transcription-'));
        },
      );

      test('includes prompt field when provided', () async {
        http.BaseRequest? capturedRequest;

        final mockClient = MockClient.streaming(
          (request, _) async {
            capturedRequest = request;
            return http.StreamedResponse(
              Stream.value(
                utf8.encode(jsonEncode({'text': 'transcribed text'})),
              ),
              200,
            );
          },
        );

        final repo = OpenAiTranscriptionRepository(httpClient: mockClient);

        await repo
            .transcribeAudio(
              model: testModel,
              audioBase64: testAudioBase64,
              apiKey: testApiKey,
              prompt: 'This is a meeting about Flutter development.',
            )
            .toList();

        expect(capturedRequest, isA<http.MultipartRequest>());
        final multipart = capturedRequest! as http.MultipartRequest;
        expect(multipart.fields['model'], equals(testModel));
        expect(
          multipart.fields['prompt'],
          equals('This is a meeting about Flutter development.'),
        );
        expect(multipart.files, hasLength(1));
        expect(multipart.files.first.field, equals('file'));
        expect(multipart.files.first.filename, equals('audio.m4a'));
      });

      test('does not include prompt field when null', () async {
        http.BaseRequest? capturedRequest;

        final mockClient = MockClient.streaming(
          (request, _) async {
            capturedRequest = request;
            return http.StreamedResponse(
              Stream.value(
                utf8.encode(jsonEncode({'text': 'transcribed text'})),
              ),
              200,
            );
          },
        );

        final repo = OpenAiTranscriptionRepository(httpClient: mockClient);

        await repo
            .transcribeAudio(
              model: testModel,
              audioBase64: testAudioBase64,
              apiKey: testApiKey,
            )
            .toList();

        final multipart = capturedRequest! as http.MultipartRequest;
        expect(multipart.fields.containsKey('prompt'), isFalse);
      });

      test('throws TranscriptionException on HTTP error', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'error': {'message': 'Bad request: invalid model'},
            }),
            400,
          );
        });

        final repo = OpenAiTranscriptionRepository(httpClient: mockClient);

        await expectLater(
          repo
              .transcribeAudio(
                model: testModel,
                audioBase64: testAudioBase64,
                apiKey: testApiKey,
              )
              .toList(),
          throwsA(
            isA<TranscriptionException>()
                .having(
                  (e) => e.statusCode,
                  'statusCode',
                  400,
                )
                .having(
                  (e) => e.message,
                  'message',
                  'Bad request: invalid model',
                ),
          ),
        );
      });

      test('throws on HTTP error with non-JSON body', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Internal Server Error', 500);
        });

        final repo = OpenAiTranscriptionRepository(httpClient: mockClient);

        await expectLater(
          repo
              .transcribeAudio(
                model: testModel,
                audioBase64: testAudioBase64,
                apiKey: testApiKey,
              )
              .toList(),
          throwsA(
            isA<TranscriptionException>().having(
              (e) => e.statusCode,
              'statusCode',
              500,
            ),
          ),
        );
      });

      test('throws on missing text field in response', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'segments': <dynamic>[]}),
            200,
          );
        });

        final repo = OpenAiTranscriptionRepository(httpClient: mockClient);

        await expectLater(
          repo
              .transcribeAudio(
                model: testModel,
                audioBase64: testAudioBase64,
                apiKey: testApiKey,
              )
              .toList(),
          throwsA(
            isA<TranscriptionException>().having(
              (e) => e.message,
              'message',
              contains('missing text field'),
            ),
          ),
        );
      });

      test('wraps unexpected exceptions in TranscriptionException', () async {
        final mockClient = MockClient((request) async {
          throw Exception('Network error');
        });

        final repo = OpenAiTranscriptionRepository(httpClient: mockClient);

        await expectLater(
          repo
              .transcribeAudio(
                model: testModel,
                audioBase64: testAudioBase64,
                apiKey: testApiKey,
              )
              .toList(),
          throwsA(
            isA<TranscriptionException>().having(
              (e) => e.message,
              'message',
              contains('Failed to transcribe audio'),
            ),
          ),
        );
      });
    });
  });
}
