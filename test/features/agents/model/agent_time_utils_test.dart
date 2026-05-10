import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_time_utils.dart';

enum _GeneratedRunStatusKind {
  completed,
  failed,
  running,
  abandoned,
  unknown,
}

enum _GeneratedRunTimingKind {
  none,
  startOnly,
  completedOnly,
  zero,
  positive,
  reversed,
}

final _generatedRunStatsBase = DateTime(2026, 5, 20, 8);

class _GeneratedRunStatsEntry {
  const _GeneratedRunStatsEntry({
    required this.statusKind,
    required this.timingKind,
    required this.startOffsetSeconds,
    required this.durationMilliseconds,
  });

  final _GeneratedRunStatusKind statusKind;
  final _GeneratedRunTimingKind timingKind;
  final int startOffsetSeconds;
  final int durationMilliseconds;

  String get status {
    return switch (statusKind) {
      _GeneratedRunStatusKind.completed => WakeRunStatus.completed.name,
      _GeneratedRunStatusKind.failed => WakeRunStatus.failed.name,
      _GeneratedRunStatusKind.running => WakeRunStatus.running.name,
      _GeneratedRunStatusKind.abandoned => WakeRunStatus.abandoned.name,
      _GeneratedRunStatusKind.unknown => 'custom-status',
    };
  }

  ({DateTime? startedAt, DateTime? completedAt}) get timing {
    final startedAt = _generatedRunStatsBase.add(
      Duration(seconds: startOffsetSeconds),
    );
    return switch (timingKind) {
      _GeneratedRunTimingKind.none => (startedAt: null, completedAt: null),
      _GeneratedRunTimingKind.startOnly => (
        startedAt: startedAt,
        completedAt: null,
      ),
      _GeneratedRunTimingKind.completedOnly => (
        startedAt: null,
        completedAt: startedAt.add(
          Duration(milliseconds: durationMilliseconds),
        ),
      ),
      _GeneratedRunTimingKind.zero => (
        startedAt: startedAt,
        completedAt: startedAt,
      ),
      _GeneratedRunTimingKind.positive => (
        startedAt: startedAt,
        completedAt: startedAt.add(
          Duration(milliseconds: durationMilliseconds),
        ),
      ),
      _GeneratedRunTimingKind.reversed => (
        startedAt: startedAt,
        completedAt: startedAt.subtract(
          Duration(milliseconds: durationMilliseconds + 1),
        ),
      ),
    };
  }

  int? get validDurationMilliseconds {
    final timing = this.timing;
    if (timing.startedAt == null || timing.completedAt == null) {
      return null;
    }

    final duration = timing.completedAt!.difference(timing.startedAt!);
    if (duration.isNegative) return null;
    return duration.inMilliseconds;
  }

  @override
  String toString() {
    return '_GeneratedRunStatsEntry('
        'statusKind: $statusKind, timingKind: $timingKind, '
        'startOffsetSeconds: $startOffsetSeconds, '
        'durationMilliseconds: $durationMilliseconds)';
  }
}

class _GeneratedRunStatsScenario {
  const _GeneratedRunStatsScenario({required this.entries});

  final List<_GeneratedRunStatsEntry> entries;

  int get expectedSuccessCount => entries
      .where((entry) => entry.status == WakeRunStatus.completed.name)
      .length;

  int get expectedFailureCount => entries
      .where((entry) => entry.status == WakeRunStatus.failed.name)
      .length;

  double get expectedSuccessRate {
    final total = expectedSuccessCount + expectedFailureCount;
    return total == 0 ? 0 : expectedSuccessCount / total;
  }

  Duration get expectedAverageDuration {
    final durations = entries
        .map((entry) => entry.validDurationMilliseconds)
        .whereType<int>()
        .toList();
    if (durations.isEmpty) return Duration.zero;

    final total = durations.fold<int>(0, (sum, value) => sum + value);
    return Duration(milliseconds: total ~/ durations.length);
  }

  @override
  String toString() => '_GeneratedRunStatsScenario($entries)';
}

extension _AnyGeneratedRunStatsScenario on glados.Any {
  glados.Generator<_GeneratedRunStatusKind> get runStatusKind =>
      glados.AnyUtils(this).choose(_GeneratedRunStatusKind.values);

  glados.Generator<_GeneratedRunTimingKind> get runTimingKind =>
      glados.AnyUtils(this).choose(_GeneratedRunTimingKind.values);

  glados.Generator<_GeneratedRunStatsEntry> get runStatsEntry =>
      glados.CombinableAny(this).combine4(
        runStatusKind,
        runTimingKind,
        glados.IntAnys(this).intInRange(0, 3600),
        glados.IntAnys(this).intInRange(0, 120000),
        (
          _GeneratedRunStatusKind statusKind,
          _GeneratedRunTimingKind timingKind,
          int startOffsetSeconds,
          int durationMilliseconds,
        ) => _GeneratedRunStatsEntry(
          statusKind: statusKind,
          timingKind: timingKind,
          startOffsetSeconds: startOffsetSeconds,
          durationMilliseconds: durationMilliseconds,
        ),
      );

  glados.Generator<_GeneratedRunStatsScenario> get runStatsScenario =>
      glados.ListAnys(this)
          .listWithLengthInRange(0, 60, runStatsEntry)
          .map(
            (entries) => _GeneratedRunStatsScenario(entries: entries),
          );
}

void main() {
  group('agent time utilities', () {
    test('truncateToDay returns local midnight for the same calendar date', () {
      final date = DateTime(2024, 3, 15, 23, 59, 58, 999);

      expect(truncateToDay(date), DateTime(2024, 3, 15));
    });

    test('nextLocalDayAtTime returns the next day at the requested time', () {
      final date = DateTime(2024, 3, 15, 23, 59);

      expect(
        nextLocalDayAtTime(date, hour: 9, minute: 30),
        DateTime(2024, 3, 16, 9, 30),
      );
    });

    group('nextOccurrenceOf', () {
      test(
        'returns today at the requested time when it has not passed yet',
        () {
          // 03:15 today → next 06:00 is today, not tomorrow.
          expect(
            nextOccurrenceOf(DateTime(2024, 3, 15, 3, 15), hour: 6),
            DateTime(2024, 3, 15, 6),
          );
        },
      );

      test("returns tomorrow when today's requested time has passed", () {
        // 21:30 today → next 06:00 is tomorrow.
        expect(
          nextOccurrenceOf(DateTime(2024, 3, 15, 21, 30), hour: 6),
          DateTime(2024, 3, 16, 6),
        );
      });

      test('rolls forward when called exactly at the requested time', () {
        // Edge: at 06:00 sharp, "next" is tomorrow's 06:00 — the slot
        // we're standing on doesn't count as "after now".
        expect(
          nextOccurrenceOf(DateTime(2024, 3, 15, 6), hour: 6),
          DateTime(2024, 3, 16, 6),
        );
      });

      test('honours non-zero minute parameter', () {
        expect(
          nextOccurrenceOf(DateTime(2024, 3, 15, 6, 14), hour: 6, minute: 15),
          DateTime(2024, 3, 15, 6, 15),
        );
        expect(
          nextOccurrenceOf(DateTime(2024, 3, 15, 6, 16), hour: 6, minute: 15),
          DateTime(2024, 3, 16, 6, 15),
        );
      });

      test('crosses month and year boundaries correctly', () {
        // 23:59 on the last day of a month → next 06:00 is the 1st of
        // the following month.
        expect(
          nextOccurrenceOf(DateTime(2024, 1, 31, 23, 59), hour: 6),
          DateTime(2024, 2, 1, 6),
        );
        // 23:59 on Dec 31 → next 06:00 is Jan 1 of the next year.
        expect(
          nextOccurrenceOf(DateTime(2024, 12, 31, 23, 59), hour: 6),
          DateTime(2025, 1, 1, 6),
        );
      });
    });

    glados.Glados(
      glados.any.runStatsScenario,
      glados.ExploreConfig(numRuns: 180),
    ).test('matches generated wake run statistics semantics', (scenario) {
      final stats = computeRunStats<_GeneratedRunStatsEntry>(
        scenario.entries,
        statusAccessor: (entry) => entry.status,
        timingAccessor: (entry) => entry.timing,
      );

      expect(stats.successCount, scenario.expectedSuccessCount);
      expect(stats.failureCount, scenario.expectedFailureCount);
      expect(
        stats.successRate,
        closeTo(scenario.expectedSuccessRate, 0.000000000001),
      );
      expect(stats.averageDuration, scenario.expectedAverageDuration);
    }, tags: 'glados');
  });
}
