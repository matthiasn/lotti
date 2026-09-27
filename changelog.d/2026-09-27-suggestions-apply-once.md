### Fixed
- **A suggestion accepted on two devices before they synced could apply twice.**
  Accepting the project agent's "create task" on a phone and a laptop created
  two tasks, and a late second acceptance of a checklist, time entry or project
  status suggestion could overwrite a change you made in between — checking an
  item off again that you had just unchecked, say. Each suggestion now applies
  once: the second acceptance finds the task already there, or finds that you
  changed the item since, and leaves it as you left it. After undoing a created
  task, accepting the suggestion again now creates the task anew.
