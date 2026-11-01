### Fixed
- **A category's Automatic inference switch could disappear while it was
  still on.** The switch also controls automatic pull request summaries, but
  it was only shown when something could transcribe or analyse — so with no
  speech model set up it vanished, and summaries kept running with no way to
  turn them off. It now shows whenever it is on, and whenever anything it
  controls could run, and its description mentions pull request summaries.
