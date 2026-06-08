import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/daily_os/repository/day_plan_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(registerAllFallbackValues);

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

  // Wires the new-plan branch: getDayPlanById returns null so save() routes
  // through createDbEntity. Pass [throws] to make createDbEntity fail.
  void stubCreateBranch(DayPlanEntry plan, {Object? throws}) {
    when(
      () => journalDb.getDayPlanById(plan.meta.id),
    ).thenAnswer((_) async => null);
    final createStub = when(() => persistenceLogic.createDbEntity(plan));
    if (throws != null) {
      createStub.thenThrow(throws);
    } else {
      createStub.thenAnswer((_) async => true);
    }
  }

  // Wires the update branch: getDayPlanById returns [original] so save()
  // routes through updateMetadata + updateDbEntity. updateMetadata yields
  // [updatedMeta]. Pass [throws] to make updateDbEntity fail.
  void stubUpdateBranch(
    DayPlanEntry original,
    Metadata updatedMeta, {
    Object? throws,
  }) {
    when(
      () => journalDb.getDayPlanById(original.meta.id),
    ).thenAnswer((_) async => original);
    when(
      () => persistenceLogic.updateMetadata(original.meta),
    ).thenAnswer((_) async => updatedMeta);
    final updateStub = when(() => persistenceLogic.updateDbEntity(any()));
    if (throws != null) {
      updateStub.thenThrow(throws);
    } else {
      updateStub.thenAnswer((_) async => true);
    }
  }

  group('getDayPlan microtask coalescing', () {
    test(
      'collapses concurrent calls in the same microtask into one batch '
      'round-trip and returns the right plan for each date',
      () async {
        final d1 = DateTime(2026, 4);
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

  group('save', () {
    test(
      'creates a new plan when getDayPlanById returns null',
      () async {
        final date = DateTime(2024, 3, 15);
        final plan = makePlan(date);

        stubCreateBranch(plan);

        final result = await repository.save(plan);

        expect(result, plan);
        verify(() => journalDb.getDayPlanById(plan.meta.id)).called(1);
        verify(() => persistenceLogic.createDbEntity(plan)).called(1);
        verifyNever(() => persistenceLogic.updateMetadata(plan.meta));
        verifyNever(() => persistenceLogic.updateDbEntity(plan));
      },
    );

    test(
      'updates existing plan with refreshed metadata when getDayPlanById returns a plan',
      () async {
        final date = DateTime(2024, 3, 16);
        final original = makePlan(date);
        final updatedMeta = original.meta.copyWith(
          updatedAt: DateTime(2024, 3, 16, 12),
        );
        final expectedResult = original.copyWith(meta: updatedMeta);

        stubUpdateBranch(original, updatedMeta);

        final result = await repository.save(original);

        expect(result.meta, updatedMeta);
        expect(result.data, original.data);
        verify(() => journalDb.getDayPlanById(original.meta.id)).called(1);
        verify(() => persistenceLogic.updateMetadata(original.meta)).called(1);
        verify(() => persistenceLogic.updateDbEntity(expectedResult)).called(1);
        verifyNever(() => persistenceLogic.createDbEntity(original));
      },
    );

    test(
      'update path: returned plan reflects the updated metadata, not the original',
      () async {
        final date = DateTime(2024, 3, 17);
        final original = makePlan(date);
        final updatedMeta = original.meta.copyWith(
          updatedAt: DateTime(2024, 3, 17, 9),
        );

        stubUpdateBranch(original, updatedMeta);

        final result = await repository.save(original);

        // The original and the result differ only in updatedAt.
        expect(result.meta.id, original.meta.id);
        expect(result.meta.updatedAt, isNot(equals(original.meta.updatedAt)));
        expect(result.meta.updatedAt, updatedMeta.updatedAt);
      },
    );

    test('propagates a createDbEntity throw on the new-plan branch', () async {
      final plan = makePlan(DateTime(2024, 3, 18));

      stubCreateBranch(plan, throws: StateError('create failed'));

      await expectLater(() => repository.save(plan), throwsStateError);
    });

    test('propagates an updateDbEntity throw on the update branch', () async {
      final original = makePlan(DateTime(2024, 3, 19));
      final updatedMeta = original.meta.copyWith(
        updatedAt: DateTime(2024, 3, 19, 12),
      );

      stubUpdateBranch(
        original,
        updatedMeta,
        throws: StateError('update failed'),
      );

      await expectLater(() => repository.save(original), throwsStateError);
    });
  });

  group('getDayPlan batching properties', () {
    glados.Glados(
      glados.IntAnys(glados.any).intInRange(1, 16),
      glados.ExploreConfig(numRuns: 80),
    ).test(
      'any same-sweep request set coalesces into one batched fetch that '
      'covers every id and routes each date to its own plan',
      (count) async {
        // Fresh doubles per generated case — the repository keeps batch
        // state between calls.
        final db = MockJournalDb();
        final repo = DayPlanRepositoryImpl(
          journalDb: db,
          persistenceLogic: MockPersistenceLogic(),
          updateNotifications: MockUpdateNotifications(),
        );

        final dates = [
          for (var i = 0; i < count; i++) DateTime(2026, 4, 1 + i),
        ];
        // Every other date has a stored plan; the rest resolve to null.
        final plans = {
          for (var i = 0; i < count; i += 2)
            dayPlanId(dates[i]): makePlan(dates[i]),
        };

        final captured = <Set<String>>[];
        when(() => db.getDayPlansByIds(any())).thenAnswer((invocation) async {
          final ids = invocation.positionalArguments.single as Set<String>;
          captured.add(Set.of(ids));
          return [
            for (final id in ids)
              if (plans[id] != null) plans[id]!,
          ];
        });

        // Same synchronous sweep: fire every request before awaiting.
        final futures = [for (final date in dates) repo.getDayPlan(date)];
        final results = await Future.wait(futures);

        // (a) exactly one batched DB call...
        expect(captured, hasLength(1), reason: 'count=$count');
        // (b) ...covering every requested id...
        expect(
          captured.single,
          {for (final date in dates) dayPlanId(date)},
          reason: 'count=$count',
        );
        // (c) ...and each date resolves to its own plan (or null).
        for (var i = 0; i < count; i++) {
          expect(
            results[i],
            plans[dayPlanId(dates[i])],
            reason: 'count=$count i=$i',
          );
        }
      },
      tags: 'glados',
    );
  });

  group('getDayPlansInRange', () {
    test(
      'delegates to JournalDb.getDayPlansInRange and returns the result',
      () async {
        final start = DateTime(2024, 3);
        final end = DateTime(2024, 3, 31);
        final p1 = makePlan(DateTime(2024, 3, 10));
        final p2 = makePlan(DateTime(2024, 3, 20));

        when(
          () => journalDb.getDayPlansInRange(
            rangeStart: start,
            rangeEnd: end,
          ),
        ).thenAnswer((_) async => [p1, p2]);

        final results = await repository.getDayPlansInRange(
          rangeStart: start,
          rangeEnd: end,
        );

        expect(results, [p1, p2]);
        verify(
          () => journalDb.getDayPlansInRange(
            rangeStart: start,
            rangeEnd: end,
          ),
        ).called(1);
      },
    );

    test(
      'returns empty list when no plans exist in the range',
      () async {
        final start = DateTime(2024, 6);
        final end = DateTime(2024, 6, 30);

        when(
          () => journalDb.getDayPlansInRange(
            rangeStart: start,
            rangeEnd: end,
          ),
        ).thenAnswer((_) async => []);

        final results = await repository.getDayPlansInRange(
          rangeStart: start,
          rangeEnd: end,
        );

        expect(results, isEmpty);
      },
    );

    test(
      'forwards a backwards range (rangeStart > rangeEnd) verbatim without '
      'normalizing the bounds',
      () async {
        // rangeStart is after rangeEnd. The repository performs no validation
        // or reordering — it delegates the bounds exactly as given and the DB
        // decides the outcome (empty for an inverted range in SQLite).
        final start = DateTime(2024, 7, 31);
        final end = DateTime(2024, 7);

        when(
          () => journalDb.getDayPlansInRange(
            rangeStart: start,
            rangeEnd: end,
          ),
        ).thenAnswer((_) async => []);

        final results = await repository.getDayPlansInRange(
          rangeStart: start,
          rangeEnd: end,
        );

        expect(results, isEmpty);
        // The exact (inverted) bounds are passed straight through — no swap.
        verify(
          () => journalDb.getDayPlansInRange(
            rangeStart: start,
            rangeEnd: end,
          ),
        ).called(1);
        verifyNever(
          () => journalDb.getDayPlansInRange(
            rangeStart: end,
            rangeEnd: start,
          ),
        );
      },
    );
  });

  group('updateStream', () {
    test(
      'relays every event from UpdateNotifications, not just the first',
      () async {
        final ids1 = <String>{'dayplan-2024-03-15', 'dayplan-2024-03-16'};
        final ids2 = <String>{'dayplan-2024-03-17'};
        final controller = StreamController<Set<String>>();
        when(
          () => updateNotifications.updateStream,
        ).thenAnswer((_) => controller.stream);

        final emitted = <Set<String>>[];
        final sub = repository.updateStream.listen(emitted.add);

        controller.add(ids1);
        // Drain the pending event-queue turns deterministically — no
        // real-time yield involved.
        await pumpEventQueue();
        expect(emitted, [ids1]);

        // A second event must also reach the listener: the repository exposes
        // the underlying stream as a persistent relay, not a one-shot.
        controller.add(ids2);
        await pumpEventQueue();
        expect(emitted, [ids1, ids2]);

        await sub.cancel();
        await controller.close();
      },
    );
  });
}
