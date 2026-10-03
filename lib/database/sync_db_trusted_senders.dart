part of 'sync_db.dart';

/// Persistence for [TrustedSyncSenders]: the sender devices this device has
/// trusted for inbound sync. The trust decision itself lives in
/// `SyncEventTrust`.
mixin _SyncDbTrustedSenders on _$SyncDatabase {
  /// Whether the device with [curve25519Key] of [userId] was trusted when this
  /// device last saw it listed.
  Future<bool> isTrustedSyncSender({
    required String userId,
    required String curve25519Key,
  }) async {
    final row =
        await (select(trustedSyncSenders)..where(
              (t) =>
                  t.userId.equals(userId) &
                  t.curve25519Key.equals(curve25519Key),
            ))
            .getSingleOrNull();
    return row != null;
  }

  /// Records a sender device found trusted. Keeps the first sighting.
  Future<void> rememberTrustedSyncSender({
    required String userId,
    required String curve25519Key,
    required String deviceId,
  }) => into(trustedSyncSenders).insert(
    TrustedSyncSendersCompanion.insert(
      userId: userId,
      curve25519Key: curve25519Key,
      deviceId: deviceId,
      trustedAt: clock.now(),
    ),
    mode: InsertMode.insertOrIgnore,
  );

  /// Removes a sender device that is listed but no longer trusted, so a later
  /// logout cannot restore trust through this record.
  Future<void> forgetTrustedSyncSender({
    required String userId,
    required String curve25519Key,
  }) =>
      (delete(trustedSyncSenders)..where(
            (t) =>
                t.userId.equals(userId) & t.curve25519Key.equals(curve25519Key),
          ))
          .go();
}
