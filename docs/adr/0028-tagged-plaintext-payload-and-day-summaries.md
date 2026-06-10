# ADR 0028: Tagged Plaintext Planner Payload and Contemporaneous Day Summaries

## Status

Accepted (2026-06-10)

## Context

The long-lived Daily OS planner (ADR 0022) drafts one day at a time and was
blind to the surrounding days: it could not see that the user burned the
midnight oil all weekend (and should get a gentle Monday), that a planned gym
session was missed, or that a deadline lands in three days. The primary goal is
**sustainability, not throughput**; a hard secondary requirement is that
**weak local models must read the context well**.

Two structural problems stood in the way:

1. **The wake payload was one `jsonEncode`d document.** Every prose value —
   the compacted day log, knowledge statements — had its newlines escaped into
   run-on strings, the worst shape for weak local models.
2. **Compaction destroys the "why".** The deterministic facts of a day
   (planned vs recorded minutes) are derivable forever, but the agent's
   contemporaneous understanding of *why* a day went the way it did dissolves
   once the log folds (ADR 0017).

## Decision

1. **The payload converts from one JSON document to tagged plaintext
   sections** (`day_agent_prompt_sections.dart`). `<snake_case_tag>` sections
   keep what JSON provided — named sections, boundary integrity — while giving
   prose real newlines. Data-shaped, tool-facing content (attention claims
   with ids, capture corpus, drafting/refine baseline, observations, trigger
   tokens) stays JSON *inside* its tags so models copy ids verbatim into tool
   calls. Section order remains stable→volatile for prefix-cache reuse; the
   week-context sections sit after `knowledge_statements` and before the mode
   sections because the today-so-far line churns with tracked time.
   A single shared sanitizer neutralizes the full open/close tag vocabulary in
   every interpolation — including the JSON-kept sections, since `jsonEncode`
   does not escape `<`/`>` — and single-line interpolations collapse whitespace
   runs so multi-line values cannot fabricate structure.

2. **ADR 0020 v2 prompt records gain a `day-log-section` wrap kind.** The
   persisted wake record splices around the whole `<day_log>…</day_log>`
   section (head/tail split on section boundaries — the log is multi-line, so
   a single-line anchor no longer works). The legacy `json-day-log-line` wrap
   stays decodable so records persisted before the conversion still
   reconstruct for the history UI.

3. **`<recent_days>`: one paragraph per day over a rolling last-7-days
   lookback (plus the plan date), facts first, agent testimony second.**
   Facts are deterministic template rendering (`week_context.dart`, the single
   owner of all wording): per-category recorded-vs-planned minutes
   (integer-tenths arithmetic, never doubles), named block-level misses, plan
   status, capped lists with deterministic overflow markers. The testimony is
   the agent's **contemporaneous day summary**, rendered adjacent to the facts
   (self-auditing); facts never come from it, and on contradiction the facts
   line wins. **Day classification is anchored to the wall clock, not the
   wake's workspace day**: past days say "Missed:", today renders
   "(today so far)" / "Still planned:", and days after today render
   "(upcoming)" — never "Missed:" and never fake rest-day lines.
   `<week_ahead>` carries future days with plans plus claim deadlines within
   `[today, today+5)`.

4. **Day summaries are a keyed mutable register with first-write-wins
   concurrency — a deliberate amendment to ADR 0016 D3 / ADR 0018 D1.**
   `AgentDomainEntity.daySummary` (`day_agent_summary:<dayId>`) is agent
   testimony written at/near day close in the agent's own words for its own
   consumption. Within-window self-rewrites upsert the register in place
   (preserving `createdAt`); on **concurrent** versions the EARLIEST
   `createdAt` wins (`resolveConcurrentAgentEntityOverride`) — the most
   contemporaneous testimony is canonical, so a later stale-device write
   cannot silently replace it. A `createdAt` tie defers to the generic LWW +
   canonical-clock path.

5. **The `write_day_summary` window amends ADR 0022 D4.** The workspace-day
   tool guard rejects any tool call whose `dayId` differs from the wake's
   workspace. `write_day_summary` is the sole, ADR-governed exception: its
   window is anchored to the **wall clock, independent of the plan date** —
   `dayId ∈ {today, yesterday}`. Future days are rejected (a drafting-tomorrow
   wake must not write testimony for unhappened days); anything older than
   yesterday is rejected (stale-device wakes must not overwrite genuine
   testimony). If no wake lands inside a day's window, that day keeps a
   permanent hole — accepted; the seeded directive mitigates by instructing
   the agent to write a missing summary on any wake while writable.

6. **Day summaries are a new episodic tier — an amendment to ADR 0022 D9.**
   They are day-scoped agent testimony, compaction-exempt for now, and NOT
   preference memory: preferences still flow through the durable-knowledge
   gate. Compaction integration is deliberately deferred until a few weeks of
   real summaries exist (retention is unbounded meanwhile; the prompt renders
   only the lookback window). This explicitly acknowledges ADR 0022's "durable
   memory needs a contradiction/decay policy" consequence and defers it to the
   compaction-integration follow-up.

7. **Strict memory-channel partition** (seeded directive):
   `write_day_summary` is the SOLE channel for day retrospectives;
   `record_observations` is for forward-looking learnings/patterns ONLY,
   never day recaps — preventing the same content from being double-fed
   through both the day log and the recent-days section.

8. **Cost gating.** Week context builds only on wakes whose workspace came
   from day-carrying tokens (planning-day / drafting / refine / scheduled);
   capture-submitted wakes — the highest-frequency kind — skip the 8-day
   journal + links + claims load entirely. Recorded time resolves through the
   shared `recorded_time.dart` core (the same pairs the Actual timeline lane
   projects), and the per-day plan/summary lookups go through ONE chunked
   `getEntitiesByIds` call.

## Consequences

- Weak local models read prose with real newlines; ids stay copyable.
- The planner sees a week of planned-vs-actual and its own day notes, enabling
  sustainable planning; the "why" survives compaction.
- The facts-vs-testimony split is self-auditing and the facts line is
  authoritative on contradiction.

Accepted limitations (documented, not fixed):

- **Cold-start omission:** both sections are omitted independently when
  information-free — `recent_days` only when every lookback day has no plan,
  no summary, and zero recorded spans (a fresh install renders nothing
  instead of eight "Nothing recorded." lines), `week_ahead` when there are no
  future plans and no deadlines in the window.
- The `recent_days` today-so-far line churns with tracked time, costing prompt
  prefix cache on same-day re-wakes (user-accepted for wake cadence).
- A transient week-context load failure and genuine no-data are
  indistinguishable in the prompt (the failure is logged).
- Deadline coverage is gated by claim *visibility*
  (`getAttentionClaimsForWindow`): a claim whose `latestEnd` elapsed but whose
  deadline is ahead may be invisible, and at >200 claims the index ordering
  can truncate deadline-bearing claims.
- The facts line reflects *current* entity state: retroactive uncommit/edit
  changes a past day's line. Summaries are testimony, not caches — they are
  never regenerated on retroactive data changes.
- The summary id carries no agentId — the same latent identity-recreation
  hazard as `day_agent_plan:<dayId>`, precedented and accepted.
- A currently *running* timer is excluded from recorded time (its growing
  `dateTo` exists only in memory until stopped).
- Recorded spans bucket whole-duration by start day, diverging from the
  per-day timeline lane's containment window for midnight-spanning entries.

## Related

- ADR 0016 (state as log projection) — D3 amended by Decision 4.
- ADR 0017 (deterministic compaction) — summaries are compaction-exempt.
- ADR 0018 (convergent execution) — D1 amended by Decision 4.
- ADR 0020 (input capture / v2 prompt records) — wrap kind added.
- ADR 0022 (long-lived planner) — D4 and D9 amended.
- ADR 0023 (domain agents) — per-agreement quota fulfillment deliberately
  excluded here and deferred there.
