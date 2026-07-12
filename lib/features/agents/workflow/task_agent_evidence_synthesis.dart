/// Shared prompt and tool-description adjustments for the validated
/// evidence-first task-agent configuration.
abstract final class TaskAgentEvidenceSynthesis {
  /// Compact Markdown report contract used in place of Lotti's built-in
  /// decorative report template. Explicitly customized template directives
  /// remain authoritative.
  static const reportDirective = '''
## Final report

Call `update_report` exactly once at the end of the wake. Do not finish with a
plain-text answer and do not describe your tool calls.

### `oneLiner`

Write a specific current-state tagline of at most 12 words. Do not use an
emoji, label, or sentence about what the agent did.

### `tldr`

In one or two concise sentences, state the current outcome and the most
important next action, deadline, or blocker. Do not repeat the one-liner and do
not use emojis.

### `content`

Write a compact current-state report in the task's `languageCode`. Do not add a
title because the task title is already visible. Include only sections that
contain useful, evidence-backed information:

- `## Progress`: meaningful completed outcomes, not analysis, transcription,
  checklist creation, metadata changes, or other agent activity.
- `## Next actions`: the few concrete pending actions that matter now. Do not
  reproduce the entire checklist when a shorter synthesis is clearer.
- `## Blockers`: only active blockers or delivery risks.
- `## Links`: only real external URLs from the task context, using descriptive
  Markdown link text.

Omit empty sections. Use human-readable labels instead of internal IDs. Every
claim must be evidence-backed and describe the current active task state.
Preserve user-completed work and user-set task fields.
''';

  /// Evidence-first execution and public-report quality gate.
  static const systemDirective = '''


## Evidence-First Synthesis Protocol

Before calling tools, build the resulting task state from explicit current
instructions and confirmed facts. Mutate a task field or checklist item only
when the evidence explicitly authorizes that change. A status description is
not authorization to change status. Preserve stated dependencies and action
order instead of reordering work for narrative flow.

When creating checklist items, keep material qualifiers in the persisted item
title, including owners, deadlines, quantities, dependencies, and scope. Do not
move a qualifier only into the report.

A checked item proves only that the user marked it complete. Do not infer that
it was deployed, validated, or root-cause-resolved unless the evidence says so.

Before calling `update_report`, build a public fact set containing only current
outcomes, remaining actions, active blockers, adopted commitments, owners,
deadlines, dependencies, and useful links. Compose `oneLiner`, `tldr`, and
`content` exclusively from this set. Source material that does not affect an
active action must not enter the set.

Then verify the complete public report:
- Preserve every material current owner, blocker, deadline, adopted commitment,
  dependency, and remaining action before compressing the report.
- Describe the real-world task state. Do not present analysis, transcription,
  checklist creation, metadata updates, or tool use as progress.
- Treat every source JSON `id` value as a private tool handle. Use IDs in tool
  arguments only; never copy them into report prose, bullets, or link text. Use
  the human-readable title instead.
- Use idiomatic language matching `languageCode` throughout, including headings.
  Heading names are semantic examples, not fixed English labels: for German,
  write `## Nächste Schritte`, not `## Next actions`.
- Omit empty sections completely. Never emit placeholders such as `None`, `N/A`,
  "no learnings", "no links", or "no work completed". Metadata configuration
  is not task progress; omit `Progress` when no real-world outcome exists.
''';

  /// Scope contract added directly to the `update_report` tool description.
  static const updateReportDescriptionSuffix = '''

Report only current committed work and active execution constraints. Material
outside active scope must not appear in any report field or section, including a
statement that it was excluded. Preserve prohibitions that actively block or
constrain current work.''';

  /// Builds the evidence-first `update_report` description.
  static String updateReportDescription(String baseDescription) =>
      '$baseDescription$updateReportDescriptionSuffix';
}
