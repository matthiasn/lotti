### Fixed
- **A slow day plan or plan change could be worked out twice.** When drafting
  or refining your day took longer than three minutes — because the planner
  was still busy with other work — the app gave up waiting and asked again
  while the first request was still running, so the same request was paid for
  twice and a refinement could leave two suggested changes. The app now waits
  for the request already under way instead of starting another.
- **The morning briefing could be written twice on the same day.** A check
  that looks for an interrupted briefing could miss one that was just about to
  start, or one whose finish time a clock correction had moved, and run the
  briefing again. It now recognises both.
