### Fixed
- **Linked pull requests are listed newest first, and their age is GitHub's.**
  A task's Pull requests card and the "+" picker now list pull requests the
  way GitHub does, the newest at the top. The age on each card is how long the
  pull request has been open — or since it was merged or closed, with the
  weekday and date (and year) once it is over a week old — instead of
  when Lotti last read it, so several pull requests linked at once no longer
  all say "10 min ago". The card says "Blocked by branch rules" only when
  nothing else on it explains why: no longer next to a missing review or a
  failing check, which it only repeated.
