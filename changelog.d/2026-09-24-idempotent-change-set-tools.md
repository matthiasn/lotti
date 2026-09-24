### Fixed
- **Confirming the same agent suggestion on two devices no longer does it
  twice.** When a suggestion was confirmed on one device and again on another
  before the two had synced, both applied it: two follow-up tasks, two time
  entries, a checklist item added or moved twice. Now the second device
  recognises what the first already created and adds nothing. A suggested
  change to a task's title, status, priority, estimate, due date or language
  is also applied only while that field still holds the value the agent saw,
  so a late confirmation on another device no longer overwrites an edit you
  made in the meantime.
