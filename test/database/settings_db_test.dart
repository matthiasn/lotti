import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/settings_db.dart';

void main() {
  late SettingsDb db;

  setUp(() {
    // Avoid drift warning when optimizer reuses isolates
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = SettingsDb(inMemoryDatabase: true);
  });

  tearDown(() async {
    await db.close();
  });

  test('removeSettingsItem removes existing entries', () async {
    await db.saveSettingsItem('test_key', 'test_value');
    expect(await db.itemByKey('test_key'), 'test_value');

    await db.removeSettingsItem('test_key');

    expect(await db.itemByKey('test_key'), isNull);
    final observed = await db.watchSettingsItemByKey('test_key').first;
    expect(observed, isEmpty);
  });

  test('removeSettingsItem handles non-existent key gracefully', () async {
    await expectLater(db.removeSettingsItem('missing_key'), completes);
  });

  test('itemByKey returns null when no value stored', () async {
    final value = await db.itemByKey('absent_key');
    expect(value, isNull);
  });

  test('full lifecycle: save, observe, remove, verify empty', () async {
    await db.saveSettingsItem('lifecycle', 'initial');

    final updates = db.watchSettingsItemByKey('lifecycle');
    final expectation = expectLater(
      updates,
      emitsInOrder([
        isA<List<SettingsItem>>()
            .having((items) => items.single.value, 'value', 'initial'),
        isEmpty,
      ]),
    );
    await db.removeSettingsItem('lifecycle');
    await expectation;
    expect(await db.itemByKey('lifecycle'), isNull);
  });
}
