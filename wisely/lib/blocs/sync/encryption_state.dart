part of 'encryption_cubit.dart';

@freezed
class EncryptionState with _$EncryptionState {
  factory EncryptionState({String? sharedKey, ImapConfig? imapConfig}) =
      _EncryptionState;
  factory EncryptionState.loading() = Loading;
  factory EncryptionState.generating() = Generating;
  factory EncryptionState.empty() = Empty;
}
