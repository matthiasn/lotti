### Fixed
- **Step counts stayed stuck on the phone's bedtime figure after a wearable
  synced its day overnight.** A band that uploads its step count once a day
  lands yesterday's final total after Lotti has already stored the phone's own
  count, and the dashboards never re-read yesterday — only a manual import did,
  and even that put a second row next to the stale one instead of replacing the
  day. Each day's steps, distance and flights are now stored as one entry that
  is updated in place whenever Apple Health or Health Connect reports a new
  total, and the background refresh re-reads the previous day as well, so the
  count on the dashboard and the daily step goal follow the latest figure in
  the health store.
