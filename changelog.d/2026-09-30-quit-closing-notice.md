### Changed
- **Quitting Lotti on the desktop now tells you it is closing.** Closing
  every database takes a few seconds, and in that time the window used to sit
  there as if it had frozen. It now dims and shows "Closing Lotti…" with a
  spinner until everything is saved, and it stops taking clicks and typing in
  the meantime. Pressing Cmd+Q again while it closes no longer risks cutting
  that saving short.
