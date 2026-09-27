### Fixed
- **Working on a task from two devices now really runs its agent once.** In
  1.1.29 a device only stood down when its task was exactly as the other
  device's had been, which in practice it never was: change a task on the
  desktop, check off one of its items on the phone before the desktop's
  update starts, and both devices still ran the agent. A device now stands
  down whenever the other device's update already included everything it has.
  An edit that reaches the other device only after its update has started is
  still processed by its own update. Both devices need this version; with an
  older one on the other side, each runs on its own as before.
