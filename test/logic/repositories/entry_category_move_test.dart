import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/repositories/category_move_intents.dart';
import 'package:lotti/logic/repositories/checklist_repository.dart';
import 'package:lotti/logic/repositories/entry_category_move.dart';
import 'package:lotti/logic/repositories/journal_repository.dart';
import 'package:lotti/logic/repositories/project_repository.dart';
import 'package:lotti/logic/services/geolocation_service.dart';
import 'package:lotti/logic/services/metadata_service.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/outbox_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/projects/test_utils.dart' show makeTestProject;
import '../../helpers/fallbacks.dart';
import '../../helpers/path_provider.dart';
import '../../mocks/mocks.dart';
import '../../test_data/test_data.dart';
import '../../widget_test_utils.dart';

part 'entry_category_move_crash.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  const projectCategoryId = 'cat_lotti';
  const otherCategoryId = 'cat_one_point_five';

  late MockJournalRepository journalRepository;
  late MockJournalDb journalDb;
  late MockProjectRepository projectRepository;
  late MockDomainLogger domainLogger;
  late SettingsDb settingsDb;
  late CategoryMoveIntents intents;
  late EntryCategoryMove categoryMove;

  EntryCategoryMove fresh() => EntryCategoryMove(
    journalRepository: journalRepository,
    journalDb: journalDb,
    projectRepository: projectRepository,
    intents: intents,
    domainLogger: domainLogger,
  );

  Task taskIn(String? categoryId, {String? id, List<String>? checklistIds}) =>
      testTask.copyWith(
        meta: testTask.meta.copyWith(
          id: id ?? testTask.meta.id,
          categoryId: categoryId,
        ),
        data: testTask.data.copyWith(checklistIds: checklistIds),
      );

  /// [entity] as the database holds it.
  void stored(JournalEntity entity) => when(
    () => journalDb.journalEntityById(entity.meta.id),
  ).thenAnswer((_) async => entity);

  void linkedFrom(String id, List<JournalEntity> entries) => when(
    () => journalRepository.getLinkedEntities(linkedTo: id),
  ).thenAnswer((_) async => entries);

  void inProject(String taskId, {String? categoryId = projectCategoryId}) =>
      when(() => projectRepository.getLinkedProjectForTask(taskId)).thenAnswer(
        (_) async => makeTestProject(id: 'project_1', categoryId: categoryId),
      );

  void verifyWrote(String id, String? categoryId) => verify(
    () => journalRepository.updateCategoryId(id, categoryId: categoryId),
  ).called(1);

  void verifyNoWrite(String id) => verifyNever(
    () => journalRepository.updateCategoryId(
      id,
      categoryId: any(named: 'categoryId'),
    ),
  );

  setUp(() {
    journalRepository = MockJournalRepository();
    journalDb = MockJournalDb();
    projectRepository = MockProjectRepository();
    domainLogger = MockDomainLogger();
    settingsDb = SettingsDb(inMemoryDatabase: true);
    intents = CategoryMoveIntents(settingsDb: settingsDb);
    categoryMove = fresh();

    when(
      () => journalRepository.updateCategoryId(
        any(),
        categoryId: any(named: 'categoryId'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => journalRepository.getLinkedEntities(
        linkedTo: any(named: 'linkedTo'),
      ),
    ).thenAnswer((_) async => const []);
    when(
      () => journalDb.journalEntityById(any()),
    ).thenAnswer((_) async => null);
    when(
      () => projectRepository.getLinkedProjectForTask(any()),
    ).thenAnswer((_) async => null);
    when(
      () => projectRepository.unlinkTaskFromProject(any()),
    ).thenAnswer((_) async => true);
    when(
      () => domainLogger.error(
        any(),
        any(),
        message: any(named: 'message'),
        subDomain: any(named: 'subDomain'),
        stackTrace: any(named: 'stackTrace'),
      ),
    ).thenReturn(null);
  });
  tearDown(() => settingsDb.close());

  group('move', () {
    test('moves the entry and every entry linked from it, and clears its '
        'record', () async {
      final task = taskIn(otherCategoryId);
      stored(task);
      final linkedTask = taskIn(null, id: 'linked_task');
      final linkedEntry = testTextEntryNoGeo.copyWith(
        meta: testTextEntryNoGeo.meta.copyWith(
          id: 'linked_entry',
          categoryId: 'old_category',
        ),
      );
      linkedFrom(task.meta.id, [linkedTask, linkedEntry]);

      expect(await categoryMove.move(task.meta.id, otherCategoryId), isTrue);

      verifyWrote(task.meta.id, otherCategoryId);
      verifyWrote(linkedTask.meta.id, otherCategoryId);
      verifyWrote(linkedEntry.meta.id, otherCategoryId);
      expect(await intents.pending(), isEmpty);
    });

    test('clears the category of the entry and its linked entries', () async {
      final task = taskIn(null);
      stored(task);
      final linkedEntry = testTextEntryNoGeo.copyWith(
        meta: testTextEntryNoGeo.meta.copyWith(
          id: 'linked_entry',
          categoryId: 'old_category',
        ),
      );
      linkedFrom(task.meta.id, [linkedEntry]);

      expect(await categoryMove.move(task.meta.id, null), isTrue);

      verifyWrote(task.meta.id, null);
      verifyWrote(linkedEntry.meta.id, null);
    });

    test('skips a linked entry already in the category', () async {
      final task = taskIn(otherCategoryId);
      stored(task);
      final linkedEntry = testTextEntryNoGeo.copyWith(
        meta: testTextEntryNoGeo.meta.copyWith(
          id: 'linked_entry',
          categoryId: otherCategoryId,
        ),
      );
      linkedFrom(task.meta.id, [linkedEntry]);

      await categoryMove.move(task.meta.id, otherCategoryId);

      verifyNoWrite(linkedEntry.meta.id);
    });

    test('moves nothing else when the entry write does not land', () async {
      final task = taskIn(projectCategoryId);
      when(
        () => journalRepository.updateCategoryId(
          task.meta.id,
          categoryId: otherCategoryId,
        ),
      ).thenAnswer((_) async => false);
      inProject(task.meta.id);

      expect(await categoryMove.move(task.meta.id, otherCategoryId), isFalse);

      verifyNever(
        () => journalRepository.getLinkedEntities(
          linkedTo: any(named: 'linkedTo'),
        ),
      );
      verifyNever(() => projectRepository.unlinkTaskFromProject(any()));
      expect(await intents.pending(), isEmpty);
    });

    test(
      'a root write reported failed that committed still moves the rest',
      () async {
        // The write answers false when work after its commit throws: the
        // stored row decides.
        when(
          () => journalRepository.updateCategoryId(
            testTask.meta.id,
            categoryId: otherCategoryId,
          ),
        ).thenAnswer((_) async => false);
        stored(taskIn(otherCategoryId));
        final linkedEntry = testTextEntryNoGeo.copyWith(
          meta: testTextEntryNoGeo.meta.copyWith(
            id: 'linked_entry',
            categoryId: projectCategoryId,
          ),
        );
        linkedFrom(testTask.meta.id, [linkedEntry]);

        expect(
          await categoryMove.move(testTask.meta.id, otherCategoryId),
          isTrue,
        );

        verifyWrote(linkedEntry.meta.id, otherCategoryId);
        expect(await intents.pending(), isEmpty);
      },
    );

    // A follower write that did not land keeps the move for the next start,
    // unless its row is gone.
    for (final (name, stillThere) in [
      ('is kept for the next start', true),
      ('is done when the row is gone', false),
    ]) {
      test(
        'a move whose linked entry did not take the category $name',
        () async {
          stored(taskIn(otherCategoryId));
          final linkedEntry = testTextEntryNoGeo.copyWith(
            meta: testTextEntryNoGeo.meta.copyWith(
              id: 'linked_entry',
              categoryId: projectCategoryId,
            ),
          );
          linkedFrom(testTask.meta.id, [linkedEntry]);
          when(
            () => journalRepository.updateCategoryId(
              linkedEntry.meta.id,
              categoryId: otherCategoryId,
            ),
          ).thenAnswer((_) async => false);
          if (stillThere) stored(linkedEntry);

          await categoryMove.move(testTask.meta.id, otherCategoryId);

          expect(
            await intents.pending(),
            stillThere
                ? {testTask.meta.id: (categoryId: otherCategoryId)}
                : isEmpty,
          );
        },
      );
    }

    test('a second move of the entry waits for the first, and its record '
        'stands', () async {
      final linkedEntry = testTextEntryNoGeo.copyWith(
        meta: testTextEntryNoGeo.meta.copyWith(
          id: 'linked_entry',
          categoryId: projectCategoryId,
        ),
      );
      linkedFrom(testTask.meta.id, [linkedEntry]);
      final writes = <String?>[];
      final firstFollower = Completer<bool>();
      when(
        () => journalRepository.updateCategoryId(
          testTask.meta.id,
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer((call) async {
        final category = call.namedArguments[#categoryId] as String?;
        writes.add('task:$category');
        stored(taskIn(category));
        return true;
      });
      when(
        () => journalRepository.updateCategoryId(
          linkedEntry.meta.id,
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer((call) {
        final category = call.namedArguments[#categoryId] as String?;
        writes.add('entry:$category');
        return writes.length == 2 ? firstFollower.future : Future.value(true);
      });

      final first = categoryMove.move(testTask.meta.id, otherCategoryId);
      final second = categoryMove.move(testTask.meta.id, 'cat_third');
      await pumpEventQueue();

      // The second move has not begun while the first is in flight.
      expect(writes, ['task:$otherCategoryId', 'entry:$otherCategoryId']);

      firstFollower.complete(true);
      await Future.wait([first, second]);

      expect(writes, [
        'task:$otherCategoryId',
        'entry:$otherCategoryId',
        'task:cat_third',
        'entry:cat_third',
      ]);
      expect(await intents.pending(), isEmpty);
    });

    // The checklists of a task and their items carry its category: a new
    // item takes its checklist's (`specs/tla/TaskCategoryMove.tla`,
    // ChecklistsFollow).
    group("a task's checklists", () {
      Checklist checklist(
        String id, {
        List<String>? tasks,
        List<String>? items,
      }) => Checklist(
        meta: testTask.meta.copyWith(id: id, categoryId: projectCategoryId),
        data: ChecklistData(
          title: 'Checklist $id',
          linkedChecklistItems: items ?? const [],
          linkedTasks: tasks ?? [testTask.meta.id],
        ),
      );

      ChecklistItem item(String id, List<String> checklists) => ChecklistItem(
        meta: testTask.meta.copyWith(id: id, categoryId: projectCategoryId),
        data: ChecklistItemData(
          title: 'Item $id',
          isChecked: false,
          linkedChecklists: checklists,
        ),
      );

      test('move with the task, with their items', () async {
        stored(taskIn(otherCategoryId, checklistIds: ['cl_1']));
        stored(checklist('cl_1', items: ['item_1']));
        stored(item('item_1', ['cl_1']));

        await categoryMove.move(testTask.meta.id, otherCategoryId);

        verifyWrote('cl_1', otherCategoryId);
        verifyWrote('item_1', otherCategoryId);
      });

      test(
        'stay when another task shows them too, and so do their items',
        () async {
          stored(taskIn(otherCategoryId, checklistIds: ['cl_1']));
          stored(
            checklist(
              'cl_1',
              tasks: [testTask.meta.id, 'other_task'],
              items: ['item_1'],
            ),
          );
          stored(item('item_1', ['cl_1']));

          await categoryMove.move(testTask.meta.id, otherCategoryId);

          verifyNoWrite('cl_1');
          verifyNoWrite('item_1');
        },
      );

      test(
        'keep an item a shared checklist of the same task lists too',
        () async {
          stored(
            taskIn(otherCategoryId, checklistIds: ['cl_own', 'cl_shared']),
          );
          stored(checklist('cl_own', items: ['item_both']));
          stored(
            checklist(
              'cl_shared',
              tasks: [testTask.meta.id, 'other_task'],
              items: ['item_both'],
            ),
          );
          stored(item('item_both', ['cl_own', 'cl_shared']));

          await categoryMove.move(testTask.meta.id, otherCategoryId);

          verifyWrote('cl_own', otherCategoryId);
          verifyNoWrite('cl_shared');
          verifyNoWrite('item_both');
        },
      );

      test("keep an item another task's checklist lists too", () async {
        stored(taskIn(otherCategoryId, checklistIds: ['cl_1']));
        stored(checklist('cl_1', items: ['item_1', 'item_2']));
        stored(item('item_1', ['cl_1', 'cl_elsewhere']));
        stored(item('item_2', ['cl_1']));

        await categoryMove.move(testTask.meta.id, otherCategoryId);

        verifyNoWrite('item_1');
        verifyWrote('item_2', otherCategoryId);
      });

      test('of a linked task move with it', () async {
        final task = taskIn(otherCategoryId);
        stored(task);
        final linkedTask = taskIn(
          projectCategoryId,
          id: 'linked_task',
          checklistIds: ['cl_linked'],
        );
        linkedFrom(task.meta.id, [linkedTask]);
        stored(checklist('cl_linked', tasks: ['linked_task']));

        await categoryMove.move(task.meta.id, otherCategoryId);

        verifyWrote('cl_linked', otherCategoryId);
      });
    });

    // A task's project must be in its category: `linkTaskToProject` refuses
    // a cross-category link, so the move drops one it leaves behind.
    group('cross-category project link', () {
      test(
        'unlinks the project when the task moves to another category',
        () async {
          stored(taskIn(otherCategoryId));
          inProject(testTask.meta.id);

          await categoryMove.move(testTask.meta.id, otherCategoryId);

          verify(
            () => projectRepository.unlinkTaskFromProject(testTask.meta.id),
          ).called(1);
        },
      );

      test('unlinks the project when the category is cleared', () async {
        stored(taskIn(null));
        inProject(testTask.meta.id);

        await categoryMove.move(testTask.meta.id, null);

        verify(
          () => projectRepository.unlinkTaskFromProject(testTask.meta.id),
        ).called(1);
      });

      test(
        'keeps the project when the picked category is the one it is in',
        () async {
          stored(taskIn(projectCategoryId));
          inProject(testTask.meta.id);

          await categoryMove.move(testTask.meta.id, projectCategoryId);

          verifyNever(() => projectRepository.unlinkTaskFromProject(any()));
        },
      );

      test(
        'keeps an uncategorized project when the category is cleared',
        () async {
          stored(taskIn(null));
          inProject(testTask.meta.id, categoryId: null);

          await categoryMove.move(testTask.meta.id, null);

          verifyNever(() => projectRepository.unlinkTaskFromProject(any()));
        },
      );

      test('unlinks a linked task the same move dragged into the new '
          'category', () async {
        stored(taskIn(otherCategoryId));
        final linkedTask = taskIn(projectCategoryId, id: 'linked_task');
        linkedFrom(testTask.meta.id, [linkedTask]);
        inProject('linked_task');

        await categoryMove.move(testTask.meta.id, otherCategoryId);

        verify(
          () => projectRepository.unlinkTaskFromProject('linked_task'),
        ).called(1);
      });

      test('ignores linked entries that are not tasks', () async {
        stored(taskIn(otherCategoryId));
        linkedFrom(testTask.meta.id, [testTextEntryNoGeo]);

        await categoryMove.move(testTask.meta.id, otherCategoryId);

        verifyNever(
          () => projectRepository.getLinkedProjectForTask(
            testTextEntryNoGeo.meta.id,
          ),
        );
      });

      test(
        'does not sweep a linked task whose category write did not land',
        () async {
          stored(taskIn(otherCategoryId));
          final linkedTask = taskIn(projectCategoryId, id: 'linked_task');
          linkedFrom(testTask.meta.id, [linkedTask]);
          inProject(testTask.meta.id);
          inProject('linked_task');
          when(
            () => journalRepository.updateCategoryId(
              'linked_task',
              categoryId: otherCategoryId,
            ),
          ).thenAnswer((_) async => false);

          await categoryMove.move(testTask.meta.id, otherCategoryId);

          verify(
            () => projectRepository.unlinkTaskFromProject(testTask.meta.id),
          ).called(1);
          verifyNever(
            () => projectRepository.unlinkTaskFromProject('linked_task'),
          );
        },
      );

      test('never consults the project repository for a non-task', () async {
        stored(testTextEntry);

        await categoryMove.move(testTextEntry.meta.id, otherCategoryId);

        verifyNever(() => projectRepository.getLinkedProjectForTask(any()));
      });

      test('unlinks only after the category write has landed', () async {
        final calls = <String>[];
        stored(taskIn(otherCategoryId));
        inProject(testTask.meta.id);
        when(
          () => journalRepository.updateCategoryId(
            testTask.meta.id,
            categoryId: otherCategoryId,
          ),
        ).thenAnswer((_) async {
          calls.add('updateCategoryId');
          return true;
        });
        when(
          () => projectRepository.unlinkTaskFromProject(testTask.meta.id),
        ).thenAnswer((_) async {
          calls.add('unlinkTaskFromProject');
          return true;
        });

        await categoryMove.move(testTask.meta.id, otherCategoryId);

        // The task is in its new category before the link is dropped, so a
        // reader in between never sees the old category with no project.
        expect(calls, ['updateCategoryId', 'unlinkTaskFromProject']);
      });

      test('a failing project lookup is logged, the move reported done and '
          'kept for the next start', () async {
        stored(taskIn(otherCategoryId));
        when(
          () => projectRepository.getLinkedProjectForTask(testTask.meta.id),
        ).thenThrow(Exception('db unavailable'));

        // The entry's write has landed; a picker callback never awaits the
        // move, so a throw would only surface as an unhandled error.
        expect(
          await categoryMove.move(testTask.meta.id, otherCategoryId),
          isTrue,
        );

        expect(await intents.pending(), {
          testTask.meta.id: (categoryId: otherCategoryId),
        });
        verify(
          () => domainLogger.error(
            any(),
            any(),
            message: any(named: 'message'),
            subDomain: any(named: 'subDomain'),
            stackTrace: any(named: 'stackTrace'),
          ),
        ).called(1);
      });
    });
  });

  // A move the app died in is finished at the next start, while its entry
  // holds the recorded category (`specs/tla/TaskCategoryMove.tla`,
  // MoveIntent).
  group('replay', () {
    test('an app that died after the task write finishes the move at the '
        'next start', () async {
      final linkedEntry = testTextEntryNoGeo.copyWith(
        meta: testTextEntryNoGeo.meta.copyWith(
          id: 'linked_entry',
          categoryId: projectCategoryId,
        ),
      );
      stored(taskIn(otherCategoryId));
      linkedFrom(testTask.meta.id, [linkedEntry]);
      inProject(testTask.meta.id);
      // The linked entry's write never returns: the app dies in it.
      final dying = Completer<bool>();
      when(
        () => journalRepository.updateCategoryId(
          linkedEntry.meta.id,
          categoryId: otherCategoryId,
        ),
      ).thenAnswer((_) => dying.future);
      unawaited(categoryMove.move(testTask.meta.id, otherCategoryId));
      await pumpEventQueue();
      verifyNever(() => projectRepository.unlinkTaskFromProject(any()));

      // The next start.
      when(
        () => journalRepository.updateCategoryId(
          linkedEntry.meta.id,
          categoryId: otherCategoryId,
        ),
      ).thenAnswer((_) async => true);
      await fresh().replay();

      verify(
        () => journalRepository.updateCategoryId(
          linkedEntry.meta.id,
          categoryId: otherCategoryId,
        ),
      ).called(2);
      verify(
        () => projectRepository.unlinkTaskFromProject(testTask.meta.id),
      ).called(1);
      expect(await intents.pending(), isEmpty);
    });

    test('a move whose entry no longer holds its category is dropped, not '
        'replayed', () async {
      // Never begun, or moved again since, here or on another device: a
      // replay must not drag the entries back.
      stored(taskIn('cat_moved_since'));
      await intents.record(testTask.meta.id, otherCategoryId);

      await categoryMove.replay();

      verifyNever(
        () => journalRepository.getLinkedEntities(
          linkedTo: any(named: 'linkedTo'),
        ),
      );
      expect(await intents.pending(), isEmpty);
    });

    test('a move of an entry that is gone, or a record this build cannot '
        'read, is dropped', () async {
      await intents.record('gone', otherCategoryId);
      await settingsDb.saveSettingsItem(
        '${CategoryMoveIntents.keyPrefix}unreadable',
        'not json',
      );

      await categoryMove.replay();

      verifyNever(
        () => journalRepository.getLinkedEntities(
          linkedTo: any(named: 'linkedTo'),
        ),
      );
      expect(await intents.pending(), isEmpty);
    });

    test('a replay that throws keeps its record for the next start', () async {
      stored(taskIn(otherCategoryId));
      await intents.record(testTask.meta.id, otherCategoryId);
      when(
        () => journalRepository.getLinkedEntities(linkedTo: testTask.meta.id),
      ).thenThrow(StateError('database closed'));

      await categoryMove.replay();

      expect((await intents.pending()).keys, [testTask.meta.id]);
    });
  });

  _registerDbTests();
}
