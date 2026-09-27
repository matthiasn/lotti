### Fixed
- **Agents from your other devices could stop arriving on a device.** If the
  agent runtime hit an error while the app started, that device silently
  discarded every agent record sync delivered for the rest of the session,
  and left agent records out of a deep backfill and out of Sync health's
  record counts. Agent records are now received, compared and counted however
  the agent runtime fares, and a failed start is logged.
