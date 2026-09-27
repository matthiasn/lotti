import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/database/ai_api_key_storage.dart';
import 'package:lotti/features/ai/database/ai_config_db.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:sqlite3/sqlite3.dart';

/// Versions of AI configurations are stamped, and a receiver keeps only the
/// newest (ADR 0094).
void main() {
  final created = DateTime(2026, 9, 27, 9);
  final now = DateTime(2026, 9, 27, 12);
  final nowMs = now.millisecondsSinceEpoch;

  AiConfig profile(String name) => AiConfig.inferenceProfile(
    id: 'profile-1',
    name: name,
    createdAt: created,
    thinkingModelId: 'model-1',
  );

  AiConfig provider(String apiKey) => AiConfig.inferenceProvider(
    id: 'provider-1',
    baseUrl: 'https://example.com',
    apiKey: apiKey,
    name: 'Provider',
    createdAt: created,
    inferenceProviderType: InferenceProviderType.genericOpenAi,
  );

  late AiApiKeyStorage storage;
  late AiConfigDb db;

  setUp(() {
    storage = AiApiKeyStorage.inMemory();
    db = AiConfigDb(inMemoryDatabase: true, apiKeyStorage: storage);
  });

  tearDown(() => db.close());

  Future<T> atNow<T>(Future<T> Function() body) =>
      withClock(Clock.fixed(now), body);

  group('local writes', () {
    test('stamp the current time, then one past it while the clock stands '
        'still', () async {
      final first = await atNow(() => db.saveConfig(profile('a')));
      final second = await atNow(() => db.saveConfig(profile('b')));
      final deletion = await atNow(() => db.deleteConfig('profile-1'));

      expect([first, second, deletion], [nowMs, nowMs + 1, nowMs + 2]);
      expect(await db.versionStamp('profile-1'), nowMs + 2);
      expect(await db.getConfigById('profile-1'), isNull);
    });

    test(
      'outrank a received version stamped ahead of the local clock',
      () async {
        await db.applyConfigVersion(profile('peer'), stamp: nowMs + 500);

        final stamp = await atNow(() => db.saveConfig(profile('local')));

        expect(stamp, nowMs + 501);
      },
    );
  });

  group('applyConfigVersion', () {
    test('drops a version that lands after a newer one', () async {
      expect(await db.applyConfigVersion(profile('v2'), stamp: 20), isTrue);

      // The timed-out send of v1 lands last.
      expect(await db.applyConfigVersion(profile('v1'), stamp: 10), isFalse);

      expect((await db.getConfigById('profile-1'))!.name, 'v2');
      expect(await db.versionStamp('profile-1'), 20);
    });

    test('applies a newer version over an older one', () async {
      await db.applyConfigVersion(profile('v1'), stamp: 10);

      expect(await db.applyConfigVersion(profile('v2'), stamp: 20), isTrue);

      expect((await db.getConfigById('profile-1'))!.name, 'v2');
      expect(await db.versionStamp('profile-1'), 20);
    });

    test('treats an identical copy as a no-op', () async {
      await db.applyConfigVersion(profile('v1'), stamp: 10);

      expect(await db.applyConfigVersion(profile('v1'), stamp: 10), isFalse);
    });

    test(
      'orders two configs with one stamp the same way on every device',
      () async {
        final other = AiConfigDb(
          inMemoryDatabase: true,
          apiKeyStorage: AiApiKeyStorage.inMemory(),
        );
        addTearDown(other.close);

        // Each device holds one, then receives the other.
        await db.applyConfigVersion(profile('alpha'), stamp: 10);
        await other.applyConfigVersion(profile('beta'), stamp: 10);
        final dbApplied = await db.applyConfigVersion(
          profile('beta'),
          stamp: 10,
        );
        final otherApplied = await other.applyConfigVersion(
          profile('alpha'),
          stamp: 10,
        );

        expect({dbApplied, otherApplied}, {true, false});
        expect(
          (await db.getConfigById('profile-1'))!.name,
          (await other.getConfigById('profile-1'))!.name,
        );
      },
    );

    test('writes no credential for a dropped provider version', () async {
      await db.applyConfigVersion(provider('new-key'), stamp: 20);

      await db.applyConfigVersion(provider('old-key'), stamp: 10);

      final held = (await db.getConfigById('provider-1'))!;
      expect((held as AiConfigInferenceProvider).apiKey, 'new-key');
    });
  });

  group('deletions', () {
    test(
      'a copy sent before a deletion does not bring the config back',
      () async {
        await db.applyConfigVersion(profile('v1'), stamp: 10);
        expect(await db.applyConfigDeletion('profile-1', stamp: 20), isTrue);

        expect(await db.applyConfigVersion(profile('v1'), stamp: 10), isFalse);

        expect(await db.getConfigById('profile-1'), isNull);
      },
    );

    test('a deletion wins a tie with a config', () async {
      await db.applyConfigDeletion('profile-1', stamp: 10);

      expect(await db.applyConfigVersion(profile('v1'), stamp: 10), isFalse);
      expect(await db.getConfigById('profile-1'), isNull);

      await db.applyConfigVersion(profile('v2'), stamp: 11);
      expect(await db.applyConfigDeletion('profile-1', stamp: 11), isTrue);
      expect(await db.getConfigById('profile-1'), isNull);
    });

    test('a deletion older than the held version is dropped', () async {
      await db.applyConfigVersion(profile('recreated'), stamp: 30);

      expect(await db.applyConfigDeletion('profile-1', stamp: 20), isFalse);

      expect((await db.getConfigById('profile-1'))!.name, 'recreated');
    });

    test('a deletion removes the provider credential', () async {
      await db.applyConfigVersion(provider('key'), stamp: 10);

      await db.applyConfigDeletion('provider-1', stamp: 20);

      expect(
        await storage.read(apiKeyStorageKeyFor('provider-1')),
        isNull,
      );
    });

    test('forgetConfig lets the same version apply again', () async {
      await db.applyConfigVersion(profile('v1'), stamp: 10);

      await db.forgetConfig('profile-1');

      expect(await db.versionStamp('profile-1'), isNull);
      expect(await db.applyConfigVersion(profile('v1'), stamp: 10), isTrue);
    });
  });

  test(
    'migrating from schema 1 stamps every row with its last write',
    () async {
      final directory = Directory.systemTemp.createTempSync('ai_config_v1_');
      addTearDown(() => directory.deleteSync(recursive: true));
      sqlite3.open('${directory.path}/$aiConfigDbFileName')
        ..execute('''
        CREATE TABLE ai_configs (
          id TEXT NOT NULL PRIMARY KEY,
          type TEXT NOT NULL,
          name TEXT NOT NULL,
          serialized TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER
        );
        INSERT INTO ai_configs VALUES ('edited', 'prompt', 'e', '{}', 100, 250);
        INSERT INTO ai_configs VALUES ('fresh', 'prompt', 'f', '{}', 300, NULL);
        PRAGMA user_version = 1;
      ''')
        ..close();

      final migrated = AiConfigDb(
        apiKeyStorage: AiApiKeyStorage.inMemory(),
        documentsDirectoryProvider: () async => directory,
        tempDirectoryProvider: () async => directory,
      );
      addTearDown(migrated.close);

      expect(await migrated.versionStamp('edited'), 250000);
      expect(await migrated.versionStamp('fresh'), 300000);
      expect(migrated.schemaVersion, 2);
    },
  );
}
