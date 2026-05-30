# ADR 0019: Attention-Negotiation Protocol and Bid Schema

- Status: Proposed
- Date: 2026-05-30

## Context

Per-task, per-project, and day (`Shepherd`) agents run independently. They read
each other's distilled reports but never negotiate for the user's scarce
attention or resolve scheduling conflicts. The anchor paper leaves multi-agent
contention over the shared graph unresolved.

Lotti is already a blackboard system (append-only log = event source, projected
typed-edge graph = shared blackboard, agents = knowledge sources); what is
missing is a meta-level controller. Hard constraints cannot be enforced by
prompting an LLM (U-Define, arXiv 2605.02765), and "ask when in doubt" has a
decision-theoretic basis in value-of-information (Sarne & Grosz 2013).

Lotti already ingests wearable/health data (`lib/services/health_service.dart` +
`lib/logic/health_import.dart` → synced `QuantitativeEntry`/`WorkoutEntry`), so
receptivity and outcome signals are real and already in the graph, not
hypothetical.

## Decision

1. Introduce a single **planner behavior** as a Hayes-Roth meta-level controller
   over the shared graph.
2. **Bids are events, not RPCs.** Task/project agents emit `attention_request`
   events carrying impact, priority, deadline-slack, energy-fit, and (for
   recurring asks) a cadence — modeled as new `AgentDomainEntity` variants and
   `AgentLink` types on the existing synced graph. The exchange is
   Contract-Net-shaped (call-for-proposals → bid → award → inform).
3. **No auction incentive-compatibility — but not blind trust.** All bidders are
   sub-agents of one principal, so allocation collapses to a centralized utility
   ranking (no Vickrey payments). But one principal does not make LLM agents
   *calibrated*: they can overstate impact or misjudge urgency. So bids carry
   **evidence references** (links to the task/project/day facts that justify
   them) and **bounded fields**, and the planner **derives utility from those
   facts**, not from agent-self-assigned scores. The arbiter is a bounded
   heuristic, not optimal winner determination (which is NP-hard).
4. **Non-negotiables are enforced by a deterministic verifier** over the
   projected graph during the `draft → agreed` transition — not by instructing
   the LLM. The minimal constraint language is recurrence + preemption priority
   (e.g. "gym 3×/week may pre-empt"). Compliance is checked against real actuals,
   including `WorkoutEntry`/`QuantitativeEntry` from health import.
5. **"Ask when in doubt" = value-of-information.** Raise a `ChangeSet`/
   `ChangeDecision` only when the expected value of the user's answer exceeds the
   interruption cost; low-VOI conflicts auto-resolve and are logged **only for
   reversible, low-stakes actions** — committed schedule changes, block drops,
   and external side effects stay gated regardless of VOI until the user has
   calibrated trust. VOI proxies:
   day-plan utility delta, deadline slack, energy-band fit, recent
   `ChangeDecision` dismissal rate, and **device/health receptivity signals**
   (recent activity, workout completion, steps) from the existing health
   pipeline.
6. The planner's output is a `ChangeSet` routed through the existing human gate
   (ADR 0006); awards become `PlannedBlock`s on the `DayPlan`. A project phase
   can emit standing recurring `attention_request`s (e.g. "monitoring → 15 min
   weekly").
7. Negotiation **converges like any other agent state** (ADR 0018): bids and
   awards are events folded in canonical order, so concurrent arbiter runs on two
   devices cannot drop a bid branch — **convergence handles that, not the lease**.
   The lease on `(userId, dayId, planner)` only reduces duplicate planner work and
   gates the irreversible schedule commit.

## Negotiation Flow

```mermaid
sequenceDiagram
  participant Agent as Task / Project agent
  participant Planner
  participant Verify as Non-negotiable verifier
  participant User
  Agent->>Planner: attention_request (impact, deadline-slack, energy-fit)
  Planner->>Verify: candidate DayPlan vs hard constraints
  Verify-->>Planner: violations
  Planner->>Planner: rank by utility; compute VOI
  alt VOI > interruption cost
    Planner->>User: ChangeSet
    User-->>Planner: ChangeDecision
  else low VOI
    Planner->>Planner: auto-resolve and log
  end
  Planner->>Agent: award becomes PlannedBlock
```

## Consequences

- Cross-agent attention arbitration with one accountable planner; reuses the
  `ChangeSet` gate, the `DayPlan` (capacity/energy bands), and `WakeOrchestrator`.
- Non-negotiables are guaranteed by code, not hoped-for via a prompt.
- Interruptions are governed by VOI with real receptivity signals — the formal
  antidote to nagging.
- Open: whether the primary abstraction is bidding vs blackboard-posting
  (determines whether bid/award edge types are required); concrete VOI weighting;
  calibration of the receptivity model.

## Related

- `docs/daily_os_ai_runtime_architecture.md` (§5, §9, Thread A)
- Hayes-Roth, "A Blackboard Architecture for Control" (1985); Contract Net
  Protocol; Sarne & Grosz (2013); U-Define (arXiv 2605.02765)
- `lib/services/health_service.dart`, `lib/logic/health_import.dart`
- ADR 0002 (wake), ADR 0006 (ChangeSet), ADR 0018 (lease)
