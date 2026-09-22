import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/repository/ollama_embedding_repository.dart';
import 'package:lotti/features/ai/repository/ollama_inference_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  late OllamaEmbeddingRepository repository;
  late MockHttpClient mockHttpClient;

  const baseUrl = 'http://localhost:11434';
  const model = 'mxbai-embed-large';

  setUpAll(() {
    registerFallbackValue(Uri.parse(baseUrl));
    OllamaEmbeddingRepository.retryBaseDelay = Duration.zero;
  });

  tearDownAll(() {
    OllamaEmbeddingRepository.retryBaseDelay = const Duration(seconds: 2);
  });

  setUp(() {
    mockHttpClient = MockHttpClient();
    repository = OllamaEmbeddingRepository(httpClient: mockHttpClient);
  });

  /// Creates a valid embedding response body with [dims] float values.
  String makeEmbeddingResponse(int dims, {double value = 0.5}) {
    final vector = List<double>.filled(dims, value);
    return jsonEncode({
      'model': model,
      'embeddings': [vector],
    });
  }

  group('OllamaEmbeddingRepository', () {
    group('embed', () {
      test('returns Float32List on successful response', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            makeEmbeddingResponse(kEmbeddingDimensions, value: 0.42),
            200,
          ),
        );

        final result = await repository.embed(
          input: 'test text for embedding',
          baseUrl: baseUrl,
        );

        expect(result.length, kEmbeddingDimensions);
        expect(result[0], closeTo(0.42, 1e-5));
      });

      // ── Property: parsed vector preserves every generated value ─────────
      glados.Glados(
        glados.IntAnys(glados.any).intInRange(1, 1 << 30),
        glados.ExploreConfig(numRuns: 40),
      ).test('embed preserves arbitrary vector values element-wise', (
        seed,
      ) async {
        // Deterministic pseudo-random vector derived from the generated seed
        // so each of the 1024 elements differs and round-trips exactly.
        final values = List<double>.generate(
          kEmbeddingDimensions,
          (i) => ((seed + i * 2654435761) % 100000) / 1000 - 50,
        );
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'model': model,
              'embeddings': [values],
            }),
            200,
          ),
        );

        final result = await repository.embed(input: 'x', baseUrl: baseUrl);

        expect(result.length, kEmbeddingDimensions);
        for (var i = 0; i < kEmbeddingDimensions; i++) {
          expect(
            result[i],
            closeTo(values[i], 1e-4),
            reason: 'element $i for seed $seed',
          );
        }
      }, tags: 'glados');

      test('sends correct request body', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            makeEmbeddingResponse(kEmbeddingDimensions),
            200,
          ),
        );

        await repository.embed(
          input: 'hello world',
          baseUrl: baseUrl,
        );

        final captured = verify(
          () => mockHttpClient.post(
            captureAny(),
            headers: captureAny(named: 'headers'),
            body: captureAny(named: 'body'),
          ),
        ).captured;

        final uri = captured[0] as Uri;
        expect(uri.toString(), '$baseUrl/api/embed');

        final headers = captured[1] as Map<String, String>;
        expect(headers['Content-Type'], 'application/json');

        final body = jsonDecode(captured[2] as String) as Map<String, dynamic>;
        expect(body['model'], model);
        expect(body['input'], 'hello world');
      });

      test(
        'throws ModelNotInstalledException on 404 with model not found',
        () async {
          when(
            () => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            ),
          ).thenAnswer(
            (_) async => http.Response(
              '{"error":"model \'$model\' not found"}',
              404,
            ),
          );

          await expectLater(
            () => repository.embed(
              input: 'test',
              baseUrl: baseUrl,
            ),
            throwsA(isA<ModelNotInstalledException>()),
          );
        },
      );

      test('throws on non-200 non-404 status', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response('Internal Server Error', 500),
        );

        await expectLater(
          () => repository.embed(
            input: 'test',
            baseUrl: baseUrl,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('HTTP 500'),
            ),
          ),
        );
      });

      test('throws on malformed JSON response', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response('not json at all', 200),
        );

        await expectLater(
          () => repository.embed(
            input: 'test',
            baseUrl: baseUrl,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Malformed'),
            ),
          ),
        );
      });

      test('throws on empty embeddings array', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({'embeddings': <List<double>>[]}),
            200,
          ),
        );

        await expectLater(
          () => repository.embed(
            input: 'test',
            baseUrl: baseUrl,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('missing or empty'),
            ),
          ),
        );
      });

      test('throws on dimension mismatch in response', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            makeEmbeddingResponse(512), // wrong dimensions
            200,
          ),
        );

        await expectLater(
          () => repository.embed(
            input: 'test',
            baseUrl: baseUrl,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('dimension mismatch'),
            ),
          ),
        );
      });

      test('throws ArgumentError on empty input', () async {
        await expectLater(
          () => repository.embed(
            input: '',
            baseUrl: baseUrl,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('uses default model when not specified', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            makeEmbeddingResponse(kEmbeddingDimensions),
            200,
          ),
        );

        await repository.embed(
          input: 'test',
          baseUrl: baseUrl,
        );

        final captured = verify(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: captureAny(named: 'body'),
          ),
        ).captured;

        final body = jsonDecode(captured[0] as String) as Map<String, dynamic>;
        expect(body['model'], 'mxbai-embed-large');
      });

      test('throws when first embedding is not a list', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'embeddings': ['not-a-list'],
            }),
            200,
          ),
        );

        await expectLater(
          () => repository.embed(
            input: 'test',
            baseUrl: baseUrl,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('first embedding is not a list'),
            ),
          ),
        );
      });

      test('missing embeddings key throws', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({'model': model}),
            200,
          ),
        );

        await expectLater(
          () => repository.embed(
            input: 'test',
            baseUrl: baseUrl,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('missing or empty'),
            ),
          ),
        );
      });
    });

    group('retry logic', () {
      test(
        'retries on TimeoutException and throws after max retries',
        () async {
          when(
            () => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            ),
          ).thenThrow(TimeoutException('timed out'));

          await expectLater(
            () => repository.embed(
              input: 'test text',
              baseUrl: baseUrl,
            ),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                allOf(
                  contains('timed out'),
                  contains('3 attempts'),
                ),
              ),
            ),
          );
        },
      );

      test('retries on SocketException and throws after max retries', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenThrow(
          const SocketException('Connection refused'),
        );

        await expectLater(
          () => repository.embed(
            input: 'test text',
            baseUrl: baseUrl,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              allOf(
                contains('Network error'),
                contains('3 attempts'),
              ),
            ),
          ),
        );
      });

      test('succeeds after transient timeout then success', () async {
        var callCount = 0;
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) {
            throw TimeoutException('timed out');
          }
          return http.Response(
            makeEmbeddingResponse(kEmbeddingDimensions),
            200,
          );
        });

        final result = await repository.embed(
          input: 'test text',
          baseUrl: baseUrl,
        );

        expect(result.length, kEmbeddingDimensions);
        expect(callCount, 2);
      });

      test('succeeds after transient SocketException then success', () async {
        var callCount = 0;
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) {
            throw const SocketException('Connection refused');
          }
          return http.Response(
            makeEmbeddingResponse(kEmbeddingDimensions),
            200,
          );
        });

        final result = await repository.embed(
          input: 'test text',
          baseUrl: baseUrl,
        );

        expect(result.length, kEmbeddingDimensions);
        expect(callCount, 2);
      });

      test('rethrows non-transient exceptions immediately', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenThrow(Exception('Something unexpected'));

        await expectLater(
          () => repository.embed(
            input: 'test text',
            baseUrl: baseUrl,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Something unexpected'),
            ),
          ),
        );
      });
    });

    group('availability', () {
      const otherUrl = 'http://other-host:11434';
      late List<Completer<http.Response>> requests;
      late List<Uri> requestedUris;
      late MockDomainLogger logger;
      late List<String> logged;

      setUp(() {
        requests = [];
        requestedUris = [];
        logged = [];
        logger = MockDomainLogger();
        when(
          () => logger.log(
            any(),
            any(),
            subDomain: any(named: 'subDomain'),
            level: any(named: 'level'),
          ),
        ).thenAnswer((invocation) {
          logged.add(invocation.positionalArguments[1] as String);
        });
        repository = OllamaEmbeddingRepository(
          httpClient: mockHttpClient,
          domainLogger: logger,
        );
        // Every request stays open until the test answers it, so the order
        // of probes, waiters and failures is decided by the test alone.
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((invocation) {
          requestedUris.add(invocation.positionalArguments.first as Uri);
          final request = Completer<http.Response>();
          requests.add(request);
          return request.future;
        });
      });

      http.Response ok() =>
          http.Response(makeEmbeddingResponse(kEmbeddingDimensions), 200);

      /// Starts an embed call and records how it ends.
      List<Object> start(String url) {
        final outcome = <Object>[];
        repository
            .embed(input: 'text', baseUrl: url)
            .then<void>(outcome.add, onError: outcome.add);
        return outcome;
      }

      /// Fails the latest request with a socket error until its retry budget
      /// is spent. A retry waits on a (zero-length) timer, which only
      /// `elapse` fires.
      void failTransport(FakeAsync async) {
        for (var attempt = 0; attempt < 3; attempt++) {
          async.flushMicrotasks();
          requests.last.completeError(const SocketException('refused'));
          async.elapse(Duration.zero);
        }
      }

      /// Drives one probe to [url] into a confirmed outage.
      void openOutage(FakeAsync async, String url) {
        final discovered = start(url);
        failTransport(async);
        expect(discovered.single.toString(), contains('after 3 attempts'));
      }

      test('concurrent callers share one probe and then proceed', () {
        fakeAsync((async) {
          final first = start(baseUrl);
          final second = start(baseUrl);
          final third = start(baseUrl);
          async.flushMicrotasks();

          // Only the probe is on the wire while the endpoint is unconfirmed.
          expect(requests, hasLength(1));

          requests.single.complete(ok());
          async.flushMicrotasks();
          expect(first.single, isA<Float32List>());
          expect(requests, hasLength(3));

          requests[1].complete(ok());
          requests[2].complete(ok());
          async.flushMicrotasks();
          expect(second.single, isA<Float32List>());
          expect(third.single, isA<Float32List>());
        });
      });

      test('callers waiting on a probe that finds an outage fail without a '
          'network call', () {
        fakeAsync((async) {
          final probe = start(baseUrl);
          final waiter = start(baseUrl);
          failTransport(async);

          expect(probe.single.toString(), contains('after 3 attempts'));
          expect(
            waiter.single,
            isA<EmbeddingEndpointUnavailableException>().having(
              (e) => e.retryAt,
              'retryAt',
              DateTime(2026).add(OllamaEmbeddingRepository.outageCooldown),
            ),
          );
          expect(requests, hasLength(3));
        }, initialTime: DateTime(2026));
      });

      test('a confirmed outage suppresses calls until retryAt, then one '
          'recovery probe reopens the endpoint', () {
        fakeAsync((async) {
          openOutage(async, baseUrl);
          final attempts = requests.length;

          async.elapse(
            OllamaEmbeddingRepository.outageCooldown -
                const Duration(seconds: 1),
          );
          final suppressed = start(baseUrl);
          async.flushMicrotasks();
          expect(
            suppressed.single,
            isA<EmbeddingEndpointUnavailableException>(),
          );
          expect(requests, hasLength(attempts));

          async.elapse(const Duration(seconds: 1));
          final recovery = start(baseUrl);
          final waiter = start(baseUrl);
          async.flushMicrotasks();
          expect(requests, hasLength(attempts + 1));

          requests.last.complete(ok());
          async.flushMicrotasks();
          expect(recovery.single, isA<Float32List>());
          expect(requests, hasLength(attempts + 2));
          requests.last.complete(ok());
          async.flushMicrotasks();
          expect(waiter.single, isA<Float32List>());
          expect(logged.last, contains('reachable again'));
        });
      });

      test('a failure that began before a newer success cannot reopen the '
          'outage', () {
        fakeAsync((async) {
          final confirm = start(baseUrl);
          async.flushMicrotasks();
          requests.single.complete(ok());
          async.flushMicrotasks();
          expect(confirm.single, isA<Float32List>());

          final stale = start(baseUrl);
          async.flushMicrotasks();
          final staleRequest = requests.last;
          final fresh = start(baseUrl);
          async.flushMicrotasks();
          requests.last.complete(ok());
          async.flushMicrotasks();
          expect(fresh.single, isA<Float32List>());

          // The older call now spends its whole retry budget.
          staleRequest.completeError(const SocketException('refused'));
          async.elapse(Duration.zero);
          requests.last.completeError(const SocketException('refused'));
          async.elapse(Duration.zero);
          requests.last.completeError(const SocketException('refused'));
          async.elapse(Duration.zero);
          expect(stale.single.toString(), contains('after 3 attempts'));

          final after = start(baseUrl);
          async.flushMicrotasks();
          expect(after, isEmpty, reason: 'the call went to the network');
          requests.last.complete(ok());
          async.flushMicrotasks();
          expect(after.single, isA<Float32List>());
        });
      });

      test('an HTTP error status proves the endpoint reachable', () {
        fakeAsync((async) {
          final probe = start(baseUrl);
          async.flushMicrotasks();
          requests.single.complete(http.Response('boom', 500));
          async.flushMicrotasks();
          expect(probe.single.toString(), contains('HTTP 500'));

          final next = start(baseUrl);
          final alongside = start(baseUrl);
          async.flushMicrotasks();
          expect(requests, hasLength(3), reason: 'no probe gating any more');
          expect(next, isEmpty);
          expect(alongside, isEmpty);
        });
      });

      test('an outage at one base URL leaves another untouched', () {
        fakeAsync((async) {
          openOutage(async, baseUrl);

          final other = start(otherUrl);
          async.flushMicrotasks();
          expect(requestedUris.last.host, 'other-host');
          requests.last.complete(ok());
          async.flushMicrotasks();
          expect(other.single, isA<Float32List>());

          // The other endpoint's success does not end this one's outage.
          final stillOut = start(baseUrl);
          async.flushMicrotasks();
          expect(stillOut.single, isA<EmbeddingEndpointUnavailableException>());
        });
      });

      test('logs and messages never carry credentials from the base URL', () {
        fakeAsync((async) {
          const secretUrl =
              'http://user:hunter2@ollama.lan:11434/p/tok?key=abc';
          openOutage(async, secretUrl);
          final suppressed = start(secretUrl);
          async.flushMicrotasks();

          final text = [...logged, suppressed.single.toString()].join('\n');
          expect(text, contains('http://ollama.lan:11434'));
          for (final secret in ['user', 'hunter2', '/p/tok', 'key=abc']) {
            expect(text, isNot(contains(secret)));
          }
        });
      });

      test(
        "the production IOClient's refused connection opens the outage",
        () async {
          // IOClient wraps a dart:io SocketException in its own
          // ClientException subtype; this drives that real wrapping rather
          // than injecting a raw SocketException.
          final io = MockIoHttpClient();
          when(() => io.openUrl(any(), any())).thenAnswer(
            (_) async => throw const SocketException('Connection refused'),
          );
          final production = OllamaEmbeddingRepository(
            httpClient: IOClient(io),
            domainLogger: logger,
          );

          await expectLater(
            production.embed(input: 'text', baseUrl: baseUrl),
            throwsA(
              predicate<Object>((e) => '$e'.contains('after 3 attempts')),
            ),
          );
          await expectLater(
            production.embed(input: 'text', baseUrl: baseUrl),
            throwsA(isA<EmbeddingEndpointUnavailableException>()),
          );
          verify(() => io.openUrl(any(), any())).called(3);
        },
      );

      test('suppressed calls are reported only at powers of two', () {
        fakeAsync((async) {
          openOutage(async, baseUrl);
          logged.clear();

          for (var i = 0; i < 20; i++) {
            start(baseUrl);
          }
          async.flushMicrotasks();

          expect(logged, hasLength(5));
          expect(
            logged.map((m) => RegExp(r'suppressed (\d+)').firstMatch(m)![1]),
            ['1', '2', '4', '8', '16'],
          );
        });
      });
    });

    group('redactEndpoint', () {
      const cases = {
        'http://localhost:11434': 'http://localhost:11434',
        'https://ollama.example.com': 'https://ollama.example.com',
        'https://me:pw@proxy.example.com/v1/tok?key=abc#frag':
            'https://proxy.example.com',
        'not a url': '<unparsable Ollama URL>',
        '/api/embed': '<unparsable Ollama URL>',
      };
      for (final MapEntry(key: input, value: expected) in cases.entries) {
        test('reduces "$input" to "$expected"', () {
          expect(redactEndpoint(input), expected);
        });
      }
    });

    group('close', () {
      test('closes the underlying HTTP client', () {
        when(() => mockHttpClient.close()).thenReturn(null);

        repository.close();

        verify(() => mockHttpClient.close()).called(1);
      });
    });
  });
}
