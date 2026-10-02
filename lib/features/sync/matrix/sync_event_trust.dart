import 'package:collection/collection.dart';
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:matrix/matrix.dart';

/// Why [SyncEventTrust] accepted or rejected an inbound event.
enum SyncEventTrustVerdict {
  /// Decrypted from a Megolm session created by a device this device shares
  /// its own keys with.
  trusted,

  /// Arrived in plaintext, or is still ciphertext. The sync room is always
  /// encrypted, so no Lotti device sends a plaintext event into it.
  notEncrypted,

  /// The Megolm session that decrypted the event is no longer known.
  unknownSession,

  /// The session key was forwarded by another device, so its creator is only
  /// claimed. Lotti never requests or forwards room keys.
  forwardedSession,

  /// The session's device does not belong to the event's sender, or its
  /// claimed signing key differs from the listed device's.
  senderMismatch,

  /// The session's device is listed but is not one this device shares its
  /// keys with — unverified or blocked.
  untrustedDevice,

  /// The session's device is not listed and was never trusted here.
  unknownDevice,
}

/// Decides whether a decrypted inbound sync event may enter the pipeline.
///
/// The Matrix SDK decrypts any Megolm event whose session key reached this
/// device and never checks the sending device, and it delivers plaintext
/// events in an encrypted room unchanged. Anyone able to post into the sync
/// room — the account holder or the homeserver's operator — could otherwise
/// inject sync payloads. Inbound acceptance therefore mirrors outbound key
/// sharing: an event is trusted only when it was encrypted by a session whose
/// creator is a device this device would encrypt to
/// (`DeviceKeys.encryptToDevice` under the client's `shareKeysWith` policy).
///
/// The sending device is identified by the Curve25519 key the session was
/// received under, never by the event's own unauthenticated `sender_key` or
/// `device_id` fields. Trusted devices are remembered in [SyncDatabase] so a
/// device that has since logged out — and that the SDK therefore no longer
/// lists — still counts for the history it sent while it was trusted.
class SyncEventTrust {
  SyncEventTrust({
    required this._syncDb,
    required this._logging,
  });

  final SyncDatabase _syncDb;
  final DomainLogger _logging;

  /// Senders already remembered by this process, so repeated events from the
  /// same device do not rewrite the ledger.
  final Set<String> _remembered = <String>{};

  /// Classifies [event]. Only [SyncEventTrustVerdict.trusted] may be applied.
  Future<SyncEventTrustVerdict> evaluate(Event event) async {
    final source = event.originalSource;
    if (event.type == EventTypes.Encrypted ||
        source == null ||
        source.type != EventTypes.Encrypted) {
      return SyncEventTrustVerdict.notEncrypted;
    }
    final RoomEncryptedContent content;
    try {
      content = source.parsedRoomEncryptedContent;
    } on Object {
      return SyncEventTrustVerdict.notEncrypted;
    }
    final sessionId = content.sessionId;
    if (content.algorithm != AlgorithmTypes.megolmV1AesSha2 ||
        sessionId == null) {
      return SyncEventTrustVerdict.notEncrypted;
    }

    final client = event.room.client;
    final encryption = client.encryption;
    if (encryption == null) return SyncEventTrustVerdict.unknownSession;
    final keyManager = encryption.keyManager;
    final roomId = event.room.id;
    final session =
        keyManager.getInboundGroupSession(roomId, sessionId) ??
        await keyManager.loadInboundGroupSession(roomId, sessionId);
    if (session == null || !session.isValid || session.roomId != roomId) {
      return SyncEventTrustVerdict.unknownSession;
    }
    if (session.forwardingCurve25519KeyChain.isNotEmpty) {
      return SyncEventTrustVerdict.forwardedSession;
    }

    final senderKey = session.senderKey;
    final senderId = event.senderId;
    // This device's own sessions: the server echo of what it sent.
    if (senderKey == encryption.identityKey) {
      return senderId == client.userID
          ? SyncEventTrustVerdict.trusted
          : SyncEventTrustVerdict.senderMismatch;
    }

    final device = client.userDeviceKeys[senderId]?.deviceKeys.values
        .firstWhereOrNull((device) => device.curve25519Key == senderKey);
    if (device == null) {
      final remembered = await _syncDb.isTrustedSyncSender(
        userId: senderId,
        curve25519Key: senderKey,
      );
      return remembered
          ? SyncEventTrustVerdict.trusted
          : SyncEventTrustVerdict.unknownDevice;
    }

    final claimedSigningKey = session.senderClaimedKeys['ed25519'];
    if (claimedSigningKey != null && claimedSigningKey != device.ed25519Key) {
      return SyncEventTrustVerdict.senderMismatch;
    }
    final ledgerKey = '$senderId|$senderKey';
    if (!device.encryptToDevice) {
      _remembered.remove(ledgerKey);
      await _syncDb.forgetTrustedSyncSender(
        userId: senderId,
        curve25519Key: senderKey,
      );
      return SyncEventTrustVerdict.untrustedDevice;
    }
    if (_remembered.add(ledgerKey)) {
      await _syncDb.rememberTrustedSyncSender(
        userId: senderId,
        curve25519Key: senderKey,
        deviceId: device.deviceId ?? '',
      );
    }
    return SyncEventTrustVerdict.trusted;
  }

  /// Whether [event] may be applied. Logs every rejection with its reason.
  Future<bool> admits(Event event, {required String subDomain}) async {
    final verdict = await evaluate(event);
    if (verdict == SyncEventTrustVerdict.trusted) return true;
    _logging.log(
      LogDomain.sync,
      'sync.trust.rejected eventId=${event.eventId} verdict=${verdict.name}',
      subDomain: subDomain,
      level: InsightLevel.warn,
    );
    return false;
  }
}
