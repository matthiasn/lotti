### Fixed
- **Updates waiting for attachments can recover after a restart.** Sync now
  retrieves the exact referenced attachment when its earlier room event is
  missing from memory, preventing queued updates from remaining stuck behind
  the saved sync position.
