import 'package:encrypt/encrypt.dart';

Future<void> encryptDecryptSalsa(String plainText) async {
  final now = DateTime.now();
  final Key key = Key.fromSecureRandom(32);
  print('Salsa key: ${key.bytes}');
  print('Salsa key: ${key.base64}');
  final IV iv = IV.fromSecureRandom(8);
  final String ivBase64 = iv.base64;

  final Encrypter encrypter = Encrypter(Salsa20(key));
  final Encrypted encrypted = encrypter.encrypt(plainText, iv: iv);
  final String encryptedBase64 = encrypted.base64;
  print('Salsa Base64: $encryptedBase64.$ivBase64');

  final decrypted =
      encrypter.decrypt64(encryptedBase64, iv: IV.fromBase64(ivBase64));

  print('Salsa decrypted: $decrypted');
  print('Salsa $now ${DateTime.now()}');
}
