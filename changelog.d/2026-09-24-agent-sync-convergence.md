### Fixed
- **Devices could permanently disagree about an agent after syncing.** A
  change written on one device from an out-of-date view — or a wake's
  cooldown timer stamped on the agent's state — could stay on that device
  while every other device kept a different version, and an agent's wake
  count could lose runs recorded elsewhere. Such out-of-date changes and
  cooldown timers now resolve the same way on every device, and no device's
  runs are dropped from the count.
- **A task report could look up to date although the task changed while it
  was being written.** Finishing an update put back the agent's state from
  when the update started, erasing the note that something had changed in
  the meantime.
- **An old goal statement could stay marked active beside the current one.**
  When two devices revised a goal offline, the version that lost stayed
  active through every later revision; the next revision now retires it.
