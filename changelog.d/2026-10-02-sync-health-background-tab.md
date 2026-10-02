### Fixed
- **The Sync health page kept querying the database after you switched to
  another tab.** On desktop the page stays loaded in the background, and it
  went on re-counting every synced table once a second and re-reading the sync
  statistics every 30 seconds — for hours, competing with sync for the
  database. It now pauses while it is out of sight and refreshes as soon as
  you come back. While it is open, the record counts are re-read only for the
  types that actually changed.
