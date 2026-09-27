### Fixed
- **Working on the same task from two devices now saves the second update on
  older tasks too.** A task holding any link saved by an older version of the
  app never let the other device stand down, so both devices still ran the
  task's agent however the update was started. Each device now tells the
  other which of those old links its update read. On older tasks, as on new
  ones, one device's update now ends the other device's countdown whenever it
  included everything the other device has.
