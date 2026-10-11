### Fixed
- **An agent you delete stops on your other devices too**, even when one of
  them missed the deletion at the time.
- **Repairing vector clocks no longer overwrites a recent agent change** made
  while the repair ran.
- **A resumed task agent follows its task again right away** after a sync
  hiccup, instead of only after a restart.
- **Old agent observations cleaned up on one device no longer come back** from
  devices that have not cleaned up yet.
- **Disconnecting GitHub reaches your other devices** when you use "Send
  settings", even if the original message was lost.
