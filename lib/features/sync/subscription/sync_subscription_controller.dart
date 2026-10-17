import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/state/matrix_service_provider.dart';
import 'package:lotti/features/sync/state/provisioning_controller.dart';
import 'package:lotti/features/sync/subscription/sync_subscription_api.dart';
import 'package:lotti/features/sync/subscription/sync_subscription_providers.dart';
import 'package:lotti/features/sync/subscription/sync_subscription_store.dart';

/// Where the subscribe flow stands.
sealed class SyncSubscribeState {
  const SyncSubscribeState();
}

/// Nothing in flight: the plan choice is shown.
class SyncSubscribeIdle extends SyncSubscribeState {
  const SyncSubscribeIdle();
}

/// Creating the entitlement and checkout session, opening the browser.
class SyncSubscribeOpening extends SyncSubscribeState {
  const SyncSubscribeOpening();
}

/// The checkout is open in the browser; the session is polled until paid.
/// [checkoutUrl] is null after a restart, when only the session id survived.
class SyncSubscribeAwaitingPayment extends SyncSubscribeState {
  const SyncSubscribeAwaitingPayment(this.checkoutUrl);

  final Uri? checkoutUrl;
}

/// The checkout session timed out unpaid.
class SyncSubscribeCheckoutExpired extends SyncSubscribeState {
  const SyncSubscribeCheckoutExpired();
}

/// Paid; fetching the account's provisioning bundle.
class SyncSubscribeClaiming extends SyncSubscribeState {
  const SyncSubscribeClaiming();
}

/// Handed to the provisioning flow, which narrates on the connect page.
class SyncSubscribeConnecting extends SyncSubscribeState {
  const SyncSubscribeConnecting();
}

/// Connected and confirmed with the service.
class SyncSubscribeDone extends SyncSubscribeState {
  const SyncSubscribeDone();
}

class SyncSubscribeFailed extends SyncSubscribeState {
  const SyncSubscribeFailed(this.failure);

  final SyncSubscribeFailure failure;
}

/// What went wrong, as the subscribe screen explains it.
enum SyncSubscribeFailure {
  /// The service could not be reached.
  offline,

  /// The service refused or failed; trying again later may help.
  service,

  /// The browser could not be opened.
  browserUnavailable,

  /// The account was set up before and its one-time credential is spent:
  /// add this device from a device that already syncs.
  alreadySetUp,

  /// The delivered bundle was refused by this app (e.g. not signed).
  invalidBundle,
}

/// How often the checkout session is polled while the browser is open. The
/// status route is cheap (no secret hashing) and rate-limited by nginx.
const syncCheckoutPollInterval = Duration(seconds: 3);

final NotifierProvider<SyncSubscriptionController, SyncSubscribeState>
syncSubscriptionControllerProvider =
    NotifierProvider.autoDispose<
      SyncSubscriptionController,
      SyncSubscribeState
    >(
      SyncSubscriptionController.new,
      name: 'syncSubscriptionControllerProvider',
    );

/// Drives web checkout from the plan choice to a connected device.
///
/// The bundle goes through the same [ProvisioningController] a pairing code
/// does, so verification, login, room join and password rotation are not
/// duplicated here; this controller only gets the bundle and, afterwards,
/// proves the rotation to the service.
class SyncSubscriptionController extends Notifier<SyncSubscribeState> {
  Timer? _poll;
  bool _polling = false;

  @override
  SyncSubscribeState build() {
    ref.onDispose(_stopPolling);
    return const SyncSubscribeIdle();
  }

  SyncSubscriptionApi get _api => ref.read(syncSubscriptionApiProvider)!;
  SyncSubscriptionStore get _store => ref.read(syncSubscriptionStoreProvider);

  /// Picks up where a previous run stopped: a session still awaiting payment,
  /// or a paid one whose bundle was never claimed.
  Future<void> resume() async {
    final record = await _store.load();
    final sessionId = record?.sessionId;
    if (record == null || sessionId == null) return;
    try {
      switch (await _api.checkoutState(sessionId)) {
        case SyncCheckoutState.paid:
          await _claimAndConnect(record);
        case SyncCheckoutState.pending:
          state = const SyncSubscribeAwaitingPayment(null);
          _startPolling(record);
        case SyncCheckoutState.expired:
          await _store.save(record.withSession(null));
      }
    } on SyncSubscriptionException {
      // Nothing to resume that can be resumed now; the plan choice stays.
    }
  }

  /// Opens the checkout for [plan] in the browser and waits for payment.
  Future<void> subscribe(SyncSubscriptionPlan plan) async {
    _stopPolling();
    state = const SyncSubscribeOpening();
    try {
      final record = await _ensureRecord();
      final session = await _api.createCheckoutSession(
        record.entitlement,
        plan: plan,
        claimSecret: record.claimSecret,
      );
      final withSession = record.withSession(session.id);
      await _store.save(withSession);
      if (!await ref.read(syncCheckoutLauncherProvider)(session.checkoutUrl)) {
        state = const SyncSubscribeFailed(
          SyncSubscribeFailure.browserUnavailable,
        );
        return;
      }
      state = SyncSubscribeAwaitingPayment(session.checkoutUrl);
      _startPolling(withSession);
    } on SyncSubscriptionException catch (e) {
      state = SyncSubscribeFailed(_failureOf(e));
    }
  }

  /// Opens the same checkout again, e.g. after the browser tab was closed.
  Future<void> reopenCheckout() async {
    final current = state;
    final url = current is SyncSubscribeAwaitingPayment
        ? current.checkoutUrl
        : null;
    if (url == null) return;
    await ref.read(syncCheckoutLauncherProvider)(url);
  }

  /// Stops waiting and returns to the plan choice. A payment that still
  /// completes is picked up by [resume] the next time the screen opens.
  void cancel() {
    _stopPolling();
    state = const SyncSubscribeIdle();
  }

  Future<SyncSubscriptionRecord> _ensureRecord() async {
    final existing = await _store.load();
    if (existing != null) return existing;
    final record = SyncSubscriptionRecord(
      entitlement: await _api.createEntitlement(),
      claimSecret: _generateSecret(),
    );
    await _store.save(record);
    return record;
  }

  void _startPolling(SyncSubscriptionRecord record) {
    _poll?.cancel();
    _poll = Timer.periodic(
      syncCheckoutPollInterval,
      (_) => unawaited(_pollOnce(record)),
    );
  }

  void _stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  Future<void> _pollOnce(SyncSubscriptionRecord record) async {
    final sessionId = record.sessionId;
    if (_polling || sessionId == null) return;
    _polling = true;
    try {
      switch (await _api.checkoutState(sessionId)) {
        case SyncCheckoutState.pending:
          break;
        case SyncCheckoutState.paid:
          _stopPolling();
          await _claimAndConnect(record);
        case SyncCheckoutState.expired:
          _stopPolling();
          await _store.save(record.withSession(null));
          state = const SyncSubscribeCheckoutExpired();
      }
    } on SyncSubscriptionException catch (e) {
      // A dropped connection while the user is paying is expected; keep
      // polling. Anything else means the session cannot complete.
      if (e.kind != SyncSubscriptionFailureKind.offline &&
          e.kind != SyncSubscriptionFailureKind.rateLimited) {
        _stopPolling();
        state = SyncSubscribeFailed(_failureOf(e));
      }
    } finally {
      _polling = false;
    }
  }

  Future<void> _claimAndConnect(SyncSubscriptionRecord record) async {
    state = const SyncSubscribeClaiming();
    final SyncPaidBundle paid;
    try {
      paid = await _api.claim(
        record.entitlement,
        claimSecret: record.claimSecret,
      );
    } on SyncSubscriptionException catch (e) {
      state = SyncSubscribeFailed(_failureOf(e));
      return;
    }
    final encoded = paid.bundle;
    final challenge = paid.rotationChallenge;
    if (encoded == null || challenge == null) {
      await _store.save(record.withSession(null));
      state = const SyncSubscribeFailed(SyncSubscribeFailure.alreadySetUp);
      return;
    }

    final provisioning = ref.read(provisioningControllerProvider.notifier);
    final bundle = _decode(provisioning, encoded);
    if (bundle == null) {
      state = const SyncSubscribeFailed(SyncSubscribeFailure.invalidBundle);
      return;
    }
    // Saved before the password rotates: if the app dies after rotating,
    // the proof is what keeps the service from deactivating the account.
    final pending = record
        .withSession(null)
        .withPendingProof(
          PendingRotationProof(
            bundleId: paid.bundleId,
            roomId: bundle.roomId,
            challenge: challenge,
          ),
        );
    await _store.save(pending);

    state = const SyncSubscribeConnecting();
    await provisioning.configureFromBundle(bundle);
    final outcome = ref.read(provisioningControllerProvider);
    final connected = outcome.maybeWhen(
      ready: (_) => true,
      done: () => true,
      orElse: () => false,
    );
    if (!connected) {
      // The connect page shows why; the bundle stays claimable for a retry.
      return;
    }
    await ref.read(rotationConfirmerProvider).confirmPending();
    state = const SyncSubscribeDone();
  }

  static SyncProvisioningBundle? _decode(
    ProvisioningController provisioning,
    String encoded,
  ) {
    try {
      return provisioning.decodeBundle(encoded);
    } on FormatException {
      return null;
    }
  }

  static SyncSubscribeFailure _failureOf(SyncSubscriptionException e) =>
      switch (e.kind) {
        SyncSubscriptionFailureKind.offline => SyncSubscribeFailure.offline,
        _ => SyncSubscribeFailure.service,
      };

  static String _generateSecret() {
    final random = Random.secure();
    return base64UrlEncode(
      List<int>.generate(32, (_) => random.nextInt(256)),
    ).replaceAll('=', '');
  }
}

/// Finishes the paid bootstrap: publishes the rotation proof in the room and
/// tells the service, which then destroys the escrowed bundle and stops
/// counting the account as abandoned.
///
/// Idempotent and safe to call on every visit to the Devices page: it does
/// nothing without a pending proof, and keeps the proof on any failure so the
/// next call retries.
class RotationConfirmer {
  const RotationConfirmer({
    required this._api,
    required this._store,
    required this._matrixService,
  });

  final SyncSubscriptionApi? _api;
  final SyncSubscriptionStore _store;
  final MatrixService _matrixService;

  /// Returns whether a pending proof was confirmed by this call.
  Future<bool> confirmPending() async {
    final api = _api;
    if (api == null) return false;
    final record = await _store.load();
    final proof = record?.pendingProof;
    if (record == null || proof == null || !_matrixService.isLoggedIn()) {
      return false;
    }
    try {
      await _matrixService.publishRotationProof(
        roomId: proof.roomId,
        bundleId: proof.bundleId,
        challenge: proof.challenge,
      );
      await api.confirmRotation(
        record.entitlement,
        claimSecret: record.claimSecret,
        bundleId: proof.bundleId,
      );
    } on Object {
      return false;
    }
    await _store.save(record.withPendingProof(null));
    return true;
  }
}

/// Runs [RotationConfirmer.confirmPending] once per visit of the Devices
/// page; resolves to whether a pending proof was confirmed.
final FutureProvider<bool> pendingRotationRecoveryProvider =
    FutureProvider.autoDispose<bool>(
      (ref) => ref.read(rotationConfirmerProvider).confirmPending(),
      name: 'pendingRotationRecoveryProvider',
    );

final Provider<RotationConfirmer> rotationConfirmerProvider =
    Provider.autoDispose<RotationConfirmer>(
      (ref) => RotationConfirmer(
        api: ref.watch(syncSubscriptionApiProvider),
        store: ref.watch(syncSubscriptionStoreProvider),
        matrixService: ref.watch(matrixServiceProvider),
      ),
      name: 'rotationConfirmerProvider',
    );
