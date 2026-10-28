### Added
- **A running agent can be stopped from where you read it.** Its page, the
  agent internals panel and the conversation it is having now show a stop
  button while it runs, the same one the summary's read-aloud uses. The
  Conversations list marks which conversation is live, and one that was
  stopped reads *Stopped* afterwards. Before, the only way to stop a stuck
  run was the sidebar's wake queue.

### Fixed
- **Stopping an agent now stops its current answer, not only the next one.**
  A stopped agent used to keep streaming, and paying for, the answer it was in
  the middle of until the model finished on its own. It now breaks off at the
  next piece of the answer, and nothing from that half-written turn is applied.
