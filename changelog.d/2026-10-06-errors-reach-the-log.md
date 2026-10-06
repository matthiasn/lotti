### Fixed
- **Many failures left no trace in the app's logs.** Errors behind a generic
  "something went wrong" message in the AI, agent, task, project and
  relationship screens were visible only to an attached debugger. They are now
  written to the app's error log with their stack trace, and the progress
  notes around them go to the matching logging domain.
