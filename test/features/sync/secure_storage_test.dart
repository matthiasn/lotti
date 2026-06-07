import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock the PackageInfo platform channel so `PackageInfo.fromPlatform()` works
  // in tests without a real platform.
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/package_info'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getAll') {
              return <String, dynamic>{
                'appName': 'Lotti',
                'packageName': 'com.example.lotti.test',
                'version': '1.0.0',
                'buildNumber': '1',
              };
            }
            return null;
          },
        );
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/package_info'),
          null,
        );
  });

  // Each test starts with a fresh in-memory secure storage backend.
  setUp(() {
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
}
