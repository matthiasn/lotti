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
  /// or a paid one whose bundle was never claimed or never connected.
  Future<void> resume() async {
    final record = await _store.load();
    if (record == null) return;
    final loggedIn = ref.read(matrixServiceProvider).isLoggedIn();
    if (loggedIn && record.pendingProof != null) {
      // A device that syncs and owes a proof only finishes it. The claim
      // would redeliver the bootstrap bundle, and connecting it again would
      // log the live session out for a password that was already rotated.
      await _guarded(_finishPendingProof);
      return;
    }
    final sessionId = record.sessionId;
    if (sessionId == null) {
      // The session can be gone while the payment is not: a connect that
      // failed, or a checkout paid after its session timed out. The claim
      // needs no session, so a device that does not sync yet asks for it;
      // unpaid simply means nothing to resume.
      if (!loggedIn) {
        await _guarded(() => _claimAndConnect(record, quietIfUnpaid: true));
      }
      return;
    }
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
    } on Object {
      state = const SyncSubscribeFailed(SyncSubscribeFailure.service);
    }
  }

  Future<void> _finishPendingProof() async {
    if (!await ref.read(rotationConfirmerProvider).confirmPending()) return;
    final confirmed = await _store.load();
    if (confirmed != null) await _store.save(confirmed.withSession(null));
  }

  /// Runs [work] from a future nobody awaits, turning any escape into a state.
  Future<void> _guarded(Future<void> Function() work) async {
    try {
      await work();
    } on Object {
      state = const SyncSubscribeFailed(SyncSubscribeFailure.service);
    }
  }

  /// Opens the checkout for [plan] in the browser and waits for payment.
  Future<void> subscribe(SyncSubscriptionPlan plan) async {
    _stopPolling();
    state = const SyncSubscribeOpening();
    try {
      final record = await _ensureRecord();
      final SyncCheckoutSession session;
      try {
        session = await _api.createCheckoutSession(
          record.entitlement,
          plan: plan,
          claimSecret: record.claimSecret,
        );
      } on SyncSubscriptionException catch (e) {
        if (e.kind != SyncSubscriptionFailureKind.conflict) rethrow;
        // Already paid for: claim it instead of billing a second time.
        await _claimAndConnect(record);
        return;
      }
      final withSession = record.withSession(session.id);
      await _store.save(withSession);
      bool opened;
      try {
        opened = await ref.read(syncCheckoutLauncherProvider)(
          session.checkoutUrl,
        );
      } on Object {
        // A platform exception from the launcher means the same as `false`.
        opened = false;
      }
      if (!opened) {
        state = const SyncSubscribeFailed(
          SyncSubscribeFailure.browserUnavailable,
        );
        return;
      }
      state = SyncSubscribeAwaitingPayment(session.checkoutUrl);
      _startPolling(withSession);
    } on SyncSubscriptionException catch (e) {
      state = SyncSubscribeFailed(_failureOf(e));
    } on Object {
      // A keystore or other unexpected failure must not leave the sheet on
      // a spinner: the plans come back with an error and a retry.
      state = const SyncSubscribeFailed(SyncSubscribeFailure.service);
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
    // _pollOnce never throws: every failure becomes a state.
    _poll = Timer.periodic(
      syncCheckoutPollInterval,
      (_) => _pollOnce(record),
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
    } on Object {
      // Called from a timer: nothing awaits it, so nothing may escape.
      _stopPolling();
      state = const SyncSubscribeFailed(SyncSubscribeFailure.service);
    } finally {
      _polling = false;
    }
  }

  Future<void> _claimAndConnect(
    SyncSubscriptionRecord record, {
    bool quietIfUnpaid = false,
  }) async {
    // Once provisioning starts the sheet moves to the connect page, which
    // drops this auto-disposed provider's last watcher. The claim, connect and
    // proof must still finish, or the service deactivates the paid account a
    // day later, so the provider is held until they do.
    final link = ref.keepAlive();
    try {
      await _claimAndConnectHeld(record, quietIfUnpaid: quietIfUnpaid);
    } finally {
      link.close();
    }
  }

  Future<void> _claimAndConnectHeld(
    SyncSubscriptionRecord record, {
    required bool quietIfUnpaid,
  }) async {
    state = const SyncSubscribeClaiming();
    final SyncPaidBundle paid;
    try {
      paid = await _api.claim(
        record.entitlement,
        claimSecret: record.claimSecret,
      );
    } on SyncSubscriptionException catch (e) {
      state =
          quietIfUnpaid && e.kind == SyncSubscriptionFailureKind.paymentPending
          ? const SyncSubscribeIdle()
          : SyncSubscribeFailed(_failureOf(e));
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
    // The session stays until the connect succeeds, so a failed one is
    // picked up again by [resume].
    final pending = record.withPendingProof(
      PendingRotationProof(
        bundleId: paid.bundleId,
        roomId: bundle.roomId,
        challenge: challenge,
      ),
    );
    await _store.save(pending);

    state = const SyncSubscribeConnecting();
    await provisioning.configureFromBundle(bundle);
    // A paid bundle is always `provisioned`, so success means `ready`: the
    // password was rotated and a handover minted.
    final connected = ref
        .read(provisioningControllerProvider)
        .maybeWhen(ready: (_) => true, orElse: () => false);
    if (!connected) {
      // The connect page shows why; the bundle stays claimable for a retry.
      return;
    }
    await ref.read(rotationConfirmerProvider).confirmPending();
    final confirmed = await _store.load();
    if (confirmed != null) await _store.save(confirmed.withSession(null));
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

/// Resumes an unfinished checkout once per visit of the subscribe page.
/// Riverpod owns the future, so its lifetime is the page's.
final FutureProvider<void> syncSubscriptionResumeProvider =
    FutureProvider.autoDispose<void>(
      (ref) => ref.read(syncSubscriptionControllerProvider.notifier).resume(),
      name: 'syncSubscriptionResumeProvider',
    );

/// Runs [RotationConfirmer.confirmPending] once per visit of the Devices
/// page; resolves to whether a pending proof was confirmed.
final FutureProvider<bool> pendingRotationRecoveryProvider =
    FutureProvider.autoDispose<bool>((ref) async {
      // Builds without the service never held a paid bundle.
      if (ref.read(syncSubscriptionApiProvider) == null) return false;
      return ref.read(rotationConfirmerProvider).confirmPending();
    }, name: 'pendingRotationRecoveryProvider');

final Provider<RotationConfirmer> rotationConfirmerProvider =
    Provider.autoDispose<RotationConfirmer>(
      (ref) => RotationConfirmer(
        api: ref.watch(syncSubscriptionApiProvider),
        store: ref.watch(syncSubscriptionStoreProvider),
        matrixService: ref.watch(matrixServiceProvider),
      ),
      name: 'rotationConfirmerProvider',
    );
