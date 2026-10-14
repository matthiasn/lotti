import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/features/goals/evaluation/goal_evaluation.dart';
import 'package:lotti/features/goals/runtime/goal_wake_facts.dart';
import 'package:lotti/features/goals/workflow/goal_agent_contract.dart';
import 'package:lotti/features/goals/workflow/goal_daily_briefing.dart';

import '../../agents/test_data/entity_factories.dart';

void main() {
  GoalWakeFacts facts({required bool periodReported}) => GoalWakeFacts(
    trackStatus: GoalTrackStatus.onTrack,
    previousStatus: GoalTrackStatus.onTrack,
    evaluation: const GoalEvaluation(
      attainment: 1,
      satisfied: true,
      onTrackByTrend: true,
      dataCoverage: 1,
      results: {},
    ),
    shortTermAttainment: 1,
    periodReported: periodReported,
  );

  group('goalDailyBriefingDue', () {
    test('is due for the first report of a period on an automatic wake', () {
      expect(
        goalDailyBriefingDue(facts(periodReported: false), interactive: false),
        isTrue,
      );
    });

    test('is not due once the period has its report', () {
      expect(
        goalDailyBriefingDue(facts(periodReported: true), interactive: false),
        isFalse,
      );
    });

    test('a chat turn answers the user; it is never the morning read', () {
      expect(
        goalDailyBriefingDue(facts(periodReported: false), interactive: true),
        isFalse,
      );
    });
  });

  group('goalPreviousBriefingFacts', () {
    // The stored shape: the summary on the report, the steps the user saw as
    // one list in the persisted sections.
    final yesterday = makeTestReport(
      tldr: 'Two walks this week; one more keeps pace.',
      provenance: {
        'periodKey': '2026-08-07',
        GoalReportProvenanceKeys.sections: {
          GoalReportSectionKeys.currentPeriod: 'One walk today.',
          GoalReportSectionKeys.nextActions: [
            'Log the evening walk.',
            'Walk after lunch on Thursday.',
          ],
        },
      },
    );

    test("carries yesterday's summary and next steps into today's wake", () {
      expect(goalPreviousBriefingFacts(yesterday, periodKey: '2026-08-08'), {
        'periodKey': '2026-08-07',
        'tldr': 'Two walks this week; one more keeps pace.',
        'nextSteps': ['Log the evening walk.', 'Walk after lunch on Thursday.'],
      });
    });

    test("today's own report is not the previous briefing", () {
      expect(
        goalPreviousBriefingFacts(yesterday, periodKey: '2026-08-07'),
        isNull,
      );
    });

    test('a report that said nothing to follow up carries nothing', () {
      expect(goalPreviousBriefingFacts(null, periodKey: '2026-08-08'), isNull);
      expect(
        goalPreviousBriefingFacts(
          makeTestReport(provenance: {'periodKey': '2026-08-07'}),
          periodKey: '2026-08-08',
        ),
        isNull,
      );
    });

    test('a summary without steps still carries the summary', () {
      expect(
        goalPreviousBriefingFacts(
          makeTestReport(
            tldr: 'Held the line.',
            provenance: {'periodKey': '2026-08-07'},
          ),
          periodKey: '2026-08-08',
        ),
        {'periodKey': '2026-08-07', 'tldr': 'Held the line.'},
      );
    });
  });

  test('the briefing instruction puts the weight on concrete next steps and '
      'on following up the previous ones', () {
    expect(goalDailyBriefingInstruction, contains('update_goal_report'));
    expect(goalDailyBriefingInstruction, contains('nextActions.later'));
    expect(goalDailyBriefingInstruction, contains('previousBriefing'));
    expect(goalDailyBriefingInstruction, contains('nextSteps'));
    expect(goalDailyBriefingReportInstruction, contains('update_goal_report'));
  });
}
