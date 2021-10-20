import 'package:freezed_annotation/freezed_annotation.dart';

part 'imap_config.freezed.dart';

@freezed
class ImapConfig with _$ImapConfig {
  factory ImapConfig({
    required String host,
    required String userName,
    required String password,
    required int port,
  }) = _ImapConfig;
}
