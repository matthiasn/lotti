### Fixed
- **An agent's summary read "Up to date" while it was still being rewritten.**
  The moment an update started — from the countdown or from *Update now* —
  the status on the task and goal agent cards flipped to "Up to date", with
  "Thinking…" spinning right beside it and the old summary still on screen.
  The status now stays "Out of date" for as long as the update runs, and only
  changes once the new summary has actually landed. A failed update leaves it
  reading as it did before.
