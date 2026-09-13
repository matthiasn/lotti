### Changed
- **The system health report can now say why transactions waited.** Slow
  statements are listed per database instead of merged across all of them,
  each is attributed to the code that issued it rather than to the shared
  transaction wrapper, and a statement that queued behind others shows how
  deep the queue was when it started. A failed agent wake is also logged with
  its kind and the workflow's own reason instead of a bare error type, so the
  report can tell a missing template from a network error.
