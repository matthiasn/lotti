import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/relationships/state/check_in_duration_suggestions_controller.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  late MockJournalDb journalDb;
  final now = DateTime(2026, 8, 13, 14, 5);
  late StreamController<bool> privateFlips;

  setUp(() async {
    journalDb = (await setUpTestGetIt()).journalDb;
    privateFlips = StreamController<bool>.broadcast();
    when(() => journalDb.watchConfigFlag(privateFlag)).thenAnswer((_) async* {
      yield true;
      yield* privateFlips.stream;
    });
  });

  tearDown(() async {
    await privateFlips.close();
    await tearDownTestGetIt();
  });

  void stubRanked(List<Duration> ranked) {
    when(
      () => journalDb.getRankedCheckInDurations(
        since: any(named: 'since'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => ranked);
  }

  Future<List<Duration>> read(ProviderContainer container) => withClock(
    Clock.fixed(now),
    () => container.read(checkInDurationSuggestionsControllerProvider.future),
  );

  group('toppedUpAndSorted', () {
    test('a full ranking is used as-is, shortest first', () {
      expect(
        CheckInDurationSuggestionsController.toppedUpAndSorted(const [
          Duration(hours: 1),
          Duration(minutes: 8),
          Duration(minutes: 25),
          Duration(minutes: 12),
          Duration(minutes: 40),
          Duration(minutes: 3),
        ]),
        const [
          Duration(minutes: 3),
          Duration(minutes: 8),
          Duration(minutes: 12),
          Duration(minutes: 25),
          Duration(minutes: 40),
          Duration(hours: 1),
        ],
      );
    });

    test("an empty ranking is the design's first positions", () {
      expect(
        CheckInDurationSuggestionsController.toppedUpAndSorted(const []),
        kCheckInDurationPositions.take(kCheckInDurationSuggestionCount),
      );
    });

    test('a thin ranking is topped up without repeating a ranked value', () {
      expect(
        CheckInDurationSuggestionsController.toppedUpAndSorted(const [
          Duration(minutes: 10),
          Duration(minutes: 11),
        ]),
        const [
          Duration(minutes: 5),
          Duration(minutes: 10),
          Duration(minutes: 11),
          Duration(minutes: 15),
          Duration(minutes: 20),
          Duration(minutes: 30),
        ],
      );
    });

    test('an over-long ranking is cut to the row before sorting', () {
      final ranked = [for (var m = 60; m > 0; m -= 5) Duration(minutes: m)];
      final row = CheckInDurationSuggestionsController.toppedUpAndSorted(
        ranked,
      );
      expect(row, hasLength(kCheckInDurationSuggestionCount));
      expect(row.first, const Duration(minutes: 35));
    });
  });

  group('build', () {
    test('queries the 90-day window, from midnight, for a full row', () async {
      stubRanked(const [Duration(minutes: 11)]);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await read(container);

      final captured = verify(
        () => journalDb.getRankedCheckInDurations(
          since: captureAny(named: 'since'),
          limit: captureAny(named: 'limit'),
        ),
      ).captured;
      expect(
        captured.first,
        DateTime(2026, 8, 13).subtract(kCheckInDurationWindow),
      );
      expect(captured.last, kCheckInDurationSuggestionCount);
    });

    test('serves the ranking topped up and sorted', () async {
      stubRanked(const [Duration(minutes: 11), Duration(minutes: 35)]);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(await read(container), const [
        Duration(minutes: 5),
        Duration(minutes: 10),
        Duration(minutes: 11),
        Duration(minutes: 15),
        Duration(minutes: 20),
        Duration(minutes: 35),
      ]);
    });

    test("re-derives when private visibility changes, so a hidden person's "
        'habits stop ranking', () async {
      stubRanked(const [Duration(minutes: 11)]);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final sub = container.listen(
        checkInDurationSuggestionsControllerProvider,
        (_, _) {},
      );
      addTearDown(sub.close);
      await read(container);
      stubRanked(const [Duration(minutes: 42)]);

      privateFlips.add(false);
      await Future<void>.delayed(Duration.zero);

      expect(await read(container), contains(const Duration(minutes: 42)));
    });
  });
}
