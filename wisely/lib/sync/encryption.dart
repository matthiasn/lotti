import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:wisely/sync/encryption_messages.dart';

Future<void> encryptFile(
    File inputFile, File encryptedFile, String b64Secret) async {
  final transaction = Sentry.startTransaction('encryptFile()', 'task');

  if (!inputFile.existsSync()) {
    debugPrint('File does not exist, aborting');
    throw Exception("File not found");
  }

  final List<int> message = await inputFile.readAsBytes();
  final algorithm = AesGcm.with256bits();
  final secretKey =
      await algorithm.newSecretKeyFromBytes(base64Decode(b64Secret));
  final nonce = algorithm.newNonce();

  final SecretBox secretBox = await algorithm.encrypt(
    message,
    secretKey: secretKey,
    nonce: nonce,
  );

  await encryptedFile.writeAsBytes(secretBox.concatenation());
  await transaction.finish();
}

Future<void> decryptFile(
    File inputFile, File outputFile, String b64Secret) async {
  final transaction = Sentry.startTransaction('decryptFile()', 'task');

  if (!inputFile.existsSync()) {
    debugPrint('File does not exist, aborting');
    throw Exception("File not found");
  }

  final algorithm = AesGcm.with256bits();
  final List<int> bytes = await inputFile.readAsBytes();
  final deserializedSecretBox =
      SecretBox.fromConcatenation(bytes, nonceLength: 12, macLength: 16);
  final secretKey =
      await algorithm.newSecretKeyFromBytes(base64Decode(b64Secret));

  final List<int> decryptedBytes = await algorithm.decrypt(
    deserializedSecretBox,
    secretKey: secretKey,
  );

  await outputFile.writeAsBytes(decryptedBytes);
  await transaction.finish();
}

Future<String> encryptStringIsolate(
    EncryptStringMessage encryptStringMessage) async {
  final transaction = Sentry.startTransaction('encryptString()', 'task');
  final List<int> message = utf8.encode(encryptStringMessage.plaintext);
  final algorithm = AesGcm.with256bits();
  final secretKey = await algorithm
      .newSecretKeyFromBytes(base64Decode(encryptStringMessage.b64Secret));
  final nonce = algorithm.newNonce();

  final SecretBox secretBox = await algorithm.encrypt(
    message,
    secretKey: secretKey,
    nonce: nonce,
  );
  transaction.finish();
  return base64.encode(secretBox.concatenation());
}

Future<String> encryptString(String plainText, b64Secret) async {
  return compute(
    encryptStringIsolate,
    EncryptStringMessage(
      b64Secret: b64Secret,
      plaintext: plainText,
    ),
  );
}

FutureOr<String> decryptStringIsolate(
    DecryptStringMessage decryptStringMessage) async {
  final transaction = Sentry.startTransaction('decryptString()', 'task');

  final algorithm = AesGcm.with256bits();
  final List<int> bytes = base64.decode(decryptStringMessage.encrypted);
  final deserializedSecretBox =
      SecretBox.fromConcatenation(bytes, nonceLength: 12, macLength: 16);
  final secretKey = await algorithm
      .newSecretKeyFromBytes(base64Decode(decryptStringMessage.b64Secret));

  final List<int> decryptedBytes = await algorithm.decrypt(
    deserializedSecretBox,
    secretKey: secretKey,
  );

  String decrypted = utf8.decode(decryptedBytes);
  transaction.finish();
  return decrypted;
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
