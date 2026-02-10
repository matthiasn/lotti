import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lotti/features/ai/repository/mistral_transcription_repository.dart';
import 'package:lotti/features/ai/repository/transcription_exception.dart';

void main() {
  group('MistralTranscriptionRepository', () {
    group('isMistralTranscriptionModel', () {
      test('returns true for voxtral-small-2507', () {
        expect(
          MistralTranscriptionRepository.isMistralTranscriptionModel(
            'voxtral-small-2507',
          ),
          isTrue,
        );
      });

      test('returns true for voxtral-mini-latest', () {
        expect(
          MistralTranscriptionRepository.isMistralTranscriptionModel(
            'voxtral-mini-latest',
          ),
          isTrue,
        );
      });

      test('returns true for voxtral-mini-2507', () {
        expect(
          MistralTranscriptionRepository.isMistralTranscriptionModel(
            'voxtral-mini-2507',
          ),
          isTrue,
        );
      });

      test('returns false for mistral-small-2501', () {
        expect(
          MistralTranscriptionRepository.isMistralTranscriptionModel(
            'mistral-small-2501',
          ),
          isFalse,
        );
      });

      test('returns false for magistral-medium-2509', () {
        expect(
          MistralTranscriptionRepository.isMistralTranscriptionModel(
            'magistral-medium-2509',
          ),
          isFalse,
        );
      });

      test('returns false for empty string', () {
        expect(
          MistralTranscriptionRepository.isMistralTranscriptionModel(''),
          isFalse,
        );
      });
    });

    group('transcribeAudio', () {
      const testModel = 'voxtral-small-2507';
      const testBaseUrl = 'https://api.mistral.ai/v1';
      const testApiKey = 'test-api-key';
      final testAudioBase64 = base64Encode([1, 2, 3, 4, 5]);

      test('sends multipart request and returns transcription', () async {
        final mockClient = MockClient((request) async {
          // Verify request structure
          expect(request.method, equals('POST'));
          expect(
            request.url.toString(),
            equals('https://api.mistral.ai/v1/audio/transcriptions'),
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

        final repo = MistralTranscriptionRepository(httpClient: mockClient);

        final responses = await repo
            .transcribeAudio(
              model: testModel,
              audioBase64: testAudioBase64,
              baseUrl: testBaseUrl,
              apiKey: testApiKey,
            )
            .toList();

        expect(responses, hasLength(1));
        expect(
          responses.first.choices?.first.delta?.content,
          'Hello, world!',
        );
        expect(responses.first.id, startsWith('mistral-transcription-'));
      });

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

        final repo = MistralTranscriptionRepository(httpClient: mockClient);

        await repo
            .transcribeAudio(
              model: testModel,
              audioBase64: testAudioBase64,
              baseUrl: testBaseUrl,
              apiKey: testApiKey,
              prompt: 'Context for transcription',
            )
            .toList();

        expect(capturedRequest, isA<http.MultipartRequest>());
        final multipart = capturedRequest! as http.MultipartRequest;
        expect(multipart.fields['model'], equals(testModel));
        expect(
          multipart.fields['prompt'],
          equals('Context for transcription'),
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

        final repo = MistralTranscriptionRepository(httpClient: mockClient);

        await repo
            .transcribeAudio(
              model: testModel,
              audioBase64: testAudioBase64,
              baseUrl: testBaseUrl,
              apiKey: testApiKey,
            )
            .toList();

        final multipart = capturedRequest! as http.MultipartRequest;
        expect(multipart.fields.containsKey('prompt'), isFalse);
      });

      test('does not include prompt field when empty', () async {
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

        final repo = MistralTranscriptionRepository(httpClient: mockClient);

        await repo
            .transcribeAudio(
              model: testModel,
              audioBase64: testAudioBase64,
              baseUrl: testBaseUrl,
              apiKey: testApiKey,
              prompt: '',
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

        final repo = MistralTranscriptionRepository(httpClient: mockClient);

        await expectLater(
          repo
              .transcribeAudio(
                model: testModel,
                audioBase64: testAudioBase64,
                baseUrl: testBaseUrl,
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

        final repo = MistralTranscriptionRepository(httpClient: mockClient);

        await expectLater(
          repo
              .transcribeAudio(
                model: testModel,
                audioBase64: testAudioBase64,
                baseUrl: testBaseUrl,
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

        final repo = MistralTranscriptionRepository(httpClient: mockClient);

        await expectLater(
          repo
              .transcribeAudio(
                model: testModel,
                audioBase64: testAudioBase64,
                baseUrl: testBaseUrl,
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

      test('throws ArgumentError for empty model', () {
        final repo = MistralTranscriptionRepository();

        expect(
          () => repo.transcribeAudio(
            model: '',
            audioBase64: testAudioBase64,
            baseUrl: testBaseUrl,
            apiKey: testApiKey,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError for empty audioBase64', () {
        final repo = MistralTranscriptionRepository();

        expect(
          () => repo.transcribeAudio(
            model: testModel,
            audioBase64: '',
            baseUrl: testBaseUrl,
            apiKey: testApiKey,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError for empty baseUrl', () {
        final repo = MistralTranscriptionRepository();

        expect(
          () => repo.transcribeAudio(
            model: testModel,
            audioBase64: testAudioBase64,
            baseUrl: '',
            apiKey: testApiKey,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError for empty apiKey', () {
        final repo = MistralTranscriptionRepository();

        expect(
          () => repo.transcribeAudio(
            model: testModel,
            audioBase64: testAudioBase64,
            baseUrl: testBaseUrl,
            apiKey: '',
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('constructs correct URL from base URL without trailing slash',
          () async {
        http.BaseRequest? capturedRequest;

        final mockClient = MockClient.streaming(
          (request, _) async {
            capturedRequest = request;
            return http.StreamedResponse(
              Stream.value(
                utf8.encode(jsonEncode({'text': 'ok'})),
              ),
              200,
            );
          },
        );

        final repo = MistralTranscriptionRepository(httpClient: mockClient);

        await repo
            .transcribeAudio(
              model: testModel,
              audioBase64: testAudioBase64,
              baseUrl: 'https://api.mistral.ai/v1',
              apiKey: testApiKey,
            )
            .toList();

        expect(
          capturedRequest!.url.toString(),
          equals('https://api.mistral.ai/v1/audio/transcriptions'),
        );
      });

      test('constructs correct URL from base URL with trailing slash',
          () async {
        http.BaseRequest? capturedRequest;

        final mockClient = MockClient.streaming(
          (request, _) async {
            capturedRequest = request;
            return http.StreamedResponse(
              Stream.value(
                utf8.encode(jsonEncode({'text': 'ok'})),
              ),
              200,
            );
          },
        );

        final repo = MistralTranscriptionRepository(httpClient: mockClient);

        await repo
            .transcribeAudio(
              model: testModel,
              audioBase64: testAudioBase64,
              baseUrl: 'https://api.mistral.ai/v1/',
              apiKey: testApiKey,
            )
            .toList();

        expect(
          capturedRequest!.url.toString(),
          equals('https://api.mistral.ai/v1/audio/transcriptions'),
        );
      });

      test('wraps unexpected exceptions in TranscriptionException', () async {
        final mockClient = MockClient((request) async {
          throw Exception('Network error');
        });

        final repo = MistralTranscriptionRepository(httpClient: mockClient);

        await expectLater(
          repo
              .transcribeAudio(
                model: testModel,
                audioBase64: testAudioBase64,
                baseUrl: testBaseUrl,
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

    group('TranscriptionException', () {
      test('toString includes provider and message', () {
        final exception = TranscriptionException(
          'Test error',
          provider: 'MistralTranscription',
        );
        expect(
          exception.toString(),
          equals('TranscriptionException(MistralTranscription): Test error'),
        );
      });

      test('stores statusCode and originalError', () {
        final original = Exception('original');
        final exception = TranscriptionException(
          'Test error',
          provider: 'MistralTranscription',
          statusCode: 500,
          originalError: original,
        );

        expect(exception.message, equals('Test error'));
        expect(exception.statusCode, equals(500));
        expect(exception.originalError, equals(original));
      });
    });
  });
}
