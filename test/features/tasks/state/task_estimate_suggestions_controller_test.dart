import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tasks/state/task_estimate_suggestions_controller.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  late MockJournalDb journalDb;

  // Fixed so the 90-day window has a knowable start; the wall clock never
  // decides what `since` this test asserts on.
  final now = DateTime(2026, 3, 15, 11, 20);

  // Drives the `private` config flag the controller watches, so a test can
  // flip visibility and observe the ranking re-derive.
  late StreamController<bool> privateFlips;
  late bool privateVisible;

  setUp(() async {
    // The shared harness, not a hand-rolled GetIt: it already registers the
    // MockJournalDb this controller resolves, and it leaves no
    // `allowReassignment` flag behind for the next file in the shard.
    journalDb = (await setUpTestGetIt()).journalDb;
    privateFlips = StreamController<bool>.broadcast();
    privateVisible = true;
    // Mirrors the real `watchConfigFlag`: every subscriber gets the current
    // value first, then subsequent changes. A bare broadcast stream would
    // drop the seed before the provider had subscribed.
    when(() => journalDb.watchConfigFlag(privateFlag)).thenAnswer((_) async* {
      yield privateVisible;
      yield* privateFlips.stream;
    });
  });

  tearDown(() async {
    await privateFlips.close();
    await tearDownTestGetIt();
  });

  void stubRanked(List<Duration> ranked) {
    when(
      () => journalDb.getRankedTaskEstimates(
        since: any(named: 'since'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => ranked);
  }

  ProviderContainer buildContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  Future<List<Duration>> read({ProviderContainer? container}) => withClock(
    Clock.fixed(now),
    () => (container ?? buildContainer()).read(
      taskEstimateSuggestionsControllerProvider.future,
    ),
  );

  group('toppedUpAndSorted', () {
    test('a full ranking is used as-is, shortest first', () {
      expect(
        TaskEstimateSuggestionsController.toppedUpAndSorted(const [
          Duration(hours: 2),
          Duration(minutes: 30),
          Duration(hours: 4),
          Duration(minutes: 45),
        ]),
        const [
          Duration(minutes: 30),
          Duration(minutes: 45),
          Duration(hours: 2),
          Duration(hours: 4),
        ],
      );
    });

    test('an empty ranking falls back to the starter ladder', () {
      expect(
        TaskEstimateSuggestionsController.toppedUpAndSorted(const []),
        kDefaultEstimateSuggestions,
      );
    });

    test('a thin ranking is topped up to a full row', () {
      final result = TaskEstimateSuggestionsController.toppedUpAndSorted(const [
        Duration(minutes: 20),
      ]);

      expect(result, hasLength(kEstimateSuggestionCount));
      expect(result.first, const Duration(minutes: 20));
      expect(result, containsAll(kDefaultEstimateSuggestions.take(3)));
    });

    test('a top-up never repeats a value already ranked', () {
      final result = TaskEstimateSuggestionsController.toppedUpAndSorted(const [
        Duration(hours: 1),
        Duration(hours: 4),
      ]);

      expect(result, hasLength(kEstimateSuggestionCount));
      expect(
        result.where((d) => d == const Duration(hours: 1)),
        hasLength(1),
        reason: 'the ladder must not duplicate a ranked value',
      );
      expect(result, const [
        Duration(minutes: 30),
        Duration(hours: 1),
        Duration(hours: 2),
        Duration(hours: 4),
      ]);
    });

    test('an over-long ranking is cut to the row size before sorting', () {
      final result = TaskEstimateSuggestionsController.toppedUpAndSorted(const [
        Duration(hours: 5),
        Duration(hours: 4),
        Duration(hours: 3),
        Duration(hours: 2),
        // Ranked fifth: past the row, so it must not appear even though it
        // would sort first.
        Duration(minutes: 10),
      ]);

      expect(result, const [
        Duration(hours: 2),
        Duration(hours: 3),
        Duration(hours: 4),
        Duration(hours: 5),
      ]);
    });

    test('a repeated ranked value collapses and the ladder fills the gap', () {
      final result = TaskEstimateSuggestionsController.toppedUpAndSorted(const [
        Duration(hours: 1),
        Duration(hours: 1),
      ]);

      expect(result, hasLength(kEstimateSuggestionCount));
      expect(result.where((d) => d == const Duration(hours: 1)), hasLength(1));
    });
  });

  group('build', () {
    test('queries the 90-day window for a full row of values', () async {
      stubRanked(const [Duration(hours: 1)]);

      await read();

      final captured = verify(
        () => journalDb.getRankedTaskEstimates(
          since: captureAny(named: 'since'),
          limit: captureAny(named: 'limit'),
        ),
      ).captured;

      expect(
        captured.first,
        DateTime(2026, 3, 15).subtract(kEstimateSuggestionWindow),
        reason: 'the window starts at midnight, not at the current time',
      );
      expect(captured.last, kEstimateSuggestionCount);
    });

    test('serves the ranked estimates, shortest first', () async {
      stubRanked(const [
        Duration(hours: 3),
        Duration(minutes: 30),
        Duration(hours: 1),
        Duration(hours: 2),
      ]);

      expect(await read(), const [
        Duration(minutes: 30),
        Duration(hours: 1),
        Duration(hours: 2),
        Duration(hours: 3),
      ]);
    });

    test(
      're-derives the ranking when private visibility is turned off',
      () async {
        // The row is kept alive for five minutes, so a flag change inside that
        // window has to invalidate it — otherwise a reopened picker still
        // offers a duration ranked from tasks that are now hidden.
        stubRanked(const [Duration(hours: 6)]);
        final container = buildContainer();

        expect(
          await read(container: container),
          contains(const Duration(hours: 6)),
        );

        stubRanked(const [Duration(hours: 1)]);
        privateVisible = false;
        privateFlips.add(false);
        await container.read(
          taskEstimateSuggestionsControllerProvider.future,
        );

        expect(
          await container.read(
            taskEstimateSuggestionsControllerProvider.future,
          ),
          contains(const Duration(hours: 1)),
        );
        expect(
          await container.read(
            taskEstimateSuggestionsControllerProvider.future,
          ),
          isNot(contains(const Duration(hours: 6))),
          reason: 'the value ranked from now-hidden tasks is gone',
        );
        verify(
          () => journalDb.getRankedTaskEstimates(
            since: any(named: 'since'),
            limit: any(named: 'limit'),
          ),
        ).called(2);
      },
    );

    test('falls back to the starter ladder with no history at all', () async {
      stubRanked(const []);

      expect(await read(), kDefaultEstimateSuggestions);
    });
  });
}
