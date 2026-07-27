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
}
