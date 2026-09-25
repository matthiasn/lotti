### Fixed
- **Closing a task left its AI summary saying it was still in progress.** When
  you moved a task to Done, the task agent woke up, saw no reason to write a new
  summary and kept the old one. It had no way to tell that the status had
  changed since that summary was written. The agent now notices any status
  change since its last summary and always writes a fresh one.

### Changed
- **An out-of-date AI summary now says when it will refresh itself.** Next to
  "Out of date" on the task's summary card, "Next update in 1:30" shows when
  the automatic update will run, so a stale summary no longer looks abandoned.
