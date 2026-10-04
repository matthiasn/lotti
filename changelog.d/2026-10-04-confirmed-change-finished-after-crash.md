### Fixed
- **A follow-up task confirmed just before the app closed could lose its
  link, project and agent.** Confirming an agent's suggested follow-up task
  creates the task, then links it to the task it came from, files it in that
  task's project and assigns it an agent. If the app quit or crashed in
  between, the suggestion showed as confirmed but the task stood on its own,
  and confirming it on another device did not repair it. The app now
  finishes an interrupted confirmation the next time it starts, and a task
  that already exists gets whatever it is missing. The same applies to tasks
  created for a project or an event, and to time entries an agent records.
