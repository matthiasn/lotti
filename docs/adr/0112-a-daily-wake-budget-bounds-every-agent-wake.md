# ADR 0112: A Daily Wake Budget Bounds Every Project-Agent Wake

- Status: Accepted — implemented; the cross-device cadence and the
  scheduled-wake deduplication that complete it follow in a later change
- Date: 2026-10-02

## Context

On 2026-10-02 a single project agent was found to have run 313 times —
12.5 million input tokens, ~40 000 per wake — and others were waking about
200 times a day. Many of those wakes reported "No movement again": nothing had
changed. The agents' own reports flagged the spend.

Two findings from the investigation shaped this decision.

- **The switch did not mean what it showed.** `AgentConfig.automaticUpdatesEnabled`
  is nullable. The "Automatic updates" switch rendered null as off
  (`automaticUpdatesEnabledEffective`), but every project-agent runtime path
  read it through `projectAgentWakeAllowed`, which treated null as on — the
  "shipped-on legacy" rule. `ProjectAgentService.createProjectAgent` never
  writes the field, so every project agent whose switch was never touched
  displayed off and ran automatically.
- **Nothing bounded the work.** The existing wake model
  (`specs/tla/WakeRuntime.tla`, ADR 0066) proves `SingleFlight` and
  `NoLostWake`: never two runs at once, never a trigger left unserved. Both
  guard against doing too *little*. No property, and no runtime check, said a
  wake must be *needed*, or that an agent's wakes are finite. Every new trigger
  path — subscription matches, morning fallbacks, restored intents, sync
  repairs, catch-up wakes — added work that only its own guards limited, and
  each device ran its own copy.

The trigger side will keep changing, so the fix had to be a bound that holds
whatever the trigger.

## Decision

1. **A missing automation preference reads as off everywhere.**
   `projectAgentWakeAllowed` uses `automaticUpdatesEnabledEffective`, the
   value the switch shows. Untoggled project agents stop waking on their own;
   the user turns automation on with one tap.

2. **Every project-agent wake passes a daily budget at one choke point.** The
   drain's last policy check before the executor — `WakeDrainEngine`
   `_currentPolicyDecision(job, claimBudget: true)` — is the one place every
   wake path reaches, on every platform. There:
   - `maxWakesPerDay` lives on the identity's `AgentConfig`, so it syncs; null
     reads as **10**, and every value is clamped to 1–24 so a peer cannot lift
     the bound.
   - **Automatic** wakes stop once today's count reaches the limit.
   - **Explicit** requests ("Update now", creation) still run past it — the
     user asked, and it counts — up to a **hard ceiling of twice the limit**,
     which bounds a request mislabelled as the user's.
   - The pre-dispatch check reads the ledger only, so a refused wake writes no
     run row; the final check claims.

3. **Claim, then execute.** The claim increments a G-counter on the agent
   state keyed `<local day>|<host>` (`dailyWakesByDayHost`) in the same
   transaction that reads it, and syncs before the executor starts. A failed
   or aborted run still counts: it may have spent tokens. A claim that cannot
   be persisted refuses the wake. The concurrent resolver joins the counter
   element-wise, so two devices' claims add up instead of one overwriting the
   other. A run key claims once, so a superseded drain handing a run back does
   not count it twice.

4. **An unreadable policy fails closed for automatic work**, open for an
   explicit request.

5. **Pause is a kill-switch.** Pause, destroy and delete — locally or
   received by sync — call `WakeOrchestrator.haltAgent`: subscriptions and
   throttle go, queued work in every workspace is cancelled, a running wake is
   aborted. The abort reaches the conversation loop through the agent
   execution zone (`isAgentWakeAborted`), so an aborted wake stops before its
   next paid model turn instead of finishing in the background.

6. **Every decision is explained.** Each route, enqueue and dispatch decision
   logs one `wakeAudit` line with a stable cause (`budgetExhausted`,
   `automaticUpdatesOff`, `agentInactive`, `selfNotification`, …) and the
   wake's source. A refused wake completes with `WakeRefusedError(cause)`.
   Agent internals show "3 of 10 used today", and "Limit reached — automatic
   updates resume tomorrow" once it is.

## Consequences

- **The bound.** On one device an agent runs at most `max` automatic and
  `2·max` total wakes a day. Devices that see each other's claims share that
  bound, except for claims that cross in flight: each of `N` devices can claim
  once more before the other's claim arrives. Devices partitioned for the whole
  day each spend their own budget, so the worst case is `N · 2·max` — finite,
  and with the default of 10 two orders of magnitude below what was observed.
  The cross-device cadence (a later change) removes the crossing for automatic
  wakes.
- The day is each device's local calendar day; devices in different zones
  disagree only about which day a wake near midnight counts for.
- An older build that rewrites the state drops the ledger (it does not know
  the field) and an older identity rewrite would drop the limit; sync apply
  overlays a missing `maxWakesPerDay` from the local row, as it does for the
  automation preference.
- Project agents whose switch was never touched stop updating automatically.
  Their reports go stale, with "Update now", until the user turns automation on.
- Two amplifiers found in the same audit are closed with it: switching
  automation on bought a catch-up wake whenever `reportFreshAt` was null (any
  report never marked stale), and project or link changes made inside an agent
  wake reached the local update stream as if the user had made them.

## Related

- ADR 0066 — model-checked agent wakes (`SingleFlight`, `NoLostWake`)
- ADR 0069 — scheduled-wake leases, which the cadence will reuse
- `lib/features/agents/wake/wake_budget.dart`, `wake_audit.dart`
