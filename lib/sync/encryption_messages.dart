import 'dart:io';

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
class DecryptFileMessage with _$DecryptFileMessage {
  factory DecryptFileMessage({
    required String b64Secret,
    required File inputFile,
    required File decryptedFile,
  }) = _DecryptFileMessage;
}
