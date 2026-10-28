// ignore_for_file: avoid_redundant_argument_values

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/history/domain/history_entry.dart';
import 'package:lotti/features/history/domain/history_filter.dart';
import 'package:lotti/features/history/state/history_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../history_test_bench.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late HistoryTestBench bench;

  setUp(() => bench = HistoryTestBench());
  tearDown(() => bench.close());

  List<String?> titlesOf(HistoryPage page) => [
    for (final item in page.items) item.title,
  ];

  group('record', () {
    test('appends a visit stamped with the clock', () async {
      final wrote = await withClock(
        Clock.fixed(DateTime(2026, 3, 15, 9, 30)),
        () => bench.service.record(taskTarget('t1')),
      );

      expect(wrote, isTrue);
      final row = await bench.db.latestEntry();
      expect(row?.kind, 'task');
      expect(row?.entityId, 't1');
      expect(row?.route, '/tasks/t1');
      expect(row?.visitedAt, DateTime(2026, 3, 15, 9, 30));
    });

    test('a repeat of the newest visit is not a new visit', () async {
      expect(await bench.service.record(taskTarget('t1')), isTrue);
      expect(await bench.service.record(taskTarget('t1')), isFalse);
      expect(await bench.service.record(taskTarget('t2')), isTrue);
      // Coming back after something else is a new visit again.
      expect(await bench.service.record(taskTarget('t1')), isTrue);

      final rows = await bench.db.entriesPage(limit: 10);
      expect(rows.map((r) => r.entityId), ['t1', 't2', 't1']);
    });

    test('the same entity through another route is the same visit', () async {
      await bench.service.record(taskTarget('t1'));
      final wrote = await bench.service.record(
        const HistoryTarget(
          kind: HistoryEntityKind.task,
          entityId: 't1',
          route: '/tasks/t1?from=link',
        ),
      );
      expect(wrote, isFalse);
    });

    test('two visits reported together compare against each other', () async {
      // Neither awaited before the other starts: the route and the desktop
      // selection both report the same task in one frame.
      final results = await Future.wait([
        bench.service.record(taskTarget('t1')),
        bench.service.record(taskTarget('t1')),
      ]);
      expect(results, [true, false]);
      expect(await bench.db.entriesPage(limit: 10), hasLength(1));
    });

    test(
      'a failed write reaches its caller and does not block the next',
      () async {
        final db = MockHistoryDb();
        var reads = 0;
        when(db.latestEntry).thenAnswer((_) async {
          if (reads++ == 0) throw StateError('disk full');
          return null;
        });
        when(
          () => db.appendEntry(
            kind: any(named: 'kind'),
            entityId: any(named: 'entityId'),
            route: any(named: 'route'),
            visitedAt: any(named: 'visitedAt'),
          ),
        ).thenAnswer((_) async => 1);
        final service = HistoryService(
          db: db,
          titleResolver: bench.titleResolver,
        );

        await expectLater(
          service.record(taskTarget('t1')),
          throwsA(isA<StateError>()),
        );
        expect(await service.record(taskTarget('t2')), isTrue);
        verify(
          () => db.appendEntry(
            kind: 'task',
            entityId: 't2',
            route: '/tasks/t2',
            visitedAt: any(named: 'visitedAt'),
          ),
        ).called(1);
      },
    );
  });

  group('page', () {
    test("lists newest first with each entity's current title", () async {
      bench
        ..putTask('t1', 'Write release notes')
        ..putTask('t2', 'Fix login bug');
      await bench.appendTaskVisit('t1', DateTime(2026, 3, 1));
      await bench.appendTaskVisit('t2', DateTime(2026, 3, 2));

      final page = await bench.service.page(const HistoryFilter());
      expect(titlesOf(page), ['Fix login bug', 'Write release notes']);
      expect(page.hasMore, isFalse);
    });

    test('a rename after the visit shows the new title', () async {
      bench.putTask('t1', 'Old name');
      await bench.appendTaskVisit('t1', DateTime(2026, 3, 1));
      bench.putTask('t1', 'New name');

      final page = await bench.service.page(const HistoryFilter());
      expect(titlesOf(page), ['New name']);
    });

    test('a deleted entity stays listed, with no title', () async {
      await bench.appendTaskVisit('gone', DateTime(2026, 3, 1));
      final page = await bench.service.page(const HistoryFilter());
      expect(page.items.single.isGone, isTrue);
    });

    test('pages of the given size, then reports the end', () async {
      for (var i = 0; i < 5; i++) {
        bench.putTask('t$i', 'Task $i');
        await bench.appendTaskVisit('t$i', DateTime(2026, 3, 1, i));
      }

      final first = await bench.service.page(const HistoryFilter(), limit: 2);
      final second = await bench.service.page(
        const HistoryFilter(),
        beforeId: first.nextBeforeId,
        limit: 2,
      );
      final third = await bench.service.page(
        const HistoryFilter(),
        beforeId: second.nextBeforeId,
        limit: 2,
      );

      expect(titlesOf(first), ['Task 4', 'Task 3']);
      expect(titlesOf(second), ['Task 2', 'Task 1']);
      expect(titlesOf(third), ['Task 0']);
      expect(first.hasMore, isTrue);
      expect(third.hasMore, isFalse);
    });

    test('the time window bounds the rows read', () async {
      bench
        ..putTask('old', 'Old task')
        ..putTask('recent', 'Recent task');
      await bench.appendTaskVisit('old', DateTime(2026, 3, 1));
      await bench.appendTaskVisit('recent', DateTime(2026, 3, 14));

      final page = await withClock(
        Clock.fixed(DateTime(2026, 3, 15, 12)),
        () => bench.service.page(
          const HistoryFilter(range: HistoryTimeRange.last7Days),
        ),
      );
      expect(titlesOf(page), ['Recent task']);
    });

    group('with a query', () {
      test('matches current titles, not the ones at visit time', () async {
        bench
          ..putTask('t1', 'Bug fix for login')
          ..putTask('t2', 'Write docs');
        await bench.appendTaskVisit('t1', DateTime(2026, 3, 1));
        await bench.appendTaskVisit('t2', DateTime(2026, 3, 2));
        bench.putTask('t2', 'Fix the bug in docs');

        final page = await bench.service.page(
          const HistoryFilter(query: 'bug fix'),
        );
        expect(titlesOf(page), ['Fix the bug in docs', 'Bug fix for login']);
      });

      test('gone entities never match', () async {
        await bench.appendTaskVisit('gone', DateTime(2026, 3, 1));
        final page = await bench.service.page(const HistoryFilter(query: 'a'));
        expect(page.items, isEmpty);
        expect(page.hasMore, isFalse);
      });

      test('reads past a batch with no match to fill the page', () async {
        bench
          ..putTask('match', 'Needle')
          ..putTask('noise', 'Hay');
        await bench.appendTaskVisit('match', DateTime(2026, 3, 1));
        // One full batch of non-matches above the one match.
        for (var i = 0; i < HistoryService.searchBatchSize; i++) {
          await bench.appendTaskVisit('noise', DateTime(2026, 3, 2));
        }

        final page = await bench.service.page(
          const HistoryFilter(query: 'needle'),
        );
        expect(titlesOf(page), ['Needle']);
        expect(page.hasMore, isFalse);
      });

      test('stops at the page size and resumes where it stopped', () async {
        for (var i = 0; i < 3; i++) {
          bench.putTask('t$i', 'Bug $i');
          await bench.appendTaskVisit('t$i', DateTime(2026, 3, 1, i));
        }
        const filter = HistoryFilter(query: 'bug');

        final first = await bench.service.page(filter, limit: 2);
        final second = await bench.service.page(
          filter,
          beforeId: first.nextBeforeId,
          limit: 2,
        );
        expect(titlesOf(first), ['Bug 2', 'Bug 1']);
        expect(titlesOf(second), ['Bug 0']);
        expect(second.hasMore, isFalse);
      });
    });
  });

  test('delete removes the visit for good', () async {
    bench.putTask('t1', 'Keep');
    final drop = await bench.appendTaskVisit('t1', DateTime(2026, 3, 1));
    final keep = await bench.appendTaskVisit('t1', DateTime(2026, 3, 2));

    await bench.service.delete(drop);

    final page = await bench.service.page(const HistoryFilter());
    expect(page.items.map((item) => item.entry.id), [keep]);
  });
}
