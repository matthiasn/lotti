### Changed
- **Working on a task from two devices at once rarely runs its agent twice
  any more.** Starting a task update on the desktop and carrying on by
  dictating into the phone left each device to run the task agent on its
  own, usually over the same synced task — two model calls for one result,
  and two sets of suggestions to review. A device that starts an update now
  tells your other devices which state of the task it is working from. A
  device holding that same state waits, and drops its own update once the
  first finishes. A device that has newer changes still runs, and if the
  first device goes quiet, the other runs after two minutes. Two devices
  that start within moments of each other, before either hears from the
  other, can still both run.
