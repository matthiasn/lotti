import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/demo/copy/demo_data_copier.dart';
import 'package:lotti/features/demo/seed/demo_seed_manifest.dart';
import 'package:lotti/features/profiles/service/world_handle.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import '../../../helpers/entity_factories.dart';
import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerAllFallbackValues);

  late Directory sourceRoot;
  late Directory targetRoot;
  late Directory stagingDir;
  late WorldHandle source;

  final created = DateTime(2026, 7, 20, 9, 30);

  setUp(() {
    sourceRoot = Directory.systemTemp.createTempSync('lotti_copier_src_');
    targetRoot = Directory.systemTemp.createTempSync('lotti_copier_dst_');
    stagingDir = Directory.systemTemp.createTempSync('lotti_copier_stage_');
    getIt.registerSingleton<EntitiesCacheService>(MockEntitiesCacheService());
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            throw PlatformException(code: 'forbidden');
          },
        );
    source = WorldHandle.open(sourceRoot);
  });

  tearDown(() async {
    await source.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await getIt.reset();
    for (final dir in [sourceRoot, targetRoot, stagingDir]) {
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
      }
    }
  });

  /// Deterministic id factory: new-1, new-2, ...
  String Function() sequentialIds() {
    var counter = 0;
    return () => 'new-${++counter}';
  }

  Future<void> seedSourceWorld() async {
    await source.writeEntityDefinition(
      CategoryDefinition(
        id: 'cat-1',
        createdAt: created,
        updatedAt: created,
        name: 'Penguin Ops',
        vectorClock: null,
        private: false,
        active: true,
      ),
    );

    final task = TestTaskFactory.create(
      id: 'task-1',
      title: 'My mission',
      createdAt: created,
      dateFrom: created,
      dateTo: created,
      categoryId: 'cat-1',
      checklistIds: ['check-1'],
    );
    final checklist = Checklist(
      meta: TestMetadataFactory.create(id: 'check-1', createdAt: created),
      data: const ChecklistData(
        title: 'Steps',
        linkedChecklistItems: ['item-1'],
        linkedTasks: ['task-1'],
      ),
    );
    final item = ChecklistItem(
      meta: TestMetadataFactory.create(id: 'item-1', createdAt: created),
      data: TestChecklistItemFactory.create(
        title: 'Step one',
        linkedChecklists: ['check-1'],
        id: 'item-1',
      ),
    );
    final note = JournalEntry(
      meta: TestMetadataFactory.create(id: 'note-1', createdAt: created),
      entryText: const EntryText(plainText: 'Attached note'),
    );
    final image = JournalImage(
      meta: TestMetadataFactory.create(id: 'img-1', createdAt: created),
      data: ImageData(
        capturedAt: created,
        imageId: 'image-id-1',
        imageFile: 'img-1.jpg',
        imageDirectory: '/images/2026-07-20/',
      ),
    );
    File(p.join(sourceRoot.path, 'images', '2026-07-20', 'img-1.jpg'))
      ..createSync(recursive: true)
      ..writeAsBytesSync([1, 2, 3, 4]);

    for (final entity in [task, checklist, item, note, image]) {
      await source.writeJournalEntity(entity);
    }
    await source.writeEntryLink(
      EntryLink.basic(
        id: 'link-note',
        fromId: 'task-1',
        toId: 'note-1',
        createdAt: created,
        updatedAt: created,
        vectorClock: null,
      ),
    );
    await source.writeEntryLink(
      EntryLink.basic(
        id: 'link-img',
        fromId: 'task-1',
        toId: 'img-1',
        createdAt: created,
        updatedAt: created,
        vectorClock: null,
      ),
    );
  }

  group('prepare', () {
    test('builds a fully remapped closure: fresh ids, preserved dates, '
        'remapped checklist wiring and links, staged media', () async {
      await seedSourceWorld();
      final copier = DemoDataCopier(newId: sequentialIds());

      final plan = await copier.prepare(
        selectedIds: {'task-1'},
        sourceDb: source.journalDb,
        sourceRoot: sourceRoot,
        stagingDir: stagingDir,
      );

      // The whole closure travelled: task + checklist + item + note + image.
      expect(plan.entities, hasLength(5));
      final byOldTitleOrType = {
        for (final entity in plan.entities)
          entity.runtimeType.toString(): entity,
      };
      final newIds = plan.entities.map((e) => e.meta.id).toSet();
      expect(newIds, hasLength(5));
      expect(
        newIds.intersection({'task-1', 'check-1', 'item-1', 'note-1', 'img-1'}),
        isEmpty,
        reason: 'every member gets a fresh id',
      );

      final task = plan.entities.whereType<Task>().single;
      final checklist = plan.entities.whereType<Checklist>().single;
      final item = plan.entities.whereType<ChecklistItem>().single;
      final image = plan.entities.whereType<JournalImage>().single;

      // Checklist wiring is remapped consistently.
      expect(task.data.checklistIds, [checklist.meta.id]);
      expect(checklist.data.linkedChecklistItems, [item.meta.id]);
      expect(checklist.data.linkedTasks, [task.meta.id]);
      expect(item.data.linkedChecklists, [checklist.meta.id]);
      expect(item.data.id, item.meta.id, reason: 'inner data id remapped too');

      // Dates preserved, vector clock cleared, category reference kept.
      for (final entity in plan.entities) {
        expect(entity.meta.createdAt, created, reason: entity.meta.id);
        expect(entity.meta.dateFrom, created);
        expect(entity.meta.vectorClock, isNull);
      }
      expect(task.categoryId, 'cat-1');

      // Insertion order: items before checklists before tasks.
      final order = plan.entities.toList();
      expect(order.indexOf(item), lessThan(order.indexOf(checklist)));
      expect(order.indexOf(checklist), lessThan(order.indexOf(task)));

      // Links remapped to the fresh ids.
      expect(plan.links, hasLength(2));
      for (final link in plan.links) {
        expect(link.fromId, task.meta.id);
        expect({link.toId}, isNotEmpty);
        expect(newIds, contains(link.toId));
      }

      // Media staged under the new name, bytes intact, target rewritten.
      expect(image.data.imageDirectory, demoImportMediaDirectory);
      expect(image.data.imageFile, '${image.meta.id}.jpg');
      final staged = plan.media.single;
      expect(staged.relativeTarget, '/demo_import/${image.meta.id}.jpg');
      expect(staged.stagedFile.readAsBytesSync(), [1, 2, 3, 4]);

      // Referenced category definition travels with its ORIGINAL id.
      expect(
        plan.definitions.whereType<CategoryDefinition>().single.id,
        'cat-1',
      );

      // The demo side is untouched: original rows still there, unchanged.
      final originalTask = await source.journalDb.journalEntityById('task-1');
      expect(
        originalTask!.maybeMap(
          task: (t) => t.data.checklistIds,
          orElse: () => null,
        ),
        ['check-1'],
      );
      expect(
        File(
          p.join(sourceRoot.path, 'images', '2026-07-20', 'img-1.jpg'),
        ).existsSync(),
        isTrue,
      );
      expect(byOldTitleOrType, isNotEmpty);
    });

    test('seeded ids cut the closure off (a note linked from a selected task '
        'but listed in the manifest stays behind)', () async {
      await seedSourceWorld();
      await DemoSeedManifest(
        seedVersion: demoSeedVersion,
        seededAt: created.toUtc(),
        localeTag: 'en',
        seededJournalIds: const ['note-1'],
        seededDefinitionIds: const [],
        seededAiConfigIds: const [],
      ).write(sourceRoot);
      final copier = DemoDataCopier(newId: sequentialIds());

      final plan = await copier.prepare(
        selectedIds: {'task-1'},
        sourceDb: source.journalDb,
        sourceRoot: sourceRoot,
        stagingDir: stagingDir,
      );

      expect(plan.entities.whereType<JournalEntry>(), isEmpty);
      // The link into the excluded note is dropped with it.
      expect(plan.links, hasLength(1));
    });
  });

  group('apply', () {
    test('moves media, upserts absent definitions, writes entities through '
        'PersistenceLogic with fresh clocks, then recreates links', () async {
      await seedSourceWorld();
      final copier = DemoDataCopier(newId: sequentialIds());
      final plan = await copier.prepare(
        selectedIds: {'task-1'},
        sourceDb: source.journalDb,
        sourceRoot: sourceRoot,
        stagingDir: stagingDir,
      );

      final persistence = MockPersistenceLogic();
      final targetDb = MockJournalDb();
      when(() => targetDb.getCategoryById(any())).thenAnswer((_) async => null);
      when(
        () => persistence.upsertEntityDefinition(any()),
      ).thenAnswer((_) async => 1);
      when(() => persistence.updateMetadata(any())).thenAnswer((invocation) {
        final meta = invocation.positionalArguments.first as Metadata;
        return Future.value(
          meta.copyWith(vectorClock: const VectorClock({'real-host': 7})),
        );
      });
      final mediaPresentAtInsert = <String, bool>{};
      when(
        () => persistence.createDbEntity(
          any(),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
        ),
      ).thenAnswer((invocation) async {
        final entity = invocation.positionalArguments.first as JournalEntity;
        if (entity is JournalImage) {
          // The media contract: bytes are in place BEFORE the entity lands.
          mediaPresentAtInsert[entity.meta.id] = File(
            '${targetRoot.path}${entity.data.imageDirectory}'
            '${entity.data.imageFile}',
          ).existsSync();
        }
        return true;
      });
      when(
        () => persistence.createLink(
          fromId: any(named: 'fromId'),
          toId: any(named: 'toId'),
        ),
      ).thenAnswer((_) async => true);

      final copied = await copier.apply(
        plan,
        persistence: persistence,
        targetJournalDb: targetDb,
        targetRoot: targetRoot,
      );

      expect(copied, 5);

      // Media landed under the real root and was present before the insert.
      final image = plan.entities.whereType<JournalImage>().single;
      final targetFile = File(
        '${targetRoot.path}/demo_import/${image.meta.id}.jpg',
      );
      expect(targetFile.readAsBytesSync(), [1, 2, 3, 4]);
      expect(mediaPresentAtInsert[image.meta.id], isTrue);

      // Definitions were checked against the target and upserted through
      // the production (sync-enqueueing) path.
      final upserted = verify(
        () => persistence.upsertEntityDefinition(captureAny()),
      ).captured;
      expect(upserted.map((d) => (d as EntityDefinition).id), ['cat-1']);

      // Every entity got a fresh real-world vector clock and preserved dates.
      final written = verify(
        () => persistence.createDbEntity(
          captureAny(),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
        ),
      ).captured.cast<JournalEntity>();
      expect(written, hasLength(5));
      for (final entity in written) {
        expect(
          entity.meta.vectorClock,
          const VectorClock({'real-host': 7}),
          reason: 'clock stamped via PersistenceLogic.updateMetadata',
        );
        expect(entity.meta.createdAt, created);
        expect(entity.meta.dateFrom, created);
      }

      // Links recreated for the remapped pairs.
      final linkCalls = verify(
        () => persistence.createLink(
          fromId: captureAny(named: 'fromId'),
          toId: captureAny(named: 'toId'),
        ),
      ).captured;
      expect(linkCalls, hasLength(4)); // 2 links x (fromId, toId)
    });

    test('an already-present definition is NOT overwritten (idempotent '
        're-copy keeps real-world edits)', () async {
      await seedSourceWorld();
      final copier = DemoDataCopier(newId: sequentialIds());
      final plan = await copier.prepare(
        selectedIds: {'task-1'},
        sourceDb: source.journalDb,
        sourceRoot: sourceRoot,
        stagingDir: stagingDir,
      );

      final persistence = MockPersistenceLogic();
      final targetDb = MockJournalDb();
      when(() => targetDb.getCategoryById('cat-1')).thenAnswer(
        (_) async => CategoryDefinition(
          id: 'cat-1',
          createdAt: created,
          updatedAt: created,
          name: 'Renamed in real world',
          vectorClock: null,
          private: false,
          active: true,
        ),
      );
      when(() => persistence.updateMetadata(any())).thenAnswer(
        (invocation) async => invocation.positionalArguments.first as Metadata,
      );
      when(
        () => persistence.createDbEntity(
          any(),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
        ),
      ).thenAnswer((_) async => true);
      when(
        () => persistence.createLink(
          fromId: any(named: 'fromId'),
          toId: any(named: 'toId'),
        ),
      ).thenAnswer((_) async => true);

      await copier.apply(
        plan,
        persistence: persistence,
        targetJournalDb: targetDb,
        targetRoot: targetRoot,
      );

      verifyNever(() => persistence.upsertEntityDefinition(any()));
    });
  });
}
