### Added
- **Pull requests in a task are summarised.** Each linked pull request gets a
  one-line summary under its title and a short TL;DR: what it changes, where
  it stands, and how it got there, including rounds of requested changes and
  long discussions. The task agent's model writes them, automatically where
  the task's category allows automatic inference, and whenever you tap
  Summarize. They sync to your other devices.
- **Pull request size and details.** Each row shows the size as +444 −221 in
  green and red. Tapping a pull request opens its details: status, size,
  summary, its own description, and a button to open it on GitHub.

### Changed
- **Merged and closed pull requests take a few lines in a task's context.**
  Coding prompts and the task agent see a finished pull request's outcome,
  size and TL;DR instead of its whole description, branch, checks and
  reviews; open pull requests keep every detail and gain their TL;DR. For a
  task with many merged pull requests, every agent wake and coding prompt is
  much smaller.
