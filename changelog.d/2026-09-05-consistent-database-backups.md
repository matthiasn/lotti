### Fixed
- **Database backups could miss your latest changes.** The copy taken before
  a database upgrade, and the one made when purging deleted entries, copied
  the database file alone — while SQLite may still be holding the most recent
  changes in its write-ahead log next to it. Backups are now taken as a
  consistent snapshot that includes everything committed, and the sync and
  agent databases get the same safety copy before their upgrades.
- **Resetting the sync or editor database from Maintenance now takes effect
  right away.** The reset used to remove the file underneath the running app,
  which kept writing to the removed file until the next restart and could
  replay stale sync state into the fresh database afterwards.
