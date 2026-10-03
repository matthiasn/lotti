### Fixed
- **Goal check-ins no longer keep their conversations in memory.** Each goal
  agent wake now discards its conversation when it finishes, as the other
  agents already did, so memory no longer grows with every goal check-in
  while the app stays open.
- **A day plan wake no longer fails over its usage record.** If saving the
  token-usage record fails, the day agent's wake still succeeds, as every other
  agent's does, instead of failing and running again.
- **Goal and relationship replies are read the same way with every provider.**
  When a model's last turn only called tools, its reply is taken from what it
  last said, whichever provider ran the conversation.
