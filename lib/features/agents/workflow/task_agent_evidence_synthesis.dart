/// Shared prompt and tool-description adjustments for the validated
/// evidence-first task-agent configuration.
abstract final class TaskAgentEvidenceSynthesis {
  /// Compact Markdown report contract used in place of Lotti's built-in
  /// decorative report template. Explicitly customized template directives
  /// remain authoritative.
  static const reportDirective = '''
## Final report

When no report exists yet or the report materially changed, call
`update_report` exactly once as the final action. Otherwise finish with a brief
plain-text note and do not republish unchanged content. Never describe tool
calls in the report.

### `oneLiner`

Write a specific current-state tagline of at most 12 words. Do not use an
emoji, label, or sentence about what the agent did.

### `tldr`

In one or two concise sentences, state the current outcome and the most
important next action, deadline, or blocker. Do not repeat the one-liner and do
not use emojis.

### `content`

Write free-form Markdown in the task's `languageCode`. Choose the structure that
best fits the facts; headings are optional. Do not add a title because the task
title is already visible.

Lead with the current real-world situation, decision, deadline, or risk, then
surface the few actions that matter next. Include an outcome only when the
source records that outcome. Mention a blocker only when an active constraint
exists. Include links only for real external URLs, with descriptive link text.

Never create a section merely because a template named it. A pending-only task
may be a short context sentence followed by an action list. Omit empty sections,
boilerplate, checklist or metadata operations, and agent activity. Use
human-readable labels instead of internal IDs. Every claim must be
evidence-backed and describe the current active task state.
''';

  /// Tighter content guidance retained for Mistral's compact active path.
  static const mistralReportDirective = '''
## Final report

When no report exists yet or the report materially changed, call
`update_report` exactly once as the final action. Otherwise finish with a brief
plain-text note and do not republish unchanged content. Never describe tool
calls in the report.

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
- `## Next actions`: the few concrete pending actions that matter now.
- `## Blockers`: only active blockers or delivery risks.
- `## Links`: only real external URLs with descriptive link text.

Omit empty sections. Use human-readable labels instead of internal IDs. Every
claim must describe current active task state. If the task has a current due
date or deadline, include it and state what it is for.
''';

  /// Selects report guidance without changing custom template directives.
  static String reportDirectiveForModel(String? modelId) {
    final normalizedModelId = modelId?.toLowerCase() ?? '';
    return normalizedModelId.contains('mistral')
        ? mistralReportDirective
        : reportDirective;
  }

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
A previous report is a projection, not proof; discard its stale claims when
newer evidence contradicts them.

Run this preflight in order before submitting the report:
1. Mutation coverage: match every explicit requested task change to a successful
   mutation tool call. Report prose is not a substitute for the tool call.
2. Execution-anchor coverage: preserve every material current owner or team,
   latest deadline or date and its purpose, estimate or quantity, blocker or
   gate, dependency, adopted commitment, and remaining action.
3. Scope exclusion: remove every concept that appears only as rejected,
   deferred, speculative, or outside the active task. Never name such a concept
   merely to say that it was omitted.
4. State grounding: use pending-state language unless the source explicitly
   records real-world progress. A user checkmark alone proves no outcome.
5. Process deletion: remove analysis, transcription, checklist or metadata
   changes, tool use, readiness or waiting filler, internal JSON IDs, and empty
   sections.

Write every report field idiomatically in `languageCode`. These rules constrain
evidence, not Markdown structure or voice.
''';

  /// Full prompt profile validated for Mistral's compact active path.
  static const mistralSystemDirective = '''


## Evidence-First Synthesis Protocol

Follow this order:
1. Read the current fields and newest explicit instructions. A previous report
   is a stale projection when newer evidence contradicts it; it is not proof.
2. For every explicit request to add, update, check, set, or otherwise mutate
   the task, call the matching mutation tool. Do this before `update_report`.
   Report text never substitutes for a requested mutation.
3. After the tool results, write the report from current active evidence only.

Keep these facts when present: explicitly recorded real-world outcomes,
remaining actions, active blockers or gates, owners or teams, the latest date
and what it is for, estimates or quantities, dependencies, adopted commitments,
and useful external links. Preserve material qualifiers in checklist titles as
well as the report.

Omit rejected, deferred, speculative, and out-of-scope concepts completely. Do
not name them to explain that they were omitted. Also omit source JSON IDs,
agent or tool operations, unsupported progress, and empty sections.

A checked item proves only that the user marked it complete. Without separate
explicit outcome evidence, use neutral wording such as "marked complete" and
never claim implemented, applied, deployed, verified, validated, or resolved.
When later evidence says the issue returned, say that the issue or events
recurred; never say that the fix recurred, reverted, or failed.

Examples of the boundary:

- "Maybe revisit catering later; now ask Noor for venue access" produces a
  report about Noor and venue access. It says nothing about catering.
- A checked "Patch sync" item followed by "the issue returned; investigate"
  produces a report about the recurrence and investigation risk, not a claim
  that the patch was deployed or verified.
- "Turn the audit and rollout steps into checklist items" requires the
  checklist mutation tool before the final report.

Write every field idiomatically in `languageCode`. The examples illustrate
evidence selection, not required wording or report structure.
''';

  /// Qwen-specific guard against explanatory scope leakage.
  static const qwenSystemDirective = '''


## Scope Erasure

Never create a Scope, Exclusions, Note, or "not doing" section. A concept that
is only rejected, deferred, speculative, future, or outside the active task
must leave zero visible trace in `oneLiner`, `tldr`, and `content`. Do not name
it to prove that you filtered it.
''';

  /// Returns the common contract plus the empirically matched family profile.
  static String systemDirectiveForModel(String? modelId) {
    final normalizedModelId = modelId?.toLowerCase() ?? '';
    if (normalizedModelId.contains('mistral')) {
      return mistralSystemDirective;
    }
    if (normalizedModelId.contains('qwen')) {
      return '$systemDirective$qwenSystemDirective';
    }
    return systemDirective;
  }

  /// Whether the opt-in should use the compact task-agent scaffold.
  static bool usesCompactScaffold(String? modelId) {
    final normalizedModelId = modelId?.toLowerCase() ?? '';
    return normalizedModelId.contains('mistral') ||
        normalizedModelId.contains('qwen');
  }

  /// Scope contract added directly to the `update_report` tool description.
  static const updateReportDescriptionSuffix = '''

Call this only after every explicit requested mutation has a matching successful
tool call. Use current active evidence rather than stale report claims, and omit
out-of-scope concepts completely.''';

  /// Builds the evidence-first `update_report` description.
  static String updateReportDescription(String baseDescription) =>
      '$baseDescription$updateReportDescriptionSuffix';

  /// Aligns report-field descriptions with the evidence-first contract while
  /// preserving the original JSON schema shape and free-form Markdown value.
  static Map<String, dynamic> updateReportParameters(
    Map<String, dynamic> baseParameters,
  ) {
    final properties = Map<String, dynamic>.from(
      baseParameters['properties']! as Map<String, dynamic>,
    );

    properties['oneLiner'] = {
      ...properties['oneLiner']! as Map<String, dynamic>,
      'description':
          'A plain-text current-state tagline of at most 12 words. Name a '
          'concrete real-world outcome, next action, deadline, or risk. Never '
          'say that the task was configured, items were created or identified, '
          'or work is ready or awaiting execution. Do not mention internal IDs '
          'or out-of-scope work.',
    };
    properties['tldr'] = {
      ...properties['tldr']! as Map<String, dynamic>,
      'description':
          'One or two evidence-backed sentences describing the current task '
          'state and its most important next action, deadline, or blocker. '
          'Checklist and metadata changes are not real-world progress. A '
          'checked item means only user-marked complete unless separate '
          'evidence records the outcome. Never repeat excluded work.',
    };
    properties['content'] = {
      ...properties['content']! as Map<String, dynamic>,
      'description':
          'A free-form Markdown current-state report in the task language. '
          'Include only evidence-backed outcomes, active constraints, and '
          'remaining actions. If no real-world progress is recorded, omit '
          'Progress or Achieved entirely. Omit Blockers or Links when empty. '
          'Never present analysis, checklist or metadata changes, or tool use '
          'as progress. Omit internal IDs and every rejected, deferred, '
          'speculative, or out-of-scope concept, even to say it was omitted.',
    };

    return {...baseParameters, 'properties': properties};
  }
}
