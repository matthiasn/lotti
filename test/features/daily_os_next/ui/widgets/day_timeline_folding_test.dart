import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_timeline_folding.dart';

final _dayDate = DateTime(2026, 5, 25);

const _category = DayAgentCategory(
  id: 'cat-work',
  name: 'Work',
  colorHex: '5ED4B7',
);

TimeBlock _block(int startHour, int endHour, {int index = 0}) {
  return TimeBlock(
    id: 'b-$startHour-$endHour-$index',
    title: 'Block $startHour-$endHour',
    start: _dayDate.add(Duration(hours: startHour)),
    end: _dayDate.add(Duration(hours: endHour)),
    type: TimeBlockType.ai,
    state: TimeBlockState.drafted,
    category: _category,
  );
}

TimelineFoldingState _stateFor(
  List<TimeBlock> blocks, {
  int startHour = 0,
  int endHour = 24,
  Set<int> expanded = const {},
}) {
  return TimelineFoldingState.fromBlocks(
    blocks: blocks,
    dayDate: _dayDate,
    startHour: startHour,
    endHour: endHour,
    expandedRegionStarts: expanded,
    collapsedHourHeight: 6,
  );
}

/// A generated set of occupied hour ranges within the day window.
class _GeneratedDaySchedule {
  const _GeneratedDaySchedule(this.ranges);

  /// Each range is (startHour, endHour) with start < end, within [0, 24].
  final List<(int, int)> ranges;

  List<TimeBlock> get blocks => [
    for (var i = 0; i < ranges.length; i++)
      _block(ranges[i].$1, ranges[i].$2, index: i),
  ];

  Set<int> get occupiedHours => {
    for (final range in ranges)
      for (var hour = range.$1; hour < range.$2; hour++) hour,
  };

  @override
  String toString() => '_GeneratedDaySchedule($ranges)';
}

extension _AnyFolding on glados.Any {
  glados.Generator<(int, int)> get _hourRange =>
      glados.CombinableAny(this).combine2(
        glados.IntAnys(this).intInRange(0, 23),
        glados.IntAnys(this).intInRange(1, 7),
        (start, length) => (start, (start + length).clamp(1, 24)),
      );

  glados.Generator<_GeneratedDaySchedule> get daySchedule => glados.ListAnys(
    this,
  ).listWithLengthInRange(0, 6, _hourRange).map(_GeneratedDaySchedule.new);

  glados.Generator<double> get hourValue =>
      glados.IntAnys(this).intInRange(0, 24 * 100 + 1).map((v) => v / 100);
}

void main() {
  group('TimelineFoldingState.fromBlocks — properties', () {
    glados.Glados<_GeneratedDaySchedule>(
      glados.any.daySchedule,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'every occupied hour falls inside a visible region',
      (schedule) {
        final state = _stateFor(schedule.blocks);

        for (final hour in schedule.occupiedHours) {
          final covered = state.segments.any(
            (segment) =>
                segment is TimelineVisibleRegion &&
                hour >= segment.startHour &&
                hour < segment.endHour,
          );
          expect(
            covered,
            isTrue,
            reason: 'occupied hour $hour not covered in $schedule',
          );
        }
      },
      tags: 'glados',
    );

    glados.Glados<_GeneratedDaySchedule>(
      glados.any.daySchedule,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'segments tile the window exactly: contiguous, ordered, no overlap',
      (schedule) {
        final state = _stateFor(schedule.blocks);

        var cursor = 0;
        for (final segment in state.segments) {
          expect(segment.startHour, cursor);
          expect(segment.endHour, greaterThan(segment.startHour));
          cursor = segment.endHour;
        }
        expect(cursor, 24);
      },
      tags: 'glados',
    );

    glados.Glados<_GeneratedDaySchedule>(
      glados.any.daySchedule,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'folded height is strictly less than all-visible unless nothing folds',
      (schedule) {
        const pxPerMinute = 1.0;
        final state = _stateFor(schedule.blocks);
        const allVisibleHeight = 24 * 60 * pxPerMinute;

        final hasCollapsedFold = state.segments.any(
          (s) => s is TimelineFoldRegion && !s.isExpanded,
        );
        if (hasCollapsedFold) {
          expect(state.totalHeight(pxPerMinute), lessThan(allVisibleHeight));
        } else {
          expect(state.totalHeight(pxPerMinute), allVisibleHeight);
        }
      },
      tags: 'glados',
    );
  });

  group('TimelineFoldingState.positionForHourValue — properties', () {
    glados.Glados2<_GeneratedDaySchedule, double>(
      glados.any.daySchedule,
      glados.any.hourValue,
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'monotone in the hour value and bounded by [0, totalHeight]',
      (schedule, hourValue) {
        const pxPerMinute = 1.0;
        final state = _stateFor(schedule.blocks);

        final position = state.positionForHourValue(hourValue, pxPerMinute);
        expect(position, greaterThanOrEqualTo(0));
        expect(
          position,
          lessThanOrEqualTo(state.totalHeight(pxPerMinute) + 0.001),
        );

        // Monotonicity against a slightly later hour value.
        final later = (hourValue + 0.37).clamp(0.0, 24.0);
        expect(
          state.positionForHourValue(later, pxPerMinute),
          greaterThanOrEqualTo(position),
        );
      },
      tags: 'glados',
    );

    glados.Glados<_GeneratedDaySchedule>(
      glados.any.daySchedule,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'boundary exactness: window start maps to 0, window end to totalHeight',
      (schedule) {
        const pxPerMinute = 1.0;
        final state = _stateFor(schedule.blocks);

        expect(state.positionForHourValue(0, pxPerMinute), 0);
        expect(
          state.positionForHourValue(24, pxPerMinute),
          closeTo(state.totalHeight(pxPerMinute), 0.001),
        );
      },
      tags: 'glados',
    );
  });

  group('TimelineFoldingState — examples', () {
    test('an empty schedule yields a single visible region', () {
      final state = _stateFor(const []);

      expect(state.segments, hasLength(1));
      expect(state.segments.single, isA<TimelineVisibleRegion>());
      expect(state.segments.single.startHour, 0);
      expect(state.segments.single.endHour, 24);
    });

    test('a long empty gap folds and expanding it restores full height', () {
      // Blocks at 8-9 and 18-19 leave a 9-hour gap that must fold.
      final blocks = [_block(8, 9), _block(18, 19)];

      final folded = _stateFor(blocks);
      final foldRegions = folded.compressedRegions.toList();
      expect(foldRegions, isNotEmpty);

      final expanded = _stateFor(
        blocks,
        expanded: {for (final r in foldRegions) r.startHour},
      );
      expect(
        expanded.totalHeight(1),
        greaterThan(folded.totalHeight(1)),
      );
      expect(expanded.totalHeight(1), 24 * 60);
    });

    test('visibleHourLabels skips collapsed fold regions', () {
      final state = _stateFor([_block(8, 9), _block(18, 19)]);

      final labels = state.visibleHourLabels;
      // The folded middle gap's interior hours are not labelled.
      expect(labels, isNot(contains(13)));
      expect(labels, contains(8));
      expect(labels, contains(18));
    });
  });
}
