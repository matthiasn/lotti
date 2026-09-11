### Fixed
- **Asking an agent could fail immediately while its setup was loading.**
  Task, project and category queries now wait for the configured model setup
  to finish loading before starting the search. Audio timestamp preparation
  uses the same corrected setup lookup.
- **Agent chat now opens with a direct invitation to ask about the current
  task, project or category.** Its failure message no longer claims a question
  was saved when setup failed before saving it.
- **Large agent searches shortlist sources together before inspecting matches.**
  This reduces model round trips while keeping exact quotes and live privacy
  checks. Skipped sources are reported as incomplete coverage.
- **Query chat shows searching while it retrieves evidence.** It switches to
  preparing an answer only when the final response is being composed.
