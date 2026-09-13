### Fixed
- **Scheduled agent wakes could silently skip a scan after a relationship
  came due.** When the relationship agent armed a check-in reminder it nudged
  the wake scheduler from inside its own database write, and the scan that
  followed ran against a transaction that had already closed. Every
  maintenance step in that scan then failed at once and the due wake waited
  for the next hourly poll. The nudge now fires after the write has committed,
  and the scheduler runs every scan on its own footing so no caller can trip it
  this way again.

### Changed
- **The sync log no longer reports leftover sequence reservations as errors on
  every launch.** The start-up audit still records them, at informational
  level, so real sync failures are no longer buried under the same line
  repeated once per app start.
