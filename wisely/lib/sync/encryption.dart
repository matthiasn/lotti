import 'dart:convert';

import 'package:cryptography/cryptography.dart';

Future<void> encryptDecrypt(String messageString) async {
  final List<int> message = utf8.encode(messageString);

  final algorithm = AesGcm.with128bits();
  final secretKey = await algorithm.newSecretKey();
  final nonce = algorithm.newNonce();

  // Encrypt
  final SecretBox secretBox = await algorithm.encrypt(
    message,
    secretKey: secretKey,
    nonce: nonce,
  );

  print('Nonce: ${secretBox.nonce}');
  print('Ciphertext: ${secretBox.cipherText}');
  print('MAC: ${secretBox.mac.bytes}');

  // Decrypt
  final List<int> clearMessage = await algorithm.decrypt(
    secretBox,
    secretKey: secretKey,
  );
  final String clearText = utf8.decode(clearMessage);
  print('Cleartext: $clearText');
}
