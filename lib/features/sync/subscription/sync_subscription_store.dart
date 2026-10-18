import 'dart:convert';

import 'package:lotti/features/sync/subscription/sync_subscription_api.dart';
import 'package:lotti/services/secure_storage.dart';

/// Keystore key of this install's Lotti Sync subscription record.
const String syncSubscriptionKey = 'LOTTI_SYNC_SUBSCRIPTION';

/// A rotation the provisioning service has not yet seen proof of. The
/// service deactivates an account whose bundle is not confirmed within a day,
/// so this is kept until the confirmation succeeds, across restarts.
class PendingRotationProof {
  const PendingRotationProof({
    required this.bundleId,
    required this.roomId,
    required this.challenge,
  });

  factory PendingRotationProof.fromJson(Map<String, dynamic> json) =>
      PendingRotationProof(
        bundleId: json['bundleId'] as String,
        roomId: json['roomId'] as String,
        challenge: json['challenge'] as String,
      );

  final String bundleId;
  final String roomId;
  final String challenge;

  Map<String, Object?> toJson() => {
    'bundleId': bundleId,
    'roomId': roomId,
    'challenge': challenge,
  };
}

/// Everything this install needs to pay for, claim, confirm and manage its
/// subscription. Secrets only — no name, email or payment detail exists here.
class SyncSubscriptionRecord {
  const SyncSubscriptionRecord({
    required this.entitlement,
    required this.claimSecret,
    this.sessionId,
    this.pendingProof,
  });

  factory SyncSubscriptionRecord.fromJson(Map<String, dynamic> json) {
    final proof = json['pendingProof'];
    return SyncSubscriptionRecord(
      entitlement: SyncEntitlement(
        id: json['entitlementId'] as String,
        authSecret: json['authSecret'] as String,
      ),
      claimSecret: json['claimSecret'] as String,
      sessionId: json['sessionId'] as String?,
      pendingProof: proof is Map<String, dynamic>
          ? PendingRotationProof.fromJson(proof)
          : null,
    );
  }

  final SyncEntitlement entitlement;
  final String claimSecret;

  /// The last checkout session, so a restart can keep waiting on it.
  final String? sessionId;
  final PendingRotationProof? pendingProof;

  SyncSubscriptionRecord withSession(String? sessionId) =>
      SyncSubscriptionRecord(
        entitlement: entitlement,
        claimSecret: claimSecret,
        sessionId: sessionId,
        pendingProof: pendingProof,
      );

  SyncSubscriptionRecord withPendingProof(PendingRotationProof? proof) =>
      SyncSubscriptionRecord(
        entitlement: entitlement,
        claimSecret: claimSecret,
        sessionId: sessionId,
        pendingProof: proof,
      );

  Map<String, Object?> toJson() => {
    'entitlementId': entitlement.id,
    'authSecret': entitlement.authSecret,
    'claimSecret': claimSecret,
    if (sessionId != null) 'sessionId': sessionId,
    if (pendingProof != null) 'pendingProof': pendingProof!.toJson(),
  };
}

/// Reads and writes the [SyncSubscriptionRecord] in the OS keystore.
class SyncSubscriptionStore {
  const SyncSubscriptionStore(this._storage);

  final SecureStorage _storage;

  Future<SyncSubscriptionRecord?> load() async {
    final raw = await _storage.read(key: syncSubscriptionKey);
    if (raw == null) return null;
    try {
      return SyncSubscriptionRecord.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } on Object {
      // A record this build cannot read is treated as absent rather than
      // blocking the subscribe screen; a new entitlement can still be made.
      return null;
    }
  }

  Future<void> save(SyncSubscriptionRecord record) =>
      _storage.write(key: syncSubscriptionKey, value: jsonEncode(record));
}
