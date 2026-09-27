### Fixed
- **A deleted agent could come back.** Deleting an agent removed its data on
  this device, but when sync delivered an older update about it afterwards —
  its creation arriving late, or a message from a run still going on another
  device — the agent reappeared, sometimes as active again. A deleted agent
  now stays deleted, whatever order its updates arrive in.
