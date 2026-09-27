### Fixed
- **Undoing a suggested task could leave two tasks behind.** While the undo of
  an accepted "create task" suggestion was still removing the task, the
  suggestion already showed as open again, and accepting it in that moment —
  on the same device or another one — created a second task. If the removal
  then failed, both tasks stayed. The undo now removes the task first and only
  then reopens the suggestion; if the removal fails, the suggestion stays
  accepted with its task.
