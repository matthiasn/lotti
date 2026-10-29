import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/goals/workflow/goal_agent_contract.dart';
import 'package:lotti/features/goals/workflow/goal_daily_briefing.dart';
import 'package:lotti/features/goals/workflow/goal_report_instructions.dart';

void main() {
  test('the escalation period tells a user request from a wake Phase A '
      'armed', () {
    expect(
      GoalReportRefreshCause.of(reportRefresh: false, escalationPeriod: null),
      GoalReportRefreshCause.none,
    );
    expect(
      GoalReportRefreshCause.of(
        reportRefresh: false,
        escalationPeriod: '2026-08-09',
      ),
      GoalReportRefreshCause.none,
    );
    expect(
      GoalReportRefreshCause.of(reportRefresh: true, escalationPeriod: null),
      GoalReportRefreshCause.userRequested,
    );
    expect(
      GoalReportRefreshCause.of(
        reportRefresh: true,
        escalationPeriod: '2026-08-09',
      ),
      GoalReportRefreshCause.automatic,
    );
  });

  test('only the user-requested texts claim the user asked', () {
    expect(goalUserRefreshInstruction, contains('USER REQUESTED'));
    expect(goalUserReportRequestInstruction, contains('USER EXPLICITLY'));
    expect(goalAutomaticRefreshInstruction, isNot(contains('USER')));
    expect(goalAutomaticRefreshInstruction, contains('sinceLastReport'));
  });

  group('the forced retry names the strongest reason that applies', () {
    String instruction({
      bool userRequestedReport = false,
      GoalReportRefreshCause refreshCause = GoalReportRefreshCause.none,
      bool statusTransitioned = false,
      bool dailyBriefing = false,
    }) => goalForcedReportInstruction(
      userRequestedReport: userRequestedReport,
      refreshCause: refreshCause,
      statusTransitioned: statusTransitioned,
      dailyBriefing: dailyBriefing,
    );

    test('a chat request outranks everything', () {
      expect(
        instruction(
          userRequestedReport: true,
          refreshCause: GoalReportRefreshCause.userRequested,
          statusTransitioned: true,
          dailyBriefing: true,
        ),
        contains('asked in chat'),
      );
    });

    test('then a refresh the user asked for', () {
      expect(
        instruction(
          refreshCause: GoalReportRefreshCause.userRequested,
          statusTransitioned: true,
        ),
        contains('editing a habit day'),
      );
    });

    test('an armed wake never claims the user edited a habit day', () {
      for (final (transitioned, briefing, expected) in [
        (true, true, goalStatusTransitionReportInstruction),
        (false, true, goalDailyBriefingReportInstruction),
      ]) {
        expect(
          instruction(
            refreshCause: GoalReportRefreshCause.automatic,
            statusTransitioned: transitioned,
            dailyBriefing: briefing,
          ),
          expected,
        );
      }
      final outOfDate = instruction(
        refreshCause: GoalReportRefreshCause.automatic,
      );
      expect(outOfDate, isNot(contains('habit day')));
      expect(
        outOfDate,
        allOf(contains('out of date'), contains('sinceLastReport')),
      );
    });
  });
}
