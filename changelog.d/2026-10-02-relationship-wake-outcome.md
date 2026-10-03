### Fixed
- **A person's agent card could say "Last run failed" on one device beside a
  briefing that had just been written on another, or stay quiet about a
  failure.** When you use Lotti on more than one device, a quick failure on
  one could outrank a longer success on the other, and an unrelated change
  on the device that failed could bring its stale failure back over the
  success. Every device now records when the last briefing was written and
  when the last run failed, and all of them agree on which came last. A
  failure that happened before the latest briefing no longer counts as the
  current state.
