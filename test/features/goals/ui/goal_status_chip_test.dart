import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/features/goals/ui/goal_status_chip.dart';

import '../../../widget_test_utils.dart';

void main() {
  testWidgets('every track status renders its localized label', (
    tester,
  ) async {
    const expected = {
      GoalTrackStatus.onTrack: 'On track',
      GoalTrackStatus.atRisk: 'At risk',
      GoalTrackStatus.offTrack: 'Off track',
      GoalTrackStatus.recovering: 'Recovering',
      GoalTrackStatus.achieved: 'Achieved',
      GoalTrackStatus.insufficientData: 'No data',
    };
    for (final MapEntry(key: status, value: label) in expected.entries) {
      await tester.pumpWidget(
        makeTestableWidget(GoalStatusChip(status: status)),
      );
      expect(find.text(label), findsOneWidget, reason: '$status');
    }
  });
}
