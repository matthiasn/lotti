import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/logic/repositories/category_move_intents.dart';

void main() {
  late SettingsDb settingsDb;
  late CategoryMoveIntents intents;

  setUp(() {
    settingsDb = SettingsDb(inMemoryDatabase: true);
    intents = CategoryMoveIntents(settingsDb: settingsDb);
  });
  tearDown(() => settingsDb.close());

  test('a recorded move is pending until cleared', () async {
    await intents.record('task-1', 'cat_to');

    expect(await intents.pending(), {'task-1': (categoryId: 'cat_to')});
    await intents.clear('task-1');
    expect(await intents.pending(), isEmpty);
  });

  test('a move that clears the category reads back as null', () async {
    await intents.record('task-1', null);

    expect(await intents.pending(), {'task-1': (categoryId: null)});
  });

  test('a later move of the same entry replaces the record', () async {
    await intents.record('task-1', 'cat_a');
    await intents.record('task-1', 'cat_b');

    expect(await intents.pending(), {'task-1': (categoryId: 'cat_b')});
  });

  test('a record this build cannot read is pending as null', () async {
    for (final (id, value) in [
      ('not-json', 'not json'),
      ('no-key', '{}'),
      ('wrong-type', '{"categoryId": 3}'),
    ]) {
      await settingsDb.saveSettingsItem(
        '${CategoryMoveIntents.keyPrefix}$id',
        value,
      );
    }

    final pending = await intents.pending();

    expect(pending.keys, unorderedEquals(['not-json', 'no-key', 'wrong-type']));
    expect(pending.values, everyElement(isNull));
  });
}
