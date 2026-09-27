### Fixed
- **A task taken out of its project could turn up in another one.** When two
  devices filed the same task under different projects before they synced, the
  task showed in one of them — and taking it out, or moving it, left the other
  link behind, so the task reappeared there, filing it under that project did
  nothing, and a move could appear not to happen at all. Moving or removing a
  task's project now takes it out of every project it was filed under.
- **Two tasks could end up blocking each other.** Linking tasks while the task
  agent linked them too, or through a long enough chain of blockers, could
  close a loop the app is meant to refuse. Such a loop is now refused on the
  device that would close it.

### Changed
- **Tasks that block each other now say so.** Two devices can still each add
  one direction of a block before they sync. Both tasks then show "Blocked in
  a cycle" instead of "Blocked by 1 task", with a hint that closing either one,
  or removing a link, releases the other; the day planner is told the two wait
  on each other instead of trying to schedule one first.
