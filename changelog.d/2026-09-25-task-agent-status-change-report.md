### Fixed
- **Closing a task left its AI summary saying it was still in progress.** When
  you moved a task to Done, the task agent woke up, saw no reason to write a new
  summary and kept the old one. It had no way to tell that the status had
  changed since that summary was written. The agent now notices any status
  change since its last summary and always writes a fresh one.

### Changed
- **An out-of-date AI summary now says when it will refresh itself.** On the
  task's summary card, the update button next to "Out of date" now reads
  "Update now · 1:30" while an automatic update is pending, so a stale summary
  no longer looks abandoned. Tapping it still updates straight away.
