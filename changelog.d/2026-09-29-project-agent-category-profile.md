### Fixed
- **A new project's agent ignored the category's inference profile.** Every
  project created with an agent quietly ran on the agent template's built-in
  Gemini model, whatever profile its category named. It now takes the
  category's default inference profile. A category without a default still
  leaves the agent on the template's profile or model.
- **The projects list blinked out whenever an agent updated.** Each time a
  project agent finished a report, the whole list vanished for a moment and
  came back. It now stays on screen and switches to the new data once it is
  ready.

### Added
- **Show each project agent's inference profile in the projects list.** A new
  *Show inference profile* switch in the projects filter tags every project
  that has an agent with the name of its profile, or *No inference profile*.
  An agent whose profile was deleted is flagged *Inference profile missing*.
  It is off by default, and makes it easy to go through projects one by one
  and fix the ones still on the wrong model.
