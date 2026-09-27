### Changed
- **Backfill sync leads with the records on this device, and keeps them
  current.** The counts that tell you whether your devices hold the same data
  now sit at the top of the page, and update every second while the page is
  open instead of waiting for a refresh.

### Fixed
- **Backfill sync scrolls smoothly during a sync.** Every change to the
  incoming queue redrew the whole page, per-device statistics included, several
  times a second; now only the numbers that changed are redrawn.
