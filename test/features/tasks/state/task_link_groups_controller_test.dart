import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/tasks/state/task_link_groups_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/entity_factories.dart';
import '../../../mocks/mocks.dart';

void main() {
  late MockJournalRepository journalRepository;
  late MockUpdateNotifications updateNotifications;
  late StreamController<Set<String>> updateStreamController;

  const currentTaskId = 'current-task';
  final baseDate = DateTime(2024, 8);

  EntryLink blocksLink({
    required String id,
    required String fromId,
    required String toId,
    DateTime? createdAt,
  }) => EntryLink.blocks(
    id: id,
    fromId: fromId,
    toId: toId,
    createdAt: createdAt ?? baseDate,
    updatedAt: createdAt ?? baseDate,
    vectorClock: null,
  );

  EntryLink basicLink({
    required String id,
    required String fromId,
    required String toId,
    DateTime? createdAt,
  }) => EntryLink.basic(
    id: id,
    fromId: fromId,
    toId: toId,
    createdAt: createdAt ?? baseDate,
    updatedAt: createdAt ?? baseDate,
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

  group('TaskLinkGroupsController', () {
    test('returns empty groups when there are no links', () async {
      when(
        () => journalRepository.getTypedLinksForTaskIds(
          {currentTaskId},
          linkTypes: any(named: 'linkTypes'),
        ),
      ).thenAnswer((_) async => <EntryLink>[]);

      final container = buildContainer();
      addTearDown(container.dispose);
      final result = await container.read(
        taskLinkGroupsControllerProvider(currentTaskId).future,
      );

      expect(result.flat, isEmpty);
      expect(result.typed, isEmpty);
      expect(result.totalCount, 0);
    });

    test(
      'buckets a basic link into flat and a blocks link into typed',
      () async {
        final blockerTask = TestTaskFactory.create(
          id: 'blocker',
          title: 'Fix the blocker',
        );
        final relatedTask = TestTaskFactory.create(
          id: 'related',
          title: 'Just related',
        );

        when(
          () => journalRepository.getTypedLinksForTaskIds(
            {currentTaskId},
            linkTypes: any(named: 'linkTypes'),
          ),
        ).thenAnswer(
          (_) async => [
            blocksLink(
              id: 'link-blocks',
              fromId: 'blocker',
              toId: currentTaskId,
            ),
            basicLink(id: 'link-basic', fromId: currentTaskId, toId: 'related'),
          ],
        );
        when(
          () => journalRepository.getJournalEntitiesByIds(any()),
        ).thenAnswer((_) async => [blockerTask, relatedTask]);

        final container = buildContainer();
        addTearDown(container.dispose);
        final result = await container.read(
          taskLinkGroupsControllerProvider(currentTaskId).future,
        );

        expect(result.flat, hasLength(1));
        expect(result.flat.single.task.meta.id, 'related');
        expect(result.flat.single.direction, TaskLinkDirection.outgoing);
        expect(result.flat.single.kind, TaskLinkKind.basic);

        expect(result.typed, hasLength(1));
        expect(result.typed.single.task.meta.id, 'blocker');
        expect(result.typed.single.direction, TaskLinkDirection.incoming);
        expect(result.typed.single.kind, TaskLinkKind.blocks);
      },
    );

    test(
      'a pair holding both a basic and a typed link lands in both buckets',
      () async {
        final otherTask = TestTaskFactory.create(id: 'other', title: 'Other');

        when(
          () => journalRepository.getTypedLinksForTaskIds(
            {currentTaskId},
            linkTypes: any(named: 'linkTypes'),
          ),
        ).thenAnswer(
          (_) async => [
            basicLink(id: 'basic-1', fromId: currentTaskId, toId: 'other'),
            blocksLink(id: 'blocks-1', fromId: currentTaskId, toId: 'other'),
          ],
        );
        when(
          () => journalRepository.getJournalEntitiesByIds(any()),
        ).thenAnswer((_) async => [otherTask]);

        final container = buildContainer();
        addTearDown(container.dispose);
        final result = await container.read(
          taskLinkGroupsControllerProvider(currentTaskId).future,
        );

        expect(result.flat, hasLength(1));
        expect(result.typed, hasLength(1));
        expect(result.totalCount, 2);
      },
    );

    test('drops a link whose other id does not resolve to a Task', () async {
      when(
        () => journalRepository.getTypedLinksForTaskIds(
          {currentTaskId},
          linkTypes: any(named: 'linkTypes'),
        ),
      ).thenAnswer(
        (_) async => [
          basicLink(id: 'basic-1', fromId: currentTaskId, toId: 'missing'),
        ],
      );
      when(
        () => journalRepository.getJournalEntitiesByIds(any()),
      ).thenAnswer((_) async => []);

      final container = buildContainer();
      addTearDown(container.dispose);
      final result = await container.read(
        taskLinkGroupsControllerProvider(currentTaskId).future,
      );

      expect(result.flat, isEmpty);
      expect(result.typed, isEmpty);
    });

    test('drops a tombstoned link', () async {
      final otherTask = TestTaskFactory.create(id: 'other', title: 'Other');
      when(
        () => journalRepository.getTypedLinksForTaskIds(
          {currentTaskId},
          linkTypes: any(named: 'linkTypes'),
        ),
      ).thenAnswer(
        (_) async => [
          EntryLink.basic(
            id: 'tombstoned',
            fromId: currentTaskId,
            toId: 'other',
            createdAt: baseDate,
            updatedAt: baseDate,
            vectorClock: null,
            deletedAt: baseDate,
          ),
        ],
      );
      when(
        () => journalRepository.getJournalEntitiesByIds(any()),
      ).thenAnswer((_) async => [otherTask]);

      final container = buildContainer();
      addTearDown(container.dispose);
      final result = await container.read(
        taskLinkGroupsControllerProvider(currentTaskId).future,
      );

      expect(result.flat, isEmpty);
      expect(result.typed, isEmpty);
    });

    test('sorts entries by createdAt descending, newest first', () async {
      final taskA = TestTaskFactory.create(id: 'a', title: 'A');
      final taskB = TestTaskFactory.create(id: 'b', title: 'B');

      when(
        () => journalRepository.getTypedLinksForTaskIds(
          {currentTaskId},
          linkTypes: any(named: 'linkTypes'),
        ),
      ).thenAnswer(
        (_) async => [
          basicLink(
            id: 'older',
            fromId: currentTaskId,
            toId: 'a',
            createdAt: baseDate,
          ),
          basicLink(
            id: 'newer',
            fromId: currentTaskId,
            toId: 'b',
            createdAt: baseDate.add(const Duration(days: 1)),
          ),
        ],
      );
      when(
        () => journalRepository.getJournalEntitiesByIds(any()),
      ).thenAnswer((_) async => [taskA, taskB]);

      final container = buildContainer();
      addTearDown(container.dispose);
      final result = await container.read(
        taskLinkGroupsControllerProvider(currentTaskId).future,
      );

      expect(result.flat.map((e) => e.task.meta.id), ['b', 'a']);
    });

    test('refetches when a notification intersects watched ids', () async {
      final blockerTask = TestTaskFactory.create(
        id: 'blocker',
        title: 'Blocker',
      );
      var callCount = 0;
      when(
        () => journalRepository.getTypedLinksForTaskIds(
          {currentTaskId},
          linkTypes: any(named: 'linkTypes'),
        ),
      ).thenAnswer((_) async {
        callCount++;
        return [
          blocksLink(id: 'link-1', fromId: 'blocker', toId: currentTaskId),
        ];
      });
      when(
        () => journalRepository.getJournalEntitiesByIds(any()),
      ).thenAnswer((_) async => [blockerTask]);

      final container = buildContainer();
      addTearDown(container.dispose);
      await container.read(
        taskLinkGroupsControllerProvider(currentTaskId).future,
      );
      expect(callCount, 1);

      updateStreamController.add({'blocker'});
      await pumpEventQueue();

      expect(callCount, 2);
    });

    test('does not refetch on an unrelated notification', () async {
      var callCount = 0;
      when(
        () => journalRepository.getTypedLinksForTaskIds(
          {currentTaskId},
          linkTypes: any(named: 'linkTypes'),
        ),
      ).thenAnswer((_) async {
        callCount++;
        return <EntryLink>[];
      });

      final container = buildContainer();
      addTearDown(container.dispose);
      await container.read(
        taskLinkGroupsControllerProvider(currentTaskId).future,
      );
      expect(callCount, 1);

      updateStreamController.add({'totally-unrelated-id'});
      await pumpEventQueue();

      expect(callCount, 1);
    });
  });
}
