### Fixed
- **Checklist items and whole checklists could silently disappear from a
  task.** When an item or a checklist arrived from another device, or was
  added by the task agent, a moment before you reordered a checklist, added
  an item or changed the task's status, priority or estimate — or before the
  agent changed one of them — your change was saved over the list as your
  screen last saw it, and the new item or checklist dropped out of the task
  on every device, although it still existed. Those changes are now applied
  to the lists as they are stored, so nothing added meanwhile is lost. A
  checklist added after you had reordered a task's checklists also stayed
  hidden until you left the task; it now shows up straight away.
- **Checking off an item could undo a move or a rename made elsewhere.**
  Ticking an item that another device (or the agent) had just moved or
  renamed saved your screen's older copy of it back. A check, rename or
  archive now changes only what you changed.
- **Swiping a checklist item away never actually deleted it.** The item
  vanished from its checklist but stayed stored, and synced to your other
  devices, indefinitely. It is now deleted once the undo toast has passed.
- **Closing the app in the middle of a checklist change could leave it half
  done** — an item created but in no checklist, an item moved into a second
  checklist while still listed in the first, or an item you swiped away and
  did not undo still around. The app now finishes such a change the next
  time it starts.
