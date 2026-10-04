### Fixed
- **Stopping a timer from the sidebar lost up to five minutes of tracked
  time.** The timer's entry is saved every five minutes while it runs, and
  stopping it from the desktop sidebar, switching profiles or quitting the app
  left the entry where that last save had put it. Every way of stopping a
  timer now saves its end, and quitting the app stops a running timer and
  saves it first.
- **The task agent could stop a timer you had just started.** When the agent
  started a timer for a task while you started one yourself, its timer
  replaced yours. It now leaves a running timer alone and says that its own
  time entry was saved but not started.
