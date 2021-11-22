import 'dart:io';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'encryption_messages.freezed.dart';

@freezed
class EncryptStringMessage with _$EncryptStringMessage {
  factory EncryptStringMessage({
    required String plaintext,
    required String b64Secret,
  }) = _EncryptStringMessage;
}

@freezed
class DecryptStringMessage with _$DecryptStringMessage {
  factory DecryptStringMessage({
    required String encrypted,
    required String b64Secret,
  }) = _DecryptStringMessage;
}

@freezed
class EncryptFileMessage with _$EncryptFileMessage {
  factory EncryptFileMessage({
    required String b64Secret,
    required File inputFile,
    required File encryptedFile,
  }) = _EncryptFileMessage;
}

@freezed
class DecryptFileMessage with _$DecryptFileMessage {
  factory DecryptFileMessage({
    required String b64Secret,
    required File inputFile,
    required File decryptedFile,
  }) = _DecryptFileMessage;
}
