import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';

Future<void> encryptFile(
  File inputFile,
  File encryptedFile,
  String b64Secret,
) async {
  if (!inputFile.existsSync()) {
    debugPrint('File $inputFile does not exist, aborting');
    throw Exception('File not found');
  }

  final List<int> message = await inputFile.readAsBytes();
  final algorithm = AesGcm.with256bits();

  final secretKey =
      await algorithm.newSecretKeyFromBytes(base64Decode(b64Secret));
  final nonce = algorithm.newNonce();

  final secretBox = await algorithm.encrypt(
    message,
    secretKey: secretKey,
    nonce: nonce,
  );

  await encryptedFile.writeAsBytes(secretBox.concatenation());
}

Future<void> decryptFile(
  File inputFile,
  File decryptedFile,
  String b64Secret,
) async {
  if (!inputFile.existsSync()) {
    debugPrint('File does not exist, aborting');
    throw Exception('File not found');
  }

  final algorithm = AesGcm.with256bits();
  final List<int> bytes = await inputFile.readAsBytes();
  final deserializedSecretBox =
      SecretBox.fromConcatenation(bytes, nonceLength: 12, macLength: 16);
  final secretKey =
      await algorithm.newSecretKeyFromBytes(base64Decode(b64Secret));

  final decryptedBytes = await algorithm.decrypt(
    deserializedSecretBox,
    secretKey: secretKey,
  );

  await decryptedFile.writeAsBytes(decryptedBytes);
}

final algorithm = AesGcm.with256bits();

Future<String> encryptString({
  required String plainText,
  required String b64Secret,
}) async {
  final message = utf8.encode(plainText);
  final secretKey = await algorithm.newSecretKeyFromBytes(
    base64Decode(b64Secret),
  );
  final nonce = algorithm.newNonce();

  final secretBox = await algorithm.encrypt(
    message,
    secretKey: secretKey,
    nonce: nonce,
  );
  return base64.encode(secretBox.concatenation());
}

Future<String> decryptString({
  required String encrypted,
  required String b64Secret,
}) async {
  final List<int> bytes = base64.decode(encrypted);
  final deserializedSecretBox =
      SecretBox.fromConcatenation(bytes, nonceLength: 12, macLength: 16);
  final secretKey =
      await algorithm.newSecretKeyFromBytes(base64Decode(b64Secret));

  final decryptedBytes = await algorithm.decrypt(
    deserializedSecretBox,
    secretKey: secretKey,
  );

  return utf8.decode(decryptedBytes);
}

String generateKeyFromPassphrase(String passphrase) {
  final key = encrypt.Key.fromUtf8(passphrase);
  return key.base64;
}
