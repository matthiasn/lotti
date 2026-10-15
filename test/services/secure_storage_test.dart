import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/services/logging_domains.dart';
import 'package:lotti/services/secure_storage.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/package_info.dart';
import '../mocks/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Each test starts with a fresh in-memory secure storage backend, and with
  // app metadata `PackageInfo.fromPlatform()` can answer from. Seeding it per
  // test rather than per file matters: the value is cached in an isolate-wide
  // static, and the release lane runs the whole suite in one isolate.
  setUp(() {
    mockPackageInfo(packageName: 'com.example.lotti.test');
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('SecureStorage.read', () {
    test('returns null when key is absent', () async {
      final storage = SecureStorage();

      final result = await storage.read(key: 'missing_key');

      expect(result, isNull);
    });

    test('reads a value that was pre-loaded into the secure store', () async {
      FlutterSecureStorage.setMockInitialValues({'my_key': 'my_value'});
      final storage = SecureStorage();

      final result = await storage.read(key: 'my_key');

      expect(result, 'my_value');
    });

    test(
      'caches value after first read — subsequent reads return cached value',
      () async {
        FlutterSecureStorage.setMockInitialValues({'cached_key': 'initial'});
        final storage = SecureStorage();

        // First call — loads from underlying storage and populates internal cache.
        final first = await storage.read(key: 'cached_key');
        expect(first, 'initial');

        // Mutate the underlying store directly; the in-memory cache must still
        // return the old value because the key is already in `_state`.
        FlutterSecureStorage.setMockInitialValues({'cached_key': 'changed'});

        final second = await storage.read(key: 'cached_key');
        expect(
          second,
          'initial',
          reason: 'cached value should be returned without re-reading storage',
        );
      },
    );

    test(
      'returns null when value in secure store is absent for missing key',
      () async {
        // Ensure the key truly does not exist.
        FlutterSecureStorage.setMockInitialValues({});
        final storage = SecureStorage();

        expect(await storage.readValue('no_such_key'), isNull);
      },
    );
  });

  group('SecureStorage.write', () {
    test('persists a value that can be read back', () async {
      final storage = SecureStorage();

      await storage.write(key: 'token', value: 'abc123');
      final result = await storage.read(key: 'token');

      expect(result, 'abc123');
    });

    test('overwrites an existing value', () async {
      FlutterSecureStorage.setMockInitialValues({'token': 'old'});
      final storage = SecureStorage();

      // Pre-warm cache so the old value is in `_state`.
      await storage.read(key: 'token');

      await storage.write(key: 'token', value: 'new_value');
      final result = await storage.read(key: 'token');

      expect(result, 'new_value');
    });

    test(
      'write is immediately visible through readValue (shared cache)',
      () async {
        final storage = SecureStorage();

        await storage.write(key: 'coherent_key', value: 'coherent_value');

        // readValue and read share the same `_state` cache — a write must be
        // observable through both getters.
        expect(await storage.readValue('coherent_key'), 'coherent_value');
        expect(await storage.read(key: 'coherent_key'), 'coherent_value');
      },
    );

    test('writeValue delegates to write and is readable via read', () async {
      final storage = SecureStorage();

      await storage.writeValue('direct_key', 'direct_value');
      final result = await storage.read(key: 'direct_key');

      expect(result, 'direct_value');
    });

    test('write with different keys stores values independently', () async {
      final storage = SecureStorage();

      await storage.write(key: 'key_a', value: 'value_a');
      await storage.write(key: 'key_b', value: 'value_b');

      expect(await storage.read(key: 'key_a'), 'value_a');
      expect(await storage.read(key: 'key_b'), 'value_b');
    });
  });

  group('SecureStorage.delete', () {
    test('removes a value so read returns null afterward', () async {
      FlutterSecureStorage.setMockInitialValues({'del_key': 'to_delete'});
      final storage = SecureStorage();

      // Pre-warm cache.
      await storage.read(key: 'del_key');

      await storage.delete(key: 'del_key');
      final result = await storage.read(key: 'del_key');

      // After deletion the in-memory cache entry is removed AND the underlying
      // store is empty, so the next read should return null.
      expect(result, isNull);
    });

    test(
      'a read issued after a delete waits for it and finds nothing',
      () async {
        FlutterSecureStorage.setMockInitialValues({'del_key': 'to_delete'});
        final storage = SecureStorage();

        final deleted = storage.delete(key: 'del_key');
        final read = storage.read(key: 'del_key');
        await deleted;

        expect(await read, isNull);
        expect(await storage.read(key: 'del_key'), isNull);
      },
    );

    test('deleting a non-existent key does not throw', () async {
      final storage = SecureStorage();

      await expectLater(
        () => storage.delete(key: 'ghost_key'),
        returnsNormally,
      );
    });

    test('write internally calls delete before writing', () async {
      // The implementation calls delete(key) before writing the new value to
      // ensure the old entry is removed.  Verify the round-trip is consistent.
      FlutterSecureStorage.setMockInitialValues({'seq_key': 'old'});
      final storage = SecureStorage();

      await storage.write(key: 'seq_key', value: 'new');

      expect(await storage.read(key: 'seq_key'), 'new');
    });
  });

  group('SecureStorage on a single-bundle keystore (#4789)', () {
    late Map<String, String> bundle;
    late MockDomainLogger logging;

    const matrixConfig = '{"homeServer":"https://example.org","user":"@a:b"}';

    setUp(() {
      bundle = <String, String>{};
      FlutterSecureStorage.setMockInitialValues(bundle);
      logging = MockDomainLogger();
    });

    SecureStorage bundled() =>
        SecureStorage(singleBundle: true, logging: logging);

    test('stores a value the bundle JSON would escape encoded, so the bundle '
        'holds no backslash, and reads it back intact', () async {
      const withControl = 'line one\nline two\\ "quoted"';
      await bundled().write(key: 'matrix', value: matrixConfig);
      await bundled().write(key: 'other', value: withControl);

      expect(bundle['matrix'], startsWith(SecureStorage.encodedPrefix));
      expect(jsonEncode(bundle), isNot(contains(r'\')));

      // A fresh instance has an empty cache, so this decodes the store.
      final fresh = bundled();
      expect(await fresh.read(key: 'matrix'), matrixConfig);
      expect(await fresh.read(key: 'other'), withControl);
    });

    test('stores a plain API key unchanged', () async {
      await bundled().write(key: 'api_key', value: 'sk-abc_123.XYZ');

      expect(bundle['api_key'], 'sk-abc_123.XYZ');
    });

    test('rewrites every value an earlier version stored raw on first access, '
        'including keys never read', () async {
      bundle.addAll({
        'github_account:active': matrixConfig,
        'github_account:guest': '{"token":null}',
        'api_key': 'sk-plain',
      });

      expect(await bundled().read(key: 'api_key'), 'sk-plain');

      expect(
        bundle['github_account:guest'],
        startsWith(SecureStorage.encodedPrefix),
      );
      expect(bundle['api_key'], 'sk-plain');
      expect(jsonEncode(bundle), isNot(contains(r'\')));
      final fresh = bundled();
      expect(await fresh.read(key: 'github_account:active'), matrixConfig);
      expect(await fresh.read(key: 'github_account:guest'), '{"token":null}');
    });

    test('encodes a value that itself starts with the prefix, so it reads '
        'back unchanged', () async {
      const lookalike = '${SecureStorage.encodedPrefix}not-base64!';
      await bundled().write(key: 'api_key', value: lookalike);

      expect(bundle['api_key'], isNot(lookalike));
      expect(await bundled().read(key: 'api_key'), lookalike);
    });

    test('writes back the keys a blanked bundle lost before writing the new '
        'one, and logs the repair', () async {
      bundle.addAll({'key_a': 'value_a', 'matrix': matrixConfig});
      final storage = bundled();
      expect(await storage.read(key: 'key_a'), 'value_a');
      expect(await storage.read(key: 'matrix'), matrixConfig);

      // The keyring reloaded and came back blank, so the plugin reads `{}`.
      bundle.clear();
      await storage.write(key: 'github', value: 'ghp_token');

      expect(bundle.keys, unorderedEquals(['key_a', 'matrix', 'github']));
      expect(bundle['key_a'], 'value_a');
      expect(await bundled().read(key: 'matrix'), matrixConfig);
      final logged = verify(
        () => logging.error(
          LogDomain.persistence,
          captureAny(),
          subDomain: 'secureStorage.repair',
          message: captureAny(named: 'message'),
        ),
      ).captured;
      expect(logged[0], isA<StateError>());
      expect(logged[1], 'Restored 2 of 2 cached keys');
    });

    test(
      'repairs before a delete too, without restoring the deleted key',
      () async {
        bundle.addAll({'key_a': 'value_a', 'key_b': 'value_b'});
        final storage = bundled();
        await storage.read(key: 'key_a');
        await storage.read(key: 'key_b');

        bundle.clear();
        await storage.delete(key: 'key_b');

        expect(bundle, {'key_a': 'value_a'});
      },
    );

    test('never restores a key deleted earlier', () async {
      final storage = bundled();
      await storage.write(key: 'key_a', value: 'value_a');
      await storage.write(key: 'gone', value: 'old');
      await storage.delete(key: 'gone');

      bundle.clear();
      await storage.write(key: 'key_b', value: 'value_b');

      expect(bundle, {'key_a': 'value_a', 'key_b': 'value_b'});
    });

    test('leaves an intact bundle alone and logs nothing', () async {
      final storage = bundled();
      await storage.write(key: 'key_a', value: 'value_a');
      await storage.write(key: 'key_b', value: 'value_b');

      expect(bundle, {'key_a': 'value_a', 'key_b': 'value_b'});
      verifyZeroInteractions(logging);
    });

    test('a keystore with one item per key stores values raw and does not '
        'read the bundle back', () async {
      final storage = SecureStorage(singleBundle: false, logging: logging);
      await storage.write(key: 'matrix', value: matrixConfig);
      await storage.write(key: 'key_a', value: 'value_a');
      expect(bundle['matrix'], matrixConfig);

      bundle.clear();
      await storage.write(key: 'key_b', value: 'value_b');

      expect(bundle, {'key_b': 'value_b'});
      verifyZeroInteractions(logging);
    });

    test('a raw value stays raw on a keystore with one item per key', () async {
      bundle['matrix'] = matrixConfig;

      expect(
        await SecureStorage(singleBundle: false).read(key: 'matrix'),
        matrixConfig,
      );
      expect(bundle['matrix'], matrixConfig);
    });

    test('a value starting with the prefix is neither encoded nor decoded on '
        'a keystore with one item per key', () async {
      const lookalike = '${SecureStorage.encodedPrefix}not-base64!';
      bundle['api_key'] = lookalike;
      await SecureStorage(singleBundle: false).write(key: 'other', value: 'x');

      expect(
        await SecureStorage(singleBundle: false).read(key: 'api_key'),
        lookalike,
      );
      expect(bundle['api_key'], lookalike);
    });
  });
}
