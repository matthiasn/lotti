import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/task_resolution_time_series.dart';
import 'package:lotti/features/agents/model/task_resolution_time_series_utils.dart';

void main() {
  group('computeResolutionTimeSeries', () {
    test('returns empty buckets when no entries', () {
      final result = computeResolutionTimeSeries([]);
      expect(result.dailyBuckets, isEmpty);
    });

    test('returns empty buckets when all entries are unresolved', () {
      final result = computeResolutionTimeSeries([
        TaskResolutionEntry(
          agentId: 'a1',
          taskId: 't1',
          agentCreatedAt: DateTime(2024, 3, 15, 10),
        ),
        TaskResolutionEntry(
          agentId: 'a2',
          taskId: 't2',
          agentCreatedAt: DateTime(2024, 3, 16, 10),
        ),
      ]);
      expect(result.dailyBuckets, isEmpty);
    });

    test('computes single-day bucket correctly', () {
      final agentCreated = DateTime(2024, 3, 15, 10);
      final resolved = DateTime(2024, 3, 15, 12); // 2 hours later

      final result = computeResolutionTimeSeries([
        TaskResolutionEntry(
          agentId: 'a1',
          taskId: 't1',
          agentCreatedAt: agentCreated,
          resolvedAt: resolved,
          resolution: 'done',
        ),
      ]);

      expect(result.dailyBuckets, hasLength(1));
      expect(result.dailyBuckets.first.date, DateTime(2024, 3, 15));
      expect(result.dailyBuckets.first.resolvedCount, 1);
      expect(
        result.dailyBuckets.first.averageMttr,
        const Duration(hours: 2),
      );
    });

    test('computes average MTTR across multiple entries on same day', () {
      final result = computeResolutionTimeSeries([
        TaskResolutionEntry(
          agentId: 'a1',
          taskId: 't1',
          agentCreatedAt: DateTime(2024, 3, 15, 10),
          resolvedAt: DateTime(2024, 3, 15, 12), // 2h
          resolution: 'done',
        ),
        TaskResolutionEntry(
          agentId: 'a2',
          taskId: 't2',
          agentCreatedAt: DateTime(2024, 3, 15, 8),
          resolvedAt: DateTime(2024, 3, 15, 12), // 4h
          resolution: 'rejected',
        ),
      ]);

      expect(result.dailyBuckets, hasLength(1));
      expect(result.dailyBuckets.first.resolvedCount, 2);
      // Average: (2h + 4h) / 2 = 3h
      expect(
        result.dailyBuckets.first.averageMttr,
        const Duration(hours: 3),
      );
    });

    test('fills gaps between days with zero-count buckets', () {
      final result = computeResolutionTimeSeries([
        TaskResolutionEntry(
          agentId: 'a1',
          taskId: 't1',
          agentCreatedAt: DateTime(2024, 3, 15, 10),
          resolvedAt: DateTime(2024, 3, 15, 12),
          resolution: 'done',
        ),
        TaskResolutionEntry(
          agentId: 'a2',
          taskId: 't2',
          agentCreatedAt: DateTime(2024, 3, 17, 8),
          resolvedAt: DateTime(2024, 3, 18, 8), // resolved on the 18th
          resolution: 'done',
        ),
      ]);

      // Days: 15, 16, 17, 18
      expect(result.dailyBuckets, hasLength(4));

      // Day 15: 1 resolved
      expect(result.dailyBuckets[0].date, DateTime(2024, 3, 15));
      expect(result.dailyBuckets[0].resolvedCount, 1);

      // Day 16: gap
      expect(result.dailyBuckets[1].date, DateTime(2024, 3, 16));
      expect(result.dailyBuckets[1].resolvedCount, 0);
      expect(result.dailyBuckets[1].averageMttr, Duration.zero);

      // Day 17: gap
      expect(result.dailyBuckets[2].date, DateTime(2024, 3, 17));
      expect(result.dailyBuckets[2].resolvedCount, 0);

      // Day 18: 1 resolved (agent created on 17th, resolved on 18th = 24h)
      expect(result.dailyBuckets[3].date, DateTime(2024, 3, 18));
      expect(result.dailyBuckets[3].resolvedCount, 1);
      expect(
        result.dailyBuckets[3].averageMttr,
        const Duration(hours: 24),
      );
    });

    test('ignores unresolved entries while computing resolved buckets', () {
      final result = computeResolutionTimeSeries([
        TaskResolutionEntry(
          agentId: 'a1',
          taskId: 't1',
          agentCreatedAt: DateTime(2024, 3, 15, 10),
          resolvedAt: DateTime(2024, 3, 15, 13), // 3h
          resolution: 'done',
        ),
        // Unresolved — should be skipped
        TaskResolutionEntry(
          agentId: 'a2',
          taskId: 't2',
          agentCreatedAt: DateTime(2024, 3, 15, 10),
        ),
      ]);

      expect(result.dailyBuckets, hasLength(1));
      expect(result.dailyBuckets.first.resolvedCount, 1);
      expect(
        result.dailyBuckets.first.averageMttr,
        const Duration(hours: 3),
      );
    });

    test('groups by resolved date, not agent creation date', () {
      // Agent created on the 14th but resolved on the 16th.
      final result = computeResolutionTimeSeries([
        TaskResolutionEntry(
          agentId: 'a1',
          taskId: 't1',
          agentCreatedAt: DateTime(2024, 3, 14, 10),
          resolvedAt: DateTime(2024, 3, 16, 10), // 48h MTTR
          resolution: 'done',
        ),
      ]);

      expect(result.dailyBuckets, hasLength(1));
      expect(result.dailyBuckets.first.date, DateTime(2024, 3, 16));
      expect(
        result.dailyBuckets.first.averageMttr,
        const Duration(hours: 48),
      );
    });

    test('handles multi-day resolution times correctly', () {
      final result = computeResolutionTimeSeries([
        // Agent created on the 10th, resolved on the 15th (5 days)
        TaskResolutionEntry(
          agentId: 'a1',
          taskId: 't1',
          agentCreatedAt: DateTime(2024, 3, 10, 8),
          resolvedAt: DateTime(2024, 3, 15, 8),
          resolution: 'done',
        ),
        // Agent created on the 13th, resolved on the 15th (2 days)
        TaskResolutionEntry(
          agentId: 'a2',
          taskId: 't2',
          agentCreatedAt: DateTime(2024, 3, 13, 8),
          resolvedAt: DateTime(2024, 3, 15, 8),
          resolution: 'rejected',
        ),
      ]);

      expect(result.dailyBuckets, hasLength(1));
      expect(result.dailyBuckets.first.resolvedCount, 2);
      // Average: (5 days + 2 days) / 2 = 3.5 days = 84 hours
      expect(
        result.dailyBuckets.first.averageMttr,
        const Duration(hours: 84),
      );
    });
  });
}
