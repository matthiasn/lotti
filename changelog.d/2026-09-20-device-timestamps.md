### Fixed

- **Timestamps follow your phone, not the app's language.** A phone set to a
  German region running Lotti in English showed `Sep 20, 2026 7:08 PM` where
  every other app on it writes `20.9.2026, 19:08`. Journal cards, the photo
  viewer, chat messages, AI attribution, sync conflicts and goal provenance
  now take the date order from the device's region and the clock from its own
  12/24-hour setting.
