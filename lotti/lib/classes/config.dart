import 'package:freezed_annotation/freezed_annotation.dart';

part 'config.freezed.dart';
part 'config.g.dart';

@freezed
class ImapConfig with _$ImapConfig {
  factory ImapConfig({
    required String host,
    required String folder,
    required String userName,
    required String password,
    required int port,
  }) = _ImapConfig;

  factory ImapConfig.fromJson(Map<String, dynamic> json) =>
      _$ImapConfigFromJson(json);
}

@freezed
class SyncConfig with _$SyncConfig {
  factory SyncConfig({
    required ImapConfig imapConfig,
    required String sharedSecret,
  }) = _SyncConfig;

  factory SyncConfig.fromJson(Map<String, dynamic> json) =>
      _$SyncConfigFromJson(json);
}
