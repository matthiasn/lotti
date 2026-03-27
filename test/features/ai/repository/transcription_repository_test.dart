import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/repository/transcription_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';

void main() {
  group('TranscriptionRepository', () {
    late TranscriptionRepository repo;

    setUp(() {
      repo = TranscriptionRepository();
    });

    group('executeTranscription', () {
      test('returns stream with transcription text on success', () async {
        final responses = await repo
            .executeTranscription(
              providerName: 'TestProvider',
              responseIdPrefix: 'test-prefix-',
              audioLengthForLog: 1024,
              sendRequest: (timeout, timeoutErrorMessage) async {
                return http.Response(
                  jsonEncode({'text': 'Hello, world!'}),
                  200,
                );
              },
            )
            .toList();

        expect(responses, hasLength(1));
        expect(
          responses.first.choices?.first.delta?.content,
          equals('Hello, world!'),
        );
      });

      test('response ID starts with the given prefix', () async {
        final responses = await repo
            .executeTranscription(
              providerName: 'TestProvider',
              responseIdPrefix: 'my-custom-prefix-',
              audioLengthForLog: 512,
              sendRequest: (timeout, timeoutErrorMessage) async {
                return http.Response(
                  jsonEncode({'text': 'transcribed'}),
                  200,
                );
              },
            )
            .toList();

        expect(responses.first.id, startsWith('my-custom-prefix-'));
      });

      test('throws TranscriptionException on HTTP error', () async {
        await expectLater(
          repo
              .executeTranscription(
                providerName: 'TestProvider',
                responseIdPrefix: 'test-',
                audioLengthForLog: 256,
                sendRequest: (timeout, timeoutErrorMessage) async {
                  return http.Response(
                    'Internal Server Error',
                    500,
                  );
                },
              )
              .toList(),
          throwsA(
            isA<TranscriptionException>()
                .having(
                  (e) => e.statusCode,
                  'statusCode',
                  500,
                )
                .having(
                  (e) => e.provider,
                  'provider',
                  'TestProvider',
                ),
          ),
        );
      });

      test(
        'parses structured error message from JSON error response',
        () async {
          await expectLater(
            repo
                .executeTranscription(
                  providerName: 'TestProvider',
                  responseIdPrefix: 'test-',
                  audioLengthForLog: 256,
                  sendRequest: (timeout, timeoutErrorMessage) async {
                    return http.Response(
                      jsonEncode({
                        'error': {'message': 'Rate limit exceeded'},
                      }),
                      429,
                    );
                  },
                )
                .toList(),
            throwsA(
              isA<TranscriptionException>()
                  .having(
                    (e) => e.statusCode,
                    'statusCode',
                    429,
                  )
                  .having(
                    (e) => e.message,
                    'message',
                    'Rate limit exceeded',
                  ),
            ),
          );
        },
      );

      test(
        'falls back to generic error message when body is not JSON',
        () async {
          await expectLater(
            repo
                .executeTranscription(
                  providerName: 'TestProvider',
                  responseIdPrefix: 'test-',
                  audioLengthForLog: 256,
                  sendRequest: (timeout, timeoutErrorMessage) async {
                    return http.Response(
                      'Something went wrong',
                      502,
                    );
                  },
                )
                .toList(),
            throwsA(
              isA<TranscriptionException>().having(
                (e) => e.message,
                'message',
                'Failed to transcribe audio (HTTP 502)',
              ),
            ),
          );
        },
      );

      test('throws TranscriptionException when response '
          "missing 'text' field", () async {
        await expectLater(
          repo
              .executeTranscription(
                providerName: 'TestProvider',
                responseIdPrefix: 'test-',
                audioLengthForLog: 256,
                sendRequest: (timeout, timeoutErrorMessage) async {
                  return http.Response(
                    jsonEncode({'segments': <dynamic>[]}),
                    200,
                  );
                },
              )
              .toList(),
          throwsA(
            isA<TranscriptionException>()
                .having(
                  (e) => e.message,
                  'message',
                  contains('missing text field'),
                )
                .having(
                  (e) => e.provider,
                  'provider',
                  'TestProvider',
                ),
          ),
        );
      });

      test('throws TranscriptionException on TimeoutException '
          'with status 408', () async {
        await expectLater(
          repo
              .executeTranscription(
                providerName: 'TestProvider',
                responseIdPrefix: 'test-',
                audioLengthForLog: 256,
                sendRequest: (timeout, timeoutErrorMessage) async {
                  throw TimeoutException('Request timed out');
                },
              )
              .toList(),
          throwsA(
            isA<TranscriptionException>()
                .having(
                  (e) => e.statusCode,
                  'statusCode',
                  httpStatusRequestTimeout,
                )
                .having(
                  (e) => e.message,
                  'message',
                  contains('timed out'),
                )
                .having(
                  (e) => e.originalError,
                  'originalError',
                  isA<TimeoutException>(),
                ),
          ),
        );
      });

      test('throws TranscriptionException on FormatException', () async {
        await expectLater(
          repo
              .executeTranscription(
                providerName: 'TestProvider',
                responseIdPrefix: 'test-',
                audioLengthForLog: 256,
                sendRequest: (timeout, timeoutErrorMessage) async {
                  return http.Response(
                    'not valid json {{{',
                    200,
                  );
                },
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
                ),
          ),
        );
      });

      test('throws TranscriptionException on generic exception', () async {
        await expectLater(
          repo
              .executeTranscription(
                providerName: 'TestProvider',
                responseIdPrefix: 'test-',
                audioLengthForLog: 256,
                sendRequest: (timeout, timeoutErrorMessage) async {
                  throw Exception('Network error');
                },
              )
              .toList(),
          throwsA(
            isA<TranscriptionException>()
                .having(
                  (e) => e.message,
                  'message',
                  contains('Failed to transcribe audio'),
                )
                .having(
                  (e) => e.originalError,
                  'originalError',
                  isA<Exception>(),
                ),
          ),
        );
      });

      test('uses default timeout when none specified', () async {
        Duration? capturedTimeout;

        await repo
            .executeTranscription(
              providerName: 'TestProvider',
              responseIdPrefix: 'test-',
              audioLengthForLog: 1024,
              sendRequest: (timeout, timeoutErrorMessage) async {
                capturedTimeout = timeout;
                return http.Response(
                  jsonEncode({'text': 'ok'}),
                  200,
                );
              },
            )
            .toList();

        expect(
          capturedTimeout,
          equals(
            const Duration(seconds: whisperTranscriptionTimeoutSeconds),
          ),
        );
      });

      test('uses custom timeout when specified', () async {
        Duration? capturedTimeout;
        const customTimeout = Duration(seconds: 30);

        await repo
            .executeTranscription(
              providerName: 'TestProvider',
              responseIdPrefix: 'test-',
              audioLengthForLog: 1024,
              timeout: customTimeout,
              sendRequest: (timeout, timeoutErrorMessage) async {
                capturedTimeout = timeout;
                return http.Response(
                  jsonEncode({'text': 'ok'}),
                  200,
                );
              },
            )
            .toList();

        expect(capturedTimeout, equals(customTimeout));
      });
    });
  });
}
