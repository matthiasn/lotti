### Changed
- **Backfill sync is now Sync health, and leads with the records on this
  device.** The page has become the place to check that your devices hold the
  same data, so it is named for that. The record counts that answer it now
  sit at the top and update every second while the page is open, instead of
  waiting for a refresh.

### Fixed
- **Sync health scrolls smoothly during a sync.** Every change to the incoming
  queue redrew the whole page, per-device statistics included, several times a
  second; now only the numbers that changed are redrawn.
