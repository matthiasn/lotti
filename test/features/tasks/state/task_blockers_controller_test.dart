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
  });
}
