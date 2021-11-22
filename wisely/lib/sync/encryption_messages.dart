import 'package:freezed_annotation/freezed_annotation.dart';

part 'encryption_messages.freezed.dart';

@freezed
class DecryptStringMessage with _$DecryptStringMessage {
  factory DecryptStringMessage({
    required String encrypted,
    required String b64Secret,
  }) = _DecryptStringMessage;
}

@freezed
class EncryptStringMessage with _$EncryptStringMessage {
  factory EncryptStringMessage({
    required String plaintext,
    required String b64Secret,
  }) = _EncryptStringMessage;
}
