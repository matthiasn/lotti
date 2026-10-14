import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
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
    final specCreated = DateTime(2026, 8);
    // The stored shape: the summary on the report, the steps the user saw as
    // one list in the persisted sections.
    final yesterday = makeTestReport(
      tldr: 'Two walks this week; one more keeps pace.',
      provenance: {
        'periodKey': '2026-08-07',
        'specVersionId': 'spec-v1',
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
      expect(
        goalPreviousBriefingFacts(
          yesterday,
          periodKey: '2026-08-08',
          specVersionId: 'spec-v1',
          specCreatedAt: specCreated,
        ),
        {
          'periodKey': '2026-08-07',
          'tldr': 'Two walks this week; one more keeps pace.',
          'nextSteps': [
            'Log the evening walk.',
            'Walk after lunch on Thursday.',
          ],
        },
      );
    });

    test("today's own report is not the previous briefing", () {
      expect(
        goalPreviousBriefingFacts(
          yesterday,
          periodKey: '2026-08-07',
          specVersionId: 'spec-v1',
          specCreatedAt: specCreated,
        ),
        isNull,
      );
    });

    test('a report that said nothing to follow up carries nothing', () {
      expect(
        goalPreviousBriefingFacts(
          null,
          periodKey: '2026-08-08',
          specVersionId: 'spec-v1',
          specCreatedAt: specCreated,
        ),
        isNull,
      );
      expect(
        goalPreviousBriefingFacts(
          makeTestReport(provenance: {'periodKey': '2026-08-07'}),
          periodKey: '2026-08-08',
          specVersionId: 'spec-v1',
          specCreatedAt: specCreated,
        ),
        isNull,
      );
    });

    test('a report from after the evaluated day is not its previous '
        'briefing — an overdue wake must not read the future', () {
      expect(
        goalPreviousBriefingFacts(
          yesterday,
          periodKey: '2026-08-06',
          specVersionId: 'spec-v1',
          specCreatedAt: specCreated,
        ),
        isNull,
      );
    });

    test('a report written for a superseded spec is not followed up', () {
      expect(
        goalPreviousBriefingFacts(
          yesterday,
          periodKey: '2026-08-08',
          specVersionId: 'spec-v2',
          specCreatedAt: specCreated,
        ),
        isNull,
      );
    });

    test('a report that names no spec is followed up only when it was written '
        'after the spec', () {
      AgentReportEntity legacy(DateTime createdAt) => makeTestReport(
        tldr: 'Held the line.',
        createdAt: createdAt,
        provenance: {'periodKey': '2026-08-07'},
      );
      expect(
        goalPreviousBriefingFacts(
          legacy(DateTime(2026, 7, 20)),
          periodKey: '2026-08-08',
          specVersionId: 'spec-v1',
          specCreatedAt: specCreated,
        ),
        isNull,
        reason: 'written for the goal before its revision',
      );
      expect(
        goalPreviousBriefingFacts(
          legacy(DateTime(2026, 8, 7, 6)),
          periodKey: '2026-08-08',
          specVersionId: 'spec-v1',
          specCreatedAt: specCreated,
        ),
        {'periodKey': '2026-08-07', 'tldr': 'Held the line.'},
      );
    });

    test('a summary without steps still carries the summary', () {
      expect(
        goalPreviousBriefingFacts(
          makeTestReport(
            tldr: 'Held the line.',
            provenance: {
              'periodKey': '2026-08-07',
              'specVersionId': 'spec-v1',
            },
          ),
          periodKey: '2026-08-08',
          specVersionId: 'spec-v1',
          specCreatedAt: specCreated,
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
