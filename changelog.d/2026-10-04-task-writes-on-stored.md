### Fixed
- **Starring a task or changing its category could undo what the agent had
  just done.** Starring, flagging or making a task private, changing its
  category or date, the location added to a new task and the agent assigning
  a label each saved the copy of the task they had read a moment earlier, so
  a status the agent set or a checklist added in that moment was put back
  without a conflict. Each now changes only its own field on the task as it
  is stored.
- **Resolving a sync conflict could undo a change made while the conflict
  screen was open.** The resolution was built from the versions the screen
  showed when it opened. If the entry changes on this device meanwhile, the
  resolution is no longer applied over it: the screen shows the difference
  again and says the entry changed.
