import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/services/connection_verifier_service.dart';

/// Stand-up a fresh `ProviderContainer` per test with the supplied
/// MockClient + optional probe-registry override + short timeout. The
/// verifier reads its dependencies via Riverpod providers, so this
/// helper threads the test fakes through the same wires production
/// uses.
ProviderContainer _makeContainer({
  required http.Client client,
  Map<InferenceProviderType, ConnectionProbe>? probes,
  Duration timeout = const Duration(milliseconds: 200),
}) {
  return ProviderContainer(
    overrides: [
      connectionVerifierClientProvider.overrideWithValue(() => client),
      connectionVerifierTimeoutProvider.overrideWithValue(timeout),
      if (probes != null)
        connectionProbeRegistryProvider.overrideWithValue(probes),
    ],
  );
}

ConnectionCheckState _readState(
  ProviderContainer container,
  InferenceProviderType type,
) => container.read(connectionVerifierControllerProvider(type));

/// Subscribes to the per-type controller so the (auto-dispose) provider
/// stays alive across the verify's async gap — otherwise its post-await
/// `state = ...` write lands on a disposed Ref and throws. Callers
/// register the returned closure with `addTearDown` to cancel the
/// subscription at the end of the test.
void Function() _keepAlive(
  ProviderContainer container,
  InferenceProviderType type,
) {
  final sub = container.listen(
    connectionVerifierControllerProvider(type),
    (_, _) {},
  );
  return sub.close;
}

void main() {
  group('ConnectionCheckState — sealed result hierarchy', () {
    test(
      'verified carries modelCount + latency so the strip can render '
      'both pieces of metadata without a follow-up read',
      () {
        const result = ConnectionCheckVerified(
          modelCount: 14,
          latency: Duration(milliseconds: 304),
        );
        expect(result.modelCount, 14);
        expect(result.latency.inMilliseconds, 304);
      },
    );

    test('failedHttp carries the HTTP status + provider error message', () {
      const result = ConnectionCheckFailedHttp(
        status: 401,
        message: 'invalid x-api-key',
      );
      expect(result.status, 401);
      expect(result.message, 'invalid x-api-key');
    });

    test('failedNetwork carries only a message (no HTTP code)', () {
      const result = ConnectionCheckFailedNetwork(message: 'Request timed out');
      expect(result.message, 'Request timed out');
    });
  });

  group('ConnectionVerifierController — state dispatch', () {
    test(
      'build() returns idle for any provider type — the resting state '
      'before the first probe',
      () {
        final container = _makeContainer(
          client: MockClient((req) async => http.Response('', 200)),
        );
        addTearDown(container.dispose);
        for (final type in InferenceProviderType.values) {
          expect(
            _readState(container, type),
            isA<ConnectionCheckIdle>(),
            reason: '$type should start idle',
          );
        }
      },
    );

    test(
      'verify() with an empty API key short-circuits to idle for cloud '
      'providers (no probe HTTP call) — the strip stays empty until the '
      'user has typed a candidate key worth probing',
      () async {
        var calls = 0;
        final container = _makeContainer(
          client: MockClient((req) async {
            calls++;
            return http.Response('{}', 200);
          }),
        );
        addTearDown(container.dispose);
        await container
            .read(
              connectionVerifierControllerProvider(
                InferenceProviderType.gemini,
              ).notifier,
            )
            .verify(baseUrl: 'https://example.com', apiKey: '');
        expect(calls, 0);
        expect(
          _readState(container, InferenceProviderType.gemini),
          isA<ConnectionCheckIdle>(),
        );
      },
    );

    test(
      'verify() with an empty API key STILL probes Ollama — local '
      'instances need no key to enumerate models',
      () async {
        var calls = 0;
        final container = _makeContainer(
          client: MockClient((req) async {
            calls++;
            return http.Response(jsonEncode({'models': <Object>[]}), 200);
          }),
        );
        addTearDown(container.dispose);
        await container
            .read(
              connectionVerifierControllerProvider(
                InferenceProviderType.ollama,
              ).notifier,
            )
            .verify(baseUrl: 'http://localhost:11434', apiKey: '');
        expect(calls, 1);
      },
    );

    test(
      'verify() against a 200 OK lands on verified with the parsed model '
      'count and a recorded latency that reflects the elapsed Stopwatch',
      () async {
        // Gemini in this app uses the OpenAI-compat probe, so the
        // expected response shape is `{"data": [...]}` (not Ollama's
        // `{"models": [...]}`) — see `_OpenAiCompatibleProbe`.
        final container = _makeContainer(
          client: MockClient((req) async {
            return http.Response(
              jsonEncode({
                'data': List.generate(7, (i) => {'id': 'model-$i'}),
              }),
              200,
            );
          }),
        );
        addTearDown(container.dispose);
        addTearDown(_keepAlive(container, InferenceProviderType.gemini));
        await container
            .read(
              connectionVerifierControllerProvider(
                InferenceProviderType.gemini,
              ).notifier,
            )
            .verify(
              baseUrl: 'https://generativelanguage.googleapis.com',
              apiKey: 'AIza-test',
            );
        final state = _readState(container, InferenceProviderType.gemini);
        expect(state, isA<ConnectionCheckVerified>());
        final verified = state as ConnectionCheckVerified;
        expect(verified.modelCount, 7);
        expect(verified.latency.inMicroseconds, greaterThanOrEqualTo(0));
      },
    );

    test(
      'verify() against a non-2xx response lands on failedHttp with the '
      'provider error.message extracted from the JSON body',
      () async {
        final container = _makeContainer(
          client: MockClient((req) async {
            return http.Response(
              jsonEncode({
                'error': {'message': 'invalid x-api-key'},
              }),
              401,
            );
          }),
        );
        addTearDown(container.dispose);
        await container
            .read(
              connectionVerifierControllerProvider(
                InferenceProviderType.anthropic,
              ).notifier,
            )
            .verify(
              baseUrl: 'https://api.anthropic.com',
              apiKey: 'sk-bad',
            );
        final state = _readState(container, InferenceProviderType.anthropic);
        expect(state, isA<ConnectionCheckFailedHttp>());
        final failed = state as ConnectionCheckFailedHttp;
        expect(failed.status, 401);
        expect(failed.message, 'invalid x-api-key');
      },
    );

    test(
      'failedHttp falls back to a body snippet when the response is not '
      'JSON (some providers return text/plain on auth failures)',
      () async {
        final container = _makeContainer(
          client: MockClient((req) async {
            return http.Response('upstream connect error', 502);
          }),
        );
        addTearDown(container.dispose);
        await container
            .read(
              connectionVerifierControllerProvider(
                InferenceProviderType.openAi,
              ).notifier,
            )
            .verify(
              baseUrl: 'https://api.openai.com/v1',
              apiKey: 'sk-test',
            );
        final state = _readState(container, InferenceProviderType.openAi);
        expect(state, isA<ConnectionCheckFailedHttp>());
        final failed = state as ConnectionCheckFailedHttp;
        expect(failed.status, 502);
        expect(failed.message, contains('upstream'));
      },
    );

    test(
      'verify() against a request that times out lands on failedNetwork — '
      'no HTTP status to report, just the timeout message',
      () async {
        final container = _makeContainer(
          client: MockClient((req) async {
            // Never resolve — the verifier's timeout fires first.
            await Future<void>.delayed(const Duration(seconds: 5));
            return http.Response('', 200);
          }),
          timeout: const Duration(milliseconds: 50),
        );
        addTearDown(container.dispose);
        addTearDown(_keepAlive(container, InferenceProviderType.gemini));
        await container
            .read(
              connectionVerifierControllerProvider(
                InferenceProviderType.gemini,
              ).notifier,
            )
            .verify(
              baseUrl: 'https://generativelanguage.googleapis.com',
              apiKey: 'AIza-test',
            );
        final state = _readState(container, InferenceProviderType.gemini);
        expect(state, isA<ConnectionCheckFailedNetwork>());
      },
    );

    test(
      'verify() against a malformed JSON body lands on failedNetwork — '
      'the format error is surfaced as a network-style problem because '
      'no usable HTTP code is available',
      () async {
        final container = _makeContainer(
          client: MockClient(
            (req) async => http.Response('not json {[', 200),
          ),
        );
        addTearDown(container.dispose);
        addTearDown(_keepAlive(container, InferenceProviderType.openAi));
        await container
            .read(
              connectionVerifierControllerProvider(
                InferenceProviderType.openAi,
              ).notifier,
            )
            .verify(
              baseUrl: 'https://api.openai.com/v1',
              apiKey: 'sk-test',
            );
        final state = _readState(container, InferenceProviderType.openAi);
        expect(state, isA<ConnectionCheckFailedNetwork>());
      },
    );

    test(
      'rapid Re-test taps: only the LATEST probe lands on state — the '
      "generation guard ensures a stale slow response can't overwrite "
      'the freshest one',
      () async {
        final completers = <Completer<http.Response>>[];
        final container = _makeContainer(
          client: MockClient((req) async {
            final c = Completer<http.Response>();
            completers.add(c);
            return c.future;
          }),
        );
        addTearDown(container.dispose);
        addTearDown(_keepAlive(container, InferenceProviderType.gemini));
        final notifier = container.read(
          connectionVerifierControllerProvider(
            InferenceProviderType.gemini,
          ).notifier,
        );

        // Fire two probes back-to-back without awaiting. The OpenAI-compat
        // probe parses `data` (not `models`) — that's the shape Gemini's
        // OpenAI-compat endpoint returns, and what the production probe
        // reads.
        final first = notifier.verify(
          baseUrl: 'https://example.com',
          apiKey: 'k1',
        );
        final second = notifier.verify(
          baseUrl: 'https://example.com',
          apiKey: 'k2',
        );

        // MockClient.send awaits before invoking the handler, so the two
        // verify calls have only just registered their async chains by
        // the time control returns here — the completers list is still
        // empty. Yield to the event loop until both handlers have run
        // before completing them, otherwise `completers[1]` is a
        // RangeError.
        while (completers.length < 2) {
          await Future<void>.delayed(Duration.zero);
        }

        // Resolve the FIRST probe last with verified=3 (stale) and the
        // SECOND probe with verified=9 (fresh) — the controller must
        // ignore the stale outcome.
        completers[1].complete(
          http.Response(
            jsonEncode({
              'data': List.generate(9, (i) => {'id': '$i'}),
            }),
            200,
          ),
        );
        await second;
        completers[0].complete(
          http.Response(
            jsonEncode({
              'data': List.generate(3, (i) => {'id': '$i'}),
            }),
            200,
          ),
        );
        await first;

        final state = _readState(container, InferenceProviderType.gemini);
        expect(state, isA<ConnectionCheckVerified>());
        expect((state as ConnectionCheckVerified).modelCount, 9);
      },
    );

    test('reset() returns the controller to idle', () async {
      final container = _makeContainer(
        client: MockClient(
          (req) async => http.Response(jsonEncode({'models': <Object>[]}), 200),
        ),
      );
      addTearDown(container.dispose);
      final notifier = container.read(
        connectionVerifierControllerProvider(
          InferenceProviderType.gemini,
        ).notifier,
      );
      await notifier.verify(baseUrl: 'https://example.com', apiKey: 'k');
      expect(
        _readState(container, InferenceProviderType.gemini),
        isA<ConnectionCheckVerified>(),
      );
      notifier.reset();
      expect(
        _readState(container, InferenceProviderType.gemini),
        isA<ConnectionCheckIdle>(),
      );
    });

    test(
      'verify() with a whitespace-only API key short-circuits to idle '
      'for cloud providers — pasted-with-stray-space keys are treated '
      'the same as a blank field rather than firing a probe that would '
      'inevitably 401',
      () async {
        var calls = 0;
        final container = _makeContainer(
          client: MockClient((req) async {
            calls++;
            return http.Response('{}', 200);
          }),
        );
        addTearDown(container.dispose);
        await container
            .read(
              connectionVerifierControllerProvider(
                InferenceProviderType.openAi,
              ).notifier,
            )
            .verify(baseUrl: 'https://api.openai.com/v1', apiKey: '   \t\n');
        expect(calls, 0);
        expect(
          _readState(container, InferenceProviderType.openAi),
          isA<ConnectionCheckIdle>(),
        );
      },
    );

    test(
      'verify() with a blank baseUrl resolves the provider default — '
      'users on the official endpoint can run the probe without '
      'retyping the URL the save path would have defaulted them to',
      () async {
        Uri? capturedUri;
        final container = _makeContainer(
          client: MockClient((req) async {
            capturedUri = req.url;
            return http.Response(jsonEncode({'data': <Object>[]}), 200);
          }),
        );
        addTearDown(container.dispose);
        addTearDown(_keepAlive(container, InferenceProviderType.openAi));
        await container
            .read(
              connectionVerifierControllerProvider(
                InferenceProviderType.openAi,
              ).notifier,
            )
            .verify(baseUrl: '   ', apiKey: 'sk-test');
        // ProviderConfig.getDefaultBaseUrl(openAi) is 'https://api.openai.com/v1';
        // the OpenAI-compat probe suffixes `/models`.
        expect(capturedUri, isNotNull);
        expect(capturedUri!.scheme, 'https');
        expect(capturedUri!.host, 'api.openai.com');
        expect(capturedUri!.path, '/v1/models');
      },
    );

    test(
      'verify() rejects URIs whose scheme is not http(s) without firing '
      'a probe — would otherwise raise ArgumentError ("Unsupported '
      'scheme") inside dart:io and pin the strip in the Checking state '
      'since Error is not caught by the `on Exception` arm',
      () async {
        var calls = 0;
        final container = _makeContainer(
          client: MockClient((req) async {
            calls++;
            return http.Response('{}', 200);
          }),
        );
        addTearDown(container.dispose);
        await container
            .read(
              connectionVerifierControllerProvider(
                InferenceProviderType.openAi,
              ).notifier,
            )
            .verify(baseUrl: 'ftp://example.com', apiKey: 'k');
        expect(calls, 0);
        final state = _readState(container, InferenceProviderType.openAi);
        expect(state, isA<ConnectionCheckFailedNetwork>());
        expect(
          (state as ConnectionCheckFailedNetwork).message,
          contains('http(s) scheme'),
        );
      },
    );

    test(
      'verify() rejects URIs whose host is empty without firing a probe '
      '— same ArgumentError prevention as the unsupported-scheme guard',
      () async {
        var calls = 0;
        final container = _makeContainer(
          client: MockClient((req) async {
            calls++;
            return http.Response('{}', 200);
          }),
        );
        addTearDown(container.dispose);
        await container
            .read(
              connectionVerifierControllerProvider(
                InferenceProviderType.openAi,
              ).notifier,
            )
            // Note: `https:///models` parses but produces an empty host.
            .verify(baseUrl: 'https:///models', apiKey: 'k');
        expect(calls, 0);
        final state = _readState(container, InferenceProviderType.openAi);
        expect(state, isA<ConnectionCheckFailedNetwork>());
        expect(
          (state as ConnectionCheckFailedNetwork).message,
          contains('http(s) scheme'),
        );
      },
    );

    test(
      'provider types with no registered probe (whisper / voxtral) '
      'short-circuit to idle without firing an HTTP call',
      () async {
        var calls = 0;
        final container = _makeContainer(
          client: MockClient((req) async {
            calls++;
            return http.Response('{}', 200);
          }),
        );
        addTearDown(container.dispose);
        for (final type in [
          InferenceProviderType.whisper,
          InferenceProviderType.voxtral,
        ]) {
          await container
              .read(connectionVerifierControllerProvider(type).notifier)
              .verify(baseUrl: 'https://example.com', apiKey: 'k');
          expect(_readState(container, type), isA<ConnectionCheckIdle>());
        }
        expect(calls, 0);
      },
    );
  });

  group('Per-provider probe — endpoint + auth shape', () {
    test(
      'Gemini probe routes through the OpenAI-compat shape (Bearer auth on '
      "`<baseUrl>/models`) — Gemini's app-configured base URL is its "
      '`/v1beta/openai` OpenAI-compatible endpoint, so building a '
      'custom `?key=` query against the same base would resolve to '
      '`/v1beta/openai/v1/models?key=...` and Gemini would answer 400. '
      'Routing the gemini-typed verifier through the OpenAI-compat probe '
      'is the fix — this test guards against accidentally re-introducing '
      'the broken native-key shape.',
      () async {
        http.BaseRequest? captured;
        final container = _makeContainer(
          client: MockClient((req) async {
            captured = req;
            return http.Response(jsonEncode({'data': <Object>[]}), 200);
          }),
        );
        addTearDown(container.dispose);
        await container
            .read(
              connectionVerifierControllerProvider(
                InferenceProviderType.gemini,
              ).notifier,
            )
            .verify(
              baseUrl:
                  'https://generativelanguage.googleapis.com/v1beta/openai',
              apiKey: 'AIza-test',
            );
        expect(captured, isNotNull);
        expect(captured!.url.path, '/v1beta/openai/models');
        expect(captured!.headers['Authorization'], 'Bearer AIza-test');
        // The legacy native shape is forbidden — no `key=` query.
        expect(captured!.url.queryParameters['key'], isNull);
      },
    );

    test(
      'OpenAI-compatible probe (OpenAI / OpenRouter / Mistral / Alibaba) '
      'targets `<baseUrl>/models` with a Bearer Authorization header',
      () async {
        http.BaseRequest? captured;
        final container = _makeContainer(
          client: MockClient((req) async {
            captured = req;
            return http.Response(jsonEncode({'data': <Object>[]}), 200);
          }),
        );
        addTearDown(container.dispose);
        await container
            .read(
              connectionVerifierControllerProvider(
                InferenceProviderType.openAi,
              ).notifier,
            )
            .verify(
              baseUrl: 'https://api.openai.com/v1',
              apiKey: 'sk-test',
            );
        expect(captured, isNotNull);
        expect(captured!.url.path, '/v1/models');
        expect(captured!.headers['Authorization'], 'Bearer sk-test');
      },
    );

    test(
      'Anthropic probe targets `/v1/models` with x-api-key + the '
      "anthropic-version header (Anthropic's versioned API contract)",
      () async {
        http.BaseRequest? captured;
        final container = _makeContainer(
          client: MockClient((req) async {
            captured = req;
            return http.Response(jsonEncode({'data': <Object>[]}), 200);
          }),
        );
        addTearDown(container.dispose);
        await container
            .read(
              connectionVerifierControllerProvider(
                InferenceProviderType.anthropic,
              ).notifier,
            )
            .verify(
              baseUrl: 'https://api.anthropic.com',
              apiKey: 'sk-ant-test',
            );
        expect(captured, isNotNull);
        expect(captured!.url.path, '/v1/models');
        expect(captured!.headers['x-api-key'], 'sk-ant-test');
        expect(captured!.headers['anthropic-version'], isNotNull);
      },
    );

    test(
      'Ollama probe targets `/api/tags` and sends NO Authorization '
      'header (local server, no auth)',
      () async {
        http.BaseRequest? captured;
        final container = _makeContainer(
          client: MockClient((req) async {
            captured = req;
            return http.Response(jsonEncode({'models': <Object>[]}), 200);
          }),
        );
        addTearDown(container.dispose);
        await container
            .read(
              connectionVerifierControllerProvider(
                InferenceProviderType.ollama,
              ).notifier,
            )
            .verify(baseUrl: 'http://localhost:11434', apiKey: '');
        expect(captured, isNotNull);
        expect(captured!.url.path, '/api/tags');
        expect(captured!.headers['Authorization'], isNull);
      },
    );

    test(
      'OpenAI-compatible probe handles top-level list payload — some '
      'self-hosted forks return `[...]` instead of `{"data": [...]}`',
      () async {
        final container = _makeContainer(
          client: MockClient((req) async {
            return http.Response(
              jsonEncode([
                {'id': 'a'},
                {'id': 'b'},
                {'id': 'c'},
              ]),
              200,
            );
          }),
        );
        addTearDown(container.dispose);
        await container
            .read(
              connectionVerifierControllerProvider(
                InferenceProviderType.genericOpenAi,
              ).notifier,
            )
            .verify(
              baseUrl: 'http://localhost:8080/v1',
              apiKey: 'sk-test',
            );
        final state = _readState(
          container,
          InferenceProviderType.genericOpenAi,
        );
        expect(state, isA<ConnectionCheckVerified>());
        expect((state as ConnectionCheckVerified).modelCount, 3);
      },
    );
  });
}
