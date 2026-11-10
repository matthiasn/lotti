### Fixed
- **Task agents act on what changed again instead of replying with a note.**
  Since their observations were trimmed, an agent could read "most wakes
  record nothing" as leave to do nothing, and end a wake after a single
  reply without updating the task or its report. The agent is now told that
  a reply without a tool call ends its wake, and that a wake with no note
  still makes every change the task needs.
