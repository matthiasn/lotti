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

    test('a sentence that carries anything else survives untouched', () {
      const kept = [
        'No deadline is set yet — the March cutoff will drive the timing.',
        'No deadline or estimate is set, and no review artifacts exist yet.',
        '- Task priority is P2, status OPEN, no due date or estimate set',
        'The estimate is two hours and the due date is 2026-10-01.',
        'No blockers remain.',
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
}
