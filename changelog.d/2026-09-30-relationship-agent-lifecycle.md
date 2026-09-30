### Fixed
- **A person marked important could lose their reminders and briefings for
  good.** When a second device received a person's agent before the person
  themself had synced, it took the person for deleted and shut the agent down
  on every device, and marking them important again did nothing. The agent
  now stops only for a person who really was deleted, and anyone still
  marked important gets their agent back automatically, including anyone
  this already happened to. If you had stopped a person's agent yourself
  but kept their reminders on, it restarts too; turn their reminders off
  instead to keep it stopped.
- **Asking for a briefing works again after deleting a person's agent.**
  *Brief me* brings the agent back, and marking the person important again
  does so straight away rather than at the next hourly check.
- **Pausing, stopping or deleting a relationship agent no longer comes
  undone on another device.** Renaming the person on a second device at the
  same time, or an older reminder setting arriving late, could quietly bring
  the agent back. Your most recent choice now holds everywhere: stop it, and
  it stays stopped until you turn reminders on again or resume it.
