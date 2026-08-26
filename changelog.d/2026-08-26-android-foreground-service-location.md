### Changed
- **Lotti on Android no longer asks for the foreground location service
  permission.** A location library declared it for a background-tracking mode
  the app never uses; Lotti only reads your position once, when you save an
  entry, and only if you switched that on. The permission is gone from the
  app's manifest.
