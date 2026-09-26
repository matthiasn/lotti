import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/tasks/repository/checklist_membership_intents.dart';
import 'package:lotti/get_it.dart';

import '../../../helpers/test_get_it.dart';

void main() {
  const prefix = ChecklistMembershipIntents.keyPrefix;

  const every = <MembershipIntent>[
    ListItemsIntent(checklistId: 'c1', itemIds: ['i1', 'i2']),
    MoveItemIntent(itemId: 'i1', fromId: 'c1', toId: 'c2'),
    DeleteItemIntent(itemId: 'i1', checklistId: 'c1'),
    ListChecklistIntent(checklistId: 'c1', taskId: 't1'),
    DeleteChecklistIntent(checklistId: 'c1', taskId: 't1'),
  ];

  group('MembershipIntent', () {
    test('every kind reads back as what it wrote, through a JSON string', () {
      for (final intent in every) {
        final read = MembershipIntent.fromJson(
          jsonDecode(jsonEncode(intent.toJson())) as Map<String, dynamic>,
        );
        expect(read.runtimeType, intent.runtimeType, reason: '$intent');
        expect(read!.toJson(), intent.toJson());
      }
    });

    test('names each kind by its own op', () {
      expect(
        [for (final intent in every) intent.toJson()['op']],
        [
          'listItems',
          'moveItem',
          'deleteItem',
          'listChecklist',
          'deleteChecklist',
        ],
      );
    });

    test('an op this build does not know reads as null', () {
      expect(
        MembershipIntent.fromJson({'op': 'renameItem', 'itemId': 'i1'}),
        isNull,
      );
      expect(MembershipIntent.fromJson(const {}), isNull);
    });
  });

  group('ChecklistMembershipIntents', () {
    late SettingsDb settingsDb;
    late ChecklistMembershipIntents intents;

    setUp(() {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      settingsDb = SettingsDb(inMemoryDatabase: true);
      intents = ChecklistMembershipIntents(settingsDb: settingsDb);
    });

    tearDown(() => settingsDb.close());

    test('record stores the intent under its own prefixed key', () async {
      const intent = MoveItemIntent(itemId: 'i1', fromId: 'c1', toId: 'c2');

      final first = await intents.record(intent);
      final second = await intents.record(intent);

      expect(first, startsWith(prefix));
      expect(second, startsWith(prefix));
      expect(first, isNot(second));
      expect(
        jsonDecode((await settingsDb.itemByKey(first))!),
        intent.toJson(),
      );
    });

    test('pending returns every recorded intent by key, and no other '
        'setting', () async {
      await settingsDb.saveSettingsItem('unrelated', '{"op":"moveItem"}');
      final keys = [for (final intent in every) await intents.record(intent)];

      final pending = await intents.pending();

      expect(pending.keys.toSet(), keys.toSet());
      for (final (index, key) in keys.indexed) {
        expect(pending[key]!.toJson(), every[index].toJson());
      }
    });

    test('pending returns an unreadable intent as null, so it can be '
        'dropped', () async {
      await settingsDb.saveSettingsItem('${prefix}garbled', 'not json');
      await settingsDb.saveSettingsItem('${prefix}future', '{"op":"later"}');
      await settingsDb.saveSettingsItem('${prefix}wrong', '{"op":"moveItem"}');

      expect(await intents.pending(), {
        '${prefix}garbled': null,
        '${prefix}future': null,
        '${prefix}wrong': null,
      });
    });

    test('clear removes the intent recorded under the key', () async {
      final kept = await intents.record(every.first);
      final cleared = await intents.record(every.last);

      await intents.clear(cleared);

      expect((await intents.pending()).keys, [kept]);
    });

    test(
      'run records the intent before the operation and clears it once done '
      'accepts the result',
      () async {
        Map<String, MembershipIntent?>? during;
        int? judged;

        final result = await intents.run(
          every[1],
          () async {
            during = await intents.pending();
            return 42;
          },
          done: (result) {
            judged = result;
            return true;
          },
        );

        expect(result, 42);
        expect(judged, 42);
        expect(during!.values.single!.toJson(), every[1].toJson());
        expect(await intents.pending(), isEmpty);
      },
    );

    test('run keeps the intent when done rejects the result — a write that '
        'was refused or failed is finished at the next start', () async {
      final result = await intents.run<int?>(
        every[0],
        () async => null,
        done: (result) => result != null,
      );

      expect(result, isNull);
      expect(
        (await intents.pending()).values.single!.toJson(),
        every[0].toJson(),
      );
    });

    test(
      'an operation that throws leaves its intent for the next start',
      () async {
        final error = StateError('the app died');

        await expectLater(
          intents.run<void>(
            every[2],
            () async => throw error,
            done: (_) => true,
          ),
          throwsA(same(error)),
        );

        expect(
          (await intents.pending()).values.single!.toJson(),
          every[2].toJson(),
        );
      },
    );

    test('without a settings database it uses the registered one', () async {
      await setUpTestGetIt(
        additionalSetup: () {
          getIt
            ..unregister<SettingsDb>()
            ..registerSingleton<SettingsDb>(settingsDb);
        },
      );
      addTearDown(tearDownTestGetIt);

      final key = await ChecklistMembershipIntents().record(every.first);

      expect((await intents.pending()).keys, [key]);
    });
  });
}
