### Fixed
- **Decimal amounts now meet a target they add up to exactly.** Ten entries of
  0.1 l, or 0.7 plus 0.1, were stored as a hair under 1 l and 0.8, so "at least
  1 l" habits did not check themselves off and goals read the day as missed.
  Totals and averages are now compared the way you would add them up yourself.
- **A skip you recorded is no longer overwritten by an automatic check-off from
  another device.** If a second device auto-completed the habit from synced
  data before your skip reached it, the check-off won everywhere once both
  synced. Anything you record for a day now always outranks the automatic one.
- **"Successful days needed to recover" counts today while it is still open.**
  A rolling-window goal could ask for three more days when completing the habit
  today was enough.
- **A goal with an "either" part that is already met is no longer marked Behind
  just because the other option ran out of days.** The goal now looks at what
  is still left to do.
- **Goals can no longer be set to a quota the window cannot hold**, such as 10
  successes in a rolling 7 days or 8 in a calendar week, which could never be
  met. Existing goals keep working unchanged.
