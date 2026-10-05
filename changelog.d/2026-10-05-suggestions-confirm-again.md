### Fixed
- **Accepting an agent's suggestion failed every time.** Since 1.1.42,
  confirming a proposed change on a task showed "Failed to apply change" and
  left it pending. Suggestions can be accepted again, and when one does
  fail, the reason is now written to the app's error log.
