### Fixed
- **A task could end up with two agents.** A follow-up task confirmed on two
  devices before they synced got a task agent from each, and assigning an
  agent to the same task on two devices did the same. Both agents then kept
  waking, spending tokens and writing reports and suggestions, though the task
  showed only one. Once the devices sync, a task now keeps the one agent it
  shows, on every device, and the other is stopped. Tasks that already have
  two agents are cleaned up the same way the next time the app starts.
