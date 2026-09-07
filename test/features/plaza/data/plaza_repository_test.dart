import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/demo/seed/demo_world.dart';
import 'package:lotti/features/plaza/data/plaza_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../../projects/test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);
  final world = ManualDemoWorld.penguinLogistics(now: manualDemoNow);
  final category = world.categories.first;
  final project = makeTestProject(id: 'project', categoryId: category.id);
  final task = world.tasks.first.copyWith(
    data: world.tasks.first.data.copyWith(coverArtId: null),
  );
  late MockJournalDb db;
  late MockEntitiesCacheService cache;
  late PlazaRepository repository;
  late MockPersistenceLogic persistence;
  late Map<String, JournalEntity> entities;

  setUp(() {
    db = MockJournalDb();
    cache = MockEntitiesCacheService();
    persistence = MockPersistenceLogic();
    repository = PlazaRepository(
      db: db,
      cache: cache,
      persistence: persistence,
    );
    entities = {
      project.meta.id: project,
      task.meta.id: task,
      for (final entity in world.checklists) entity.meta.id: entity,
      for (final entity in world.checklistItems) entity.meta.id: entity,
    };
    when(() => cache.lockedCategoryIds).thenReturn({});
    when(
      () => db.getProjectForTask(task.meta.id),
    ).thenAnswer((_) async => project);
    when(() => cache.getCategoryById(any())).thenReturn(category);
    when(() => db.getJournalEntitiesForIds(any())).thenAnswer((
      invocation,
    ) async {
      final ids = invocation.positionalArguments.first as Set<String>;
      return [
        for (final id in ids) ?entities[id],
      ];
    });
    when(
      () => db.getTasksForProject(project.meta.id),
    ).thenAnswer((_) async => [task]);
    when(
      () => db.linksForEntryIdsBidirectional(any()),
    ).thenAnswer((_) async => []);
  });

  test(
    'cover paths escape spaces and deleted covers disappear from the world',
    () async {
      await setUpTestGetIt(
        additionalSetup: () {
          getIt.registerSingleton<Directory>(Directory('/fixture data'));
        },
      );
      addTearDown(tearDownTestGetIt);
      final image = world.images.first.copyWith(
        data: world.images.first.data.copyWith(
          imageDirectory: '/images/plaza/',
          imageFile: 'cover art.png',
        ),
      );
      final withCover = task.copyWith(
        data: task.data.copyWith(coverArtId: image.id),
      );
      when(
        () => db.getTasksForProject(project.id),
      ).thenAnswer((_) async => [withCover]);
      entities[image.id] = image;
      final visible = (await repository.loadProject(project.id))!;
      expect(
        visible.tasks.single.coverImageUrl,
        'file:///fixture%20data/images/plaza/cover%20art.png',
      );
      expect(visible.dependencyIds, contains(image.id));
      entities[image.id] = image.copyWith(
        meta: image.meta.copyWith(deletedAt: manualDemoNow),
      );
      final removed = (await repository.loadProject(project.id))!;
      expect(removed.tasks.single.coverImageUrl, isNull);
      expect(removed.dependencyIds, contains(image.id));
    },
  );

  test(
    'category reads stay scoped and defer checklist and cover hydration',
    () async {
      final outside = project.copyWith(
        meta: project.meta.copyWith(id: 'outside', categoryId: 'elsewhere'),
      );
      when(
        () => db.getProjectsForCategory(category.id),
      ).thenAnswer((_) async => [project, outside]);
      final result = (await repository.loadCategory(category.id))!;
      expect(result.category.id, category.id);
      expect(result.projects.map((summary) => summary.project.id), [
        project.id,
      ]);
      expect(result.projects.single.tasks.single.id, task.id);
      expect(result.projects.single.tasks.single.coverImageUrl, isNull);
      expect(result.projects.single.tasks.single.openChecklistItemIds, isEmpty);
      expect(
        result.dependencyIds,
        containsAll([category.id, project.id, task.id]),
      );
      verifyNever(() => db.getJournalEntitiesForIds(any()));
      verifyNever(() => db.getTasksForProject('outside'));
      when(() => cache.lockedCategoryIds).thenReturn({category.id});
      expect(await repository.loadCategory(category.id), isNull);
      verify(() => db.getProjectsForCategory(category.id)).called(1);
    },
  );

  test(
    'reads only the requested project and resolves checklist identity',
    () async {
      final result = (await repository.loadProject(project.meta.id))!;
      expect(result.project, project);
      expect(result.category, category);
      expect(result.tasks.single.id, task.meta.id);
      expect(result.tasks.single.title, task.data.title);
      expect(result.tasks.single.checklistItems, greaterThan(0));
      expect(result.tasks.single.openChecklistItemIds, isNotEmpty);
      for (final id in result.tasks.single.openChecklistItemIds) {
        final item = entities[id]! as ChecklistItem;
        expect(item.data.isChecked, isFalse);
        expect(result.dependencyIds, contains(id));
      }
      verify(() => db.getTasksForProject(project.meta.id)).called(1);
      expect(
        result.dependencyIds,
        containsAll([project.meta.id, category.id, task.meta.id]),
      );
    },
  );

  test(
    'does not read tasks for a missing, private-filtered or deleted project',
    () async {
      entities.remove(project.meta.id);
      expect(await repository.loadProject(project.meta.id), isNull);
      entities[project.meta.id] = project.copyWith(
        meta: project.meta.copyWith(deletedAt: manualDemoNow),
      );
      expect(await repository.loadProject(project.meta.id), isNull);
      verifyNever(() => db.getTasksForProject(any()));
    },
  );

  test('locked categories cannot expose a project world', () async {
    when(() => cache.lockedCategoryIds).thenReturn({category.id});
    expect(await repository.loadProject(project.meta.id), isNull);
    verifyNever(() => db.getTasksForProject(any()));
  });

  test(
    'rejects stale membership across category and privacy boundaries',
    () async {
      final moved = task.copyWith(
        meta: task.meta.copyWith(id: 'moved', categoryId: 'outside'),
      );
      final hidden = task.copyWith(
        meta: task.meta.copyWith(
          id: 'hidden',
          private: !(project.meta.private ?? false),
        ),
      );
      when(
        () => db.getTasksForProject(project.meta.id),
      ).thenAnswer((_) async => [task, moved, hidden]);
      final result = (await repository.loadProject(project.meta.id))!;
      expect(result.tasks.map((task) => task.id), [task.meta.id]);
      expect(result.dependencyIds, containsAll(['moved', 'hidden']));
    },
  );

  test(
    'keeps unresolved child IDs so late sync arrivals can refresh',
    () async {
      final checklistId = task.data.checklistIds!.first;
      entities.remove(checklistId);
      final result = (await repository.loadProject(project.meta.id))!;
      expect(result.dependencyIds, contains(checklistId));
      expect(result.tasks.single.checklistItems, 0);
      expect(result.tasks.single.progress, 0);
    },
  );

  test('empty project stays empty and does not query task links', () async {
    when(
      () => db.getTasksForProject(project.meta.id),
    ).thenAnswer((_) async => []);
    final result = (await repository.loadProject(project.meta.id))!;
    expect(result.tasks, isEmpty);
    expect(result.project.meta.id, project.meta.id);
    verifyNever(() => db.linksForEntryIdsBidirectional(any()));
  });

  test(
    'links stay within visible membership and exclude hidden/tombstoned edges',
    () async {
      final sibling = task.copyWith(meta: task.meta.copyWith(id: 'sibling'));
      final third = task.copyWith(meta: task.meta.copyWith(id: 'third'));
      when(
        () => db.getTasksForProject(project.meta.id),
      ).thenAnswer((_) async => [task, sibling, third]);
      EntryLink link(
        String id,
        String toId, {
        bool? hidden,
        DateTime? deletedAt,
      }) => EntryLink.basic(
        id: id,
        fromId: task.meta.id,
        toId: toId,
        createdAt: manualDemoNow,
        updatedAt: manualDemoNow,
        vectorClock: null,
        hidden: hidden,
        deletedAt: deletedAt,
      );
      when(() => db.linksForEntryIdsBidirectional(any())).thenAnswer(
        (_) async => [
          link('visible', sibling.meta.id),
          link('duplicate', sibling.meta.id),
          link('private-or-unrelated', 'outside-project'),
          link('hidden', third.meta.id, hidden: true),
          link('deleted', third.meta.id, deletedAt: manualDemoNow),
        ],
      );
      final tasks = (await repository.loadProject(project.meta.id))!.tasks;
      expect(tasks.first.linkedTaskIds, [sibling.meta.id]);
      expect(tasks[1].linkedTaskIds, [task.meta.id]);
      expect(tasks[2].linkedTaskIds, isEmpty);
    },
  );
  test(
    'checklist writes preserve fresh content and stamp user provenance',
    () async {
      final checklist = entities[task.data.checklistIds!.first]! as Checklist;
      final itemId = checklist.data.linkedChecklistItems.first;
      final original = entities[itemId]! as ChecklistItem;
      final item = original.copyWith(
        data: original.data.copyWith(
          title: 'Renamed by sync',
          isChecked: false,
        ),
      );
      entities[itemId] = item;
      when(
        () => persistence.updateMetadata(item.meta),
      ).thenAnswer((_) async => item.meta);
      when(
        () => persistence.updateDbEntity(any(), linkedId: task.meta.id),
      ).thenAnswer((_) async => true);
      final saved = await withClock(
        Clock.fixed(manualDemoNow),
        () => repository.setChecklistItemChecked(
          projectId: project.meta.id,
          taskId: task.meta.id,
          itemId: itemId,
          checked: true,
        ),
      );
      expect(saved, isTrue);
      final updated =
          verify(
                () => persistence.updateDbEntity(
                  captureAny(),
                  linkedId: task.meta.id,
                ),
              ).captured.single
              as ChecklistItem;
      expect(updated.meta.id, itemId);
      expect(updated.data.title, 'Renamed by sync');
      expect(updated.data.isChecked, isTrue);
      expect(updated.data.checkedAt, manualDemoNow);
      expect(updated.data.linkedChecklists, item.data.linkedChecklists);
    },
  );

  test(
    'checklist writes reject items no longer belonging to the task',
    () async {
      final item = world.checklistItems.first;
      entities[task.meta.id] = task.copyWith(
        data: task.data.copyWith(checklistIds: []),
      );
      expect(
        await repository.setChecklistItemChecked(
          projectId: project.meta.id,
          taskId: task.meta.id,
          itemId: item.id,
          checked: true,
        ),
        isFalse,
      );
      verifyNever(
        () =>
            persistence.updateDbEntity(any(), linkedId: any(named: 'linkedId')),
      );
    },
  );

  test(
    'a checklist click cannot follow a task moved to another project',
    () async {
      when(() => db.getProjectForTask(task.id)).thenAnswer(
        (_) async => makeTestProject(id: 'outside', categoryId: category.id),
      );
      final checklist = entities[task.data.checklistIds!.first]! as Checklist;
      expect(
        await repository.setChecklistItemChecked(
          projectId: project.id,
          taskId: task.id,
          itemId: checklist.data.linkedChecklistItems.first,
          checked: true,
        ),
        isFalse,
      );
      verifyNever(
        () =>
            persistence.updateDbEntity(any(), linkedId: any(named: 'linkedId')),
      );
    },
  );

  test('an already checked item needs no write', () async {
    final checklist = entities[task.data.checklistIds!.first]! as Checklist;
    final itemId = checklist.data.linkedChecklistItems.first;
    final item = entities[itemId]! as ChecklistItem;
    entities[itemId] = item.copyWith(data: item.data.copyWith(isChecked: true));
    expect(
      await repository.setChecklistItemChecked(
        projectId: project.meta.id,
        taskId: task.meta.id,
        itemId: itemId,
        checked: true,
      ),
      isTrue,
    );
    verifyNever(
      () => persistence.updateDbEntity(any(), linkedId: any(named: 'linkedId')),
    );
  });
}
