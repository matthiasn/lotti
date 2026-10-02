### Fixed
- **A sync message too large to send no longer holds up the queue, or takes
  other changes down with it.** Sync tried such a message ten times, although
  it could never fit, before marking it as failed. When it travelled in a
  batch with other changes, every change in that batch failed with it. A
  message that is too large now fails at once, and a batch that is too large
  goes out one change at a time, so only a change that cannot fit on its own
  is marked as failed in the outbox.
