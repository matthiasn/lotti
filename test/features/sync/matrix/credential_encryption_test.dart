import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/features/sync/matrix/credential_encryption.dart';

void main() {
  group('CredentialEncryption', () {
    const testConfig = MatrixConfig(
      homeServer: 'https://matrix.example.com',
      user: 'testuser',
      password: 'testpassword123',
    );

    group('generatePin', () {
      test('generates a 6-digit PIN', () {
        final pin = CredentialEncryption.generatePin();

        expect(pin.length, equals(6));
        expect(int.tryParse(pin), isNotNull);
      });

      test('generates different PINs on each call', () {
        final pins = <String>{};
        for (var i = 0; i < 100; i++) {
          pins.add(CredentialEncryption.generatePin());
        }

        // With 1M possible combinations, 100 calls should produce unique PINs
        expect(pins.length, equals(100));
      });

      test('generates only numeric characters', () {
        for (var i = 0; i < 50; i++) {
          final pin = CredentialEncryption.generatePin();
          expect(pin, matches(RegExp(r'^\d{6}$')));
        }
      });
    });

    group('encrypt and decrypt', () {
      test('round-trip encryption/decryption succeeds', () async {
        final pin = CredentialEncryption.generatePin();

        final encrypted = await CredentialEncryption.encrypt(testConfig, pin);
        final result = await CredentialEncryption.decrypt(encrypted, pin);

        expect(result, isA<DecryptionSuccess>());
        final success = result as DecryptionSuccess;
        expect(success.credentials.homeServer, equals(testConfig.homeServer));
        expect(success.credentials.user, equals(testConfig.user));
        expect(success.credentials.password, equals(testConfig.password));
      });

      test('decryption fails with wrong PIN', () async {
        const correctPin = '123456';
        const wrongPin = '654321';

        final encrypted =
            await CredentialEncryption.encrypt(testConfig, correctPin);
        final result = await CredentialEncryption.decrypt(encrypted, wrongPin);

        expect(result, isA<DecryptionFailed>());
      });

      test('decryption fails with empty payload', () async {
        final result = await CredentialEncryption.decrypt('', '123456');

        expect(result, isA<DecryptionFailed>());
      });

      test('decryption fails with invalid base64', () async {
        final result =
            await CredentialEncryption.decrypt('not-valid-base64!@#', '123456');

        expect(result, isA<DecryptionFailed>());
      });

      test('decryption fails with truncated payload', () async {
        const pin = '123456';
        final encrypted = await CredentialEncryption.encrypt(testConfig, pin);

        // Truncate the payload
        final truncated = encrypted.substring(0, encrypted.length ~/ 2);
        final result = await CredentialEncryption.decrypt(truncated, pin);

        expect(result, isA<DecryptionFailed>());
      });

      test('different PINs produce different ciphertexts', () async {
        const pin1 = '111111';
        const pin2 = '222222';

        final encrypted1 = await CredentialEncryption.encrypt(testConfig, pin1);
        final encrypted2 = await CredentialEncryption.encrypt(testConfig, pin2);

        expect(encrypted1, isNot(equals(encrypted2)));
      });

      test('same PIN produces different ciphertexts (random IV)', () async {
        const pin = '123456';

        final encrypted1 = await CredentialEncryption.encrypt(testConfig, pin);
        final encrypted2 = await CredentialEncryption.encrypt(testConfig, pin);

        // Due to random salt and IV, ciphertexts should differ
        expect(encrypted1, isNot(equals(encrypted2)));

        // But both should decrypt correctly
        final result1 = await CredentialEncryption.decrypt(encrypted1, pin);
        final result2 = await CredentialEncryption.decrypt(encrypted2, pin);

        expect(result1, isA<DecryptionSuccess>());
        expect(result2, isA<DecryptionSuccess>());
      });
    });

    group('expiration', () {
      test('credentials are not expired when just created', () async {
        const pin = '123456';

        final encrypted = await CredentialEncryption.encrypt(
          testConfig,
          pin,
        );
        final result = await CredentialEncryption.decrypt(encrypted, pin);

        expect(result, isA<DecryptionSuccess>());
        final success = result as DecryptionSuccess;
        expect(success.credentials.isExpired, isFalse);
      });

      test('credentials expire after expiry duration', () async {
        const pin = '123456';

        // Create with very short expiry
        final encrypted = await CredentialEncryption.encrypt(
          testConfig,
          pin,
          expiresIn: const Duration(milliseconds: 1),
        );

        // Wait for expiry
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final result = await CredentialEncryption.decrypt(encrypted, pin);

        expect(result, isA<DecryptionExpired>());
      });

      test('DecryptionExpired contains expiration time', () async {
        const pin = '123456';

        final encrypted = await CredentialEncryption.encrypt(
          testConfig,
          pin,
          expiresIn: const Duration(milliseconds: 1),
        );

        await Future<void>.delayed(const Duration(milliseconds: 10));

        final result = await CredentialEncryption.decrypt(encrypted, pin);

        expect(result, isA<DecryptionExpired>());
        final expired = result as DecryptionExpired;
        expect(expired.expiredAt, isNotNull);
        expect(expired.expiredAt.isBefore(DateTime.now()), isTrue);
      });
    });

    group('EncryptedCredentials', () {
      test('toConfig creates valid MatrixConfig', () {
        final credentials = EncryptedCredentials(
          homeServer: 'https://matrix.example.com',
          user: 'testuser',
          password: 'testpassword',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );

        final config = credentials.toConfig();

        expect(config.homeServer, equals('https://matrix.example.com'));
        expect(config.user, equals('testuser'));
        expect(config.password, equals('testpassword'));
      });

      test('fromConfig creates credentials with expiry', () {
        final credentials = EncryptedCredentials.fromConfig(
          testConfig,
          expiresIn: const Duration(minutes: 15),
        );

        expect(credentials.homeServer, equals(testConfig.homeServer));
        expect(credentials.user, equals(testConfig.user));
        expect(credentials.password, equals(testConfig.password));
        expect(credentials.isExpired, isFalse);
        expect(
          credentials.expiresAt.isAfter(DateTime.now()),
          isTrue,
        );
      });

      test('JSON round-trip preserves all fields', () {
        final original = EncryptedCredentials(
          homeServer: 'https://matrix.example.com',
          user: 'testuser',
          password: 'testpassword',
          expiresAt: DateTime.utc(2025, 12, 31, 12),
        );

        final json = original.toJson();
        final restored = EncryptedCredentials.fromJson(json);

        expect(restored.homeServer, equals(original.homeServer));
        expect(restored.user, equals(original.user));
        expect(restored.password, equals(original.password));
        expect(restored.expiresAt, equals(original.expiresAt));
      });
    });

    group('DecryptionResult', () {
      test('DecryptionSuccess contains credentials', () {
        final credentials = EncryptedCredentials(
          homeServer: 'https://matrix.example.com',
          user: 'testuser',
          password: 'testpassword',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );

        final result = DecryptionSuccess(credentials);

        expect(result.credentials, equals(credentials));
      });

      test('DecryptionFailed can optionally contain error', () {
        const withoutError = DecryptionFailed();
        final withError = DecryptionFailed(Exception('test error'));

        expect(withoutError.error, isNull);
        expect(withError.error, isNotNull);
      });
    });

    group('edge cases', () {
      test('handles special characters in password', () async {
        const configWithSpecialChars = MatrixConfig(
          homeServer: 'https://matrix.example.com',
          user: 'testuser',
          password: r'p@$$w0rd!#$%^&*(){}[]|\/":;<>,.?~`',
        );
        const pin = '123456';

        final encrypted = await CredentialEncryption.encrypt(
          configWithSpecialChars,
          pin,
        );
        final result = await CredentialEncryption.decrypt(encrypted, pin);

        expect(result, isA<DecryptionSuccess>());
        final success = result as DecryptionSuccess;
        expect(
          success.credentials.password,
          equals(configWithSpecialChars.password),
        );
      });

      test('handles unicode in username', () async {
        const configWithUnicode = MatrixConfig(
          homeServer: 'https://matrix.example.com',
          user: 'user_日本語_emoji_🎉',
          password: 'testpassword',
        );
        const pin = '123456';

        final encrypted = await CredentialEncryption.encrypt(
          configWithUnicode,
          pin,
        );
        final result = await CredentialEncryption.decrypt(encrypted, pin);

        expect(result, isA<DecryptionSuccess>());
        final success = result as DecryptionSuccess;
        expect(success.credentials.user, equals(configWithUnicode.user));
      });

      test('handles very long homeserver URL', () async {
        final longUrl =
            'https://${'subdomain.' * 50}matrix.example.com/path/to/server';
        final configWithLongUrl = MatrixConfig(
          homeServer: longUrl,
          user: 'testuser',
          password: 'testpassword',
        );
        const pin = '123456';

        final encrypted = await CredentialEncryption.encrypt(
          configWithLongUrl,
          pin,
        );
        final result = await CredentialEncryption.decrypt(encrypted, pin);

        expect(result, isA<DecryptionSuccess>());
        final success = result as DecryptionSuccess;
        expect(success.credentials.homeServer, equals(longUrl));
      });
    });
  });
}
