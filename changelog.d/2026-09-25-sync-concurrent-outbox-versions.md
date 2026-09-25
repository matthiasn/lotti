### Fixed
- **Concurrent link and agent changes survive outgoing sync.** Changes from
  different devices now travel separately until the receiving device resolves
  them, preventing a delayed update from hiding another change from sync repair.
