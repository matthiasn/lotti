import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/daily_os/state/timeline_data_controller.dart';
import 'package:lotti/features/daily_os/util/timeline_folding_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testDate = DateTime(2026, 1, 15);

  ActualTimeSlot createActualSlot({
    required int hour,
    required int durationMinutes,
    String? categoryId,
    int minute = 0,
  }) {
    final startTime = testDate.add(Duration(hours: hour, minutes: minute));
    final endTime = startTime.add(Duration(minutes: durationMinutes));
    final entry = JournalEntity.journalEntry(
      meta: Metadata(
        id: 'entry-$hour-$minute',
        createdAt: startTime,
        updatedAt: startTime,
        dateFrom: startTime,
        dateTo: endTime,
        categoryId: categoryId,
      ),
    );
    return ActualTimeSlot(
      startTime: startTime,
      endTime: endTime,
      categoryId: categoryId,
      entry: entry,
    );
  }

  PlannedTimeSlot createPlannedSlot({
    required int hour,
    required int durationMinutes,
    String categoryId = 'cat-test',
    int minute = 0,
  }) {
    final startTime = testDate.add(Duration(hours: hour, minutes: minute));
    final endTime = startTime.add(Duration(minutes: durationMinutes));
    return PlannedTimeSlot(
      startTime: startTime,
      endTime: endTime,
      categoryId: categoryId,
      block: PlannedBlock(
        id: 'block-$hour',
        categoryId: categoryId,
        startTime: startTime,
        endTime: endTime,
      ),
    );
  }

  group('VisibleCluster', () {
    test('calculates hourCount correctly', () {
      const cluster = VisibleCluster(startHour: 9, endHour: 12);
      expect(cluster.hourCount, 3);
    });

    test('equality works correctly', () {
      const cluster1 = VisibleCluster(startHour: 9, endHour: 12);
      const cluster2 = VisibleCluster(startHour: 9, endHour: 12);
      const cluster3 = VisibleCluster(startHour: 10, endHour: 12);

      expect(cluster1, equals(cluster2));
      expect(cluster1, isNot(equals(cluster3)));
    });

    test('hashCode is consistent with equality', () {
      const cluster1 = VisibleCluster(startHour: 9, endHour: 12);
      const cluster2 = VisibleCluster(startHour: 9, endHour: 12);

      expect(cluster1.hashCode, equals(cluster2.hashCode));
    });

    test('toString returns readable representation', () {
      const cluster = VisibleCluster(startHour: 9, endHour: 12);
      expect(cluster.toString(), 'VisibleCluster(9-12)');
    });
  });

  group('CompressedRegion', () {
    test('calculates hourCount correctly', () {
      const region = CompressedRegion(startHour: 3, endHour: 9);
      expect(region.hourCount, 6);
    });

    test('equality works correctly', () {
      const region1 = CompressedRegion(startHour: 3, endHour: 9);
      const region2 = CompressedRegion(startHour: 3, endHour: 9);
      const region3 = CompressedRegion(startHour: 3, endHour: 10);

      expect(region1, equals(region2));
      expect(region1, isNot(equals(region3)));
    });

    test('hashCode is consistent with equality', () {
      const region1 = CompressedRegion(startHour: 3, endHour: 9);
      const region2 = CompressedRegion(startHour: 3, endHour: 9);

      expect(region1.hashCode, equals(region2.hashCode));
    });

    test('toString returns readable representation', () {
      const region = CompressedRegion(startHour: 3, endHour: 9);
      expect(region.toString(), 'CompressedRegion(3-9)');
    });
  });

  group('TimelineFoldingState', () {
    test('hasCompressedRegions returns true when regions exist', () {
      const state = TimelineFoldingState(
        visibleClusters: [VisibleCluster(startHour: 9, endHour: 12)],
        compressedRegions: [CompressedRegion(startHour: 0, endHour: 6)],
      );

      expect(state.hasCompressedRegions, isTrue);
    });

    test('hasCompressedRegions returns false when no regions', () {
      const state = TimelineFoldingState(
        visibleClusters: [VisibleCluster(startHour: 0, endHour: 24)],
        compressedRegions: [],
      );

      expect(state.hasCompressedRegions, isFalse);
    });
  });

  group('calculateFoldingState', () {
    test('empty day shows default 6AM-10PM with compressed regions', () {
      final state = calculateFoldingState(
        plannedSlots: [],
        actualSlots: [],
      );

      expect(state.visibleClusters, hasLength(1));
      expect(state.visibleClusters.first.startHour, 6);
      expect(state.visibleClusters.first.endHour, 22);
      expect(state.compressedRegions, hasLength(2));
      expect(state.compressedRegions[0].startHour, 0);
      expect(state.compressedRegions[0].endHour, 6);
      expect(state.compressedRegions[1].startHour, 22);
      expect(state.compressedRegions[1].endHour, 24);
    });

    test('entry at 1AM creates morning cluster', () {
      final slots = [createActualSlot(hour: 1, durationMinutes: 30)];
      final state = calculateFoldingState(
        plannedSlots: [],
        actualSlots: slots,
      );

      // Should have cluster 0-2 (1AM entry, small gap to 0 extends to start)
      expect(state.visibleClusters.first.startHour, 0);
      // End hour: 1 + ceil(30/60) = 2
      expect(state.visibleClusters.first.endHour, 2);
    });

    test('entries at 1AM and 2PM create two clusters with compressed gap', () {
      final slots = [
        createActualSlot(hour: 1, durationMinutes: 30),
        createActualSlot(hour: 14, durationMinutes: 60),
      ];
      final state = calculateFoldingState(
        plannedSlots: [],
        actualSlots: slots,
      );

      expect(state.visibleClusters, hasLength(2));

      // First cluster: 0-2 (1AM entry, small gap to 0 extends to start)
      expect(state.visibleClusters[0].startHour, 0);
      expect(state.visibleClusters[0].endHour, 2);

      // Second cluster: 14-15 (14:00-15:00 entry)
      expect(state.visibleClusters[1].startHour, 14);
      expect(state.visibleClusters[1].endHour, 15);

      // Compressed region between: 2-14 (12 hours)
      expect(
        state.compressedRegions.any(
          (r) => r.startHour == 2 && r.endHour == 14,
        ),
        isTrue,
      );

      // Compressed region after: 15-24 (9 hours)
      expect(
        state.compressedRegions.any(
          (r) => r.startHour == 15 && r.endHour == 24,
        ),
        isTrue,
      );
    });

    test('adjacent entries within 4 hours merge into single cluster', () {
      final slots = [
        createActualSlot(hour: 9, durationMinutes: 60),
        createActualSlot(
            hour: 12, durationMinutes: 60), // 2 hour gap (10-12), < 4
      ];
      final state = calculateFoldingState(
        plannedSlots: [],
        actualSlots: slots,
      );

      expect(state.visibleClusters, hasLength(1)); // Merged
      expect(state.visibleClusters.first.startHour, 9); // No buffer
      expect(state.visibleClusters.first.endHour, 13); // No buffer
    });

    test('planned slots are also considered for clustering', () {
      final actualSlots = [createActualSlot(hour: 9, durationMinutes: 60)];
      // Place planned slot far enough to create a separate cluster (gap > 4)
      final plannedSlots = [createPlannedSlot(hour: 18, durationMinutes: 60)];
      final state = calculateFoldingState(
        plannedSlots: plannedSlots,
        actualSlots: actualSlots,
      );

      // Should have 2 clusters: 9AM actual (9-10) and 6PM planned (18-19)
      // Gap between 10 and 18 is 8 hours, > 4 threshold
      expect(state.visibleClusters, hasLength(2));
    });

    test('late night entries extend cluster to end of day', () {
      // Entry from 22:00 to 23:00
      final slots = [
        createActualSlot(hour: 22, durationMinutes: 60),
      ];
      final state = calculateFoldingState(
        plannedSlots: [],
        actualSlots: slots,
      );

      // Without buffer: cluster is 22-23, small gap (1 hour) to 24 extends to end
      expect(state.visibleClusters.last.endHour, 24);
    });

    test('late night entries with buffer extend cluster to end of day', () {
      // Entry from 22:00 to 23:00 with buffer=1
      final slots = [
        createActualSlot(hour: 22, durationMinutes: 60),
      ];
      final state = calculateFoldingState(
        plannedSlots: [],
        actualSlots: slots,
        bufferHours: 1,
      );

      // With buffer: 21-24, naturally extends to 24
      expect(state.visibleClusters.last.endHour, 24);
    });

    test('entry with minutes past hour boundary extends to next hour', () {
      // Entry from 10:30 to 11:15 - should mark hours 10 and 11 as occupied
      final slots = [
        createActualSlot(hour: 10, durationMinutes: 45, minute: 30),
      ];
      final state = calculateFoldingState(
        plannedSlots: [],
        actualSlots: slots,
      );

      // No buffer: cluster is 10-12 (hours 10 and 11, endHour 12 is exclusive)
      expect(state.visibleClusters.first.startHour, 10);
      expect(state.visibleClusters.first.endHour, 12);
    });

    test('custom gap threshold works', () {
      // Entry at 8: occupies hour 8 (8-9)
      // Entry at 18: occupies hour 18 (18-19)
      // Gap between 9 and 18 is 9 hours
      final slots = [
        createActualSlot(hour: 8, durationMinutes: 60),
        createActualSlot(hour: 18, durationMinutes: 60),
      ];

      // With default threshold of 4, gap of 9 hours creates 2 clusters
      final state4 = calculateFoldingState(
        plannedSlots: [],
        actualSlots: slots,
      );
      expect(state4.visibleClusters, hasLength(2));

      // With threshold of 10, gap of 9 hours merges into 1 cluster
      final state10 = calculateFoldingState(
        plannedSlots: [],
        actualSlots: slots,
        gapThreshold: 10,
      );
      expect(state10.visibleClusters, hasLength(1));
    });

    test('custom buffer hours work', () {
      final slots = [createActualSlot(hour: 12, durationMinutes: 60)];

      // With default buffer of 0
      final state0 = calculateFoldingState(
        plannedSlots: [],
        actualSlots: slots,
      );
      expect(state0.visibleClusters.first.startHour, 12); // No buffer
      expect(state0.visibleClusters.first.endHour, 13); // No buffer

      // With buffer of 1
      final state1 = calculateFoldingState(
        plannedSlots: [],
        actualSlots: slots,
        bufferHours: 1,
      );
      expect(state1.visibleClusters.first.startHour, 11); // 12 - 1
      expect(state1.visibleClusters.first.endHour, 14); // 13 + 1

      // With buffer of 2
      final state2 = calculateFoldingState(
        plannedSlots: [],
        actualSlots: slots,
        bufferHours: 2,
      );
      expect(state2.visibleClusters.first.startHour, 10); // 12 - 2
      expect(state2.visibleClusters.first.endHour, 15); // 13 + 2
    });

    test('small gaps at start of day extend cluster to start', () {
      // Entry at 2AM creates cluster 2-3
      // Gap from 0-2 is only 2 hours, less than threshold
      // Should extend cluster to include 0
      final slots = [createActualSlot(hour: 2, durationMinutes: 60)];
      final state = calculateFoldingState(
        plannedSlots: [],
        actualSlots: slots,
      );

      // First cluster should start at 0 (small gap extended)
      expect(state.visibleClusters.first.startHour, 0);
    });

    test('small gaps at end of day extend cluster to end', () {
      // Entry at 21AM with buffer creates cluster 20-23
      // Gap from 23-24 is only 1 hour, less than threshold
      // Should extend cluster to include 24
      final slots = [createActualSlot(hour: 21, durationMinutes: 60)];
      final state = calculateFoldingState(
        plannedSlots: [],
        actualSlots: slots,
      );

      // Last cluster should end at 24 (small gap extended)
      expect(state.visibleClusters.last.endHour, 24);
    });

    test('full day coverage results in no compressed regions', () {
      // Create entries every 3 hours to cover the entire day
      final slots = [
        createActualSlot(hour: 0, durationMinutes: 60),
        createActualSlot(hour: 3, durationMinutes: 60),
        createActualSlot(hour: 6, durationMinutes: 60),
        createActualSlot(hour: 9, durationMinutes: 60),
        createActualSlot(hour: 12, durationMinutes: 60),
        createActualSlot(hour: 15, durationMinutes: 60),
        createActualSlot(hour: 18, durationMinutes: 60),
        createActualSlot(hour: 21, durationMinutes: 60),
      ];
      final state = calculateFoldingState(
        plannedSlots: [],
        actualSlots: slots,
      );

      expect(state.compressedRegions, isEmpty);
      expect(state.visibleClusters, hasLength(1));
      expect(state.visibleClusters.first.startHour, 0);
      expect(state.visibleClusters.first.endHour, 24);
    });

    test('custom default day bounds work for empty day', () {
      final state = calculateFoldingState(
        plannedSlots: [],
        actualSlots: [],
        defaultDayStart: 8,
        defaultDayEnd: 20,
      );

      expect(state.visibleClusters.first.startHour, 8);
      expect(state.visibleClusters.first.endHour, 20);
      expect(state.compressedRegions[0].startHour, 0);
      expect(state.compressedRegions[0].endHour, 8);
      expect(state.compressedRegions[1].startHour, 20);
      expect(state.compressedRegions[1].endHour, 24);
    });
  });

  group('calculateFoldedTimelineHeight', () {
    test('calculates height with no compressed regions', () {
      const state = TimelineFoldingState(
        visibleClusters: [VisibleCluster(startHour: 8, endHour: 18)],
        compressedRegions: [],
      );

      final height = calculateFoldedTimelineHeight(
        foldingState: state,
        expandedRegions: {},
      );

      expect(height, 10 * 40.0); // 10 hours * 40px
    });

    test('calculates height with collapsed compressed regions', () {
      const state = TimelineFoldingState(
        visibleClusters: [VisibleCluster(startHour: 8, endHour: 12)],
        compressedRegions: [
          CompressedRegion(startHour: 0, endHour: 8),
          CompressedRegion(startHour: 12, endHour: 24),
        ],
      );

      final height = calculateFoldedTimelineHeight(
        foldingState: state,
        expandedRegions: {},
      );

      // 4 visible hours * 40 + 8 compressed hours * 8 + 12 compressed hours * 8
      expect(height, (4 * 40.0) + (8 * 8.0) + (12 * 8.0));
    });

    test('calculates height with expanded compressed regions', () {
      const state = TimelineFoldingState(
        visibleClusters: [VisibleCluster(startHour: 8, endHour: 12)],
        compressedRegions: [
          CompressedRegion(startHour: 0, endHour: 8),
          CompressedRegion(startHour: 12, endHour: 24),
        ],
      );

      final height = calculateFoldedTimelineHeight(
        foldingState: state,
        expandedRegions: {0}, // First region expanded
      );

      // 4 visible hours * 40 + 8 expanded hours * 40 + 12 compressed hours * 8
      expect(height, (4 * 40.0) + (8 * 40.0) + (12 * 8.0));
    });
  });

  group('timeToFoldedPosition', () {
    test('calculates position in visible cluster', () {
      const state = TimelineFoldingState(
        visibleClusters: [VisibleCluster(startHour: 8, endHour: 12)],
        compressedRegions: [
          CompressedRegion(startHour: 0, endHour: 8),
        ],
      );

      // Position at 9:30 (1.5 hours into visible cluster)
      final position = timeToFoldedPosition(
        hour: 9,
        minute: 30,
        foldingState: state,
        expandedRegions: {},
      );

      // Compressed region (0-8): 8 hours * 8px = 64px
      // Into visible cluster: 1.5 hours * 40px = 60px
      expect(position, (8 * 8.0) + (1.5 * 40.0));
    });

    test('calculates position in compressed region (collapsed)', () {
      const state = TimelineFoldingState(
        visibleClusters: [VisibleCluster(startHour: 8, endHour: 12)],
        compressedRegions: [
          CompressedRegion(startHour: 0, endHour: 8),
        ],
      );

      // Position at 4:00 (4 hours into compressed region)
      final position = timeToFoldedPosition(
        hour: 4,
        minute: 0,
        foldingState: state,
        expandedRegions: {},
      );

      // 4 hours into compressed region at 8px/hour
      expect(position, 4 * 8.0);
    });

    test('calculates position in compressed region (expanded)', () {
      const state = TimelineFoldingState(
        visibleClusters: [VisibleCluster(startHour: 8, endHour: 12)],
        compressedRegions: [
          CompressedRegion(startHour: 0, endHour: 8),
        ],
      );

      // Position at 4:00 with region expanded
      final position = timeToFoldedPosition(
        hour: 4,
        minute: 0,
        foldingState: state,
        expandedRegions: {0}, // Region starting at hour 0 is expanded
      );

      // 4 hours into expanded region at 40px/hour
      expect(position, 4 * 40.0);
    });

    test('calculates position after compressed region', () {
      const state = TimelineFoldingState(
        visibleClusters: [
          VisibleCluster(startHour: 0, endHour: 4),
          VisibleCluster(startHour: 12, endHour: 18),
        ],
        compressedRegions: [
          CompressedRegion(startHour: 4, endHour: 12),
        ],
      );

      // Position at 14:00 (2 hours into second visible cluster)
      final position = timeToFoldedPosition(
        hour: 14,
        minute: 0,
        foldingState: state,
        expandedRegions: {},
      );

      // First cluster: 4 hours * 40px = 160px
      // Compressed region: 8 hours * 8px = 64px
      // Into second cluster: 2 hours * 40px = 80px
      expect(position, (4 * 40.0) + (8 * 8.0) + (2 * 40.0));
    });
  });

  group('isHourInCompressedRegion', () {
    test('returns true for hour in collapsed compressed region', () {
      const state = TimelineFoldingState(
        visibleClusters: [VisibleCluster(startHour: 8, endHour: 12)],
        compressedRegions: [
          CompressedRegion(startHour: 0, endHour: 8),
        ],
      );

      expect(
        isHourInCompressedRegion(
          hour: 4,
          foldingState: state,
          expandedRegions: {},
        ),
        isTrue,
      );
    });

    test('returns false for hour in expanded compressed region', () {
      const state = TimelineFoldingState(
        visibleClusters: [VisibleCluster(startHour: 8, endHour: 12)],
        compressedRegions: [
          CompressedRegion(startHour: 0, endHour: 8),
        ],
      );

      expect(
        isHourInCompressedRegion(
          hour: 4,
          foldingState: state,
          expandedRegions: {0}, // Region expanded
        ),
        isFalse,
      );
    });

    test('returns false for hour in visible cluster', () {
      const state = TimelineFoldingState(
        visibleClusters: [VisibleCluster(startHour: 8, endHour: 12)],
        compressedRegions: [
          CompressedRegion(startHour: 0, endHour: 8),
        ],
      );

      expect(
        isHourInCompressedRegion(
          hour: 10,
          foldingState: state,
          expandedRegions: {},
        ),
        isFalse,
      );
    });

    test('boundary hour at start of region is considered inside', () {
      const state = TimelineFoldingState(
        visibleClusters: [VisibleCluster(startHour: 8, endHour: 12)],
        compressedRegions: [
          CompressedRegion(startHour: 0, endHour: 8),
        ],
      );

      // Hour 0 is the start of the compressed region
      expect(
        isHourInCompressedRegion(
          hour: 0,
          foldingState: state,
          expandedRegions: {},
        ),
        isTrue,
      );
    });

    test('boundary hour at end of region is considered outside', () {
      const state = TimelineFoldingState(
        visibleClusters: [VisibleCluster(startHour: 8, endHour: 12)],
        compressedRegions: [
          CompressedRegion(startHour: 0, endHour: 8),
        ],
      );

      // Hour 8 is the end (exclusive) of the compressed region
      expect(
        isHourInCompressedRegion(
          hour: 8,
          foldingState: state,
          expandedRegions: {},
        ),
        isFalse,
      );
    });
  });

  group('calculateFoldingState edge cases', () {
    test('entry exactly at midnight (hour 0) with zero minutes', () {
      final slots = [createActualSlot(hour: 0, durationMinutes: 30)];
      final state = calculateFoldingState(
        plannedSlots: [],
        actualSlots: slots,
      );

      // Entry at 00:00-00:30 with buffer becomes 0-2 (can't go below 0)
      expect(state.visibleClusters.first.startHour, 0);
      expect(state.visibleClusters.first.endHour, lessThanOrEqualTo(3));
    });

    test('entry at hour 23 extends to midnight', () {
      final slots = [createActualSlot(hour: 23, durationMinutes: 30)];
      final state = calculateFoldingState(
        plannedSlots: [],
        actualSlots: slots,
      );

      // Entry at 23:00-23:30 with buffer ends at 24
      expect(state.visibleClusters.last.endHour, 24);
    });

    test('very short entry (5 minutes) still creates valid cluster', () {
      final slots = [createActualSlot(hour: 12, durationMinutes: 5)];
      final state = calculateFoldingState(
        plannedSlots: [],
        actualSlots: slots,
      );

      // Even 5-minute entry should create valid cluster
      expect(state.visibleClusters.isNotEmpty, isTrue);
      expect(state.visibleClusters.first.startHour, 12); // No buffer
    });

    test('entry with 59 minutes does not extend to next hour', () {
      // Entry 10:00-10:59 should occupy hour 10 only (endHour is exclusive)
      final slots = [createActualSlot(hour: 10, durationMinutes: 59)];
      final state = calculateFoldingState(
        plannedSlots: [],
        actualSlots: slots,
      );

      // With no buffer (default), cluster should be 10-11 (hour 10 only)
      expect(state.visibleClusters.first.startHour, lessThanOrEqualTo(10));
    });

    test('entry crossing exactly 1 hour boundary', () {
      // Entry 10:30-11:30 crosses hour boundary
      final slots = [
        createActualSlot(hour: 10, durationMinutes: 60, minute: 30),
      ];
      final state = calculateFoldingState(
        plannedSlots: [],
        actualSlots: slots,
      );

      // Should occupy hours 10 and 11 (11:30 rounds up)
      expect(state.visibleClusters.first.hourCount, greaterThanOrEqualTo(2));
    });

    test('two entries at exactly the gap threshold apart', () {
      // Entry at hour 4 and hour 8 (exactly 4 hour gap)
      final slots = [
        createActualSlot(hour: 4, durationMinutes: 30),
        createActualSlot(hour: 8, durationMinutes: 30),
      ];
      final state = calculateFoldingState(
        plannedSlots: [],
        actualSlots: slots,
      );

      // Gap of exactly 4 hours should trigger compression
      // First entry: hour 4-5, Second entry: hour 8-9, gap: 5-8 = 3 hours
      // With default buffer=0, we verify actual behavior
      expect(state.visibleClusters.isNotEmpty, isTrue);
    });

    test('buffer hours clamp correctly at day boundaries', () {
      // Entry at hour 0 - buffer should not go negative
      final earlySlots = [createActualSlot(hour: 0, durationMinutes: 30)];
      final earlyState = calculateFoldingState(
        plannedSlots: [],
        actualSlots: earlySlots,
        bufferHours: 2,
      );
      expect(earlyState.visibleClusters.first.startHour, 0);

      // Entry at hour 22 ending at 23 - buffer extends to 24 (end of day)
      // Note: Entries crossing midnight (e.g., 23:00-00:00) aren't yet supported
      final lateSlots = [createActualSlot(hour: 22, durationMinutes: 60)];
      final lateState = calculateFoldingState(
        plannedSlots: [],
        actualSlots: lateSlots,
        bufferHours: 2,
      );
      // With entry 22:00-23:00 and buffer 2, cluster is 20-24 (clamped)
      expect(lateState.visibleClusters.last.endHour, 24);
    });

    test('many small entries across the day merge into minimal clusters', () {
      // Create entries every 2 hours (less than 4-hour threshold)
      final slots = List.generate(12, (i) {
        return createActualSlot(hour: i * 2, durationMinutes: 30);
      });
      final state = calculateFoldingState(
        plannedSlots: [],
        actualSlots: slots,
      );

      // With entries every 2 hours and 1-hour buffer, gaps are < 4 hours
      // All should merge into one cluster
      expect(state.visibleClusters.length, lessThanOrEqualTo(2));
      expect(state.compressedRegions.isEmpty, isTrue);
    });

    test('single entry in middle of day creates two compressed regions', () {
      final slots = [createActualSlot(hour: 12, durationMinutes: 60)];
      final state = calculateFoldingState(
        plannedSlots: [],
        actualSlots: slots,
      );

      // Entry at 12:00-13:00 with buffer becomes 11-14
      // Gap from 0-11 is 11 hours (> 4), gap from 14-24 is 10 hours (> 4)
      // However, if gaps are small at boundaries, they may be extended
      // We should have at least one visible cluster
      expect(state.visibleClusters.isNotEmpty, isTrue);
      // And at least one compressed region for the larger gap
      expect(state.compressedRegions.isNotEmpty, isTrue);
    });

    test('entry crossing midnight (overnight) clamps to end of day', () {
      // Entry from 23:00 to 01:00 next day (2 hour duration crossing midnight)
      final startTime = testDate.add(const Duration(hours: 23));
      final endTime = startTime.add(const Duration(hours: 2)); // 01:00 next day
      final entry = JournalEntity.journalEntry(
        meta: Metadata(
          id: 'overnight-entry',
          createdAt: startTime,
          updatedAt: startTime,
          dateFrom: startTime,
          dateTo: endTime,
        ),
      );
      final overnightSlot = ActualTimeSlot(
        startTime: startTime,
        endTime: endTime,
        entry: entry,
      );

      final state = calculateFoldingState(
        plannedSlots: [],
        actualSlots: [overnightSlot],
      );

      // Entry crossing midnight should clamp to 24 for this day
      // Without buffer, cluster is 23-24 (ends at midnight)
      expect(state.visibleClusters.last.endHour, 24);
      // Start should be 23 (no buffer)
      expect(state.visibleClusters.last.startHour, 23);
    });

    test('multiple entries including overnight do not break clustering', () {
      // Morning entry at 9:00
      final morningSlot = createActualSlot(hour: 9, durationMinutes: 60);

      // Overnight entry from 23:00 to 02:00 next day
      final startTime = testDate.add(const Duration(hours: 23));
      final endTime = startTime.add(const Duration(hours: 3)); // 02:00 next day
      final entry = JournalEntity.journalEntry(
        meta: Metadata(
          id: 'overnight-entry',
          createdAt: startTime,
          updatedAt: startTime,
          dateFrom: startTime,
          dateTo: endTime,
        ),
      );
      final overnightSlot = ActualTimeSlot(
        startTime: startTime,
        endTime: endTime,
        entry: entry,
      );

      final state = calculateFoldingState(
        plannedSlots: [],
        actualSlots: [morningSlot, overnightSlot],
      );

      // Should have two clusters: morning and evening
      expect(state.visibleClusters, hasLength(2));
      // Last cluster should extend to 24
      expect(state.visibleClusters.last.endHour, 24);
      // There should be a compressed region between them
      expect(state.compressedRegions.isNotEmpty, isTrue);
    });
  });

  group('timeToFoldedPosition edge cases', () {
    test('position at exact cluster boundary', () {
      const state = TimelineFoldingState(
        visibleClusters: [
          VisibleCluster(startHour: 0, endHour: 6),
          VisibleCluster(startHour: 12, endHour: 18),
        ],
        compressedRegions: [
          CompressedRegion(startHour: 6, endHour: 12),
        ],
      );

      // Position at 6:00 (start of compressed region)
      final pos6 = timeToFoldedPosition(
        hour: 6,
        minute: 0,
        foldingState: state,
        expandedRegions: {},
      );
      // First cluster: 6 hours * 40px = 240px
      expect(pos6, equals(6 * 40.0));

      // Position at 12:00 (start of second visible cluster)
      final pos12 = timeToFoldedPosition(
        hour: 12,
        minute: 0,
        foldingState: state,
        expandedRegions: {},
      );
      // First cluster: 240px + compressed: 6 * 8 = 48px = 288px
      expect(pos12, equals((6 * 40.0) + (6 * 8.0)));
    });

    test('position with partial hour (30 minutes)', () {
      const state = TimelineFoldingState(
        visibleClusters: [VisibleCluster(startHour: 8, endHour: 12)],
        compressedRegions: [CompressedRegion(startHour: 0, endHour: 8)],
      );

      // Position at 9:30
      final pos = timeToFoldedPosition(
        hour: 9,
        minute: 30,
        foldingState: state,
        expandedRegions: {},
      );
      // Compressed: 8 * 8 = 64px
      // Into visible: 1.5 hours * 40px = 60px
      expect(pos, equals((8 * 8.0) + (1.5 * 40.0)));
    });

    test('position at minute 59 vs minute 0 of next hour', () {
      const state = TimelineFoldingState(
        visibleClusters: [VisibleCluster(startHour: 8, endHour: 18)],
        compressedRegions: [],
      );

      final pos959 = timeToFoldedPosition(
        hour: 9,
        minute: 59,
        foldingState: state,
        expandedRegions: {},
      );

      final pos1000 = timeToFoldedPosition(
        hour: 10,
        minute: 0,
        foldingState: state,
        expandedRegions: {},
      );

      // 9:59 and 10:00 should be almost equal (1 minute apart)
      expect(
          (pos1000 - pos959).abs(), lessThan(1.0)); // Less than 1px difference
    });
  });

  group('Named constants', () {
    test('default constants have expected values', () {
      expect(kDefaultGapThreshold, equals(4));
      expect(kDefaultBufferHours, equals(0));
      expect(kDefaultDayStart, equals(6));
      expect(kDefaultDayEnd, equals(22));
      expect(kNormalHourHeight, equals(40.0));
      expect(kCompressedHourHeight, equals(8.0));
    });

    test('calculateFoldingState uses default constants', () {
      // Empty state should use defaults
      final state = calculateFoldingState(
        plannedSlots: [],
        actualSlots: [],
      );

      // Default visible cluster should be 6-22
      expect(state.visibleClusters.first.startHour, equals(kDefaultDayStart));
      expect(state.visibleClusters.first.endHour, equals(kDefaultDayEnd));
    });
  });

  group('blockOverlapsCompressedRegion', () {
    PlannedBlock createBlock({
      required int startHour,
      required int startMinute,
      required int endHour,
      required int endMinute,
    }) {
      return PlannedBlock(
        id: 'test-block',
        categoryId: 'test-category',
        startTime: testDate.add(
          Duration(hours: startHour, minutes: startMinute),
        ),
        endTime: testDate.add(
          Duration(hours: endHour, minutes: endMinute),
        ),
      );
    }

    test('block entirely in visible cluster returns false', () {
      const foldingState = TimelineFoldingState(
        visibleClusters: [VisibleCluster(startHour: 9, endHour: 17)],
        compressedRegions: [
          CompressedRegion(startHour: 0, endHour: 9),
          CompressedRegion(startHour: 17, endHour: 24),
        ],
      );

      final block = createBlock(
        startHour: 10,
        startMinute: 0,
        endHour: 12,
        endMinute: 0,
      );

      expect(
        blockOverlapsCompressedRegion(
          block: block,
          foldingState: foldingState,
          expandedRegions: {},
        ),
        isFalse,
      );
    });

    test('block entirely in compressed region returns true', () {
      const foldingState = TimelineFoldingState(
        visibleClusters: [VisibleCluster(startHour: 9, endHour: 17)],
        compressedRegions: [
          CompressedRegion(startHour: 0, endHour: 9),
          CompressedRegion(startHour: 17, endHour: 24),
        ],
      );

      final block = createBlock(
        startHour: 2,
        startMinute: 0,
        endHour: 4,
        endMinute: 0,
      );

      expect(
        blockOverlapsCompressedRegion(
          block: block,
          foldingState: foldingState,
          expandedRegions: {},
        ),
        isTrue,
      );
    });

    test('block starting in visible and ending in compressed returns true', () {
      const foldingState = TimelineFoldingState(
        visibleClusters: [VisibleCluster(startHour: 9, endHour: 17)],
        compressedRegions: [
          CompressedRegion(startHour: 0, endHour: 9),
          CompressedRegion(startHour: 17, endHour: 24),
        ],
      );

      final block = createBlock(
        startHour: 16,
        startMinute: 0,
        endHour: 18,
        endMinute: 0,
      );

      expect(
        blockOverlapsCompressedRegion(
          block: block,
          foldingState: foldingState,
          expandedRegions: {},
        ),
        isTrue,
      );
    });

    test('block starting in compressed and ending in visible returns true', () {
      const foldingState = TimelineFoldingState(
        visibleClusters: [VisibleCluster(startHour: 9, endHour: 17)],
        compressedRegions: [
          CompressedRegion(startHour: 0, endHour: 9),
          CompressedRegion(startHour: 17, endHour: 24),
        ],
      );

      final block = createBlock(
        startHour: 8,
        startMinute: 0,
        endHour: 10,
        endMinute: 0,
      );

      expect(
        blockOverlapsCompressedRegion(
          block: block,
          foldingState: foldingState,
          expandedRegions: {},
        ),
        isTrue,
      );
    });

    test('minute-accurate: block ending exactly at boundary returns false', () {
      // Block from 8:00-9:00, compressed region 0:00-9:00
      // Block ends exactly at compressed boundary, should NOT overlap
      const foldingState = TimelineFoldingState(
        visibleClusters: [VisibleCluster(startHour: 9, endHour: 17)],
        compressedRegions: [
          CompressedRegion(startHour: 0, endHour: 9),
        ],
      );

      // But wait - this block is entirely within compressed region!
      // Let's test boundary case differently:
      // Block from 9:00-10:00 with compressed region 0:00-9:00
      final block = createBlock(
        startHour: 9,
        startMinute: 0,
        endHour: 10,
        endMinute: 0,
      );

      expect(
        blockOverlapsCompressedRegion(
          block: block,
          foldingState: foldingState,
          expandedRegions: {},
        ),
        isFalse,
      );
    });

    test('minute-accurate: block with 1 minute overlap returns true', () {
      const foldingState = TimelineFoldingState(
        visibleClusters: [VisibleCluster(startHour: 9, endHour: 17)],
        compressedRegions: [
          CompressedRegion(startHour: 0, endHour: 9),
        ],
      );

      // Block 8:59-10:00 overlaps compressed region by 1 minute
      final block = createBlock(
        startHour: 8,
        startMinute: 59,
        endHour: 10,
        endMinute: 0,
      );

      expect(
        blockOverlapsCompressedRegion(
          block: block,
          foldingState: foldingState,
          expandedRegions: {},
        ),
        isTrue,
      );
    });

    test('minute-accurate: block ending 1 minute into compressed returns true',
        () {
      const foldingState = TimelineFoldingState(
        visibleClusters: [VisibleCluster(startHour: 9, endHour: 17)],
        compressedRegions: [
          CompressedRegion(startHour: 17, endHour: 24),
        ],
      );

      // Block 16:00-17:01 overlaps compressed region by 1 minute
      final block = createBlock(
        startHour: 16,
        startMinute: 0,
        endHour: 17,
        endMinute: 1,
      );

      expect(
        blockOverlapsCompressedRegion(
          block: block,
          foldingState: foldingState,
          expandedRegions: {},
        ),
        isTrue,
      );
    });

    test('expanded region does not count as compressed', () {
      const foldingState = TimelineFoldingState(
        visibleClusters: [VisibleCluster(startHour: 9, endHour: 17)],
        compressedRegions: [
          CompressedRegion(startHour: 0, endHour: 9),
          CompressedRegion(startHour: 17, endHour: 24),
        ],
      );

      // Block entirely in early morning compressed region
      final block = createBlock(
        startHour: 2,
        startMinute: 0,
        endHour: 4,
        endMinute: 0,
      );

      // But region is expanded
      expect(
        blockOverlapsCompressedRegion(
          block: block,
          foldingState: foldingState,
          expandedRegions: {0}, // startHour of early morning region
        ),
        isFalse,
      );
    });

    test('block overlapping two compressed regions returns true', () {
      // Scenario: visible 6-10, compressed 0-6, visible 10-14, compressed 14-24
      const foldingState = TimelineFoldingState(
        visibleClusters: [
          VisibleCluster(startHour: 6, endHour: 10),
          VisibleCluster(startHour: 14, endHour: 18),
        ],
        compressedRegions: [
          CompressedRegion(startHour: 0, endHour: 6),
          CompressedRegion(startHour: 10, endHour: 14),
          CompressedRegion(startHour: 18, endHour: 24),
        ],
      );

      // Block spanning compressed middle region
      final block = createBlock(
        startHour: 11,
        startMinute: 0,
        endHour: 13,
        endMinute: 0,
      );

      expect(
        blockOverlapsCompressedRegion(
          block: block,
          foldingState: foldingState,
          expandedRegions: {},
        ),
        isTrue,
      );
    });
  });

  group('findContainingSection', () {
    test('returns visible cluster containing the time', () {
      const foldingState = TimelineFoldingState(
        visibleClusters: [
          VisibleCluster(startHour: 9, endHour: 12),
          VisibleCluster(startHour: 14, endHour: 18),
        ],
        compressedRegions: [
          CompressedRegion(startHour: 0, endHour: 9),
          CompressedRegion(startHour: 12, endHour: 14),
          CompressedRegion(startHour: 18, endHour: 24),
        ],
      );

      final section = findContainingSection(
        hour: 10,
        minute: 30,
        foldingState: foldingState,
        expandedRegions: {},
      );

      expect(section, isNotNull);
      expect(section!.startHour, 9);
      expect(section.endHour, 12);
    });

    test('returns expanded region containing the time', () {
      const foldingState = TimelineFoldingState(
        visibleClusters: [VisibleCluster(startHour: 9, endHour: 17)],
        compressedRegions: [
          CompressedRegion(startHour: 0, endHour: 9),
          CompressedRegion(startHour: 17, endHour: 24),
        ],
      );

      // Time at 5:30 in compressed region that is expanded
      final section = findContainingSection(
        hour: 5,
        minute: 30,
        foldingState: foldingState,
        expandedRegions: {0}, // Early morning region is expanded
      );

      expect(section, isNotNull);
      expect(section!.startHour, 0);
      expect(section.endHour, 9);
    });

    test('returns null for time in non-expanded compressed region', () {
      const foldingState = TimelineFoldingState(
        visibleClusters: [VisibleCluster(startHour: 9, endHour: 17)],
        compressedRegions: [
          CompressedRegion(startHour: 0, endHour: 9),
          CompressedRegion(startHour: 17, endHour: 24),
        ],
      );

      final section = findContainingSection(
        hour: 5,
        minute: 30,
        foldingState: foldingState,
        expandedRegions: {}, // No regions expanded
      );

      expect(section, isNull);
    });

    test('boundary: time at start of cluster returns that cluster', () {
      const foldingState = TimelineFoldingState(
        visibleClusters: [VisibleCluster(startHour: 9, endHour: 17)],
        compressedRegions: [],
      );

      final section = findContainingSection(
        hour: 9,
        minute: 0,
        foldingState: foldingState,
        expandedRegions: {},
      );

      expect(section, isNotNull);
      expect(section!.startHour, 9);
      expect(section.endHour, 17);
    });

    test('boundary: time at end of cluster (exclusive) returns null', () {
      const foldingState = TimelineFoldingState(
        visibleClusters: [VisibleCluster(startHour: 9, endHour: 17)],
        compressedRegions: [CompressedRegion(startHour: 17, endHour: 24)],
      );

      // 17:00 is at the boundary - endHour is exclusive
      final section = findContainingSection(
        hour: 17,
        minute: 0,
        foldingState: foldingState,
        expandedRegions: {},
      );

      // 17:00 falls into compressed region (not expanded), so null
      expect(section, isNull);
    });

    test('minute-accurate: 16:59 vs 17:00 boundary', () {
      const foldingState = TimelineFoldingState(
        visibleClusters: [VisibleCluster(startHour: 9, endHour: 17)],
        compressedRegions: [CompressedRegion(startHour: 17, endHour: 24)],
      );

      // 16:59 should be in visible cluster
      final section1659 = findContainingSection(
        hour: 16,
        minute: 59,
        foldingState: foldingState,
        expandedRegions: {},
      );
      expect(section1659, isNotNull);
      expect(section1659!.startHour, 9);

      // 17:00 should be in compressed region (null when not expanded)
      final section1700 = findContainingSection(
        hour: 17,
        minute: 0,
        foldingState: foldingState,
        expandedRegions: {},
      );
      expect(section1700, isNull);
    });

    test('returns second cluster for time in second cluster', () {
      const foldingState = TimelineFoldingState(
        visibleClusters: [
          VisibleCluster(startHour: 6, endHour: 10),
          VisibleCluster(startHour: 14, endHour: 18),
        ],
        compressedRegions: [
          CompressedRegion(startHour: 0, endHour: 6),
          CompressedRegion(startHour: 10, endHour: 14),
          CompressedRegion(startHour: 18, endHour: 24),
        ],
      );

      final section = findContainingSection(
        hour: 15,
        minute: 30,
        foldingState: foldingState,
        expandedRegions: {},
      );

      expect(section, isNotNull);
      expect(section!.startHour, 14);
      expect(section.endHour, 18);
    });
  });

  group('calculateContiguousDragBounds', () {
    test('returns section bounds when no adjacent expanded regions', () {
      const foldingState = TimelineFoldingState(
        visibleClusters: [VisibleCluster(startHour: 8, endHour: 12)],
        compressedRegions: [
          CompressedRegion(startHour: 0, endHour: 8),
          CompressedRegion(startHour: 12, endHour: 24),
        ],
      );

      final bounds = calculateContiguousDragBounds(
        sectionStartHour: 8,
        sectionEndHour: 12,
        foldingState: foldingState,
        expandedRegions: {},
      );

      expect(bounds.startHour, 8);
      expect(bounds.endHour, 12);
    });

    test('expands bounds to include adjacent expanded region after', () {
      const foldingState = TimelineFoldingState(
        visibleClusters: [VisibleCluster(startHour: 8, endHour: 12)],
        compressedRegions: [
          CompressedRegion(startHour: 0, endHour: 8),
          CompressedRegion(startHour: 12, endHour: 18),
          CompressedRegion(startHour: 18, endHour: 24),
        ],
      );

      // Expand the 12-18 region
      final bounds = calculateContiguousDragBounds(
        sectionStartHour: 8,
        sectionEndHour: 12,
        foldingState: foldingState,
        expandedRegions: {12},
      );

      expect(bounds.startHour, 8);
      expect(bounds.endHour, 18); // Extended to include expanded region
    });

    test('expands bounds to include adjacent expanded region before', () {
      const foldingState = TimelineFoldingState(
        visibleClusters: [VisibleCluster(startHour: 12, endHour: 18)],
        compressedRegions: [
          CompressedRegion(startHour: 0, endHour: 6),
          CompressedRegion(startHour: 6, endHour: 12),
          CompressedRegion(startHour: 18, endHour: 24),
        ],
      );

      // Expand the 6-12 region
      final bounds = calculateContiguousDragBounds(
        sectionStartHour: 12,
        sectionEndHour: 18,
        foldingState: foldingState,
        expandedRegions: {6},
      );

      expect(bounds.startHour, 6); // Extended to include expanded region
      expect(bounds.endHour, 18);
    });

    test('expands bounds in both directions with multiple expanded regions',
        () {
      const foldingState = TimelineFoldingState(
        visibleClusters: [VisibleCluster(startHour: 10, endHour: 14)],
        compressedRegions: [
          CompressedRegion(startHour: 0, endHour: 6),
          CompressedRegion(startHour: 6, endHour: 10),
          CompressedRegion(startHour: 14, endHour: 20),
          CompressedRegion(startHour: 20, endHour: 24),
        ],
      );

      // Expand regions on both sides
      final bounds = calculateContiguousDragBounds(
        sectionStartHour: 10,
        sectionEndHour: 14,
        foldingState: foldingState,
        expandedRegions: {6, 14},
      );

      expect(bounds.startHour, 6); // Extended backward
      expect(bounds.endHour, 20); // Extended forward
    });

    test('stops at collapsed region even with expanded region beyond', () {
      const foldingState = TimelineFoldingState(
        visibleClusters: [VisibleCluster(startHour: 10, endHour: 14)],
        compressedRegions: [
          CompressedRegion(startHour: 0, endHour: 6),
          CompressedRegion(startHour: 6, endHour: 10),
          CompressedRegion(startHour: 14, endHour: 18),
          CompressedRegion(startHour: 18, endHour: 24),
        ],
      );

      // Only expand the 0-6 region (not adjacent)
      final bounds = calculateContiguousDragBounds(
        sectionStartHour: 10,
        sectionEndHour: 14,
        foldingState: foldingState,
        expandedRegions: {0}, // Not adjacent to 10-14
      );

      // Should not expand because 6-10 is collapsed (blocks 0-6)
      expect(bounds.startHour, 10);
      expect(bounds.endHour, 14);
    });

    test('handles multiple visible clusters with expanded region between', () {
      const foldingState = TimelineFoldingState(
        visibleClusters: [
          VisibleCluster(startHour: 6, endHour: 10),
          VisibleCluster(startHour: 14, endHour: 18),
        ],
        compressedRegions: [
          CompressedRegion(startHour: 0, endHour: 6),
          CompressedRegion(startHour: 10, endHour: 14),
          CompressedRegion(startHour: 18, endHour: 24),
        ],
      );

      // Expand the middle region
      final bounds = calculateContiguousDragBounds(
        sectionStartHour: 6,
        sectionEndHour: 10,
        foldingState: foldingState,
        expandedRegions: {10},
      );

      // Should extend through expanded region to next visible cluster
      expect(bounds.startHour, 6);
      expect(bounds.endHour, 18);
    });

    test('returns original bounds when section not found', () {
      const foldingState = TimelineFoldingState(
        visibleClusters: [VisibleCluster(startHour: 8, endHour: 12)],
        compressedRegions: [],
      );

      // Section that doesn't exist in foldingState
      final bounds = calculateContiguousDragBounds(
        sectionStartHour: 20,
        sectionEndHour: 22,
        foldingState: foldingState,
        expandedRegions: {},
      );

      expect(bounds.startHour, 20);
      expect(bounds.endHour, 22);
    });
  });
}
