import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/labels/services/label_assignment_rate_limiter.dart';

void main() {
  test('handles thousands of tasks in memory without errors', () {
    final limiter = LabelAssignmentRateLimiter();
    for (var i = 0; i < 3000; i++) {
      limiter.recordAssignment('task_$i');
    }
    expect(limiter.history.length, 3000);

    // Clear should reset the state
    limiter.clearHistory();
    expect(limiter.history, isEmpty);
  });
}
