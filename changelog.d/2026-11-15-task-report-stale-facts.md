### Fixed
- **A task report could keep saying "due today" days after the due date had
  passed.** The task agent avoids rewriting a report when nothing changed, and
  a date passing did not count as a change, so the report stayed wrong until
  something else woke the agent. Reports now record the due date and estimate
  they were written against. When the due date passes, moves or is cleared,
  when the estimate changes, or when the status has changed since, the agent
  writes a new report even if nothing else happened. With automatic updates
  on, it also wakes by itself at the midnight a due date turns into
  "tomorrow", "today" or "overdue".
