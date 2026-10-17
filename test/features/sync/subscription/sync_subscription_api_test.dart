import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lotti/features/sync/subscription/sync_subscription_api.dart';

const _entitlement = SyncEntitlement(id: 'ent-1', authSecret: 'auth-secret');
final _base = Uri.parse('https://api.example.com/');

class _Recorder {
  final requests = <http.Request>[];
}

SyncSubscriptionApi _api(
  _Recorder recorder,
  http.Response Function(http.Request request) respond,
) => SyncSubscriptionApi(
  baseUrl: _base,
  httpClient: MockClient((request) async {
    recorder.requests.add(request);
    return respond(request);
  }),
);

http.Response _json(Object body, {int status = 200}) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

Matcher _failsWith(SyncSubscriptionFailureKind kind) => throwsA(
  isA<SyncSubscriptionException>().having((e) => e.kind, 'kind', kind),
);

void main() {
  group('requests', () {
    test('entitlement creation is anonymous and returns the secret', () async {
      final recorder = _Recorder();
      final api = _api(
        recorder,
        (_) => _json({
          'entitlement_id': 'ent-1',
          'auth_secret': 'auth-secret',
          'obfuscated_account_id': 'ignored',
        }, status: 201),
      );

      final entitlement = await api.createEntitlement();

      expect(entitlement.id, 'ent-1');
      expect(entitlement.authSecret, 'auth-secret');
      final request = recorder.requests.single;
      expect(
        request.url.toString(),
        'https://api.example.com/api/v1/client/subscriptions/entitlements',
      );
      expect(request.headers.containsKey('Authorization'), isFalse);
    });

    test('a checkout session names the plan and carries the bearer', () async {
      final recorder = _Recorder();
      final api = _api(
        recorder,
        (_) => _json({
          'session_id': 'sess-1',
          'checkout_url': 'https://sync.example.com/checkout#session=sess-1',
          'expires_at': '2026-10-17T12:30:00Z',
        }, status: 201),
      );

      final session = await api.createCheckoutSession(
        _entitlement,
        plan: SyncSubscriptionPlan.annual,
        claimSecret: 'claim-secret',
      );

      expect(session.id, 'sess-1');
      expect(session.checkoutUrl.fragment, 'session=sess-1');
      final request = recorder.requests.single;
      expect(request.headers['Authorization'], 'Bearer auth-secret');
      expect(request.followRedirects, isFalse);
      expect(jsonDecode(request.body), {
        'entitlement_id': 'ent-1',
        'plan': 'annual',
        'claim_secret': 'claim-secret',
      });
    });

    test('a non-https checkout URL is refused', () async {
      final api = _api(
        _Recorder(),
        (_) => _json({
          'session_id': 'sess-1',
          'checkout_url': 'http://sync.example.com/checkout',
        }, status: 201),
      );

      expect(
        () => api.createCheckoutSession(
          _entitlement,
          plan: SyncSubscriptionPlan.monthly,
          claimSecret: 'claim-secret',
        ),
        _failsWith(SyncSubscriptionFailureKind.invalidResponse),
      );
    });

    for (final state in SyncCheckoutState.values) {
      test(
        'session status ${state.name} is read without credentials',
        () async {
          final recorder = _Recorder();
          final api = _api(recorder, (_) => _json({'state': state.name}));

          expect(await api.checkoutState('sess-1'), state);
          expect(jsonDecode(recorder.requests.single.body), {
            'session_id': 'sess-1',
          });
          expect(
            recorder.requests.single.headers.containsKey('Authorization'),
            isFalse,
          );
        },
      );
    }

    test('an unknown session state is an invalid response', () async {
      final api = _api(_Recorder(), (_) => _json({'state': 'refunded'}));

      expect(
        () => api.checkoutState('sess-1'),
        _failsWith(SyncSubscriptionFailureKind.invalidResponse),
      );
    });

    test('a claim returns the bundle and its rotation challenge', () async {
      final recorder = _Recorder();
      final api = _api(
        recorder,
        (_) => _json({
          'bundle_id': 'b-1',
          'bundle': 'encoded',
          'expires_at': null,
          'rotation_challenge': 'challenge',
          'bundle_import_required': true,
          'entitlement_state': 'active',
        }),
      );

      final paid = await api.claim(_entitlement, claimSecret: 'claim-secret');

      expect(paid.bundleId, 'b-1');
      expect(paid.bundle, 'encoded');
      expect(paid.rotationChallenge, 'challenge');
      expect(jsonDecode(recorder.requests.single.body), {
        'entitlement_id': 'ent-1',
        'claim_secret': 'claim-secret',
      });
    });

    test('rotation confirmation accepts a 204', () async {
      final recorder = _Recorder();
      final api = _api(recorder, (_) => http.Response('', 204));

      await api.confirmRotation(
        _entitlement,
        claimSecret: 'claim-secret',
        bundleId: 'b-1',
      );

      expect(
        recorder.requests.single.url.path,
        '/api/v1/client/subscriptions/bundle-claims/confirm-rotation',
      );
      expect(jsonDecode(recorder.requests.single.body)['bundle_id'], 'b-1');
    });

    test('the portal link must be https', () async {
      final good = _api(
        _Recorder(),
        (_) => _json({'url': 'https://customer-portal.paddle.com/cpl_1'}),
      );
      final bad = _api(
        _Recorder(),
        (_) => _json({'url': 'javascript:alert(1)'}),
      );

      expect(
        await good.portalUrl(_entitlement),
        Uri.parse('https://customer-portal.paddle.com/cpl_1'),
      );
      expect(
        () => bad.portalUrl(_entitlement),
        _failsWith(SyncSubscriptionFailureKind.invalidResponse),
      );
    });
  });

  group('failures', () {
    final byStatus = {
      401: SyncSubscriptionFailureKind.unauthorized,
      402: SyncSubscriptionFailureKind.paymentPending,
      404: SyncSubscriptionFailureKind.notFound,
      409: SyncSubscriptionFailureKind.conflict,
      422: SyncSubscriptionFailureKind.refused,
      429: SyncSubscriptionFailureKind.rateLimited,
      500: SyncSubscriptionFailureKind.server,
      503: SyncSubscriptionFailureKind.server,
      302: SyncSubscriptionFailureKind.invalidResponse,
    };
    for (final MapEntry(key: status, value: kind) in byStatus.entries) {
      test('HTTP $status is ${kind.name}', () {
        final api = _api(_Recorder(), (_) => _json({}, status: status));

        expect(() => api.checkoutState('sess-1'), _failsWith(kind));
      });
    }

    test('a failure names its kind when logged', () {
      expect(
        const SyncSubscriptionException(
          SyncSubscriptionFailureKind.paymentPending,
        ).toString(),
        'SyncSubscriptionException(paymentPending)',
      );
    });

    test('a rate limit carries its Retry-After', () async {
      final api = _api(
        _Recorder(),
        (_) => http.Response('{}', 429, headers: {'retry-after': '42'}),
      );

      await expectLater(
        () => api.checkoutState('sess-1'),
        throwsA(
          isA<SyncSubscriptionException>().having(
            (e) => e.retryAfter,
            'retryAfter',
            const Duration(seconds: 42),
          ),
        ),
      );
    });

    for (final body in ['not json', '[1, 2]']) {
      test('a 200 with body "$body" is an invalid response', () {
        final api = _api(_Recorder(), (_) => http.Response(body, 200));

        expect(
          () => api.checkoutState('sess-1'),
          _failsWith(SyncSubscriptionFailureKind.invalidResponse),
        );
      });
    }

    test('a missing field is an invalid response', () {
      final api = _api(_Recorder(), (_) => _json({'entitlement_id': 'x'}));

      expect(
        api.createEntitlement,
        _failsWith(SyncSubscriptionFailureKind.invalidResponse),
      );
    });

    for (final error in <Object>[
      const SocketException('down'),
      http.ClientException('reset'),
      const HandshakeException('tls'),
    ]) {
      test('${error.runtimeType} is offline', () {
        final api = SyncSubscriptionApi(
          baseUrl: _base,
          httpClient: MockClient((_) async => throw error),
        );

        expect(
          () => api.checkoutState('sess-1'),
          _failsWith(SyncSubscriptionFailureKind.offline),
        );
      });
    }

    test('a request that never answers times out as offline', () {
      fakeAsync((async) {
        final api = SyncSubscriptionApi(
          baseUrl: _base,
          httpClient: MockClient((_) => Completer<http.Response>().future),
        );
        Object? failure;
        unawaited(
          api.checkoutState('sess-1').catchError((Object e) {
            failure = e;
            return SyncCheckoutState.pending;
          }),
        );

        async.elapse(SyncSubscriptionApi.timeout + const Duration(seconds: 1));

        expect(
          failure,
          isA<SyncSubscriptionException>().having(
            (e) => e.kind,
            'kind',
            SyncSubscriptionFailureKind.offline,
          ),
        );
      });
    });
  });
}
