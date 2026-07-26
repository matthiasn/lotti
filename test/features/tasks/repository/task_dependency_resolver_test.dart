import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/tasks/repository/task_dependency_resolver.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/entity_factories.dart';
import '../../../mocks/mocks.dart';

void main() {
  late MockJournalRepository journalRepository;
  late TaskDependencyResolver resolver;

  final baseDate = DateTime(2024, 9);

  EntryLink blocksLink({
    required String id,
    required String fromId,
    required String toId,
    DateTime? deletedAt,
  }) => EntryLink.blocks(
    id: id,
    fromId: fromId,
    toId: toId,
    createdAt: baseDate,
    updatedAt: baseDate,
    vectorClock: null,
    deletedAt: deletedAt,
  );

  setUp(() {
    journalRepository = MockJournalRepository();
    resolver = TaskDependencyResolver(journalRepository: journalRepository);
  });

  void stubLinks(Set<String> taskIds, List<EntryLink> links) {
    when(
      () => journalRepository.getTypedLinksForTaskIds(
        taskIds,
        linkTypes: {'BlocksLink'},
      ),
    ).thenAnswer((_) async => links);
  }

  void stubResolved(List<JournalEntity> entities) {
    when(
      () => journalRepository.getJournalEntitiesByIdsIncludingDeleted(any()),
    ).thenAnswer((_) async => entities);
  }

  group('TaskDependencyResolver.resolveBlockedStatus', () {
    test('empty taskIds short-circuits without querying either repository '
        'method', () async {
      final result = await resolver.resolveBlockedStatus(<String>{});

      expect(result, isEmpty);
      verifyNever(
        () => journalRepository.getTypedLinksForTaskIds(
          any(),
          linkTypes: any(named: 'linkTypes'),
        ),
      );
      verifyNever(
        () => journalRepository.getJournalEntitiesByIdsIncludingDeleted(any()),
      );
    });

    test(
      'one open, resolvable blocker resolves to a named ResolvedBlocker',
      () async {
        final blocker = TestTaskFactory.create(
          id: 'blocker',
          title: 'Blocker',
          categoryId: 'ops',
        );
        stubLinks(
          {'blocked'},
          [
            blocksLink(id: 'l1', fromId: 'blocker', toId: 'blocked'),
          ],
        );
        stubResolved([blocker]);

        final result = await resolver.resolveBlockedStatus({'blocked'});

        expect(result.keys, ['blocked']);
        expect(result['blocked'], [
          const ResolvedBlocker(
            taskId: 'blocker',
            title: 'Blocker',
            status: 'OPEN',
            categoryId: 'ops',
          ),
        ]);
        // The blocker's own category, not the blocked task's. The blocked-work
        // rule tells the model to schedule this blocker, and `draft_day_plan`
        // requires a categoryId per block — without this the model has to
        // guess, and guesses the category of the task it is blocking.
        expect(result['blocked']!.single.toJson()['categoryId'], 'ops');
      },
    );

    test('blocker is DONE — task absent from the result (released)', () async {
      final doneBlocker = TestTaskFactory.create(
        id: 'blocker',
        title: 'Done blocker',
        status: TaskStatus.done(id: 's', createdAt: baseDate, utcOffset: 0),
      );
      stubLinks(
        {'blocked'},
        [
          blocksLink(id: 'l1', fromId: 'blocker', toId: 'blocked'),
        ],
      );
      stubResolved([doneBlocker]);

      final result = await resolver.resolveBlockedStatus({'blocked'});

      expect(result, isEmpty);
    });

    test(
      'blocker is REJECTED — task absent from the result (released)',
      () async {
        final rejectedBlocker = TestTaskFactory.create(
          id: 'blocker',
          title: 'Rejected blocker',
          status: TaskStatus.rejected(
            id: 's',
            createdAt: baseDate,
            utcOffset: 0,
          ),
        );
        stubLinks(
          {'blocked'},
          [
            blocksLink(id: 'l1', fromId: 'blocker', toId: 'blocked'),
          ],
        );
        stubResolved([rejectedBlocker]);

        final result = await resolver.resolveBlockedStatus({'blocked'});

        expect(result, isEmpty);
      },
    );

    test(
      'blocker link is tombstoned (deletedAt set) — task absent (released)',
      () async {
        stubLinks(
          {'blocked'},
          [
            blocksLink(
              id: 'l1',
              fromId: 'blocker',
              toId: 'blocked',
              deletedAt: baseDate,
            ),
          ],
        );
        stubResolved(const []);

        final result = await resolver.resolveBlockedStatus({'blocked'});

        expect(result, isEmpty);
      },
    );

    test(
      'blocker id resolves to nothing — still blocked, per ADR 0042 §4',
      () async {
        stubLinks(
          {'blocked'},
          [
            blocksLink(id: 'l1', fromId: 'missing-blocker', toId: 'blocked'),
          ],
        );
        stubResolved(const []);

        final result = await resolver.resolveBlockedStatus({'blocked'});

        expect(result.keys, ['blocked']);
        expect(result['blocked'], [
          const ResolvedBlocker(taskId: 'missing-blocker'),
        ]);
        expect(result['blocked']!.single.isUnresolved, isTrue);
        expect(result['blocked']!.single.toJson(), {
          'taskId': 'missing-blocker',
        });
      },
    );

    test('mutual block: both tasks present, each naming the other', () async {
      final taskA = TestTaskFactory.create(id: 'task-a', title: 'Task A');
      final taskB = TestTaskFactory.create(id: 'task-b', title: 'Task B');
      stubLinks(
        {'task-a', 'task-b'},
        [
          blocksLink(id: 'a-blocked-by-b', fromId: 'task-b', toId: 'task-a'),
          blocksLink(id: 'b-blocked-by-a', fromId: 'task-a', toId: 'task-b'),
        ],
      );
      stubResolved([taskA, taskB]);

      final result = await resolver.resolveBlockedStatus({
        'task-a',
        'task-b',
      });

      expect(result.keys.toSet(), {'task-a', 'task-b'});
      expect(result['task-a']!.single.taskId, 'task-b');
      expect(result['task-b']!.single.taskId, 'task-a');
    });

    test(
      'direction guard: a blocks link where the queried task is fromId '
      '(blocks someone else) contributes nothing to its own entry',
      () async {
        stubLinks(
          {'blocked'},
          [
            blocksLink(id: 'l1', fromId: 'blocked', toId: 'other-task'),
          ],
        );
        stubResolved(const []);

        final result = await resolver.resolveBlockedStatus({'blocked'});

        expect(result, isEmpty);
      },
    );
  });

  group('ResolvedBlocker', () {
    test('equals another instance with the same fields', () {
      const a = ResolvedBlocker(taskId: 'x', title: 'X', status: 'OPEN');
      const b = ResolvedBlocker(taskId: 'x', title: 'X', status: 'OPEN');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('differs when any field differs', () {
      const base = ResolvedBlocker(taskId: 'x', title: 'X', status: 'OPEN');

      expect(
        base,
        isNot(const ResolvedBlocker(taskId: 'y', title: 'X', status: 'OPEN')),
      );
      expect(
        base,
        isNot(const ResolvedBlocker(taskId: 'x', title: 'Y', status: 'OPEN')),
      );
      expect(
        base,
        isNot(const ResolvedBlocker(taskId: 'x', title: 'X', status: 'DONE')),
      );
      expect(
        base,
        isNot(
          const ResolvedBlocker(
            taskId: 'x',
            title: 'X',
            status: 'OPEN',
            categoryId: 'ops',
          ),
        ),
      );
    });

    test('an unresolvable blocker carries no category to guess from', () {
      // The sync-gap case: the link exists but the task could not be loaded,
      // so there is no category to report. The entry still blocks.
      const unresolved = ResolvedBlocker(taskId: 'x');

      expect(unresolved.isUnresolved, isTrue);
      expect(unresolved.toJson(), {'taskId': 'x'});
    });
  });

  group('taskDependencyResolverProvider', () {
    test(
      'resolves a TaskDependencyResolver backed by journalRepositoryProvider',
      () {
        final mockRepo = MockJournalRepository();
        final container = ProviderContainer(
          overrides: [journalRepositoryProvider.overrideWithValue(mockRepo)],
        );
        addTearDown(container.dispose);

        final resolved = container.read(taskDependencyResolverProvider);

        expect(resolved.journalRepository, mockRepo);
      },
    );
  });
}
