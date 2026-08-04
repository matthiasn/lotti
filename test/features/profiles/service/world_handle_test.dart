import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/profiles/service/world_handle.dart';
import 'package:lotti/features/sync/utils.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:path/path.dart' as p;

import '../../../helpers/entity_factories.dart';
import '../../../mocks/mocks.dart';

/// Recursive snapshot of a directory: relative path -> file length.
Map<String, int> snapshotTree(Directory dir) {
  final result = <String, int>{};
  if (!dir.existsSync()) return result;
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is File) {
      result[p.relative(entity.path, from: dir.path)] = entity.lengthSync();
    }
  }
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory worldRoot;
  late Directory canaryRealRoot;

  setUp(() {
    worldRoot = Directory.systemTemp.createTempSync('lotti_world_');
    canaryRealRoot = Directory.systemTemp.createTempSync('lotti_canary_');
    // Plant canary content so "untouched" is a meaningful assertion.
    File(p.join(canaryRealRoot.path, 'db.sqlite')).writeAsStringSync('real');
    Directory(
      p.join(canaryRealRoot.path, 'text_entries'),
    ).createSync(recursive: true);

    // The ACTIVE generation points at the canary; any WorldHandle write that
    // falls back to the active root or the OS path is an isolation breach.
    getIt
      ..registerSingleton<Directory>(canaryRealRoot)
      ..registerSingleton<EntitiesCacheService>(MockEntitiesCacheService());
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            throw PlatformException(code: 'forbidden');
          },
        );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await getIt.reset();
    for (final dir in [worldRoot, canaryRealRoot]) {
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
      }
    }
  });

  group('WorldHandle', () {
    test('writes land exclusively under the world root; the active world '
        'stays byte-identical', () async {
      final before = snapshotTree(canaryRealRoot);

      final world = WorldHandle.open(worldRoot);
      final task = TestTaskFactory.create(
        id: 'seed-task-1',
        title: 'Inspect orbital penguin habitat',
        plainText: 'demo seed',
      );
      await world.writeJournalEntity(task);
      await world.writeEntityDefinition(
        CategoryDefinition(
          id: 'seed-category',
          createdAt: DateTime(2026, 7, 17),
          updatedAt: DateTime(2026, 7, 17),
          name: 'Penguin Operations',
          vectorClock: null,
          private: false,
          active: true,
        ),
      );
      await world.writeEntryLink(
        EntryLink.basic(
          id: 'seed-link-1',
          fromId: 'seed-task-1',
          toId: 'seed-task-1',
          createdAt: DateTime(2026, 7, 17),
          updatedAt: DateTime(2026, 7, 17),
          vectorClock: null,
        ),
      );
      await world.writeSetting('demo_seed_version', '1');
      await world.close();

      // World content is real and readable back.
      final reopened = WorldHandle.open(worldRoot);
      final persisted = await reopened.journalDb.journalEntityById(
        'seed-task-1',
      );
      expect(persisted, isNotNull);
      expect(
        persisted!.maybeMap(
          task: (Task task) => task.data.title,
          orElse: () => '',
        ),
        'Inspect orbital penguin habitat',
      );
      expect(
        await reopened.settingsDb.itemByKey('demo_seed_version'),
        '1',
      );
      // The world's own settings file exists → its future host ID lives
      // here, not in the real world's settings.sqlite.
      expect(
        File(p.join(worldRoot.path, 'settings.sqlite')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(worldRoot.path, 'db.sqlite')).existsSync(),
        isTrue,
      );
      // JSON sidecar landed under the world root.
      final sidecars = Directory(
        p.join(worldRoot.path, 'tasks'),
      ).listSync(recursive: true).whereType<File>();
      expect(sidecars, isNotEmpty);
      await reopened.close();

      // Isolation: the canary tree is byte-identical.
      expect(snapshotTree(canaryRealRoot), before);
      // And the world root holds no marker of the real world's host key.
      expect(
        await WorldHandle.open(worldRoot).settingsDb.itemByKey(hostKey),
        isNull,
      );
    });
  });
}
