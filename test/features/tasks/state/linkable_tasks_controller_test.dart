import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/tasks/state/linkable_tasks_controller.dart';
import 'package:lotti/features/tasks/ui/utils.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

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

  CategoryDefinition buildCategory({
    required String id,
    required String name,
    bool active = true,
  }) => CategoryDefinition(
    id: id,
    name: name,
    createdAt: now,
    updatedAt: now,
    vectorClock: null,
    private: false,
    active: active,
  );

  late TestGetItMocks mocks;
  late MockJournalDb mockJournalDb;
  late MockEntitiesCacheService mockCache;
  late StreamController<Set<String>> updateStream;

  /// What `getTasks` will answer with next. Mutable so a test can change the
  /// world and then push an update notification, which is exactly the shape of
  /// "the user created their second task somewhere else".
  late List<JournalEntity> tasksInDb;

  setUp(() async {
    updateStream = StreamController<Set<String>>.broadcast();
    mockCache = MockEntitiesCacheService();
    tasksInDb = [buildTask('task-1')];

    mocks = await setUpTestGetIt(
      additionalSetup: () =>
          getIt.registerSingleton<EntitiesCacheService>(mockCache),
    );
    mockJournalDb = mocks.journalDb;

    when(
      () => mockCache.categoriesById,
    ).thenReturn(<String, CategoryDefinition>{});
    when(
      () => mocks.updateNotifications.updateStream,
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
  });

  tearDown(() async {
    await updateStream.close();
    await tearDownTestGetIt();
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  /// Keeps an autoDispose provider alive for the length of a test and records
  /// every state it publishes. Without a listener it is torn down the moment
  /// the read completes, and the update-stream subscription goes with it.
  List<AsyncValue<bool>> watch(ProviderContainer container, String taskId) {
    final emitted = <AsyncValue<bool>>[];
    final sub = container.listen(
      linkableTasksExistProvider(taskId),
      (_, next) => emitted.add(next),
    );
    addTearDown(sub.close);
    return emitted;
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
    () {
      // `fakeAsync` rather than a real zero-duration wait: the refresh is a
      // broadcast-stream delivery followed by an async db read, all of it
      // microtasks, and `flushMicrotasks` drains exactly that chain instead of
      // hoping one turn of the event loop was enough.
      fakeAsync((async) {
        final container = makeContainer();
        watch(container, 'task-1');
        async.flushMicrotasks();
        expect(
          container.read(linkableTasksExistProvider('task-1')).value,
          isFalse,
        );

        // The world changes, then the write announces itself. This is the
        // shape of "Create new linked task" on the very page reading this
        // provider.
        tasksInDb = [buildTask('task-1'), buildTask('task-2')];
        updateStream.add({'task-2'});
        async.flushMicrotasks();

        expect(
          container.read(linkableTasksExistProvider('task-1')).value,
          isTrue,
        );
      });
    },
  );

  test(
    'an update that does not change the answer publishes no new state',
    () {
      fakeAsync((async) {
        final container = makeContainer();
        final emitted = watch(container, 'task-1');
        async.flushMicrotasks();
        expect(emitted, hasLength(1), reason: 'the initial resolution');

        updateStream.add({'task-1'});
        async.flushMicrotasks();

        expect(
          emitted,
          hasLength(1),
          reason:
              'no needless rebuild for an unchanged answer — every one of '
              'these repaints the Linked Tasks band',
        );
      });
    },
  );

  test(
    'a slow earlier refresh cannot overwrite a newer answer — a sync batch '
    'fires several notifications and the queries can land out of order',
    () {
      fakeAsync((async) {
        final container = makeContainer();
        final emitted = watch(container, 'task-1');
        async.flushMicrotasks();

        // Two refreshes in flight. The FIRST one to be started is the LAST to
        // answer, and it answers "no other tasks" — the state the world has
        // since left behind.
        final slowFirst = Completer<List<JournalEntity>>();
        final fastSecond = Completer<List<JournalEntity>>();
        var call = 0;
        when(
          () => mockJournalDb.getTasks(
            starredStatuses: any(named: 'starredStatuses'),
            taskStatuses: any(named: 'taskStatuses'),
            categoryIds: any(named: 'categoryIds'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) => call++ == 0 ? slowFirst.future : fastSecond.future);

        updateStream
          ..add({'a'})
          ..add({'b'});
        async.flushMicrotasks();

        fastSecond.complete([buildTask('task-1'), buildTask('task-2')]);
        async.flushMicrotasks();
        slowFirst.complete([buildTask('task-1')]);
        async.flushMicrotasks();

        expect(
          container.read(linkableTasksExistProvider('task-1')).value,
          isTrue,
          reason: 'the superseded query must not restore its stale answer',
        );
        expect(emitted.map((e) => e.value), [false, true]);
      });
    },
  );

  test(
    'a failed refresh keeps the last good answer rather than blanking a card '
    'the user is looking at',
    () {
      fakeAsync((async) {
        final container = makeContainer();
        final emitted = watch(container, 'task-1');
        async.flushMicrotasks();

        when(
          () => mockJournalDb.getTasks(
            starredStatuses: any(named: 'starredStatuses'),
            taskStatuses: any(named: 'taskStatuses'),
            categoryIds: any(named: 'categoryIds'),
            limit: any(named: 'limit'),
          ),
        ).thenThrow(Exception('db went away'));

        updateStream.add({'a'});
        async.flushMicrotasks();

        final state = container.read(linkableTasksExistProvider('task-1'));
        expect(state.hasError, isFalse);
        expect(state.value, isFalse);
        expect(emitted, hasLength(1), reason: 'only the initial resolution');
      });
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
    'every status counts as a link target — a finished task is a valid '
    '"duplicates" or "follows up on"',
    () async {
      final container = makeContainer();
      await container.read(linkableTasksExistProvider('task-1').future);

      final taskStatuses =
          verify(
                () => mockJournalDb.getTasks(
                  starredStatuses: any(named: 'starredStatuses'),
                  taskStatuses: captureAny(named: 'taskStatuses'),
                  categoryIds: any(named: 'categoryIds'),
                  limit: any(named: 'limit'),
                ),
              ).captured.single
              as List<String>;

      expect(taskStatuses, unorderedEquals(allTaskStatuses));
    },
  );

  test(
    'queries every category — including inactive ones — plus the '
    'uncategorized bucket; an empty list short-circuits the query builder '
    'to WHERE 1 = 0',
    () async {
      // An archived category is exactly the case `sortedCategories` drops. The
      // picker's full-text path resolves tasks through `getJournalEntitiesForIds`
      // with no category filter at all, so gating on the active-only set would
      // hide the whole card from someone whose only other task lives here.
      when(() => mockCache.categoriesById).thenReturn({
        'cat-1': buildCategory(id: 'cat-1', name: 'Work'),
        'cat-archived': buildCategory(
          id: 'cat-archived',
          name: 'Retired',
          active: false,
        ),
      });
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

      expect(
        categoryIds,
        unorderedEquals(<String>['cat-1', 'cat-archived', '']),
      );
    },
  );
}
