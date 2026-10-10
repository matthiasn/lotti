import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/ai/repository/ai_config_sync_ledger.dart';

void main() {
  late SettingsDb settingsDb;
  late AiConfigSyncLedger ledger;

  setUp(() {
    settingsDb = SettingsDb(inMemoryDatabase: true);
    ledger = AiConfigSyncLedger(settingsDb);
  });

  tearDown(() => settingsDb.close());

  test('starts empty and owes ids until they are settled', () async {
    expect(await ledger.load(), isEmpty);

    await ledger.owe('prompt-1');
    await ledger.owe('model-2');
    await ledger.owe('prompt-1');
    expect(await ledger.load(), {'prompt-1', 'model-2'});

    await ledger.settle('prompt-1');
    expect(await ledger.load(), {'model-2'});

    await ledger.settle('model-2');
    expect(await ledger.load(), isEmpty);
  });

  test('persists the owed ids for a repository built later', () async {
    await ledger.owe('provider-1');

    expect(await AiConfigSyncLedger(settingsDb).load(), {'provider-1'});
    expect(
      await settingsDb.itemByKey(AiConfigSyncLedger.storageKey),
      '["provider-1"]',
    );
  });

  test('settling an id it does not owe writes nothing', () async {
    await ledger.settle('never-owed');

    expect(await settingsDb.itemByKey(AiConfigSyncLedger.storageKey), isNull);
  });

  test('reads an unreadable or ill-shaped value as owing nothing', () async {
    await settingsDb.saveSettingsItem(AiConfigSyncLedger.storageKey, '{not');
    expect(await ledger.load(), isEmpty);

    await settingsDb.saveSettingsItem(
      AiConfigSyncLedger.storageKey,
      '{"pending": ["x"]}',
    );
    expect(await ledger.load(), isEmpty);

    await settingsDb.saveSettingsItem(
      AiConfigSyncLedger.storageKey,
      '["kept", 7, null]',
    );
    expect(await ledger.load(), {'kept'});
  });
}
