import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/features/goals/logic/goal_today_briefing.dart';
import 'package:lotti/features/goals/workflow/goal_agent_contract.dart';

import '../../agents/test_data/entity_factories.dart';

void main() {
  AgentReportEntity report({
    String? oneLiner,
    String? tldr,
    List<Object?>? steps,
    String specVersionId = 'spec-v1',
    DateTime? deletedAt,
  }) {
    final base = makeTestReport(
      oneLiner: oneLiner,
      tldr: tldr,
      provenance: {
        'specVersionId': specVersionId,
        GoalReportProvenanceKeys.sections: {
          GoalReportSectionKeys.nextActions: ?steps,
        },
      },
    );
    return deletedAt == null ? base : base.copyWith(deletedAt: deletedAt);
  }

  GoalTodayBriefingSource goal(
    String id, {
    GoalTrackStatus? status = GoalTrackStatus.onTrack,
    AgentReportEntity? standing,
  }) => (
    agentId: id,
    title: 'Goal $id',
    status: status,
    specVersionId: 'spec-v1',
    report: standing,
  );

  group('goalReportNextSteps', () {
    test('reads the stored steps in order, dropping blanks and non-text', () {
      expect(
        goalReportNextSteps(
          report(steps: [' Walk after lunch. ', '', 7, 'Log tonight.']),
        ),
        ['Walk after lunch.', 'Log tonight.'],
      );
    });

    test('a report without sections or steps has none', () {
      expect(goalReportNextSteps(makeTestReport()), isEmpty);
      expect(goalReportNextSteps(report()), isEmpty);
    });
  });

  group('goalTodayBriefingItems', () {
    test("quotes each goal's one-liner and its first next step", () {
      final items = goalTodayBriefingItems([
        goal(
          'walk',
          standing: report(
            oneLiner: 'Two walks this week.',
            tldr: 'Longer summary.',
            steps: ['Walk after lunch.', 'Log tonight.'],
          ),
        ),
      ]);

      expect(items, hasLength(1));
      expect(items.single.agentId, 'walk');
      expect(items.single.title, 'Goal walk');
      expect(items.single.read, 'Two walks this week.');
      expect(items.single.nextStep, 'Walk after lunch.');
    });

    test('falls back to the summary when the report has no one-liner', () {
      final items = goalTodayBriefingItems([
        goal('walk', standing: report(tldr: 'On pace.')),
      ]);
      expect(items.single.read, 'On pace.');
      expect(items.single.nextStep, isNull);
    });

    test('leaves out goals with nothing to say: no report, a deleted one, '
        'one for a superseded spec, or one that is empty', () {
      final items = goalTodayBriefingItems([
        goal('none'),
        goal(
          'deleted',
          standing: report(oneLiner: 'x', deletedAt: DateTime(2026)),
        ),
        goal(
          'old-spec',
          standing: report(oneLiner: 'x', specVersionId: 'spec-v0'),
        ),
        goal('empty', standing: report()),
        goal('kept', standing: report(oneLiner: 'Kept.')),
      ]);

      expect([for (final item in items) item.agentId], ['kept']);
    });

    test('the goals that need attention come first; equals keep their '
        'order', () {
      AgentReportEntity said(String text) => report(oneLiner: text);
      final items = goalTodayBriefingItems([
        goal('fine', standing: said('a')),
        goal('fine-too', standing: said('b')),
        goal('unknown', status: null, standing: said('c')),
        goal('behind', status: GoalTrackStatus.offTrack, standing: said('d')),
        goal('close', status: GoalTrackStatus.atRisk, standing: said('e')),
        goal(
          'blind',
          status: GoalTrackStatus.insufficientData,
          standing: said('f'),
        ),
        goal(
          'turning',
          status: GoalTrackStatus.recovering,
          standing: said('g'),
        ),
        goal('done', status: GoalTrackStatus.achieved, standing: said('h')),
      ]);

      expect(
        [for (final item in items) item.agentId],
        [
          'behind',
          'close',
          'blind',
          'turning',
          'fine',
          'fine-too',
          'done',
          'unknown',
        ],
      );
    });
  });
}
