import 'package:lotti/features/sync/models/sync_device_info.dart';
import 'package:lotti/features/sync/models/sync_verification.dart';
import 'package:matrix/matrix.dart' show EventTypes;

/// Plain-value fixtures for the verification surfaces (ADR 0142): the UI
/// never sees a runner or SDK `KeyVerification`, so its tests feed
/// [SyncVerificationState] snapshots and [SyncDeviceInfo] rows instead.

/// Eight identical emoji with distinct names, the shape the SAS row renders.
List<SyncVerificationEmoji> sasEmojis([String emoji = '😀']) => List.generate(
  8,
  (index) => SyncVerificationEmoji(emoji: emoji, name: 'emoji$index'),
);

/// One ceremony snapshot. Defaults to a pending outgoing ceremony with
/// `@alice:example.com/DEVICE1` on the other side that has not sent a step.
SyncVerificationState verificationState({
  String id = 'ceremony-1',
  SyncVerificationDirection direction = SyncVerificationDirection.outgoing,
  String? peerUserId = '@alice:example.com',
  String? peerDeviceId = 'DEVICE1',
  String lastStep = '',
  List<SyncVerificationEmoji>? emojis,
  KeyVerificationOutcome outcome = KeyVerificationOutcome.pending,
}) => SyncVerificationState(
  id: id,
  direction: direction,
  peerUserId: peerUserId,
  peerDeviceId: peerDeviceId,
  lastStep: lastStep,
  emojis: emojis,
  outcome: outcome,
);

/// The ceremony at the emoji step, with [emojis] to compare.
SyncVerificationState emojiStep({
  String id = 'ceremony-1',
  SyncVerificationDirection direction = SyncVerificationDirection.outgoing,
  String? peerUserId = '@alice:example.com',
  String? peerDeviceId = 'DEVICE1',
  List<SyncVerificationEmoji>? emojis,
}) => verificationState(
  id: id,
  direction: direction,
  peerUserId: peerUserId,
  peerDeviceId: peerDeviceId,
  lastStep: 'm.key.verification.key',
  emojis: emojis ?? sasEmojis(),
);

/// A ceremony that verified both devices.
SyncVerificationState doneStep({
  String id = 'ceremony-1',
  SyncVerificationDirection direction = SyncVerificationDirection.outgoing,
  String? peerUserId = '@alice:example.com',
  String? peerDeviceId = 'DEVICE1',
}) => verificationState(
  id: id,
  direction: direction,
  peerUserId: peerUserId,
  peerDeviceId: peerDeviceId,
  lastStep: EventTypes.KeyVerificationDone,
  outcome: KeyVerificationOutcome.success,
);

/// A ceremony the other side (or the SDK) ended without verifying.
SyncVerificationState cancelledStep({
  String id = 'ceremony-1',
  SyncVerificationDirection direction = SyncVerificationDirection.outgoing,
  String? peerUserId = '@alice:example.com',
  String? peerDeviceId = 'DEVICE1',
}) => verificationState(
  id: id,
  direction: direction,
  peerUserId: peerUserId,
  peerDeviceId: peerDeviceId,
  lastStep: EventTypes.KeyVerificationCancel,
  outcome: KeyVerificationOutcome.cancelled,
);

/// Another session on the account that has published keys and is not yet
/// verified: the device every ceremony surface is opened for.
SyncDeviceInfo unverifiedPeerDevice({
  String deviceId = 'DEVICE1',
  String? displayName = 'Pixel 7',
  String? userId = '@alice:example.com',
  bool hasKeys = true,
  DateTime? lastSeen,
  bool onServer = true,
  bool ownAccount = true,
}) => SyncDeviceInfo(
  deviceId: deviceId,
  displayName: displayName,
  userId: userId,
  lastSeen: lastSeen,
  isCurrentDevice: false,
  verified: false,
  hasKeys: hasKeys,
  onServer: onServer,
  ownAccount: ownAccount,
);
