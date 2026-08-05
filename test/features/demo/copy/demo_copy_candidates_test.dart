import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/demo/copy/demo_copy_candidates.dart';
import 'package:lotti/features/demo/seed/demo_seed_manifest.dart';
import 'package:lotti/features/profiles/service/world_handle.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';

import '../../../helpers/entity_factories.dart';
import '../../../mocks/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory demoRoot;
  late WorldHandle world;

  final fixed = DateTime(2026, 8, 4, 12);

  setUp(() {
    demoRoot = Directory.systemTemp.createTempSync('lotti_candidates_');
    getIt.registerSingleton<EntitiesCacheService>(MockEntitiesCacheService());
    // Any fallback to the OS documents path is a bug in the loader's inputs.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            throw PlatformException(code: 'forbidden');
          },
        );
    world = WorldHandle.open(demoRoot);
  });

  tearDown(() async {
    await world.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await getIt.reset();
    if (demoRoot.existsSync()) {
      await demoRoot.delete(recursive: true);
    }
  });

  JournalEntry entry(String id, String text) => JournalEntry(
    meta: TestMetadataFactory.create(id: id, createdAt: fixed),
    entryText: EntryText(plainText: text),
  );

  EntryLink link(String id, String fromId, String toId) => EntryLink.basic(
    id: id,
    fromId: fromId,
    toId: toId,
    createdAt: fixed,
    updatedAt: fixed,
    vectorClock: null,
  );

  test('offers demo-created tasks and unlinked entries; excludes seeded '
      'fixtures, linked entries and checklist internals', () async {
    // Seeded fixture content, listed in the manifest.
    final seededTask = TestTaskFactory.create(
      id: 'seeded-task',
      title: 'Inspect orbital habitat',
    );
    // Demo-created content.
    final userTask = TestTaskFactory.create(
      id: 'user-task',
      title: 'My own mission',
      checklistIds: ['user-checklist'],
    );
    final userChecklist = Checklist(
      meta: TestMetadataFactory.create(id: 'user-checklist', createdAt: fixed),
      data: const ChecklistData(
        title: 'Steps',
        linkedChecklistItems: ['user-item'],
        linkedTasks: ['user-task'],
      ),
    );
    final userItem = ChecklistItem(
      meta: TestMetadataFactory.create(id: 'user-item', createdAt: fixed),
      data: TestChecklistItemFactory.create(
        title: 'Step one',
        linkedChecklists: ['user-checklist'],
      ),
    );
    final standalone = entry('standalone-entry', 'A loose note');
    final attachedToUserTask = entry('attached-entry', 'Attached note');
    final attachedToSeededTask = entry('seeded-attached', 'On a fixture');

    for (final entity in [
      seededTask,
      userTask,
      userChecklist,
      userItem,
      standalone,
      attachedToUserTask,
      attachedToSeededTask,
    ]) {
      await world.writeJournalEntity(entity);
    }
    await world.writeEntryLink(
      link('l1', 'user-task', 'attached-entry'),
    );
    await world.writeEntryLink(
      link('l2', 'seeded-task', 'seeded-attached'),
    );

    await DemoSeedManifest(
      seedVersion: demoSeedVersion,
      seededAt: fixed.toUtc(),
      localeTag: 'en',
      seededJournalIds: const ['seeded-task'],
      seededDefinitionIds: const [],
      seededAiConfigIds: const [],
    ).write(demoRoot);

    final candidates = await loadDemoCopyCandidates(
      journalDb: world.journalDb,
      demoRoot: demoRoot,
    );

    expect(
      candidates.tasks.map((task) => task.meta.id),
      ['user-task'],
      reason: 'seeded task excluded; checklists never surface as roots',
    );
    expect(
      candidates.entries.map((e) => e.meta.id),
      ['standalone-entry'],
      reason:
          'entries with an inbound link travel with their parent — '
          'including entries attached to SEEDED tasks (documented v1 scope)',
    );
    expect(candidates.isNotEmpty, isTrue);
    expect(candidates.length, 2);
  });

  test('deleted entities are never offered', () async {
    final deleted = TestTaskFactory.create(id: 'deleted-task', title: 'Gone');
    await world.writeJournalEntity(
      deleted.copyWith(meta: deleted.meta.copyWith(deletedAt: fixed)),
    );

    final candidates = await loadDemoCopyCandidates(
      journalDb: world.journalDb,
      demoRoot: demoRoot,
    );
    expect(candidates.isEmpty, isTrue);
  });

  test('a missing manifest excludes nothing (over-offering beats losing '
      'user work)', () async {
    await world.writeJournalEntity(
      TestTaskFactory.create(id: 'task-a', title: 'A'),
    );

    final candidates = await loadDemoCopyCandidates(
      journalDb: world.journalDb,
      demoRoot: demoRoot,
    );
    expect(candidates.tasks.map((task) => task.meta.id), ['task-a']);
  });
}
