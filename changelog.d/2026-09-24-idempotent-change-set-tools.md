### Fixed
- **Confirming an agent's suggestion to create a follow-up task, a time entry
  or a checklist item on two devices no longer creates it twice.** When such a
  suggestion was confirmed on one device and again on another before the two
  had synced, both applied it: two follow-up tasks, two time entries, a
  checklist item added or moved twice. Now both devices create the same entry.
  A device that has already received it adds nothing — also when you have
  deleted the entry, or its checklist, in the meantime. If both devices create
  it before either has received the other's, you get one entry and a sync
  conflict to resolve, not a duplicate. A suggested change to a task's title,
  status, priority, estimate, due date or language is also applied only while
  that field still holds the value the agent saw, so a late confirmation on
  another device no longer overwrites an edit you made in the meantime.
