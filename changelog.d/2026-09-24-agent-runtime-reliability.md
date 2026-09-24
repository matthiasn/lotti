### Fixed
- **Agent updates you asked for could be lost when the app closed.** A wake
  that was still waiting — or still running — when the app was closed or
  killed was gone for good, so an agent could miss the change that should have
  woken it. The app now remembers every wake it owes and runs the unfinished
  ones the next time it starts.
- **Confirming a suggestion twice could apply it twice.** A quick double tap,
  or "Confirm all" racing a single confirm, could apply the same change twice —
  two time entries, two checklist items. Only the first confirmation now
  applies the change; the second one does nothing. Likewise, rejecting a
  suggestion at the moment it was being confirmed could show an applied
  change as rejected; whichever comes first now wins.
- **A suggestion could be applied again after it had already taken effect.**
  When a follow-up step failed after a confirmed change had been applied, the
  suggestion went back to pending, and confirming it again applied the change
  a second time. It now stays confirmed.
- **An agent could run twice at the same time after a cancelled or timed-out
  update.** The cancelled run kept working in the background while the next
  one started. The next update for that agent now waits for it to finish —
  for up to 30 minutes, after which a run that is still going is treated as
  stuck and no longer holds the agent back.
