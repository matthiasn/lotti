part of 'sync_config_cubit.dart';

@freezed
class SyncConfigState with _$SyncConfigState {
  factory SyncConfigState.configured({
    required ImapConfig imapConfig,
    required String sharedSecret,
  }) = _Configured;

  factory SyncConfigState.imapSaved({
    required ImapConfig imapConfig,
  }) = _ImapSaved;

  factory SyncConfigState.imapValid({
    required ImapConfig imapConfig,
  }) = _ImapValid;

  factory SyncConfigState.imapTesting({
    required ImapConfig imapConfig,
  }) = _ImapTesting;

  factory SyncConfigState.imapInvalid({
    required ImapConfig imapConfig,
    required String errorMessage,
  }) = _ImapInvalid;

  factory SyncConfigState({
    String? sharedSecret,
    ImapConfig? imapConfig,
  }) = _SyncConfigState;

  factory SyncConfigState.loading() = _Loading;

  factory SyncConfigState.generating() = _Generating;

  factory SyncConfigState.empty() = _Empty;
}
