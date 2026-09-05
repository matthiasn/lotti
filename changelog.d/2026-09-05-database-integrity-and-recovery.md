### Added
- **A database integrity check in Settings → Advanced → Maintenance.** It
  verifies that the journal, sync, agent, editor and search files are sound and
  names any that are not.

### Fixed
- **A damaged database file no longer stops the app from starting.** When a
  database can no longer be read, the newest backup of it is restored
  automatically and the damaged file is kept alongside for support.
- **Queries no longer get slower as data outgrows stale planner statistics.**
  Each database refreshes its statistics when the app closes.
