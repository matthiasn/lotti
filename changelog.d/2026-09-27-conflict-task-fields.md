### Fixed
- **Resolving a sync conflict on a task could quietly undo a status,
  priority, estimate or due date change.** The conflict screen compared a
  task's title, but lumped every other task field into "other details", so
  keeping one device's version put back whatever the other device had set
  there, unseen. The screen now shows a task's status (with the reason it is
  blocked or on hold), priority, estimate and due date side by side, and
  Combine lets you take each from either device.
