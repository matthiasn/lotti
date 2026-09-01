### Fixed
- **The task estimate is visible at a glance again.** The task header's
  summary lane shows the estimate as its own read-out, next to the due date,
  instead of only inside the Details fly-out. Tapping it opens the fly-out
  as the other read-outs do; a task without an estimate shows nothing extra.
- **The AI summary no longer says "Up to date" while counting down to its
  next update.** A scheduled update means something changed since the last
  summary, so the footer now reads "Out of date" beside the countdown and
  only claims "Up to date" when nothing is pending.
