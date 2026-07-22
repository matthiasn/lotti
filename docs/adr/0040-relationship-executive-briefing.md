# ADR 0040: Relationship Executive Briefing

- Status: Proposed
- Date: 2026-07-22

## Context

Before the user next engages with a person, Lotti should hand them what a
good executive assistant would: how things are going, what was discussed
recently, how interactions have felt, what to bring up, what to pay
attention to, and what to avoid.

The AI layer is mid-migration: the legacy prompt-driven `AiResponseType`
path is deprecated for summaries, superseded by the agent system
(`lib/features/agents/`). The established pattern — used by task, project,
event, and day agents — is: an agent kind plus link type binds a durable
agent to an entity; a workflow runs profile-resolved inference with tool
calls; the output is an `AgentReportEntity` (`content` markdown, `tldr`,
`oneLiner`) with a latest-report head; consumers resolve it like
`TaskSummaryResolver` does. The project agent additionally emits a
structured health band (`ProjectHealthMetrics`: band, rationale,
confidence) parsed from report provenance and rendered as a chip. Local
inference (Ollama, OMLX/MLX) is a first-class provider option, and
inference profiles can pin capability slots to local models.

## Decision

1. **A durable relationship agent per relationship.** New
   `AgentKinds.relationshipAgent`, `AgentLinkTypes.agentRelationship`, and
   `AgentTemplateKind.relationshipAgent`; a `RelationshipAgentService`
   creates the agent lazily and links it to the relationship entity,
   mirroring `TaskAgentService`/`ProjectAgentService`. All exhaustive
   agent-kind switches are audited as part of the change.
2. **The briefing is an `AgentReportEntity`.** `content` is the full
   executive briefing (state of the relationship, key topics from recent
   check-ins, sentiment trajectory, suggested talking points, pay-attention
   list, avoid list); `tldr` is the card summary; `oneLiner` the compact
   tagline. Latest-wins via the report head; shown in the relationship
   detail header through a resolver in the `TaskSummaryResolver` style.
3. **Structured relationship health in provenance.** The report contract
   defines a `relationship_health` band — `thriving`, `steady`,
   `needsAttention`, `strained` — with free-text rationale and optional
   confidence, parsed and rendered exactly like `ProjectHealthMetrics`.
   The band must be grounded first in the explicit `CheckInData.sentiment`
   values (user judgment), with prose only as secondary evidence.
4. **Strict context boundary.** The workflow assembles: the relationship
   entity and its `entryText`, the most recent N check-ins (structured
   fields plus narrative), linked tasks' titles and statuses, and the
   previous report. Nothing else from the journal is included. This keeps
   briefings explainable, keeps token budgets bounded, and minimizes what a
   cloud model could ever see when one is selected.
5. **Triggers.** On-demand ("Brief me" on the relationship detail page) and
   an automatic debounced refresh after a new check-in is saved, so the
   briefing is already fresh when a reminder (ADR 0039) brings the user
   back. No scheduled or speculative runs beyond that.
6. **Privacy-weighted model routing.** The profile is resolved from
   `RelationshipData.profileId`, falling back to the category default.
   Local-model profiles are the recommended default for this data class;
   cloud providers are an equally legitimate route when they are
   GDPR-compliant with zero-data-retention terms — then inference is
   transient processing and nothing is stored outside the user's devices.
   Either way, the trigger surface names the provider before running
   (ADR 0037). No inference ever runs
   without an explicit user-facing trigger or the post-check-in refresh the
   user enabled by using the feature.
7. **Honesty rules in the template.** The briefing may only reference
   captured check-ins and linked entities, must state recency ("last spoke
   five weeks ago"), must say when there is not enough data rather than
   pad, and must keep `payAttentionTo`/`avoid` guidance traceable to the
   check-ins that produced it.

## Consequences

- The feature inherits agent-system infrastructure wholesale: report
  storage, sync, head resolution, profile routing, and UI patterns — the
  new code is one service, one workflow, one report contract, and rendering.
- Briefing quality tracks check-in quality; thin capture yields thin
  briefings by design (honesty rules), which is the correct incentive.
- Local-first routing means weaker prose on low-end hardware; users can
  opt into cloud per profile, with the trade-off made visible.
- A second consumer of the health-band pattern will pressure the provenance
  parsing into a shared helper rather than a copy — worth doing during
  implementation.

## Related

- [ADR 0037: Relationship Data Stays On-Device](./0037-relationship-on-device-storage-and-privacy.md)
- [ADR 0038: Relationship Domain Model](./0038-relationship-domain-model.md)
- [ADR 0039: Relationship Check-In Reminders](./0039-relationship-check-in-reminders.md)
- [ADR 0016: Agent-Derived State as a Projection of the Append-Only Log](./0016-agent-state-as-log-projection.md)
- [ADR 0023: Durable Domain Agents and Time Negotiation](./0023-durable-domain-agents-and-time-negotiation.md)
- [Implementation plan](../implementation_plans/2026-07-22_relationship_management.md)
