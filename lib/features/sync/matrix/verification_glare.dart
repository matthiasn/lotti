/// Two devices that start the SAS ceremony at each other are two SDK
/// transactions, and the SDK's glare rule only reconciles a `start` inside
/// one of them. Left alone, each device's sheet waits on a request the other
/// never shows, because its own sheet holds the modal lock
/// (`specs/tla/VerificationLaunch.tla`, `AutoVerifies`).
///
/// The rule here is the SDK's, applied one step earlier: while this device's
/// own request is still unanswered, it yields to an incoming request from a
/// **smaller** identity. The order is what makes it terminate — the smallest
/// device in any tangle never yields, so its ceremony is the one that
/// finishes; yielding to any third device instead let three devices withdraw
/// ceremonies from under each other forever.
library;

import 'dart:async';

import 'package:lotti/features/sync/matrix/key_verification_runner.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:matrix/matrix.dart';

/// The identity the SDK orders a glare by: `userId|deviceId`.
String verificationIdentity({
  required String? userId,
  required String? deviceId,
}) => '${userId ?? ''}|${deviceId ?? ''}';

/// Whether the ceremony [runner] drives is still waiting on its request:
/// the peer has neither accepted (`ready`) nor started it.
bool isUnansweredRequest(KeyVerificationRunner runner) =>
    runner.outcome == KeyVerificationOutcome.pending &&
    (runner.lastStep.isEmpty ||
        runner.lastStep == EventTypes.KeyVerificationRequest);

/// Whether this device gives up its own unanswered [outgoing] ceremony to
/// answer [incoming] instead.
bool shouldYieldTo({
  required KeyVerification incoming,
  required KeyVerificationRunner? outgoing,
  required String? ownUserId,
  required String? ownDeviceId,
}) {
  if (outgoing == null || !isUnansweredRequest(outgoing)) return false;
  final theirs = verificationIdentity(
    userId: incoming.userId,
    deviceId: incoming.deviceId,
  );
  final ours = verificationIdentity(userId: ownUserId, deviceId: ownDeviceId);
  return theirs.compareTo(ours) < 0;
}

/// Hands the open outgoing sheet over to [incoming]: cancels the ceremony this
/// device started, wraps the peer's in a runner published on the **outgoing**
/// stream — the one `VerificationModal` renders — and accepts it, so the
/// sheet the user is looking at carries on with the peer's ceremony and the
/// emoji appear in it.
///
/// The old runner is detached before the cancel: a cancel fires the SDK's
/// `onUpdate`, and a still-attached runner would publish the cancelled state
/// and make the modal arm its auto-dismiss mid-ceremony.
Future<KeyVerificationRunner> handOffOutgoingVerification({
  required MatrixService service,
  required KeyVerification incoming,
  required DomainLogger domainLogger,
}) async {
  final outgoing = service.keyVerificationRunner;
  if (outgoing != null) {
    outgoing.stopTimer();
    await outgoing.keyVerification.cancel();
  }
  final runner = KeyVerificationRunner(
    incoming,
    controller: service.keyVerificationController,
    name: 'Outgoing KeyVerificationRunner (handed off)',
    domainLogger: domainLogger,
    onCompleted: (source) => service.onVerificationCompleted(source: source),
  );
  service.keyVerificationRunner = runner;
  await runner.acceptVerification();
  return runner;
}
