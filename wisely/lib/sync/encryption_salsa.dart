import 'package:encrypt/encrypt.dart';
import 'package:flutter/foundation.dart' hide Key;

String encryptSalsa(String plainText, b64Secret) {
  final Key key = Key.fromBase64(b64Secret);
  final IV iv = IV.fromSecureRandom(8);
  final String ivBase64 = iv.base64;
  final Encrypter encrypter = Encrypter(Salsa20(key));
  final Encrypted encrypted = encrypter.encrypt(plainText, iv: iv);
  final String encryptedBase64 = encrypted.base64;
  return ('$encryptedBase64.$ivBase64');
}

String decryptSalsa(String message, String b64Secret) {
  List<String> base64Strings = message.split('.');
  String encryptedBase64 = base64Strings[0];
  String ivBase64 = base64Strings[1];
  final Key key = Key.fromBase64(b64Secret);
  final Encrypter encrypter = Encrypter(Salsa20(key));
  return encrypter.decrypt64(encryptedBase64, iv: IV.fromBase64(ivBase64));
}

void encryptDecryptSalsa(String plainText) {
  final now = DateTime.now();
  final String b64Secret = Key.fromSecureRandom(32).base64;
  final String encryptedMessage = encryptSalsa(plainText, b64Secret);
  final String decrypted = decryptSalsa(encryptedMessage, b64Secret);
  debugPrint('Salsa encrypt decrypt: $now ${DateTime.now()}');
  debugPrint('Salsa decrypted: $decrypted');
}
