import 'dart:convert';
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
