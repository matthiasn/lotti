import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/features/tasks/repository/blocks_cycles.dart';
import 'package:lotti/features/tasks/repository/task_dependency_resolver.dart';
import 'package:lotti/features/tasks/state/task_blockers_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/services/metadata_service.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../database/test_utils.dart';
import '../../../helpers/entity_factories.dart';
import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

part 'task_link_graph_model_conformance.dart';

void main() {
  late MockJournalRepository repository;

  final baseDate = DateTime(2024, 9);

  EntryLink blocks(String fromId, String toId, {DateTime? deletedAt}) =>
      EntryLink.blocks(
        id: '$fromId-blocks-$toId',
        fromId: fromId,
        toId: toId,
        createdAt: baseDate,
        updatedAt: baseDate,
        vectorClock: null,
        deletedAt: deletedAt,
      );

  Task task(String id, {TaskStatus? status}) =>
      TestTaskFactory.create(id: id, title: id, status: status);

  final done = TaskStatus.done(id: 'done', createdAt: baseDate, utcOffset: 0);

  /// Serves [links] and [entities] the way the journal does: a link for
  /// every task it touches, and the entities asked for that exist.
  void stubGraph(List<EntryLink> links, List<JournalEntity> entities) {
    when(
      () => repository.getTypedLinksForTaskIds(
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
      () => repository.getJournalEntitiesByIdsIncludingDeleted(any()),
    ).thenAnswer((invocation) async {
      final ids = (invocation.positionalArguments.first as Iterable<String>)
          .toSet();
      return [
        for (final entity in entities)
          if (ids.contains(entity.id)) entity,
      ];
    });
  }

  setUp(() {
    repository = MockJournalRepository();
  });

  group('blockerReleases', () {
    test('only a deleted or closed task releases what it blocks', () {
      final deleted = task('deleted');
      expect(blockerReleases(task('open')), isFalse);
      expect(blockerReleases(task('done', status: done)), isTrue);
      expect(
        blockerReleases(
          deleted.copyWith(meta: deleted.meta.copyWith(deletedAt: baseDate)),
        ),
        isTrue,
      );
      // A missing blocker, or one that is not a task, keeps blocking.
      expect(blockerReleases(null), isFalse);
      expect(
        blockerReleases(TestProjectFactory.create(id: 'project')),
        isFalse,
      );
    });
  });

  group('findBlockersInCycle', () {
    test('reads nothing when no task has a blocker', () async {
      final cycles = await findBlockersInCycle(
        repository,
        blockersByTask: {'a': {}},
      );

      expect(cycles.inCycle, isEmpty);
      expect(cycles.visited, isEmpty);
      verifyNever(
        () => repository.getJournalEntitiesByIdsIncludingDeleted(any()),
      );
    });

    test(
      'reports the blocker of each task on a two-task cycle, the one that '
      'two devices close by each writing one direction',
      () async {
        stubGraph([blocks('a', 'b'), blocks('b', 'a')], [task('a'), task('b')]);

        final cycles = await findBlockersInCycle(
          repository,
          blockersByTask: {
            'a': {'b'},
            'b': {'a'},
          },
        );

        expect(cycles.of('a'), {'b'});
        expect(cycles.of('b'), {'a'});
        expect(cycles.visited, {'a', 'b'});
      },
    );

    test(
      'follows a cycle through other tasks, and does not mark a blocker '
      'that is not on it',
      () async {
        // a -> b -> c -> a, and d blocks a from outside the cycle.
        stubGraph(
          [
            blocks('a', 'b'),
            blocks('b', 'c'),
            blocks('c', 'a'),
            blocks('d', 'a'),
          ],
          [task('a'), task('b'), task('c'), task('d')],
        );

        final cycles = await findBlockersInCycle(
          repository,
          blockersByTask: {
            'a': {'c', 'd'},
          },
        );

        expect(cycles.of('a'), {'c'});
        expect(cycles.visited, {'a', 'b', 'c'});
      },
    );

    test(
      'a closed task on the cycle breaks it: its links block nothing',
      () async {
        stubGraph(
          [blocks('a', 'b'), blocks('b', 'c'), blocks('c', 'a')],
          [task('a'), task('b', status: done), task('c')],
        );

        final cycles = await findBlockersInCycle(
          repository,
          blockersByTask: {
            'a': {'c'},
          },
        );

        expect(cycles.inCycle, isEmpty);
      },
    );

    test('a task that is closed itself is on no cycle', () async {
      stubGraph(
        [blocks('a', 'b'), blocks('b', 'a')],
        [task('a', status: done), task('b')],
      );

      final cycles = await findBlockersInCycle(
        repository,
        blockersByTask: {
          'a': {'b'},
        },
      );

      expect(cycles.inCycle, isEmpty);
      verifyNever(
        () => repository.getTypedLinksForTaskIds(
          any(),
          linkTypes: {'BlocksLink'},
        ),
      );
    });

    test(
      'a removed link carries no cycle, and a blocker that has not synced '
      'yet keeps its links',
      () async {
        // a -> m -> e -> a runs through m, which is missing here. The path
        // a -> c -> d -> a is broken: a's link to c was removed.
        stubGraph(
          [
            blocks('a', 'm'),
            blocks('m', 'e'),
            blocks('e', 'a'),
            blocks('a', 'c', deletedAt: baseDate),
            blocks('c', 'd'),
            blocks('d', 'a'),
          ],
          [task('a'), task('c'), task('d'), task('e')],
        );

        final cycles = await findBlockersInCycle(
          repository,
          blockersByTask: {
            'a': {'e', 'd'},
          },
        );

        expect(cycles.of('a'), {'e'});
        expect(cycles.visited, {'a', 'm', 'e'});
      },
    );

    test('follows a chain of any length, one read per hop', () async {
      // t0 -> t1 -> ... -> t99 -> t0: longer than any depth cap would allow.
      const length = 100;
      stubGraph(
        [
          for (var i = 0; i < length; i++)
            blocks('t$i', 't${(i + 1) % length}'),
        ],
        [for (var i = 0; i < length; i++) task('t$i')],
      );

      final cycles = await findBlockersInCycle(
        repository,
        blockersByTask: {
          't0': {'t${length - 1}'},
        },
      );

      expect(cycles.of('t0'), {'t${length - 1}'});
      verify(
        () => repository.getJournalEntitiesByIdsIncludingDeleted(any()),
      ).called(length);
    });
  });

  _registerTaskLinkGraphConformance();
}
