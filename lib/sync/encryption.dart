import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:lotti/sync/encryption_messages.dart';

FutureOr<void> encryptFileIsolate(EncryptFileMessage msg) async {
  if (!msg.inputFile.existsSync()) {
    debugPrint('File ${msg.inputFile} does not exist, aborting');
    throw Exception('File not found');
  }

  final List<int> message = await msg.inputFile.readAsBytes();
  final algorithm = AesGcm.with256bits();
  final secretKey =
      await algorithm.newSecretKeyFromBytes(base64Decode(msg.b64Secret));
  final nonce = algorithm.newNonce();

  final secretBox = await algorithm.encrypt(
    message,
    secretKey: secretKey,
    nonce: nonce,
  );

  await msg.encryptedFile.writeAsBytes(secretBox.concatenation());
}

Future<void> encryptFile(
  File inputFile,
  File encryptedFile,
  String b64Secret,
) async {
  if (!inputFile.existsSync()) {
    debugPrint('File $inputFile does not exist, aborting');
    throw Exception('File not found');
  }

  return compute(
    encryptFileIsolate,
    EncryptFileMessage(
      b64Secret: b64Secret,
      inputFile: inputFile,
      encryptedFile: encryptedFile,
    ),
  );
}

FutureOr<void> decryptFileIsolate(DecryptFileMessage msg) async {
  if (!msg.inputFile.existsSync()) {
    debugPrint('File does not exist, aborting');
    throw Exception('File not found');
  }

  final algorithm = AesGcm.with256bits();
  final List<int> bytes = await msg.inputFile.readAsBytes();
  final deserializedSecretBox =
      SecretBox.fromConcatenation(bytes, nonceLength: 12, macLength: 16);
  final secretKey =
      await algorithm.newSecretKeyFromBytes(base64Decode(msg.b64Secret));

  final decryptedBytes = await algorithm.decrypt(
    deserializedSecretBox,
    secretKey: secretKey,
  );

  await msg.decryptedFile.writeAsBytes(decryptedBytes);
}

Future<void> decryptFile(
  File inputFile,
  File decryptedFile,
  String b64Secret,
) async {
  return compute(
    decryptFileIsolate,
    DecryptFileMessage(
      b64Secret: b64Secret,
      inputFile: inputFile,
      decryptedFile: decryptedFile,
    ),
  );
}

Future<String> encryptStringIsolate(EncryptStringMessage msg) async {
  final message = utf8.encode(msg.plaintext);
  final algorithm = AesGcm.with256bits();
  final secretKey =
      await algorithm.newSecretKeyFromBytes(base64Decode(msg.b64Secret));
  final nonce = algorithm.newNonce();

  final secretBox = await algorithm.encrypt(
    message,
    secretKey: secretKey,
    nonce: nonce,
  );
  return base64.encode(secretBox.concatenation());
}

Future<String> encryptString({
  required String plainText,
  required String b64Secret,
}) async {
  return compute(
    encryptStringIsolate,
    EncryptStringMessage(
      b64Secret: b64Secret,
      plaintext: plainText,
    ),
  );
}

FutureOr<String> decryptStringIsolate(DecryptStringMessage msg) async {
  final algorithm = AesGcm.with256bits();
  final List<int> bytes = base64.decode(msg.encrypted);
  final deserializedSecretBox =
      SecretBox.fromConcatenation(bytes, nonceLength: 12, macLength: 16);
  final secretKey =
      await algorithm.newSecretKeyFromBytes(base64Decode(msg.b64Secret));

  final decryptedBytes = await algorithm.decrypt(
    deserializedSecretBox,
    secretKey: secretKey,
  );

  return utf8.decode(decryptedBytes);
}

Future<String> decryptString(String encrypted, String b64Secret) async {
  return compute(
    decryptStringIsolate,
    DecryptStringMessage(
      b64Secret: b64Secret,
      encrypted: encrypted,
    ),
  );
}
