# Week Context — tagged-plaintext payload, planned-vs-actual day paragraphs, and contemporaneous day summaries for the Daily OS planner

Red-teamed 2026-06-10 by three adversarial review agents (codebase-correctness, architecture/memory, failure-modes); all confirmed findings folded in below.

## Context

The long-lived Daily OS planner (ADR 0022) drafts one day at a time and is blind to the surrounding days: it cannot see that the user burned the midnight oil all weekend (and should get a gentle Monday), that a planned gym session was missed, or that a deadline lands in three days. Primary goal (user-stated): **sustainability, not throughput**. Secondary driver (user-stated, hard requirement): **weak local models must read this well** — and the ideal outcome wins over implementation effort.

Final converged design (each point user-driven):

1. **The prompt payload converts from one JSON document to tagged plaintext sections.** Today `_buildUserMessage` (`day_agent_context_builder.dart:70`) `jsonEncode`s a map, newline-escaping all prose into run-on strings — the worst shape for weak local models. Tagged sections keep what JSON provided — named sections, boundary integrity — while giving prose real newlines. Data-shaped, tool-facing content (attention claims with ids, capture corpus, drafting baseline) stays JSON *inside* its tags (models copy ids into tool calls); prose sections become plain text.
2. **Rolling last-7-days lookback + 5-day lookahead** (moving target), NOT a calendar week. No week-start/region logic.
3. **`<recent_days>`: one paragraph per day, facts first, agent testimony second.** Facts: deterministic, template-rendered planned-vs-recorded minutes per category + named block-level misses + plan status. Testimony: the agent's **contemporaneous day summary**, written at/near day close in its own words for its own consumption — preserves the *why* that compaction destroys; never silently rewritten; facts never come from it; rendered adjacent to the facts (self-auditing).
4. **`<week_ahead>`**: future days that have plans, plus claim deadlines within 5 days.
5. **No session counting / noise floors in Dart**; no per-agreement quota section (→ ADR 0023 domain agents).
6. **Compaction integration deliberately deferred**: learn from a few weeks of real summaries first (user decision).

## Target rendered shape

```
<recent_days>
Sat Jun 7 — committed plan. Work: 10.2h recorded vs 6h planned (4.2h over). Missed: 'Gym session' (90m, Fitness), 'Do taxes' (1h, Admin). Total recorded: 10.2h.
Agent note: Client emergency ate the evening; gym and taxes dropped. User seemed drained.

Sun Jun 8 — no plan. Work: 9h recorded. Total recorded: 9h.

Wed Jun 10 (today so far) — committed plan. Work: 1.5h recorded of 5h planned. Still planned: 'Gym session' (90m, Fitness).
</recent_days>

<week_ahead>
Fri Jun 12 — draft plan: Work 4h.
Deadline: 'Submit report' due Fri Jun 12 17:00 (2h requested, Work).
</week_ahead>
```

## Rendering rules (deterministic; exact wording lives in ONE renderer)

- **Day-classification is anchored to wall-clock, not workspace** (red team): `today := localDay(clock.now())`. Day < today → past treatment ("Missed:"); day == today → "(today so far)" + "Still planned:"; day > today (possible: drafting-tomorrow wakes, morning pre-warm wakes carrying yesterday's dayId — `real_day_agent.dart:193-229`, `day_agent_workflow.dart:663-674`) → "(upcoming)" + "Still planned:", never "Missed:", and never fake "Nothing recorded." rest-day lines for days that haven't happened. Lookback span stays anchored to `localDay(planDate)`; days in the span strictly after `today` render as upcoming.
- One paragraph per day, blank-line separated, chronological; all 8 lookback days present (empty past day renders "Nothing recorded." — rest days are signal).
- Durations: integer math only — `tenths = (minutes * 10 + 30) ~/ 60`, rendered `${tenths ~/ 10}.${tenths % 10}h`; < 1h as "45m". Never format doubles (round-trip nondeterminism).
- Category *names* (resolver, raw-id fallback), sorted. Null-category recorded time renders as an "Uncategorized" bucket (precedent `actual_time_blocks_provider.dart:15-19`); uncategorized time never suppresses a real category's miss.
- **Caps with deterministic overflow markers** (weak-model token budget): max 6 categories per day by `max(planned, recorded)` + "+N more (X.Xh)"; max 5 named misses + "+N more missed"; max 10 deadline lines + "+N more".
- Block-level miss detection (past days only): non-dropped block whose `taskId` matched no recorded span that day; taskId-less block missed only if its category recorded zero that day. Title from `block.title`, category-name fallback.
- "Agent note:" appended only when a day summary exists, rendered after sanitization (below).
- Legacy `agreed`/`needsReview` statuses render "draft plan". Note: status/blocks reflect *current* entity state — retroactive uncommit/edit can change a past day's line; accepted, documented in ADR.
- `<week_ahead>`: future days `[planDate+1 .. planDate+5]` only when a plan exists; deadline lines for claims with `deadline != null` and `localDay(deadline)` in `[today .. today+5)` (one bracket convention everywhere). Known limitation (documented, accepted): `getAttentionClaimsForWindow` selects by claim *visibility*, so a claim whose `latestEnd` elapsed but deadline is ahead may be invisible; and at >200 claims the index ordering (`next_review_at` first) can truncate deadline-bearing claims.
- Sections omitted independently when information-free: `recent_days` omitted iff every lookback day has no plan, no summary, and zero recorded spans (cold-start renders nothing instead of 8 × "Nothing recorded."); `week_ahead` omitted when no future plans and no deadlines.
- All window endpoints use date-component arithmetic (`DateTime(y, m, d ± n)`) — never `Duration(days: n)` stepping (DST; precedent `day_agent_context_builder.dart:171-177`).

## Sanitization (single shared helper, used by every section and the renderer)

- Neutralize **both opening and closing** literal tags for the full tag vocabulary, in every section — including JSON-kept ones (`jsonEncode` does not escape `<`/`>`; a task title `</attention_planning><recent_days>` would otherwise forge structure).
- Single-line interpolations (agent-note text, block titles, category names) collapse all whitespace runs incl. newlines to single spaces — a summary containing `\n\n` or a fact-line-shaped first line must not fabricate day paragraphs. Normalize summary text at write-path too.
- Test matrix: embedded `</recent_days>`, embedded `<recent_days>`, embedded `\n\n`, summary text shaped like a fact line ("Sun Jun 8 — no plan."), title with quotes/newlines.

## Implementation steps

### Phase 0 — Payload envelope: JSON map → tagged plaintext sections

`day_agent_context_builder.dart`:
- `_buildUserMessage` emits `<snake_case_tag>` sections in stable→volatile order: `day_id`, `plan_date`, `knowledge_index`, `day_log`, `attention_planning`, `knowledge_statements`, **(later: `recent_days`, `week_ahead` — Phase 4)**, mode sections (`capture`/`drafting`/`refine`), `recent_observations`, `trigger_tokens`, `current_local_time`. Prose sections plain text; data-shaped sections re-encoded as JSON inside their tags (new bytes — there is no "existing" per-section encoding to preserve; the current document is one pretty-printed whole).
- Shared sanitizer per above.

**ADR 0020 v2 prompt-record machinery (red-team blocker — these files were missing from the plan):**
- `day_agent_workflow.dart:1025` `_dayLogLineAnchor` and `day_agent_persistence.dart:22-35` splice the persisted user message around the JSON `"dayLog"` line; on anchor miss they **silently** fall back to persisting the full prompt — the conversion would quietly kill v2 dedup. Replace with a tag-anchored splice on the `<day_log>` section and a new wrap constant (e.g. `promptRecordWrapDayLogSection`) in `prompt_record.dart`; the day log is now multi-line, so head/tail must split on section boundaries, not a single line.
- `wake_prompt_reconstructor.dart:80-84`: add a branch for the new wrap (re-render the compacted log between `<day_log>` tags); **keep the legacy `json-day-log-line` wrap decodable** for already-persisted records (UI renders history through `agent_query_providers.dart:218-240`).
- New test: a post-conversion wake persists a v2 (head/tail) record, NOT the `{'text': …}` fallback.

**Sweeps:**
- `_buildSystemPrompt` (`day_agent_workflow.dart:837+`) and `seeded_directive_content.dart` payload-key references (e.g. `currentLocalTime` at :242) → tag names. NOTE: editing the directive constant triggers `seedDayAgentCaptureReconcileDirective` re-versioning, so `agent_template_service_test.dart` fixture updates land **in Phase 0** (again in Phase 5).
- Tests: ~22 `jsonDecode(...lastUserMessage!)` sites across `day_agent_workflow_test.dart` (427–3272), the C1 cache-order tests (2980-3056, `keys.indexOf` → string `indexOf` on tags), prompt-record tests (`day_agent_workflow_test.dart:1240-1320`), `wake_prompt_reconstructor_test.dart`.

### Phase 1 — Shared recorded-time resolution: `lib/features/daily_os_next/logic/recorded_time.dart` (new)

The UI projection needs entry id / dateTo / title / linkedFrom that a bare span discards (red team), so the shared core resolves **pairs**, and each consumer projects:
- `class ResolvedTimeEntry { JournalEntity entry; JournalEntity? linkedFrom; String? categoryId; Duration duration; }`
- `List<ResolvedTimeEntry> resolveTimeEntries({entries, links, linkedFromById})` — deleted-skipping, `entryDuration > 0`, linked-from resolution (Task wins, RatingEntry skipped; `_resolveLinkedFrom` moves here).
- `actualTimeBlocksForEntries` consumes it for its TimeBlock projection; the `debugResolveLinkedFrom` test seam stays and delegates (its tests at `actual_time_blocks_provider_test.dart:337-422` stay green).
- Week context derives lightweight spans (`categoryId`, `start = entry.meta.dateFrom`, `duration`, `taskId`) from the same pairs.

### Phase 2 — Day summary entity + conflict rule

- Freezed variant `AgentDomainEntity.daySummary` (pattern: `plannerKnowledge`): id `day_agent_summary:<dayId>`, agentId, dayId, text, createdAt, updatedAt, deletedAt, vectorClock. `AgentEntityTypes.daySummary`. Compiler-enforced exhaustive maps (`agent_db_conversions.dart` deletedAt/type/createdAt/updatedAt; `agent_lww_timestamp.dart`) **plus the NON-enforced `entitySubtype` `mapOrNull` (`agent_db_conversions.dart:252-279`): add `daySummary: (e) => e.dayId` explicitly** (enables indexed type+subtype lookups). `make build_runner`. Synced via normal `syncService.upsertEntity`; generic sync/outbox/backfill handle unknown-union fallback already.
- **Conflict semantics (red team — plain LWW would silently replace testimony):** add a `daySummary` rule to `resolveConcurrentAgentEntityOverride` (`agent_concurrent_resolver.dart:77-95`): on concurrent vector clocks, **earliest `createdAt` wins** (the most contemporaneous testimony is canonical); tie → canonical clock comparison. Within-window self-rewrites (same device, sequential clocks) remain the only sanctioned mutation. Documented in the new ADR as a deliberate amendment to ADR 0016 D3 / ADR 0018 D1 (a keyed register for agent testimony, with first-write-wins concurrency, instead of append-only union).
- Retention: unbounded storage for now (prompt renders only 7); revisit with compaction integration — stated in ADR.

### Phase 3 — Week context domain + renderer + service + tool

**Domain** `lib/features/daily_os_next/agents/domain/week_context.dart` (pure, no codegen; reuse `localDay()`):
- Constants: lookback 7, lookahead 5, `daySummaryMaxChars = 500`.
- `WeekContext { String? recentDays; String? weekAhead; bool get isEmpty; }` (fully rendered section bodies).
- `buildWeekContext({required DateTime planDate, required DateTime now, required claims, required dayPlans, required daySummaries, required recordedSpans, required categoryName})` — explicit `now` parameter (testable; wall-clock classification per rendering rules).
- Recorded spans bucket by `localDay(span.start)` — entire duration to the start day; spans bucketing outside the day span are dropped. **Documented divergence** from the per-day timeline lane: the wide containment window includes midnight-spanning entries that no single-day window contains.

**Service** `lib/features/daily_os_next/agents/service/day_agent_week_context_service.dart`:
- `buildForDay({agentId, planDate})` (fail-soft null + `domainLogger.error`; accepted: transient error and no-data are indistinguishable in the prompt) and `executeTool(...)` for `write_day_summary`.
- **One chunked `getEntitiesByIds` call** (`agent_repository.dart:141-189`) for all 21 deterministic ids (13 plans + 8 summaries), split by prefix — NOT per-id `Future.wait` fan-out (documented production incident in the repo's own doc comment). Filter: correct type, `agentId` matches, `deletedAt == null`.
- Claims: `getAttentionClaimsForWindow(start: localDay(now), end: localDay(now)+5d)` (component arithmetic).
- Recorded: `journalDb.sortedCalendarEntries(rangeStart: DateTime(y,m,d-7 of planDate), rangeEnd: DateTime(y,m,d+1 of min(planDate, today)))` — **end-of-day, not `clock.now()`** (containment query `date_from >= start AND date_to <= end`, `database.drift:435-441`: a now-capped range drops entries finishing later today). Accepted + stated in scaffold: the currently *running* timer is excluded (its growing `dateTo` exists only in memory, `time_service.dart:28-38`).
- `categoryNameResolver` → `EntitiesCacheService.getCategoryById(...)?.name` (getIt-guarded), raw-id fallback; null → "Uncategorized".
- **Tool** `write_day_summary(dayId, text)`: window anchored to **wall clock, independent of planDate**: `dayId ∈ {localDay(now), localDay(now) − 1}`; everything else rejected — future days rejected (a drafting-tomorrow wake must not write testimony for unhappened days), 2-days-ago rejected (stale-device wakes must not overwrite genuine testimony). Text: reject > 500 chars; whitespace-normalized before persist. Upsert within window (same id). Permanent holes are accepted: if no wake occurs within the window, that day has no note forever (directive mitigates: write on *any* wake while in window).

**Tool registration (red team — string-keyed, NOT compiler-enforced):** add `writeDaySummary` to `day_agent_tool_names.dart` AND to a set folded into `workflowHandlerTools` (`day_agent_tool_names.dart:84-89`) — without set membership the model is offered a tool whose every call dies as unknown (`day_agent_workflow.dart:588-592`). Tool definition in `day_agent_tools.dart`. `_isToolEnabled` (`day_agent_workflow.dart:1027-1038`): explicit `weekContextService != null` branch (default is `true`!). System-prompt `toolLines` gating (854-861) is the third touchpoint.

### Phase 4 — Workflow integration + providers

- `DayAgentWorkflow`: optional ctor field `weekContextService`. **Gate context building to drafting / refine / planning-day / scheduled wakes — capture-submitted wakes (highest-frequency) skip it** (8-day journal query + links + claims per capture is unjustified for text-triage work).
- `_executeToolHandler`: `write_day_summary` validated and dispatched **before** the blanket dayId guard (`day_agent_workflow.dart:508-521`, runs unconditionally otherwise) — the carve-out is the service's now-anchored window, commented as the ADR-governed exception to ADR 0022 D4. The handler closure (333-339) needs no extra params (window uses `clock.now()` inside the service).
- `_buildUserMessage`: `<recent_days>` + `<week_ahead>` inserted **after `knowledge_statements`, before the mode sections** (red-team correction: the today-so-far line changes with tracked time, making these sections more volatile than knowledge statements — original placement would evict more prefix than claimed).
- System-prompt scaffold block gated on service presence: facts deterministic (recorded = truth excluding any still-running session; planned = intent; committed real, draft weak); plan sustainably after heavy stretches; respect week_ahead deadlines; `write_day_summary` rules (one paragraph ≤500 chars, what happened + why, agent-facing, today/yesterday only, don't restate the numbers).
- Providers: `dayAgentWeekContextService` (@Riverpod keepAlive) in `day_agent_providers.dart`; pass into `dayAgentWorkflow` (`agent_workflow_providers.dart:144`). `make build_runner`.

### Phase 5 — Seeded directive (channel partition)

- `dayAgentGeneralDirective`: read `<recent_days>` before drafting — sustainability over throughput. **Explicit memory-channel partition (red team — prevents double-feed):** `write_day_summary` is the SOLE channel for day retrospectives ("what happened and why"); `record_observations` is for forward-looking learnings/patterns ONLY, never day recaps — amend the existing observation guidance (`seeded_directive_content.dart:225`) accordingly. Write the missing summary on *any* wake while the day is still in the window. On contradiction, the facts line wins.
- `SeedDirectiveChange(date: '2026-06-10', kind: AgentTemplateKind.dayAgent, ...)`; re-versioning + fixture updates as in Phase 0.

## New ADR (required, not optional)

"Tagged plaintext planner payload and contemporaneous day summaries" — must explicitly:
- Amend **ADR 0022 D4** (the `write_day_summary` now-anchored two-day window as the sole exception to workspace-day tool rejection).
- Amend **ADR 0022 D9** (day summaries are a new episodic tier: day-scoped agent testimony, compaction-exempt for now, NOT preference memory — preferences still flow through the weekly gate / durable knowledge; retention/decay deferred to the compaction-integration follow-up, explicitly acknowledging 0022's "durable memory needs a contradiction/decay policy" consequence).
- Amend **ADR 0016 D3 / ADR 0018 D1** (a keyed mutable register for testimony with earliest-createdAt-wins concurrency, instead of append-only union / Version-Head).
- Record: ADR 0020 wrap-kind addition; facts-line reflects current (not historical) plan state; id carries no agentId (same latent identity-recreation hazard as `day_agent_plan:<dayId>`, precedented and accepted); cold-start omission; visibility-gated deadline coverage.

## Tests

- `recorded_time_test.dart` — pair resolution; existing actual-blocks tests green via delegating seam.
- `week_context_test.dart` (pure, fixed `now`) — verbatim section assertions for every phrasing case; **planDate = tomorrow and planDate = yesterday matrices** (no "Missed" for unhappened days, "(upcoming)" labels, no fake rest days); midnight-spanning span bucketing; caps + overflow markers; integer-tenths formatting (135m → "2.3h", 627m → "10.5h"); Uncategorized bucket + miss-suppression rule; sanitizer matrix (open/close tags, `\n\n`, fact-line-shaped note); deadline brackets; cold-start `isEmpty`; DST span.
- `day_agent_week_context_service_test.dart` — single `getEntitiesByIds` call with all 21 ids; recorded query end-of-day bounds; window enforcement matrix for the tool (today ok, yesterday ok, 2-days-ago rejected, tomorrow rejected, **midnight-straddle**: validated against injected clock); char budget; whitespace normalization; fail-soft.
- `day_agent_workflow_test.dart` — bench gains `MockDayAgentWeekContextService`; tag order `attention_planning < knowledge_statements < recent_days < week_ahead < mode`; absence on null/empty/throw; capture wakes do NOT build week context; summary tool bypasses blanket guard only via service window; Phase 0 rewrites (22 jsonDecode sites, C1 ordering, prompt-record v2 anchor tests).
- `wake_prompt_reconstructor_test.dart` — new wrap kind round-trip + legacy wrap still decodes.
- Entity conversion tests — `daySummary` round-trip incl. `entitySubtype = dayId`; concurrent-resolver test (earliest createdAt wins).
- `test/mocks/mocks.dart`: `MockDayAgentWeekContextService`.

## Docs & changelog

- `lib/features/daily_os_next/README.md`: payload format section rewritten (tags, order, sanitization, JSON-inside-tags rationale, prompt-record wrap change); "Week Context & Day Summaries" subsection (facts-vs-testimony, wall-clock classification, channel partition, caps).
- New ADR as above. CHANGELOG `## [0.9.1018]` + flatpak metainfo: planner sees the last week's planned-vs-actual (missed sessions, overworked stretches), keeps short day notes, plans sustainably. Envelope conversion: invisible, no entry. No l10n.

## Execution order

1. Phase 0 (envelope + prompt-record wrap + sweeps + test rewrites) → analyze zero issues, format, workflow + reconstructor + template-service tests green. Manual verification: run app, trigger a drafting wake, inspect logged prompt (weak-local-model legibility check).
2. Phase 1 → green. 3. Phase 2 (+ build_runner, conversion + resolver tests) → green. 4. Phase 3 (domain+service+tool tests) → green. 5. Phase 4 (+ build_runner) → green. 6. Phase 5 → green.
7. ADR + README + CHANGELOG + metainfo; final full-project analyze (zero warnings), format, all touched suites via dart-mcp.

## Accepted risks (documented, not fixed)

- Prompt-cache: recent_days churns with today's tracked time (user-accepted for wake cadence).
- Transient-failure vs no-data indistinguishable in prompt (logged).
- Deadline coverage gated by claim visibility; >200-claim truncation bias.
- Permanent summary holes when no wake lands in a day's window.
- Facts line reflects current entity state for retroactively edited past days.
- Summary id without agentId (identity-recreation hazard, precedented by day plans).

## Out of scope (deliberate)

- Compaction integration of day summaries (learn first — user decision).
- Per-agreement quota fulfillment → ADR 0023 domain agents.
- Regenerating summaries on retroactive data changes (testimony, not cache).
- Habit-completion evidence; calendar-derived capacity; live-timer inclusion.
