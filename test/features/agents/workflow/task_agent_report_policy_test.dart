import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/workflow/task_agent_report_policy.dart';

void main() {
  test('first publication is required even without material mutations', () {
    for (final tools in [
      <String>[],
      [TaskAgentToolNames.setTaskLanguage],
    ]) {
      expect(
        TaskAgentReportPolicy.requiresReport(
          hasExistingReport: false,
          successfulToolNames: tools,
        ),
        isTrue,
      );
    }
  });

  test(
    'housekeeping preserves an existing report but material work does not',
    () {
      const housekeeping = [
        TaskAgentToolNames.assignTaskLabel,
        TaskAgentToolNames.assignTaskLabels,
        TaskAgentToolNames.setTaskLanguage,
      ];
      expect(
        TaskAgentReportPolicy.requiresReport(
          hasExistingReport: true,
          successfulToolNames: housekeeping,
        ),
        isFalse,
      );
      for (final tool in [
        TaskAgentToolNames.addChecklistItem,
        TaskAgentToolNames.updateTaskDueDate,
        TaskAgentToolNames.updateTaskEstimate,
      ]) {
        expect(
          TaskAgentReportPolicy.requiresReport(
            hasExistingReport: true,
            successfulToolNames: [...housekeeping, tool],
          ),
          isTrue,
        );
      }
    },
  );

  test(
    'changed IDs are stable and only follow-up wakes need restraint guidance',
    () {
      final followUp = TaskAgentReportPolicy.changedEntitiesContext(
        triggerTokens: ['note-b', 'note-a'],
        hasReport: true,
      );
      expect(followUp, contains('note-a, note-b'));
      expect(followUp, contains(TaskAgentReportPolicy.changedEntitiesRule));
      expect(
        TaskAgentReportPolicy.changedEntitiesContext(
          triggerTokens: ['note-a'],
          hasReport: false,
        ),
        isNot(contains(TaskAgentReportPolicy.changedEntitiesRule)),
      );
      expect(
        TaskAgentReportPolicy.changedEntitiesContext(
          triggerTokens: [],
          hasReport: true,
        ),
        isEmpty,
      );
    },
  );

  group('withoutAbsentMetadataNotes', () {
    // Verbatim sentences from failed task-workflow gym samples, 2026-09-15..17.
    const bareNotes = [
      'No estimate or due date is set for this work.',
      'No estimate or due date is set yet.',
      'No estimate or due date is set.',
      'No deadline or estimate is set.',
      'No due date or time estimate has been set yet.',
      'No deadline, priority, or estimate is set.',
      'There is no due date set.',
    ];

    test('a report keeps its prose and loses the bare absence note', () {
      for (final note in bareNotes) {
        expect(
          TaskAgentReportPolicy.withoutAbsentMetadataNotes(
            'Fix the seeding so empty profiles are no longer offered. $note',
          ),
          'Fix the seeding so empty profiles are no longer offered.',
          reason: note,
        );
        expect(
          TaskAgentReportPolicy.withoutAbsentMetadataNotes(
            '## Next actions\n- Fix the seeding.\n\n$note\n',
          ),
          '## Next actions\n- Fix the seeding.',
          reason: note,
        );
      }
    });

    test('a trailing absence clause is dropped, the sentence is kept', () {
      // Verbatim glm-5.3 gym report: the sentence says something, its tail
      // does not.
      expect(
        TaskAgentReportPolicy.withoutAbsentMetadataNotes(
          'No work has been completed yet — the task is open with no due date '
          'or estimate set.',
        ),
        'No work has been completed yet — the task is open.',
      );
      expect(
        TaskAgentReportPolicy.withoutAbsentMetadataNotes(
          'The migration is ready to start, and no deadline is set yet.',
        ),
        'The migration is ready to start.',
      );
    });

    test('a note joined to real content loses only the note', () {
      // Verbatim glm-5.3-flash gym reports that the sentence rule missed.
      const joined = {
        'No due date or time estimate has been set, and no code changes have '
                'been made yet.':
            'No code changes have been made yet.',
        'No estimate or due date is set, and no blockers are recorded. Work '
                'has not started yet.':
            'No blockers are recorded. Work has not started yet.',
        'No estimate, due date, or scheduling request has been given yet. '
                'Work begins with the implementation step.':
            'Work begins with the implementation step.',
        'No estimate, due date, or planner time has been set yet; these can '
                'be added once implementation starts.':
            'These can be added once implementation starts.',
        'No deadline or estimate is set, and no review artifacts exist yet.':
            'No review artifacts exist yet.',
        '- Task priority is P2, status OPEN, no due date or estimate set':
            '- Task priority is P2, status OPEN.',
        // Verbatim glm-5.3-flash bullet: the marker stays with what survives.
        '- No estimate or due date has been set; the work is sequenced as a '
                'single review-and-release pipeline.':
            '- The work is sequenced as a single review-and-release pipeline.',
      };
      joined.forEach((report, expected) {
        expect(
          TaskAgentReportPolicy.withoutAbsentMetadataNotes(report),
          expected,
          reason: report,
        );
      });
    });

    test('a sentence that carries anything else survives untouched', () {
      const kept = [
        'No deadline is set yet — the March cutoff will drive the timing.',
        'The estimate is two hours and the due date is 2026-10-01.',
        'No blockers remain.',
        'The task can proceed with no due date set, and the owner will confirm it tomorrow.',
        'No deadline is set yet, though the March cutoff will drive the timing.',
        'There is no estimated risk to the release.',
      ];
      for (final line in kept) {
        expect(
          TaskAgentReportPolicy.withoutAbsentMetadataNotes(line),
          line,
          reason: line,
        );
      }
    });

    test('a draft that is only noise is published as the model wrote it', () {
      // Emptying a required report would skip publication and leave the
      // previous report looking fresh, so the draft stands.
      for (final draft in [
        'No estimate or due date is set.',
        '## Decision needed\nNone right now.',
      ]) {
        expect(
          TaskAgentReportPolicy.withoutPublicationNoise(draft),
          draft,
          reason: draft,
        );
      }
      expect(
        TaskAgentReportPolicy.withoutPublicationNoise(
          'Fix the seeding. No estimate or due date is set.',
        ),
        'Fix the seeding.',
      );
    });

    test('a report that is only the note becomes empty', () {
      expect(
        TaskAgentReportPolicy.withoutAbsentMetadataNotes(
          'No estimate or due date is set.',
        ),
        isEmpty,
      );
      expect(TaskAgentReportPolicy.withoutAbsentMetadataNotes(''), isEmpty);
    });
  });

  group('withoutEmptySections', () {
    test('a section that only says none is dropped', () {
      // Verbatim glm-5.3 and glm-5.3-flash decision memos.
      const report =
          '## Recommendation\n'
          'Deployment stays on hold; Marta owns the Legal approval.\n\n'
          '## Next moves\n'
          '- Marta approves the retention wording.\n\n'
          '## Decision needed\n'
          'None from you right now — the gate sits with Marta and Legal.';
      expect(
        TaskAgentReportPolicy.withoutEmptySections(report),
        '## Recommendation\n'
        'Deployment stays on hold; Marta owns the Legal approval.\n\n'
        '## Next moves\n'
        '- Marta approves the retention wording.',
      );
      for (final body in [
        "None — the only open input is Marta's approval, tracked above.",
        'Nothing outstanding.',
        'No decision is needed.',
        'N/A',
      ]) {
        expect(
          TaskAgentReportPolicy.withoutEmptySections(
            '## Keep\nReal.\n\n## Gone\n$body',
          ),
          '## Keep\nReal.',
          reason: body,
        );
      }
    });

    test('a heading with no body at all is dropped', () {
      expect(
        TaskAgentReportPolicy.withoutEmptySections(
          '## Progress\n\n## Next\nShip it.',
        ),
        '## Next\nShip it.',
      );
    });

    test('a section that carries content is kept whole', () {
      const kept = [
        '## Decision needed\nPick the candidate model before the eval runs.',
        '## Decision needed\nNone of the three candidates is ready.\nPick one anyway.',
        '## Blockers\nNone of the sensors report, so the swap is blocked.',
        '## Next\n- None of this is done yet.\n- Start with the seeding fix.',
      ];
      for (final report in kept) {
        expect(
          TaskAgentReportPolicy.withoutEmptySections(report),
          report,
          reason: report,
        );
      }
    });
  });
}
