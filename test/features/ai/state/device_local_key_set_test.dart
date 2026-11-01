import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/state/device_local_key_set.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

const _key = 'TEST_KEYS';

class _Keys extends DeviceLocalKeySet {
  @override
  String get settingsKey => _key;
}

final _keysProvider = AsyncNotifierProvider<_Keys, Set<String>>(_Keys.new);

void main() {
  late MockSettingsDb settingsDb;
  late ProviderContainer container;

  setUp(() {
    settingsDb = MockSettingsDb();
    when(
      () => settingsDb.saveSettingsItem(any(), any()),
    ).thenAnswer((_) async => 1);
    container = ProviderContainer(
      overrides: [settingsDbProvider.overrideWithValue(settingsDb)],
    );
    addTearDown(container.dispose);
  });

  void stored(String? raw) =>
      when(() => settingsDb.itemByKey(_key)).thenAnswer((_) async => raw);

  test('reads the stored keys', () async {
    stored(jsonEncode(['b', 'a', 7]));

    expect(await container.read(_keysProvider.future), {'a', 'b'});
  });

  test('reads nothing stored, malformed JSON or a non-list as empty', () async {
    for (final raw in [
      null,
      '{not json',
      jsonEncode({'a': 1}),
    ]) {
      stored(raw);
      container.invalidate(_keysProvider);

      expect(await container.read(_keysProvider.future), isEmpty, reason: raw);
    }
  });

  test('adds a key: publishes it, then stores the set sorted', () async {
    stored(jsonEncode(['m']));
    await container.read(_keysProvider.future);

    await container.read(_keysProvider.notifier).addKey('a');

    expect(container.read(_keysProvider).value, {'a', 'm'});
    verify(
      () => settingsDb.saveSettingsItem(_key, jsonEncode(['a', 'm'])),
    ).called(1);
  });

  test('adding a key it holds writes nothing', () async {
    stored(jsonEncode(['a']));

    await container.read(_keysProvider.notifier).addKey('a');

    verifyNever(() => settingsDb.saveSettingsItem(any(), any()));
  });
}
