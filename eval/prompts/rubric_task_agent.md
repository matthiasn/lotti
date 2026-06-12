# Rubric — Task Agent (`TaskAgentWorkflow`)

The task agent is a persistent assistant for **one** task. On each wake it
analyses the task's current state (status, priority, due date, estimate,
checklist, time entries, prior observations), optionally calls tools to propose
changes, records private observations, and **publishes a report**
(one-liner + TLDR + "✅ Achieved / 📌 Left to Do / 💡 Learnings").

Tools it may call (deferred = needs user confirmation):

- Metadata: `set_task_title`, `set_task_status`, `update_task_priority`,
  `update_task_due_date`, `update_task_estimate`, `set_task_language`,
  `assign_task_labels`.
- Checklist: `add_multiple_checklist_items`, `update_checklist_items`,
  `migrate_checklist_items`.
- Time: `create_time_entry`, `update_time_entry`, `update_running_timer`.
- Splitting: `create_follow_up_task` (+ `migrate_checklist_items`).
- Attention: `request_attention`, `resolve_attention_request`.
- Local: `update_report`, `record_observations`, `get_related_task_details`,
  `retract_suggestions`.

## goalAttainment anchors

- **5** — Moves the task forward exactly as the state warrants: surfaces the real
  next action, sets a sensible status/estimate when missing, breaks down vague
  work into a clean checklist, and the report's "Left to Do" matches reality.
- **3** — Reasonable but partial: does something useful but misses an obvious
  signal (e.g. ignores an overdue due date, or doesn't address the user's note).
- **1** — Does nothing useful, or acts against the state (re-adds completed
  checklist items, contradicts the task title/intent).

## quality anchors

- **5** — Every tool argument is valid and grounded in the task; no duplicate
  checklist items; `set_task_status` only to an agent-settable value
  (`OPEN`, `IN PROGRESS`, `GROOMED`, `BLOCKED`, `ON HOLD`); `update_task_estimate`
  `minutes` in `1..1440`; ≤ 3 labels added; report honest and in the task's
  language.
- **3** — Mostly correct with a minor flaw (slightly off estimate, a redundant
  no-op call that re-sets an unchanged value).
- **1** — Hallucinated checklist content/IDs, invalid status (`DONE`/`REJECTED`
  via `set_task_status`), out-of-range estimate, or a report that claims work it
  did not do.

## efficiency anchors

- **5** — Minimal tool calls for the change made; batched independent calls; no
  re-reading already-known context; token use modest for the profile.
- **3** — A couple of avoidable calls or some prompt bloat.
- **1** — Many redundant/no-op tool calls, repeated drill-downs, or token burn
  far beyond what the change justifies — especially damning on a **local**
  profile.

## Hard-fail triggers (force `pass: false`)

- Any hallucinated task/checklist reference.
- `set_task_status` to `DONE` or `REJECTED`.
- `update_task_estimate` outside `1..1440`.
- More than 3 labels assigned.
- No report published when the wake did substantive work.
