import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/goals/logic/goal_checkin_compaction_strategy.dart';
import 'package:lotti/features/goals/logic/goal_user_voice.dart';
import 'package:lotti/features/goals/model/goal_checkin_summary.dart';

/// Records every span it was asked to digest and returns a legible stub.
class _RecordingDigestWriter implements GoalCheckInDigestWriter {
  final requests = <GoalCheckInDigestRequest>[];

  @override
  Future<String> write(GoalCheckInDigestRequest request) async {
    requests.add(request);
    return 'digest of ${request.periodLabel} '
        '(${request.checkIns.length} check-ins)';
  }
}

void main() {
  // Sized like a real Layer-1 summary (~120 tokens), not a one-liner: the
  // budgets under test are token budgets, and a toy history that fits in
  // the verbatim slice would let every strategy look identical.
  GoalCheckInSummary summary(String id, DateTime at) => GoalCheckInSummary(
    id: id,
    sourceEntryId: 'entry-$id',
    recordedAt: at,
    whatHappened:
        'Walked the perimeter loop after lunch and again after the evening '
        'colony count, about 9,800 steps by the tracker. The wind picked up '
        'in the afternoon so the second loop was shorter than planned.',
    committedTo:
        'Do the full perimeter loop both times tomorrow, even if the wind '
        'is up, and log it before the shift ends.',
    blockers: 'Afternoon katabatic wind and a long desk block for the survey.',
    mood: 'Steady, a little tired.',
  );

  /// Three check-ins a week from [start] for [weeks] weeks.
  List<GoalCheckInSummary> history(DateTime start, int weeks) => [
    for (var w = 0; w < weeks; w++)
      for (final d in const [0, 2, 4])
        summary('w$w-d$d', start.add(Duration(days: w * 7 + d, hours: 8))),
  ];

  final reference = DateTime.utc(2026, 8, 27, 12);
  final start = DateTime.utc(2024, 9, 2);
  final twoYears = history(start, 103);

  group('full', () {
    test(
      'carries every check-in, oldest first, in the production shape',
      () async {
        final shuffled = [twoYears[5], twoYears[0], twoYears[2]];
        final context = await const FullContextCheckInCompaction().build(
          shuffled,
          reference: reference,
        );

        expect(context.verbatimCount, 3);
        expect(context.digestCount, 0);
        expect(
          context.entries.map((e) => e['sourceEntryId']),
          ['entry-w0-d0', 'entry-w0-d4', 'entry-w1-d4'],
        );
        expect(context.entries.first, goalUserVoiceEntry(twoYears[0]));
      },
    );

    test('is unbounded — the oracle grows with the history', () async {
      final one = await const FullContextCheckInCompaction().build(
        twoYears.take(30).toList(),
        reference: reference,
      );
      final all = await const FullContextCheckInCompaction().build(
        twoYears,
        reference: reference,
      );
      expect(all.estimatedTokens, greaterThan(one.estimatedTokens * 5));
    });
  });

  group('truncate', () {
    test('matches the shipped goalUserVoiceEntries slice exactly', () async {
      final context = await const TruncatingCheckInCompaction().build(
        twoYears,
        reference: reference,
      );

      expect(context.entries, goalUserVoiceEntries(twoYears));
      expect(context.verbatimCount, context.entries.length);
      expect(context.digestCount, 0);
      expect(
        context.estimatedTokens,
        lessThanOrEqualTo(goalUserVoiceTokenBudget),
      );
      // The point of the whole evaluation: two years of history reduce to a
      // handful of the newest check-ins.
      expect(context.entries.length, lessThan(20));
      expect(
        context.entries.last['sourceEntryId'],
        'entry-${twoYears.last.id}',
      );
    });
  });

  group('hierarchical', () {
    test('keeps the recent tail verbatim and digests the rest', () async {
      final writer = _RecordingDigestWriter();
      final strategy = HierarchicalCheckInCompaction(digestWriter: writer);

      final context = await strategy.build(twoYears, reference: reference);

      final truncated = goalUserVoiceEntries(twoYears);
      expect(context.verbatimCount, truncated.length);
      expect(context.entries.sublist(context.digestCount), truncated);
      expect(context.digestCount, writer.requests.length);
      expect(context.digestCount, greaterThan(0));
      final foldedCount = writer.requests.fold<int>(
        0,
        (sum, r) => sum + r.checkIns.length,
      );
      expect(foldedCount + context.verbatimCount, twoYears.length);
    });

    test('digests read oldest first and carry their span and count', () async {
      final writer = _RecordingDigestWriter();
      final strategy = HierarchicalCheckInCompaction(digestWriter: writer);

      final context = await strategy.build(twoYears, reference: reference);

      final digests = context.entries.take(context.digestCount).toList();
      expect(digests.first['kind'], 'digest');
      expect(digests.first['layer'], 'year');
      expect(digests.first['period'], '2024');
      expect(digests.first['checkIns'], writer.requests.first.checkIns.length);
      expect(
        digests.first['digest'],
        'digest of 2024 (${writer.requests.first.checkIns.length} check-ins)',
      );
      final froms = writer.requests.map((r) => r.from).toList();
      expect(froms, orderedEquals([...froms]..sort()));
      for (var i = 1; i < writer.requests.length; i++) {
        expect(
          writer.requests[i].from.isAfter(writer.requests[i - 1].to),
          isTrue,
          reason: 'spans must not overlap',
        );
      }
    });

    test('months → quarters → years by age, each layer shorter', () async {
      final writer = _RecordingDigestWriter();
      final strategy = HierarchicalCheckInCompaction(
        digestWriter: writer,
        // ignore: avoid_redundant_argument_values
        monthlyHorizonMonths: 6,
        // ignore: avoid_redundant_argument_values
        quarterlyHorizonMonths: 18,
      );

      await strategy.build(twoYears, reference: reference);

      final byLabel = {for (final r in writer.requests) r.periodLabel: r};
      // Six months before 2026-08-27 is 2026-02: February onwards is monthly.
      expect(byLabel['2026-02']?.layer, GoalCheckInDigestLayer.month);
      expect(byLabel['2026-07']?.layer, GoalCheckInDigestLayer.month);
      // Between 18 and 6 months back: quarters. January 2026 sits alone in
      // a one-month quarter rather than being promoted to monthly.
      expect(byLabel['2025-Q4']?.layer, GoalCheckInDigestLayer.quarter);
      expect(byLabel['2026-Q1']?.layer, GoalCheckInDigestLayer.quarter);
      expect(byLabel.containsKey('2026-01'), isFalse);
      expect(byLabel.containsKey('2025-10'), isFalse);
      // Eighteen months back is 2025-02: everything before is yearly.
      expect(byLabel['2024']?.layer, GoalCheckInDigestLayer.year);
      expect(byLabel['2025']?.layer, GoalCheckInDigestLayer.year);
      expect(byLabel['2025']!.checkIns.first.recordedAt.month, 1);
      expect(byLabel['2025']!.checkIns.last.recordedAt.month, 1);
      // February and March 2025 are still inside the quarterly window, so
      // 2025-Q1 exists as a two-month quarter.
      expect(byLabel['2025-Q1']!.checkIns.first.recordedAt.month, 2);
      expect(byLabel.containsKey('2024-Q4'), isFalse);
      // Coarser is shorter: the bound the layers exist for.
      expect(
        GoalCheckInDigestLayer.year.maxWords,
        lessThan(GoalCheckInDigestLayer.month.maxWords),
      );
      expect(byLabel['2024']!.maxWords, 80);
      expect(byLabel['2026-07']!.maxWords, 120);
      for (final request in writer.requests) {
        expect(request.from.isBefore(request.to), isTrue);
        expect(
          request.checkIns.map((c) => c.recordedAt),
          orderedEquals([...request.checkIns.map((c) => c.recordedAt)]..sort()),
        );
      }
    });

    test('the number of digest entries stops growing with age', () async {
      // Four years of history: the yearly layer holds the count to
      // (months in horizon) + (quarters in horizon) + years.
      final fourYears = history(DateTime.utc(2022, 9, 5), 207);
      final writer = _RecordingDigestWriter();
      final strategy = HierarchicalCheckInCompaction(digestWriter: writer);

      final two = await strategy.build(twoYears, reference: reference);
      final four = await strategy.build(fourYears, reference: reference);

      expect(four.digestCount - two.digestCount, lessThanOrEqualTo(2));
    });

    test('a history that fits the verbatim budget needs no digest', () async {
      final writer = _RecordingDigestWriter();
      final strategy = HierarchicalCheckInCompaction(digestWriter: writer);

      final context = await strategy.build(
        twoYears.take(3).toList(),
        reference: reference,
      );

      expect(context.digestCount, 0);
      expect(writer.requests, isEmpty);
      expect(context.entries, goalUserVoiceEntries(twoYears.take(3).toList()));
    });

    test('an empty history is empty', () async {
      final writer = _RecordingDigestWriter();
      final context = await HierarchicalCheckInCompaction(
        digestWriter: writer,
      ).build(const [], reference: reference);
      expect(context, GoalUserVoiceContext.empty);
      expect(writer.requests, isEmpty);
    });

    test(
      'stays bounded: two years cost a small multiple of the tail',
      () async {
        final writer = _RecordingDigestWriter();
        final strategy = HierarchicalCheckInCompaction(digestWriter: writer);
        final full = await const FullContextCheckInCompaction().build(
          twoYears,
          reference: reference,
        );

        final context = await strategy.build(twoYears, reference: reference);

        expect(context.estimatedTokens, lessThan(full.estimatedTokens ~/ 5));
      },
    );
  });
}
