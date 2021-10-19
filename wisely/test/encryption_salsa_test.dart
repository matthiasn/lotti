import 'package:encrypt/encrypt.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wisely/sync/encryption_salsa.dart';

void main() {
  test('Check Salsa encryption/decryption roundtrip', () {
    const testString = 'Ḽơᶉëᶆ ȋṕšᶙṁ ḍỡḽǭᵳ ʂǐť ӓṁệẗ, ĉṓɲṩḙċťᶒțûɾ ấɖḯƥĭṩčįɳġ';
    final String b64Secret = Key.fromSecureRandom(32).base64;
    final String encryptedMessage = encryptSalsa(testString, b64Secret);
    final String decrypted = decryptSalsa(encryptedMessage, b64Secret);
    print('Salsa decrypted: $decrypted');
    expect(decrypted, testString);
  });
}
