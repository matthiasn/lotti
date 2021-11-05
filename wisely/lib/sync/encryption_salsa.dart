import 'package:encrypt/encrypt.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

String encryptSalsa(String plainText, b64Secret) {
  final transaction = Sentry.startTransaction('encryptSalsa()', 'task');
  final Key key = Key.fromBase64(b64Secret);
  final IV iv = IV.fromSecureRandom(8);
  final String ivBase64 = iv.base64;
  final Encrypter encrypter = Encrypter(Salsa20(key));
  final Encrypted encrypted = encrypter.encrypt(plainText, iv: iv);
  final String encryptedBase64 = encrypted.base64;
  transaction.finish();
  return ('$encryptedBase64.$ivBase64');
}

String decryptSalsa(String message, String b64Secret) {
  final transaction = Sentry.startTransaction('decryptSalsa()', 'task');
  List<String> base64Strings = message.split('.');
  String encryptedBase64 = base64Strings[0];
  String ivBase64 = base64Strings[1];
  final Key key = Key.fromBase64(b64Secret);
  final Encrypter encrypter = Encrypter(Salsa20(key));
  String decrypted = encrypter.decrypt64(
    encryptedBase64,
    iv: IV.fromBase64(ivBase64),
  );
  transaction.finish();
  return decrypted;
}
