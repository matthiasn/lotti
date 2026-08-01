import 'package:flutter_test/flutter_test.dart';
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
      );

      expect(record.healthScore, 85);
      expect(record.completedTaskCount, 5);
      expect(record.totalTaskCount, 10);
      expect(record.blockedTaskCount, 2);
      expect(record.aiSummary, 'Custom summary');
      // Derived computation, not just constructor echo: 5 of 10 done.
      expect(record.overviewListItem.taskRollup.completionRatio, 0.5);
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
    test('stores task, one-liner, and estimated duration', () {
      final summary = makeTestTaskSummary(
        estimatedDuration: const Duration(hours: 1, minutes: 30),
        oneLiner: 'Implementation done, release next',
      );

      expect(summary.task.data.title, 'Test Task');
      expect(summary.oneLiner, 'Implementation done, release next');
      expect(summary.estimatedDuration, const Duration(hours: 1, minutes: 30));
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
