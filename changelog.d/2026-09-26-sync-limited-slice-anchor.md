### Fixed
- **Sync could skip changes after a device had been away for a while.** When
  the server sent only the newest part of a room's history, the app could
  record its place past the part it had not received yet, so the missing
  changes were never fetched unless another device resent them. The app now
  keeps its place until it knows whether anything was skipped and has asked
  for it, without holding back the changes it did receive.
