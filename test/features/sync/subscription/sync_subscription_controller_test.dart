import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/features/sync/state/matrix_service_provider.dart';
import 'package:lotti/features/sync/state/provisioning_controller.dart';
import 'package:lotti/features/sync/state/provisioning_error.dart';
import 'package:lotti/features/sync/subscription/sync_subscription_api.dart';
import 'package:lotti/features/sync/subscription/sync_subscription_controller.dart';
import 'package:lotti/features/sync/subscription/sync_subscription_providers.dart';
import 'package:lotti/features/sync/subscription/sync_subscription_store.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

const _entitlement = SyncEntitlement(id: 'ent-1', authSecret: 'auth');
const _bundle = SyncProvisioningBundle(
  v: 2,
  kind: SyncBundleKind.provisioned,
  homeServer: 'https://matrix.example.com',
  user: '@sync_ent1:example.com',
  password: 'bootstrap',
  roomId: '!room:example.com',
);
final Uri _checkoutUrl = Uri.parse(
  'https://sync.example.com/checkout#session=s1',
);

/// Stands in for the real provisioning flow, which has its own suite; this
/// one only needs to see what the subscription flow hands it.
class _FakeProvisioning extends ProvisioningController {
  ProvisioningState outcome = const ProvisioningState.ready('handover');
  bool rejectDecode = false;
  final configured = <SyncProvisioningBundle>[];
  void Function()? onConfigure;
  Future<void> Function()? onConfigureAsync;

  @override
  ProvisioningState build() => const ProvisioningState.initial();

  @override
  SyncProvisioningBundle decodeBundle(String base64String) {
    if (rejectDecode) throw const FormatException('refused');
    return _bundle;
  }

  @override
  Future<void> configureFromBundle(SyncProvisioningBundle bundle) async {
    onConfigure?.call();
    await onConfigureAsync?.call();
    configured.add(bundle);
    state = outcome;
  }
}

class _Bench {
  _Bench() {
    when(
      () => storage.read(key: syncSubscriptionKey),
    ).thenAnswer((_) async => stored);
    when(
      () => storage.write(
        key: syncSubscriptionKey,
        value: any(named: 'value'),
      ),
    ).thenAnswer((invocation) async {
      stored = invocation.namedArguments[#value] as String;
    });
    when(matrix.isLoggedIn).thenReturn(true);
    when(
      () => matrix.publishRotationProof(
        roomId: any(named: 'roomId'),
        bundleId: any(named: 'bundleId'),
        challenge: any(named: 'challenge'),
      ),
    ).thenAnswer((_) async {});
    when(api.createEntitlement).thenAnswer((_) async => _entitlement);
    when(
      () => api.createCheckoutSession(
        any(),
        plan: any(named: 'plan'),
        claimSecret: any(named: 'claimSecret'),
      ),
    ).thenAnswer(
      (_) async => SyncCheckoutSession(id: 's1', checkoutUrl: _checkoutUrl),
    );
    when(() => api.checkoutState(any())).thenAnswer(
      (_) async => SyncCheckoutState.pending,
    );
    when(
      () => api.claim(any(), claimSecret: any(named: 'claimSecret')),
    ).thenAnswer(
      (_) async => const SyncPaidBundle(
        bundleId: 'b-1',
        bundle: 'encoded',
        rotationChallenge: 'challenge',
      ),
    );
    when(
      () => api.confirmRotation(
        any(),
        claimSecret: any(named: 'claimSecret'),
        bundleId: any(named: 'bundleId'),
      ),
    ).thenAnswer((_) async {});

    container = ProviderContainer(
      overrides: [
        syncSubscriptionApiProvider.overrideWithValue(api),
        syncSubscriptionStoreProvider.overrideWithValue(
          SyncSubscriptionStore(storage),
        ),
        syncCheckoutLauncherProvider.overrideWithValue((url) async {
          final error = launcherThrows;
          if (error != null) throw error;
          launched.add(url);
          return launcherWorks;
        }),
        matrixServiceProvider.overrideWithValue(matrix),
        provisioningControllerProvider.overrideWith(() => provisioning),
      ],
    );
    // The provider is autoDispose; the sheet keeps it alive in the app.
    watcher = container.listen(syncSubscriptionControllerProvider, (_, next) {
      states.add(next);
    });
  }

  final api = MockSyncSubscriptionApi();
  final storage = MockSecureStorage();
  final matrix = MockMatrixService();
  final provisioning = _FakeProvisioning();
  final launched = <Uri>[];
  final states = <SyncSubscribeState>[];
  bool launcherWorks = true;
  Exception? launcherThrows;
  String? stored;
  late final ProviderContainer container;
  late final ProviderSubscription<SyncSubscribeState> watcher;

  SyncSubscriptionController get controller =>
      container.read(syncSubscriptionControllerProvider.notifier);

  SyncSubscribeState get state =>
      container.read(syncSubscriptionControllerProvider);

  Map<String, dynamic>? get record =>
      stored == null ? null : jsonDecode(stored!) as Map<String, dynamic>;

  void seed(SyncSubscriptionRecord record) => stored = jsonEncode(record);

  void dispose() => container.dispose();
}

const _seeded = SyncSubscriptionRecord(
  entitlement: _entitlement,
  claimSecret: 'claim-secret',
  sessionId: 's1',
);

void main() {
  late _Bench bench;

  setUpAll(registerAllFallbackValues);
  setUp(() => bench = _Bench());
  tearDown(() => bench.dispose());

  group('subscribe', () {
    test('creates one anonymous entitlement and opens the checkout', () {
      fakeAsync((async) {
        unawaited(bench.controller.subscribe(SyncSubscriptionPlan.annual));
        async.flushMicrotasks();

        expect(bench.state, isA<SyncSubscribeAwaitingPayment>());
        expect(
          (bench.state as SyncSubscribeAwaitingPayment).checkoutUrl,
          _checkoutUrl,
        );
        expect(bench.launched, [_checkoutUrl]);
        final record = bench.record!;
        expect(record['entitlementId'], 'ent-1');
        expect(record['sessionId'], 's1');
        final claimSecret = record['claimSecret'] as String;
        // 32 random bytes, unpadded base64url.
        expect(claimSecret.length, 43);
        verify(
          () => bench.api.createCheckoutSession(
            any(),
            plan: SyncSubscriptionPlan.annual,
            claimSecret: claimSecret,
          ),
        ).called(1);

        // A second attempt reuses the stored identity.
        unawaited(bench.controller.subscribe(SyncSubscriptionPlan.monthly));
        async.flushMicrotasks();
        verify(bench.api.createEntitlement).called(1);
      });
    });

    test(
      'polls until paid, then provisions, proves rotation and confirms',
      () {
        fakeAsync((async) {
          Map<String, dynamic>? recordAtConfigure;
          bench.provisioning.onConfigure = () {
            recordAtConfigure = bench.record;
          };
          var polls = 0;
          when(() => bench.api.checkoutState('s1')).thenAnswer((_) async {
            polls++;
            return polls < 3
                ? SyncCheckoutState.pending
                : SyncCheckoutState.paid;
          });

          unawaited(bench.controller.subscribe(SyncSubscriptionPlan.monthly));
          async
            ..flushMicrotasks()
            ..elapse(syncCheckoutPollInterval * 2);
          expect(bench.state, isA<SyncSubscribeAwaitingPayment>());

          async.elapse(syncCheckoutPollInterval);

          expect(polls, 3);
          expect(bench.provisioning.configured, [_bundle]);
          // The proof was durable before the password could rotate.
          expect(recordAtConfigure!['pendingProof'], {
            'bundleId': 'b-1',
            'roomId': '!room:example.com',
            'challenge': 'challenge',
          });
          verifyInOrder([
            () => bench.matrix.publishRotationProof(
              roomId: '!room:example.com',
              bundleId: 'b-1',
              challenge: 'challenge',
            ),
            () => bench.api.confirmRotation(
              any(),
              claimSecret: any(named: 'claimSecret'),
              bundleId: 'b-1',
            ),
          ]);
          expect(bench.record!.containsKey('pendingProof'), isFalse);
          expect(bench.record!.containsKey('sessionId'), isFalse);
          expect(bench.states, contains(isA<SyncSubscribeConnecting>()));
          expect(bench.state, isA<SyncSubscribeDone>());

          // Polling stopped once paid.
          async.elapse(syncCheckoutPollInterval * 5);
          expect(polls, 3);
        });
      },
    );

    test('an entitlement that already pays claims instead of paying twice', () {
      fakeAsync((async) {
        when(
          () => bench.api.createCheckoutSession(
            any(),
            plan: any(named: 'plan'),
            claimSecret: any(named: 'claimSecret'),
          ),
        ).thenThrow(
          const SyncSubscriptionException(SyncSubscriptionFailureKind.conflict),
        );

        unawaited(bench.controller.subscribe(SyncSubscriptionPlan.annual));
        async.flushMicrotasks();

        expect(bench.launched, isEmpty);
        expect(bench.provisioning.configured, [_bundle]);
        expect(bench.state, isA<SyncSubscribeDone>());
      });
    });

    test('a launcher that throws is a browser that cannot open', () {
      fakeAsync((async) {
        bench.launcherThrows = Exception('no handler for https');

        unawaited(bench.controller.subscribe(SyncSubscriptionPlan.annual));
        async.flushMicrotasks();

        expect(
          (bench.state as SyncSubscribeFailed).failure,
          SyncSubscribeFailure.browserUnavailable,
        );
      });
    });

    test('an unexpected keystore failure brings the plans back', () {
      fakeAsync((async) {
        when(
          () => bench.storage.read(key: syncSubscriptionKey),
        ).thenAnswer((_) async => throw StateError('keystore locked'));

        unawaited(bench.controller.subscribe(SyncSubscriptionPlan.annual));
        async.flushMicrotasks();

        expect(
          (bench.state as SyncSubscribeFailed).failure,
          SyncSubscribeFailure.service,
        );
      });
    });

    test('provisioning finishes after the sheet stops watching', () {
      fakeAsync((async) {
        final release = Completer<void>();
        bench.provisioning.onConfigureAsync = () => release.future;
        when(
          () => bench.api.checkoutState('s1'),
        ).thenAnswer((_) async => SyncCheckoutState.paid);
        bench.seed(_seeded);

        unawaited(bench.controller.resume());
        async.flushMicrotasks();
        // The sheet moved to the connect page: nothing watches any more.
        bench.watcher.close();
        async.flushMicrotasks();
        release.complete();
        async.flushMicrotasks();

        verify(
          () => bench.api.confirmRotation(
            any(),
            claimSecret: any(named: 'claimSecret'),
            bundleId: 'b-1',
          ),
        ).called(1);
        expect(bench.record!.containsKey('pendingProof'), isFalse);
      });
    });

    test('a browser that cannot open is reported', () {
      fakeAsync((async) {
        bench.launcherWorks = false;

        unawaited(bench.controller.subscribe(SyncSubscriptionPlan.annual));
        async.flushMicrotasks();

        expect(
          (bench.state as SyncSubscribeFailed).failure,
          SyncSubscribeFailure.browserUnavailable,
        );
        async.elapse(syncCheckoutPollInterval * 2);
        verifyNever(() => bench.api.checkoutState(any()));
      });
    });

    test(
      'an unreachable service is offline, any other failure a service error',
      () {
        fakeAsync((async) {
          when(bench.api.createEntitlement).thenThrow(
            const SyncSubscriptionException(
              SyncSubscriptionFailureKind.offline,
            ),
          );
          unawaited(bench.controller.subscribe(SyncSubscriptionPlan.annual));
          async.flushMicrotasks();
          expect(
            (bench.state as SyncSubscribeFailed).failure,
            SyncSubscribeFailure.offline,
          );

          when(bench.api.createEntitlement).thenThrow(
            const SyncSubscriptionException(SyncSubscriptionFailureKind.server),
          );
          unawaited(bench.controller.subscribe(SyncSubscriptionPlan.annual));
          async.flushMicrotasks();
          expect(
            (bench.state as SyncSubscribeFailed).failure,
            SyncSubscribeFailure.service,
          );
        });
      },
    );
  });

  group('waiting for payment', () {
    test('a dropped connection keeps polling; a lost session stops it', () {
      fakeAsync((async) {
        when(() => bench.api.checkoutState('s1')).thenThrow(
          const SyncSubscriptionException(SyncSubscriptionFailureKind.offline),
        );
        unawaited(bench.controller.subscribe(SyncSubscriptionPlan.annual));
        async
          ..flushMicrotasks()
          ..elapse(syncCheckoutPollInterval * 2);
        expect(bench.state, isA<SyncSubscribeAwaitingPayment>());

        when(() => bench.api.checkoutState('s1')).thenThrow(
          const SyncSubscriptionException(SyncSubscriptionFailureKind.notFound),
        );
        async.elapse(syncCheckoutPollInterval);
        expect(
          (bench.state as SyncSubscribeFailed).failure,
          SyncSubscribeFailure.service,
        );
        clearInteractions(bench.api);
        async.elapse(syncCheckoutPollInterval * 3);
        verifyNever(() => bench.api.checkoutState(any()));
      });
    });

    test('an unexpected error while polling fails the flow, not the zone', () {
      fakeAsync((async) {
        when(
          () => bench.api.checkoutState('s1'),
        ).thenAnswer((_) async => throw StateError('corrupt response'));

        unawaited(bench.controller.subscribe(SyncSubscriptionPlan.annual));
        async
          ..flushMicrotasks()
          ..elapse(syncCheckoutPollInterval);

        expect(
          (bench.state as SyncSubscribeFailed).failure,
          SyncSubscribeFailure.service,
        );
        clearInteractions(bench.api);
        async.elapse(syncCheckoutPollInterval * 3);
        verifyNever(() => bench.api.checkoutState(any()));
      });
    });

    test('an expired session forgets itself and asks for a plan again', () {
      fakeAsync((async) {
        when(
          () => bench.api.checkoutState('s1'),
        ).thenAnswer((_) async => SyncCheckoutState.expired);

        unawaited(bench.controller.subscribe(SyncSubscriptionPlan.annual));
        async
          ..flushMicrotasks()
          ..elapse(syncCheckoutPollInterval);

        expect(bench.state, isA<SyncSubscribeCheckoutExpired>());
        expect(bench.record!.containsKey('sessionId'), isFalse);
      });
    });

    test('reopen launches the same checkout; cancel stops waiting', () {
      fakeAsync((async) {
        unawaited(bench.controller.subscribe(SyncSubscriptionPlan.annual));
        async.flushMicrotasks();

        unawaited(bench.controller.reopenCheckout());
        async.flushMicrotasks();
        expect(bench.launched, [_checkoutUrl, _checkoutUrl]);

        bench.controller.cancel();
        expect(bench.state, isA<SyncSubscribeIdle>());
        clearInteractions(bench.api);
        async.elapse(syncCheckoutPollInterval * 3);
        verifyNever(() => bench.api.checkoutState(any()));

        // Nothing to reopen once idle.
        unawaited(bench.controller.reopenCheckout());
        async.flushMicrotasks();
        expect(bench.launched, hasLength(2));
      });
    });
  });

  group('claim', () {
    void payImmediately() => when(
      () => bench.api.checkoutState('s1'),
    ).thenAnswer((_) async => SyncCheckoutState.paid);

    test('an account set up before cannot be claimed again', () {
      fakeAsync((async) {
        payImmediately();
        when(
          () => bench.api.claim(any(), claimSecret: any(named: 'claimSecret')),
        ).thenAnswer(
          (_) async => const SyncPaidBundle(
            bundleId: 'b-1',
            bundle: null,
            rotationChallenge: null,
          ),
        );
        bench.seed(_seeded);

        unawaited(bench.controller.resume());
        async.flushMicrotasks();

        expect(
          (bench.state as SyncSubscribeFailed).failure,
          SyncSubscribeFailure.alreadySetUp,
        );
        expect(bench.provisioning.configured, isEmpty);
      });
    });

    test('a bundle this app refuses is not imported', () {
      fakeAsync((async) {
        payImmediately();
        bench
          ..provisioning.rejectDecode = true
          ..seed(_seeded);

        unawaited(bench.controller.resume());
        async.flushMicrotasks();

        expect(
          (bench.state as SyncSubscribeFailed).failure,
          SyncSubscribeFailure.invalidBundle,
        );
        expect(bench.provisioning.configured, isEmpty);
        expect(bench.record!.containsKey('pendingProof'), isFalse);
      });
    });

    test('a failed connection keeps the proof and confirms nothing', () {
      fakeAsync((async) {
        payImmediately();
        bench
          ..provisioning.outcome = const ProvisioningState.error(
            ProvisioningError.loginFailed,
          )
          ..seed(_seeded);

        unawaited(bench.controller.resume());
        async.flushMicrotasks();

        expect(bench.state, isA<SyncSubscribeConnecting>());
        expect(bench.record!['pendingProof'], isNotNull);
        // Kept, so the next visit resumes the paid claim.
        expect(bench.record!['sessionId'], 's1');
        verifyNever(
          () => bench.api.confirmRotation(
            any(),
            claimSecret: any(named: 'claimSecret'),
            bundleId: any(named: 'bundleId'),
          ),
        );
      });
    });

    test('a refused claim is a service failure', () {
      fakeAsync((async) {
        payImmediately();
        when(
          () => bench.api.claim(any(), claimSecret: any(named: 'claimSecret')),
        ).thenThrow(
          const SyncSubscriptionException(SyncSubscriptionFailureKind.conflict),
        );
        bench.seed(_seeded);

        unawaited(bench.controller.resume());
        async.flushMicrotasks();

        expect(
          (bench.state as SyncSubscribeFailed).failure,
          SyncSubscribeFailure.service,
        );
      });
    });
  });

  group('resume without a session', () {
    const sessionless = SyncSubscriptionRecord(
      entitlement: _entitlement,
      claimSecret: 'claim-secret',
    );

    test('a device that does not sync yet claims a late payment', () {
      fakeAsync((async) {
        when(bench.matrix.isLoggedIn).thenReturn(false);
        bench.seed(sessionless);

        unawaited(bench.controller.resume());
        async.flushMicrotasks();

        expect(bench.provisioning.configured, [_bundle]);
        verifyNever(() => bench.api.checkoutState(any()));
      });
    });

    test('an unpaid entitlement just shows the plans again', () {
      fakeAsync((async) {
        when(bench.matrix.isLoggedIn).thenReturn(false);
        when(
          () => bench.api.claim(any(), claimSecret: any(named: 'claimSecret')),
        ).thenThrow(
          const SyncSubscriptionException(
            SyncSubscriptionFailureKind.paymentPending,
          ),
        );
        bench.seed(sessionless);

        unawaited(bench.controller.resume());
        async.flushMicrotasks();

        expect(bench.state, isA<SyncSubscribeIdle>());
      });
    });

    const owed = PendingRotationProof(
      bundleId: 'b-1',
      roomId: '!room:example.com',
      challenge: 'challenge',
    );

    test('a syncing device that owes a proof only confirms it', () {
      fakeAsync((async) {
        bench.seed(sessionless.withPendingProof(owed));

        unawaited(bench.controller.resume());
        async.flushMicrotasks();

        // The live session is never logged out for the spent bootstrap code.
        expect(bench.provisioning.configured, isEmpty);
        verifyNever(
          () => bench.api.claim(any(), claimSecret: any(named: 'claimSecret')),
        );
        verify(
          () => bench.api.confirmRotation(
            any(),
            claimSecret: 'claim-secret',
            bundleId: 'b-1',
          ),
        ).called(1);
        expect(bench.record!.containsKey('pendingProof'), isFalse);
      });
    });

    test('a kept session never reclaims on a device that owes a proof', () {
      fakeAsync((async) {
        when(
          () => bench.api.checkoutState('s1'),
        ).thenAnswer((_) async => SyncCheckoutState.paid);
        bench.seed(_seeded.withPendingProof(owed));

        unawaited(bench.controller.resume());
        async.flushMicrotasks();

        expect(bench.provisioning.configured, isEmpty);
        verifyNever(() => bench.api.checkoutState(any()));
        expect(bench.record!.containsKey('pendingProof'), isFalse);
        expect(bench.record!.containsKey('sessionId'), isFalse);
      });
    });

    test('an unconfirmed proof keeps the session for the next visit', () {
      fakeAsync((async) {
        when(
          () => bench.api.confirmRotation(
            any(),
            claimSecret: any(named: 'claimSecret'),
            bundleId: any(named: 'bundleId'),
          ),
        ).thenThrow(
          const SyncSubscriptionException(SyncSubscriptionFailureKind.offline),
        );
        bench.seed(_seeded.withPendingProof(owed));

        unawaited(bench.controller.resume());
        async.flushMicrotasks();

        expect(bench.provisioning.configured, isEmpty);
        expect(bench.record!['sessionId'], 's1');
        expect(bench.record!['pendingProof'], isNotNull);
      });
    });

    test('a device whose connect failed retries it', () {
      fakeAsync((async) {
        when(bench.matrix.isLoggedIn).thenReturn(false);
        bench.seed(sessionless.withPendingProof(owed));

        unawaited(bench.controller.resume());
        async.flushMicrotasks();

        expect(bench.provisioning.configured, [_bundle]);
      });
    });

    test('a syncing device with nothing owed claims nothing', () {
      fakeAsync((async) {
        bench.seed(sessionless);

        unawaited(bench.controller.resume());
        async.flushMicrotasks();

        verifyNever(
          () => bench.api.claim(any(), claimSecret: any(named: 'claimSecret')),
        );
        expect(bench.state, isA<SyncSubscribeIdle>());
      });
    });

    test('an unexpected error is reported', () {
      fakeAsync((async) {
        when(bench.matrix.isLoggedIn).thenReturn(false);
        when(
          () => bench.api.claim(any(), claimSecret: any(named: 'claimSecret')),
        ).thenAnswer((_) async => throw StateError('keystore locked'));
        bench.seed(sessionless);

        unawaited(bench.controller.resume());
        async.flushMicrotasks();

        expect(
          (bench.state as SyncSubscribeFailed).failure,
          SyncSubscribeFailure.service,
        );
      });
    });
  });

  group('resume', () {
    test('without a stored session there is nothing to resume', () {
      fakeAsync((async) {
        unawaited(bench.controller.resume());
        async.flushMicrotasks();

        expect(bench.state, isA<SyncSubscribeIdle>());
        verifyNever(() => bench.api.checkoutState(any()));
      });
    });

    test('a pending session keeps waiting without a URL to reopen', () {
      fakeAsync((async) {
        bench.seed(_seeded);

        unawaited(bench.controller.resume());
        async.flushMicrotasks();

        expect(bench.state, isA<SyncSubscribeAwaitingPayment>());
        expect(
          (bench.state as SyncSubscribeAwaitingPayment).checkoutUrl,
          isNull,
        );
        async.elapse(syncCheckoutPollInterval);
        verify(() => bench.api.checkoutState('s1')).called(2);
      });
    });

    test('an expired session is forgotten quietly', () {
      fakeAsync((async) {
        when(
          () => bench.api.checkoutState('s1'),
        ).thenAnswer((_) async => SyncCheckoutState.expired);
        bench.seed(_seeded);

        unawaited(bench.controller.resume());
        async.flushMicrotasks();

        expect(bench.state, isA<SyncSubscribeIdle>());
        expect(bench.record!.containsKey('sessionId'), isFalse);
      });
    });

    test('an unexpected error while resuming is reported', () {
      fakeAsync((async) {
        when(
          () => bench.api.checkoutState('s1'),
        ).thenAnswer((_) async => SyncCheckoutState.paid);
        when(
          () => bench.api.claim(any(), claimSecret: any(named: 'claimSecret')),
        ).thenAnswer((_) async => throw StateError('keystore locked'));
        bench.seed(_seeded);

        unawaited(bench.controller.resume());
        async.flushMicrotasks();

        expect(
          (bench.state as SyncSubscribeFailed).failure,
          SyncSubscribeFailure.service,
        );
      });
    });

    test('an unreachable service leaves the plan choice up', () {
      fakeAsync((async) {
        when(() => bench.api.checkoutState('s1')).thenThrow(
          const SyncSubscriptionException(SyncSubscriptionFailureKind.offline),
        );
        bench.seed(_seeded);

        unawaited(bench.controller.resume());
        async.flushMicrotasks();

        expect(bench.state, isA<SyncSubscribeIdle>());
      });
    });
  });

  group('RotationConfirmer', () {
    const proof = PendingRotationProof(
      bundleId: 'b-1',
      roomId: '!room:example.com',
      challenge: 'challenge',
    );

    Future<bool> confirm() =>
        bench.container.read(rotationConfirmerProvider).confirmPending();

    test('confirms a pending proof once and forgets it', () async {
      bench.seed(_seeded.withPendingProof(proof));

      expect(await confirm(), isTrue);
      expect(bench.record!.containsKey('pendingProof'), isFalse);
      expect(await confirm(), isFalse);
      verify(
        () => bench.api.confirmRotation(
          any(),
          claimSecret: 'claim-secret',
          bundleId: 'b-1',
        ),
      ).called(1);
    });

    test('keeps the proof when the service cannot be told', () async {
      bench.seed(_seeded.withPendingProof(proof));
      when(
        () => bench.api.confirmRotation(
          any(),
          claimSecret: any(named: 'claimSecret'),
          bundleId: any(named: 'bundleId'),
        ),
      ).thenThrow(
        const SyncSubscriptionException(SyncSubscriptionFailureKind.offline),
      );

      expect(await confirm(), isFalse);
      expect(bench.record!['pendingProof'], isNotNull);
    });

    test('waits for a logged-in session and a configured service', () async {
      bench.seed(_seeded.withPendingProof(proof));
      when(() => bench.matrix.isLoggedIn()).thenReturn(false);

      expect(await confirm(), isFalse);

      final noService = RotationConfirmer(
        api: null,
        store: SyncSubscriptionStore(bench.storage),
        matrixService: bench.matrix,
      );
      when(() => bench.matrix.isLoggedIn()).thenReturn(true);
      expect(await noService.confirmPending(), isFalse);
      verifyNever(
        () => bench.matrix.publishRotationProof(
          roomId: any(named: 'roomId'),
          bundleId: any(named: 'bundleId'),
          challenge: any(named: 'challenge'),
        ),
      );
    });

    test('the Devices page recovery provider runs it', () async {
      bench.seed(_seeded.withPendingProof(proof));

      expect(
        await bench.container.read(pendingRotationRecoveryProvider.future),
        isTrue,
      );
    });
  });
}
