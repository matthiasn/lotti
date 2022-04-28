part of 'sync_config_cubit.dart';

@freezed
class SyncConfigState with _$SyncConfigState {
  factory SyncConfigState({String? sharedSecret, ImapConfig? imapConfig}) =
      _SyncConfigState;
  factory SyncConfigState.loading() = Loading;
  factory SyncConfigState.generating() = Generating;
  factory SyncConfigState.empty() = Empty;
}
