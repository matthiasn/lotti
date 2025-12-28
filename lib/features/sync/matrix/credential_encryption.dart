import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:lotti/classes/config.dart';

/// Represents the encrypted credentials payload that will be encoded in the QR.
class EncryptedCredentials {
  EncryptedCredentials({
    required this.homeServer,
    required this.user,
    required this.password,
    required this.expiresAt,
  });

  factory EncryptedCredentials.fromJson(Map<String, dynamic> json) {
    return EncryptedCredentials(
      homeServer: json['homeServer'] as String,
      user: json['user'] as String,
      password: json['password'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  }

  factory EncryptedCredentials.fromConfig(
    MatrixConfig config, {
    required Duration expiresIn,
  }) {
    return EncryptedCredentials(
      homeServer: config.homeServer,
      user: config.user,
      password: config.password,
      expiresAt: DateTime.now().add(expiresIn),
    );
  }

  final String homeServer;
  final String user;
  final String password;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  MatrixConfig toConfig() => MatrixConfig(
        homeServer: homeServer,
        user: user,
        password: password,
      );

  Map<String, dynamic> toJson() => {
        'homeServer': homeServer,
        'user': user,
        'password': password,
        'expiresAt': expiresAt.toIso8601String(),
      };
}

/// Result of decryption attempt.
sealed class DecryptionResult {
  const DecryptionResult();
}

class DecryptionSuccess extends DecryptionResult {
  const DecryptionSuccess(this.credentials);
  final EncryptedCredentials credentials;
}

class DecryptionExpired extends DecryptionResult {
  const DecryptionExpired(this.expiredAt);
  final DateTime expiredAt;
}

class DecryptionFailed extends DecryptionResult {
  const DecryptionFailed([this.error]);
  final Object? error;
}

/// Service for encrypting and decrypting Matrix credentials using AES-256-GCM.
///
/// Uses a 6-digit PIN to derive the encryption key via PBKDF2.
/// The encrypted payload includes:
/// - Version number for future compatibility
/// - Salt for key derivation
/// - IV/nonce for AES-GCM
/// - Encrypted data (homeserver, username, password, expiry)
/// - MAC for authentication
class CredentialEncryption {
  CredentialEncryption._();

  static const int _pinLength = 6;
  static const int _saltLength = 16;
  static const int _ivLength = 12;
  static const int _pbkdf2Iterations = 100000;
  static const int _currentVersion = 1;
  static const Duration defaultExpiry = Duration(minutes: 15);

  /// Generates a cryptographically secure 6-digit PIN.
  static String generatePin() {
    final random = Random.secure();
    final pin = StringBuffer();
    for (var i = 0; i < _pinLength; i++) {
      pin.write(random.nextInt(10));
    }
    return pin.toString();
  }

  /// Encrypts a [MatrixConfig] with the given [pin].
  ///
  /// Returns a base64-encoded string containing the encrypted payload.
  /// The payload expires after [expiresIn] duration (default 15 minutes).
  static Future<String> encrypt(
    MatrixConfig config,
    String pin, {
    Duration expiresIn = defaultExpiry,
  }) async {
    final credentials = EncryptedCredentials.fromConfig(
      config,
      expiresIn: expiresIn,
    );

    final plaintext = utf8.encode(jsonEncode(credentials.toJson()));
    final salt = _generateSecureBytes(_saltLength);
    final iv = _generateSecureBytes(_ivLength);

    final key = await _deriveKey(pin, salt);
    final algorithm = AesGcm.with256bits();

    final secretBox = await algorithm.encrypt(
      plaintext,
      secretKey: key,
      nonce: iv,
    );

    // Build payload: version (1 byte) + salt + iv + ciphertext + mac
    final payload = BytesBuilder()
      ..addByte(_currentVersion)
      ..add(salt)
      ..add(iv)
      ..add(secretBox.cipherText)
      ..add(secretBox.mac.bytes);

    return base64Encode(payload.toBytes());
  }

  /// Decrypts an encrypted payload with the given [pin].
  ///
  /// Returns a [DecryptionResult] which can be:
  /// - [DecryptionSuccess] with the decrypted credentials
  /// - [DecryptionExpired] if the QR code has expired
  /// - [DecryptionFailed] if the PIN is wrong or data is corrupted
  static Future<DecryptionResult> decrypt(
    String encryptedPayload,
    String pin,
  ) async {
    try {
      final payload = base64Decode(encryptedPayload);
      if (payload.isEmpty) {
        return const DecryptionFailed();
      }

      var offset = 0;

      // Read version
      final version = payload[offset];
      offset += 1;

      if (version != _currentVersion) {
        return const DecryptionFailed();
      }

      // Read salt
      final salt = payload.sublist(offset, offset + _saltLength);
      offset += _saltLength;

      // Read IV
      final iv = payload.sublist(offset, offset + _ivLength);
      offset += _ivLength;

      // MAC is last 16 bytes
      const macLength = 16;
      final mac = payload.sublist(payload.length - macLength);
      final ciphertext = payload.sublist(offset, payload.length - macLength);

      final key = await _deriveKey(pin, salt);
      final algorithm = AesGcm.with256bits();

      final secretBox = SecretBox(
        ciphertext,
        nonce: iv,
        mac: Mac(mac),
      );

      final plaintext = await algorithm.decrypt(
        secretBox,
        secretKey: key,
      );

      final json = jsonDecode(utf8.decode(plaintext)) as Map<String, dynamic>;
      final credentials = EncryptedCredentials.fromJson(json);

      if (credentials.isExpired) {
        return DecryptionExpired(credentials.expiresAt);
      }

      return DecryptionSuccess(credentials);
    } on SecretBoxAuthenticationError {
      // Wrong PIN or corrupted data
      return const DecryptionFailed();
    } catch (e) {
      return DecryptionFailed(e);
    }
  }

  /// Derives a 256-bit key from the PIN using PBKDF2.
  static Future<SecretKey> _deriveKey(String pin, List<int> salt) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _pbkdf2Iterations,
      bits: 256,
    );

    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(pin)),
      nonce: salt,
    );
  }

  /// Generates cryptographically secure random bytes.
  static Uint8List _generateSecureBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(length, (_) => random.nextInt(256)),
    );
  }
}
