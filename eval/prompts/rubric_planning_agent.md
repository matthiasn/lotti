# Rubric — Planning Agent (`DayAgentWorkflow`, the long-lived Daily OS planner)

The planner owns the day. On a wake it may: parse a capture transcript into items
(`parse_capture_to_items`), draft a full day plan of time blocks
(`draft_day_plan`), propose a diff to an existing plan (`propose_plan_diff` with
`move_block` / `add_block` / `drop_block`), record observations, and schedule its
next wake (`set_next_wake`). A day has a `capacityMinutes` budget (default 480),
energy bands, and a set of allowed categories.

User input arrives as `CaptureEntity.transcript` (e.g. *"Here is what I want to
achieve today…"*); trigger tokens (`drafting:<dayId>`, `capture_submitted:<id>`,
`refine:<dayId>`) say what kind of wake it is.

## goalAttainment anchors

- **5** — The plan/diff faithfully reflects the capture and the app state:
  the things the user said they want to do are scheduled (or surfaced as parsed
  items), deadlines and in-progress work are honoured, and the day respects
  energy bands and stated constraints (e.g. "no deep work before 10:00").
- **3** — Captures the gist but drops or misplaces something the user clearly
  asked for, or schedules around capacity awkwardly.
- **1** — Ignores the capture, plans unrelated work, or violates an explicit
  user constraint.

## quality anchors

- **5** — Σ block minutes ≤ `capacityMinutes`; no overlapping blocks; every block
  uses an allowed `categoryId` and references only real task IDs; parsed items
  have plausible confidence; the plan is internally consistent.
- **3** — Minor flaw: small over/under-allocation, or one weak category/confidence
  call.
- **1** — Over-capacity plan, overlapping blocks, blocks for unknown
  categories/tasks (hallucinated), or self-contradictory diff
  (drops a block it just added).

## efficiency anchors

- **5** — Reaches a good plan in few turns with tight token use; no redundant
  re-drafting; diffs are minimal (only changed blocks).
- **3** — Some avoidable turns or a larger-than-needed prompt.
- **1** — Re-drafts the whole plan when a small diff would do, repeats parsing,
  or burns tokens far beyond the day's complexity — especially on a **local**
  profile, where a tight context budget is the whole point.

## Hard-fail triggers (force `pass: false`)

- Scheduled minutes exceed `capacityMinutes`.
- Overlapping blocks.
- A block references a category not in `allowedCategoryIds`, or a task id absent
  from the app state.
- A non-empty capture that yields neither parsed items nor plan blocks.
