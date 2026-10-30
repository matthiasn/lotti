import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lotti/features/tts/cloud/voxtral_tts_service.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart' show MockDomainLogger;

const _baseUrl = 'https://api.mistral.ai/v1';
const _apiKey = 'secret-key';
const _text = 'Grüß Gott — „Äpfel“ & 😀 kosten 3,50 €.';
final Uint8List _audio = utf8.encode('RIFF fake wav');

Map<String, dynamic> _voice(String id, String language) => {
  'id': id,
  'name': 'Voice $id',
  'languages': [language],
  'type': 'preset',
};

void main() {
  setUpAll(registerAllFallbackValues);

  late MockDomainLogger logger;
  late List<http.BaseRequest> requests;

  setUp(() {
    logger = MockDomainLogger();
    requests = [];
  });

  VoxtralTtsService service(
    FutureOr<http.Response> Function(http.Request request) handler,
  ) => VoxtralTtsService(
    domainLogger: logger,
    httpClient: MockClient((request) async {
      requests.add(request);
      return handler(request);
    }),
  );

  Future<VoxtralTtsException> failure(Future<Object?> call) async {
    try {
      await call;
    } on VoxtralTtsException catch (error) {
      return error;
    }
    fail('expected a VoxtralTtsException');
  }

  List<String> loggedText() => [
    for (final call in verify(
      () => logger.log(
        any(),
        captureAny(),
        subDomain: any(named: 'subDomain'),
      ),
    ).captured)
      call as String,
  ];

  group('synthesize', () {
    test('posts the documented request and decodes audio_data', () async {
      final bytes =
          await service(
            (_) => http.Response(
              jsonEncode({'audio_data': base64Encode(_audio)}),
              200,
            ),
          ).synthesize(
            text: _text,
            voiceId: 'v-de-1',
            baseUrl: _baseUrl,
            apiKey: _apiKey,
          );

      expect(bytes, _audio);
      final request = requests.single as http.Request;
      expect(request.method, 'POST');
      expect(request.url.toString(), 'https://api.mistral.ai/v1/audio/speech');
      expect(request.headers['Authorization'], 'Bearer $_apiKey');
      expect(request.followRedirects, isFalse);
      expect(jsonDecode(request.body), {
        'model': VoxtralTtsService.defaultModel,
        'input': _text,
        'voice_id': 'v-de-1',
        'response_format': 'wav',
      });
    });

    test('passes model and format through, trailing slash or not', () async {
      await service(
        (_) => http.Response(
          jsonEncode({'audio_data': base64Encode(_audio)}),
          200,
        ),
      ).synthesize(
        text: 'Hi',
        voiceId: 'v',
        baseUrl: '$_baseUrl/',
        apiKey: _apiKey,
        model: 'voxtral-mini-tts-2603',
        format: VoxtralAudioFormat.mp3,
      );
      final request = requests.single as http.Request;
      expect(request.url.path, '/v1/audio/speech');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['model'], 'voxtral-mini-tts-2603');
      expect(body['response_format'], 'mp3');
    });

    test('never logs the text or the key', () async {
      await service(
        (_) => http.Response(
          jsonEncode({'audio_data': base64Encode(_audio)}),
          200,
        ),
      ).synthesize(
        text: _text,
        voiceId: 'v-de-1',
        baseUrl: _baseUrl,
        apiKey: _apiKey,
      );
      final logged = loggedText();
      expect(logged, hasLength(2));
      expect(logged.first, contains('${_text.length} chars'));
      expect(logged.last, contains('${_audio.length} bytes'));
      for (final line in logged) {
        expect(line, isNot(contains('Grüß')));
        expect(line, isNot(contains(_apiKey)));
      }
    });

    test('rejects empty arguments before any request', () {
      final s = service((_) => http.Response('', 200));
      expect(
        () => s.synthesize(
          text: '  ',
          voiceId: 'v',
          baseUrl: _baseUrl,
          apiKey: _apiKey,
        ),
        throwsArgumentError,
      );
      expect(
        () => s.synthesize(
          text: 'a',
          voiceId: '',
          baseUrl: _baseUrl,
          apiKey: _apiKey,
        ),
        throwsArgumentError,
      );
      expect(
        () => s.synthesize(
          text: 'a',
          voiceId: 'v',
          baseUrl: _baseUrl,
          apiKey: '',
        ),
        throwsArgumentError,
      );
      expect(
        () =>
            s.synthesize(text: 'a', voiceId: 'v', baseUrl: '', apiKey: _apiKey),
        throwsArgumentError,
      );
      expect(requests, isEmpty);
    });

    test('refuses plain HTTP except on loopback', () async {
      final s = service(
        (_) => http.Response(
          jsonEncode({'audio_data': base64Encode(_audio)}),
          200,
        ),
      );
      expect(
        () => s.synthesize(
          text: 'a',
          voiceId: 'v',
          baseUrl: 'http://api.mistral.ai/v1',
          apiKey: _apiKey,
        ),
        throwsArgumentError,
      );
      expect(requests, isEmpty);
      for (final local in [
        'http://localhost:8000/v1',
        'http://127.0.0.1:8000/v1',
      ]) {
        expect(
          await s.synthesize(
            text: 'a',
            voiceId: 'v',
            baseUrl: local,
            apiKey: _apiKey,
          ),
          _audio,
        );
      }
    });

    test('maps HTTP statuses to failures', () async {
      const cases = {
        401: VoxtralTtsFailure.unauthorized,
        403: VoxtralTtsFailure.unauthorized,
        400: VoxtralTtsFailure.rejected,
        404: VoxtralTtsFailure.rejected,
        422: VoxtralTtsFailure.rejected,
        500: VoxtralTtsFailure.server,
        503: VoxtralTtsFailure.server,
        302: VoxtralTtsFailure.invalidResponse,
      };
      for (final entry in cases.entries) {
        final error = await failure(
          service(
            // A validation detail echoes the rejected value as `input`.
            (_) => http.Response.bytes(
              utf8.encode(
                jsonEncode({
                  'detail': [
                    {
                      'loc': ['body', 'input'],
                      'msg': 'String too long',
                      'input': _text,
                    },
                  ],
                }),
              ),
              entry.key,
            ),
          ).synthesize(
            text: _text,
            voiceId: 'v',
            baseUrl: _baseUrl,
            apiKey: _apiKey,
          ),
        );
        expect(error.failure, entry.value, reason: 'HTTP ${entry.key}');
        expect(error.statusCode, entry.key);
        // The body may echo the user's text; the message must not.
        expect(error.toString(), isNot(contains('Grüß')));
        expect(
          error.apiError,
          entry.key == 302 ? isNull : 'body.input: String too long',
        );
      }
    });

    test('keeps the server message and request id, and logs both', () async {
      final error = await failure(
        service(
          (_) => http.Response(
            jsonEncode({
              'object': 'error',
              'message': 'Invalid model: voxtral-nope',
              'type': 'invalid_request_error',
            }),
            400,
            headers: {'x-request-id': 'req-7'},
          ),
        ).synthesize(
          text: _text,
          voiceId: 'v-de-1',
          baseUrl: _baseUrl,
          apiKey: _apiKey,
          model: 'voxtral-nope',
        ),
      );
      expect(error.apiError, 'Invalid model: voxtral-nope');
      expect(error.requestId, 'req-7');
      expect(
        error.toString(),
        'VoxtralTtsException(rejected, HTTP 400): Request rejected by the '
        'Mistral API — server: Invalid model: voxtral-nope (request req-7)',
      );
      final message =
          verify(
                () => logger.error(
                  LogDomain.speech,
                  error,
                  subDomain: 'VoxtralTts',
                  message: captureAny(named: 'message'),
                ),
              ).captured.single
              as String;
      expect(
        message,
        'Speech request (/v1/audio/speech): ${_text.length} chars, '
        'voice v-de-1, model voxtral-nope, wav failed',
      );
      expect(message, isNot(contains('Grüß')));
    });

    test('reads nested and plain-string server errors', () async {
      Future<String?> apiErrorOf(String body) async => (await failure(
        service((_) => http.Response(body, 422)).synthesize(
          text: 'a',
          voiceId: 'v',
          baseUrl: _baseUrl,
          apiKey: _apiKey,
        ),
      )).apiError;

      expect(
        await apiErrorOf(
          jsonEncode({
            'message': {
              'detail': [
                {
                  'loc': ['body', 'voice_id'],
                  'msg': 'Unknown voice',
                },
                {'msg': 'Second problem'},
                'not a detail',
              ],
            },
          }),
        ),
        'body.voice_id: Unknown voice; Second problem',
      );
      expect(
        await apiErrorOf('{"detail": "Voice not found"}'),
        'Voice not found',
      );
      expect(
        await apiErrorOf(jsonEncode({'message': 'x' * 600})),
        '${'x' * 500}…',
      );
      // Not JSON, or JSON without a message: unknown content, not kept.
      for (final body in [
        '<html>Bad gateway</html>',
        '',
        '{}',
        '[]',
        '{"message": " "}',
      ]) {
        expect(await apiErrorOf(body), isNull, reason: body);
      }
    });

    test('reads Retry-After on a 429', () async {
      final limited = await failure(
        service(
          (_) => http.Response('', 429, headers: {'retry-after': '12'}),
        ).synthesize(
          text: 'a',
          voiceId: 'v',
          baseUrl: _baseUrl,
          apiKey: _apiKey,
        ),
      );
      expect(limited.failure, VoxtralTtsFailure.rateLimited);
      expect(limited.retryAfter, const Duration(seconds: 12));
      expect(limited.isRetryable, isTrue);

      final dated = await failure(
        service(
          (_) => http.Response(
            '',
            429,
            headers: {'retry-after': 'Wed, 21 Oct 2026 07:28:00 GMT'},
          ),
        ).synthesize(
          text: 'a',
          voiceId: 'v',
          baseUrl: _baseUrl,
          apiKey: _apiKey,
        ),
      );
      expect(dated.retryAfter, isNull);
    });

    test('flags malformed 200 bodies as invalid responses', () async {
      for (final body in [
        'not json',
        '[1, 2]',
        '{}',
        '{"audio_data": ""}',
        '{"audio_data": 42}',
        '{"audio_data": "%%% not base64"}',
      ]) {
        final error = await failure(
          service((_) => http.Response(body, 200)).synthesize(
            text: 'a',
            voiceId: 'v',
            baseUrl: _baseUrl,
            apiKey: _apiKey,
          ),
        );
        expect(error.failure, VoxtralTtsFailure.invalidResponse, reason: body);
        expect(error.isRetryable, isFalse);
      }
      verify(
        () => logger.error(
          LogDomain.speech,
          any<Object>(that: isA<VoxtralTtsException>()),
          subDomain: 'VoxtralTts',
          message: any(named: 'message'),
        ),
      ).called(6);
    });

    test('maps transport errors to network failures and logs them', () async {
      for (final transportError in <Exception>[
        const SocketException('Connection refused'),
        http.ClientException('Connection closed'),
        const HandshakeException('Bad certificate'),
      ]) {
        final error = await failure(
          service((_) => throw transportError).synthesize(
            text: 'a',
            voiceId: 'v',
            baseUrl: _baseUrl,
            apiKey: _apiKey,
          ),
        );
        expect(error.failure, VoxtralTtsFailure.network);
        expect(error.isRetryable, isTrue);
      }
      verify(
        () => logger.error(
          LogDomain.speech,
          any<Object>(that: isA<VoxtralTtsException>()),
          subDomain: 'VoxtralTts',
          message: any(named: 'message'),
        ),
      ).called(3);
    });

    test('times out instead of waiting forever', () {
      fakeAsync((async) {
        final never = Completer<http.Response>();
        VoxtralTtsException? error;
        VoxtralTtsService(
              domainLogger: logger,
              httpClient: MockClient((_) => never.future),
              timeout: const Duration(seconds: 5),
            )
            .synthesize(
              text: 'a',
              voiceId: 'v',
              baseUrl: _baseUrl,
              apiKey: _apiKey,
            )
            .then<void>(
              (_) {},
              onError: (Object e) => error = e as VoxtralTtsException,
            );

        async.elapse(const Duration(seconds: 4));
        expect(error, isNull);
        async.elapse(const Duration(seconds: 1));
        expect(error?.failure, VoxtralTtsFailure.timeout);
        expect(error?.isRetryable, isTrue);
      });
    });
  });

  group('fetchVoices', () {
    test('requests all voice types and builds a timestamped catalog', () async {
      final now = DateTime.utc(2026, 10, 27, 9);
      final catalog = await withClock(
        Clock.fixed(now),
        () => service(
          (_) => http.Response(
            jsonEncode({
              'items': [
                _voice('a', 'en'),
                _voice('heidi', 'de'),
                {'name': 'no id'},
              ],
              'page': '1',
              'page_size': '100',
              'total': 3,
              'total_pages': '1',
            }),
            200,
          ),
        ).fetchVoices(baseUrl: _baseUrl, apiKey: _apiKey),
      );

      expect(catalog.fetchedAt, now);
      expect(catalog.voices.map((v) => v.id), ['a', 'heidi']);
      expect(catalog.resolve(languageCode: 'de')?.id, 'heidi');
      final request = requests.single;
      expect(request.method, 'GET');
      expect(request.url.path, '/v1/audio/voices');
      expect(request.url.queryParameters, {
        'type': 'all',
        // The API's maximum: a larger limit is a 422, and was the cause of
        // every cloud read-aloud failing before any text was sent.
        'limit': '100',
        'offset': '0',
      });
      expect(request.headers['Authorization'], 'Bearer $_apiKey');
      expect(loggedText().single, contains('1 malformed entries skipped'));
    });

    test('follows total_pages across full pages', () async {
      const size = VoxtralTtsService.voicesPageSize;
      final catalog = await service((request) {
        final offset = int.parse(request.url.queryParameters['offset']!);
        final count = offset == 0 ? size : 2;
        return http.Response(
          jsonEncode({
            'items': [
              for (var i = 0; i < count; i++) _voice('${offset + i}', 'de'),
            ],
            'total_pages': 2,
          }),
          200,
        );
      }).fetchVoices(baseUrl: _baseUrl, apiKey: _apiKey);

      expect(catalog.voices, hasLength(size + 2));
      expect(
        requests.map((r) => r.url.queryParameters['offset']),
        ['0', '$size'],
      );
    });

    test('stops at a short page even if total_pages claims more', () async {
      await service(
        (_) => http.Response(
          jsonEncode({
            'items': [_voice('a', 'de')],
            'total_pages': '9',
          }),
          200,
        ),
      ).fetchVoices(baseUrl: _baseUrl, apiKey: _apiKey);
      expect(requests, hasLength(1));
    });

    test('rejects a body without an items list', () async {
      final error = await failure(
        service(
          (_) => http.Response('{"voices": []}', 200),
        ).fetchVoices(baseUrl: _baseUrl, apiKey: _apiKey),
      );
      expect(error.failure, VoxtralTtsFailure.invalidResponse);
    });

    test('logs a rejected page with the field the server named', () async {
      final error = await failure(
        service(
          (_) => http.Response(
            jsonEncode({
              'detail': [
                {
                  'type': 'less_than_equal',
                  'loc': ['query', 'limit'],
                  'msg': 'Input should be less than or equal to 100',
                  'input': '1000',
                },
              ],
            }),
            422,
          ),
        ).fetchVoices(baseUrl: _baseUrl, apiKey: _apiKey),
      );
      expect(error.failure, VoxtralTtsFailure.rejected);
      expect(
        error.apiError,
        'query.limit: Input should be less than or equal to 100',
      );
      verify(
        () => logger.error(
          LogDomain.speech,
          error,
          subDomain: 'VoxtralTts',
          message: 'Voice catalog request (/v1/audio/voices): page 1 failed',
        ),
      ).called(1);
    });

    test('surfaces an auth failure', () async {
      final error = await failure(
        service(
          (_) => http.Response('', 401),
        ).fetchVoices(baseUrl: _baseUrl, apiKey: _apiKey),
      );
      expect(error.failure, VoxtralTtsFailure.unauthorized);
      expect(error.isRetryable, isFalse);
    });

    test('rejects an empty key before any request', () {
      expect(
        () => service(
          (_) => http.Response('', 200),
        ).fetchVoices(baseUrl: _baseUrl, apiKey: ''),
        throwsArgumentError,
      );
      expect(requests, isEmpty);
    });
  });

  test('VoxtralTtsException describes itself without secrets', () {
    const error = VoxtralTtsException(
      VoxtralTtsFailure.rejected,
      'Request rejected by the Mistral API',
      statusCode: 422,
    );
    expect(
      error.toString(),
      'VoxtralTtsException(rejected, HTTP 422): '
      'Request rejected by the Mistral API',
    );
    expect(
      const VoxtralTtsException(VoxtralTtsFailure.timeout, 'x').toString(),
      'VoxtralTtsException(timeout): x',
    );
    expect(
      const VoxtralTtsException(
        VoxtralTtsFailure.invalidResponse,
        'Unexpected redirect, not followed',
        statusCode: 302,
        requestId: 'r1',
      ).toString(),
      'VoxtralTtsException(invalidResponse, HTTP 302): '
      'Unexpected redirect, not followed (request r1)',
    );
  });

  test('close closes the injected client', () async {
    var closed = false;
    final client = _ClosingClient(() => closed = true);
    VoxtralTtsService(domainLogger: logger, httpClient: client).close();
    expect(closed, isTrue);
  });
}

class _ClosingClient extends http.BaseClient {
  _ClosingClient(this.onClose);

  final void Function() onClose;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      throw UnimplementedError();

  @override
  void close() => onClose();
}
