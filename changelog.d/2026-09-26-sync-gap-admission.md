### Fixed
- **New sync updates no longer hide an earlier gap in history.** Sync protects
  missing history before applying a newly arrived batch, even when Matrix
  delivers the new messages before reporting the gap.
