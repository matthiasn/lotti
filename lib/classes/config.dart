import 'package:freezed_annotation/freezed_annotation.dart';

part 'config.freezed.dart';
part 'config.g.dart';

@Freezed(toStringOverride: false)
abstract class MatrixConfig with _$MatrixConfig {
  const factory MatrixConfig({
    required String homeServer,
    required String user,
    required String password,

    /// The operator's signature over this account's identity, kept from the
    /// bundle that provisioned it so every handover this device issues
    /// carries it on. Null for self-hosted and hand-typed accounts.
    @JsonKey(includeIfNull: false) BundleAttestation? attestation,
  }) = _MatrixConfig;

  factory MatrixConfig.fromJson(Map<String, dynamic> json) =>
      _$MatrixConfigFromJson(json);
}

/// Which role this bundle plays in the provisioning flow. Tells the
/// consuming client whether to rotate the password (fresh bundle from the
/// CLI) or join as-is (bundle from an already-configured peer device).
enum SyncBundleKind {
  /// Emitted by the `matrix_provisioner` CLI. The embedded password is the
  /// initial random password and MUST be rotated on first consumption —
  /// otherwise a stale copy of the bundle retains access to the account.
  provisioned,

  /// Emitted by an already-configured device handing off to another device.
  /// The password has already been rotated and is the current live credential
  /// shared by every peer in the room; the consumer joins without rotating.
  handover,
}

/// The provisioning service's Ed25519 signature over a bundle's identity
/// (`homeServer`, `user`, `roomId`), present from schema v3.
///
/// The password is deliberately not signed: a device that rotated it hands
/// the same attestation on, and the next device can still verify it.
/// `iat`/`exp` are Unix seconds; `sig` is unpadded Base64url.
@freezed
abstract class BundleAttestation with _$BundleAttestation {
  const factory BundleAttestation({
    required String kid,
    required int iat,
    required int exp,
    required String sig,
  }) = _BundleAttestation;

  factory BundleAttestation.fromJson(Map<String, dynamic> json) =>
      _$BundleAttestationFromJson(json);
}

@Freezed(toStringOverride: false)
abstract class SyncProvisioningBundle with _$SyncProvisioningBundle {
  const factory SyncProvisioningBundle({
    required int v,
    required SyncBundleKind kind,
    required String homeServer,
    required String user,
    required String password,
    required String roomId,
    @JsonKey(includeIfNull: false) BundleAttestation? att,
  }) = _SyncProvisioningBundle;

  const SyncProvisioningBundle._();

  factory SyncProvisioningBundle.fromJson(Map<String, dynamic> json) =>
      _$SyncProvisioningBundleFromJson(json);

  @override
  String toString() =>
      'SyncProvisioningBundle(v: $v, kind: ${kind.name}, '
      'homeServer: $homeServer, user: $user, password: <redacted>, '
      'roomId: $roomId, signed: ${att != null})';
}
