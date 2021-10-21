import 'dart:io';

import 'package:encrypt/encrypt.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:wisely/sync/encryption.dart';

Function eq = const ListEquality().equals;

void main() {
  test('File encryption', () async {
    final originalFile = File('test_resources/test.aac');
    final encryptedFile = File('test_resources/test.aac.aes');
    final decryptedFile = File('test_resources/test_decrypted.aac');
    final String b64Secret = Key.fromSecureRandom(32).base64;

    await encryptFile(originalFile, encryptedFile, b64Secret);
    await decryptFile(encryptedFile, decryptedFile, b64Secret);

    final originalBytes = await originalFile.readAsBytes();
    final decryptedBytes = await decryptedFile.readAsBytes();
    expect(eq(originalBytes, decryptedBytes), true);
    encryptedFile.delete();
    decryptedFile.delete();
  });
}
