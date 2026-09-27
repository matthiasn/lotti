import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/tasks/state/task_blockers_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/entity_factories.dart';
import '../../../mocks/mocks.dart';

void main() {
  late MockJournalRepository journalRepository;
  late MockUpdateNotifications updateNotifications;
  late StreamController<Set<String>> updateStreamController;

  const blockedTaskId = 'blocked-task';
  final baseDate = DateTime(2024, 9);

  EntryLink blocksLink({
    required String id,
    required String fromId,
    required String toId,
  }) => EntryLink.blocks(
    id: id,
    fromId: fromId,
    toId: toId,
    createdAt: baseDate,
    updatedAt: baseDate,
    vectorClock: null,
  );

  setUp(() {
    journalRepository = MockJournalRepository();
    updateNotifications = MockUpdateNotifications();
    updateStreamController = StreamController<Set<String>>.broadcast();

    when(
      () => updateNotifications.updateStream,
    ).thenAnswer((_) => updateStreamController.stream);

    getIt.allowReassignment = true;
    getIt.registerSingleton<UpdateNotifications>(updateNotifications);
  });

  tearDown(() async {
    await updateStreamController.close();
    getIt.unregister<UpdateNotifications>();
  });

  ProviderContainer buildContainer() => ProviderContainer(
    overrides: [journalRepositoryProvider.overrideWithValue(journalRepository)],
  );

  void stubBlocksLinks(List<EntryLink> links) {
    when(
      () => journalRepository.getTypedLinksForTaskIds(
        {blockedTaskId},
        linkTypes: {'BlocksLink'},
      ),
    ).thenAnswer((_) async => links);
  }

  void stubResolved(List<JournalEntity> entities) {
    when(
      () => journalRepository.getJournalEntitiesByIdsIncludingDeleted(any()),
    ).thenAnswer((_) async => entities);
  }

  group('TaskBlockersController', () {
    test('reports not blocked when there are no blocks links', () async {
      stubBlocksLinks([]);

      final container = buildContainer();
      addTearDown(container.dispose);
      final result = await container.read(
        taskBlockersControllerProvider(blockedTaskId).future,
      );

      expect(result.isBlocked, isFalse);
      expect(result.openBlockers, isEmpty);
      expect(result.unresolvedCount, 0);
    });

    test('includes an open blocker task', () async {
      final blocker = TestTaskFactory.create(id: 'blocker', title: 'Blocker');
      stubBlocksLinks([
        blocksLink(id: 'l1', fromId: 'blocker', toId: blockedTaskId),
      ]);
      stubResolved([blocker]);

      final container = buildContainer();
      addTearDown(container.dispose);
      final result = await container.read(
        taskBlockersControllerProvider(blockedTaskId).future,
      );

      expect(result.isBlocked, isTrue);
      expect(result.openBlockers.map((t) => t.meta.id), ['blocker']);
      expect(result.unresolvedCount, 0);
    });

    test('excludes a tombstoned blocker (releases the dependent)', () async {
      final blockerTask = TestTaskFactory.create(id: 'blocker', title: 'Gone');
      final tombstoned = blockerTask.copyWith(
        meta: blockerTask.meta.copyWith(deletedAt: baseDate),
      );
      stubBlocksLinks([
        blocksLink(id: 'l1', fromId: 'blocker', toId: blockedTaskId),
      ]);
      stubResolved([tombstoned]);

      final container = buildContainer();
      addTearDown(container.dispose);
      final result = await container.read(
        taskBlockersControllerProvider(blockedTaskId).future,
      );

      expect(result.isBlocked, isFalse);
      expect(result.openBlockers, isEmpty);
      expect(result.unresolvedCount, 0);
    });

    test('excludes a DONE blocker (releases the dependent)', () async {
      final doneStatus = TaskStatus.done(
        id: 'status-done',
        createdAt: baseDate,
        utcOffset: 0,
      );
      final doneBlocker = TestTaskFactory.create(
        id: 'blocker',
        title: 'Done blocker',
        status: doneStatus,
      );
      stubBlocksLinks([
        blocksLink(id: 'l1', fromId: 'blocker', toId: blockedTaskId),
      ]);
      stubResolved([doneBlocker]);

      final container = buildContainer();
      addTearDown(container.dispose);
      final result = await container.read(
        taskBlockersControllerProvider(blockedTaskId).future,
      );

      expect(result.isBlocked, isFalse);
      expect(result.openBlockers, isEmpty);
    });

    test('excludes a REJECTED blocker (releases the dependent)', () async {
      final rejectedStatus = TaskStatus.rejected(
        id: 'status-rejected',
        createdAt: baseDate,
        utcOffset: 0,
      );
      final rejectedBlocker = TestTaskFactory.create(
        id: 'blocker',
        title: 'Rejected blocker',
        status: rejectedStatus,
      );
      stubBlocksLinks([
        blocksLink(id: 'l1', fromId: 'blocker', toId: blockedTaskId),
      ]);
      stubResolved([rejectedBlocker]);

      final container = buildContainer();
      addTearDown(container.dispose);
      final result = await container.read(
        taskBlockersControllerProvider(blockedTaskId).future,
      );

      expect(result.isBlocked, isFalse);
      expect(result.openBlockers, isEmpty);
    });

    test(
      'counts an unresolvable blocker id and stays conservatively blocked',
      () async {
        stubBlocksLinks([
          blocksLink(id: 'l1', fromId: 'missing-blocker', toId: blockedTaskId),
        ]);
        stubResolved([]);

        final container = buildContainer();
        addTearDown(container.dispose);
        final result = await container.read(
          taskBlockersControllerProvider(blockedTaskId).future,
        );

        expect(result.isBlocked, isTrue);
        expect(result.openBlockers, isEmpty);
        expect(result.unresolvedCount, 1);
      },
    );

    test('ignores a blocks link in the opposite direction (this task blocks '
        'the other one, not vice versa)', () async {
      stubBlocksLinks([
        blocksLink(id: 'l1', fromId: blockedTaskId, toId: 'other-task'),
      ]);
      stubResolved([]);

      final container = buildContainer();
      addTearDown(container.dispose);
      final result = await container.read(
        taskBlockersControllerProvider(blockedTaskId).future,
      );

      expect(result.isBlocked, isFalse);
    });

    test('mutual block: two independent provider instances both resolve '
        'without hanging', () async {
      const taskA = 'task-a';
      const taskB = 'task-b';
      final blockerA = TestTaskFactory.create(id: taskA, title: 'A');
      final blockerB = TestTaskFactory.create(id: taskB, title: 'B');

      when(
        () => journalRepository.getTypedLinksForTaskIds(
          {taskA},
          linkTypes: {'BlocksLink'},
        ),
      ).thenAnswer(
        (_) async => [
          blocksLink(id: 'a-blocked-by-b', fromId: taskB, toId: taskA),
        ],
      );
      when(
        () => journalRepository.getTypedLinksForTaskIds(
          {taskB},
          linkTypes: {'BlocksLink'},
        ),
      ).thenAnswer(
        (_) async => [
          blocksLink(id: 'b-blocked-by-a', fromId: taskA, toId: taskB),
        ],
      );
      when(
        () =>
            journalRepository.getJournalEntitiesByIdsIncludingDeleted({taskB}),
      ).thenAnswer((_) async => [blockerB]);
      when(
        () =>
            journalRepository.getJournalEntitiesByIdsIncludingDeleted({taskA}),
      ).thenAnswer((_) async => [blockerA]);

      final container = buildContainer();
      addTearDown(container.dispose);

      final resultA = await container.read(
        taskBlockersControllerProvider(taskA).future,
      );
      final resultB = await container.read(
        taskBlockersControllerProvider(taskB).future,
      );

      expect(resultA.openBlockers.map((t) => t.meta.id), [taskB]);
      expect(resultB.openBlockers.map((t) => t.meta.id), [taskA]);
    });

    test(
      'refetches and updates state when a watched id is affected and the '
      'result actually changed',
      () async {
        final blocker = TestTaskFactory.create(id: 'blocker', title: 'Blocker');
        final doneStatus = TaskStatus.done(
          id: 'status-done',
          createdAt: baseDate,
          utcOffset: 0,
        );
        stubBlocksLinks([
          blocksLink(id: 'l1', fromId: 'blocker', toId: blockedTaskId),
        ]);
        // First fetch sees an open blocker; the notification-triggered
        // refetch sees it closed — a real state change, not just a re-run.
        var closed = false;
        when(
          () =>
              journalRepository.getJournalEntitiesByIdsIncludingDeleted(any()),
        ).thenAnswer(
          (_) async => [
            if (closed)
              blocker.copyWith(data: blocker.data.copyWith(status: doneStatus))
            else
              blocker,
          ],
        );

        final container = buildContainer();
        addTearDown(container.dispose);
        final initial = await container.read(
          taskBlockersControllerProvider(blockedTaskId).future,
        );
        expect(initial.isBlocked, isTrue);

        closed = true;
        updateStreamController.add({'blocker'});
        await pumpEventQueue();

        expect(
          container
              .read(taskBlockersControllerProvider(blockedTaskId))
              .value
              ?.isBlocked,
          isFalse,
        );
      },
    );

    test('does not refetch on an unrelated notification', () async {
      var callCount = 0;
      when(
        () => journalRepository.getTypedLinksForTaskIds(
          {blockedTaskId},
          linkTypes: {'BlocksLink'},
        ),
      ).thenAnswer((_) async {
        callCount++;
        return <EntryLink>[];
      });

      final container = buildContainer();
      addTearDown(container.dispose);
      await container.read(
        taskBlockersControllerProvider(blockedTaskId).future,
      );
      expect(callCount, 1);

      updateStreamController.add({'totally-unrelated-id'});
      await pumpEventQueue();

      expect(callCount, 1);
    });
  });

  group('TaskBlockersResult', () {
    test('equals another result with the same fields', () {
      final blocker = TestTaskFactory.create(id: 'blocker', title: 'Blocker');
      const a = TaskBlockersResult.empty;
      const b = TaskBlockersResult.empty;
      expect(a, b);
      expect(a.hashCode, b.hashCode);

      final withBlocker1 = TaskBlockersResult(
        openBlockers: [blocker],
        unresolvedCount: 1,
      );
      final withBlocker2 = TaskBlockersResult(
        openBlockers: [blocker],
        unresolvedCount: 1,
      );
      expect(withBlocker1, withBlocker2);
      expect(withBlocker1.hashCode, withBlocker2.hashCode);
    });

    test('differs when openBlockers or unresolvedCount differ', () {
      final blocker = TestTaskFactory.create(id: 'blocker', title: 'Blocker');
      final withBlocker = TaskBlockersResult(
        openBlockers: [blocker],
        unresolvedCount: 0,
      );
      expect(withBlocker, isNot(TaskBlockersResult.empty));
      expect(
        withBlocker,
        isNot(TaskBlockersResult(openBlockers: [blocker], unresolvedCount: 1)),
      );
    });

    test(
      'differs when the blockers on a cycle differ, whatever their order',
      () {
        final blocker = TestTaskFactory.create(id: 'blocker', title: 'Blocker');
        TaskBlockersResult result(Set<String> cycle) => TaskBlockersResult(
          openBlockers: [blocker],
          unresolvedCount: 0,
          cycleBlockerIds: cycle,
        );

        expect(result({'blocker'}).inCycle, isTrue);
        expect(result({}).inCycle, isFalse);
        expect(result({'blocker'}), isNot(result({})));
        expect(result({'a', 'b'}), result({'b', 'a'}));
        expect(result({'a', 'b'}).hashCode, result({'b', 'a'}).hashCode);
      },
    );
  });

  group('TaskBlockersController cycles (ADR 0106)', () {
    // blocked-task -> middle -> blocker -> blocked-task: each waits on the
    // one before it.
    final links = [
      blocksLink(id: 'l1', fromId: 'blocker', toId: blockedTaskId),
      blocksLink(id: 'l2', fromId: blockedTaskId, toId: 'middle'),
      blocksLink(id: 'l3', fromId: 'middle', toId: 'blocker'),
    ];

    void stubCycle(Map<String, JournalEntity> tasks) {
      when(
        () => journalRepository.getTypedLinksForTaskIds(
          any(),
          linkTypes: {'BlocksLink'},
        ),
      ).thenAnswer((invocation) async {
        final ids = invocation.positionalArguments.first as Set<String>;
        return [
          for (final link in links)
            if (ids.contains(link.fromId) || ids.contains(link.toId)) link,
        ];
      });
      when(
        () => journalRepository.getJournalEntitiesByIdsIncludingDeleted(any()),
      ).thenAnswer((invocation) async {
        final ids = invocation.positionalArguments.first as Iterable<String>;
        return [for (final id in ids) ?tasks[id]];
      });
    }

    test(
      'reports a blocker the task waits on through another task, and '
      'refetches when that other task changes',
      () async {
        final blocker = TestTaskFactory.create(id: 'blocker', title: 'B');
        final middle = TestTaskFactory.create(id: 'middle', title: 'M');
        final tasks = <String, JournalEntity>{
          blockedTaskId: TestTaskFactory.create(id: blockedTaskId),
          'blocker': blocker,
          'middle': middle,
        };
        stubCycle(tasks);

        final container = buildContainer();
        addTearDown(container.dispose);
        final initial = await container.read(
          taskBlockersControllerProvider(blockedTaskId).future,
        );
        expect(initial.cycleBlockerIds, {'blocker'});
        expect(initial.openBlockers.map((t) => t.meta.id), ['blocker']);

        // Closing the middle task breaks the cycle; it is not a blocker of
        // this task, yet the page must hear about it.
        tasks['middle'] = middle.copyWith(
          data: middle.data.copyWith(
            status: TaskStatus.done(
              id: 'status-done',
              createdAt: baseDate,
              utcOffset: 0,
            ),
          ),
        );
        updateStreamController.add({'middle'});
        await pumpEventQueue();

        final after = container
            .read(taskBlockersControllerProvider(blockedTaskId))
            .value;
        expect(after?.inCycle, isFalse);
        expect(after?.isBlocked, isTrue);
      },
    );
  });
}
