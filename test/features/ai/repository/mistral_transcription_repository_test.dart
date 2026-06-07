import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lotti/features/ai/repository/mistral_transcription_repository.dart';
import 'package:lotti/features/ai/repository/transcription_exception.dart';
import 'package:lotti/features/ai/state/consts.dart';

/// Streaming 200-OK stub that records the outgoing request — previously
/// repeated inline in every multipart-shape test. Returns one pre-built
/// client plus an accessor for the captured request.
({
  http.Client client,
  http.MultipartRequest Function() multipart,
})
_stubStreamingOk() {
  http.BaseRequest? captured;
  final client = MockClient.streaming((request, _) async {
    captured = request;
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode({'text': 'transcribed text'}))),
      200,
    );
  });
  return (
    client: client,
    multipart: () => captured! as http.MultipartRequest,
  );
}

void main() {
  group('MistralTranscriptionRepository', () {
    group('isMistralTranscriptionModel', () {
      test('classifies known model ids', () {
        const cases = {
          'voxtral-small-2507': true,
          'voxtral-mini-latest': true,
          'voxtral-mini-2507': true,
          'mistral-small-2501': false,
          'magistral-medium-2509': false,
          '': false,
        };
        for (final entry in cases.entries) {
          expect(
            MistralTranscriptionRepository.isMistralTranscriptionModel(
              entry.key,
            ),
            entry.value,
            reason: '"${entry.key}"',
          );
        }
      });

      // Property: the predicate is exactly a `voxtral-` prefix check.
      glados.Glados(
        glados.any.letterOrDigits,
        glados.ExploreConfig(numRuns: 120),
      ).test('matches iff the model id starts with voxtral-', (suffix) {
        expect(
          MistralTranscriptionRepository.isMistralTranscriptionModel(
            'voxtral-$suffix',
          ),
          isTrue,
          reason: 'voxtral-$suffix',
        );
        expect(
          MistralTranscriptionRepository.isMistralTranscriptionModel(suffix),
          suffix.startsWith('voxtral-'),
          reason: suffix,
        );
      }, tags: 'glados');
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

      test('includes context_bias field with dictionary terms', () async {
        final stub = _stubStreamingOk();
        final repo = MistralTranscriptionRepository(httpClient: stub.client);

        await repo
            .transcribeAudio(
              model: testModel,
              audioBase64: testAudioBase64,
              baseUrl: testBaseUrl,
              apiKey: testApiKey,
              contextBias: ['macOS', 'Flutter', 'Kirkjubæjarklaustur'],
            )
            .toList();

        final multipart = stub.multipart();
        expect(multipart.fields['model'], equals(testModel));
        expect(
          multipart.fields['context_bias'],
          equals('macOS,Flutter,Kirkjubæjarklaustur'),
        );
        expect(multipart.files, hasLength(1));
        expect(multipart.files.first.field, equals('file'));
        expect(multipart.files.first.filename, equals('audio.m4a'));
      });

      // Property: for any raw term list, the wire field is the trimmed,
      // de-duplicated, order-preserving prefix capped at 100 entries —
      // and it is omitted entirely when nothing survives normalisation.
      glados.Glados(
        glados.any.list(
          glados.AnyUtils(glados.any).choose(const [
            'macOS',
            ' macOS ',
            'Flutter',
            'Claude Code',
            '',
            '   ',
            'Kirkjubæjarklaustur',
            'Nano Banana Pro',
            '\ttabbed\t',
          ]),
        ),
        glados.ExploreConfig(numRuns: 60),
      ).test(
        'context_bias is trimmed, unique, capped, order-preserving',
        (
          rawTerms,
        ) async {
          final stub = _stubStreamingOk();
          final repo = MistralTranscriptionRepository(httpClient: stub.client);

          await repo
              .transcribeAudio(
                model: testModel,
                audioBase64: testAudioBase64,
                baseUrl: testBaseUrl,
                apiKey: testApiKey,
                contextBias: rawTerms,
              )
              .toList();

          // Oracle: trim, drop empties, dedupe preserving first occurrence,
          // cap at 100.
          final expected = <String>[];
          for (final term in rawTerms.map((t) => t.trim())) {
            if (term.isEmpty || expected.contains(term)) continue;
            expected.add(term);
            if (expected.length == 100) break;
          }

          final field = stub.multipart().fields['context_bias'];
          if (expected.isEmpty) {
            expect(field, isNull, reason: 'raw: $rawTerms');
          } else {
            final sent = field!.split(',');
            expect(sent, expected, reason: 'raw: $rawTerms');
            expect(sent.length, lessThanOrEqualTo(100));
            expect(sent.toSet().length, sent.length, reason: 'no duplicates');
          }
        },
        tags: 'glados',
      );

      test('preserves multi-word context_bias phrases', () async {
        final stub = _stubStreamingOk();
        final repo = MistralTranscriptionRepository(httpClient: stub.client);

        await repo
            .transcribeAudio(
              model: testModel,
              audioBase64: testAudioBase64,
              baseUrl: testBaseUrl,
              apiKey: testApiKey,
              contextBias: ['Claude Code', 'macOS', 'Nano Banana Pro'],
            )
            .toList();

        final multipart = stub.multipart();
        expect(
          multipart.fields['context_bias'],
          equals('Claude Code,macOS,Nano Banana Pro'),
        );
      });

      test('deduplicates repeated context_bias terms', () async {
        final stub = _stubStreamingOk();
        final repo = MistralTranscriptionRepository(httpClient: stub.client);

        await repo
            .transcribeAudio(
              model: testModel,
              audioBase64: testAudioBase64,
              baseUrl: testBaseUrl,
              apiKey: testApiKey,
              contextBias: ['Gemini Pro', 'Gemini Pro', 'Gemini Flash'],
            )
            .toList();

        final multipart = stub.multipart();
        final terms = multipart.fields['context_bias']!.split(',');
        expect(
          terms.where((t) => t == 'Gemini Pro').length,
          equals(1),
        );
        expect(terms, containsAll(['Gemini Pro', 'Gemini Flash']));
      });

      test('limits context_bias to 100 terms', () async {
        final stub = _stubStreamingOk();
        final repo = MistralTranscriptionRepository(httpClient: stub.client);

        await repo
            .transcribeAudio(
              model: testModel,
              audioBase64: testAudioBase64,
              baseUrl: testBaseUrl,
              apiKey: testApiKey,
              contextBias: List.generate(101, (index) => 'Term$index'),
            )
            .toList();

        final multipart = stub.multipart();
        final terms = multipart.fields['context_bias']!.split(',');
        expect(terms, hasLength(100));
        expect(terms.first, 'Term0');
        expect(terms.last, 'Term99');
      });

      test('does not include context_bias field when null', () async {
        final stub = _stubStreamingOk();
        final repo = MistralTranscriptionRepository(httpClient: stub.client);

        await repo
            .transcribeAudio(
              model: testModel,
              audioBase64: testAudioBase64,
              baseUrl: testBaseUrl,
              apiKey: testApiKey,
            )
            .toList();

        final multipart = stub.multipart();
        expect(multipart.fields.containsKey('context_bias'), isFalse);
      });

      test('does not include context_bias field when empty', () async {
        final stub = _stubStreamingOk();
        final repo = MistralTranscriptionRepository(httpClient: stub.client);

        await repo
            .transcribeAudio(
              model: testModel,
              audioBase64: testAudioBase64,
              baseUrl: testBaseUrl,
              apiKey: testApiKey,
              contextBias: [],
            )
            .toList();

        final multipart = stub.multipart();
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

      test(
        'constructs correct URL from base URL without trailing slash',
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
        },
      );

      test(
        'constructs correct URL from base URL with trailing slash',
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
        },
      );

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
        final stub = _stubStreamingOk();
        final repo = MistralTranscriptionRepository(httpClient: stub.client);

        await repo
            .transcribeAudio(
              model: testModel,
              audioBase64: testAudioBase64,
              baseUrl: testBaseUrl,
              apiKey: testApiKey,
            )
            .toList();

        final multipart = stub.multipart();
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

      test(
        'wraps TimeoutException thrown by the client in a 408 '
        'TranscriptionException',
        () async {
          // A raw TimeoutException bubbling out of the client (not the
          // .timeout() wrapper) is mapped to a 408 TranscriptionException
          // with the original error preserved.
          final original = TimeoutException('upstream stalled');
          final mockClient = MockClient((request) async {
            throw original;
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
                    httpStatusRequestTimeout,
                  )
                  .having((e) => e.message, 'message', contains('timed out'))
                  .having(
                    (e) => e.originalError,
                    'originalError',
                    same(original),
                  ),
            ),
          );
        },
      );

      test(
        'wraps FormatException from malformed 200 body in TranscriptionException',
        () async {
          // A 200 response whose body is not valid JSON makes jsonDecode throw
          // a FormatException, which is mapped to a format-error message.
          final mockClient = MockClient((request) async {
            return http.Response('not json {{{', 200);
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
                    (e) => e.message,
                    'message',
                    'Invalid response format from transcription service',
                  )
                  .having(
                    (e) => e.originalError,
                    'originalError',
                    isA<FormatException>(),
                  )
                  .having((e) => e.statusCode, 'statusCode', isNull),
            ),
          );
        },
      );

      test(
        'onTimeout fires a 408 TranscriptionException with a seconds-formatted '
        'message when the request exceeds the timeout',
        () {
          fakeAsync((async) {
            // Client send() never completes, so the .timeout() wrapper invokes
            // onTimeout once the (sub-minute) timeout elapses.
            const customTimeout = Duration(seconds: 30);
            final mockClient = MockClient.streaming((request, bodyStream) {
              return Completer<http.StreamedResponse>().future;
            });

            final repo = MistralTranscriptionRepository(httpClient: mockClient);

            Object? error;
            var completed = false;
            repo
                .transcribeAudio(
                  model: testModel,
                  audioBase64: testAudioBase64,
                  baseUrl: testBaseUrl,
                  apiKey: testApiKey,
                  timeout: customTimeout,
                )
                .listen(
                  (_) {},
                  onError: (Object e) {
                    error = e;
                    completed = true;
                  },
                  onDone: () => completed = true,
                );

            // Advance past the timeout to trigger onTimeout deterministically.
            async
              ..elapse(customTimeout + const Duration(milliseconds: 1))
              ..flushMicrotasks();

            expect(completed, isTrue);
            expect(
              error,
              isA<TranscriptionException>()
                  .having(
                    (e) => e.statusCode,
                    'statusCode',
                    httpStatusRequestTimeout,
                  )
                  // _formatTimeout seconds branch: 30 -> "30 seconds".
                  .having(
                    (e) => e.message,
                    'message',
                    contains('30 seconds'),
                  ),
            );
          });
        },
      );

      test(
        'onTimeout message uses singular "second" for a one-second timeout',
        () {
          fakeAsync((async) {
            const customTimeout = Duration(seconds: 1);
            final mockClient = MockClient.streaming((request, bodyStream) {
              return Completer<http.StreamedResponse>().future;
            });

            final repo = MistralTranscriptionRepository(httpClient: mockClient);

            Object? error;
            repo
                .transcribeAudio(
                  model: testModel,
                  audioBase64: testAudioBase64,
                  baseUrl: testBaseUrl,
                  apiKey: testApiKey,
                  timeout: customTimeout,
                )
                .listen((_) {}, onError: (Object e) => error = e);

            async
              ..elapse(customTimeout + const Duration(milliseconds: 1))
              ..flushMicrotasks();

            expect(
              error,
              isA<TranscriptionException>().having(
                (e) => e.message,
                'message',
                // _formatTimeout singular seconds branch: 1 -> "1 second".
                contains('1 second.'),
              ),
            );
          });
        },
      );
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
