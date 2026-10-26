/// One interactive (SAS/emoji) device verification, as the UI sees it
/// (ADR 0142): plain values, so the ceremony can be driven from an isolate
/// that holds no Matrix client. The SDK's `KeyVerification` stays with
/// whoever runs the client; the UI acts on it through the sync service's
/// `acceptVerification`, `acceptEmojiVerification` and `cancelVerification`
/// by the ceremony's id.
library;

/// Which side started the ceremony.
enum SyncVerificationDirection {
  /// This device asked the peer to verify.
  outgoing,

  /// The peer asked this device.
  incoming,
}

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

/// One of the emoji both devices compare.
final class SyncVerificationEmoji {
  const SyncVerificationEmoji({required this.emoji, required this.name});

  final String emoji;

  /// The emoji's name in the SDK's list — "Dog", "Cat" — for a screen reader.
  final String name;
}

/// A snapshot of one ceremony. A new snapshot is published on every change;
/// two snapshots with the same [id] describe the same ceremony.
final class SyncVerificationState {
  const SyncVerificationState({
    required this.id,
    required this.direction,
    required this.lastStep,
    required this.outcome,
    this.peerUserId,
    this.peerDeviceId,
    this.emojis,
  });

  /// The ceremony's identity: the SDK transaction id when it has one, else
  /// one the service minted. Stable for the ceremony's life.
  final String id;

  final SyncVerificationDirection direction;

  /// The Matrix user on the other side, when known.
  final String? peerUserId;

  /// The device on the other side, when known.
  final String? peerDeviceId;

  /// The last SDK step seen — `m.key.verification.request`, `...key`,
  /// `...done`, `...cancel` — or the empty string before the first.
  final String lastStep;

  /// The emoji to compare, once the ceremony has reached the key step.
  final List<SyncVerificationEmoji>? emojis;

  final KeyVerificationOutcome outcome;

  /// Whether the ceremony is still live.
  bool get isPending => outcome == KeyVerificationOutcome.pending;

  /// The identity the SDK orders a glare by: `userId|deviceId`.
  String get peerIdentity => '${peerUserId ?? ''}|${peerDeviceId ?? ''}';
}
