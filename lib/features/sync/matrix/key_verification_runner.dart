import 'dart:async';

import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:matrix/matrix.dart';

/// How a verification ceremony ended, as far as this device is concerned.
///
/// The SDK's `KeyVerification.isDone` cannot answer this: it is
/// `canceled || state in {error, done}`, so it reports true for a ceremony
/// that was cancelled or failed just as loudly as for one that succeeded.
enum KeyVerificationOutcome {
  /// Still running, or not started.
  pending,

  /// The devices verified each other.
  success,

  /// Ended without verifying — either side cancelled, or the SDK failed the
  /// ceremony. Every SDK path that sets `KeyVerificationState.error` also sets
  /// `canceled`, so failure is not separable from cancellation here (matrix
  /// 8.1.0, `encryption/utils/key_verification.dart`).
  cancelled,
}

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
class KeyVerificationRunner {
  KeyVerificationRunner(
    this.keyVerification, {
    required this.controller,
    required this.name,
    this.onCompleted,
  }) {
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

  String name;
  String lastStep = '';
  List<KeyVerificationEmoji>? emojis;
  KeyVerification keyVerification;
  StreamController<KeyVerificationRunner> controller;
  final Future<void> Function(String source)? onCompleted;
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
      DevLogger.log(
        name: 'KeyVerificationRunner',
        message: '$name newLastStep: $newLastStep',
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

  void publishState() {
    controller.add(this);
  }

  Future<void> cancelVerification() async {
    await keyVerification.cancel();
    stopTimer();
  }
}

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
            onCompleted: (source) =>
                service.onVerificationCompleted(source: source),
          );

          DevLogger.log(
            name: 'KeyVerificationRunner',
            message:
                'Key Verification Request from ${keyVerification.deviceId}',
          );
          service.incomingKeyVerificationController.add(keyVerification);
        });
    return subscription;
  } catch (e, stackTrace) {
    DevLogger.error(
      name: 'KeyVerificationRunner',
      message: 'Error listening for key verification requests',
      error: e,
      stackTrace: stackTrace,
    );
    loggingService.error(
      LogDomain.sync,
      e,
      stackTrace: stackTrace,
      subDomain: 'listen',
    );
    return null;
  }
}

Future<void> verifyMatrixDevice({
  required DeviceKeys deviceKeys,
  required MatrixService service,
}) async {
  final keyVerification = await deviceKeys.startVerification();
  service.keyVerificationRunner = KeyVerificationRunner(
    keyVerification,
    controller: service.keyVerificationController,
    name: 'Outgoing KeyVerificationRunner',
    onCompleted: (source) => service.onVerificationCompleted(source: source),
  );
}
