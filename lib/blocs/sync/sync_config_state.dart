part of 'sync_config_cubit.dart';

@freezed
class SyncConfigState with _$SyncConfigState {
  factory SyncConfigState.configured({
    required String sharedSecret,
    required ImapConfig imapConfig,
  }) = _Configured;

  factory SyncConfigState.imapValid({
    required ImapConfig imapConfig,
  }) = _ImapValid;

  factory SyncConfigState.imapTesting({
    ImapConfig? imapConfig,
  }) = _ImapTesting;

  factory SyncConfigState.imapInvalid({
    required ImapConfig imapConfig,
    String? errorMessage,
  }) = _ImapInvalid;

  factory SyncConfigState({
    String? sharedSecret,
    ImapConfig? imapConfig,
  }) = _SyncConfigState;

  factory SyncConfigState.loading() = _Loading;

  factory SyncConfigState.generating() = _Generating;

  factory SyncConfigState.empty() = _Empty;
}
