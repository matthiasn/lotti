### Fixed
- **Sync preserves link and agent snapshots with missing version clocks.**
  These changes now travel separately so outgoing sync cannot discard a
  snapshot before the receiving device resolves it.
