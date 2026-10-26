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

import 'package:lotti/features/sync/models/sync_verification.dart';
import 'package:lotti/features/sync/sync_service.dart';
import 'package:matrix/matrix.dart' show EventTypes;

/// The identity the SDK orders a glare by: `userId|deviceId`.
String verificationIdentity({
  required String? userId,
  required String? deviceId,
}) => '${userId ?? ''}|${deviceId ?? ''}';

/// Whether the ceremony [state] describes is still waiting on its request:
/// the peer has neither accepted (`ready`) nor started it.
bool isUnansweredRequest(SyncVerificationState state) =>
    state.isPending &&
    (state.lastStep.isEmpty ||
        state.lastStep == EventTypes.KeyVerificationRequest);

/// Whether this device gives up its own unanswered [outgoing] ceremony to
/// answer [incoming] instead.
bool shouldYieldTo({
  required SyncVerificationState incoming,
  required SyncVerificationState? outgoing,
  required String? ownUserId,
  required String? ownDeviceId,
}) {
  if (outgoing == null || !isUnansweredRequest(outgoing)) return false;
  final ours = verificationIdentity(userId: ownUserId, deviceId: ownDeviceId);
  return incoming.peerIdentity.compareTo(ours) < 0;
}

/// Calls [reoffer] once for each outgoing ceremony [service] starts.
///
/// The service stores the outgoing ceremony only after the request has been
/// sent, so a peer's request that lands while the send is in flight finds no
/// outgoing ceremony and [shouldYieldTo] says no: the device holds it back.
/// When both devices do that, neither ceremony moves
/// (`specs/tla/VerificationLaunch.tla`, `ReofferOnRegister`). Offering the
/// held-back request again once the ceremony exists lets the device that
/// should yield do so.
StreamSubscription<SyncVerificationState> reofferOnOwnVerification(
  SyncService service,
  void Function() reoffer,
) {
  String? last;
  return service.outgoingVerifications.listen((state) {
    if (state.id == last || state.id != service.outgoingVerification?.id) {
      return;
    }
    last = state.id;
    reoffer();
  });
}
