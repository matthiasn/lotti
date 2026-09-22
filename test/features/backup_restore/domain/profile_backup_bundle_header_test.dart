import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/backup_restore/domain/profile_backup_bundle_header.dart';

Uint8List _filled(int length, int value) =>
    Uint8List.fromList(List.filled(length, value));

ProfileBackupBundleHeader _header({List<BackupKeySlot>? slots}) =>
    ProfileBackupBundleHeader(
      bundleId: _filled(ProfileBackupBundleHeader.bundleIdLength, 1),
      keySlots: slots ?? [_slot()],
    );

BackupKeySlot _slot({BackupKdfParameters? kdf}) => BackupKeySlot(
  salt: _filled(BackupKeySlot.saltLength, 2),
  kdf: kdf ?? BackupKdfParameters.recommended,
  nonce: _filled(BackupKeySlot.nonceLength, 3),
  wrappedKey: _filled(BackupKeySlot.wrappedKeyLength, 4),
);

Map<String, Object?> _json(ProfileBackupBundleHeader header) =>
    jsonDecode(utf8.decode(header.toBytes())) as Map<String, Object?>;

Uint8List _bytes(Map<String, Object?> json) => utf8.encode(jsonEncode(json));

Map<String, Object?> _slotJson(Map<String, Object?> header) =>
    (header['keySlots']! as List).single as Map<String, Object?>;

Matcher _formatError(String fragment) => throwsA(
  isA<ProfileBackupBundleFormatException>().having(
    (e) => e.message,
    'message',
    contains(fragment),
  ),
);

void main() {
  group('ProfileBackupBundleHeader', () {
    test('round-trips through its bytes', () {
      final header = _header();

      final parsed = ProfileBackupBundleHeader.fromBytes(header.toBytes());

      expect(parsed.bundleId, header.bundleId);
      expect(parsed.chunkSize, profileBackupChunkSize);
      final slot = parsed.keySlots.single;
      expect(slot.salt, _filled(16, 2));
      expect(slot.nonce, _filled(12, 3));
      expect(slot.wrappedKey, _filled(48, 4));
      expect(slot.kdf.memoryKiB, BackupKdfParameters.recommended.memoryKiB);
      expect(parsed.toBytes(), header.toBytes());
    });

    test('serialises with sorted keys and no whitespace', () {
      expect(
        utf8.decode(_header().coreBytes()),
        '{"bundleId":"AQEBAQEBAQEBAQEBAQEBAQ==","chunkSize":65536,'
        '"cipher":"chacha20-poly1305-stream","version":1}',
      );
    });

    test('the authenticated core leaves the key slots out, so a slot can be '
        'added later', () {
      final withTwoSlots = _header(slots: [_slot(), _slot()]);

      expect(withTwoSlots.coreBytes(), _header().coreBytes());
      expect(withTwoSlots.toBytes(), isNot(_header().toBytes()));
    });

    test('binds the key derivation parameters of each slot', () {
      final cheaper = _slot(
        kdf: const BackupKdfParameters(
          memoryKiB: 64,
          iterations: 1,
          parallelism: 1,
        ),
      );

      expect(cheaper.kdfBinding(), isNot(_slot().kdfBinding()));
      expect(utf8.decode(_slot().kdfBinding()), contains('"salt":'));
    });

    test('rejects unreadable JSON', () {
      expect(
        () => ProfileBackupBundleHeader.fromBytes(utf8.encode('{nope')),
        _formatError('not readable'),
      );
    });

    test('names a newer format as coming from a newer Lotti', () {
      final json = _json(_header())
        ..['version'] = profileBackupBundleVersion + 1;

      expect(
        () => ProfileBackupBundleHeader.fromBytes(_bytes(json)),
        _formatError('newer version of Lotti'),
      );
    });

    for (final (field, value) in [
      ('cipher', 'aes-256-gcm'),
      ('chunkSize', 1024),
      ('version', 0),
    ]) {
      test('rejects an unsupported $field', () {
        final json = _json(_header())..[field] = value;

        expect(
          () => ProfileBackupBundleHeader.fromBytes(_bytes(json)),
          _formatError('Unsupported backup container'),
        );
      });
    }

    for (final (label, slots) in [
      ('no slots', <Object?>[]),
      ('a non-list', 'slot'),
      ('more than eight slots', List.filled(9, _slot().toJson())),
    ]) {
      test('rejects $label', () {
        final json = _json(_header())..['keySlots'] = slots;

        expect(
          () => ProfileBackupBundleHeader.fromBytes(_bytes(json)),
          _formatError('no usable key slot'),
        );
      });
    }

    for (final (field, value) in [
      ('bundleId', 'not base64!'),
      ('bundleId', base64.encode([1, 2, 3])),
      ('version', '1'),
    ]) {
      test('rejects a malformed $field: $value', () {
        final json = _json(_header())..[field] = value;

        expect(
          () => ProfileBackupBundleHeader.fromBytes(_bytes(json)),
          throwsA(isA<ProfileBackupBundleFormatException>()),
        );
      });
    }

    test('rejects a header that is not an object', () {
      expect(
        () => ProfileBackupBundleHeader.fromBytes(utf8.encode('[1]')),
        _formatError('Malformed backup header'),
      );
    });
  });

  group('BackupKeySlot', () {
    Map<String, Object?> slotJson() => _slotJson(_json(_header()));

    ProfileBackupBundleHeader parseWithSlot(Map<String, Object?> slot) {
      final json = _json(_header())..['keySlots'] = [slot];
      return ProfileBackupBundleHeader.fromBytes(_bytes(json));
    }

    test('rejects an unknown slot kind', () {
      expect(
        () => parseWithSlot(slotJson()..['kind'] = 'hardware-key'),
        _formatError('Unsupported key slot kind'),
      );
    });

    for (final (field, value) in [
      ('algorithm', 'scrypt'),
      ('version', 16),
    ]) {
      test('rejects a key derivation other than Argon2id v1.3 ($field)', () {
        final slot = slotJson();
        (slot['kdf']! as Map<String, Object?>)[field] = value;

        expect(() => parseWithSlot(slot), _formatError('key derivation'));
      });
    }

    // A tampered header must not make restore allocate or spin without bound
    // before the passphrase is even tried.
    for (final (field, value, fragment) in [
      ('memoryKiB', BackupKdfParameters.maxMemoryKiB + 1, 'memory cost'),
      ('memoryKiB', 7, 'memory cost'),
      ('iterations', 0, 'iteration count'),
      ('iterations', BackupKdfParameters.maxIterations + 1, 'iteration count'),
      ('parallelism', 0, 'parallelism'),
      ('parallelism', BackupKdfParameters.maxParallelism + 1, 'parallelism'),
    ]) {
      test('rejects $field = $value', () {
        final slot = slotJson();
        (slot['kdf']! as Map<String, Object?>)[field] = value;

        expect(() => parseWithSlot(slot), _formatError(fragment));
      });
    }

    for (final field in ['nonce', 'wrappedKey']) {
      test('rejects a $field of the wrong length', () {
        expect(
          () => parseWithSlot(slotJson()..[field] = base64.encode([1])),
          _formatError('"$field"'),
        );
      });
    }

    test('rejects a salt of the wrong length', () {
      final slot = slotJson();
      (slot['kdf']! as Map<String, Object?>)['salt'] = base64.encode([1]);

      expect(() => parseWithSlot(slot), _formatError('"salt"'));
    });

    test('rejects a slot that is not an object', () {
      final json = _json(_header())..['keySlots'] = [42];

      expect(
        () => ProfileBackupBundleHeader.fromBytes(_bytes(json)),
        _formatError('Malformed backup key slot'),
      );
    });

    test('four recommended slots fit the total work budget', () {
      final header = _header(slots: List.generate(4, (_) => _slot()));

      expect(
        ProfileBackupBundleHeader.fromBytes(header.toBytes()).keySlots,
        hasLength(4),
      );
    });

    test('a fifth recommended slot exceeds the total work budget', () {
      // Each slot is individually valid: only the sum, tried one slot after
      // another before any passphrase check, is refused.
      final header = _header(slots: List.generate(5, (_) => _slot()));

      expect(
        () => ProfileBackupBundleHeader.fromBytes(header.toBytes()),
        _formatError('more key-derivation work'),
      );
    });

    test(
      'one slot at every per-slot maximum exceeds the budget on its own',
      () {
        final header = _header(
          slots: [
            _slot(
              kdf: const BackupKdfParameters(
                memoryKiB: BackupKdfParameters.maxMemoryKiB,
                iterations: BackupKdfParameters.maxIterations,
                parallelism: 1,
              ),
            ),
          ],
        );

        expect(
          () => ProfileBackupBundleHeader.fromBytes(header.toBytes()),
          _formatError('more key-derivation work'),
        );
      },
    );

    test('the recommended cost is valid', () {
      expect(BackupKdfParameters.recommended.validate, returnsNormally);
    });
  });
}
