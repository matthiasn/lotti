import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lotti/features/tts/cloud/cloud_tts_exception.dart';
import 'package:lotti/features/tts/cloud/cloud_tts_http.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart' show MockDomainLogger;

const _description = 'Speech request (/v1/x): 3 chars';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockDomainLogger logger;
  late List<http.BaseRequest> requests;

  setUp(() {
    logger = MockDomainLogger();
    requests = [];
  });

  CloudTtsHttp transport(
    FutureOr<http.Response> Function(http.Request request) handler, {
    Duration timeout = const Duration(seconds: 60),
  }) => CloudTtsHttp(
    domainLogger: logger,
    providerName: 'Acme',
    subDomain: 'AcmeTts',
    requestIdHeaders: const ['request-id', 'x-request-id'],
    timeout: timeout,
    httpClient: MockClient((request) async {
      requests.add(request);
      return handler(request);
    }),
  );

  http.Request request() =>
      http.Request('POST', Uri.parse('https://api.acme.test/v1/x'));

  Future<CloudTtsException> failure(Future<Object?> call) async {
    try {
      await call;
    } on CloudTtsException catch (error) {
      return error;
    }
    fail('expected a CloudTtsException');
  }

  Future<CloudTtsException> answer(
    int status, {
    String body = '',
    Map<String, String> headers = const {},
  }) => failure(
    transport(
      (_) => http.Response(body, status, headers: headers),
    ).send(request(), description: _description),
  );

  group('sendStreamed', () {
    test(
      'hands on a 200 body as it arrives, never following a redirect',
      () async {
        final body = await transport(
          (_) => http.Response('one\ntwo', 200),
        ).sendStreamed(request(), description: _description).toList();

        expect(utf8.decode(body.expand((chunk) => chunk).toList()), 'one\ntwo');
        expect(requests.single.followRedirects, isFalse);
      },
    );

    test('maps a status that is not 200 to its failure, as send does, and '
        'logs it under the call', () async {
      final error = await failure(
        transport(
          (_) => http.Response('{"message": "bad key"}', 401),
        ).sendStreamed(request(), description: _description).drain<void>(),
      );

      expect(error.failure, CloudTtsFailure.unauthorized);
      expect(error.statusCode, 401);
      verify(
        () => logger.error(
          LogDomain.speech,
          error,
          subDomain: 'AcmeTts',
          message: '$_description failed',
        ),
      ).called(1);
    });

    test('a connection that fails is a network failure; anything else is '
        'not dressed up as one', () async {
      final error = await failure(
        transport(
          (_) => throw const SocketException('unreachable'),
        ).sendStreamed(request(), description: _description).drain<void>(),
      );
      expect(error.failure, CloudTtsFailure.network);
      expect(error.message, 'unreachable');

      await expectLater(
        transport(
          (_) => throw StateError('a bug'),
        ).sendStreamed(request(), description: _description).drain<void>(),
        throwsStateError,
      );
    });

    test('no answer within the timeout is a timeout', () {
      fakeAsync((async) {
        CloudTtsException? error;
        failure(
          transport(
            (_) => Completer<http.Response>().future,
            timeout: const Duration(seconds: 5),
          ).sendStreamed(request(), description: _description).drain<void>(),
        ).then((caught) => error = caught);
        async.elapse(const Duration(seconds: 6));

        expect(error!.failure, CloudTtsFailure.timeout);
        expect(error!.message, 'No response within 5 s');
      });
    });
  });

  group('send', () {
    test('returns a 200 and never follows a redirect', () async {
      final response = await transport(
        (_) => http.Response('ok', 200),
      ).send(request(), description: _description);

      expect(response.body, 'ok');
      expect(requests.single.followRedirects, isFalse);
    });

    test('maps every status to its failure, naming the provider', () async {
      final cases = <int, (CloudTtsFailure, String)>{
        401: (
          CloudTtsFailure.unauthorized,
          'The Acme API key was rejected',
        ),
        403: (
          CloudTtsFailure.unauthorized,
          'The Acme API key was rejected',
        ),
        429: (CloudTtsFailure.rateLimited, 'Rate limited by the Acme API'),
        500: (CloudTtsFailure.server, 'Acme API server error'),
        503: (CloudTtsFailure.server, 'Acme API server error'),
        302: (
          CloudTtsFailure.invalidResponse,
          'Unexpected redirect, not followed',
        ),
        400: (CloudTtsFailure.rejected, 'Request rejected by the Acme API'),
        404: (CloudTtsFailure.rejected, 'Request rejected by the Acme API'),
        422: (CloudTtsFailure.rejected, 'Request rejected by the Acme API'),
      };
      for (final MapEntry(key: status, value: (kind, message))
          in cases.entries) {
        final error = await answer(status);
        expect(error.failure, kind, reason: '$status');
        expect(error.message, message, reason: '$status');
        expect(error.statusCode, status);
      }
    });

    test(
      'logs a failure under its sub-domain with the call it ended',
      () async {
        await answer(500);

        verify(
          () => logger.error(
            LogDomain.speech,
            any<Object>(that: isA<CloudTtsException>()),
            subDomain: 'AcmeTts',
            message: '$_description failed',
          ),
        ).called(1);
      },
    );

    test('reads Retry-After as seconds, and nothing else', () async {
      expect(
        (await answer(429, headers: {'retry-after': ' 7 '})).retryAfter,
        const Duration(seconds: 7),
      );
      for (final header in ['soon', '-3', 'Wed, 21 Oct 2026 07:28:00 GMT']) {
        expect(
          (await answer(429, headers: {'retry-after': header})).retryAfter,
          isNull,
          reason: header,
        );
      }
      expect((await answer(429)).retryAfter, isNull);
    });

    test('keeps the first request id header the provider sends', () async {
      expect(
        (await answer(
          500,
          headers: {'x-request-id': 'second', 'request-id': 'first'},
        )).requestId,
        'first',
      );
      expect(
        (await answer(500, headers: {'x-request-id': 'only'})).requestId,
        'only',
      );
      expect((await answer(500)).requestId, isNull);
    });

    test(
      'a redirect keeps no server text, which may come from anywhere',
      () async {
        final error = await answer(302, body: jsonEncode({'message': 'moved'}));
        expect(error.apiError, isNull);
      },
    );

    group("the server's reason", () {
      Future<String?> apiErrorOf(String body) async =>
          (await answer(400, body: body)).apiError;

      test('a plain or nested message', () async {
        expect(
          await apiErrorOf(jsonEncode({'message': 'Bad voice'})),
          'Bad voice',
        );
        expect(
          await apiErrorOf(
            jsonEncode({
              'message': {'detail': 'Nested'},
            }),
          ),
          'Nested',
        );
        expect(await apiErrorOf(jsonEncode('Just text')), 'Just text');
      });

      test("ElevenLabs' detail object", () async {
        expect(
          await apiErrorOf(
            jsonEncode({
              'detail': {
                'status': 'voice_not_found',
                'message': 'A voice with that id was not found.',
              },
            }),
          ),
          'A voice with that id was not found.',
        );
      });

      test('each validation detail as loc: msg, never its input', () async {
        final reason = await apiErrorOf(
          jsonEncode({
            'detail': [
              {
                'loc': ['body', 'text'],
                'msg': 'Field required',
                'input': 'the spoken words',
              },
              {'msg': 'Something else'},
              {'loc': <String>[], 'msg': 'No location'},
              {'msg': 42},
              'not a map',
            ],
          }),
        );
        expect(
          reason,
          'body.text: Field required; Something else; No location',
        );
        expect(reason, isNot(contains('spoken')));
      });

      test('nothing for a body that is not JSON or says nothing', () async {
        for (final body in [
          '<html>proxy</html>',
          '{"message": " "}',
          '{}',
          '3',
        ]) {
          expect(await apiErrorOf(body), isNull, reason: body);
        }
      });

      test('a long reason is cut with an ellipsis', () async {
        final reason = await apiErrorOf(jsonEncode({'message': 'x' * 600}));
        expect(reason, '${'x' * 500}…');
      });
    });

    test('maps transport errors to network failures', () async {
      for (final transportError in <Exception>[
        const SocketException('Connection refused'),
        http.ClientException('Connection closed'),
        const HandshakeException('Bad certificate'),
      ]) {
        final error = await failure(
          transport(
            (_) => throw transportError,
          ).send(request(), description: _description),
        );
        expect(error.failure, CloudTtsFailure.network);
      }
      verify(
        () => logger.error(
          LogDomain.speech,
          any<Object>(that: isA<CloudTtsException>()),
          subDomain: 'AcmeTts',
          message: '$_description failed',
        ),
      ).called(3);
    });

    test('times out instead of waiting forever', () {
      fakeAsync((async) {
        final never = Completer<http.Response>();
        CloudTtsException? error;
        transport(
              (_) => never.future,
              timeout: const Duration(seconds: 5),
            )
            .send(request(), description: _description)
            .then<void>(
              (_) {},
              onError: (Object e) => error = e as CloudTtsException,
            );

        async.elapse(const Duration(seconds: 4));
        expect(error, isNull);
        async.elapse(const Duration(seconds: 1));
        expect(error?.failure, CloudTtsFailure.timeout);
        expect(error?.message, 'No response within 5 s');
      });
    });
  });

  group('sendForJson', () {
    test('decodes any JSON value', () async {
      expect(
        await transport(
          (_) => http.Response('[1, {"a": 2}]', 200),
        ).sendForJson(request(), description: _description),
        [
          1,
          {'a': 2},
        ],
      );
    });

    test('a body that is not JSON is an invalid response', () async {
      final error = await failure(
        transport(
          (_) => http.Response('<html>', 200),
        ).sendForJson(request(), description: _description),
      );
      expect(error.failure, CloudTtsFailure.invalidResponse);
      expect(error.message, 'Response is not JSON');
    });
  });

  test('invalidResponse logs what it returns', () {
    final error = transport(
      (_) => http.Response('', 200),
    ).invalidResponse('No audio', description: _description);

    expect(error.failure, CloudTtsFailure.invalidResponse);
    expect(error.message, 'No audio');
    verify(
      () => logger.error(
        LogDomain.speech,
        error,
        subDomain: 'AcmeTts',
        message: '$_description failed',
      ),
    ).called(1);
  });

  test('log writes a progress line under the sub-domain', () {
    transport((_) => http.Response('', 200)).log('Speech response: 3 bytes');

    verify(
      () => logger.log(
        LogDomain.speech,
        'Speech response: 3 bytes',
        subDomain: 'AcmeTts',
      ),
    ).called(1);
  });

  group('endpoint', () {
    test('resolves a path under the base, with or without a slash', () {
      for (final base in [
        'https://api.acme.test/v1',
        'https://api.acme.test/v1/',
      ]) {
        expect(
          CloudTtsHttp.endpoint(base, 'voices').toString(),
          'https://api.acme.test/v1/voices',
        );
      }
    });

    test('allows plain HTTP only on loopback', () {
      for (final base in [
        'http://localhost:8000/v1',
        'http://127.0.0.1:8000/v1',
        'http://[::1]:8000/v1',
      ]) {
        expect(
          CloudTtsHttp.endpoint(base, 'x').scheme,
          'http',
          reason: base,
        );
      }
      expect(
        () => CloudTtsHttp.endpoint('http://api.acme.test/v1', 'x'),
        throwsArgumentError,
      );
      expect(
        () => CloudTtsHttp.endpoint('ftp://localhost/v1', 'x'),
        throwsArgumentError,
      );
    });

    test('refuses an empty base URL', () {
      expect(() => CloudTtsHttp.endpoint('', 'x'), throwsArgumentError);
    });
  });

  test('requireKey refuses only an empty key', () {
    expect(() => CloudTtsHttp.requireKey(''), throwsArgumentError);
    expect(() => CloudTtsHttp.requireKey('k'), returnsNormally);
  });

  test('close closes the injected client', () {
    var closed = false;
    CloudTtsHttp(
      domainLogger: logger,
      providerName: 'Acme',
      subDomain: 'AcmeTts',
      requestIdHeaders: const [],
      timeout: const Duration(seconds: 1),
      httpClient: _ClosingClient(() => closed = true),
    ).close();
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
