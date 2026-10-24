import 'dart:async';

import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:matrix/matrix.dart';

export 'package:lotti/features/sync/models/sync_verification.dart';

/// Classifies a ceremony from the SDK state the runner tracks.
///
/// A free function so that test doubles standing in for a runner can derive
/// the outcome from one definition rather than copying the rules and drifting
/// from them.
///
/// Cancellation is checked first and deliberately wins: a remote cancel sets
/// `canceled` while leaving any earlier state in place, and claiming success
/// for a ceremony that did not verify is the worse failure of the two.
KeyVerificationOutcome keyVerificationOutcome({
  required String lastStep,
  required KeyVerification keyVerification,
}) {
  if (keyVerification.canceled ||
      lastStep == EventTypes.KeyVerificationCancel) {
    return KeyVerificationOutcome.cancelled;
  }
  if (lastStep == EventTypes.KeyVerificationDone ||
      keyVerification.state == KeyVerificationState.done) {
    return KeyVerificationOutcome.success;
  }
  return KeyVerificationOutcome.pending;
}

/// Drives one interactive (SAS/emoji) device-verification session and pushes
/// its evolving state onto [controller] for the verification UI to render.
///
/// Wraps a single SDK [KeyVerification]: it hooks the SDK's `onUpdate`
/// callback and, because that callback is not always fired, also polls every
/// 100 ms for step/`isDone` changes. On each change it republishes itself and,
/// once verification **succeeds**, invokes [onCompleted] exactly once and stops
/// the timer. Restores the SDK's previous `onUpdate` handler when it tears down.
///
/// Read [outcome] rather than the SDK's `isDone`, which is also true for a
/// cancelled or failed ceremony.
///
/// The UI never sees the runner: it reads [toState] snapshots and acts by
/// [id] through the sync service (ADR 0142).
class KeyVerificationRunner {
  KeyVerificationRunner(
    this.keyVerification, {
    required this.controller,
    required this.name,
    required this.direction,
    required this._domainLogger,
    this.onCompleted,
  }) : id = verificationIdOf(keyVerification) {
    lastStep = keyVerification.lastStep ?? '';
    _lastIsDone = keyVerification.isDone;
    _previousOnUpdate = keyVerification.onUpdate;
    keyVerification.onUpdate = _handleSdkUpdate;
    publishState();
    _notifyCompletionIfNeeded();

    _timer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _pollState(),
    );
  }

  /// The ceremony's identity for the UI; see [verificationIdOf].
  final String id;

  final SyncVerificationDirection direction;
  String name;
  String lastStep = '';
  List<KeyVerificationEmoji>? emojis;
  KeyVerification keyVerification;
  StreamController<KeyVerificationRunner> controller;
  final Future<void> Function(String source)? onCompleted;
  final DomainLogger _domainLogger;
  Timer? _timer;
  bool _lastIsDone = false;
  bool _completionNotified = false;
  void Function()? _previousOnUpdate;

  void _handleSdkUpdate() {
    final previousOnUpdate = _previousOnUpdate;
    _pollState();
    previousOnUpdate?.call();
  }

  void _pollState() {
    var changed = false;
    final newLastStep = keyVerification.lastStep ?? '';
    if (newLastStep != lastStep) {
      lastStep = newLastStep;
      changed = true;
      _domainLogger.log(
        LogDomain.sync,
        '$name newLastStep: $newLastStep',
        subDomain: 'KeyVerificationRunner',
      );

      if (lastStep == 'm.key.verification.key') {
        readEmojis();
      }
    }

    final isDone = keyVerification.isDone;
    if (_lastIsDone != isDone) {
      _lastIsDone = isDone;
      changed = true;
    }

    if (changed) {
      publishState();
    }

    _notifyCompletionIfNeeded();

    if (outcome != KeyVerificationOutcome.pending || isDone) {
      stopTimer();
    }
  }

  /// How this ceremony ended. See [keyVerificationOutcome].
  KeyVerificationOutcome get outcome => keyVerificationOutcome(
    lastStep: lastStep,
    keyVerification: keyVerification,
  );

  /// This ceremony as the UI sees it right now.
  SyncVerificationState toState() => SyncVerificationState(
    id: id,
    direction: direction,
    peerUserId: keyVerification.userId,
    peerDeviceId: keyVerification.deviceId,
    lastStep: lastStep,
    emojis: emojis
        ?.map((e) => SyncVerificationEmoji(emoji: e.emoji, name: e.name))
        .toList(),
    outcome: outcome,
  );

  void _notifyCompletionIfNeeded() {
    // Gated on success, not on the SDK's `isDone`: that is true for a cancel
    // too, so every cancelled ceremony used to trigger the completion work
    // (`updateUserDeviceKeys` + `forceRescan`) as if a device had just been
    // verified.
    if (_completionNotified || outcome != KeyVerificationOutcome.success) {
      return;
    }
    _completionNotified = true;
    if (onCompleted != null) {
      unawaited(onCompleted!(name));
    }
  }

  void stopTimer() {
    _timer?.cancel();
    keyVerification.onUpdate = _previousOnUpdate;
    _previousOnUpdate = null;
  }

  Future<void> acceptVerification() async {
    await keyVerification.acceptVerification();
  }

  Future<void> acceptEmojiVerification() async {
    await keyVerification.acceptSas();
  }

  void readEmojis() {
    emojis = keyVerification.sasEmojis;
  }

  /// Publishes this runner's state; after its service closed the stream (a
  /// late SDK callback during dispose) there is no one left to tell.
  void publishState() {
    if (controller.isClosed) return;
    controller.add(this);
  }

  Future<void> cancelVerification() async {
    await keyVerification.cancel();
    stopTimer();
  }
}

/// The identity a ceremony is known by across the UI boundary: the SDK's
/// transaction id, which both devices share, or — for a request the SDK has
/// not numbered yet — one tied to the object's lifetime.
String verificationIdOf(KeyVerification keyVerification) =>
    keyVerification.transactionId ??
    'local-${identityHashCode(keyVerification)}';

/// Subscribes to inbound key-verification requests and wraps each one in a
/// [KeyVerificationRunner] stored on `service.incomingKeyVerificationRunner`,
/// so the UI can present the incoming-verification flow. Returns the
/// subscription (to be cancelled on logout/dispose), or `null` if wiring up the
/// listener fails. Pass [requests] to inject the stream in tests.
Future<StreamSubscription<KeyVerification>?>
listenForKeyVerificationRequestsWithSubscription({
  required MatrixService service,
  required DomainLogger loggingService,
  Stream<KeyVerification>? requests,
}) async {
  try {
    final subscription =
        (requests ?? service.client.onKeyVerificationRequest.stream).listen((
          KeyVerification keyVerification,
        ) {
          service.incomingKeyVerificationRunner = KeyVerificationRunner(
            keyVerification,
            controller: service.incomingKeyVerificationRunnerController,
            name: 'Incoming KeyVerificationRunner',
            direction: SyncVerificationDirection.incoming,
            domainLogger: loggingService,
            onCompleted: (source) =>
                service.onVerificationCompleted(source: source),
          );
          service.rememberIncomingRequest(keyVerification);

          loggingService.log(
            LogDomain.sync,
            'Key Verification Request from ${keyVerification.deviceId}',
            subDomain: 'KeyVerificationRunner',
          );
          service.incomingKeyVerificationController.add(keyVerification);
        });
    return subscription;
  } catch (e, stackTrace) {
    loggingService.error(
      LogDomain.sync,
      e,
      stackTrace: stackTrace,
      subDomain: 'listen',
    );
    return null;
  }
}

/// Starts an outgoing verification of [deviceKeys] and stores its
/// [KeyVerificationRunner] on `service.keyVerificationRunner`; the runner
/// traces its step changes to [loggingService].
Future<void> verifyMatrixDevice({
  required DeviceKeys deviceKeys,
  required MatrixService service,
  required DomainLogger loggingService,
}) async {
  final keyVerification = await deviceKeys.startVerification();
  service.keyVerificationRunner = KeyVerificationRunner(
    keyVerification,
    controller: service.keyVerificationController,
    name: 'Outgoing KeyVerificationRunner',
    direction: SyncVerificationDirection.outgoing,
    domainLogger: loggingService,
    onCompleted: (source) => service.onVerificationCompleted(source: source),
  );
}

/// Cancels the ceremony a dismissed sheet was showing, if it is still live.
///
/// A backdrop tap used to leave the SDK ceremony running: the peer's sheet
/// kept waiting on a device that had walked away, with nothing left to free
/// its lock. Cancelling tells the peer, whose sheet shows the notice and
/// closes (`specs/tla/VerificationLaunch.tla`, `CancelOnDismiss`). A finished
/// ceremony is left alone. A cancel that fails is logged, never thrown: the
/// caller's lock release must still run.
Future<void> cancelAbandonedVerification(
  KeyVerificationRunner? runner, {
  required DomainLogger loggingService,
}) async {
  if (runner == null || runner.outcome != KeyVerificationOutcome.pending) {
    return;
  }
  try {
    await runner.cancelVerification();
  } catch (error, stackTrace) {
    loggingService.error(
      LogDomain.sync,
      error,
      stackTrace: stackTrace,
      subDomain: 'verification.cancelAbandoned',
    );
  }
}
