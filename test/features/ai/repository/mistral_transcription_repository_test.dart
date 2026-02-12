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

      test('includes context_bias field with single-word terms', () async {
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

        await repo.transcribeAudio(
          model: testModel,
          audioBase64: testAudioBase64,
          baseUrl: testBaseUrl,
          apiKey: testApiKey,
          contextBias: ['macOS', 'Flutter', 'Kirkjubæjarklaustur'],
        ).toList();

        expect(capturedRequest, isA<http.MultipartRequest>());
        final multipart = capturedRequest! as http.MultipartRequest;
        expect(multipart.fields['model'], equals(testModel));
        expect(
          multipart.fields['context_bias'],
          equals('macOS,Flutter,Kirkjubæjarklaustur'),
        );
        expect(multipart.files, hasLength(1));
        expect(multipart.files.first.field, equals('file'));
        expect(multipart.files.first.filename, equals('audio.m4a'));
      });

      test('splits multi-word terms into individual words', () async {
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

        await repo.transcribeAudio(
          model: testModel,
          audioBase64: testAudioBase64,
          baseUrl: testBaseUrl,
          apiKey: testApiKey,
          contextBias: ['Claude Code', 'macOS', 'Nano Banana Pro'],
        ).toList();

        final multipart = capturedRequest! as http.MultipartRequest;
        final terms = multipart.fields['context_bias']!.split(',');
        expect(terms, containsAll(['Claude', 'Code', 'macOS', 'Nano']));
        expect(terms, containsAll(['Banana', 'Pro']));
        // Each term should be a single word (no spaces)
        for (final term in terms) {
          expect(term, isNot(contains(' ')));
        }
      });

      test('deduplicates words from multi-word terms', () async {
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

        await repo.transcribeAudio(
          model: testModel,
          audioBase64: testAudioBase64,
          baseUrl: testBaseUrl,
          apiKey: testApiKey,
          contextBias: ['Gemini Pro', 'Gemini Flash'],
        ).toList();

        final multipart = capturedRequest! as http.MultipartRequest;
        final terms = multipart.fields['context_bias']!.split(',');
        // "Gemini" appears in both terms but should only appear once
        expect(
          terms.where((t) => t == 'Gemini').length,
          equals(1),
        );
        expect(terms, containsAll(['Gemini', 'Pro', 'Flash']));
      });

      test('does not include context_bias field when null', () async {
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
        expect(multipart.fields.containsKey('context_bias'), isFalse);
      });

      test('does not include context_bias field when empty', () async {
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

        await repo.transcribeAudio(
          model: testModel,
          audioBase64: testAudioBase64,
          baseUrl: testBaseUrl,
          apiKey: testApiKey,
          contextBias: [],
        ).toList();

        final multipart = capturedRequest! as http.MultipartRequest;
        expect(multipart.fields.containsKey('context_bias'), isFalse);
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

      test('includes diarization fields in request', () async {
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
              baseUrl: testBaseUrl,
              apiKey: testApiKey,
            )
            .toList();

        final multipart = capturedRequest! as http.MultipartRequest;
        expect(multipart.fields['diarize'], equals('true'));
        expect(
          multipart.fields['timestamp_granularities'],
          equals('segment'),
        );
      });

      test('formats diarized response with speaker labels', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'text': 'Hello how are you I am fine thanks',
              'segments': [
                {
                  'speaker_id': 0,
                  'text': 'Hello how are you',
                  'start': 0.0,
                  'end': 2.5,
                },
                {
                  'speaker_id': 1,
                  'text': 'I am fine thanks',
                  'start': 2.5,
                  'end': 5.0,
                },
              ],
            }),
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

        final content = responses.first.choices?.first.delta?.content;
        expect(content, contains('[Speaker 1]'));
        expect(content, contains('[Speaker 2]'));
        expect(content, contains('Hello how are you'));
        expect(content, contains('I am fine thanks'));
      });

      test('groups consecutive segments from same speaker', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'text': 'Hello. How are you? Fine thanks.',
              'segments': [
                {
                  'speaker_id': 0,
                  'text': 'Hello.',
                  'start': 0.0,
                  'end': 1.0,
                },
                {
                  'speaker_id': 0,
                  'text': 'How are you?',
                  'start': 1.0,
                  'end': 2.5,
                },
                {
                  'speaker_id': 1,
                  'text': 'Fine thanks.',
                  'start': 2.5,
                  'end': 4.0,
                },
                {
                  'speaker_id': 0,
                  'text': 'Great!',
                  'start': 4.0,
                  'end': 5.0,
                },
              ],
            }),
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

        final content = responses.first.choices?.first.delta?.content;
        // Speaker 1's consecutive segments should be joined
        expect(
          content,
          equals(
            '[Speaker 1]\n'
            'Hello. How are you?\n'
            '\n'
            '[Speaker 2]\n'
            'Fine thanks.\n'
            '\n'
            '[Speaker 1]\n'
            'Great!',
          ),
        );
      });

      test('falls back to text field when no segments', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'text': 'Plain transcription without segments'}),
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

        expect(
          responses.first.choices?.first.delta?.content,
          equals('Plain transcription without segments'),
        );
      });

      test('falls back to text when single speaker in segments', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'text': 'Single speaker monologue',
              'segments': [
                {
                  'speaker_id': 0,
                  'text': 'Single speaker',
                  'start': 0.0,
                  'end': 1.5,
                },
                {
                  'speaker_id': 0,
                  'text': 'monologue',
                  'start': 1.5,
                  'end': 3.0,
                },
              ],
            }),
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

        // Should use plain text, not formatted with speaker labels
        expect(
          responses.first.choices?.first.delta?.content,
          equals('Single speaker monologue'),
        );
      });

      test('falls back to text when segments lack speaker info', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'text': 'Segments without speaker attribution',
              'segments': [
                {'text': 'First segment', 'start': 0.0, 'end': 1.0},
                {'text': 'Second segment', 'start': 1.0, 'end': 2.0},
              ],
            }),
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

        expect(
          responses.first.choices?.first.delta?.content,
          equals('Segments without speaker attribution'),
        );
      });

      test('uses 1-based speaker numbering', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'text': 'A B C',
              'segments': [
                {'speaker_id': 0, 'text': 'A', 'start': 0.0, 'end': 1.0},
                {'speaker_id': 2, 'text': 'B', 'start': 1.0, 'end': 2.0},
                {'speaker_id': 1, 'text': 'C', 'start': 2.0, 'end': 3.0},
              ],
            }),
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

        final content = responses.first.choices?.first.delta?.content;
        // API speaker 0 → [Speaker 1], speaker 2 → [Speaker 3],
        // speaker 1 → [Speaker 2]
        expect(content, contains('[Speaker 1]'));
        expect(content, contains('[Speaker 3]'));
        expect(content, contains('[Speaker 2]'));
        expect(content, isNot(contains('[Speaker 0]')));
      });

      test('skips empty segments in diarized response', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'text': 'Hello World',
              'segments': [
                {'speaker_id': 0, 'text': 'Hello', 'start': 0.0, 'end': 1.0},
                {'speaker_id': 1, 'text': '  ', 'start': 1.0, 'end': 1.5},
                {'speaker_id': 1, 'text': 'World', 'start': 1.5, 'end': 2.0},
              ],
            }),
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

        final content = responses.first.choices?.first.delta?.content;
        // The empty segment should be skipped, not produce extra whitespace
        expect(
          content,
          equals(
            '[Speaker 1]\n'
            'Hello\n'
            '\n'
            '[Speaker 2]\n'
            'World',
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
