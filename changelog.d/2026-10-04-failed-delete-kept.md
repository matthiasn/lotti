### Fixed
- **A delete that could not be saved looked done.** When deleting a
  checklist item, a checklist or an entry failed to save — the database
  refused or could not write it — the app carried on as if it had worked: the
  checklist item or checklist stayed in the journal but disappeared from its
  task, and nothing tried again; an entry's page closed though the entry was
  still there. A failed checklist deletion is now finished the next time the
  app starts, and a failed entry deletion keeps the page open and says so.
