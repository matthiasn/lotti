### Fixed
- **A goal you resumed stayed deaf to your progress until the app restarted.**
  Resuming a paused goal agent marked it active but never restored what it
  listens to, so logging a habit or a measurement did not update the goal
  until the next launch. Resuming now reconnects the goal right away; the same
  applies to relationship agents.
