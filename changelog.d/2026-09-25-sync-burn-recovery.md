### Fixed
- **Sync recovery keeps retrying an interrupted write's cancellation.** If the
  local sync queue cannot save the cancellation message, the counter now stays
  recoverable on the next startup or repair request instead of leaving other
  devices waiting for a change that never happened.
