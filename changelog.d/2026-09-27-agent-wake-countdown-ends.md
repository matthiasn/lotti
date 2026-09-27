### Fixed
- **A task update finished on another device now ends this device's countdown
  at once.** With the same task open on two devices, this device waited until
  its own countdown ran out before noticing that the other device had already
  updated the task — the countdown kept running and the summary kept showing
  as outdated in the meantime. Now, as soon as the other device finishes an
  update that included everything this device has, the countdown disappears
  and the summary is no longer marked outdated. This works in both
  directions.
