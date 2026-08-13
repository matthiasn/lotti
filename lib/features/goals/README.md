# Goals

The deterministic core of **goal-driven agents**: the vocabulary a long-term
personal goal is written in, and the pure-Dart evaluation that decides — at
zero inference cost — whether the user is on track.

This feature is landing in phases (see the ADR cluster below). What exists
today:

- The **vocabulary lives in `lib/classes/`** (`goal_criterion.dart`,
  `goal_window.dart`, `goal_enums.dart`, `goal_nudge_models.dart`,
  `goal_progress_models.dart`) — the shared-vocabulary rule that lets the
  agent entity union embed these types without `features/agents` depending
  on a feature (the `day_plan.dart` precedent).
  `GoalCriterion.fromAutoCompleteRule` imports an existing habit rule as a
  goal seed.
- `evaluation/` — `GoalProgressEvaluator`, a pure fold over a
  `GoalSignalWindow` of daily aggregates, and `GoalTrackPolicy`, which turns
  attainment, pace, grace, and data coverage into a `GoalTrackStatus`.
  Quantitative and user-defined measurable leaves share the existing journal
  ingestion paths; category-time leaves reuse Insights attribution, support
  minimum/maximum hours and optional local time bands, and give Phase B the
  bounded raw session evidence needed to discuss timing patterns. Tracked-time
  mutations mark the standing report out of date without waking the agent for
  every timer edit; the daily cadence consumes accumulated evidence into the
  deterministic progress register, while only a report-producing transition
  or Update now can clear the stale report. Update now first refreshes the
  deterministic register from the same evidence snapshot used for prose, and a
  report rendered while a watched timer is still running remains stale until a
  settled wake. Habit and measured-data observations remain immediate.
  Supported weight and blood-pressure levels also get a bounded 28-day trend
  projection:
  a favorable trajectory can be on-track while remaining explicitly unmet.
- `GoalSpecValidator` (in `lib/classes/goal_spec_validator.dart`, beside
  the vocabulary it validates) — the decode-boundary gate, invoked from
  `AgentDomainEntity.fromJson` so every path (Matrix sync, storage reads)
  passes it: raw-JSON checks (fractional counts a decode would silently
  truncate) plus structural checks (empty composites, unsatisfiable
  quotas, blank identifiers, duplicate criterion ids).

The deterministic runtime RUNS (Phase A of ADR 0054): `runtime/` holds the
per-tick executor (`GoalAgentPhaseA`) and startup maintenance, `sync/` the
synced-signal dispatcher, `service/` transactional goal creation, and
`state/` the providers that plug the `goal_agent` kind into the shared
agent runtime (merged in `app_bootstrap.dart`). Persistence entities live
on `AgentDomainEntity` (`goalSpecVersion`/`goalSpecHead`/`goalProgress`/
`goalNudge`) with `GoalSpecValidator` gating every decode path.
Each goal-progress period retains one `GoalCriterionProgress` result per stable
criterion id, so multi-dimensional goals remain accountable beneath the
composite health result. Subjective daily ratings are deliberately not written
into those recomputed rows: direct Met/Mixed/Missed assessments are append-only
agent-log actions bound to the active spec version, with optional notes and
per-dimension ratings. The detail page presents those reflections as a separate
history beside the measured evidence.

The LLM tier (Phase B) runs too: `workflow/` holds the lease-elected
escalation workflow, its code-owned contract, the tool dispatcher, and the
revision flow that turns an approved `propose_goal_revision_v2` change set
into a new spec version only while its originating immutable version is still
current. The versioned tool name is a mixed-client capability fence: older
clients cannot execute the newer base-version contract, while newer clients
retire legacy v1 proposals instead of applying them. User-authored chat turns
take the same fact-grounded
workflow through a throttle-bypassing manual wake: `GoalChatService` persists
the source turn only after rechecking that the goal identity is active, then
enqueues it; it reconciles a committed message when a later
sync-outbox flush reports failure, and the workflow persists a sanitized answer as a
`reply_to_user` action that the shared bounded chat projection can display
without exposing thoughts or tool bookkeeping. Reply rows use stable per-wake
ids, so a transaction that commits before its deferred outbox flush fails is
recognized as complete instead of rerunning inference. The visible layer shipped behind the
`enable_agents_page` flag: procedural text banners (ADR 0058) on the day
and habits pages (`ui/goal_banner_*`), and a Goal Agents tab (`ui/pages/`;
the `/agents` route path is unchanged)
with per-goal health at a glance, deterministic rolling-window progress,
proposal approval, goal creation/deletion, and durable conversation as a
pushed phone page or desktop peer pane. Agent replies retain their Markdown
structure, while long replies start compact and can be expanded in place.
The detail grid follows each habit's authored day, rolling, week, or month
window and can record success or a miss on any day inside the habit's active
lifetime through the normal habit-completion path while the goal remains active;
current and past edits wake the
deterministic evaluator and queue a standing-report refresh, with an Update now
fallback visible beside the report, while future calendar cells remain
read-only. The detail page leads with the standing report and this goal's active
banners directly under the goal definition, with the habit cards and charts
below. Rolling-seven-day rows keep their localized weekday labels glued
directly above the day squares in one shared horizontal scroller; desktop and
phone use the handoff's compact day-cell rhythm, while the
phone layout keeps each habit name and cadence together above its strip.
A completed day whose window target was not yet met renders as a lighter
partial-success wash with a full-strength inner dot (day states wear the
success family; the interactive teal stays tap-only), each square carries its
concrete date in tooltip and outcome-menu header, and a blank habit day with
a name-matching data observation recorded today offers a one-tap check-off.
On the detail page the banner CTA opens a one-tap logging sheet
(`GoalLogTodaySheet`) instead of navigating to the page it is on.
Blood-pressure and weight headers quote the latest reading while their
verdicts stay on the rolling-average target. When today's latest sample meets
its target, the card celebrates that today's logging is on target even if the
rolling average still needs recovery; an over-target rolling average remains
actionable when today has not been measured. Agent FACTS carry the newest 100
exact samples per supported health criterion plus total and omitted counts,
anchored to the same evaluation instant as the rolling aggregate. The latest
sample also carries today's completion state and its direction since the
previous sample, while a daily-action index keeps completed health logging
separate from rolling habits that remain behind. Delayed prior-day wakes name
their evaluated date instead of presenting it as today's state. Banner
freshness hashes only those model-facing window samples, so older backfills do
not invalidate copy that could not cite them. Goal Agents
list rows share one silhouette — reserved week-strip footprint, shared trend
chip, right-aligned data block on wide rows inside a centered reading-measure
column.
Typed dimension cards preserve the evaluator's configured aggregation
rather than treating every daily contribution as a standalone target;
composite details retain every metric and measurable leaf that contributes to
health, show the authored composite rule, and keep per-dimension evidence
visible when one source needs attention. Their compact cells combine
accomplishment and rolling success: a day
is green when the rolling criterion was satisfied then, or when the authored
routine was fully completed on that day. Goal creation now follows the designed
intention → observable mapping → confirmation flow. Each watched habit has its
own rolling-seven-day cadence, unobservable intentions receive an honest
refusal instead of a fictional measurement, and the user names both the goal
and its conversational persona. The same flow edits an active goal from its
detail menu. Owner edits preserve criterion identities where possible, retain
unsupported or out-of-range criterion trees read-only, keep already-authored
habit criteria when privacy hides them from the picker, and mint a new
immutable spec version before re-registering signals and waking the agent. A
stale editor returns to the refreshed goal instead of offering a retry that
cannot succeed. The mapping stage can add linked measurables with their own
rolling-week target, or add Weight and Blood pressure from the existing health
catalog. Blood pressure expands to separate systolic and diastolic targets;
each health leaf supports `at least` or `no more than`. Creation and owner
editing share these controls and can author `all`, `any`, or `at least N`
composites without flattening stable criterion ids. Goal chat stays
purpose-bound: unrelated general-assistant requests are redirected to the goal
rather than answered.
When a user message explicitly names a positive quantity and unit belonging to
a measurable linked to that goal, chat offers a review card rather than writing
silently. The user can edit estimated per-day splits, reject individual rows,
record the accepted rows through the normal measurement path, or dismiss the
offer durably. Recorded entries retain their source-message decision and agent
provenance, and the progress card marks them with a quill.
Weekly reliability is shown only for authored rolling-seven-day habits rather
than reinterpreting day, rolling-N, or calendar periods. Health and direction are separate signals, the standing report stays visible
beside active banners, and lifetime AI consumption plus compute time use the
same governance pills as Task Details; compute time is withheld when legacy
calls carry no recorded duration. Chat can also snooze the current banner
until any requested future time, when that exact banner returns automatically;
the just-committed snooze is suppressed locally while its durable projection
reloads. Dismissal cooldown applies to automatic banners only: a direct request
for a banner, a missing-banner report, or a short affirmative reply to the
agent's banner offer can create or re-run a banner immediately without the
follow-up wake retiring it, including positive or recovery copy when the goal
is not behind. Localized requests use the model's typed banner action as the
language-independent authorization at persistence. A new at-risk goal receives
its first banner without waiting for a multi-day decline. When an active banner
ages out — or its stamped evidence fingerprint no longer matches the current
derivation because new data arrived — while the goal still qualifies for
automatic copy, the next deterministic tick expires it and re-arms Phase B
for a replacement; healthy expiry remains model-free, and new evidence after
today's earlier tick also marks the standing report out of date. The desktop banner tenant fills the dock's available
width.
Voice input in the goal chat composer lets the user record, transcribe,
and fill the text field from speech. Paging beyond the newest fifty visible
turns, search, and inline nudge cards remain later conversation increments;
the plan of record is
`docs/implementation_plans/2026-08-08_goal_agents_design.md`.

Runtime map: [knowledge/features/goals.md](../../../knowledge/features/goals.md).

Decisions: ADRs
[0053](../../../docs/adr/0053-goal-driven-agents-per-goal-producers.md),
[0054](../../../docs/adr/0054-deterministic-first-two-tier-wakes.md),
[0055](../../../docs/adr/0055-banner-nudge-attention-channel.md),
[0056](../../../docs/adr/0056-need-to-know-visual-brief-boundary.md),
[0057](../../../docs/adr/0057-decade-scale-agent-memory.md),
[0058](../../../docs/adr/0058-procedural-text-banners-no-generative-imagery.md).
The runtime's knowledge concept is
[knowledge/features/goals.md](../../../knowledge/features/goals.md).
