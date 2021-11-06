import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

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
