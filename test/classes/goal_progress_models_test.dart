import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_progress_models.dart';

void main() {
  test('GoalCriterionProgress round-trips with pace intact', () {
    const progress = GoalCriterionProgress(
      criterionId: 'steps',
      actual: 8585.7,
      target: 10000,
      ratio: 0.8586,
      satisfied: false,
      sampleCount: 7,
      paceFeasible: false,
    );
    final decoded = GoalCriterionProgress.fromJson(
      jsonDecode(jsonEncode(progress)) as Map<String, dynamic>,
    );
    expect(decoded, progress);
    expect(decoded.paceFeasible, isFalse);
  });
}
