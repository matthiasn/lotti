import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';

/// First bytes of every portable backup bundle.
const profileBackupBundleMagic = 'LOTTIBAK';

/// Container version this build writes and the newest it reads.
const profileBackupBundleVersion = 1;

/// The only payload cipher: chunked ChaCha20-Poly1305 (RFC 8439).
const profileBackupStreamCipher = 'chacha20-poly1305-stream';

/// Plaintext bytes per encrypted chunk.
const int profileBackupChunkSize = 64 * 1024;

/// A bundle that is not a Lotti backup, or one this build cannot read.
class ProfileBackupBundleFormatException implements Exception {
  const ProfileBackupBundleFormatException(this.message);

  final String message;

  @override
  String toString() => 'ProfileBackupBundleFormatException: $message';
}

/// Argon2id cost parameters for deriving a key from a passphrase.
@immutable
class BackupKdfParameters {
  const BackupKdfParameters({
    required this.memoryKiB,
    required this.iterations,
    required this.parallelism,
  });

  /// RFC 9106 §4, second recommended option: 64 MiB, 3 passes, one lane.
  /// About half a second in Dart on a desktop and a few seconds on a phone,
  /// paid once per backup and once per restore.
  static const recommended = BackupKdfParameters(
    memoryKiB: 64 * 1024,
    iterations: 3,
    parallelism: 1,
  );

  final int memoryKiB;
  final int iterations;
  final int parallelism;

  /// Upper bounds one slot may demand. A tampered header must not be able to
  /// make restore allocate unbounded memory or spin for hours before the
  /// passphrase is even checked.
  static const int maxMemoryKiB = 256 * 1024;
  static const maxIterations = 16;
  static const maxParallelism = 8;

  /// Upper bound on the Argon2id work of all slots together, in KiB × passes:
  /// four derivations at the [recommended] cost. Restore tries the slots one
  /// after another, so without it eight slots could each demand the per-slot
  /// maximum.
  static const int maxTotalWork = 4 * 64 * 1024 * 3;

  /// This derivation's share of [maxTotalWork].
  int get work => memoryKiB * iterations;

  void validate() {
    if (memoryKiB < 8 * parallelism || memoryKiB > maxMemoryKiB) {
      throw ProfileBackupBundleFormatException(
        'Unsupported Argon2id memory cost: $memoryKiB KiB.',
      );
    }
    if (iterations < 1 || iterations > maxIterations) {
      throw ProfileBackupBundleFormatException(
        'Unsupported Argon2id iteration count: $iterations.',
      );
    }
    if (parallelism < 1 || parallelism > maxParallelism) {
      throw ProfileBackupBundleFormatException(
        'Unsupported Argon2id parallelism: $parallelism.',
      );
    }
  }
}

/// One way to unlock a bundle's data key.
///
/// The payload is encrypted with a random data key; each slot holds that key
/// wrapped under a key-encryption key of its own. Today the only slot is the
/// user's passphrase. A recovery-code slot can be added later without
/// re-encrypting the payload, because slots are deliberately left out of what
/// the payload chunks authenticate.
@immutable
class BackupKeySlot {
  const BackupKeySlot({
    required this.salt,
    required this.kdf,
    required this.nonce,
    required this.wrappedKey,
  });

  factory BackupKeySlot.fromJson(Object? json) {
    final map = _map(json, 'key slot');
    if (map['kind'] != kindPassphrase) {
      throw ProfileBackupBundleFormatException(
        'Unsupported key slot kind: ${map['kind']}.',
      );
    }
    final kdfJson = _map(map['kdf'], 'key derivation');
    if (kdfJson['algorithm'] != 'argon2id' || kdfJson['version'] != 19) {
      throw const ProfileBackupBundleFormatException(
        'Unsupported key derivation.',
      );
    }
    final kdf = BackupKdfParameters(
      memoryKiB: _int(kdfJson, 'memoryKiB'),
      iterations: _int(kdfJson, 'iterations'),
      parallelism: _int(kdfJson, 'parallelism'),
    )..validate();
    return BackupKeySlot(
      salt: _bytes(kdfJson, 'salt', saltLength),
      kdf: kdf,
      nonce: _bytes(map, 'nonce', nonceLength),
      wrappedKey: _bytes(map, 'wrappedKey', wrappedKeyLength),
    );
  }

  static const kindPassphrase = 'passphrase';
  static const saltLength = 16;
  static const nonceLength = 12;

  /// A 32-byte data key plus the 16-byte Poly1305 tag.
  static const wrappedKeyLength = 48;

  final Uint8List salt;
  final BackupKdfParameters kdf;
  final Uint8List nonce;
  final Uint8List wrappedKey;

  /// Bytes that bind this slot's derivation to the header when the data key
  /// is wrapped or unwrapped.
  Uint8List kdfBinding() => _canonicalJson(_kdfJson());

  Map<String, Object?> _kdfJson() => {
    'algorithm': 'argon2id',
    'iterations': kdf.iterations,
    'memoryKiB': kdf.memoryKiB,
    'parallelism': kdf.parallelism,
    'salt': base64.encode(salt),
    'version': 19,
  };

  Map<String, Object?> toJson() => {
    'kdf': _kdfJson(),
    'kind': kindPassphrase,
    'nonce': base64.encode(nonce),
    'wrappedKey': base64.encode(wrappedKey),
  };
}

/// The unencrypted header at the front of a bundle.
///
/// It carries only what is needed to derive the key and decrypt: the
/// container version, cipher, chunk size, a random bundle id and the key
/// slots. Nothing about the profile — its name, type, size, file list or app
/// version — is readable without the passphrase; all of that lives in the
/// encrypted manifest.
@immutable
class ProfileBackupBundleHeader {
  const ProfileBackupBundleHeader({
    required this.bundleId,
    required this.keySlots,
    this.chunkSize = profileBackupChunkSize,
  });

  factory ProfileBackupBundleHeader.fromBytes(Uint8List bytes) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw const ProfileBackupBundleFormatException(
        'The backup header is not readable.',
      );
    }
    final map = _map(decoded, 'header');
    final version = _int(map, 'version');
    if (version > profileBackupBundleVersion) {
      throw ProfileBackupBundleFormatException(
        'This backup was made by a newer version of Lotti (format $version).',
      );
    }
    if (version != profileBackupBundleVersion ||
        map['cipher'] != profileBackupStreamCipher ||
        _int(map, 'chunkSize') != profileBackupChunkSize) {
      throw const ProfileBackupBundleFormatException(
        'Unsupported backup container parameters.',
      );
    }
    final slots = map['keySlots'];
    if (slots is! List || slots.isEmpty || slots.length > 8) {
      throw const ProfileBackupBundleFormatException(
        'The backup has no usable key slot.',
      );
    }
    final keySlots = [for (final slot in slots) BackupKeySlot.fromJson(slot)];
    final totalWork = keySlots.fold(0, (sum, slot) => sum + slot.kdf.work);
    if (totalWork > BackupKdfParameters.maxTotalWork) {
      throw const ProfileBackupBundleFormatException(
        'The backup asks for more key-derivation work than Lotti allows.',
      );
    }
    return ProfileBackupBundleHeader(
      bundleId: _bytes(map, 'bundleId', bundleIdLength),
      keySlots: keySlots,
    );
  }

  static const bundleIdLength = 16;

  /// Random per bundle. Mixed into every chunk's authenticated data, so
  /// chunks cannot be moved between bundles.
  final Uint8List bundleId;
  final int chunkSize;
  final List<BackupKeySlot> keySlots;

  /// The part of the header the payload authenticates: everything but the
  /// key slots.
  Uint8List coreBytes() => _canonicalJson(_coreJson());

  Map<String, Object?> _coreJson() => {
    'bundleId': base64.encode(bundleId),
    'chunkSize': chunkSize,
    'cipher': profileBackupStreamCipher,
    'version': profileBackupBundleVersion,
  };

  Uint8List toBytes() => _canonicalJson({
    ..._coreJson(),
    'keySlots': [for (final slot in keySlots) slot.toJson()],
  });
}

/// Sorted-key, whitespace-free JSON, so the same header always produces the
/// same authenticated bytes.
Uint8List _canonicalJson(Map<String, Object?> value) =>
    utf8.encode(jsonEncode(_sortKeys(value)));

Object? _sortKeys(Object? value) => switch (value) {
  final Map<String, Object?> map => {
    for (final key in map.keys.toList()..sort()) key: _sortKeys(map[key]),
  },
  final List<Object?> list => [for (final item in list) _sortKeys(item)],
  _ => value,
};

Map<String, Object?> _map(Object? value, String what) {
  if (value is! Map<String, Object?>) {
    throw ProfileBackupBundleFormatException('Malformed backup $what.');
  }
  return value;
}

int _int(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! int) {
    throw ProfileBackupBundleFormatException('Malformed backup field "$key".');
  }
  return value;
}

Uint8List _bytes(Map<String, Object?> map, String key, int length) {
  final value = map[key];
  if (value is String) {
    try {
      final bytes = base64.decode(value);
      if (bytes.length == length) return bytes;
    } on FormatException {
      // Reported below.
    }
  }
  throw ProfileBackupBundleFormatException('Malformed backup field "$key".');
}
