import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

Future<void> encryptDecrypt(String messageString) async {
  final List<int> message = utf8.encode(messageString);

  final algorithm = AesGcm.with256bits();
  final secretKey = await algorithm.newSecretKey();
  final nonce = algorithm.newNonce();

  // Encrypt
  final SecretBox secretBox = await algorithm.encrypt(
    message,
    secretKey: secretKey,
    nonce: nonce,
  );

  final Uint8List bytes = secretBox.concatenation();
  final String b64String = base64.encode(bytes);

  print('Nonce: ${secretBox.nonce}');
  print('Nonce length: ${secretBox.nonce.length}');
  print('Ciphertext: ${secretBox.cipherText}');
  print('Base64 encoded: ${b64String}');
  print('MAC: ${secretBox.mac.bytes}');

  final deserializedSecretBox =
      SecretBox.fromConcatenation(bytes, nonceLength: 12, macLength: 16);

  // Decrypt
  final List<int> clearMessage = await algorithm.decrypt(
    deserializedSecretBox,
    secretKey: secretKey,
  );
  final String clearText = utf8.decode(clearMessage);
  print('Cleartext: $clearText');
}

Future<void> encryptFile(
    File inputFile, File encryptedFile, String b64Secret) async {
  if (!inputFile.existsSync()) {
    print('File does not exist, aborting');
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

  final Uint8List bytes = secretBox.concatenation();
  await encryptedFile.writeAsBytes(bytes);
}

Future<void> decryptFile(
    File inputFile, File outputFile, String b64Secret) async {
  if (!inputFile.existsSync()) {
    print('File does not exist, aborting');
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
}
