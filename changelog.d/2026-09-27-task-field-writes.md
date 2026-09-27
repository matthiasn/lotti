### Fixed
- **A change to a task could quietly undo another change made a moment
  before.** When the task agent set a task's status, priority, title, estimate,
  due date or language while the task was open, and you then changed a
  different field — or the other way round, or a change arrived from another
  device just before — the earlier change was reverted on every device, with no
  conflict shown. Each change now touches only the field it sets, so both
  stick.
- **The task agent could overwrite a field you had just changed.** If you
  changed a field between the agent reading the task and writing its own
  change, the agent's older decision replaced yours. The agent now leaves a
  field alone when it has changed since it looked, and says so.
- **Statuses you set yourself were missing from a task's status history.**
  Only the agent's and the day planner's status changes were recorded, so the
  history — and what the agent reports about how the task moved — skipped
  yours. Resolving a sync conflict also dropped the statuses of the side you
  did not keep. Every status change is now recorded, and a resolution keeps
  both sides' history.
