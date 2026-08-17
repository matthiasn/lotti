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

### Task graph decision cluster

| ADR | Status | Decision ownership |
| --- | --- | --- |
| [0042: Typed Task Relationship Links](./0042-typed-task-relationship-links.md) | Accepted | `EntryLink` union variants (blocks, followsUp, duplicates, fixes, supersedes), one stored edge with rendered inverses, derived one-hop readiness, cycle tolerance, suggestion-only lifecycle coupling. |
| [0043: Dependency-Aware Planning](./0043-dependency-aware-planning.md) | Accepted | Ready frontier consumed by planning: corpus annotation (never exclusion), batch dependency resolver, drafting/digest prompt rules, task-detail visibility, explicit non-goals. |

### Relationship management decision cluster

| ADR | Status | Decision ownership |
| --- | --- | --- |
| [0037: Relationship Data Stays On-Device](./0037-relationship-on-device-storage-and-privacy.md) | Proposed | Local-only storage, opt-in E2E sync, zero external retention, explicit cloud-AI consent, deletion cascade, GDPR framing. |
| [0038: Relationship Domain Model](./0038-relationship-domain-model.md) | Proposed | `relationship`/`checkIn` journal subtypes, embedded person identity, status union, `RelationshipLink` task/timeline linking, no schema change. |
| [0039: Relationship Check-In Reminders](./0039-relationship-check-in-reminders.md) | Accepted, two decisions amended at implementation | Importance-gated cadence rule (a Phase A wake fact), reminders as a projection of that verdict rather than a second producer, per-episode row identity, startup reconcile, platform limits — and the Android notification stack it had to fix. |
| [0040: Relationship Executive Briefing](./0040-relationship-executive-briefing.md) | Proposed, amended by 0059 | Relationship agent + report contract, health band, strict context boundary, privacy-weighted model routing, honesty rules; runtime binding and template assumption amended. |
| [0041: Relationship Contact Linking](./0041-relationship-contact-linking.md) | Proposed | Selective per-relationship contact linking (no bulk import), channel snapshots, call/message actions from the briefing, post-interaction check-in prompt. |
| [0059: Relationship Agents on the Shared Runtime and the Kind-Agnostic Nudge Substrate](./0059-relationship-agent-runtime-and-nudge-generalization.md) | Proposed | Registered runtime kind on two-tier wakes (no template), per-episode lease-elected escalations with baseline tokens, banner dock as the attention channel (OS reminders deferred), sibling `relationshipNudge` variant with mixed-fleet-safe rollout, per-kind dock visibility. |

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

### Chronological index

- [`0001-agent-capabilities-runtime-model.md`](./0001-agent-capabilities-runtime-model.md)
- [`0002-wake-scheduling-and-throttling-policy.md`](./0002-wake-scheduling-and-throttling-policy.md)
- [`0003-task-agent-linked-task-context-contract.md`](./0003-task-agent-linked-task-context-contract.md)
- [`0004-task-agent-tool-execution-policy.md`](./0004-task-agent-tool-execution-policy.md)
- [`0005-template-model-resolution-policy.md`](./0005-template-model-resolution-policy.md)
- [`0006-change-set-deferred-tool-confirmation.md`](./0006-change-set-deferred-tool-confirmation.md)
- [`0007-token-usage-wake-run-log-storage.md`](./0007-token-usage-wake-run-log-storage.md)
- [`0008-inference-profiles-agent-provider-mapping.md`](./0008-inference-profiles-agent-provider-mapping.md)
- [`0009-redundant-change-proposal-suppression.md`](./0009-redundant-change-proposal-suppression.md)
- [`0010-scheduled-wake-infrastructure.md`](./0010-scheduled-wake-infrastructure.md)
- [`0011-feedback-classification-strategy.md`](./0011-feedback-classification-strategy.md)
- [`0012-recursive-self-improvement-depth-policy.md`](./0012-recursive-self-improvement-depth-policy.md)
- [`0013-outbox-priority-queue.md`](./0013-outbox-priority-queue.md)
- [`0014-cross-wake-critical-observation-injection.md`](./0014-cross-wake-critical-observation-injection.md)
- [`0015-outbox-message-bundling.md`](./0015-outbox-message-bundling.md)
- [`0016-agent-state-as-log-projection.md`](./0016-agent-state-as-log-projection.md)
- [`0017-deterministic-log-compaction.md`](./0017-deterministic-log-compaction.md)
- [`0018-convergent-multi-device-execution.md`](./0018-convergent-multi-device-execution.md)
- [`0019-attention-negotiation-protocol.md`](./0019-attention-negotiation-protocol.md)
- [`0020-agent-input-capture.md`](./0020-agent-input-capture.md)
- [`0021-llm-mediated-attention-claim-weighing.md`](./0021-llm-mediated-attention-claim-weighing.md)
- [`0022-long-lived-daily-os-planner.md`](./0022-long-lived-daily-os-planner.md)
- [`0023-durable-domain-agents-and-time-negotiation.md`](./0023-durable-domain-agents-and-time-negotiation.md)
- [`0024-correction-lexicon-and-transcript-correction.md`](./0024-correction-lexicon-and-transcript-correction.md)
- [`0025-insights-time-analysis-data-layer.md`](./0025-insights-time-analysis-data-layer.md)
- [`0026-author-time-memory-links.md`](./0026-author-time-memory-links.md)
- [`0027-wake-notification-propagation-and-storm-prevention.md`](./0027-wake-notification-propagation-and-storm-prevention.md)
- [`0028-tagged-plaintext-payload-and-day-summaries.md`](./0028-tagged-plaintext-payload-and-day-summaries.md)
- [`0029-knowledge-graph-explorer.md`](./0029-knowledge-graph-explorer.md)
- [`0030-desktop-keyboard-command-system.md`](./0030-desktop-keyboard-command-system.md)
- [`0031-batch-first-day-audio-capture.md`](./0031-batch-first-day-audio-capture.md)
- [`0032-hierarchical-day-agent-coordination.md`](./0032-hierarchical-day-agent-coordination.md)
- [`0033-learning-verification-checkpoint-policy.md`](./0033-learning-verification-checkpoint-policy.md)
- [`0034-hybrid-understanding-evaluation.md`](./0034-hybrid-understanding-evaluation.md)
- [`0035-learning-verification-session-persistence.md`](./0035-learning-verification-session-persistence.md)
- [`0036-learning-understanding-rating.md`](./0036-learning-understanding-rating.md)
- [`0037-relationship-on-device-storage-and-privacy.md`](./0037-relationship-on-device-storage-and-privacy.md)
- [`0038-relationship-domain-model.md`](./0038-relationship-domain-model.md)
- [`0039-relationship-check-in-reminders.md`](./0039-relationship-check-in-reminders.md)
- [`0040-relationship-executive-briefing.md`](./0040-relationship-executive-briefing.md)
- [`0041-relationship-contact-linking.md`](./0041-relationship-contact-linking.md)
- [`0042-typed-task-relationship-links.md`](./0042-typed-task-relationship-links.md)
- [`0043-dependency-aware-planning.md`](./0043-dependency-aware-planning.md)
- [`0044-day-processing-outbox-storage.md`](./0044-day-processing-outbox-storage.md)
- [`0045-exclude-unverified-devices-from-key-sharing.md`](./0045-exclude-unverified-devices-from-key-sharing.md)
- [`0046-sync-actor-isolate-removed-and-how-to-rebuild.md`](./0046-sync-actor-isolate-removed-and-how-to-rebuild.md)
- [`0047-lean-keyboard-command-catalog-metadata.md`](./0047-lean-keyboard-command-catalog-metadata.md)
- [`0048-one-device-runs-the-coordinator-digest.md`](./0048-one-device-runs-the-coordinator-digest.md)
- [`0049-profile-scoped-storage-and-demo-mode.md`](./0049-profile-scoped-storage-and-demo-mode.md)
- [`0050-multi-tenant-worlds.md`](./0050-multi-tenant-worlds.md)
- [`0051-agenda-gated-tool-exposure.md`](./0051-agenda-gated-tool-exposure.md)
- [`0052-agent-directive-constitution.md`](./0052-agent-directive-constitution.md)
- [`0053-goal-driven-agents-per-goal-producers.md`](./0053-goal-driven-agents-per-goal-producers.md)
- [`0054-deterministic-first-two-tier-wakes.md`](./0054-deterministic-first-two-tier-wakes.md)
- [`0055-banner-nudge-attention-channel.md`](./0055-banner-nudge-attention-channel.md)
- [`0056-need-to-know-visual-brief-boundary.md`](./0056-need-to-know-visual-brief-boundary.md)
- [`0057-decade-scale-agent-memory.md`](./0057-decade-scale-agent-memory.md)
- [`0058-procedural-text-banners-no-generative-imagery.md`](./0058-procedural-text-banners-no-generative-imagery.md)
- [`0059-relationship-agent-runtime-and-nudge-generalization.md`](./0059-relationship-agent-runtime-and-nudge-generalization.md)
