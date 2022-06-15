import 'dart:io';

import 'package:collection/collection.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/sync/encryption.dart';

Function eq = const ListEquality<String>().equals;

void main() {
  test('File encryption', () async {
    final originalFile = File('test_resources/test.aac');
    final encryptedFile = File('test_resources/test.aac.aes');
    final decryptedFile = File('test_resources/test_decrypted.aac');
    final b64Secret = Key.fromSecureRandom(32).base64;

    await encryptFile(originalFile, encryptedFile, b64Secret);
    await decryptFile(encryptedFile, decryptedFile, b64Secret);

    final originalBytes = await originalFile.readAsBytes();
    final decryptedBytes = await decryptedFile.readAsBytes();
    // ignore: avoid_dynamic_calls
    expect(eq(originalBytes, decryptedBytes), true);
    await encryptedFile.delete();
    await decryptedFile.delete();
  });
}
