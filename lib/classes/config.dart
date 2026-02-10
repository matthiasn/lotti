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

@freezed
abstract class SyncProvisioningBundle with _$SyncProvisioningBundle {
  const factory SyncProvisioningBundle({
    required int v,
    required String homeServer,
    required String user,
    required String password,
    required String roomId,
  }) = _SyncProvisioningBundle;

  factory SyncProvisioningBundle.fromJson(Map<String, dynamic> json) =>
      _$SyncProvisioningBundleFromJson(json);
}
