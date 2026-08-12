# Goal Agents — Delivery Roadmap

- Date: 2026-08-11
- Status: Living tracker — update the status columns as PRs land
- Purpose: the single source of truth for *what we are building* and *how far
  along it is*. The vision lives in the design brief; the architecture lives in
  the kickoff plan and the ADRs; this doc maps those onto shippable increments
  and their real status, so progress is judged against a target rather than a
  task list.

## The target, in five lines

One durable, mostly-dormant **agent per goal**. You tell it a goal; it watches
the signals that goal depends on (habit completions, step counts) and speaks
through short, model-authored **text banners** where you already are. You can
**dismiss** a banner, **rate** it, **tap into a conversation** with the agent,
and **change the goal by talking to it**. Full vision:
[2026-08-10_goal_agents_ui_design_brief.md](2026-08-10_goal_agents_ui_design_brief.md).

Load-bearing properties (do not erode):

- **The banner is the agent's voice, not an alarm.** Its *presence* follows the
  rhythm of the period; escalation lives in copy and tone. Dismissal quiets the
  goal for the rest of the day, absolutely.
- **No generated imagery** (ADR 0058). All personality comes from typography,
  motion, colour and copy.
- **Goals are arbitrary**, not a fixed menu — the criteria tree is general.

## How to read the status

`shipped` = merged to `main` (behind the `enable_agents_page` flag) ·
`in review` = PR open · `started` = branch exists, not PR'd · `todo` = not begun.
Everything ships behind `enable_agents_page` (default **off**) until the loop is
whole.

## Foundation / backend

| # | Increment | Status | PR |
|---|---|---|---|
| F1 | Kickoff — decisions, deterministic core, eval-first harness | shipped | #3857 |
| F2 | Goal entities, spec validator, procedural text banners (ADR 0058) | shipped | #3859 |
| F3 | Phase A — deterministic headless runtime (+ hardening) | shipped | #3861, #3862 |
| F4 | Phase B — lease-elected LLM tier | shipped | #3863 |
| F5 | Revision flow — approving a proposal mints the spec | shipped | #3871 |
| F6 | Wake immediacy — signal wakes drain now, no 120 s throttle | shipped | #3876 |
| F7 | Rolling 7-day habit window + days-to-recover / buffer, surfaced | shipped | #3881 |

The deterministic tier, CRDT merge rules, two-tier wake scheduling, the LLM
tier and the revision flow are built and tested. ADRs 0053–0058 record the
decisions.

## UI surfaces (the design increments)

| WP | Surface | Target | Status | PR |
|---|---|---|---|---|
| WP1 | Banner card | Register-tinted accent, persona chip, one CTA pill, X | shipped | #3877 |
| WP2 | Shell dock | One 15 s rotating slot at shell level; collapses when silent | shipped | #3877 |
| WP3 | Agents list | Executive rows: coarse-health chip, trend arrow, one-liner, needs-you badge; first-run explainer | shipped | #3879, #3880 |
| WP4 | Goal detail + **progress grid** | Grouped detail; the per-day window grid/strip (`GoalDayCell`) | **todo** | — |
| WP5 | **Create / edit flow** | Designed intention → mapping → confirm; **and editing** an existing goal | **todo** | — |
| WP6 | **Conversation surface** | A real composer over the durable log — *the single largest gap* | **todo** | — |

Notes:

- The current **create** screen is the dogfooding form, not the WP5 design.
- The current **detail** page is read-only (F5's approval card, banners,
  history) — no grid, no composer, no edit.
- WP4 re-adds the `GoalDayCell` pipeline that #3881 deliberately removed as
  unused; WP4 is its real consumer.

## Lifecycle & cross-cutting

| Item | Target | Status | PR |
|---|---|---|---|
| Delete a goal | Confirmed destroy from the detail page | in review | #3882 |
| Pause / resume | Suspend a goal's waking without deleting it | todo | — |
| Editing | Rename, retarget, change window, add/remove watched habit (owner-initiated, not only agent-proposed) | todo | — |
| Cost / energy visibility | "What does my fitness agent cost per month" answerable per goal | todo | — |

## Closing the loop — demoability

This is the work that makes the feature *feel* real, and the reason it currently
reads as "far from target" even though a lot is merged. None of it is large; all
of it is load-bearing for dogfooding.

1. **Nothing shows without data or a wake.** A goal has no register (hence no
   chip detail, no hint) until Phase A runs — on creation (`enqueueManualWake`),
   a watched-habit check-off, or the 06:00 cadence tick. Old goals created before
   #3881 are calendar-window, so they show *no* rolling hint or trend arrow at
   all. → **A manual "Refresh now" affordance** on the detail page (runs Phase A
   on demand) is `started` on `feat/goal_agent_refresh`; it doubles as a
   diagnostic for the wake→register→row chain.
2. **Getting a banner to appear is the deep end.** Banners are Phase B (LLM)
   output: they need an AI provider configured, a goal in a state that escalates,
   and Phase B choosing to speak. There is no non-LLM path to see the dock
   populated. → We need either a **seeding/preview affordance** (dev) or a
   documented end-to-end recipe (configure model → off-track goal → escalate).
3. **The flag is off by default.** Fine while the loop is incomplete; flip when
   WP4–WP6 + lifecycle make it a coherent experience.

## Design divergences already locked in (do not revert)

- Accent/label text binds to `text.highEmphasis`, not raw accent (raw accent
  fails 4.5:1 over light washes); coarse-health and needs-you chips use the DS
  `ink`/high-emphasis foreground over a hue wash.
- Tap targets are 48 dp (`TapTargets.minimum`).
- The list shows a coarse chip, never a raw percentage; a report one-liner is
  the agent's own prose (no widget-level content policing).
- Trend arrow is withheld unless two same-spec, non-deleted registers exist and
  the goal's windows are rolling (calendar windows reset each period).

## Recommended sequencing

1. **Close the loop first** (small, unblocks everything): land delete (#3882),
   land the refresh affordance, and pick the banner-visibility path (2 above).
   After this, the feature is *inspectable* end to end.
2. **WP4 — detail + progress grid.** Highest-value visible surface; consumes the
   `GoalDayCell` pipeline.
3. **WP6 — conversation.** The single largest gap against the concept; larger,
   and depends on the reusable chat interface requirements.
4. **WP5 — designed create/edit + owner editing.** Replaces the dogfooding form
   and adds the missing edit paths.
5. **Cost visibility** and **pause/resume** as the experience matures.

## Links

- Vision: [2026-08-10_goal_agents_ui_design_brief.md](2026-08-10_goal_agents_ui_design_brief.md)
- Architecture: [2026-08-08_goal_agents_kickoff_plan.md](2026-08-08_goal_agents_kickoff_plan.md),
  [2026-08-08_goal_agents_design.md](2026-08-08_goal_agents_design.md)
- Assessment: [2026-08-08_goal_agents_phase1_assessment.md](2026-08-08_goal_agents_phase1_assessment.md)
- Decisions: ADRs 0053–0058
- Current-state map: [knowledge/features/goals.md](../../knowledge/features/goals.md)
