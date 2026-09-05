### Fixed
- **Agent updates perform less redundant database work.** Overlapping requests
  to clear the same cooldown now share a state read, while newly scheduled
  cooldowns and stale deadlines left on disk remain correctly handled.
