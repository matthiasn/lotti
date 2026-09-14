import 'package:lotti/features/agents/tools/agent_tool_registry.dart';

/// Publication requirements shared by task-agent prompts and execution.
abstract final class TaskAgentReportPolicy {
  /// The same publication gate is rendered beside tools and in both scaffolds.
  static const publicationRule =
      'When no report exists yet or a material task change makes the existing '
      'report stale, call `update_report` exactly once as the final action. '
      'Otherwise finish with a brief plain-text note and do not republish '
      'unchanged content. Label or language housekeeping alone does not '
      'require a new report.';

  /// Existing-report context contains no prior report prose.
  static const existingReportContext = '''
## Report Publication State
A report already exists. Before publishing, identify a new or corrected task fact that changes the situation, outcome, next action, deadline, or blocker. A note confirming that things are still the same is not such a change. Different wording, another wake, or a housekeeping label/language proposal does not warrant a new report. Skip optional label/language tidying on a no-change wake; still honor explicit user requests. If no material fact changed, do not call `update_report`; finish with a brief plain-text note. If evidence does change the task or correct a stale claim, publish the updated report after any justified tool calls.

''';

  static const firstReportContext = '''
## First Wake — No prior report exists. Produce an initial report.

''';

  /// Routine initialization is deferred on a quiet wake; explicit intent wins.
  static const languageRule =
      'Write public report fields in the task language. Detect and set language '
      'only when it is currently absent and a report is required. On a no-change '
      'wake, skip routine language initialization. Honor an explicit language '
      'request.';

  /// Conditional additions extend a custom report's required section list.
  static const conditionalSectionRule =
      'First select the required headings from the active report directive, '
      'then test each conditional section against current evidence. A '
      'conditional addition extends the required heading list: "use exactly" '
      'for that list does not cancel a later conditional addition. For example, '
      'two required sections plus a source section when a URL exists means '
      'three sections when a URL is present. Include each exact heading. '
      'Evidence activating a section must appear under its requested heading; '
      'an inline link elsewhere does not replace a requested evidence section. '
      'Omit the entire conditional section when its condition is false. Never '
      'invent headings for a directive requesting none.';

  /// Presentation directives cannot invent a decision or a user dependency.
  static const decisionSectionRule =
      'A decision section requires an unresolved decision the user can make now. '
      'Identify source evidence of a specific missing input only the user can '
      'provide now. Do not invent missing criteria or ask the user to reconfirm '
      "criteria that are already stated. Someone else's approval, a future "
      'evaluation result, or a routine next step is not a current user decision. '
      'Report such dependencies with the pending work. For example: a '
      'supplier-owned review still pending means list that dependency under '
      'next actions and omit the optional decision heading; a comparison not '
      'yet run means run the comparison first.';

  static const changedEntitiesRule =
      'These are triggers to inspect, not proof of material progress. '
      'Read what changed before deciding whether to publish a report.';

  static const closingInstruction =
      'Analyze the current state, maintain any attention requests, and call '
      'tools if needed. $publicationRule Add observations if warranted.';

  /// Rendered by production and synthetic eval contexts from the same source.
  static String changedEntitiesContext({
    required Iterable<String> triggerTokens,
    required bool hasReport,
  }) {
    final sorted = triggerTokens.toList()..sort();
    if (sorted.isEmpty) return '';
    return '## Changed Since Last Wake\n'
        'The following entity IDs changed: ${sorted.join(", ")}\n'
        '${hasReport ? '$changedEntitiesRule\n' : ''}\n';
  }

  /// Housekeeping alone does not stale an existing task report. The model may
  /// still publish when independent evidence changes the task's material state.
  static bool requiresReport({
    required bool hasExistingReport,
    required Iterable<String> successfulToolNames,
  }) =>
      !hasExistingReport ||
      successfulToolNames.any(
        (name) => !const {
          TaskAgentToolNames.assignTaskLabel,
          TaskAgentToolNames.assignTaskLabels,
          TaskAgentToolNames.setTaskLanguage,
        }.contains(name),
      );
}
