### Fixed

- **Project membership stays consistent when tasks or projects change.** Task
  links now respect category and privacy changes, failed task assignments clean
  up newly created tasks, and project edits preserve unrelated synced changes.
  A project's category cannot change while it has linked tasks or a live agent.
- **Project agents follow synced project changes.** Agents are retired when a
  synced project disappears, and their category permissions follow synced moves
  without scheduling an unnecessary report.
