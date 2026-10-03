### Security
- **A synced photo or recording can no longer point at a file outside Lotti's
  documents folder.** A path with `..` in it, received from another device, now
  stays inside the folder.
- **Events received before the newer device-trust check, but not yet applied,
  are fetched again and checked** when you update from an older version,
  instead of being applied as they were.
