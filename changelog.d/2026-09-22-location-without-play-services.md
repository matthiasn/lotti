### Changed
- **Android reads entry locations without Google Play Services.** Lotti now
  asks Android's own location service for the position of a new entry, so
  location recording also works on phones without Google's apps. Lotti no
  longer asks you to switch location services on when it starts: if they are
  off, a new entry falls back to an approximate location from your network,
  as it already did when permission was declined.
