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

The LLM tier (Phase B) runs too: `workflow/` holds the lease-elected
escalation workflow, its code-owned contract, the tool dispatcher, and the
revision flow that turns an approved `propose_goal_revision` change set
into a new spec version. User-authored chat turns take the same fact-grounded
workflow through a throttle-bypassing manual wake: `GoalChatService` persists
the source turn before enqueueing, reconciles a committed message when a later
sync-outbox flush reports failure, and the workflow persists a sanitized answer as a
`reply_to_user` action that the shared bounded chat projection can display
without exposing thoughts or tool bookkeeping. Reply rows use stable per-wake
ids, so a transaction that commits before its deferred outbox flush fails is
recognized as complete instead of rerunning inference. The visible layer shipped behind the
`enable_agents_page` flag: procedural text banners (ADR 0058) on the day
and habits pages (`ui/goal_banner_*`), and an Agents tab (`ui/pages/`)
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
read-only. Metric strips preserve the evaluator's configured aggregation
rather than treating every daily contribution as a standalone target;
composite details retain every metric and measurable leaf that contributes to
health. Their compact cells combine accomplishment and rolling success: a day
is green when the rolling criterion was satisfied then, or when the authored
routine was fully completed on that day. Goal chat stays purpose-bound: unrelated
general-assistant requests are redirected to the goal rather than answered.
Habit-routine creation assigns the rolling-seven-day frequency independently
for every selected habit rather than applying one shared count.
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
language-independent authorization at persistence. A new at-risk goal receives its first banner
without waiting for a multi-day decline. The desktop banner tenant fills the
dock's available width.
Voice, paging beyond the newest fifty visible turns, search, and inline nudge
cards remain later conversation increments; the plan of record is
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
