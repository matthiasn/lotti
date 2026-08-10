# Goal Agents — UI Design Brief

- Date: 2026-08-10 (revised same day: banner voice model, goal generality)
- Status: Brief for design (no implementation decisions locked)
- Audience: a designer picking up the whole feature surface, with no prior
  context on this codebase

## 1. What the feature is

One durable, mostly dormant **agent per goal**. You tell it a goal ("walk more",
"gym three times a week"). It watches the signals that goal depends on — habit
completions, step counts — and speaks to you through short, model-authored
**text banners** that appear where you already are. You can dismiss a banner,
rate it, tap into a conversation with the agent, and change the goal by talking
to it.

Two properties are load-bearing and shape everything below:

- **The banner is the agent's voice, not an alarm.** During an active period a
  goal generally *has* a current message: "start the week strong" on Monday
  morning, a nudge after a missed day, plain "you're at risk" language late in
  a bad week, celebration when the target lands. Escalation lives in the copy
  and tone — the banner's *presence* follows the rhythm of the period, not the
  presence of trouble. Dismissal always quiets the goal for the rest of the
  day, and that quiet is honoured absolutely.
- **No generated imagery.** An earlier design generated an illustration per
  nudge; that was removed on purpose (ADR 0058) because spending energy on
  decoration was indefensible. **All personality must come from typography,
  motion, colour and copy.** This is the central creative constraint of the
  brief, not a limitation to work around.

## 2. Honest state of things

The backend is substantially built and well tested: entity model, CRDT merge
rules, two-tier wake scheduling, LLM tier, revision flow. The UI is three
screens that were built to make the backend visible, never designed:

| Screen | File | Reality |
|---|---|---|
| Agents list | `lib/features/goals/ui/pages/agents_page.dart` | Flat cards: title, status chip, "55% of target", one-liner |
| Create goal | `lib/features/goals/ui/pages/create_goal_agent_page.dart` | Name, statement, segmented type picker, target, habit checkboxes |
| Goal detail | `lib/features/goals/ui/pages/goal_agent_detail_page.dart` | **Read-only.** Status, statement, banners, report, history |
| Banner | `lib/features/goals/ui/goal_banner_card.dart` | Accent bar, headline, tagline, CTA, goal name, star, X |

What does not exist at all:

- **No conversation.** The detail page shows a read-only log with no composer.
  "No conversations yet" is an empty log for a conversation there is no way to
  start. This is the single largest gap against the original concept.
- **No editing.** After creation the goal is immutable to its owner. You cannot
  rename it, change the target, change the window, or add/remove a watched
  habit. The only path to change is the agent proposing a revision you approve.
- **No lifecycle controls.** No pause, no resume, **no delete**. A goal you
  create is permanent.
- **No cost or energy visibility**, despite that being an explicit product
  promise ("what does my fitness agent cost per month" should be answerable).

Known UI defects in what does exist, worth not reproducing:

- The banner's CTA and goal-name row collide on phone (`Lace up now Expedition
  fitness` runs together, the goal name truncates) and strand mid-card on
  desktop.
- The CTA is coloured text with no affordance — it looks pressable and isn't;
  the whole card navigates instead.
- Two always-present icon buttons take roughly a third of phone width and force
  the headline to wrap; one of them disappears after rating, so the layout jumps.
- Accent presets are a 4px bar plus a barely-tinted fill — the "personality"
  the design is supposed to carry isn't visible.
- The detail page is one flat `ListView` with no grouping; history rows put
  status labels in a right-hand column that collides with wrapped headlines.

Current-state screenshots can be regenerated at phone and desktop sizes with
the `app-screenshots` skill. Images are never committed to this repo.

## 3. Vocabulary the design has to express

Status is being reworked in parallel (see §8). Habit goals are evaluated over
a **rolling window** — the trailing 7 days including today — never a calendar
quota. A calendar week has two dead zones where effort stops mattering: once
the target is arithmetically unreachable ("why walk on Saturday?") and once it
is already met ("done till Monday"). A rolling window has neither: every
action enters the window and counts for exactly seven days.

Two small numbers drive everything:

- **deficit** = target − successes-in-window. Because at most one success per
  day is creditable, the deficit IS the days-to-recovery: no state is ever
  more than `target` days from healthy. "Haven't walked in a week" means
  "three walking days from whole", not "this week is lost".
- **buffer** = when at target, days until the oldest success ages out — the
  internal direction signal that tells the agent *today* is worth mentioning.

**The voice speaks in events and time; the UI speaks in numbers.** Deficit
and buffer decide *when* the agent speaks and *how warmly* — they never enter
a sentence as state. Ledger-talk ("you're at three", "2 of 3", "keeps you at
three") assumes the reader tracks a running count against a threshold; nobody
does. What is natural is observation and recency: "you've walked three times
in the past week" (a trailing-week observation IS the rolling window, in
ordinary English), "it's been five days since a walk", "a walk today keeps
the momentum going". Counts as facts about what the user did are fine; counts
as position-against-target belong to the chip and the progress grid. When the
window slides and the count drops overnight, the grid shows a day slipping
off the edge — the explanation is visual, not verbal.

The health vocabulary the design expresses:

| State | Meaning | Copy register |
|---|---|---|
| **Healthy** | At rate (deficit 0, comfortable buffer) | celebrate / quiet confidence |
| **Aging out** | At rate, but the oldest success expires imminently | gentle nudge |
| **One away** | Deficit 1 | nudge — "one walk from whole" |
| **Behind** | Deficit 2 … target−1 | firmer — "two days of walks gets you back" |
| **Restarting** | Deficit = target (empty window) | **encourage** — a beginning, not a verdict |
| **Not enough data** | Signals too sparse to judge | honest silence |

Note the wrap-around: the *worst* state maps to the warmest register. There is
no configuration of the numbers in which action is pointless, so the banner
can always truthfully say "do it today and the number moves" — the property a
quota model structurally cannot provide. There is no "off track" state.

Chips and list labels use only the coarse states — Healthy / Behind /
Restarting / Not enough data. The finer gradations ("aging out", deficit
counts) drive copy and the progress grid, never labels: a chip that says
"Aging out" is the same mechanism-leak as a banner that explains it.

Deficit and buffer have **two consumers**: the health shown on chips and
lists, and the register the agent writes in. One source of truth, two voices.
Percentage-of-target is banned from surfaces: it is misleading mid-window and
implies failure while the user is fine. Show distance-to-healthy and
direction instead.

(Metric goals — average steps over a rolling week — already live in this
frame; this section brings habit routines into the same one.)

A second input runs alongside the rate: per-habit **reliability** — the
habit's success record over trailing periods. It decides which habit earns the
banner's attention (§5.D) and belongs in the progress visualisation too: a
long-reliable habit and a chronically failing one should not look the same,
even in the same week.

## 4. Which goals can this coach? (scope of generality)

Should the UX promise to monitor and improve **arbitrary** goals? Honest
answer: **arbitrary intentions in, observable contracts out.** People think in
intentions ("walk more", "get back in shape"), and the entry should accept them
in the user's own words. But an agent can only *coach* what it can *observe*,
and the design must keep that boundary legible instead of letting the agent
pretend. Four tiers:

1. **Signal-backed** (built today): habit completions, step counts, workouts,
   measurables. The coaching loop closes with zero user effort — the agent
   simply sees what happened. This is the core, and it should feel effortless.
2. **Composable**: the criterion model already supports composites
   (all-of / any-of / at-least-N) that the create form never exposes. The
   design should assume goal *shapes* grow over time, not hard-code two forms.
3. **Self-reported** (future, viable): goals observable only through the user
   saying so — "worked on the novel today". Viable once conversation exists,
   because a check-in answer becomes evidence. This is a *different UX
   contract*: the agent's knowledge is only as fresh as the last conversation,
   and the design must show that honestly ("last heard from you Tuesday")
   rather than displaying confident staleness.
4. **Unobservable**: "be more patient." No signal, no honest loop. The right
   UX is **honest refusal at creation time**: the agent states what it would
   need to watch and offers the nearest observable proxy — not acceptance
   followed by hallucinated coaching.

The recommended create flow follows from this: **intention first, mapping
second, confirmation third.** The user states the goal in their own words (the
statement is what the agent will later "speak"); the system maps it to
observable criteria and *shows the mapping* ("I'll watch: Morning walk and
Evening walk, three times each, Monday–Sunday"); the user confirms or adjusts.
The visible mapping step is where honesty lives — and long-term, that mapping
negotiation is the conversation surface's first real job.

## 5. Surfaces to design

Grouped by user job. Every surface needs phone and desktop, light and dark.

### A. Getting in

1. **First-run / feature explanation.** What a goal agent is, what it will do,
   what it will cost, before the first one exists. Currently a single line of
   text on an empty list.
2. **Agents list.** The home of the feature. Per goal: name, coarse health,
   direction of travel, whether it needs the user (pending proposal, unread
   message) — and an **executive summary**: the agent's standing one-liner,
   one plain sentence per goal. It obeys the same language law as banners
   (§3): events and time, never ledger states or percentages — "Three walks
   this past week; the gym's been quiet since Tuesday", not "55% of target".
   It is editorial, not exhaustive: it names the one thing that matters most
   right now, reliability-weighted like the banner. It must never contradict
   the chip beside it (both derive from the same facts) and it refreshes on
   the voice's rhythm — completions reflected promptly, misses at day close.
   (Wiring exists: the health projection already carries the report
   one-liner; what's new is the language law and the freshness contract.)
   Must scale from one goal to a dozen without becoming a wall. States: empty,
   one, many, loading, background refresh, error.

### B. Setting an intention

3. **Create a goal.** Today it is a database row in a form. It should feel
   like setting an intention, following §4: statement in the user's words →
   visible mapping to what will be watched → confirmation. Progressive
   disclosure for the mechanical parts (window, target, which habits count).
   Two goal shapes exist today and more will follow — the shape picker needs
   room to grow, and tier-4 goals need the honest-refusal path designed.
   **Counts are per habit**: gym 2× while morning exercises run 5× under the
   same goal. The criterion model already carries a target per habit leaf —
   the current form's single shared "times per week (each habit)" field is a
   flattening artifact, not a constraint. One rolling window per goal;
   per-habit counts within it. (Knock-on for §5.F: an agent-proposed cadence
   revision must name WHICH habit it retargets, and the approval card must
   show it — "Gym: 2× → 3×, others unchanged".)
4. **Edit a goal.** Same material, in an editing posture. Renaming,
   retargeting, changing the window, adding or removing watched habits. Needs
   to communicate that editing starts a new version of the goal rather than
   rewriting history.

### C. Living with it

5. **Goal detail.** The agent's home. Should answer, in order: how am I doing,
   what is the agent saying, what has it said before, what is it watching, and
   what can I do about it. Currently an undifferentiated list.
6. **Progress visualisation.** The most valuable missing piece. A habit-routine
   goal is naturally a small grid — habits × days, one cell per creditable day.
   A metric goal is a series against a target line. Both want to show direction
   and the period boundary, not just a fill percentage. History across periods
   matters too: this week versus the last several.
7. **Report.** The agent's standing write-up — a one-line summary plus a longer
   body. Needs a resting form that doesn't dominate and an expanded form.
8. **Timeline / history.** Past banners with their outcomes (dismissed, expired,
   retired, superseded), past reports, past goal versions. This is the durable
   record and should be browsable over years.

### D. The voice — banners

This is the product. It is what a user experiences day to day, and under the
voice model it is a **standing presence**, not an occasional alarm. The
canonical arc for a "3× per week (rolling)" goal:

| Moment | Numbers (internal) | Register | Copy shape |
|---|---|---|---|
| Empty window | deficit 3 | encourage | "Quiet week for walks — today's a good day to restart." |
| After a check-off | deficit 2, moving | celebrate/encourage | "Back out there. Keep it going tomorrow." |
| At rate | deficit 0 | quiet confidence | "Three walks this past week. That's the rhythm." |
| Oldest success expiring | deficit 0, buffer 0 | gentle nudge | "A walk today keeps the momentum going." |
| One short | deficit 1 | nudge | "It's been a few days — room for a walk today?" |
| Sustained streak | weeks at rate | celebrate | "Three steady weeks of walking." (weekly recap rhythm) |

The numbers column is internal — it selects the row, it never appears in the
words (§3: events and time in the voice, numbers in the UI). Every row can
truthfully imply "today's action matters" — there is no dead-week state.

The *current* banner supersedes the previous one — one standing message per
goal, refreshed at meaningful moments, never a pile of stale alarms. The
refresh rhythm is asymmetric: **a completion is acknowledged within seconds**
(the check-off → fresh-copy loop is the feature's best moment), **a miss is
judged only at day close** (a day isn't missed until it ends — and under the
rolling window a "miss" is really a success aging out, §3). Status is rolling,
but *ritual* keeps a weekly beat: a Monday kickoff and a weekly recap are
rhythm moments for the voice, not arithmetic boundaries.

**The arc is a skeleton, not a script.** The banner is an editorial product:
the agent says the *one most useful thing*, never an enumeration of everything
left to do. Which habit earns the mention is **reliability-weighted**: a habit
the user has hit for six straight weeks has earned silence until its pattern
actually breaks, while a habit that failed the last two weeks gets named on
Monday, by name, first. Dialogue reshapes it too — "I'm traveling until
Thursday" should change both the copy and the timing of what's worth saying.
(Per-habit trailing reliability is deterministically computable from persisted
per-period results; dialogue hooks arrive with the conversation surface.) A
Monday banner that lists nine sessions across three habits is a bug in voice,
even when every word of it is true.

9. **Banner card.** Content model: `headline` (always), `tagline` (optional),
   `cta` (optional), the goal's name, plus a dismiss and a rate affordance. The
   model also chooses presentation presets per banner:
   - **Tone**: encourage, nudge, roast, celebrate — the registers of the arc
     above. Default persona is "gently humorous, never shaming"; body-shaming
     and guilt are out of bounds by contract.
   - **Accent**: calm, ember, tide, neon, aurora — colour/energy families that
     should be visibly different from one another and map to design-system
     colours. The accents are energy, not status — so the **register should
     tint the default**: a celebrate/on-track banner reads green-family at a
     glance, before a word of it is read. Doing well deserves to be visible.
   - **Animation**: steady, typewriter, pulse, wave, marquee, glitch. A fixed,
     code-owned catalogue. Motion must respect reduced-motion settings and
     degrade where fragment shaders are unavailable (shaders are disabled on
     Linux). Cheesy is explicitly allowed — this is the one place the product
     gets to have fun.
10. **Placement: one rotating slot** (mechanics decided; surface set
    recommended, not yet ratified). The slot is a **single fixed-height region
    that cycles through all standing banners, ~15 seconds per tenure** — every
    goal's voice gets screen time, the region never grows, and the exposure
    metering that feeds the rating/reuse loop measures real tenure instead of
    stack position. **Surface (decided): a persistent bottom dock at shell
    level** — the "now playing" bar pattern. The voice is never buried in
    scroll content: the dock anchors at the bottom of the content region
    across the main working tabs (Tasks, Daily OS, Habits) with one shared
    rotation state. On desktop it sits beside — not under — the navigation
    sidebar, which keeps its full height. On mobile the exact position is
    **TBD**; the leading candidate is directly above the bottom navigation
    (mini-player position), and the design must resolve collisions with the
    keyboard (the dock yields while typing), snackbars, and FABs. When
    nothing is standing — everything dismissed, or nothing to say — the dock
    collapses entirely; the disappearance is itself the feedback that
    dismissal worked. The former in-content mounts (day page, habits page)
    are removed. The old Daily-OS + Habits pair was an artefact of the alarm
    era: it made the voice invisible to a tasks-first user and broke the
    acknowledgment loop. Exclusions: Settings, Logbook; goal detail keeps its
    own uncycled display. Dismissal removes the tenant globally. Named trade:
    the voice is present during work-mode task triage — bounded by register,
    cadence and one-swipe dismissal. Bonus: exposure metering simplifies and
    gets more honest — a docked tenant is visible whenever the app is
    foregrounded, so tenure ≈ real screen time, exactly what the rating/reuse
    loop needs. Rules: the cycle pauses on hover/touch/open rating sheet;
    freshly refreshed copy (a completion acknowledgment) jumps the queue;
    dismissal removes that goal from rotation for the day and advances
    immediately; dot indicators appear only with more than one tenant; a
    banner plays its animation preset once per tenure and settles — one layer
    of motion at a time, transition motion belongs to the slot. Goal detail
    still shows that goal's banner alone, uncycled. Reduced motion: crossfade
    transitions; whether auto-advance stops entirely is design's call
    (auto-advancing content is a WCAG pause/stop/hide concern).
11. **Dismiss.** Both an explicit control and swipe, on **any banner in any
    register — congratulations are as dismissible as criticism.** Dismissal
    quiets that goal for the rest of the day (statuses keep updating silently)
    and removes it from the rotation, advancing to the next tenant. The agent
    sees dismissal as a signal, but reads it by register: a dismissed roast may
    mean "too pushy"; a dismissed celebration means "seen it, thanks" and must
    not teach the agent to stop celebrating. The user should understand that
    something happened — without a nagging confirmation.
12. **Rating.** One rating opportunity per banner run, currently a modal sheet
    with five stars and a skip. It feeds which lines of copy get reused. It
    must be genuinely optional and never block dismissal.

### E. Conversation — entirely unbuilt

13. **Chat with the agent.** A durable, resumable conversation you return to,
    not a session. Message list projecting stored agent messages, composer,
    voice input (the app has a recorder-plus-transcription toolkit already),
    a waiting/thinking state while a turn runs, error and retry, and pagination
    for histories that will span years. Only user turns and the agent's replies
    are shown; internal reasoning, tool calls and summaries stay hidden.
14. **Entry points.** From a banner, from goal detail, from the list. Tapping a
    banner should land in the conversation about *that* nudge.
15. **In-conversation goal change.** When the agent proposes changing the goal,
    the proposal should appear inline as something approvable, with a clear
    before-and-after. Goal changes always require explicit approval — the agent
    never silently moves its own goalposts.
16. **Check-ins as evidence** (tier 3 of §4, future): the agent asks, the
    answer is recorded as progress evidence. The design should anticipate chat
    turns that *are* data entry, and staleness display when the agent hasn't
    heard from the user.

### F. Governance

17. **Revision approval.** Agent-proposed goal changes as a readable diff.
    Partially exists as a generic change-set card and looks like plumbing.
18. **Version history.** How the goal has evolved and who authored each version.
19. **Lifecycle.** Pause, resume, delete, with honest consequences (what happens
    to history, to banners, to the schedule).
20. **Cost and energy.** Per-goal spend and energy, surfaced without shame or
    alarm. Every inference is already attributed per agent; the figures are
    small (fractions of a cent per wake) and the design should make that
    reassuring rather than hidden.

## 6. Constraints

**Platform.** Flutter, one codebase. Phone (390×844) and desktop (1280×800 and
much wider) from the same widgets. Desktop is not a stretched phone — the
banner at 1280px currently has an enormous dead centre.

**Design system is mandatory.** Spacing, typography, colour, radii and elevation
come from tokens. Raw numbers in `EdgeInsets`/`SizedBox`, literal `fontSize` or
`fontWeight`, and one-off colours are not permitted. If a needed token doesn't
exist, that's a conversation, not a local constant. Both light and dark themes
are first-class.

**Localisation.** Every fixed label ships in eleven catalogues, informal
register (Romanian formal is the deliberate exception). **Agent-authored copy —
headline, tagline, CTA — is generated content and is never localised**, so the
design must hold text of unpredictable length and language, including long
German compounds, without collapsing.

**Accessibility.** Meaningful semantics on every interactive element, support for
large text scaling without truncation or overflow, adequate touch targets, and
reduced-motion honoured by every animation preset.

**Never flash established UI.** Background refreshes (sync, database
notifications) must preserve the last rendered content. Full-screen loading and
empty states are for genuine first loads and deliberate navigation only.

**Every surface needs its full state set**: first load, background refresh,
empty, error, offline/stale, and — because this is a synced multi-device app —
content that changes underneath the user while they are looking at it.

## 7. What good looks like

- A user can create, understand, correct, converse with, pause and delete a goal
  without ever hitting a dead end.
- The Monday banner feels like a coach showing up, not a system warning. Someone
  should be willing to screenshot one.
- Dismissal is respected instantly and visibly; the resulting quiet feels like
  being listened to.
- On a phone, the banner region is a guest, not an occupier — even when several
  goals are active.
- Nothing anywhere states a percentage that implies failure when the user is
  doing fine.
- The boundary of §4 stays legible: the user always knows what the agent can
  see, and the agent never speaks with confidence about things it cannot.

## 8. Being fixed in parallel — not design's problem

- Habit goals currently evaluate against a Mon–Sun calendar quota, computing
  attainment against the full week's target with no regard for elapsed time —
  a good Monday reports "at risk", every habit reads "behind", and a bad week
  ends in an "arithmetically impossible" dead zone that advises against
  exercising. Being replaced with the rolling-window deficit/buffer model of
  §3 (the create form's habit shape moves to rolling-7; calendar-scoped
  existing goals get migrated).
- Banner eligibility is currently gated on the status ladder and, for at-risk
  goals, on three weeks of declining attainment — so a banner cannot fire in a
  goal's first week at all. Being replaced by the voice model: a standing
  banner whose register follows deficit and buffer; the trouble-gating layer
  is deleted, not recalibrated.
- The agent is passed habit identifiers rather than habit names, so its reports
  say "Habit 1 / Habit 2 / Habit 3" instead of "Morning walk".
- A habit check-off used to sit behind the wake system's 120-second coalescing
  window before the agent even recomputed; signal wakes now dispatch
  immediately (fixed 2026-08-10), so design may assume the numbers react to a
  tap in seconds.

Design should assume these are correct: health is truthful and always
actionable, the agent speaks in the right register within seconds of a
completion, and it can name the things it is watching.

## 9. Open questions for design to answer

1. Does the agent have an identity — a name, a face, a voice — or is it an
   ambient property of the goal? This affects the banner, the list and the whole
   conversation surface.
2. ~~The multi-goal Monday~~ — answered: a single rotating slot, ~15s per
   tenure (§5.D.10). Remaining for design: the transition itself (slide vs
   crossfade), the dot affordance, rotation *order* (round-robin vs
   register-priority), and whether reduced-motion stops auto-advance.
   The surface is settled — a persistent bottom dock at shell level
   (§5.D.10); still TBD is the **mobile dock position** (above the bottom
   nav is the leading candidate) and its keyboard/snackbar/FAB choreography.
3. Copy refresh cadence is largely settled by an asymmetry: **completions are
   acknowledged immediately** (the check-off → fresh-copy loop, seconds not
   minutes, is the feature's best moment), while **misses are judged at day
   close** (a day isn't missed until it ends) and periods at their boundary.
   Bursts coalesce into one refresh; a dismissal's quiet window overrides
   everything until tomorrow. Still open for design: whether an *intra-day*
   miss-side nudge ("the evening is still yours") is welcome or intrusive.
4. How far can the roast register go visually before the app feels like it is
   mocking the user rather than teasing them?
5. Where does conversation live: a pushed page, a sheet, or a peer of the goal
   detail view?
6. Does dismissing a banner mean "not now", "not today", or "not this one,
   ever"? Today it means today. The design should make whichever answer we pick
   legible without a confirmation dialog.
7. How is a period boundary expressed? A week ending is the natural rhythm of
   the whole feature and currently appears nowhere in the UI.

## Related

- `docs/adr/0053-goal-driven-agents-per-goal-producers.md` — one agent per goal
- `docs/adr/0055-banner-nudge-attention-channel.md` — banners as the attention
  channel; dismissal is data; staleness is a contract (its "never chide
  succeeding users" gating is superseded by the voice model above, and its
  bounded-stack presentation by the rotating slot of §5.D.10)
- `docs/adr/0058-procedural-text-banners-no-generative-imagery.md` — why there
  are no generated images, and where personality is expected to come from
- `docs/implementation_plans/2026-08-08_goal_agents_design.md` — the original
  system design
- `docs/implementation_plans/2026-08-08_reusable_chat_interface_requirements.md`
  — chat requirements, written but never built
- `knowledge/features/goals.md` — runtime behaviour as built
