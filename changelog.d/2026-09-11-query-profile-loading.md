### Fixed
- **Asking an agent could fail immediately while its setup was loading.**
  Task, project and category queries now wait for the configured model setup
  to finish loading before starting the search. Audio timestamp preparation
  uses the same corrected setup lookup.
- **Agent chat now opens with a direct invitation to ask about the current
  task, project or category.** Its failure message no longer claims a question
  was saved when setup failed before saving it.
