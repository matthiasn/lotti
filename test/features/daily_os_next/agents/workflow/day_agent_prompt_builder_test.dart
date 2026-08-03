import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/agents/workflow/day_agent_workflow.dart';

import '../../integration/realistic_day_planning_scenarios.dart';

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
    final normalized = dayAgentCaptureExample.replaceAll(RegExp(r'\s+'), ' ');

    expect(
      normalized,
      contains('collapse or discard any clause'),
    );
    expect(normalized, contains('12:00-12:40 completely free'));
    expect(normalized, contains('candidate replies into one 25-minute block'));
    expect(normalized, contains('only if the vendor quote has arrived'));
    expect(normalized, contains('45 minutes for the quarterly risk review'));
    expect(normalized, contains('stop focused work at 17:15'));
    expect(normalized, contains('five separate items'));
    expect(normalized, contains('protected interval'));
    expect(normalized, contains('conditional dependency'));
  });

  test(
    'worked examples account explicitly for overcommitted selected work',
    () {
      expect(dayAgentDraftExample, contains('105 minutes remain'));
      expect(dayAgentDraftExample, contains('150 minutes'));
      expect(dayAgentDraftExample, contains('overCommitted'));
      expect(
        dayAgentDraftExample,
        contains('name the\n  45-minute repair call as omitted'),
      );
      expect(
        dayAgentDraftExample,
        contains('Never make an instruction disappear'),
      );
    },
  );

  test('worked examples are held out from the live evaluation fixtures', () {
    final normalizedExamples = '$dayAgentCaptureExample\n$dayAgentDraftExample'
        .toLowerCase();
    for (final scenario in realisticDayPlanningScenarios) {
      for (final task in scenario.tasks) {
        expect(
          normalizedExamples,
          isNot(contains(task.title.toLowerCase())),
          reason: 'Prompt example leaked live fixture task: ${task.title}',
        );
      }
    }
    for (final fixtureSignature in [
      'migration',
      'invoice',
      'client call',
      'walk after lunch',
      'dentist',
      'board deck',
      'interviews',
      'release notes',
      'support inbox',
      'afternoon walk',
      '180 minutes',
      'two omitted items',
    ]) {
      expect(
        normalizedExamples,
        isNot(contains(fixtureSignature)),
        reason:
            'Prompt example leaked live fixture signature: $fixtureSignature',
      );
    }
  });

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
      contains('`draft_day_plan` MUST be the final tool call'),
    );
    expect(
      draftRule,
      contains(
        'A successful draft completes the wake without a separate summary '
        'turn',
      ),
    );
  });

  test('a closed drafting window has one explicit artifact contract', () {
    final normalized = dayAgentDraftTerminalRule.replaceAll(
      RegExp(r'\s+'),
      ' ',
    );

    expect(normalized, contains('When `<planning_window>` is closed'));
    expect(normalized, contains('no baseline blocks'));
    expect(normalized, contains('`blocks: []`'));
    expect(normalized, contains('repeat every baseline block unchanged'));
    expect(normalized, contains('Never erase a non-empty baseline'));
  });
}
