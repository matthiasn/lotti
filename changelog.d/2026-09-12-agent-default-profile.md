### Added
- **Choose a default inference profile in AI Settings.** Agents without a
  configured route can use your selected profile on this device.

### Fixed
- **Relationship agents now honor the model chosen in their settings.**
  Missing configuration retries less often and resumes when a usable profile
  becomes available.
- **Reduce background agent work.** Wakes reuse prepared memory when no
  compaction is needed, deferred jobs avoid unnecessary queue checks, and
  project recommendations are retired once per replacement.
