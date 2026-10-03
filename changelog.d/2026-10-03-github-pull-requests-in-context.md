### Added
- **Coding prompts and task agents now see a task's pull requests.** With
  GitHub pull requests turned on, generating a coding prompt or waking the
  task agent first refreshes every pull request linked to the task. The
  coding prompt then knows what is already done — its state, checks, merge
  conflicts, reviews and description — asks only for what remains, and says
  at the top where the pull requests and the checklist disagree. The task
  agent can propose ticking off checklist items a pull request has done,
  naming that pull request; you confirm each one. A pull request that could
  not be refreshed is never taken as evidence.
