import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/ai/util/seed_tombstone_store.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  late SettingsDb settingsDb;
  late SeedTombstoneStore store;

  setUp(() {
    settingsDb = SettingsDb(inMemoryDatabase: true);
    store = SeedTombstoneStore(settingsDb: settingsDb);
  });

  tearDown(() => settingsDb.close());

  test('starts empty', () async {
    expect(await store.deletedIdentities(), isEmpty);
  });

  test('remembers and forgets an identity', () async {
    await store.remember(SeedTombstoneStore.profileKey('profile-1'));
    expect(await store.deletedIdentities(), {'profile:profile-1'});

    await store.forget(SeedTombstoneStore.profileKey('profile-1'));
    expect(await store.deletedIdentities(), isEmpty);
  });

  test('accumulates distinct identities', () async {
    await store.remember(SeedTombstoneStore.profileKey('profile-1'));
    await store.remember(
      SeedTombstoneStore.modelKey(
        inferenceProviderId: 'provider-1',
        providerModelId: 'gpt-5.2',
      ),
    );

    expect(await store.deletedIdentities(), {
      'profile:profile-1',
      'model:provider-1:gpt-5.2',
    });
  });

  test('remembering twice is a no-op', () async {
    await store.remember('profile:p');
    await store.remember('profile:p');

    expect(await store.deletedIdentities(), {'profile:p'});
  });

  // Model identity is provider-scoped: the same provider-native model under
  // two providers is two separate tombstones, matching how backfill decides a
  // known model is already configured.
  test('model identity is scoped to its provider', () async {
    final first = SeedTombstoneStore.modelKey(
      inferenceProviderId: 'provider-1',
      providerModelId: 'gpt-5.2',
    );
    final second = SeedTombstoneStore.modelKey(
      inferenceProviderId: 'provider-2',
      providerModelId: 'gpt-5.2',
    );

    expect(first, isNot(second));

    await store.remember(first);
    expect(await store.deletedIdentities(), contains(first));
    expect(await store.deletedIdentities(), isNot(contains(second)));
  });

  test('persists sorted, so the stored value is stable', () async {
    await store.remember('profile:zeta');
    await store.remember('profile:alpha');

    final raw = await settingsDb.itemByKey(seedTombstonesSettingsKey);
    expect(jsonDecode(raw!), ['profile:alpha', 'profile:zeta']);
  });

  // A corrupt or foreign value must not wedge seeding permanently.
  test('unreadable stored values degrade to empty', () async {
    await settingsDb.saveSettingsItem(seedTombstonesSettingsKey, 'not json');
    expect(await store.deletedIdentities(), isEmpty);

    await settingsDb.saveSettingsItem(seedTombstonesSettingsKey, '{"a": 1}');
    expect(await store.deletedIdentities(), isEmpty);
  });

  test('ignores non-string entries in the stored list', () async {
    await settingsDb.saveSettingsItem(
      seedTombstonesSettingsKey,
      jsonEncode(['profile:p', 42, null]),
    );

    expect(await store.deletedIdentities(), {'profile:p'});
  });

  // The repository builds a fresh store per deletion, and a synced delete can
  // land while a user delete is in flight. Without serialization both read the
  // same prior set and the second write drops the first identity — reviving
  // that seed.
  test(
    'concurrent writes through separate stores keep both identities',
    () async {
      final first = SeedTombstoneStore(settingsDb: settingsDb);
      final second = SeedTombstoneStore(settingsDb: settingsDb);

      await Future.wait([
        first.remember('profile:one'),
        second.remember('model:provider-1:two'),
      ]);

      expect(await store.deletedIdentities(), {
        'profile:one',
        'model:provider-1:two',
      });
    },
  );

  test('a burst of writes through one store keeps every identity', () async {
    await Future.wait([
      for (var i = 0; i < 8; i++) store.remember('profile:p$i'),
    ]);

    expect(await store.deletedIdentities(), hasLength(8));
  });

  // Mutations share one queue, so a failed write must not wedge everything
  // queued behind it.
  test('a failing mutation does not block later writes', () async {
    final failing = MockSettingsDb();
    when(() => failing.itemByKey(any())).thenAnswer((_) async => null);
    when(
      () => failing.saveSettingsItem(any(), any()),
    ).thenThrow(StateError('settings db down'));
    final broken = SeedTombstoneStore(settingsDb: failing);

    await expectLater(broken.remember('profile:doomed'), throwsStateError);
    await store.remember('profile:after');

    expect(await store.deletedIdentities(), {'profile:after'});
  });

  test('forgetting an unknown identity leaves the set alone', () async {
    await store.remember('profile:p');
    await store.forget('profile:other');

    expect(await store.deletedIdentities(), {'profile:p'});
  });
}
