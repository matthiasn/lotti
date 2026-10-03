### Changed
- **GitHub pull requests no longer need a config flag, and a task shows them
  only when you ask.** The *GitHub pull requests* config flag is gone: adding
  your token under Settings → Advanced Settings → GitHub is all it takes.
  Tasks no longer carry an empty Pull requests card. On a task that should
  follow pull requests, choose *Pull request tracking* from the "+" menu of
  the bar at the bottom of the task: the Pull requests section appears and
  the page scrolls to it, and it stays — on every device, even with nothing
  linked yet. Tasks that already have pull requests linked keep their section
  without doing anything. A category's GitHub repository is offered while
  your token works. If GitHub rejects the token later — it expired or was
  revoked — the action is withdrawn until it works again, while the pull
  requests already linked keep showing what GitHub last said and why they
  could not be refreshed.
