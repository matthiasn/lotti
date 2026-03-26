import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/projects/ui/model/project_list_detail_models.dart';

import '../../test_utils.dart';

void main() {
  group('ProjectRecord', () {
    test('stores all fields correctly', () {
      final record = makeTestProjectRecord(
        healthScore: 85,
        completedTaskCount: 5,
        totalTaskCount: 10,
        blockedTaskCount: 2,
        aiSummary: 'Custom summary',
        recommendations: ['Do A', 'Do B'],
      );

      expect(record.healthScore, 85);
      expect(record.completedTaskCount, 5);
      expect(record.totalTaskCount, 10);
      expect(record.blockedTaskCount, 2);
      expect(record.aiSummary, 'Custom summary');
      expect(record.recommendations, ['Do A', 'Do B']);
    });

    test('exposes an overview list item backed by the real list model', () {
      final record = makeTestProjectRecord(
        completedTaskCount: 4,
        totalTaskCount: 6,
        blockedTaskCount: 2,
      );

      final item = record.overviewListItem;

      expect(item.project, same(record.project));
      expect(item.category, same(record.category));
      expect(item.taskRollup.completedTaskCount, 4);
      expect(item.taskRollup.totalTaskCount, 6);
      expect(item.taskRollup.blockedTaskCount, 2);
    });
  });

  group('TaskSummary', () {
    test('stores task and estimated duration', () {
      final summary = makeTestTaskSummary(
        estimatedDuration: const Duration(hours: 1, minutes: 30),
      );

      expect(summary.task.data.title, 'Test Task');
      expect(summary.estimatedDuration, const Duration(hours: 1, minutes: 30));
    });
  });

  group('ReviewSession', () {
    test('has sensible defaults', () {
      const session = ReviewSession(
        id: 'r1',
        summaryLabel: 'Week 1',
        rating: 3,
      );

      expect(session.metrics, isEmpty);
      expect(session.note, isNull);
      expect(session.expanded, isFalse);
    });

    test('stores all fields when provided', () {
      final session = makeTestReviewSession(
        id: 'r2',
        summaryLabel: 'Week 2',
        rating: 5,
        metrics: const [
          ReviewMetric(type: ReviewMetricType.accuracy, rating: 5),
        ],
        note: 'Great week',
        expanded: true,
      );

      expect(session.id, 'r2');
      expect(session.summaryLabel, 'Week 2');
      expect(session.rating, 5);
      expect(session.metrics, hasLength(1));
      expect(session.metrics.first.type, ReviewMetricType.accuracy);
      expect(session.note, 'Great week');
      expect(session.expanded, isTrue);
    });
  });

  group('ReviewMetricType', () {
    test('has all expected values', () {
      expect(
        ReviewMetricType.values,
        containsAll([
          ReviewMetricType.communication,
          ReviewMetricType.usefulness,
          ReviewMetricType.accuracy,
        ]),
      );
    });
  });

  group('ProjectListData', () {
    test('stores categories, projects, and currentTime', () {
      final data = makeTestProjectListData();

      expect(data.categories, hasLength(2));
      expect(data.projects, hasLength(2));
      expect(data.currentTime, DateTime(2026, 4, 2, 9, 30));
    });
  });
}
