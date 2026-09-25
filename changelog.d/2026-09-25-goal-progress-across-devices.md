### Fixed
- **A goal's report no longer keeps an old status after your devices catch up
  with each other.** When the device that wrote the report had not yet
  received your latest check-off, the report could say "behind" all day while
  the goal showed on track everywhere. A report that contradicts the day's
  status is now refreshed.
- **A check-off can no longer vanish from a goal's day.** Two evaluations of
  the same goal on one device could overlap, and the one that started first
  could finish last, dropping evidence the other had counted.
- **Status changes reach the goal's report promptly and are not lost when a
  device goes away.** A change of status is now handed to your other devices
  at once instead of waiting two minutes on the device that noticed it;
  "Skip once" still holds back refreshes for new evidence that leaves the
  status alone.
