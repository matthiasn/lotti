### Fixed
- **A stray backslash no longer breaks a Lotti answer.** Some models write
  `\-` in front of list dashes. That made the whole answer unreadable and the
  question failed; the answer is now read with the backslash dropped.
- **A Lotti answer survives an action it cannot offer.** When the assistant
  proposed a change to something outside the current task — another task's
  entry, say — the whole answer was dropped and the chat showed an error.
  The answer is now shown with no change proposed.
