import 'package:freezed_annotation/freezed_annotation.dart';

part 'config.freezed.dart';
part 'config.g.dart';

@Freezed(toStringOverride: false)
abstract class MatrixConfig with _$MatrixConfig {
  const factory MatrixConfig({
    required String homeServer,
    required String user,
    required String password,
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

@Freezed(toStringOverride: false)
abstract class SyncProvisioningBundle with _$SyncProvisioningBundle {
  const factory SyncProvisioningBundle({
    required int v,
    required SyncBundleKind kind,
    required String homeServer,
    required String user,
    required String password,
    required String roomId,
  }) = _SyncProvisioningBundle;

  const SyncProvisioningBundle._();

  factory SyncProvisioningBundle.fromJson(Map<String, dynamic> json) =>
      _$SyncProvisioningBundleFromJson(json);

  @override
  String toString() =>
      'SyncProvisioningBundle(v: $v, kind: ${kind.name}, '
      'homeServer: $homeServer, user: $user, password: <redacted>, '
      'roomId: $roomId)';
}
