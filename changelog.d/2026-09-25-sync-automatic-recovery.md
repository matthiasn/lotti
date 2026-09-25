### Fixed
- **Sync recovers interrupted outgoing changes while the app stays open.**
  Temporary database or queue failures are retried automatically without
  waiting for a restart or a request from another device.
