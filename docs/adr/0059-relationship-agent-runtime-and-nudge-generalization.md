# ADR 0059: Relationship Agents on the Shared Runtime and the Kind-Agnostic Nudge Substrate

- Status: Proposed
- Date: 2026-08-16

## Context

ADRs 0037–0041 specified relationship management on 2026-07-22, before the
goal-agent stack existed. Since then, ADRs 0053–0058 shipped (behind
`enable_agents_page`) exactly the machinery those ADRs had to assume or
invent:

- a **runtime registry for pluggable agent kinds** — feature-owned wake
  runners and maintenance merged into `agentWakeRunnersProvider` /
  `agentRuntimeMaintenanceProvider` in `app_bootstrap.dart` (today: day and
  goal agents),
- **deterministic-first two-tier wakes** (ADR 0054) — a €0 pure-Dart Phase A
  on every device tick, LLM Phase B only on lease-elected escalation, with
  the workspace-key and baseline-token contract proven in
  `lib/classes/goal_trigger_tokens.dart`,
- the **banner-nudge attention channel** (ADR 0055, revised by 0058) — the
  `goalNudge` entity lifecycle (`draft → ready → active → dismissed |
  retired | expired | superseded | failed`), dismissal-as-data with
  rest-of-day quiet windows, snooze provenance, per-activation ratings,
  exposure metrics, and a shell-level dock,
- a **kind-agnostic chat projection** and the durable chat-turn pattern.

Meanwhile phases 1–2 of the
[v2 implementation plan](../implementation_plans/2026-08-13_relationship_management_v2.md)
landed: the journal-side domain model (ADR 0038 holds) and the flag-gated
People tab with full CRUD, check-ins, contact channels, and task linking.

The next phases bind the relationship agent and its attention surface to
this runtime. Two of the July ADRs no longer describe the best available
shape: ADR 0040 assumed an `AgentTemplateKind` and ad-hoc triggering; ADR
0039 routed attention through OS notifications first. This ADR records the
rebase — decisions D2 and D3 of the v2 plan — and the sync-compatibility
rules for generalizing the goal-typed nudge substrate to a second kind.

Two traps in the current code motivate specific decisions below, both
verified: `agent_wiring.dart` resolves unregistered agent kinds to the
task-agent workflow silently (the registry is "consulted before the
task-agent default"), and the `requiresLease` predicate in
`agent_providers.dart` enumerates lease-elected workspaces explicitly — a
new escalation family that is not added there runs on every device and
bills one inference per device for a single result.

## Decision

1. **The relationship agent is a registered runtime kind on two-tier wakes
   (amends ADR 0040).** New `AgentKinds.relationshipAgent`, linked to its
   journal entity via `AgentLinkTypes.agentRelationship`, contributed
   through `relationshipAgentWakeRunnersProvider` +
   `RelationshipRuntimeMaintenance` merged in `app_bootstrap.dart` — never
   resolved via the silent task-agent default in `agent_wiring.dart`. A
   regression test pins runner resolution for the kind (the documented
   ADR 0054 trap). Following the goal precedent (ADR 0053 Decision 7),
   there is **no `AgentTemplateKind.relationshipAgent`**: the constitution
   is code (`relationshipAgentSystemPrompt`, ADR 0052). ADR 0040's
   template assumption (its Decision 1) is dropped; its report contract,
   health band, context boundary, honesty rules, and privacy-weighted
   routing all stand.

2. **Phase A is deterministic and free; inference is fact-gated.** Every
   wake recomputes a **cadence-health register** from the relationship and
   its linked check-ins — recomputed, never accumulated, so multi-device
   runs converge — and re-arms the daily cadence tick on a
   `relationship-cadence` workspace (calendar arithmetic, the
   `goal-cadence` pattern). ADR 0039's eligibility rule survives here as
   wake facts: `important == true`, status `active`, days since the last
   check-in (baseline: the relationship's own `meta.dateFrom`) measured
   against `checkInCadenceDays`. Phase B runs only on facts — cadence
   newly due, a check-in saved since the last report, a user chat message,
   or an explicit "Brief me" — and tool exposure stays fact-gated per
   ADR 0051.

3. **Escalations are lease-elected and per-episode.** The escalation
   workspace key derives from the due-day key
   (`relationship-escalation:<dueDayKey>`, the `goal-escalation:<periodKey>`
   precedent), so devices arming the same logical escalation write
   identical records and one lease winner runs Phase B. The trigger tokens
   carry a **baseline token** with the pre-transition cadence state (the
   `goal-baseline` lesson): Phase A updates the register and arms the
   escalation in one transaction, so by the time Phase B re-derives facts,
   "newly due" vs. "still due" is unreconstructable from storage without
   it. A check-in landing while an escalation is pending changes the due
   day and thus the episode; Phase B re-derives facts first and returns
   before any inference when the armed fact no longer holds. The
   `requiresLease` predicate in `agent_providers.dart` is extended with the
   `relationship-escalation:` family. The token contract lives in
   `lib/classes/relationship_trigger_tokens.dart`, runtime-visible without
   importing the feature (the `goal_trigger_tokens.dart` shape).

4. **Attention is the banner channel; OS reminders come later (supersedes
   ADR 0039 in part).** The primary nudge surface is the shell banner dock
   with every inherited semantic: quiet by default, dismissal = rest of
   the local calendar day, snooze as provenance, per-activation ratings,
   exposure metrics as synced CRDT data (ADR 0055/0058). Banner copy is
   model-authored text rendered procedurally — no generative imagery
   (ADR 0058 governs). ADR 0039's `NotificationEntity.relationshipCheckIn`
   variant and the `NotificationScheduler.reconcile()` startup wiring are
   **still wanted** — a phone should alert when the app is closed — but
   deferred to their own change, because wiring `reconcile()` revives OS
   alerts for *all* inbox types and deserves isolated tests. The gate for
   building it at all is dogfooding evidence that closed-app reminders are
   actually missed.

5. **The nudge substrate generalizes by sibling variant, never by
   conversion.** The nudge vocabulary currently in
   `lib/classes/goal_nudge_models.dart` — tone, the status lifecycle, the
   animation/accent catalogs, brief, rating, snooze, day-dismissal — is
   extracted into kind-neutral shared models (goal aliases retained during
   migration). `AgentDomainEntity` gains a **sibling `relationshipNudge`
   variant beside `goalNudge`**. Existing `goalNudge` rows are never
   converted or renamed — older peers must keep decoding them. Older peers
   decode `relationshipNudge` through the existing `unknown` fallback in
   `agent_db_conversions.dart` and never surface it (the agent kind does
   not exist for them), so mixed-fleet rollout is safe by construction,
   not by coordination. The concurrent-resolver rules (terminal-dismissal
   dominance, G-counter exposure merges) move into shared helpers applied
   per-variant rather than being duplicated.

6. **Dock visibility becomes per-kind; the height contract holds.** The
   `goal_banner_*.dart` widget family, `goal_banner_snooze.dart`, and
   `GoalNudgeInteractions` are generalized to the shared entry type; the
   shell dock (`beamer_app.dart` mounts) merges active nudges across kinds
   and keeps the reserved-lane height contract. The page-visibility gate
   (today `_showsGoalBannerDock`: tasks, dailyOs, habits) becomes
   per-kind: goal nudges keep exactly their current surfaces; relationship
   nudges show on those same surfaces plus the `/people` pages. The
   generalization is a behavior-preserving refactor that lands green with
   `enable_relationships` off and zero visible change for goals, pinned by
   the existing goal-banner test suites.

7. **Privacy posture is inherited unchanged (ADR 0037 holds).** Phase B
   context is bounded per ADR 0040: the relationship, the last N
   check-ins, linked task titles/statuses, and the previous report —
   **contact channels and contact refs never enter model context**
   (ADR 0041 §5). Inference is profile-routed
   (`RelationshipData.profileId` → category default → app default); before
   any cloud-bound trigger the UI names the provider, using the
   fails-closed `profileIsLocal` helper
   (`lib/features/ai/helpers/profile_locality.dart`). Deletion of a
   relationship cascades to its agent identity and the agent's entities —
   reports, nudges, registers — and pending reminder rows.

## Consequences

- The relationship feature inherits the goal stack wholesale — wake
  orchestration, lease election, outbox buffering, chat projection, report
  head resolution, consumption events, retention — and its new runtime code
  reduces to Phase A facts, one workflow, one token contract, and
  registration.
- The nudge generalization (Decision 5–6) is a prerequisite refactor that
  touches goals without changing them; the existing goal tests are the
  safety net, and the refactor must land before any relationship-agent
  banner work starts.
- A second consumer forces the shared helpers ADR 0040 predicted: the
  health-band provenance parsing extracts from
  `project_health_metrics.dart` into a helper used by both project and
  relationship reports.
- `app_bootstrap_test.dart` pins the provider override count; the bootstrap
  merge bumps it deliberately.
- ADR housekeeping recorded here: ADR 0039 is **superseded in part** (its
  attention channel; its eligibility rule and inbox variant survive as
  Decisions 2 and 4), and ADR 0040 is **amended** (registered runtime kind,
  two-tier wakes, no template).
- Left deliberately open, to be decided in the Phase B UI work: whether
  tapping a relationship nudge opens the relationship detail page
  (proposed — the briefing lives there) or the agent chat (the goal
  precedent, ADR 0055 Decision 6).

## Non-Goals

- OS push or notification-tap routing for relationship reminders (deferred
  per Decision 4).
- Converting, renaming, or migrating existing `goalNudge` rows.
- Birthday nudges (a deterministic Phase A fact feeding a banner — post-v1).

## Related

- [ADR 0037: Relationship Data Stays On-Device](./0037-relationship-on-device-storage-and-privacy.md)
- [ADR 0038: Relationship Domain Model](./0038-relationship-domain-model.md)
- [ADR 0039: Relationship Check-In Reminders](./0039-relationship-check-in-reminders.md) — superseded in part by this ADR
- [ADR 0040: Relationship Executive Briefing](./0040-relationship-executive-briefing.md) — amended by this ADR
- [ADR 0041: Relationship Contact Linking](./0041-relationship-contact-linking.md)
- [ADR 0051: Agenda-Gated Tool Exposure](./0051-agenda-gated-tool-exposure.md)
- [ADR 0052: Agent Directive Constitution](./0052-agent-directive-constitution.md)
- [ADR 0053: Goal-Driven Agents — Per-Goal Durable Producers](./0053-goal-driven-agents-per-goal-producers.md)
- [ADR 0054: Deterministic-First Two-Tier Wakes](./0054-deterministic-first-two-tier-wakes.md)
- [ADR 0055: The Banner-Nudge Attention Channel](./0055-banner-nudge-attention-channel.md)
- [ADR 0058: Procedural Text Banners — No Generative Imagery](./0058-procedural-text-banners-no-generative-imagery.md)
- [Implementation plan v2](../implementation_plans/2026-08-13_relationship_management_v2.md) (decisions D2/D3 recorded here)
- [knowledge/features/goals.md](../../knowledge/features/goals.md) — the runtime precedent this rebases onto
- [knowledge/features/relationships.md](../../knowledge/features/relationships.md) — the shipped phases 1–2
