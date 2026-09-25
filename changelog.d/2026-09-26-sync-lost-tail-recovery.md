### Fixed
- **Sync can discover a missing final update automatically.** Devices periodically
  announce their latest settled counter so peers can request missing updates
  even when no later edit arrives. Recovery can retry older gaps while the
  originating device is available, without requiring an app restart.
