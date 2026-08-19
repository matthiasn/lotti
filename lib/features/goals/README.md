# Goals

The deterministic core of **goal-driven agents**: the vocabulary a long-term
personal goal is written in, and the pure-Dart evaluation that decides — at
zero inference cost — whether the user is on track.

This feature is landing in phases (see the ADR cluster below). What exists
today:

- The **vocabulary lives in `lib/classes/`** (`goal_criterion.dart`,
  `goal_window.dart`, `goal_enums.dart`, `goal_progress_models.dart`) — the
  shared-vocabulary rule that lets the agent entity union embed these types
  without `features/agents` depending on a feature (the `day_plan.dart`
  precedent). The banner-nudge vocabulary moved out of this feature
  entirely in ADR 0059 and is now the kind-agnostic `nudge_models.dart`.
  `GoalCriterion.fromAutoCompleteRule` imports an existing habit rule as a
  goal seed.
- `evaluation/` — `GoalProgressEvaluator`, a pure fold over a
  `GoalSignalWindow` of daily aggregates, and `GoalTrackPolicy`, which turns
  attainment, pace, grace, and data coverage into a `GoalTrackStatus`.
  Quantitative and user-defined measurable leaves share the existing journal
  ingestion paths; category-time leaves reuse Insights attribution, support
  minimum/maximum hours and optional local time bands, and give Phase B the
  bounded raw session evidence needed to discuss timing patterns. Label-time
  leaves select tracked entries by stable label id across categories by
  default (with an optional category scope), aggregate their interval-unioned
  hours per local day, and expose bounded entry markdown to Phase B so it can
  reason about what the time contained rather than only its duration. Tracked-time
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
into those recomputed rows: Met/Improving/Mixed/Missed assessments are
append-only agent-log actions bound to the active spec version, with optional
notes and per-dimension ratings. Every day in the seven-day strip opens its own
reflection, past days included, and a recorded verdict decides that day's
colour in place of the measured state. The sheet arrives on a verdict derived
from the day's evidence, which the user can override.

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
payload-bearing `reply_to_user` action that the shared bounded chat projection
can display without exposing thoughts or tool bookkeeping. Each wake also
receives a token-bounded tail of the recent user/assistant exchange, and reply
rows link back to their durable source message. Startup maintenance, pre-wake
scans, and the goal wake router recover the oldest source message that still
has no reply across the complete durable conversation. A queued explicit chat
wake rechecks that its source remains unanswered before inference, so an
earlier cadence wake cannot make it process the same turn twice. Reply rows use
stable per-wake ids, so a transaction that commits before its deferred outbox
flush fails is recognized as complete instead of rerunning inference. A mixed
interactive tool batch is all-or-nothing: if any call is rejected, a later
accepted call to that same tool cannot hide it, and its optimistic reply and
sibling mutations are not published. The visible layer ships behind the
`enable_unified_goals` flag: procedural text banners (ADR 0058) on the day
and habits pages — rendered through the kind-agnostic banner substrate in
`lib/features/nudges/` since ADR 0059, with `ui/goal_banner_card.dart` as
the goal-owned surface — and the unified Goals tab (`ui/pages/`,
route root `/goals`)
with per-goal health at a glance, deterministic rolling-window progress,
proposal approval, goal creation/deletion, and durable conversation as a
pushed phone page or a non-modal desktop overlay drawer (the §4b detail
dashboard: full-width hero stack of This-week + timestamped Agent's read —
the read carrying the cost pills and automation controls — Habits and
Signals sections, and a goal-scoped completion-rate chart). Agent replies retain their Markdown
structure, while long replies start compact and can be expanded in place.
The detail grid follows each habit's authored day, rolling, week, or month
window and can record success, skip, miss, or clear on any day inside the
habit's active lifetime through the normal habit-completion path while the goal
remains active. Clear appends a latest completion with an empty outcome, so the
older same-day completion stack remains intact. Current and past edits wake the
  deterministic evaluator, mark the standing
  report out of date, and start a visible two-minute refresh countdown. Further
  edits join that countdown without postponing it. The shared agent controls let
  the user update immediately, skip the pending run once, or turn automatic
  report updates off, while future calendar cells remain read-only. The detail
  page leads with the standing report and this goal's active
banners directly under the goal definition, with the habit cards and charts
below. A habit card states one thing per row — identity and reading, then the
cadence against how far off the habit is, then the span, the days, and the
six-week reliability tail that closes it. Day tracks narrow their columns to
FIT the card (weekday captions shortening to one letter when squeezed) and
only pan when even the narrowest column overflows, so a fortnight no longer
opens with its first days cut off the left edge. A leading gutter is reserved
only where a value axis is actually drawn.
A completed day whose window target was not yet met renders as a lighter
partial-success wash with a full-strength inner dot (day states wear the
success family; the interactive teal stays tap-only), each square carries its
concrete date in tooltip and outcome-menu header, and a blank habit day with
a name-matching data observation recorded today offers a one-tap check-off.
On the detail page the banner CTA opens a one-tap logging sheet
(`GoalLogTodaySheet`) instead of navigating to the page it is on.
On phones a goal's own pages — detail, chat, and the create and edit wizards —
take the whole screen: the bottom navigation bar slides away, so the day
sheet's record button and the wizards' Continue band dock at the bottom edge
instead of sitting under it.
Asking the agent in chat to change its report — shorter, sectioned, less
repetitive — rewrites the standing report itself rather than only answering in
chat, and an explicit refusal to change it is respected.
Signal charts carry one legend entry per mark drawn, each with its threshold
as a quiet annotation, and tooltips name the day once above their values.
A dimension with no readings shows no plot rather than an empty frame, and the
hand-painted tracked-time bars have a value axis, a date row, a key, and a
tap-to-read value. Opening the Goals list or a goal page re-imports the health
signals that goal watches, so the cards are never a day behind the phone's
health store (see the health-freshness section of the concept; automatic
health-linked habit check-off is a separate, deliberate follow-up).
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
their evaluated date instead of presenting it as today's state. Standing
reports use separate evaluated-period, rolling, change, coverage, and action
slots that the app assembles into the visible summary. A structured current
action is shown only when its criterion id appears in deterministic
health-logging-needed guidance; a lagging rolling habit alone cannot create a
"do this today" action item.
Banner
freshness hashes only those model-facing window samples, so older backfills do
not invalidate copy that could not cite them. Goal Agents
list rows share one silhouette — reserved week-strip footprint, shared trend
chip, right-aligned data block on wide rows inside a centered reading-measure
column.

A **unified Goals page** is landing behind `enable_unified_goals` (Phase 1 of
the Habits + Goal Agents merge; `ui/pages/unified_goals_page.dart`, `/goals`
route in the Habits nav slot): one centered column carrying the reused
Done-today card and due/later/done/all filter tabs, one expanded card per goal
(`ui/unified/unified_goal_card.dart` — persona chip, four-pill status with the
recovery hint folded in, deterministic templated summary, the goal's habit
rows with one-tap quick-complete and "N of M this window" readings), a
"not in a goal" group for unclaimed habits, and the aggregate consistency
heatmap and completion-rate chart (whose dashed line is now labeled *Target*,
never "Goal", to avoid colliding with this entity). The four-pill vocabulary
and the criterion→habit-id join live in `ui/unified/unified_goal_status.dart`.
Goal-card rows count only real successes as done (goal criteria ignore
skips), and the page reads the category-unfiltered habit buckets so it never
inherits the Habits tab's hidden category filter. `GoalsLocation` is the
sole host of the detail, chat and wizard pages under `/goals/...`, built by
the plain path helpers in `ui/goal_routes.dart`. (The never-released Goal
Agents tab that hosted the same pages under `/agents/...` behind
`enable_agents_page` was removed after the unified surface landed.)
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
and its conversational persona. The goal name is an explicit labelled field on
the mapping step — derived from the selected habits' names (emoji-free),
falling back to the steps label or the intention text when no habit is
selected, until the user types their own — and reappears on the
confirmation step as the same field rendered read-only behind a pencil
affordance. Editing skips the intention page entirely: the statement is a
single-line field with the example pills at the top of the mapping page, so
the edit flow is two steps where creation is three, and the step indicator
reflects the count the user actually walks. The automatic step count
is an always-visible signal row rather than an intention-gated one, and an
intention that names a health capability (blood pressure, weight) arrives
with that signal pre-selected and seeded (130/80 mmHg, at-most), while a
habit that is nothing but a record of that reading — its whole name is the
reading's own words plus a measurement verb in the app's language, as in
"Measure blood pressure" — is demoted to an unchecked suggestion. A signal
the user deselects stays deselected across intention back-edits. Every signal is one kind of row in one signals card — provenance
icon, plain-language subtitle, targets on the row's secondary line (blood
pressure is a single row with paired systolic/diastolic inputs sharing one
direction) — grouped as the user's signals above a Suggested caption, with
the row order frozen per step entry so toggling never reorders under the
finger. Picked health and tracked-time signals seed sensible default
targets, a missing target errors inline on its own input and scrolls into
view, back-edits of the intention only add matched signals (never clearing
shaped targets, and a re-checked habit restores its remembered cadence), and
every signal is added through one multi-select picker (steps included). The
confirmation step leads with the agent's name and restates the goal as prose
in which only the signals carry emphasis. The same flow edits an active goal from its
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
beside active banners, and lifetime AI consumption uses the same governance
pill as Task Details. Invocation duration remains in attribution detail rather
than competing with goal status in the card footer. Banner visibility is snooze-first: the
prominent action offers 1, 3, 6, or 8 hours in context, while Dismiss for today
is the tertiary final choice and there is no direct X or swipe dismissal. Both
choices persist on the nudge, and provider deadlines plus app-resume checks
restore the exact banner after snooze expiry or the next local day even across
restarts. Every snooze and day dismissal appends its activation, local offset,
start, and requested return boundary; snoozes also preserve the selected or
exact duration. The FACTS renderer gives the agent bounded timing summaries so
repeated snooze-return and dismissal hours can inform future initial display
times without shifting a requested return across timezone or daylight-saving
boundaries. Chat can also snooze the current banner until any requested future time;
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

**Check-ins** are the free-form counterpart to the daily reflection: the user
telling the goal what is actually going on, in their own words, whenever it is
worth saying. Audio first — one tap into the shared recorder from the goal's
app-bar mic, its Check-ins header, or a banner whose CTA asks for one — with
"write instead" as the typed fallback. A check-in is an ordinary journal entry
linked to the goal, so it inherits sync, privacy, categories, export and
transcription rather than owning any of them, and the recording is saved
before it is transcribed so nothing is lost waiting for words. The one thing
this feature does own is asking for the transcript: the app-wide
post-recording automation gates on the linked subject's category, and a goal
has none — so a check-in calls the shared transcription skill itself once the
recorder hands back an entry, gated on the goal's automatic-updates switch.
When that switch is off the decline is recorded rather than skipped, so the
beat offers Retry instead of looking like it is still being transcribed. Tapping a beat
opens the journal entry behind it.

They appear as dated beats on the goal's timeline, which is the shared
`lib/widgets/timeline/` rail that Events uses, merged with the standing daily
reflections so both halves of "what I've said about this goal" read as one
story. The rail is the reflections' only surface — the dashboard renders no
separate history card — and each reflection is one tight row: the verdict
pill rides the beat header's trailing slot, the row itself reopens the day's
reflection sheet, and no provenance text is shown. A wide window renders the rail as a second column beside the dashboard
(the conversation drawer keeps overlaying both); a phone previews three beats
in a card after This week, with the full history at
`/goals/details/<id>/timeline`. The reflection sheet's note gained a voice row,
whose transcript is deliberately never merged into the typed note.

The agent reads a **compacted** form, never a transcript: on automatic report
wakes, each check-in is distilled into what happened, what the user committed
to, blockers, mood and asks. Interactive chat only reads summaries already on
disk, so a background compaction cannot delay a reply. Failed compactions write
a durable retry marker with bounded backoff and stop after three failed
attempts for the same source digest until the transcript changes. The recent
summaries ride into the wake through the
`userVoice` FACTS section under a token budget. Those words inform coaching and record
commitments; they never override deterministic criterion results. Checking in
marks the standing report stale rather than waking the agent per recording.

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
