# Task Agent LLM Context — Review Findings & Mitigations

- Status: Plan proposed (findings accepted; implementation not started)
- Date: 2026-06-09
- Decision baseline: [ADR 0003](../adr/0003-task-agent-linked-task-context-contract.md),
  [ADR 0004](../adr/0004-task-agent-tool-execution-policy.md),
  [ADR 0016](../adr/0016-agent-state-as-log-projection.md),
  [ADR 0017](../adr/0017-deterministic-log-compaction.md),
  [ADR 0022](../adr/0022-long-lived-daily-os-planner.md),
  [ADR 0023](../adr/0023-durable-domain-agents-and-time-negotiation.md)
- Scope: the task-agent wake → LLM context path
  (`lib/features/agents/workflow/task_agent_*`,
  `lib/features/ai/conversation/conversation_manager.dart`), reviewed against the
  patterns established for the Daily OS planning agents. No behavior shipped yet.

## Goal

Evaluate, and where warranted improve, how the per-task agent constructs and
orders the LLM context for each wake: prompt assembly and ordering, system-prompt
size and instruction design, whether progressive disclosure / a skills layer is
worth building, how linked-task context and the cross-task update graph behave,
and which Daily OS planner / agent-state patterns should (and should not)
transfer to task agents.

The task agent's design is, on the whole, sound and deliberate — the verdict is
**not** a rewrite. This plan captures the small set of real defects worth fixing
and an explicit list of tempting-but-wrong changes to avoid, so the prefix-cache
and convergence properties the design depends on are preserved.

It also carries one **priority correctness fix** to land alongside this work: a
fail-closed pass over every task-agent tool so a **hallucinated entity ID** can
never be queued as a suggestion or surfaced as raw-ID text — see the next
section.

## How this plan was produced

An adversarial multi-agent review (find → independently refute → synthesize) ran
over five dimensions. Every finding was checked by a separate skeptic that tried
to refute it against the actual code before it was accepted — the same discipline
that previously caught review claims resting on false premises.

- 5 dimensions, **28 findings, 24 survived verification, 4 refuted**.
- Severities below are the **verifier-corrected** severities, not the original
  reviewer framing (several "high" findings were downgraded once the premise was
  tested against the code).

## Verdict (answers to the five questions)

1. **Is the context constructed correctly — system message first?** Yes. The
   system prompt is `messages[0]`
   (`conversation_manager.dart:49-50`); the user message is volatility-ordered
   after it. The one real construction defect is that parent-project and
   linked-task JSON sit in the *stable prefix* yet embed other agents' mutable
   reports (see **asm-2**).
2. **Is the system message too large?** Not in cost/latency terms — it is
   byte-stable, content-addressed once, and prefix-cacheable; token count is the
   wrong metric. The genuine concern is **attention dilution on the small/local
   models this system explicitly targets** (see **sp-1**), plus prose duplicated
   against per-tool descriptions (see **pd-3**). Fix by salience-ordering and
   dedup — **not** by shrinking for tokens.
3. **Should there be progressive disclosure with skills?** **No**, not as a
   framework (see **pd-1, pd-5, pd-6**). The prefix is already cached, so
   disclosure trades a free cache-read for an extra round-trip against the scarce
   `maxTurnsPerWake` budget. `built_in_skills.dart` is an unrelated single-shot
   feature and must not be conflated (**pd-4**).
4. **How are linked tasks treated and what is the update graph?** Compact
   `oneLiner`/`tldr` per neighbor, rebuilt each wake; the full body is omitted.
   **There IS an event-driven cross-task graph** (the original finding's
   "no cross-task push" framing was wrong — see **graph-1, corrected**): a
   *user* edit of task A fans out via `parentLinkedEntityIds` + `PROPAGATED::B`
   tokens on `localUpdateStream` and wakes the agent of every task B that links
   A; task agents set `deferPropagatedMatches: false`, so they fast-drain these.
   What is *deliberately* suppressed is **agent-origin** propagation — an agent's
   own journal writes use `notifyUiOnly` (off `localUpdateStream`) and
   report-prose writes hit only `agent.sqlite` — and that suppression, together
   with propagated-match deferral, the 120 s throttle, and self-mutation
   suppression, is the multi-layer system that kills the A→B→A storms. The
   on-demand drill-down meant to deepen linked context is **dead code**
   (**graph-2**).
5. **Which planner patterns transfer?** Almost none. The **one-agent-per-task
   boundary is confirmed correct** (**xfer-1**). The planner's single-identity,
   two-tier hook-index, and weekly-promotion loop should **not** be ported
   (**pd-5, xfer-5**). The one genuine gap is a narrow per-task,
   compaction-exempt, user-confirmed instruction surface — and even that has
   cheaper mitigations than a new store (**xfer-2/xfer-3**).

> Cross-cutting caveat (**sp-5**): there are **no explicit `cache_control`
> breakpoints** anywhere in `lib/features/ai` or `lib/features/agents`; every
> provider (incl. Anthropic) is routed through the OpenAI-compatible
> `openai_dart` surface and relies on *implicit* endpoint prefix caching. The
> byte-stable-prefix savings therefore hold for OpenAI/Gemini/local-KV but yield
> **zero discount on the Anthropic path**. If cost on that path matters, the
> follow-up is "verify the endpoint enables automatic prefix caching", **not** a
> scaffold shrink.

## Invariants any change here MUST preserve

These are why several plausible fixes are rejected below; treat them as gates.

1. **Stable-prefix byte-stability.** Nothing per-wake-mutable may precede the
   `## Task Log` (`task_agent_prompt_builder.dart:445-451`). One flipped byte
   voids the provider prefix cache for everything after it. In particular, **no
   value derived from `createdAt`-vs-now (`stale` flags) may go into the stable
   prefix.**
2. **Convergence (ADR 0016/0018) is about the log/state, not the scaffold.** The
   system prompt is template-derived and content-addressed; a one-time stable
   reorder is fine. Do not introduce new mutable synced rows.
3. **No dead code / docs that lie.** The repo's no-dead-code rule applies; docs
   must match runtime reality.
4. **Report prose is never re-injected** (`task_agent_prompt_builder.dart:616-620`)
   — this is deliberate anti-feedback-loop design. No "remember my own
   conclusions" store may reverse it (**xfer-6**).

---

## Priority fix (land first): fail-closed entity-reference validation across all task-agent tools

**Symptom (observed in the running app):** deferred suggestions were shown whose
visible text was a raw/truncated **ID** (a label, and checklist items) rather
than a name/title — a clear sign the agent passed a **hallucinated ID** that no
lookup could resolve, yet the system queued a user-facing proposal for it anyway
instead of rejecting it.

**Root cause (confirmed in code):** the deferred change-set path resolves entity
names *for display only*, falls back to the raw ID, and explicitly **keeps**
items it cannot resolve:

- `change_set_batch_exploder.dart:496-510` (`_generateLabelSummary`):
  `display = labelName ?? _truncateId(labelId)` — a non-existent label ID renders
  as a truncated UUID and the item is **still added** to `_items` (`:177-184`).
  There is **no existence gate for labels** — only an already-assigned redundancy
  check (`_checkLabelRedundancy`) and fingerprint dedup, neither of which fires
  for a made-up ID.
- `change_set_batch_exploder.dart:239-295` (`_generateItemSummary`) +
  `:392-403` (`_checkRedundancy`): when `checklistItemStateResolver` returns null
  (item not found), `_checkRedundancy` returns null with the comment
  *"Item not found — keep it,"* and the summary falls back to
  `'<action> item <truncatedId>'`. A hallucinated checklist-item ID is kept and
  surfaced as a raw ID.
- The **immediate** (non-deferred) checklist handler already rejects unknown ids
  (`lotti_checklist_update_handler.dart:348` `_skip(id, 'Item not found')`), but
  `assign_task_labels` and `update_checklist_items` are **deferred** tools that
  never reach it — they go through the exploder, which has no existence gate.

So the resolvers (`labelNameResolver`, `checklistItemStateResolver`) already
return null on a miss; the bug is that the code treats null as
*"show the raw ID and keep the proposal"* instead of *"reject."*

**Principle:** every tool argument that references an existing entity must be
validated against the real DB / the wake's allowlist **before** a proposal is
queued or a mutation applied. On failure: drop the element, never surface a raw
ID, and return an explicit error to the model so it self-corrects — e.g.
*"label `<id>` does not exist; use only label IDs from the 'Available Labels'
section — do not invent IDs."*

**Surface to harden (every task-agent tool taking an entity reference):**

| Tool | Arg(s) | Validate against | Today |
|------|--------|------------------|-------|
| `assign_task_labels` | `labels[].id` | label exists (`getLabelDefinitionById`) **and** is in the wake's Available-Labels set | **leaks raw ID, queues** |
| `update_checklist_items` | `items[].id` | checklist item exists + belongs to this task | **leaks raw ID, keeps** |
| `migrate_checklist_items` | `items[].id` | checklist item exists + belongs to the source task | unvalidated |
| `update_time_entry` | `entryId` | entry exists + is in the prompt's "Editable Time Entries" allowlist | unvalidated (queued, fails later) |
| `update_running_timer` | `timerId` | equals the actually-running timer id for this task | unvalidated |
| `get_related_task_details` | `requestedTaskId` | in `allowedRelatedTaskIds` | already gated (but tool dormant — see **graph-2**) |
| `set_task_*`, `create_time_entry`, `create_follow_up_task` | — | operate on the wake task / create new entities | no lookup needed |

**Fix approach:**

1. Add a fail-closed existence/allowlist gate per referenced id in the exploder
   (`assign_task_label`, `update_checklist_item`, `migrate_checklist_item`) and in
   the non-batch deferred handlers (`update_time_entry`, `update_running_timer`).
   Surface rejected elements as a distinct `rejected` bucket in `BatchAddResult`
   (parallel to `redundant`/`skipped`), each with a per-element reason.
2. **Never fall back to a raw/truncated ID in any `humanSummary`.** If a
   name/title cannot be resolved, the element is by definition invalid and must be
   rejected — there is no legitimate queued proposal that references an
   unresolvable entity. (Removes the `?? _truncateId(...)` fallbacks at
   exploder `:278,:286,:291,:440,:491,:503`.)
3. Return an explicit, instructive error string in the tool response (the model
   sees it next turn and stops hallucinating) **and** record a tool-failure
   observation, per the existing "note the failure in observations" guidance.
4. Reuse the existing resolvers as the gate — they already return null on miss;
   the change is to treat null as **reject**, not **display-fallback / keep**
   (flip the `_checkRedundancy` "Item not found — keep it" branch to a rejection
   for the *update* case, since you cannot update what does not exist).
5. Tests: a hallucinated label id and a hallucinated checklist-item id each
   (a) queue **zero** items, (b) produce an error response naming the bad id,
   (c) never surface a raw UUID in any `humanSummary`; plus a valid id still
   queues normally (no regression to the redundancy/dedup pipeline).

**Why it's safe:** the gate rejects only references no lookup resolves; valid ids
(present in the prompt context) are unaffected. It is tool-execution-time
validation — no impact on prefix-cache stability or multi-device convergence —
and it strengthens, rather than replaces, the existing redundancy/dedup pipeline.

---

## Findings & mitigations

Each item lists the verifier-corrected severity, the code evidence, and the
agreed mitigation. Items are grouped by dimension; the cross-dimension execution
order is in the next section.

### A. Context construction & ordering

- **asm-2 — Parent-project / linked-task JSON in the stable prefix embeds
  neighbors' mutable reports.** `[MEDIUM, confirmed]`
  `## Parent Project Context` and `## Linked Tasks` are written before the log
  (`task_agent_prompt_builder.dart:484-500`) but carry
  `latestTaskAgentReportOneLiner/Tldr/CreatedAt`
  (`task_agent_context_builder.dart:325-329`) and the project agent's report
  (`ai_input_repository.dart:297-306`). The ISO `createdAt` is the wake `now`
  rewritten on every material `update_report`, so a neighbor's republish flips
  high-prefix bytes and voids this task's warm cache for the whole log + tail.
  The sibling **project** agent already places this content *after* its log
  (`project_agent_context_builder.dart:191-215`) — the task agent is the outlier,
  and ADR 0017 Decision 6 does not include parent/linked JSON in the prefix.
  **Mitigation:** move both blocks below `## Task Log` into the volatile tail
  (match the project agent); at minimum drop the `createdAt` field. Extend the
  byte-identity prefix test to vary a neighbor's report between wakes so this
  regression is caught going forward. _Impact: warm-cache cost/latency only,
  never correctness._

- **asm-4 — Open proposals rendered twice; trigger tokens are content-free.**
  `[LOW, partial]` In compacted mode the open-proposal payload renders
  byte-identically in both the ledger (`task_agent_context_builder.dart:145-156`)
  and the guard (`:187-195`). The `## Changed Since Last Wake` section
  (`task_agent_prompt_builder.dart:630-637`) — the most action-relevant signal of
  the wake — emits only a bare joined entity-ID list with no diff.
  **Mitigation (volatile tail only, prefix-cache-safe):** in compacted mode drop
  the open list from the ledger and keep the guard copy (it carries the
  fingerprints `retract_suggestions` needs); keep the ledger's Resolved
  subsection for legacy/non-compacted mode. Resolve trigger tokens into
  human-readable diffs in `## Changed Since Last Wake`. _Most tasks carry
  few/zero open proposals, so payoff is modest — quality, not correctness._

- **asm-3 — `maxHistorySize` hardcoded to 100, decoupled from
  `maxTurnsPerWake`; trim is not tool-pair-aware.** `[LOW, partial]`
  `createConversation` forwards only `maxTurns`, so `maxHistorySize` stays 100;
  `_trimHistoryIfNeeded` (`conversation_manager.dart:178-212`) drops the middle
  role-blind. Refuted parts: trim runs only on `addUserMessage`, so it cannot
  split a turn's assistant `tool_use` from its own tool responses, and >100
  messages in one wake is unrealistic at the real default `maxTurnsPerWake=10`
  (exploded-batch tools yield one tool response per call; single-use guards cap
  fan-out; default model Gemini is lenient on pairing).
  **Mitigation (cheap hardening, optional):** make `_trimHistoryIfNeeded` drop
  leading orphan `tool` messages so the retained tail starts on an
  assistant/user boundary (helps strict providers if trim ever fires).
  Optionally derive `maxHistorySize` from config.

- **asm-1 — Label/correction context precedes the log.** `[LOW, partial]`
  `task_agent_prompt_builder.dart:454-482` writes label/correction context first.
  These are rare-change (label proposals are user-gated `deferredTools`;
  corrections are category-scoped) and the agent cannot directly flip them, so
  they are correctly grouped with the other rare-change reference blocks.
  **Mitigation:** documentation only — soften the comment at `:445-451` to
  "nothing that changes *more often than the log* may precede it." **Do not
  relocate** (no steady-state gain; would invalidate an already-cold region).

### B. System prompt size & instruction design

- **sp-1 — Trailing scaffold is a ~2,414-token undifferentiated rule wall.**
  `[MEDIUM, confirmed]` `taskAgentScaffoldTrailing`
  (`task_agent_prompt_builder.dart:258-417`, ~63% of the scaffold) mixes
  load-bearing gates (no-op `:263-266`, single-use discipline, report-vs-
  observations) with rarely-fired narrative (task-splitting `:359-373`,
  grievance sub-policy `:300-314`, ~35-line Suggestion Hygiene `:375-410`). The
  no-op gate is stated 3× (prompt bullet + per-behavior bullets `:327-344` + each
  tool's own description). The system demonstrably targets weak local models
  (code comments cite Qwen 3.6 and "smaller models burn all turns"), where
  dilution bites. **Mitigation:** salience-order the always-on body
  (high-frequency / high-consequence rules first); state the no-op principle once
  and rely on the per-tool descriptions. One-time stable reorder — prefix-cache
  and convergence neutral. _Caveat: the magnitude of behavioral gain is
  empirical/unproven; the shape (dense wall, triplicated gate) is verified fact._

- **pd-3 — Scaffold prose duplicates per-tool description text.**
  `[LOW, confirmed]` Concrete duplicated pairs: Estimates (scaffold `:323-326`
  vs tool `:30-32`), Status no-op + BLOCKED/ON HOLD + DONE/REJECTED-user-only
  (`:327-334` vs `:761-769`), Title (`:321-322` vs `:7-14`), Labels cap-3 gate
  (`:340-344` vs `:700-704`), Language (`:335-339` vs `:736-741`), Checklist
  sovereignty (`:345-357` vs `:119-126`), Task splitting (`:359-373` vs
  `:179-184`/`:215-218`). **Mitigation:** deduplicate scaffold-vs-tool-schema
  prose. Both halves sit in the stable prefix, so dedup shrinks the cached block
  without breaking byte-stability. **Do not** build a hook index for these rules.

- **sp-3 — Enforced single-use contract is invisible up front.**
  `[LOW, partial]` The runtime `_usedDeferredTools` guard
  (`task_agent_strategy.dart:318-347`) and forced-report retry
  (`task_agent_workflow.dart:986-1008`) work, but the scaffold never states "each
  metadata tool at most once per wake"; the model learns it only from an error
  string after burning a turn. **Mitigation:** add one line near the No-op rule —
  "Each metadata tool may be queued at most once per wake (batch tools and
  `create_follow_up_task` are exempt)." Keep `:273` ("do not call speculatively
  or redundantly") — it also covers speculative calls. Disregard the finding's
  "~2,400 tokens wasted" framing (conflates the whole block with two lines).

- **sp-2 — `languageCode` / report-vs-observations restated.** `[LOW, partial]`
  Inflated: only ~2 of the cited language copies are true restatements
  (`:209-212` and the first clause of `:335-339`); `:264` (no-op list) and `:560`
  (tool desc) are different rules. **Mitigation:** zero-priority — collapse only
  the one truly duplicated sentence so it lives once in the Writing-style section;
  keep the Language bullet's non-redundant `set_task_language` gating half and
  Core step 3 (carries the "context is lost forever" data-loss warning).

- **sp-4 — Static sections fire regardless of task shape.** `[LOW, partial]`
  Task-splitting, checklist-sovereignty, and parent-project guidance are
  unconditional. This is **intended** — being unconditional is what makes the
  prefix cacheable; conditionalizing or a body/appendix split would either change
  nothing or push per-wake-mutable bytes into the prefix.
  **Mitigation:** **do not relocate / conditionalize.** If cold prefill is ever
  measured as a concern, condense the prose while keeping it byte-stable.

- **sp-5 — Token size is cheap; do not optimize for it.** `[LOW, JUSTIFIED]`
  Accepted guidance, with the Anthropic-path caching caveat noted in the Verdict.
  **Mitigation:** none beyond treating prefix stability as an asset; track the
  "verify endpoint automatic prefix caching" follow-up separately if Anthropic
  cost matters.

### C. Progressive disclosure / skills

- **pd-6 / pd-1 / pd-5 — No general disclosure/skills framework.**
  `[LOW, confirmed/partial]` Savings are illusory (prefix cached), the cost lands
  on the scarce turns budget, the gated content is mostly common-path, the
  planner's two-tier knowledge solves an *unbounded-growth* problem task agents
  don't have, and the only growing per-task surface (the log) is already bounded
  by ADR 0017 compaction. **Decision: do not build it.** At most, gate the single
  rarest workflow (task-splitting) behind a one-line hook — and measure first.

- **pd-4 — `built_in_skills.dart` is unrelated.** `[LOW, confirmed]` It is a
  single-shot AI-assistant feature (Transcribe / Analyze Image / Prompt
  Generation) with zero coupling to `lib/features/agents/`. **Decision:**
  explicitly scope it out of any task-agent disclosure design; the word "skill"
  overloads three unrelated concepts.

### D. Linked tasks & update graph

- **graph-2 — `get_related_task_details` drill-down is dead on three axes.**
  `[MEDIUM, confirmed]` `enabled: false`
  (`task_agent_tool_definitions.dart:402`, the only such tool) is filtered out by
  `_buildToolDefinitions().where((def) => def.enabled)`
  (`task_agent_context_builder.dart:510`); `allowedRelatedTaskIds` defaults to
  `const <String>{}` (`task_agent_strategy.dart:82`) and is never passed at the
  sole construction site (`task_agent_workflow.dart:605-632`), so even a
  hallucinated call is rejected; a registry test enshrines the disabled state.
  The full linked-task body lives only in `buildRelatedTaskDetailsJson` — i.e.
  the disabled tool. `README.md:50-53` and ADR 0003/0004 still describe it as
  live. **Mitigation (pick one, end-to-end):**
  - **(a) Re-enable:** flip `enabled: true`, populate `allowedRelatedTaskIds` at
    `task_agent_workflow.dart:605` from the sibling/linked-task id set already
    computed in `_buildLinkedTasksContextJson`, and update the registry test.
  - **(b) Delete:** remove the tool def, the strategy branch
    (`task_agent_strategy.dart:236-240`), `_handleRelatedTaskDetails`, the
    resolver wiring (`task_agent_workflow.dart:626-631`),
    `buildRelatedTaskDetailsJson`, and the README/ADR references.

  Either way the docs must be reconciled. **Recommendation:** if **graph-1** is
  left as read-time-only, lean toward **(a) re-enable** — without a cross-task
  wake, the on-demand drill-down is the agent's only path to fresher linked-task
  detail.

- **graph-1 (CORRECTED) — The cross-task update graph IS event-driven for user
  edits; agent-origin propagation is deliberately suppressed (this is the
  storm-prevention system).** `[finding's headline REFUTED; reframed as
  documentation gap]`

  The original finding claimed "no event-driven cross-task push." That is
  **wrong**, confirmed by tracing the real plumbing (and corroborated by the
  observed behavior: linked tasks visibly wake, and the project historically had
  A→B→A update storms that a system was built to stop). The actual mechanism:

  1. **Fan-out on every journal write** (`persistence_logic.dart:569-587`):
     editing entity X emits a notification set containing X's own ids, each
     `parentLinkedEntityIds(X)` (= `from_id WHERE to_id = X`, i.e. entries that
     link *to* X), and a `PROPAGATED::parentId` token per parent. A task→task
     link is stored `from_id = linker(B), to_id = linked(A)`, so editing **A**
     surfaces **B** as a parent → B is notified (raw + `PROPAGATED::B`).
  2. **Two routing branches** (`db_notification.dart:39-84`): `notify(ids)` (a
     **user** edit, `isAgentExecution == false`) emits on **both** `updateStream`
     and `localUpdateStream`; `notifyUiOnly(ids)` (an **agent** write inside the
     wake zone, `isAgentExecution == true`, `db_notification.dart:134-144`) emits
     on `updateStream` **only**.
  3. **The orchestrator listens on `localUpdateStream`**
     (`agent_providers.dart:386`). So a user edit of A reaches it and **wakes
     B's agent**; an agent's own write to A does **not**.
  4. **Direct vs propagated classification** (`wake_batch_router.dart:14-70`):
     pure-`PROPAGATED::` matches may defer to the next morning, but task-agent
     subscriptions set `deferPropagatedMatches: false`, so they **fast-drain**
     (120 s) on linked-task changes; project agents use the daily-digest defer.

  **What is genuinely (and intentionally) absent:** agent-authored **report
  prose** changes write only to `agent.sqlite` (`task_agent_workflow.dart:761-791`,
  no journal notification), and an agent's own journal writes (BLOCKED/ON HOLD,
  checklist toggles) use `notifyUiOnly` — so **agent→agent** propagation does not
  fire. This is the **storm-prevention design**, not a defect.

  **The multi-layer storm-prevention system** (the "system in place"):
  (1) agent-execution zone → `notifyUiOnly` breaks the A→B→A loop
  (`persistence_logic.dart:583-587`); (2) `PROPAGATED::` + `deferPropagatedMatches`
  daily-digest deferral (`wake_batch_router.dart`); (3) `WakeThrottleCoordinator`
  120 s coalescing window (`wake_throttle_coordinator.dart`); (4) self-mutation
  suppression via `recordMutatedEntities` / `_preRegisterSuppression` /
  `WakeSuppressionTracker` (`wake_orchestrator.dart:321-345`, ADR 0004 vector-clock
  capture); (5) single-flight drain + per-agent wake counters.

  **Mitigation (documentation — largely DONE):** the graph and its
  storm-prevention layers were under-documented relative to their importance.
  Captured in **[ADR 0027: Wake Notification Propagation and Storm
  Prevention](../adr/0027-wake-notification-propagation-and-storm-prevention.md)**
  (origin-routing model `notify`/`notifyUiOnly`/`fromSync`, the `agentExecutionZone`
  loop-breaker, the `parentLinkedEntityIds` + `PROPAGATED::` cross-entity fan-out,
  the direct-vs-propagated deferral split, and the five composed storm-prevention
  layers), with cross-links added from ADR 0002 and ADR 0003. Remaining: ensure
  `lib/features/agents/README.md` ("Wake Orchestration") points at ADR 0027 and is
  consistent with it. Optionally tell the model in the prompt that an agent-driven
  change on a linked task may not be reflected until that task is next user-touched
  or its agent next wakes. **Do not** add agent→agent report-head propagation — it
  would reintroduce exactly the storms layers (1)–(5) exist to prevent.

- **graph-3 — `linked_from`/`linked_to` emitted as bare JSON keys with no
  legend.** `[LOW, partial]` `task_agent_prompt_builder.dart:493-500` dumps raw
  JSON; the parallel non-agent skill prompts ship a legend
  (`preconfigured_prompts.dart:130-131`) but the task scaffold does not. No
  behavior currently keys off direction, so impact is prompt clarity, not
  correctness. **Mitigation:** add a one-line legend to a scaffold constant
  (stable prefix, cache-safe) mapping the existing keys. **Do not** rename the
  keys — `linked_from`/`linked_to` is the canonical app-wide journal contract.

- **graph-5 — Embedded summary can be silently empty/stale.** `[LOW, partial]`
  When no report resolves, the row omits the summary fields, so "no report" is
  indistinguishable from "no work" (`task_agent_context_builder.dart:297-330`);
  `createdAt` is emitted but the scaffold gives no instruction to weigh it.
  **Mitigation:** add a **static** `summaryStatus: 'none'` absence marker and a
  **static** scaffold sentence telling the model `latestTaskAgentReportCreatedAt`
  indicates age. **Explicitly reject** any `'stale'` flag derived from
  `createdAt`-vs-now — it would flip prefix bytes every wake (Invariant 1).

### E. Planner-pattern transfer

- **xfer-1 — One-agent-per-task boundary is correct.** `[confirmed]` The
  generalizable cross-task signal already lives template-side; do not transfer the
  single-identity model. _Validates the user's stated premise._
- **xfer-2 / xfer-3 — The one real gap: per-task, compaction-exempt,
  user-confirmed instructions.** `[LOW]` User behavioral corrections are recorded
  as ordinary observations (`task_agent_prompt_builder.dart:308-314`) that the
  verbatim critical-observation section caps at the most-recent-20 (`:574-576`),
  with no compaction-exempt path and **no recall tool on the task surface**
  (`search_memory` exists only on the day agent; `get_related_task_details` is
  disabled). The underlying observation entities are never deleted (a *surfacing*
  gap, not data loss). **Mitigation (cheapest-first):** raise/remove the 20-cap
  for critical observations and/or wire the already-built `searchLog` as a
  `search_memory` tool for task agents — **before** considering a new store. If a
  store is ever built, settle it at ADR 0023 Open Question 5 and do **not** port
  the scope/hook-index tiers.
- **xfer-4 — Proposal ledger already serves the action-shaped knowledge role.**
  Verdicts are durable, fingerprint-keyed, multi-device-convergent. Any new
  per-task store must cover only non-proposable free-text instructions; the ledger
  stays the source of truth for verdicts. (Nuance: ledger verdicts fold into
  summaries, so a free-text store, if built, must itself be compaction-exempt.)
- **xfer-5 — Do not port the slow weekly-promotion loop per-task.** The template
  slow loop (`FeedbackExtractionService.extract(templateId)`) is shared by all
  task agents on a template; reusing it for per-task durability would leak one
  task's preference onto every sibling. Use explicit `userStated` confirmation.
- **xfer-6 — Report non-re-injection is correct; preserve it.** Do not "fix"
  `task_agent_prompt_builder.dart:616-620` with a planner-style verbatim
  conclusion store. Confine any durability exemption to user-stated instructions.

---

## Recommended execution order

Each item is independently shippable. Effort is S/M/L; "worth it?" is the
verifier's judgement for short-lived per-wake task agents.

| # | Item(s) | Sev | Effort | Risk | Worth it? |
|---|---------|-----|--------|------|-----------|
| 0 | **Priority fix** — fail-closed entity-reference validation across all task-agent tools (reject hallucinated label/checklist/time-entry/timer ids; never surface a raw id; tell the model it invented the id) | **HIGH (user-visible)** | M | Low | **Yes** — observed bug; surfaces wrong suggestions to the user |
| 1 | **graph-2** — reconcile the dead drill-down (re-enable + wire allowlist, or delete end-to-end) + fix docs | MED | S (delete) / M (re-enable+test) | Low | **Yes** — hygiene/correctness defect regardless of lifetime |
| 2 | **asm-2** — move parent-project + linked-task JSON below `## Task Log`; drop `createdAt`; extend prefix test | MED | S | Low | **Yes** — removes a real prefix-cache contract violation; cost scales with linked-task count |
| 3 | **sp-1 + pd-3 + sp-3 (+ sp-2)** — salience-order trailing scaffold, state no-op once, dedup scaffold-vs-tool prose, add the single-use line | MED theme | M | Low | **Maybe** — dedup + single-use line are safe wins; broad reorder gain is unproven |
| 4 | **asm-4** — enrich `## Changed Since Last Wake` with diffs; dedup open-proposal rendering (compacted mode) | LOW | S–M | Low | **Maybe** — quality nicety; few/zero open proposals on most wakes |
| 5 | **graph-3 + graph-5** — `linked_from`/`linked_to` legend; static `summaryStatus:'none'` + `createdAt`-age sentence | LOW | S | Low | **Maybe** — clarity polish; avoid any `createdAt`-derived `stale` flag |
| 6 | **graph-1** — document the *actual* cross-task update graph + the 5-layer storm-prevention system. **DONE:** captured in [ADR 0027](../adr/0027-wake-notification-propagation-and-storm-prevention.md) (+ cross-links from ADR 0002/0003); remaining is a README pointer | LOW | S | None | **Yes** — done; corrects an under-documented strength |
| 7 | **asm-3** — orphan-tool-aware history trim; optional `maxHistorySize` from config | LOW | S | Low | **Maybe** — low-probability trigger; cheap insurance |
| 8 | **xfer-2 / xfer-3** — raise/remove the critical-observation 20-cap and/or wire `searchLog` as `search_memory` for task agents | LOW | S (cap/tool) / L (new store) | Low (cap/tool) | **Maybe** — only for long-lived tasks; measure first, do not build a store yet |

**Suggested PR grouping:** (1)+(2) as a "linked-task & prefix correctness" PR;
(3)+(part of 4) as a "scaffold salience & dedup" PR; (5)+(6) as a "linked-task
clarity & docs" PR; (7) and (8) standalone/optional.

## Explicitly NOT worth doing

- **A general progressive-disclosure / "skills" layer for task agents** (pd-1,
  pd-5, pd-6). The scaffold + const tool array are already cached; disclosure
  converts a free cache-read into an extra round-trip against `maxTurnsPerWake`.
- **Porting the planner's two-tier hook-index knowledge store** (pd-5, xfer-2).
  It bounds an *unbounded* corpus over a long-lived identity; a task has fixed
  surfaces, no scope tiers, and its only growing surface (the log) is already
  bounded by ADR 0017 compaction.
- **Reusing the template-scoped slow loop for per-task durable promotion**
  (xfer-5). `FeedbackExtractionService` aggregates across all instances of a
  template, so promotion would leak one task's preference onto every sibling.
- **Transferring the single-long-lived-identity model to tasks** (xfer-1). The
  one-agent-per-task boundary is correct and disables sibling-TLDR injection
  precisely to avoid context pollution.
- **A planner-style verbatim store of the agent's own inferred conclusions**
  (xfer-6). Re-injecting prior report prose is the exact feedback-loop bug the
  non-re-injection deliberately prevents.
- **Cross-task / agent→agent report-head propagation** (graph-1). A user-edit
  cross-task graph already exists and works; what is suppressed is *agent-origin*
  propagation, on purpose. Adding agent→agent push would reintroduce exactly the
  A→B→A storms the agent-execution-zone + propagated-deferral + throttle +
  self-mutation-suppression layers were built to prevent. Document the existing
  graph and its storm-prevention instead.
- **Renaming `linked_from`/`linked_to` JSON keys** (graph-3). Canonical app-wide
  journal contract; add a legend that maps the existing keys.
- **Conditionally including scaffold sections by task shape, or a body/appendix
  split** (sp-4). Either changes nothing or pushes per-wake-mutable bytes into
  the prefix and voids the cache.
- **Shrinking the scaffold for token count** (sp-5). It is byte-stable,
  content-addressed once, and prefix-cacheable; the real levers are attention
  dilution (sp-1) and dedup (pd-3).
- **A `createdAt`-derived `'stale'` flag in the linked-task block** (graph-5).
  Time-relative values in the stable prefix void the prefix cache every wake.

## Test impact

- **graph-2 (re-enable path):** the registry test asserting
  `get_related_task_details` is the only `enabled: false` tool must be updated; add
  a test asserting an advertised tool + a non-empty `allowedRelatedTaskIds`.
  **(delete path):** remove the corresponding strategy/handler tests.
- **asm-2:** extend the existing byte-identity prefix test to vary a neighbor's
  report between two wakes and assert the stable prefix (up to `## Task Log`) is
  unchanged — this both proves the fix and prevents regression.
- **asm-4 / graph-3 / graph-5:** assert the new rendering (diff text, legend,
  `summaryStatus:'none'`) and, for graph-5, assert no `createdAt`-derived value
  enters the pre-log region.
- **asm-3:** assert `_trimHistoryIfNeeded` never leaves a leading orphan `tool`
  message after a forced trim.
- **sp-* / pd-3:** prompt-shape assertions only; no behavioral test claims (the
  dilution benefit is unproven and must not be asserted as fact).

## Related

- Adversarial review provenance: 5 dimensions, 28 findings, 24 survived, 4
  refuted (run 2026-06-09).
- `lib/features/agents/README.md` (Memory model, linked-task context) — must be
  reconciled by items 1 and 6.
- [ADR 0003](../adr/0003-task-agent-linked-task-context-contract.md) — update for
  the drill-down reconciliation (item 1) and, alongside the README + ADR 0004,
  to document the actual cross-task update graph and storm-prevention layers
  (item 6). Storm-prevention plumbing:
  `lib/services/db_notification.dart` (`notify` vs `notifyUiOnly`,
  `agentExecutionZoneKey`, `PROPAGATED::`),
  `lib/logic/persistence_logic.dart:569-587` (`parentLinkedEntityIds` fan-out),
  `lib/features/agents/wake/{wake_orchestrator,wake_batch_router,wake_throttle_coordinator,wake_suppression_tracker}.dart`,
  `lib/features/agents/state/agent_providers.dart:386` (`localUpdateStream`
  subscription).
- Planner reference patterns:
  `lib/features/daily_os_next/agents/domain/planner_knowledge.dart`,
  `lib/features/daily_os_next/agents/service/day_agent_knowledge_service.dart`.
