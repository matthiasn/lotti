import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/agents/workflow/day_agent_workflow.dart';

void main() {
  test('omission rules forbid placeholders and require visible evidence', () {
    expect(
      dayAgentOmissionRules,
      contains(
        'Never represent omitted or unscheduled work as a zero-duration',
      ),
    );
    expect(
      dayAgentOmissionRules,
      contains('Every block must have `end` later than `start`'),
    );
    expect(
      dayAgentOmissionRules,
      contains('name the omitted work in an existing block `reason`'),
    );
    expect(
      dayAgentOmissionRules,
      contains('status `attentionNeeded` and reason\n  `overCommitted`'),
    );
    expect(
      dayAgentOmissionRules,
      contains('name the omitted work in its `note`'),
    );
    expect(
      dayAgentOmissionRules,
      contains('escalation is required'),
    );
    expect(
      dayAgentOmissionRules,
      contains('`directiveUnsatisfiable` for a binding directive'),
    );
  });

  test('worked examples preserve every instruction in a dense capture', () {
    final normalized = dayAgentPlanningExamples.replaceAll(RegExp(r'\s+'), ' ');

    expect(
      normalized,
      contains('collapse or discard any clause'),
    );
    expect(normalized, contains('Finish the migration first'));
    expect(normalized, contains('walk after lunch'));
    expect(normalized, contains('dentist is fixed at 16:30'));
    expect(normalized, contains('invoice before 15:00'));
    expect(normalized, contains('leave a 15-minute break'));
    expect(normalized, contains('five separate items'));
  });

  test(
    'worked examples account explicitly for overcommitted selected work',
    () {
      expect(dayAgentPlanningExamples, contains('180 minutes remain'));
      expect(dayAgentPlanningExamples, contains('240 minutes'));
      expect(dayAgentPlanningExamples, contains('overCommitted'));
      expect(dayAgentPlanningExamples, contains('name the two omitted items'));
      expect(
        dayAgentPlanningExamples,
        contains('Never make an instruction disappear'),
      );
    },
  );

  test('successful parse and draft tools are explicitly terminal', () {
    final captureRule = dayAgentCaptureTerminalRule.replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    final draftRule = dayAgentDraftTerminalRule.replaceAll(
      RegExp(r'\s+'),
      ' ',
    );

    expect(
      captureRule,
      contains('`parse_capture_to_items` MUST be the final tool call'),
    );
    expect(
      captureRule,
      contains(
        'A successful parse completes the wake without a separate summary '
        'turn',
      ),
    );
    expect(
      draftRule,
      contains(
        'A successful draft completes the wake without a separate summary '
        'turn',
      ),
    );
  });
}
