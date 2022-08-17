import 'dart:io';

import 'package:encrypt/encrypt.dart';
import 'package:flutter/foundation.dart' hide Key;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/sync/encryption.dart';

void main() {
  test('Check AES GCM encryption/decryption roundtrip', () async {
    final originalFile = File('test_resources/test.txt');
    final testString = await originalFile.readAsString();
    final b64Secret = Key.fromSecureRandom(32).base64;
    final encryptedMessage = await encryptString(
      b64Secret: b64Secret,
      plainText: testString,
    );
    final decrypted = await decryptString(
      encrypted: encryptedMessage,
      b64Secret: b64Secret,
    );
    debugPrint('AES GCM decrypted: $decrypted');
    expect(decrypted, testString);
  });
}
