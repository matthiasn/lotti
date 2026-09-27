# Architecture Decision Records (ADR)

This folder stores architecture decisions that need durable rationale beyond
feature README snapshots.

## Scope

- Record decisions that affect module boundaries, lifecycle behavior, storage
  contracts, and cross-feature integration.
- Keep feature READMEs focused on the current implementation.
- Use ADRs for "why this shape exists" and migration constraints.

## File Naming

- `NNNN-short-title.md` (for example: `0001-agent-capabilities-runtime-model.md`)
- `NNNN` is a zero-padded, increasing sequence.

## ADR Template

Each ADR should contain:

1. `Status` (`Proposed`, `Accepted`, `Superseded`, `Deprecated`)
2. `Date`
3. `Context`
4. `Decision`
5. `Consequences`
6. `Related` (optional links to PRs/issues/docs)

## Index

Every ADR is a file in this folder, and the zero-padded numbers keep
`ls docs/adr` in order: that listing is the complete index. Do not add a line
here for a new ADR. A list every pull request appends to made concurrent
pull requests conflict over lines they do not share (the same reason release
notes go in `changelog.d/`). The clusters below group ADRs that belong
together; add to them only when a decision joins one.

### Task graph decision cluster

| ADR | Status | Decision ownership |
| --- | --- | --- |
| [0042: Typed Task Relationship Links](./0042-typed-task-relationship-links.md) | Accepted | `EntryLink` union variants (blocks, followsUp, duplicates, fixes, supersedes), one stored edge with rendered inverses, derived one-hop readiness, cycle tolerance, suggestion-only lifecycle coupling. |
| [0043: Dependency-Aware Planning](./0043-dependency-aware-planning.md) | Accepted | Ready frontier consumed by planning: corpus annotation (never exclusion), batch dependency resolver, drafting/digest prompt rules, task-detail visibility, explicit non-goals. |
| [0106: The Task Link Graph Across Devices](./0106-the-task-link-graph-across-devices.md) | Accepted | Cycles kept and reported the same on every device, never broken; the cycle check inside the write's transaction and uncapped; a project move or unfile retires every live project link of the task. |

### Relationship management decision cluster

| ADR | Status | Decision ownership |
| --- | --- | --- |
| [0037: Relationship Data Stays On-Device](./0037-relationship-on-device-storage-and-privacy.md) | Accepted | Local-only storage, opt-in E2E sync, zero external retention, explicit cloud-AI consent, deletion cascade, GDPR framing. |
| [0038: Relationship Domain Model](./0038-relationship-domain-model.md) | Accepted | `relationship`/`checkIn` journal subtypes, embedded person identity, status union, `RelationshipLink` task/timeline linking, no schema change. |
| [0039: Relationship Check-In Reminders](./0039-relationship-check-in-reminders.md) | Accepted, two decisions amended at implementation | Importance-gated cadence rule (a Phase A wake fact), reminders as a projection of that verdict rather than a second producer, per-episode row identity, startup reconcile, platform limits — and the Android notification stack it had to fix. |
| [0040: Relationship Executive Briefing](./0040-relationship-executive-briefing.md) | Accepted, amended by 0059 | Relationship agent + report contract, health band, strict context boundary, privacy-weighted model routing, honesty rules; runtime binding and template assumption amended. |
| [0041: Relationship Contact Linking](./0041-relationship-contact-linking.md) | Accepted | Selective per-relationship contact linking (no bulk import), channel snapshots, call/message actions from the briefing, post-interaction check-in prompt. |
| [0059: Relationship Agents on the Shared Runtime and the Kind-Agnostic Nudge Substrate](./0059-relationship-agent-runtime-and-nudge-generalization.md) | Accepted | Registered runtime kind on two-tier wakes (no template), per-episode lease-elected escalations with baseline tokens, banner dock as the attention channel (OS reminders deferred), sibling `relationshipNudge` variant with mixed-fleet-safe rollout, per-kind dock visibility. |

### Learning verification decision cluster

| ADR | Status | Decision ownership |
| --- | --- | --- |
| [0033: Learning Verification Checkpoint Policy](./0033-learning-verification-checkpoint-policy.md) | Proposed | When quizzes start: manual-first entry from any task, deterministic suggestion triggers/guards/caps, no gating, no spaced-repetition scheduler. |
| [0034: Hybrid Understanding Evaluation](./0034-hybrid-understanding-evaluation.md) | Proposed | Frozen evidence snapshots, tailored quiz generation, deterministic validation, conversational LLM grading with bounded probes, injection resistance. |
| [0035: Learning Verification Session Persistence](./0035-learning-verification-session-persistence.md) | Proposed | Quiz events/artifacts/links on the existing agent log, identity and sync convergence, device-local boundaries, plain deletion and export. |
| [0036: Learning Understanding Rating](./0036-learning-understanding-rating.md) | Proposed | Per-item verdicts, session scores/labels, feedback-first presentation, honesty rules, storage separate from journal ratings. |

### Goal-driven agents decision cluster

| ADR | Status | Decision ownership |
| --- | --- | --- |
| [0053: Goal-Driven Agents — Per-Goal Durable Producers](./0053-goal-driven-agents-per-goal-producers.md) | Proposed | One durable agent per goal (amends 0023's granularity), versioned goal spec (version + head), purpose-built `GoalCriterion` tree, deterministic `goalProgress` register, proposal-only revision, StandingAgreement's first writer, no template in v1. |
| [0054: Deterministic-First Two-Tier Wakes](./0054-deterministic-first-two-tier-wakes.md) | Proposed | €0 deterministic Phase A on every device, lease-elected LLM Phase B, sync-origin Phase-A dispatcher, per-goal subscriptions, recurrence by re-arm, fact-gated tools from day one, cost monitored not capped. |
| [0055: The Banner-Nudge Attention Channel](./0055-banner-nudge-attention-channel.md) | Proposed | Banner-only in-app ads (never push), `goalNudge` lifecycle with dismissal-as-data, staleness contract, respect mechanics (cool-down, dedupe), quiet-by-default surfaces, on-device copy compositing, ads permanent in chat history. |
| [0056: The Need-to-Know Visual Brief Boundary](./0056-need-to-know-visual-brief-boundary.md) | Proposed | Non-ZDR image providers receive only a self-contained typed brief; the parameter type is the enforcement; on-device text compositing; provenance-gated reference images; leakage evals; one-retry verification. |
| [0057: Decade-Scale Agent Memory](./0057-decade-scale-agent-memory.md) | Proposed | Generalized search + keyed knowledge read path, bounded observation reads, epoch summaries via `summaryDepth` (amends 0017), distill-then-prune retention, bounded prune instead of the 20k skip, cold-prefill context budgets. |
| [0058: Procedural Text Banners — No Generative Imagery](./0058-procedural-text-banners-no-generative-imagery.md) | Proposed | Goal ads are model-authored copy over code-owned animation/accent presets; no image provider in the channel (supersedes 0055 D8; 0056 dormant); per-agent energy (Wh/goal-month) is a first-class reported figure. |
