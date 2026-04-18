// ignore_for_file: avoid_redundant_argument_values
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/daily_os/repository/day_plan_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  DayPlanEntry makePlan(DateTime date) {
    return DayPlanEntry(
      meta: Metadata(
        id: dayPlanId(date),
        createdAt: date,
        updatedAt: date,
        dateFrom: date,
        dateTo: date.add(const Duration(days: 1)),
      ),
      data: DayPlanData(
        planDate: date,
        status: const DayPlanStatus.draft(),
        plannedBlocks: const [],
      ),
    );
  }

  late MockJournalDb journalDb;
  late MockPersistenceLogic persistenceLogic;
  late MockUpdateNotifications updateNotifications;
  late DayPlanRepositoryImpl repository;

  setUp(() {
    journalDb = MockJournalDb();
    persistenceLogic = MockPersistenceLogic();
    updateNotifications = MockUpdateNotifications();
    repository = DayPlanRepositoryImpl(
      journalDb: journalDb,
      persistenceLogic: persistenceLogic,
      updateNotifications: updateNotifications,
    );
  });

  group('getDayPlan microtask coalescing', () {
    test(
      'collapses concurrent calls in the same microtask into one batch '
      'round-trip and returns the right plan for each date',
      () async {
        final d1 = DateTime(2026, 4, 1);
        final d2 = DateTime(2026, 4, 2);
        final d3 = DateTime(2026, 4, 3);
        final p1 = makePlan(d1);
        final p3 = makePlan(d3);

        when(() => journalDb.getDayPlansByIds(any())).thenAnswer(
          // Returns only p1 and p3 — d2 has no plan, verifying nulls flow.
          (_) async => [p1, p3],
        );

        // Fire three requests in the same synchronous sweep (simulating the
        // prefetch-window loop in time_history_header_widget).
        final futures = [
          repository.getDayPlan(d1),
          repository.getDayPlan(d2),
          repository.getDayPlan(d3),
        ];
        final results = await Future.wait(futures);

        expect(results[0], p1);
        expect(results[1], isNull);
        expect(results[2], p3);

        // Exactly one batch call against the DB for all three dates.
        final captured =
            verify(
                  () => journalDb.getDayPlansByIds(captureAny()),
                ).captured.single
                as Iterable<String>;
        expect(captured.toSet(), {
          dayPlanId(d1),
          dayPlanId(d2),
          dayPlanId(d3),
        });
        verifyNever(() => journalDb.getDayPlanById(any()));
      },
    );

    test('distinct microtask waves issue separate batch calls', () async {
      final d1 = DateTime(2026, 4, 5);
      final d2 = DateTime(2026, 4, 6);
      final p1 = makePlan(d1);
      final p2 = makePlan(d2);

      when(
        () => journalDb.getDayPlansByIds(any()),
      ).thenAnswer((invocation) async {
        final ids = (invocation.positionalArguments.first as Iterable<String>)
            .toSet();
        return [
          if (ids.contains(p1.meta.id)) p1,
          if (ids.contains(p2.meta.id)) p2,
        ];
      });

      final first = await repository.getDayPlan(d1);
      final second = await repository.getDayPlan(d2);

      expect(first, p1);
      expect(second, p2);
      verify(() => journalDb.getDayPlansByIds(any())).called(2);
    });

    test('requesting the same date twice hits the DB once', () async {
      final d = DateTime(2026, 4, 7);
      final plan = makePlan(d);
      when(
        () => journalDb.getDayPlansByIds(any()),
      ).thenAnswer((_) async => [plan]);

      final results = await Future.wait([
        repository.getDayPlan(d),
        repository.getDayPlan(d),
      ]);

      expect(results[0], plan);
      expect(results[1], plan);
      final captured =
          verify(
                () => journalDb.getDayPlansByIds(captureAny()),
              ).captured.single
              as Iterable<String>;
      expect(captured.toSet(), {dayPlanId(d)});
    });

    test(
      'batch error propagates to every caller waiting on that wave',
      () async {
        final d1 = DateTime(2026, 4, 8);
        final d2 = DateTime(2026, 4, 9);
        final failure = StateError('db blew up');
        when(
          () => journalDb.getDayPlansByIds(any()),
        ).thenThrow(failure);

        final f1 = repository.getDayPlan(d1);
        final f2 = repository.getDayPlan(d2);

        // Register both expectations before awaiting: the shared batch
        // completes both futures with the same error in one microtask,
        // so sequential awaits would leave the second one unhandled.
        await Future.wait([
          expectLater(f1, throwsA(same(failure))),
          expectLater(f2, throwsA(same(failure))),
        ]);
        verify(() => journalDb.getDayPlansByIds(any())).called(1);
      },
    );

    test(
      'a failed wave does not poison the next: the subsequent call succeeds',
      () async {
        final d1 = DateTime(2026, 4, 10);
        final d2 = DateTime(2026, 4, 11);
        final plan = makePlan(d2);

        var calls = 0;
        when(
          () => journalDb.getDayPlansByIds(any()),
        ).thenAnswer((_) async {
          calls += 1;
          if (calls == 1) throw StateError('transient');
          return [plan];
        });

        await expectLater(
          repository.getDayPlan(d1),
          throwsA(isA<StateError>()),
        );
        final second = await repository.getDayPlan(d2);

        expect(second, plan);
        expect(calls, 2);
      },
    );
  });
}
