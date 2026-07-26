---
type: Feature Module
title: Templates, souls and evolution
description: What an agent does (template skills) versus who it is (soul personality), and the ritual loop that evolves both from user feedback.
resource: ../../../lib/features/agents/workflow/template_evolution_workflow.dart
tags: [agents, templates, souls, evolution, improver]
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-25T23:30:00Z }
stale_after: 2026-10-26
sources:
  - id: seeding
    resource: ../../../lib/features/agents/service/agent_template_seeding.dart
    title: Seeded default templates
    last_modified: 2026-07-25
  - id: evolution
    resource: ../../../lib/features/agents/workflow/template_evolution_workflow.dart
    title: TemplateEvolutionWorkflow
    last_modified: 2026-07-25
  - id: improver
    resource: ../../../lib/features/agents/workflow/improver_agent_workflow.dart
    title: ImproverAgentWorkflow
    last_modified: 2026-07-25
  - id: soul-ops
    resource: ../../../lib/features/agents/service/soul_template_ops.dart
    title: Soul document service operations
    last_modified: 2026-07-25
  - id: adr-0012
    resource: ../../../docs/adr/0012-recursive-self-improvement-depth-policy.md
    title: ADR 0012 — Recursive self-improvement depth policy
    last_modified: 2026-07-24
---

# Two axes: skills and personality

The feature separates **what an agent does** from **who it is**:

| | Owns | Versioned as |
|---|------|--------------|
| **Template** | Operational directives — skills | Template row + version rows + head pointer |
| **Soul** | `voiceDirective`, `toneBounds`, `coachingStyle`, `antiSycophancyPolicy` | Soul row + version rows + head pointer |

```mermaid
erDiagram
    SoulDocument ||--o{ SoulDocumentVersion : "has versions"
    SoulDocument ||--|| SoulDocumentHead : "active version pointer"
    AgentTemplate }o--|| SoulDocument : "SoulAssignmentLink"
    AgentTemplate ||--o{ AgentTemplateVersion : "has versions (skills only)"
```

**Key invariant: one active soul per template.** Multiple templates can share a
soul. Instances inherit their soul through their template assignment.

At wake time, `TaskAgentWorkflow` and `ProjectAgentWorkflow` resolve the active
soul and inject personality under `## Your Personality`, while skills go under
`## Your Operational Directives`. Templates without a soul assignment fall back
to the legacy combined `## Your Personality & Directives` format.

# Seeded defaults

`AgentTemplateService.seedDefaults()` seeds seven named templates:

| Template | Kind |
|----------|------|
| `Laura` | `taskAgent` |
| `Tom` | `taskAgent` |
| `Project Analyst` | `projectAgent` |
| `Scribe` | `eventAgent` |
| `Shepherd` | `dayAgent` (Daily OS) |
| `Template Improver` | improver |
| `Meta Improver` | improver |

`Scribe` is what makes event recaps usable out of the box: a category opts in by
pointing `Category.defaultEventTemplateId` at it (or at any other
`eventAgent`-kind template). Without a seeded event template the category picker
would have nothing to offer.

Six seeded souls form a personality palette — Laura, Tom, Max, Iris, Sage and
Kit — with three default assignments: Laura soul → Laura task template, Tom soul
→ Tom task template, Laura soul → Project Analyst. Max, Iris, Sage and Kit are
available for manual assignment.

`SoulDocumentService` manages the lifecycle: `createSoul()` (entity + initial
version + head), `createVersion()` (archive old, create new active),
`assignSoulToTemplate()`, `resolveActiveSoulForTemplate()` (link → head → version
chain), and `getTemplatesUsingSoul()` for reverse lookup.

# The evolution session

`TemplateEvolutionWorkflow` is the multi-turn session runtime, handling both
template evolution (skill changes) and soul evolution (personality changes):

1. Gather template context, metrics and soul context.
2. Create an `EvolutionSessionEntity`.
3. Start a conversation with `EvolutionStrategy`.
4. Record evolution notes, structured ritual recap state and proposal state.
5. Create a new template version **only after approval** (`propose_directives`).
6. Optionally create a new soul version (`propose_soul_directives`) — this
   affects **all** templates sharing the soul.
7. Persist an `EvolutionSessionRecapEntity` from the explicit
   `publish_ritual_recap` tool payload plus the approved-change rationale,
   ratings and transcript snapshot.

```mermaid
stateDiagram-v2
  [*] --> Active: startSession()
  Active --> Completed: approveProposal() + persist recap
  Active --> Abandoned: abandon / stale-session cleanup
  Completed --> [*]
  Abandoned --> [*]
```

**Only one active evolution session per template** at a time.

The UI splits into two surfaces: `EvolutionReviewPage` (a history-first ritual
home with a pending-session card, compact metrics and persisted history) and
`EvolutionChatPage` (the active negotiation loop). Session history cards prefer
the persisted recap `tldr`, falling back to `session.feedbackSummary` when it is
absent or empty.

`EvolutionMessageInput` reuses the chat recorder controller for batch voice
input. Successful transcripts populate the composer; failures render the
provider's diagnostic detail in an error toast and clear the consumed recorder
result so the same failure is not replayed on rebuild.

`ritualSummaryMetricsProvider` exposes only the retained signals: lifetime wake
count, wakes since the last completed ritual, token usage since the last
completed ritual, and 30-day wake activity buckets.

# Improver agents

An improver is a scheduled agent whose job is to open evolution sessions with
richer context.

```mermaid
flowchart TD
  Wake["Scheduled improver wake"] --> Feedback["FeedbackExtractionService.extract()"]
  Feedback --> Threshold{"At least 3 feedback items?"}
  Threshold -->|No| Reschedule["Update watermark and schedule next ritual"]
  Threshold -->|Yes| Context["RitualContextBuilder.buildRitualContext()"]
  Context --> Session["TemplateEvolutionWorkflow.startSession()"]
  Session --> Home["EvolutionReviewPage shows pending card and history"]
  Home --> Chat["EvolutionChatPage negotiation loop"]
  Chat --> Approval{"Proposal approved?"}
  Approval -->|Yes| Recap["Persist EvolutionSessionRecapEntity"]
  Approval -->|No, abandoned| Reschedule
  Recap --> Reschedule
```

`ImproverAgentWorkflow` loads `activeTemplateId`, extracts classified feedback
since the last watermark, **skips the ritual when fewer than 3 feedback items
exist**, builds ritual context from feedback, reports, observations, versions and
metrics, starts the session, then updates the feedback scan watermark and
schedules the next ritual.

Meta-improvers reuse the same workflow, distinguished only by
`recursionDepth > 0` (ADR 0012).

# Standalone soul evolution

Soul personality evolves two ways:

1. **During a template ritual** — the evolution agent can opportunistically
   propose soul changes via `propose_soul_directives` alongside skill changes.
2. **A standalone soul session** — a dedicated 1-on-1 focused exclusively on
   personality.

```mermaid
flowchart TD
  SoulDetail["Soul detail page"] --> Review["SoulEvolutionReviewPage"]
  Review --> Chat["SoulEvolutionChatPage"]
  Chat --> Start["startSoulSession(soulId)"]
  Start --> Feedback["FeedbackExtractionService.extractForSoul()"]
  Feedback --> T1["extract(template1)"]
  Feedback --> T2["extract(template2)"]
  T1 --> Merge["Merged feedback by template"]
  T2 --> Merge
  Merge --> Context["SoulEvolutionContextBuilder"]
  Context --> LLM["Conversation with personality evolution agent"]
  LLM --> Approve{"Soul proposal approved?"}
  Approve -->|Yes| Version["Create SoulDocumentVersionEntity"]
  Approve -->|No| Continue["Continue conversation or abandon"]
```

`startSoulSession(soulId)` aggregates feedback from **all templates sharing the
soul**, `SoulEvolutionContextBuilder` builds personality-focused context with
cross-template feedback grouped by source template, only
`propose_soul_directives` is available (no `propose_directives`), and
`completeSoulSession()` creates a new `SoulDocumentVersionEntity`.

Session entities reuse `EvolutionSessionEntity` with `agentId = soulId` and
`templateId = soulId`.
