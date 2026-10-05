import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/agents/service/change_dispatch_intents.dart';

void main() {
  late SettingsDb settingsDb;

  ChangeDispatchIntents intentsOf(String scope) =>
      ChangeDispatchIntents(scope: scope, settingsDb: settingsDb);

  setUp(() => settingsDb = SettingsDb(inMemoryDatabase: true));
  tearDown(() => settingsDb.close());

  test('a recorded dispatch is pending until cleared', () async {
    final intents = intentsOf('task');

    final key = await intents.record((changeSetId: 'set-1', itemIndex: 3));

    expect(await intents.pending(), {
      key: (changeSetId: 'set-1', itemIndex: 3),
    });
    await intents.clear(key);
    expect(await intents.pending(), isEmpty);
  });

  test('recording the same item again is the same record', () async {
    final intents = intentsOf('task');

    final first = await intents.record((changeSetId: 'set-1', itemIndex: 0));
    final second = await intents.record((changeSetId: 'set-1', itemIndex: 0));

    expect(second, first);
    expect(await intents.pending(), hasLength(1));
  });

  test('a set id containing the separator reads back whole', () async {
    final intents = intentsOf('task');
    const dispatch = (changeSetId: 'agent-1:run:7', itemIndex: 12);

    final key = await intents.record(dispatch);

    expect(await intents.pending(), {key: dispatch});
  });

  test("each service sees only its own scope's dispatches", () async {
    final task = intentsOf('task');
    final project = intentsOf('project');

    final taskKey = await task.record((changeSetId: 'set-1', itemIndex: 0));
    final projectKey = await project.record((
      changeSetId: 'set-1',
      itemIndex: 0,
    ));

    expect((await task.pending()).keys, [taskKey]);
    expect((await project.pending()).keys, [projectKey]);
    expect(taskKey, isNot(projectKey));
  });

  test('a key this build cannot read is pending as null, for the caller '
      'to drop', () async {
    final intents = intentsOf('task');
    const prefix = '${ChangeDispatchIntents.keyPrefix}task:';
    for (final rest in ['no-separator', ':set-1', 'x:set-1', '4:']) {
      await settingsDb.saveSettingsItem('$prefix$rest', '');
    }

    final pending = await intents.pending();

    expect(pending, hasLength(4));
    expect(pending.values, everyElement(isNull));
  });
}
