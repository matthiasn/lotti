### Changed
- **Task agents no longer spend a run when nothing they read has changed.**
  Saving a running timer's note without editing it, re-saving a task, or any
  other write that leaves the task's content as it was used to start a full
  agent run two minutes later. An automatic update now first checks the task,
  its linked entries and links, the category brief and the agent's setup
  against the last completed run, and stops there when all of them match —
  before any model is called. "Update now" always runs.
