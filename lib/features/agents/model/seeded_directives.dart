/// Fresh directive content seeded into existing template versions when
/// the `generalDirective` and `reportDirective` fields are empty.
///
/// These are purpose-built for each template kind, not copies of the old
/// `directives` field.
library;

import 'package:lotti/features/agents/model/agent_enums.dart';

// ── Seed Directive Changelog ─────────────────────────────────────────────────

part 'seeded_directive_content.dart';

/// A dated record of a change to the seed directives.
///
/// The evolution context builder includes entries newer than the active
/// version's `createdAt` so the evolution agent can incorporate them.
/// Each entry is scoped to a [kind] so that task-agent-specific changes
/// are not surfaced during improver/meta-improver rituals.
class SeedDirectiveChange {
  const SeedDirectiveChange({
    required this.date,
    required this.kind,
    required this.description,
  });

  /// ISO date string, e.g. '2026-03-09'.
  final String date;

  /// The template kind this change applies to.
  final AgentTemplateKind kind;

  /// Human-readable description of what changed.
  final String description;

  /// The date parsed to midnight. The evolution context builder compares
  /// date-only to avoid missing same-day entries.
  DateTime get dateTime => DateTime.parse(date);
}

/// Chronological log of seed directive changes.
///
/// Add new entries at the bottom with the date the change was made.
const seedDirectiveChangelog = <SeedDirectiveChange>[
  SeedDirectiveChange(
    date: '2026-03-09',
    kind: AgentTemplateKind.taskAgent,
    description:
        'Report language: Write in the language specified by the '
        "task's `languageCode` field, not the content language. "
        'Respect user-set language choices.',
  ),
  SeedDirectiveChange(
    date: '2026-03-09',
    kind: AgentTemplateKind.taskAgent,
    description:
        'Internal task links: when provided task context includes a task ID '
        'and linking helps the user inspect proof of work, link the readable '
        'task title to `/tasks/<taskId>`. Never show bare IDs or hashes as '
        'link text, and never invent task IDs. Keep the Links section for '
        'real external URLs (GitHub, docs, etc.).',
  ),
  SeedDirectiveChange(
    date: '2026-03-28',
    kind: AgentTemplateKind.projectAgent,
    description:
        'Project report formatting: do not add a separate markdown headline '
        'or repeat the project title as a heading; the UI renders the title.',
  ),
  SeedDirectiveChange(
    date: '2026-03-31',
    kind: AgentTemplateKind.templateImprover,
    description:
        'Question style: ask blunt, concrete follow-up questions. Prefer '
        'yes/no, either/or, or pick-one prompts. Avoid abstract phrasing '
        'about what the user is "signaling".',
  ),
  SeedDirectiveChange(
    date: '2026-04-19',
    kind: AgentTemplateKind.taskAgent,
    description:
        'Report tool is non-negotiable: `update_report` MUST be the final '
        'tool call of every wake, even when nothing new needs saying '
        '(reuse prior `content`, refresh `oneLiner` / `tldr`). Weaker '
        'models stopping before the report leaves the UI empty — the '
        'wake now forces a retry with `tool_choice` if the tool was '
        'missed, and the directive is reinforced at the top of the '
        'prompt.',
  ),
  SeedDirectiveChange(
    date: '2026-05-25',
    kind: AgentTemplateKind.dayAgent,
    description:
        'Initial Daily OS day-agent directives: energy-aware planning, '
        'capacity discipline, propose-not-impose behavior, private '
        'observations, and self-scheduled wake timing.',
  ),
  SeedDirectiveChange(
    date: '2026-05-26',
    kind: AgentTemplateKind.dayAgent,
    description:
        'Draft blocks must set `taskId` when they map to a task under '
        '`drafting.decidedTasks`; the Daily OS Next agenda groups by '
        'taskId, so unlinked ai/manual placements collapse into a '
        '"Nothing to do today" empty state. Buffer and calendar blocks '
        'continue to omit `taskId`.',
  ),
  SeedDirectiveChange(
    date: '2026-05-26',
    kind: AgentTemplateKind.dayAgent,
    description:
        'Refine tools (`propose_plan_diff`, `accept_diff`, `revert_diff`) '
        'are now available. On `refine:<dayId>` wakes, emit a structured '
        'diff via `propose_plan_diff` referencing existing blockIds from '
        '`refine.baselinePlan.blocks`. Never call `accept_diff` or '
        '`revert_diff` autonomously — those are user verdicts.',
  ),
  SeedDirectiveChange(
    date: '2026-05-26',
    kind: AgentTemplateKind.dayAgent,
    description:
        'Commit tool (`commit_day`) is now available. Never call '
        "`commit_day` autonomously — committing is the user's decision. "
        'Once a plan is committed (`DayPlanStatus.committed`), do not '
        'call `draft_day_plan` or `propose_plan_diff` against it: the '
        'service rejects both. Further edits require a refine wake the '
        'user initiates.',
  ),
  SeedDirectiveChange(
    date: '2026-05-26',
    kind: AgentTemplateKind.dayAgent,
    description:
        'Uncommit tool (`uncommit_day`) is now available as the escape '
        'hatch from a committed plan. Never call `uncommit_day` '
        'autonomously — it is the user-initiated "edit committed plan" '
        'action and flips the plan back to draft so drafting/refine tools '
        'become callable again. inProgress/completed/dropped blocks are '
        'preserved as history.',
  ),
  SeedDirectiveChange(
    date: '2026-05-26',
    kind: AgentTemplateKind.dayAgent,
    description:
        'Drafting wakes (`drafting:<dayId>`) MUST end with `draft_day_plan`. '
        'Reconcile-only wakes (`capture_submitted:<captureId>` alone) skip '
        'the plan tool. The workflow now forces `tool_choice` when the model '
        'misses the final draft call.',
  ),
  SeedDirectiveChange(
    date: '2026-05-26',
    kind: AgentTemplateKind.dayAgent,
    description:
        'Wake payloads include `currentLocalTime`. When drafting today, '
        'new drafted ai/manual blocks must not start before that time; '
        'earlier in-progress, completed, or dropped baseline blocks are '
        'history and may be preserved.',
  ),
  SeedDirectiveChange(
    date: '2026-05-26',
    kind: AgentTemplateKind.dayAgent,
    description:
        '`create_task_from_phrase` now creates a real task and returns its '
        '`taskId`; use that id on the matching `draft_day_plan` block so '
        'Daily OS agenda rows open the backing task.',
  ),
  SeedDirectiveChange(
    date: '2026-06-09',
    kind: AgentTemplateKind.dayAgent,
    description:
        '`accept_diff`, `revert_diff`, `commit_day`, and `uncommit_day` were '
        'removed from the tool set: diff verdicts and commit state are the '
        "user's decisions, applied through the UI only (ADR 0006). Do not "
        'claim to have applied a diff or changed commit state.',
  ),
  SeedDirectiveChange(
    date: '2026-06-09',
    kind: AgentTemplateKind.dayAgent,
    description:
        '`propose_knowledge` no longer confirms `userStated` entries '
        "immediately: every proposal awaits the user's confirmation in the "
        'knowledge panel before becoming durable. `source` is provenance '
        'only. Do not claim something is durably memorized until confirmed.',
  ),
  SeedDirectiveChange(
    date: '2026-06-10',
    kind: AgentTemplateKind.dayAgent,
    description:
        'Week context: the prompt now carries `<recent_days>` (planned and '
        'recorded facts per day plus your own contemporaneous day notes) and '
        '`<week_ahead>` (upcoming plans and claim deadlines). Read '
        '`<recent_days>` before drafting and plan sustainably after heavy '
        'stretches. `write_day_summary` (today/yesterday only, ≤500 chars) '
        'is the SOLE channel for day retrospectives; `record_observations` '
        'is for forward-looking learnings only, never day recaps. On '
        'contradiction the deterministic facts line wins over your note.',
  ),
];

// ── Task Agent: General Directive ──────────────────────────────────────────
