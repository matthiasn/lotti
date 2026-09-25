### Fixed
- **A message to a goal could be answered twice, by two of your devices.**
  When you write to a goal, the device you typed on answers, and your other
  devices only step in if no answer arrives within half an hour. Outside the
  UTC time zone, that half hour was read wrongly: east of Greenwich — most of
  Europe, Asia and Australia — another device could step in as soon as the
  message reached it, while the first one was still answering. West of it,
  in the Americas, goal and relationship check-ins that were meant to run
  right away could wait hours. Every scheduled wake is now due at the moment
  it names, in any time zone.
