### Fixed
- **Project agents woke on their own even with Automatic updates switched
  off.** A project agent that had never had the switch touched showed it off,
  yet ran its analysis whenever its project changed — in the worst case
  hundreds of times a day, each run a paid model call. The switch now means
  what it shows: off is off.
- **Pausing an agent now stops it at once.** Pause, Destroy and Delete used to
  stop only future triggers; a wake already queued could still start, and one
  already running kept paying for further model turns until it finished. Now
  queued work is dropped and a running wake stops before its next model call,
  on every device the pause reaches.
- **A revoked or invalid API key no longer keeps the app retrying.** Goal and
  relationship briefings and Daily OS transcriptions retried a refused key
  every few minutes or on every check, forever; they now wait for the key to be
  fixed. The error says the key was refused instead of "rate limit exceeded".
- **Switching Automatic updates on no longer always starts a paid update.** It
  now runs one only when the report is missing or out of date.

### Added
- **A daily wake limit for project agents.** Each project agent may run at most
  ten times a day by default, counted across all your devices; Agent internals
  shows how much of today's limit is used and lets you choose another limit.
  Once it is reached, automatic updates pause until tomorrow and the panel says
  so. Update now keeps working, up to twice the limit.
