### Changed
- **Agent status refreshes use less database work.** Latest-state and report
  lookups now check for newer records directly, reducing work when refreshing
  many agents.
