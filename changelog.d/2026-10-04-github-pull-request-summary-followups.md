### Changed
- **Pull request summaries are written in the task's language**, whatever
  language the pull request itself is in.
- **Pull request summaries no longer appear in the journal feed.** They
  belong to their pull request: its details in the task show them. An
  outdated summary is removed once a new one is written, and a pull
  request's summaries go when it is unlinked.
- **A pull request without a summary says why**: automatic summaries are off
  for the task's category, no model is set up for its agent, the last
  attempt failed, or one is written at the next refresh.

### Fixed
- **A summary that failed is not asked for again on every refresh.**
  Automatic summaries wait an hour after a failure; Summarize still works
  right away.
