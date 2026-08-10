import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_nudge_models.dart';
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

  group('goalNudgeStatusLabel', () {
    /// Captures the function's return value under a real localized
    /// BuildContext, since the function itself is not a widget.
    Future<String> labelFor(WidgetTester tester, GoalNudgeStatus status) async {
      late String result;
      await tester.pumpWidget(
        makeTestableWidget(
          Builder(
            builder: (context) {
              result = goalNudgeStatusLabel(context, status);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return result;
    }

    testWidgets('retired returns the localized "Retired" label', (
      tester,
    ) async {
      expect(
        await labelFor(tester, GoalNudgeStatus.retired),
        'Retired',
      );
    });

    testWidgets('expired returns the localized "Expired" label', (
      tester,
    ) async {
      expect(
        await labelFor(tester, GoalNudgeStatus.expired),
        'Expired',
      );
    });

    testWidgets('superseded returns the localized "Superseded" label', (
      tester,
    ) async {
      expect(
        await labelFor(tester, GoalNudgeStatus.superseded),
        'Superseded',
      );
    });

    testWidgets('dismissed returns the localized "Dismissed" label', (
      tester,
    ) async {
      expect(
        await labelFor(tester, GoalNudgeStatus.dismissed),
        'Dismissed',
      );
    });

    testWidgets(
      'pipeline statuses (draft/ready/active/failed) never render a '
      'PAST-outcome label — they return the empty string',
      (tester) async {
        for (final status in [
          GoalNudgeStatus.draft,
          GoalNudgeStatus.ready,
          GoalNudgeStatus.active,
          GoalNudgeStatus.failed,
        ]) {
          expect(
            await labelFor(tester, status),
            '',
            reason: '$status is a pipeline state, not a past outcome',
          );
        }
      },
    );
  });
}
