### Fixed
- **Skip once no longer claims a task summary is up to date.** Skipping the
  countdown to a task agent's next automatic update used to flip its summary
  to "Up to date", even though the summary still missed the change that
  started the countdown. Skipping now saves only the run: the summary keeps
  reading "Out of date" until the next update or *Update now* refreshes it.

### Changed
- **Skip once now sits beside the countdown on the task's AI summary.** When
  a summary is out of date and an automatic update is about to run, *Skip
  once* appears next to "Update now · 1:30" on the card itself, so you can
  decline a paid run where it is announced instead of opening the agent
  internals first.
