import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lotti/features/ai/repository/mistral_ocr_repository.dart';

/// A non-timeout, non-format transport error to exercise the generic
/// `Exception` branch.
class _TransportFailure implements Exception {
  const _TransportFailure();
}

/// A client that records whether [close] was called, to assert that an
/// injected client is never closed by the repository.
class _RecordingClient extends http.BaseClient {
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw UnimplementedError();
  }

  @override
  void close() => closed = true;
}

void main() {
  group('MistralOcrRepository', () {
    const baseUrl = 'https://api.mistral.ai/v1';
    const apiKey = 'sk-mistral-test';
    const model = 'mistral-ocr-2512';

    MistralOcrRepository repoWithHandler(
      Future<http.Response> Function(http.Request request) handler,
    ) {
      final repo = MistralOcrRepository(httpClient: MockClient(handler));
      addTearDown(repo.close);
      return repo;
    }

    MistralOcrRepository repoReturning(Object? body, {int status = 200}) {
      return repoWithHandler(
        (_) async => http.Response(
          body is String ? body : jsonEncode(body),
          status,
        ),
      );
    }

    // Runs extractText and returns the single emitted chunk's text content.
    Future<String> textFrom(MistralOcrRepository repo) async {
      final chunks = await repo
          .extractText(
            model: model,
            images: const ['base64data'],
            baseUrl: baseUrl,
            apiKey: apiKey,
          )
          .toList();
      return chunks.single.choices!.single.delta!.content!;
    }

    group('isMistralOcrModel', () {
      test('matches ocr models case-insensitively', () {
        expect(
          MistralOcrRepository.isMistralOcrModel('mistral-ocr-2512'),
          true,
        );
        expect(
          MistralOcrRepository.isMistralOcrModel('Mistral-OCR-Latest'),
          true,
        );
      });

      test('does not match non-ocr models', () {
        expect(
          MistralOcrRepository.isMistralOcrModel('mistral-medium-latest'),
          false,
        );
        expect(MistralOcrRepository.isMistralOcrModel('pixtral-large'), false);
      });
    });

    group('argument validation', () {
      MistralOcrRepository idleRepo() =>
          repoReturning(const {'pages': <dynamic>[]});

      test('rejects an empty model', () {
        expect(
          () => idleRepo().extractText(
            model: '  ',
            images: const ['x'],
            baseUrl: baseUrl,
            apiKey: apiKey,
          ),
          throwsArgumentError,
        );
      });

      test('rejects empty image list', () {
        expect(
          () => idleRepo().extractText(
            model: model,
            images: const [],
            baseUrl: baseUrl,
            apiKey: apiKey,
          ),
          throwsArgumentError,
        );
      });

      test('rejects an empty base URL', () {
        expect(
          () => idleRepo().extractText(
            model: model,
            images: const ['x'],
            baseUrl: '   ',
            apiKey: apiKey,
          ),
          throwsArgumentError,
        );
      });

      test('rejects an empty API key', () {
        expect(
          () => idleRepo().extractText(
            model: model,
            images: const ['x'],
            baseUrl: baseUrl,
            apiKey: '  ',
          ),
          throwsArgumentError,
        );
      });
    });

    group('request shape', () {
      test('posts the image as a data URI to the /ocr endpoint', () async {
        late http.Request captured;
        late Map<String, dynamic> sentBody;
        final repo = repoWithHandler((request) async {
          captured = request;
          sentBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'pages': [
                {'index': 0, 'markdown': 'Hello world'},
              ],
            }),
            200,
          );
        });

        final text = await textFrom(repo);

        expect(text, 'Hello world');
        expect(captured.method, 'POST');
        expect(captured.url.toString(), '$baseUrl/ocr');
        expect(captured.headers['authorization'], 'Bearer $apiKey');
        expect(sentBody['model'], model);
        expect(sentBody['include_image_base64'], false);
        final document = sentBody['document'] as Map<String, dynamic>;
        expect(document['type'], 'image_url');
        expect(document['image_url'], 'data:image/jpeg;base64,base64data');
      });

      test(
        'appends /ocr correctly when base URL has a trailing slash',
        () async {
          late http.Request captured;
          final repo = repoWithHandler((request) async {
            captured = request;
            return http.Response(
              jsonEncode({
                'pages': [
                  {'markdown': 'x'},
                ],
              }),
              200,
            );
          });

          await repo
              .extractText(
                model: model,
                images: const ['data'],
                baseUrl: '$baseUrl/',
                apiKey: apiKey,
              )
              .toList();

          expect(captured.url.toString(), '$baseUrl/ocr');
        },
      );

      test('sends the trimmed model so trailing whitespace never reaches the '
          'API', () async {
        late Map<String, dynamic> sentBody;
        final repo = repoWithHandler((request) async {
          sentBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'pages': [
                {'markdown': 'x'},
              ],
            }),
            200,
          );
        });

        await repo
            .extractText(
              model: '  $model\n',
              images: const ['data'],
              baseUrl: baseUrl,
              apiKey: apiKey,
            )
            .toList();

        expect(sentBody['model'], model);
      });
    });

    group('markdown assembly', () {
      test('joins multiple pages with blank lines', () async {
        final text = await textFrom(
          repoReturning({
            'pages': [
              {'index': 0, 'markdown': 'Page one'},
              {'index': 1, 'markdown': '  Page two  '},
            ],
          }),
        );

        expect(text, 'Page one\n\nPage two');
      });

      test('skips blank, missing, and non-object pages', () async {
        final text = await textFrom(
          repoReturning({
            'pages': [
              {'markdown': 'Kept'},
              {'markdown': '   '},
              {'index': 2},
              'not-a-map',
            ],
          }),
        );

        expect(text, 'Kept');
      });

      test('strips figure placeholders the app never resolves', () async {
        final text = await textFrom(
          repoReturning({
            'pages': [
              {
                'markdown': '# Title\n\n![img-0.jpeg](img-0.jpeg)\n\n'
                    'Body text with inline ![fig 1](img-1.png) reference.',
              },
            ],
          }),
        );

        expect(
          text,
          '# Title\n\nBody text with inline  reference.',
        );
      });

      test('skips a page whose markdown is only image placeholders', () async {
        final text = await textFrom(
          repoReturning({
            'pages': [
              {'markdown': '![img-0.jpeg](img-0.jpeg)'},
              {'markdown': 'Real text'},
            ],
          }),
        );

        expect(text, 'Real text');
      });

      test('joins results across multiple images', () async {
        var call = 0;
        final repo = repoWithHandler((_) async {
          call++;
          return http.Response(
            jsonEncode({
              'pages': [
                {'markdown': 'Image $call text'},
              ],
            }),
            200,
          );
        });

        final chunks = await repo
            .extractText(
              model: model,
              images: const ['first', 'second'],
              baseUrl: baseUrl,
              apiKey: apiKey,
            )
            .toList();

        expect(call, 2);
        expect(
          chunks.single.choices!.single.delta!.content,
          'Image 1 text\n\nImage 2 text',
        );
      });
    });

    group('error handling', () {
      test('surfaces a structured error.message with status', () async {
        await expectLater(
          textFrom(
            repoReturning(
              const {
                'error': {'message': 'Invalid model: mistral-ocr-2512'},
              },
              status: 400,
            ),
          ),
          throwsA(
            isA<MistralOcrException>()
                .having(
                  (e) => e.message,
                  'message',
                  'Invalid model: mistral-ocr-2512',
                )
                .having((e) => e.statusCode, 'statusCode', 400),
          ),
        );
      });

      test('reads a string error field', () async {
        await expectLater(
          textFrom(repoReturning(const {'error': 'nope'}, status: 500)),
          throwsA(
            isA<MistralOcrException>().having(
              (e) => e.message,
              'message',
              'nope',
            ),
          ),
        );
      });

      test('reads a top-level message field', () async {
        await expectLater(
          textFrom(
            repoReturning(const {'message': 'bad request'}, status: 400),
          ),
          throwsA(
            isA<MistralOcrException>().having(
              (e) => e.message,
              'message',
              'bad request',
            ),
          ),
        );
      });

      test('falls back to the HTTP status for an empty body', () async {
        await expectLater(
          textFrom(repoReturning('', status: 503)),
          throwsA(
            isA<MistralOcrException>().having(
              (e) => e.message,
              'message',
              'Mistral OCR error (HTTP 503)',
            ),
          ),
        );
      });

      test('clips an overlong non-JSON error body', () async {
        await expectLater(
          textFrom(repoReturning('x' * 200, status: 500)),
          throwsA(
            isA<MistralOcrException>().having(
              (e) => e.message,
              'message',
              allOf(endsWith('…'), hasLength(161)),
            ),
          ),
        );
      });

      test('rejects a non-object response', () async {
        await expectLater(
          textFrom(repoReturning('"nope"')),
          throwsA(
            isA<MistralOcrException>().having(
              (e) => e.message,
              'message',
              contains('must be a JSON object'),
            ),
          ),
        );
      });

      test('rejects a response without a pages[] array', () async {
        await expectLater(
          textFrom(repoReturning(const {'model': 'mistral-ocr-2512'})),
          throwsA(
            isA<MistralOcrException>().having(
              (e) => e.message,
              'message',
              contains('missing a pages[] array'),
            ),
          ),
        );
      });

      test('wraps invalid JSON', () async {
        await expectLater(
          textFrom(repoReturning('not json {')),
          throwsA(
            isA<MistralOcrException>().having(
              (e) => e.message,
              'message',
              contains('was not valid JSON'),
            ),
          ),
        );
      });

      test('wraps request timeouts', () async {
        final repo = repoWithHandler(
          (_) async => throw TimeoutException('slow'),
        );
        await expectLater(
          textFrom(repo),
          throwsA(
            isA<MistralOcrException>().having(
              (e) => e.message,
              'message',
              contains('timed out'),
            ),
          ),
        );
      });

      test('wraps unexpected transport errors', () async {
        final repo = repoWithHandler(
          (_) async => throw const _TransportFailure(),
        );
        await expectLater(
          textFrom(repo),
          throwsA(
            isA<MistralOcrException>().having(
              (e) => e.message,
              'message',
              contains('Failed to run Mistral OCR'),
            ),
          ),
        );
      });
    });

    group('client ownership', () {
      test('close does not close an injected (caller-owned) client', () {
        final injected = _RecordingClient();
        MistralOcrRepository(httpClient: injected).close();
        expect(injected.closed, isFalse);
      });

      test('close on a self-created client does not throw', () {
        expect(MistralOcrRepository().close, returnsNormally);
      });
    });

    test('MistralOcrException.toString includes status and cause', () {
      const e = MistralOcrException(
        'boom',
        statusCode: 400,
        originalError: 'root',
      );
      expect(e.toString(), 'MistralOcrException (HTTP 400): boom: root');
      expect(
        const MistralOcrException('plain').toString(),
        'MistralOcrException: plain',
      );
    });
  });
}
