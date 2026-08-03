import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/tasks/state/linkable_tasks_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  final now = DateTime(2026, 8, 4, 9);

  Task buildTask(String id) => Task(
    meta: Metadata(
      id: id,
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now,
    ),
    data: TaskData(
      status: TaskStatus.open(id: 's-$id', createdAt: now, utcOffset: 0),
      dateFrom: now,
      dateTo: now,
      statusHistory: const [],
      title: 'Task $id',
    ),
  );

  late MockJournalDb mockJournalDb;
  late MockUpdateNotifications mockUpdateNotifications;
  late MockEntitiesCacheService mockCache;
  late StreamController<Set<String>> updateStream;

  /// What `getTasks` will answer with next. Mutable so a test can change the
  /// world and then push an update notification, which is exactly the shape of
  /// "the user created their second task somewhere else".
  late List<JournalEntity> tasksInDb;

  setUp(() {
    mockJournalDb = MockJournalDb();
    mockUpdateNotifications = MockUpdateNotifications();
    mockCache = MockEntitiesCacheService();
    updateStream = StreamController<Set<String>>.broadcast();
    tasksInDb = [buildTask('task-1')];

    when(() => mockCache.sortedCategories).thenReturn(<CategoryDefinition>[]);
    when(
      () => mockUpdateNotifications.updateStream,
    ).thenAnswer((_) => updateStream.stream);
    when(
      () => mockJournalDb.getTasks(
        starredStatuses: any(named: 'starredStatuses'),
        taskStatuses: any(named: 'taskStatuses'),
        categoryIds: any(named: 'categoryIds'),
        labelIds: any(named: 'labelIds'),
        priorities: any(named: 'priorities'),
        ids: any(named: 'ids'),
        sortByDate: any(named: 'sortByDate'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => tasksInDb);

    getIt
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
      ..registerSingleton<EntitiesCacheService>(mockCache);
  });

  tearDown(() async {
    await updateStream.close();
    await getIt.reset();
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  /// Keeps an autoDispose provider alive for the length of a test. Without a
  /// listener it is torn down the moment the read completes, and the
  /// update-stream subscription goes with it.
  void keepAlive(ProviderContainer container, String taskId) {
    final sub = container.listen(
      linkableTasksExistProvider(taskId),
      (_, _) {},
    );
    addTearDown(sub.close);
  }

  test(
    'the viewed task does not count as something to link itself to',
    () async {
      final container = makeContainer();

      final exists = await container.read(
        linkableTasksExistProvider('task-1').future,
      );

      expect(exists, isFalse);
    },
  );

  test('any other task makes linking possible', () async {
    tasksInDb = [buildTask('task-1'), buildTask('task-2')];
    final container = makeContainer();

    expect(
      await container.read(linkableTasksExistProvider('task-1').future),
      isTrue,
    );
  });

  test(
    'a task created elsewhere flips the answer without a reload — the card '
    'has to come back the moment a second task exists',
    () async {
      final container = makeContainer();
      keepAlive(container, 'task-1');
      expect(
        await container.read(linkableTasksExistProvider('task-1').future),
        isFalse,
      );

      // The world changes, then the write announces itself. This is the shape
      // of "Create new linked task" on the very page reading this provider.
      tasksInDb = [buildTask('task-1'), buildTask('task-2')];
      updateStream.add({'task-2'});
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(linkableTasksExistProvider('task-1')).value,
        isTrue,
      );
    },
  );

  test(
    'an update that does not change the answer leaves the state alone',
    () async {
      final container = makeContainer();
      keepAlive(container, 'task-1');
      await container.read(linkableTasksExistProvider('task-1').future);

      final before = container.read(linkableTasksExistProvider('task-1'));
      updateStream.add({'task-1'});
      await Future<void>.delayed(Duration.zero);

      expect(
        identical(before, container.read(linkableTasksExistProvider('task-1'))),
        isTrue,
        reason: 'no needless rebuild for an unchanged answer',
      );
    },
  );

  test('asks for two rows — one cannot distinguish self from others', () async {
    final container = makeContainer();
    await container.read(linkableTasksExistProvider('task-1').future);

    final limit =
        verify(
              () => mockJournalDb.getTasks(
                starredStatuses: any(named: 'starredStatuses'),
                taskStatuses: any(named: 'taskStatuses'),
                categoryIds: any(named: 'categoryIds'),
                limit: captureAny(named: 'limit'),
              ),
            ).captured.single
            as int;

    expect(limit, 2);
  });

  test(
    'queries every category plus the uncategorized bucket — an empty list '
    'short-circuits the query builder to WHERE 1 = 0',
    () async {
      when(() => mockCache.sortedCategories).thenReturn([
        CategoryDefinition(
          id: 'cat-1',
          name: 'Work',
          createdAt: now,
          updatedAt: now,
          vectorClock: null,
          private: false,
          active: true,
        ),
      ]);
      final container = makeContainer();
      await container.read(linkableTasksExistProvider('task-1').future);

      final categoryIds =
          verify(
                () => mockJournalDb.getTasks(
                  starredStatuses: any(named: 'starredStatuses'),
                  taskStatuses: any(named: 'taskStatuses'),
                  categoryIds: captureAny(named: 'categoryIds'),
                  limit: any(named: 'limit'),
                ),
              ).captured.single
              as List<String>;

      expect(categoryIds, containsAll(<String>['cat-1', '']));
    },
  );
}
